--[[
    Housing Codex - VendorMapIndex.lua
    World map vendor pin indexing and progress caching
]]

local _, addon = ...

addon.vendorMapVendorsByMapID = nil
addon.vendorPinProgressCache = addon.vendorPinProgressCache or {}

--------------------------------------------------------------------------------
-- Shared: Resolve zone-level mapID (walks up from sub-zones/dungeons to parent zone)
-- Used by ZoneIndex.lua and VendorMapPins.lua
--------------------------------------------------------------------------------
local zoneRootMapCache = {}

function addon:GetZoneRootMapID(uiMapID)
    if not uiMapID then return nil end

    local cached = zoneRootMapCache[uiMapID]
    if cached ~= nil then return cached end

    local currentMapID = uiMapID
    for _ = 1, 20 do
        local mapInfo = C_Map.GetMapInfo(currentMapID)
        if not mapInfo then break end

        if mapInfo.mapType and mapInfo.mapType == Enum.UIMapType.Zone then
            zoneRootMapCache[uiMapID] = currentMapID
            return currentMapID
        end

        local parentMapID = mapInfo.parentMapID
        if not parentMapID or parentMapID == 0 or parentMapID == currentMapID then
            break
        end

        -- If parent is a Continent, current map is zone-level (stop before walking up)
        local parentInfo = C_Map.GetMapInfo(parentMapID)
        if parentInfo and parentInfo.mapType and parentInfo.mapType == Enum.UIMapType.Continent then
            zoneRootMapCache[uiMapID] = currentMapID
            return currentMapID
        end

        currentMapID = parentMapID
    end

    zoneRootMapCache[uiMapID] = uiMapID
    return uiMapID
end

--------------------------------------------------------------------------------
-- Shared: Map zone mapIDs to their geographically-contained city mapIDs
-- WoW places cities as siblings of zones under the continent (not children),
-- so no API discovers this relationship. Static table, one entry per zone.
--------------------------------------------------------------------------------
local CITY_CHILDREN = {
    -- Eastern Kingdoms
    [37]   = { 84 },   -- Elwynn Forest -> Stormwind City
    [27]   = { 87 },   -- Dun Morogh -> Ironforge
    [18]   = { 90 },   -- Tirisfal Glades -> Undercity
    [94]   = { 110 },  -- Eversong Woods -> Silvermoon City (TBC)
    [2395] = { 2393 }, -- Eversong Woods -> Silvermoon City (Midnight)
    -- Kalimdor
    [1]    = { 85 },   -- Durotar -> Orgrimmar
    [7]    = { 88 },   -- Mulgore -> Thunder Bluff
    -- Battle for Azeroth
    [895]  = { 1161 }, -- Tiragarde Sound -> Boralus
    [862]  = { 1165 }, -- Zuldazar -> Dazar'alor
    -- Dragonflight
    [2025] = { 2112 }, -- Thaldraszus -> Valdrakken
    -- The War Within
    [2248] = { 2339 }, -- Isle of Dorn -> Dornogal
    [2255] = { 2213 }, -- Azj-Kahet -> City of Threads
    [2371] = { 2472 }, -- K'aresh -> Tazavesh
}

function addon:GetCityChildMapIDs(zoneMapID)
    if not zoneMapID then return nil end
    return CITY_CHILDREN[zoneMapID]
end

local function ShouldIncludeFaction(vendorFaction, playerFaction)
    if not vendorFaction or vendorFaction == "" or vendorFaction == "Neutral" then
        return true
    end
    return vendorFaction == playerFaction
end

local function InsertVendorIntoMap(vendorsByMapID, mapID, mapEntry)
    local list = vendorsByMapID[mapID]
    if not list then
        list = {}
        vendorsByMapID[mapID] = list
    end
    table.insert(list, mapEntry)
end

local function InsertVendorLocation(vendorsByMapID, npcId, vendorName, locData, playerFaction)
    if not locData.uiMapId or not locData.x or not locData.y or locData.x <= 0 or locData.y <= 0 then
        return
    end
    if not ShouldIncludeFaction(locData.faction, playerFaction) then
        return
    end

    local mapEntry = {
        npcId = npcId,
        npcName = vendorName,
        uiMapId = locData.uiMapId,
        x = locData.x,
        y = locData.y,
        faction = locData.faction,
    }
    InsertVendorIntoMap(vendorsByMapID, locData.uiMapId, mapEntry)

    -- Also index under parent zone for zone overlay aggregation
    local rootMapID = addon:GetZoneRootMapID(locData.uiMapId)
    if rootMapID and rootMapID ~= locData.uiMapId then
        InsertVendorIntoMap(vendorsByMapID, rootMapID, mapEntry)
    end
end

local function BuildVendorMapIndex()
    if addon.vendorMapVendorsByMapID then
        return
    end

    if not addon.vendorIndexBuilt then
        addon:BuildVendorIndex()
    end
    addon:EnsurePlayerProfessionSkillLines()

    local vendorsByMapID = {}
    local playerFaction = UnitFactionGroup("player") or "Neutral"

    for npcId, vendorEntry in pairs(addon.vendorIndex or {}) do
        if addon:ShouldShowVendorForPlayerProfessionFilter(npcId) then
            local locations = addon:GetNPCLocations(npcId)
            if locations then
                for _, locData in ipairs(locations) do
                    InsertVendorLocation(vendorsByMapID, npcId, vendorEntry.npcName, locData, playerFaction)
                end
            end
        end
    end

    for _, mapVendors in pairs(vendorsByMapID) do
        table.sort(mapVendors, function(a, b)
            return (a.npcName or "") < (b.npcName or "")
        end)
    end

    addon.vendorMapVendorsByMapID = vendorsByMapID
end

function addon:GetAllVendorMapVendors()
    BuildVendorMapIndex()
    return addon.vendorMapVendorsByMapID
end

-- Returns: owned, total, missingNames, promoOwned, promoTotal
-- owned / total  - count of ALWAYS-available decors (the ones actively on the merchant frame)
-- missingNames   - up to TOOLTIP_ITEM_LIMIT entries of {name, locked, promotional} for uncollected items
-- promoOwned / promoTotal - count of PROMO (rotating / event-gated / collab) decors; 0 for vendors without promo stock
--
-- The split lets tooltips render "Collected: X/total" + "Promo: Y/promoTotal" instead of
-- a misleading single ratio that can never be completed in one promo cycle. Callers that
-- only unpack the first three returns keep working; the trailing two are optional.
function addon:GetVendorPinProgress(npcId)
    if not npcId then
        return 0, 0, {}, 0, 0
    end

    if not addon:ShouldShowVendorForPlayerProfessionFilter(npcId) then
        return 0, 0, {}, 0, 0
    end

    local cached = addon.vendorPinProgressCache[npcId]
    if cached then
        return cached.owned, cached.total, cached.missingNames, cached.promoOwned, cached.promoTotal
    end

    local vendor = addon.vendorIndex and addon.vendorIndex[npcId]
    if not vendor or not vendor.decorIds then
        return 0, 0, {}, 0, 0
    end

    local promoSet = vendor.promotionalDecorIds
    local owned, total = 0, 0
    local promoOwned, promoTotal = 0, 0
    local missingNames = {}
    local limit = addon.CONSTANTS.VENDOR_PIN.TOOLTIP_ITEM_LIMIT

    for _, decorId in ipairs(vendor.decorIds) do
        local isPromo = promoSet and promoSet[decorId] or false
        local record = addon:ResolveRecord(decorId)
        local isOwned = record and record.isCollected

        if isPromo then
            promoTotal = promoTotal + 1
            if isOwned then promoOwned = promoOwned + 1 end
        else
            total = total + 1
            if isOwned then owned = owned + 1 end
        end

        if not isOwned and #missingNames < limit then
            local name = addon:ResolveDecorName(decorId, record)
            local achId = addon.DecorToAchievementLookup and addon.DecorToAchievementLookup[decorId]
            local isLocked = achId and not addon:IsAchievementCompleted(achId)
            missingNames[#missingNames + 1] = {
                name = name,
                locked = isLocked or false,
                promotional = isPromo,
            }
        end
    end

    addon.vendorPinProgressCache[npcId] = {
        owned = owned,
        total = total,
        missingNames = missingNames,
        promoOwned = promoOwned,
        promoTotal = promoTotal,
    }

    return owned, total, missingNames, promoOwned, promoTotal
end

function addon:InvalidateVendorPinCache()
    wipe(self.vendorPinProgressCache)
end

addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function(recordID, collectionStateChanged)
    if not collectionStateChanged then return end
    addon:InvalidateVendorPinCache()
end)

addon:RegisterInternalEvent("ACHIEVEMENT_COMPLETION_CHANGED", function()
    addon:InvalidateVendorPinCache()
end)
