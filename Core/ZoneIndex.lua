--[[
    Housing Codex - ZoneIndex.lua
    Zone-to-decor aggregation for the world map overlay.
    Combines vendor, quest, and treasure hunt data by zone/mapID.
]]

local ADDON_NAME, addon = ...

-- Zone name aliases: C_Map.GetMapInfo().name -> scraper zone name
-- Only needed when WoW's map name differs from WowDB scraper zone name
local ZONE_NAME_ALIASES = {
    ["Boralus"] = "Boralus Harbor",
    ["Mechagon Island"] = "Mechagon",
    ["Gilneas City"] = "Gilneas",
}

-- Runtime data
local questsByZoneName = {}       -- zoneName -> { questKey1, questKey2, ... }
local treasureHuntQuestSet = {}   -- questID -> true (fast lookup for treasure hunt classification)
local zoneDecorCache = {}         -- mapID -> { vendors = {...}, quests = {...}, treasures = {...} }
local zoneProgressCache = {}      -- mapID -> { uncollected = n, total = n }
local indexBuilt = false

--------------------------------------------------------------------------------
-- Resolve the scraper zone name for a given mapID
-- Uses C_Map.GetMapInfo().name with alias fallback
--------------------------------------------------------------------------------
local mapNameCache = {}  -- mapID -> resolved scraper zone name (or false if none)

local function GetScraperZoneName(mapID)
    if not mapID then return nil end

    local cached = mapNameCache[mapID]
    if cached ~= nil then
        return cached or nil
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    if not mapInfo or not mapInfo.name then
        mapNameCache[mapID] = false
        return nil
    end

    local mapName = mapInfo.name

    -- Direct match first
    if questsByZoneName[mapName] then
        mapNameCache[mapID] = mapName
        return mapName
    end

    -- Try alias
    local aliased = ZONE_NAME_ALIASES[mapName]
    if aliased and questsByZoneName[aliased] then
        mapNameCache[mapID] = aliased
        return aliased
    end

    mapNameCache[mapID] = false
    return nil
end

--------------------------------------------------------------------------------
-- Build the zone decor index (lazy, called on first access)
--------------------------------------------------------------------------------
local function BuildIndex()
    if indexBuilt then return end

    local startTime = debugprofilestop()

    -- 1. Build treasure hunt quest ID set (for classification)
    wipe(treasureHuntQuestSet)
    if addon.TreasureHuntLocations then
        for questID in pairs(addon.TreasureHuntLocations) do
            treasureHuntQuestSet[questID] = true
        end
    end

    -- 2. Build questsByZoneName reverse index from questZoneFromScrape
    wipe(questsByZoneName)
    if addon.questZoneFromScrape then
        for questKey, zoneData in pairs(addon.questZoneFromScrape) do
            local zoneName = zoneData.zoneName
            if zoneName then
                if not questsByZoneName[zoneName] then
                    questsByZoneName[zoneName] = {}
                end
                table.insert(questsByZoneName[zoneName], questKey)
            end
        end
    end

    indexBuilt = true

    addon:Debug(string.format("Built zone decor index in %d ms", debugprofilestop() - startTime))
end

--------------------------------------------------------------------------------
-- Get decor items for a zone, grouped by source
-- Returns: { vendors = {...}, quests = {...}, treasures = {...} } or nil
--------------------------------------------------------------------------------
function addon:GetZoneDecorItems(mapID)
    if not mapID or not self.dataLoaded then return nil end

    -- Resolve to zone-level mapID
    local zoneMapID = self:GetZoneRootMapID(mapID)
    if not zoneMapID then return nil end

    -- Check if this is a zone or city (not continent/world)
    local mapInfo = C_Map.GetMapInfo(zoneMapID)
    if not mapInfo then return nil end
    local mt = mapInfo.mapType
    if not mt or mt == Enum.UIMapType.Cosmic or mt == Enum.UIMapType.World or mt == Enum.UIMapType.Continent then
        return nil
    end

    -- Check cache
    local cached = zoneDecorCache[zoneMapID]
    if cached then return cached end

    BuildIndex()

    local result = { vendors = {}, quests = {}, treasures = {} }
    local seenRecords = {}  -- Deduplicate across sources

    -- Helper: add a decor item to a target list with deduplication
    local function AddItem(targetList, recordID, sourceName, sourceId)
        if seenRecords[recordID] then return end
        seenRecords[recordID] = true
        local record = self:GetRecord(recordID)
        table.insert(targetList, {
            recordID = recordID,
            decorName = self:ResolveDecorName(recordID, record),
            sourceName = sourceName,
            sourceId = sourceId,
            isCollected = record and record.isCollected or false,
        })
    end

    -- 1. Vendors (indexed by mapID directly)
    local vendorsByMapID = self:GetAllVendorMapVendors()
    local mapVendors = vendorsByMapID and vendorsByMapID[zoneMapID]
    if mapVendors then
        for _, vendorPin in ipairs(mapVendors) do
            local vendor = self.vendorIndex and self.vendorIndex[vendorPin.npcId]
            if vendor and vendor.decorIds then
                for _, decorId in ipairs(vendor.decorIds) do
                    AddItem(result.vendors, decorId, vendorPin.npcName, vendorPin.npcId)
                end
            end
        end
    end

    -- 2. Quests and Treasure Hunts (indexed by zone name)
    local zoneName = GetScraperZoneName(zoneMapID)
    local zoneQuests = zoneName and questsByZoneName[zoneName]
    if zoneQuests then
        for _, questKey in ipairs(zoneQuests) do
            local questRecords = self.questIndex and self.questIndex[questKey]
            if questRecords then
                local isTreasureHunt = type(questKey) == "number" and treasureHuntQuestSet[questKey]
                local targetList = isTreasureHunt and result.treasures or result.quests
                local questTitle = self:GetQuestTitle(questKey)

                for recordID in pairs(questRecords) do
                    AddItem(targetList, recordID, questTitle, questKey)
                end
            end
        end
    end

    -- 3. Treasure hunts by mapID (catches any not covered by zone name matching)
    if addon.TreasureHuntLocations then
        for questID, locData in pairs(addon.TreasureHuntLocations) do
            if locData.mapID == zoneMapID then
                local questRecords = self.questIndex and self.questIndex[questID]
                if questRecords then
                    local questTitle = self:GetQuestTitle(questID)
                    for recordID in pairs(questRecords) do
                        AddItem(result.treasures, recordID, questTitle, questID)
                    end
                end
            end
        end
    end

    -- Sort each group by pre-resolved name
    local function SortByName(a, b)
        return a.decorName < b.decorName
    end
    table.sort(result.vendors, SortByName)
    table.sort(result.quests, SortByName)
    table.sort(result.treasures, SortByName)

    zoneDecorCache[zoneMapID] = result
    return result
end

--------------------------------------------------------------------------------
-- Get zone progress (uncollected/total counts)
--------------------------------------------------------------------------------
function addon:GetZoneDecorProgress(mapID)
    if not mapID then return 0, 0 end

    local zoneMapID = self:GetZoneRootMapID(mapID)
    if not zoneMapID then return 0, 0 end

    -- Check cache
    local cached = zoneProgressCache[zoneMapID]
    if cached then return cached.uncollected, cached.total end

    local items = self:GetZoneDecorItems(zoneMapID)
    if not items then return 0, 0 end

    local uncollected, total = 0, 0
    for _, group in ipairs({ items.vendors, items.quests, items.treasures }) do
        for _, item in ipairs(group) do
            total = total + 1
            if not item.isCollected then
                uncollected = uncollected + 1
            end
        end
    end

    zoneProgressCache[zoneMapID] = { uncollected = uncollected, total = total }
    return uncollected, total
end

--------------------------------------------------------------------------------
-- Cache invalidation
--------------------------------------------------------------------------------
function addon:InvalidateZoneDecorCache()
    wipe(zoneDecorCache)
    wipe(zoneProgressCache)
end

-- Invalidate on ownership changes
addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
    addon:InvalidateZoneDecorCache()
    addon:FireEvent("ZONE_DECOR_CACHE_INVALIDATED")
end)
