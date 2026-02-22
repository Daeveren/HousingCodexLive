--[[
    Housing Codex - ZoneIndex.lua
    Zone-to-decor aggregation for the world map overlay.
    Combines vendor, quest, and treasure hunt data by zone/mapID.
]]

local ADDON_NAME, addon = ...

-- Shared zone-to-expansion mapping (used by QuestIndex, VendorIndex, and ZoneIndex)
-- Source: merged from VendorSourceData and QuestSourceData scraper zone names
-- Conflict resolution: Gilneas/Ruins of Gilneas = CATA, Voidstorm = MIDNIGHT
addon.ZONE_TO_EXPANSION = {
    -- Classic
    ["Blackrock Depths"] = "EXPANSION_CLASSIC",
    ["Blasted Lands"] = "EXPANSION_CLASSIC",
    ["Burning Steppes"] = "EXPANSION_CLASSIC",
    ["Darnassus"] = "EXPANSION_CLASSIC",
    ["Deeprun Tram"] = "EXPANSION_CLASSIC",
    ["Dun Morogh"] = "EXPANSION_CLASSIC",
    ["Duskwood"] = "EXPANSION_CLASSIC",
    ["Dustwallow Marsh"] = "EXPANSION_CLASSIC",
    ["Eastern Plaguelands"] = "EXPANSION_CLASSIC",
    ["Elwynn Forest"] = "EXPANSION_CLASSIC",
    ["Felwood"] = "EXPANSION_CLASSIC",
    ["Hillsbrad Foothills"] = "EXPANSION_CLASSIC",
    ["Ironforge"] = "EXPANSION_CLASSIC",
    ["Loch Modan"] = "EXPANSION_CLASSIC",
    ["Mudsprocket, Dustwallow Marsh"] = "EXPANSION_CLASSIC",
    ["Mulgore"] = "EXPANSION_CLASSIC",
    ["Northern Stranglethorn"] = "EXPANSION_CLASSIC",
    ["Northshire"] = "EXPANSION_CLASSIC",
    ["Orgrimmar"] = "EXPANSION_CLASSIC",
    ["Searing Gorge"] = "EXPANSION_CLASSIC",
    ["Silverpine Forest"] = "EXPANSION_CLASSIC",
    ["Stormwind City"] = "EXPANSION_CLASSIC",
    ["Stranglethorn Vale"] = "EXPANSION_CLASSIC",
    ["Surwich, Blasted Lands"] = "EXPANSION_CLASSIC",
    ["Teldrassil"] = "EXPANSION_CLASSIC",
    ["The Cape of Stranglethorn"] = "EXPANSION_CLASSIC",
    ["The Library, Ironforge"] = "EXPANSION_CLASSIC",
    ["Thelsamar, Loch Modan"] = "EXPANSION_CLASSIC",
    ["Thunder Bluff"] = "EXPANSION_CLASSIC",
    ["Tirisfal Glades"] = "EXPANSION_CLASSIC",
    ["Trade District, Stormwind"] = "EXPANSION_CLASSIC",
    ["Undercity"] = "EXPANSION_CLASSIC",
    ["Undercity, Orgrimmar"] = "EXPANSION_CLASSIC",
    ["Westfall"] = "EXPANSION_CLASSIC",
    ["Wetlands"] = "EXPANSION_CLASSIC",
    ["Winterspring"] = "EXPANSION_CLASSIC",

    -- TBC
    ["Exile's Reach"] = "EXPANSION_TBC",
    ["Ghostlands"] = "EXPANSION_TBC",
    ["Shattrath City"] = "EXPANSION_TBC",

    -- Wrath
    ["Borean Tundra"] = "EXPANSION_WRATH",
    ["Dalaran"] = "EXPANSION_WRATH",
    ["Grizzly Hills"] = "EXPANSION_WRATH",
    ["Sholazar Basin"] = "EXPANSION_WRATH",
    ["Storm Peaks"] = "EXPANSION_WRATH",

    -- Cataclysm
    ["Gilneas"] = "EXPANSION_CATA",
    ["Mount Hyjal"] = "EXPANSION_CATA",
    ["Ruins of Gilneas"] = "EXPANSION_CATA",
    ["Stormglen Village, Gilneas"] = "EXPANSION_CATA",
    ["The Maelstrom"] = "EXPANSION_CATA",
    ["Twilight Highlands"] = "EXPANSION_CATA",

    -- MoP
    ["Brawl'gar Arena"] = "EXPANSION_MOP",
    ["Either Shrine in Vale of Eternal Blossoms"] = "EXPANSION_MOP",
    ["Kun-Lai Summit"] = "EXPANSION_MOP",
    ["Shrine of Seven Stars"] = "EXPANSION_MOP",
    ["Shrine of Two Moons"] = "EXPANSION_MOP",
    ["Shrine of Two Moons, Vale of Eternal Blossoms"] = "EXPANSION_MOP",
    ["The Jade Forest"] = "EXPANSION_MOP",
    ["The Veiled Stair"] = "EXPANSION_MOP",
    ["Timeless Isle"] = "EXPANSION_MOP",
    ["Vale of Eternal Blossoms"] = "EXPANSION_MOP",
    ["Valley of the Four Winds"] = "EXPANSION_MOP",

    -- WoD
    ["Ashran"] = "EXPANSION_WOD",
    ["Frostfire Ridge"] = "EXPANSION_WOD",
    ["Frostwall"] = "EXPANSION_WOD",
    ["Lunarfall"] = "EXPANSION_WOD",
    ["Nagrand"] = "EXPANSION_WOD",
    ["Shadowmoon Valley"] = "EXPANSION_WOD",
    ["Shadowmoon Valley (Draenor)"] = "EXPANSION_WOD",
    ["Spires of Arak"] = "EXPANSION_WOD",
    ["Stormshield"] = "EXPANSION_WOD",
    ["Stormshield, Ashran"] = "EXPANSION_WOD",
    ["Talador"] = "EXPANSION_WOD",
    ["Tanaan Jungle"] = "EXPANSION_WOD",
    ["Warspear"] = "EXPANSION_WOD",

    -- Legion
    ["Acherus: The Ebon Hold"] = "EXPANSION_LEGION",
    ["Acherus: Ebon Hold"] = "EXPANSION_LEGION",
    ["Azsuna"] = "EXPANSION_LEGION",
    ["Broken Isles"] = "EXPANSION_LEGION",
    ["Broken Shore"] = "EXPANSION_LEGION",
    ["Dreadscar Rift"] = "EXPANSION_LEGION",
    ["Eredath"] = "EXPANSION_LEGION",
    ["Hall of the Guardian"] = "EXPANSION_LEGION",
    ["Highmountain"] = "EXPANSION_LEGION",
    ["Krokuun"] = "EXPANSION_LEGION",
    ["Mandori Village"] = "EXPANSION_LEGION",
    ["Mardum, the Shattered Abyss"] = "EXPANSION_LEGION",
    ["Netherlight Temple"] = "EXPANSION_LEGION",
    ["Niskara"] = "EXPANSION_LEGION",
    ["Sanctum of Light"] = "EXPANSION_LEGION",
    ["Skyhold"] = "EXPANSION_LEGION",
    ["Stormheim"] = "EXPANSION_LEGION",
    ["Suramar"] = "EXPANSION_LEGION",
    ["The Dreamgrove"] = "EXPANSION_LEGION",
    ["The Fel Hammer"] = "EXPANSION_LEGION",
    ["The Hall of Shadows"] = "EXPANSION_LEGION",
    ["The Heart of Azeroth"] = "EXPANSION_LEGION",
    ["The Vindicaar"] = "EXPANSION_LEGION",
    ["The Wandering Isle"] = "EXPANSION_LEGION",
    ["Thunder Totem, Highmountain"] = "EXPANSION_LEGION",
    ["Trueshot Lodge"] = "EXPANSION_LEGION",
    ["Val'sharah"] = "EXPANSION_LEGION",

    -- BFA
    ["Boralus"] = "EXPANSION_BFA",
    ["Boralus Harbor"] = "EXPANSION_BFA",
    ["Chamber of Heart"] = "EXPANSION_BFA",
    ["Dazar'alor"] = "EXPANSION_BFA",
    ["Drustvar"] = "EXPANSION_BFA",
    ["Mechagon"] = "EXPANSION_BFA",
    ["Mechagon Island"] = "EXPANSION_BFA",
    ["Nazmir"] = "EXPANSION_BFA",
    ["Port of Zandalar, Dazar'alor"] = "EXPANSION_BFA",
    ["Stormsong Valley"] = "EXPANSION_BFA",
    ["The Great Sea"] = "EXPANSION_BFA",
    ["Tiragarde Sound"] = "EXPANSION_BFA",
    ["Vol'dun"] = "EXPANSION_BFA",
    ["Zuldazar"] = "EXPANSION_BFA",
    ["Zuldazar, Dazar'alor"] = "EXPANSION_BFA",

    -- Shadowlands
    ["Ardenweald"] = "EXPANSION_SL",
    ["Bastion"] = "EXPANSION_SL",
    ["Maldraxxus"] = "EXPANSION_SL",
    ["Oribos"] = "EXPANSION_SL",
    ["Revendreth"] = "EXPANSION_SL",
    ["Sinfall"] = "EXPANSION_SL",
    ["Tazavesh"] = "EXPANSION_SL",
    ["Tazavesh, the Veiled Market"] = "EXPANSION_SL",
    ["The Maw"] = "EXPANSION_SL",
    ["Zereth Mortis"] = "EXPANSION_SL",

    -- Dragonflight
    ["All Dragonflight Zones, moves with the Dreamsurge Event"] = "EXPANSION_DF",
    ["Amirdrassil"] = "EXPANSION_DF",
    ["Dragonscale Basecamp"] = "EXPANSION_DF",
    ["Emerald Dream"] = "EXPANSION_DF",
    ["Eon's Fringe, Thaldraszus"] = "EXPANSION_DF",
    ["Iskaara"] = "EXPANSION_DF",
    ["Ohn'ahran Plains"] = "EXPANSION_DF",
    ["Thaldraszus"] = "EXPANSION_DF",
    ["The Azure Span"] = "EXPANSION_DF",
    ["The Forbidden Reach"] = "EXPANSION_DF",
    ["The Waking Shores"] = "EXPANSION_DF",
    ["Valdrakken"] = "EXPANSION_DF",
    ["Zaralek Cavern"] = "EXPANSION_DF",

    -- TWW
    ["Azj-Kahet"] = "EXPANSION_TWW",
    ["City of Threads"] = "EXPANSION_TWW",
    ["Dornogal"] = "EXPANSION_TWW",
    ["Founder's Point"] = "EXPANSION_TWW",
    ["Freywold Village, Isle of Dorn"] = "EXPANSION_TWW",
    ["Gundargaz, Ringing Deeps"] = "EXPANSION_TWW",
    ["Hallowfall"] = "EXPANSION_TWW",
    ["Isle of Dorn"] = "EXPANSION_TWW",
    ["K'aresh"] = "EXPANSION_TWW",
    ["Liberation of Undermine"] = "EXPANSION_TWW",
    ["Razorwind Shores"] = "EXPANSION_TWW",
    ["Tazavesh, the Veiled Market, K'aresh"] = "EXPANSION_TWW",
    ["The Ringing Deeps"] = "EXPANSION_TWW",
    ["Undermine"] = "EXPANSION_TWW",

    -- Midnight
    ["Arcantina"] = "EXPANSION_MIDNIGHT",
    ["Eversong Woods"] = "EXPANSION_MIDNIGHT",
    ["Harandar"] = "EXPANSION_MIDNIGHT",
    ["Masters' Perch"] = "EXPANSION_MIDNIGHT",
    ["Satheril's Haven, Eversong Woods"] = "EXPANSION_MIDNIGHT",
    ["Silvermoon City"] = "EXPANSION_MIDNIGHT",
    ["The Bazaar, Silvermoon City"] = "EXPANSION_MIDNIGHT",
    ["Voidstorm"] = "EXPANSION_MIDNIGHT",
    ["Zul'Aman"] = "EXPANSION_MIDNIGHT",
}

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

local function SortByName(a, b)
    return a.decorName < b.decorName
end

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
    local function AddItem(targetList, recordID, sourceName, sourceId, cityName)
        if seenRecords[recordID] then return end
        seenRecords[recordID] = true
        local record = self:GetRecord(recordID)
        table.insert(targetList, {
            recordID = recordID,
            decorName = self:ResolveDecorName(recordID, record),
            sourceName = sourceName,
            sourceId = sourceId,
            isCollected = record and record.isCollected or false,
            cityName = cityName,
        })
    end

    local vendorsByMapID = self:GetAllVendorMapVendors()

    -- Helper: collect vendors for a single mapID
    local function CollectVendors(targetMapID, cityName)
        local mapVendors = vendorsByMapID and vendorsByMapID[targetMapID]
        if not mapVendors then return end
        for _, vendorPin in ipairs(mapVendors) do
            local vendor = self.vendorIndex and self.vendorIndex[vendorPin.npcId]
            if vendor and vendor.decorIds then
                for _, decorId in ipairs(vendor.decorIds) do
                    AddItem(result.vendors, decorId, vendorPin.npcName, vendorPin.npcId, cityName)
                end
            end
        end
    end

    -- Helper: collect quests and treasure hunts for a single mapID
    local function CollectQuestsAndTreasures(targetMapID)
        local zoneName = GetScraperZoneName(targetMapID)
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

        -- Treasure hunts by mapID (catches any not covered by zone name matching)
        if addon.TreasureHuntLocations then
            for questID, locData in pairs(addon.TreasureHuntLocations) do
                if locData.mapID == targetMapID then
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
    end

    -- 1. City children first: vendors get cityName, so they win dedupe over zone-level duplicates
    local cityChildren = addon:GetCityChildMapIDs(zoneMapID)
    if cityChildren then
        for _, cityMapID in ipairs(cityChildren) do
            local cityInfo = C_Map.GetMapInfo(cityMapID)
            local cityName = cityInfo and cityInfo.name
            CollectVendors(cityMapID, cityName)
            CollectQuestsAndTreasures(cityMapID)
        end
    end

    -- 2. Zone-level vendors and quests (duplicates from cities are harmlessly deduped)
    CollectVendors(zoneMapID)
    CollectQuestsAndTreasures(zoneMapID)

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

    local total = #items.vendors + #items.quests + #items.treasures
    local uncollected = 0
    for _, item in ipairs(items.vendors) do
        if not item.isCollected then uncollected = uncollected + 1 end
    end
    for _, item in ipairs(items.quests) do
        if not item.isCollected then uncollected = uncollected + 1 end
    end
    for _, item in ipairs(items.treasures) do
        if not item.isCollected then uncollected = uncollected + 1 end
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
