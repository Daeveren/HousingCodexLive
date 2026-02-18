--[[
    Housing Codex - VendorMapIndex.lua
    World map vendor pin indexing and progress caching
]]

local ADDON_NAME, addon = ...

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

        if mapInfo.mapType == Enum.UIMapType.Zone then
            zoneRootMapCache[uiMapID] = currentMapID
            return currentMapID
        end

        local parentMapID = mapInfo.parentMapID
        if not parentMapID or parentMapID == 0 or parentMapID == currentMapID then
            break
        end

        -- If parent is a Continent, current map is zone-level (stop before walking up)
        local parentInfo = C_Map.GetMapInfo(parentMapID)
        if parentInfo and parentInfo.mapType == Enum.UIMapType.Continent then
            zoneRootMapCache[uiMapID] = currentMapID
            return currentMapID
        end

        currentMapID = parentMapID
    end

    zoneRootMapCache[uiMapID] = uiMapID
    return uiMapID
end

--------------------------------------------------------------------------------
-- Shared: Find city-type child maps for a given zone (for overlay aggregation)
-- Cities have mapType=Zone (same as outdoor zones) so GetZoneRootMapID stops
-- at the city itself. This discovers city children to merge into parent zone.
--------------------------------------------------------------------------------
local cityChildrenCache = {}

function addon:GetCityChildMapIDs(zoneMapID)
    if not zoneMapID then return nil end
    local cached = cityChildrenCache[zoneMapID]
    if cached ~= nil then return cached or nil end

    -- GetMapChildrenInfo has MayReturnNothing — nil-guard required
    local children = C_Map.GetMapChildrenInfo(zoneMapID)
    if not children then
        cityChildrenCache[zoneMapID] = false
        return nil
    end

    local cityChildren
    for _, childInfo in ipairs(children) do
        if childInfo.mapID and bit.band(childInfo.flags, Enum.UIMapFlag.IsCityMap) ~= 0 then
            if not cityChildren then cityChildren = {} end
            cityChildren[#cityChildren + 1] = childInfo.mapID
        end
    end

    cityChildrenCache[zoneMapID] = cityChildren or false
    return cityChildren
end

local function ShouldIncludeFaction(vendorFaction, playerFaction)
    if not vendorFaction or vendorFaction == "" or vendorFaction == "Neutral" then
        return true
    end
    return vendorFaction == playerFaction
end

local function BuildVendorMapIndex()
    if addon.vendorMapVendorsByMapID then
        return
    end

    if not addon.vendorIndexBuilt then
        addon:BuildVendorIndex()
    end

    local vendorsByMapID = {}
    local playerFaction = UnitFactionGroup("player")

    for npcId, vendorEntry in pairs(addon.vendorIndex or {}) do
        local locData = addon:GetNPCLocation(npcId)
        if locData and locData.uiMapId and locData.x and locData.y and locData.x > 0 and locData.y > 0 then
            if ShouldIncludeFaction(locData.faction, playerFaction) then
                local mapVendors = vendorsByMapID[locData.uiMapId]
                if not mapVendors then
                    mapVendors = {}
                    vendorsByMapID[locData.uiMapId] = mapVendors
                end

                local mapEntry = {
                    npcId = npcId,
                    npcName = vendorEntry.npcName,
                    uiMapId = locData.uiMapId,
                    x = locData.x,
                    y = locData.y,
                    faction = locData.faction,
                }
                table.insert(mapVendors, mapEntry)

                -- Also index under parent zone for zone overlay aggregation
                local rootMapID = addon:GetZoneRootMapID(locData.uiMapId)
                if rootMapID and rootMapID ~= locData.uiMapId then
                    local rootVendors = vendorsByMapID[rootMapID]
                    if not rootVendors then
                        rootVendors = {}
                        vendorsByMapID[rootMapID] = rootVendors
                    end
                    table.insert(rootVendors, mapEntry)
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

function addon:GetVendorPinProgress(npcId)
    if not npcId then
        return 0, 0, {}
    end

    local cached = addon.vendorPinProgressCache[npcId]
    if cached then
        return cached.owned, cached.total, cached.missingNames
    end

    local vendor = addon.vendorIndex and addon.vendorIndex[npcId]
    if not vendor or not vendor.decorIds then
        return 0, 0, {}
    end

    local owned = 0
    local total = #vendor.decorIds
    local missingNames = {}
    local limit = addon.CONSTANTS.VENDOR_PIN.TOOLTIP_ITEM_LIMIT

    for _, decorId in ipairs(vendor.decorIds) do
        local record = addon:GetRecord(decorId)
        if record and record.isCollected then
            owned = owned + 1
        elseif #missingNames < limit then
            missingNames[#missingNames + 1] = addon:ResolveDecorName(decorId, record)
        end
    end

    addon.vendorPinProgressCache[npcId] = {
        owned = owned,
        total = total,
        missingNames = missingNames,
    }

    return owned, total, missingNames
end

function addon:InvalidateVendorPinCache()
    wipe(self.vendorPinProgressCache)
end

addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
    addon:InvalidateVendorPinCache()
end)
