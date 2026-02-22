--[[
    Housing Codex - VendorIndex.lua
    Vendor-to-decor index building and hierarchy management
]]

local ADDON_NAME, addon = ...

local ZONE_TO_EXPANSION = addon.ZONE_TO_EXPANSION

-- Shared expansion order; module-specific unknowns fall back to 0 at usage sites
local EXPANSION_ORDER = addon.CONSTANTS.EXPANSION_ORDER

-- Legion Class Hall zone annotations
local CLASS_HALL_ZONES = {
    -- Death Knight
    ["Acherus: The Ebon Hold"] = "Death Knight",
    ["Acherus: Ebon Hold"] = "Death Knight",
    -- Demon Hunter
    ["The Fel Hammer"] = "Demon Hunter",
    ["Mardum, the Shattered Abyss"] = "Demon Hunter",
    -- Druid
    ["The Dreamgrove"] = "Druid",
    -- Hunter
    ["Trueshot Lodge"] = "Hunter",
    -- Mage
    ["Hall of the Guardian"] = "Mage",
    -- Monk
    ["The Wandering Isle"] = "Monk",
    ["Mandori Village"] = "Monk",
    -- Paladin
    ["Sanctum of Light"] = "Paladin",
    -- Priest
    ["Netherlight Temple"] = "Priest",
    -- Rogue
    ["The Hall of Shadows"] = "Rogue",
    -- Shaman
    ["The Maelstrom"] = "Shaman",
    ["The Heart of Azeroth"] = "Shaman",
    -- Warlock
    ["Dreadscar Rift"] = "Warlock",
    ["Niskara"] = "Warlock",
    -- Warrior
    ["Skyhold"] = "Warrior",
}

-- Housing zones (faction-specific player housing areas)
local HOUSING_ZONES = {
    ["Founder's Point"] = "Alliance",
    ["Razorwind Shores"] = "Horde",
}

-- Runtime data structures
addon.vendorIndex = {}
addon.vendorHierarchy = {}
addon.vendorIndexBuilt = false
addon.vendorZoneCache = {}
addon.vendorExpansionProgressCache = {}

function addon:GetExpansionForVendorZone(zoneName)
    return zoneName and ZONE_TO_EXPANSION[zoneName] or "VENDORS_UNKNOWN_EXPANSION"
end

function addon:GetClassHallAnnotation(zoneName)
    return zoneName and CLASS_HALL_ZONES[zoneName]
end

function addon:GetHousingZoneAnnotation(zoneName)
    return zoneName and HOUSING_ZONES[zoneName]
end

function addon:BuildVendorIndex()
    if not self.VendorSourceData then
        self:Debug("Cannot build vendor index: VendorSourceData not loaded")
        return
    end

    local startTime = debugprofilestop()

    wipe(self.vendorIndex)
    wipe(self.vendorHierarchy)
    wipe(self.vendorZoneCache)
    wipe(self.vendorExpansionProgressCache)
    self.vendorMapVendorsByMapID = nil

    local vendorCount, decorCount = 0, 0

    for sourceExpansionKey, zones in pairs(self.VendorSourceData) do
        for zoneName, vendors in pairs(zones) do
            -- Use expansion from VendorSourceData if valid, otherwise fall back to zone mapping
            local expansionKey = EXPANSION_ORDER[sourceExpansionKey] and sourceExpansionKey
                or ZONE_TO_EXPANSION[zoneName]
                or "VENDORS_UNKNOWN_EXPANSION"

            if not self.vendorHierarchy[expansionKey] then
                self.vendorHierarchy[expansionKey] = {
                    order = EXPANSION_ORDER[expansionKey] or 0,
                    zones = {},
                }
            end

            if not self.vendorHierarchy[expansionKey].zones[zoneName] then
                self.vendorHierarchy[expansionKey].zones[zoneName] = {}
            end

            for _, vendorData in ipairs(vendors) do
                local npcId = vendorData.npcId
                if npcId then
                    local vendorEntry = self.vendorIndex[npcId]
                    if not vendorEntry then
                        vendorEntry = {
                            npcId = npcId,
                            npcName = vendorData.npcName,
                            cost = vendorData.cost,
                            currencyName = vendorData.currencyName,
                            decorIds = {},
                            decorIdSet = {},
                            zones = {},
                        }
                        self.vendorIndex[npcId] = vendorEntry
                        vendorCount = vendorCount + 1
                    end

                    -- Merge decor IDs using set for deduplication
                    if vendorData.decorIds then
                        for _, decorId in ipairs(vendorData.decorIds) do
                            if not vendorEntry.decorIdSet[decorId] then
                                vendorEntry.decorIdSet[decorId] = true
                                table.insert(vendorEntry.decorIds, decorId)
                                decorCount = decorCount + 1
                            end
                        end
                    end

                    vendorEntry.zones[zoneName] = true

                    if not self.vendorZoneCache[npcId] then
                        self.vendorZoneCache[npcId] = {
                            zoneName = zoneName,
                            expansionKey = expansionKey,
                        }
                    end

                    table.insert(self.vendorHierarchy[expansionKey].zones[zoneName], {
                        npcId = npcId,
                        npcName = vendorData.npcName,
                        cost = vendorData.cost,
                        currencyName = vendorData.currencyName,
                        decorIds = vendorData.decorIds or {},
                    })
                end
            end
        end
    end

    -- Sort vendors within each zone by name
    for _, expData in pairs(self.vendorHierarchy) do
        for _, zoneVendors in pairs(expData.zones) do
            table.sort(zoneVendors, function(a, b)
                return (a.npcName or "") < (b.npcName or "")
            end)
        end
    end

    -- Clean up temporary dedup sets
    for _, vendorEntry in pairs(self.vendorIndex) do
        vendorEntry.decorIdSet = nil
    end

    self.vendorIndexBuilt = true

    self:Debug(string.format("Built vendor index: %d vendors, %d decor items in %d ms",
        vendorCount, decorCount, math.floor(debugprofilestop() - startTime)))
end

function addon:GetSortedVendorExpansions()
    local expansions = {}
    for expansionKey in pairs(self.vendorHierarchy) do
        table.insert(expansions, expansionKey)
    end
    table.sort(expansions, function(a, b)
        return (EXPANSION_ORDER[a] or 0) > (EXPANSION_ORDER[b] or 0)
    end)
    return expansions
end

function addon:GetSortedVendorZones(expansionKey)
    local expData = self.vendorHierarchy[expansionKey]
    if not expData then return {} end

    local zones = {}
    for zoneName in pairs(expData.zones) do
        table.insert(zones, zoneName)
    end
    table.sort(zones)
    return zones
end

function addon:GetVendorsForZone(expansionKey, zoneName)
    local expData = self.vendorHierarchy[expansionKey]
    return expData and expData.zones[zoneName] or {}
end

function addon:GetVendorCollectionProgress(npcId)
    local vendor = self.vendorIndex[npcId]
    if not vendor then return 0, 0 end

    local owned, total = 0, #vendor.decorIds
    for _, decorId in ipairs(vendor.decorIds) do
        local record = self:ResolveRecord(decorId)
        if record and record.isCollected then
            owned = owned + 1
        end
    end
    return owned, total
end

function addon:GetVendorZoneCollectionProgress(expansionKey, zoneName)
    local owned, total = 0, 0
    for _, vendor in ipairs(self:GetVendorsForZone(expansionKey, zoneName)) do
        for _, decorId in ipairs(vendor.decorIds) do
            total = total + 1
            local record = self:ResolveRecord(decorId)
            if record and record.isCollected then
                owned = owned + 1
            end
        end
    end
    return owned, total
end

function addon:GetVendorExpansionCollectionProgress(expansionKey)
    local cached = self.vendorExpansionProgressCache[expansionKey]
    if cached then return cached.owned, cached.total end

    local expData = self.vendorHierarchy[expansionKey]
    if not expData then return 0, 0 end

    local owned, total = 0, 0
    for zoneName in pairs(expData.zones) do
        local zOwned, zTotal = self:GetVendorZoneCollectionProgress(expansionKey, zoneName)
        owned, total = owned + zOwned, total + zTotal
    end

    self.vendorExpansionProgressCache[expansionKey] = { owned = owned, total = total }
    return owned, total
end

function addon:GetVendorCount()
    local count = 0
    for _ in pairs(self.vendorIndex) do
        count = count + 1
    end
    return count
end

function addon:IsDecorCollected(decorId)
    local record = self:ResolveRecord(decorId)
    return record and record.isCollected or false
end

function addon:GetNPCLocations(npcId)
    local locData = self.NPCLocationData and self.NPCLocationData[npcId]
    if not locData then return nil end
    if type(locData[1]) == "table" then return locData end  -- Array format (multi-location)
    return { locData }  -- Wrap single location as array
end

function addon:GetNPCLocation(npcId)
    local locations = self:GetNPCLocations(npcId)
    if not locations then return nil end
    if #locations == 1 then return locations[1] end
    -- Multi-location: prefer player faction match, then neutral, then first
    local playerFaction = UnitFactionGroup("player") or "Neutral"
    local neutral = nil
    for _, loc in ipairs(locations) do
        if loc.faction == playerFaction then return loc end
        if not loc.faction then neutral = neutral or loc end
    end
    return neutral or locations[1]
end

function addon:GetVendorFaction(npcId)
    local locData = self:GetNPCLocation(npcId)
    return locData and locData.faction
end

addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
    wipe(addon.vendorExpansionProgressCache)
end)
