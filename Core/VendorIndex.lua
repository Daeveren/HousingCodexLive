--[[
    Housing Codex - VendorIndex.lua
    Vendor-to-decor index building and hierarchy management
]]

local _, addon = ...
local L = addon.L

local ZONE_TO_EXPANSION = addon.ZONE_TO_EXPANSION

-- Shared expansion order; module-specific unknowns fall back to 0 at usage sites
local EXPANSION_ORDER = addon.CONSTANTS.EXPANSION_ORDER
local SOURCE_PREFIX_COLOR = "|cffeac100"
local COLOR_RESET = "|r"

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

-- Display name -> class file token for RAID_CLASS_COLORS lookup
local CLASS_FILE_TOKENS = {
    ["Death Knight"] = "DEATHKNIGHT",
    ["Demon Hunter"] = "DEMONHUNTER",
    ["Druid"] = "DRUID",
    ["Hunter"] = "HUNTER",
    ["Mage"] = "MAGE",
    ["Monk"] = "MONK",
    ["Paladin"] = "PALADIN",
    ["Priest"] = "PRIEST",
    ["Rogue"] = "ROGUE",
    ["Shaman"] = "SHAMAN",
    ["Warlock"] = "WARLOCK",
    ["Warrior"] = "WARRIOR",
}

-- Housing zones (faction-specific player housing areas)
local HOUSING_ZONES = {
    ["Founder's Point"] = "Alliance",
    ["Razorwind Shores"] = "Horde",
}

local PROFESSION_ENUM = Enum and Enum.Profession or {}

local SILVERMOON_PROFESSION_VENDOR_ENUMS = {
    [243359] = PROFESSION_ENUM.Alchemy,        -- Melaris
    [241451] = PROFESSION_ENUM.Blacksmithing,  -- Eriden
    [257914] = PROFESSION_ENUM.Cooking,        -- Quelis
    [243350] = PROFESSION_ENUM.Enchanting,     -- Lyna
    [241453] = PROFESSION_ENUM.Engineering,    -- Yatheon
    [256026] = PROFESSION_ENUM.Herbalism,      -- Irodalmin
    [243531] = PROFESSION_ENUM.Leatherworking, -- Zaralda
    [243555] = PROFESSION_ENUM.Inscription,    -- Lelorian
    [243353] = PROFESSION_ENUM.Tailoring,      -- Deynna
}

local silvermoonProfessionVendorSkillLines = {}
local silvermoonProfessionRequirementsReady = false
local learnedProfessionSkillLines = nil
local learnedProfessionSkillLinesReady = false

local function IsUsableNumber(value)
    return type(value) == "number"
        and not (type(issecretvalue) == "function" and issecretvalue(value))
end

local function SetsEqual(a, b)
    if a == b then return true end
    if not a or not b then return false end

    for key, value in pairs(a) do
        if b[key] ~= value then return false end
    end
    for key, value in pairs(b) do
        if a[key] ~= value then return false end
    end
    return true
end

local function CopyItemCosts(itemCosts)
    if not itemCosts then return nil end

    local copy = {}
    for decorId, cost in pairs(itemCosts) do
        copy[decorId] = cost
    end
    return copy
end

local function ResolveProfessionSkillLine(profession)
    if profession == nil then return nil end
    if not (C_TradeSkillUI and C_TradeSkillUI.GetProfessionSkillLineID) then return nil end

    local ok, skillLineID = pcall(C_TradeSkillUI.GetProfessionSkillLineID, profession)
    if ok and IsUsableNumber(skillLineID) then
        return skillLineID
    end
    return nil
end

local function BuildSilvermoonProfessionVendorSkillLines()
    local result = {}
    for npcId, profession in pairs(SILVERMOON_PROFESSION_VENDOR_ENUMS) do
        local skillLineID = ResolveProfessionSkillLine(profession)
        if not skillLineID then
            return nil
        end
        result[npcId] = skillLineID
    end
    return result
end

local function AddProfessionSkillLine(skillLines, professionIndex)
    if professionIndex == nil then return true end
    if type(issecretvalue) == "function" and issecretvalue(professionIndex) then return false end
    if type(professionIndex) ~= "number" then return false end
    if type(GetProfessionInfo) ~= "function" then return false end

    local ok, _, _, _, _, _, _, skillLine = pcall(GetProfessionInfo, professionIndex)
    if not ok or not IsUsableNumber(skillLine) then
        return false
    end

    skillLines[skillLine] = true
    return true
end

local function BuildPlayerProfessionSkillLines()
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return nil
    end

    local ok, prof1, prof2, arch, fish, cook = pcall(GetProfessions)
    if not ok then return nil end

    local skillLines = {}
    if not AddProfessionSkillLine(skillLines, prof1) then return nil end
    if not AddProfessionSkillLine(skillLines, prof2) then return nil end
    if not AddProfessionSkillLine(skillLines, arch) then return nil end
    if not AddProfessionSkillLine(skillLines, fish) then return nil end
    if not AddProfessionSkillLine(skillLines, cook) then return nil end
    return skillLines
end

-- Runtime data structures
addon.vendorIndex = {}
addon.vendorHierarchy = {}
addon.vendorIndexBuilt = false
addon.vendorZoneCache = {}
addon.vendorExpansionProgressCache = {}
addon.vendorZoneProgressCache = {}
addon.vendorZoneToMapId = {}  -- zoneName -> uiMapId (for localized zone name lookup)

local function FormatVendorSourceText(vendorName)
    if not vendorName or vendorName == "" then return nil end

    local label = L["PROGRESS_SOURCE_VENDORS"]
    if label and label ~= "" then
        return SOURCE_PREFIX_COLOR .. label .. ": " .. COLOR_RESET .. vendorName
    end

    return vendorName
end

local function GetVendorDecorCost(vendorData, decorId)
    local itemCosts = vendorData and vendorData.itemCosts
    if itemCosts then
        return itemCosts[decorId], itemCosts[decorId] ~= nil
    end
    return vendorData and vendorData.cost, false
end

local function BuildVendorDecorDetails(vendorData, zoneName, decorId)
    local cost, hasItemCost = GetVendorDecorCost(vendorData, decorId)
    local promoSet = addon.VendorPromotionalDecorIds
        and addon.VendorPromotionalDecorIds[vendorData.npcId]

    return {
        contextKind = "default",
        npcId = vendorData.npcId,
        vendorName = vendorData.npcName,
        zoneName = zoneName,
        cost = cost,
        currencyName = vendorData.currencyName,
        isPromotional = promoSet and promoSet[decorId] == true,
        hasItemCost = hasItemCost,
    }
end

local function IsBetterVendorDecorDetails(candidate, current)
    if not current then return true end

    if candidate.isPromotional ~= current.isPromotional then
        return not candidate.isPromotional
    end

    local candidateHasCost = candidate.cost ~= nil
    local currentHasCost = current.cost ~= nil
    if candidateHasCost ~= currentHasCost then
        return candidateHasCost
    end

    if candidate.hasItemCost ~= current.hasItemCost then
        return candidate.hasItemCost
    end

    return (candidate.vendorName or "") < (current.vendorName or "")
end

function addon:BuildVendorSourceLookup()
    if not self.VendorSourceData then return end

    local vendorNamesByDecor = {}
    local vendorDetailsByDecor = {}
    self.decorVendorSourceText = self.decorVendorSourceText or {}
    self.decorVendorDetails = self.decorVendorDetails or {}
    wipe(self.decorVendorSourceText)
    wipe(self.decorVendorDetails)

    for _, zones in pairs(self.VendorSourceData) do
        for zoneName, vendors in pairs(zones) do
            for _, vendorData in ipairs(vendors) do
                local vendorName = vendorData.npcName
                if vendorName and vendorData.decorIds then
                    for _, decorId in ipairs(vendorData.decorIds) do
                        vendorNamesByDecor[decorId] = vendorNamesByDecor[decorId] or {}
                        vendorNamesByDecor[decorId][vendorName] = true

                        local details = BuildVendorDecorDetails(vendorData, zoneName, decorId)
                        if IsBetterVendorDecorDetails(details, vendorDetailsByDecor[decorId]) then
                            vendorDetailsByDecor[decorId] = details
                        end
                    end
                end
            end
        end
    end

    for decorId, vendorNames in pairs(vendorNamesByDecor) do
        local sortedNames = {}
        for vendorName in pairs(vendorNames) do
            sortedNames[#sortedNames + 1] = vendorName
        end
        table.sort(sortedNames)
        local details = vendorDetailsByDecor[decorId]
        self.decorVendorDetails[decorId] = details
        self.decorVendorSourceText[decorId] = FormatVendorSourceText(
            details and details.vendorName or sortedNames[1]
        )
    end
end

function addon:GetVendorSourceText(decorId)
    return self.decorVendorSourceText and self.decorVendorSourceText[decorId]
end

function addon:GetDefaultVendorDecorDetails(decorId)
    if not decorId then return nil end
    if not self.decorVendorDetails and self.BuildVendorSourceLookup then
        self:BuildVendorSourceLookup()
    end

    local details = self.decorVendorDetails and self.decorVendorDetails[decorId]
    if not details then return nil end

    return {
        contextKind = details.contextKind,
        npcId = details.npcId,
        vendorName = addon:GetLocalizedNPCName(details.npcId, details.vendorName)
            or details.vendorName
            or addon.L["VENDOR_UNKNOWN"],
        zoneName = details.zoneName and addon:GetLocalizedVendorZoneName(details.zoneName) or nil,
        cost = details.cost,
        currencyName = details.currencyName,
        isPromotional = details.isPromotional,
    }
end

function addon:EnrichVendorSourceText()
    if not self.decorVendorSourceText then return 0 end

    local enriched = 0
    for decorId, sourceText in pairs(self.decorVendorSourceText) do
        local primary = self.decorRecords and self.decorRecords[decorId]
        if primary and (not primary.sourceText or primary.sourceText == "") then
            primary.sourceText = sourceText
            enriched = enriched + 1
        end
        local fallback = self.fallbackRecords and self.fallbackRecords[decorId]
        if fallback and fallback ~= false and (not fallback.sourceText or fallback.sourceText == "") then
            fallback.sourceText = sourceText
            enriched = enriched + 1
        end
    end

    if enriched > 0 then
        self.byWordIndexBuilt = false
    end

    return enriched
end

function addon:GetClassHallAnnotation(zoneName)
    return zoneName and CLASS_HALL_ZONES[zoneName]
end

function addon:GetHousingZoneAnnotation(zoneName)
    return zoneName and HOUSING_ZONES[zoneName]
end

local function ResolveClassColor(className)
    local token = className and CLASS_FILE_TOKENS[className]
    return token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
end

-- Returns "|cffRRGGBB" escape code for the given class display name, or gray fallback
function addon:GetClassColorCode(className)
    local color = ResolveClassColor(className)
    if color then
        return string.format("|cff%02x%02x%02x", math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255))
    end
    return "|cff888888"
end

-- Returns r, g, b for the given class display name (for GameTooltip:AddLine), or gray fallback
function addon:GetClassColorRGB(className)
    local color = ResolveClassColor(className)
    if color then
        return color.r, color.g, color.b
    end
    return 0.6, 0.6, 0.6
end

-- Returns the localized class display name for a given English class name
function addon:GetLocalizedClassName(englishClassName)
    local token = englishClassName and CLASS_FILE_TOKENS[englishClassName]
    if not token then return englishClassName end
    return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token] or englishClassName
end

-- Returns the localized faction name for a given English faction name
function addon:GetLocalizedFactionName(englishFaction)
    if englishFaction == "Alliance" then
        return FACTION_ALLIANCE or englishFaction
    elseif englishFaction == "Horde" then
        return FACTION_HORDE or englishFaction
    end
    return englishFaction
end

function addon:InvalidateVendorVisibilityCaches()
    self.vendorMapVendorsByMapID = nil
    if self.InvalidateVendorPinCache then
        self:InvalidateVendorPinCache()
    end
    if self.InvalidateZoneDecorCache then
        self:InvalidateZoneDecorCache()
        self:FireEvent(self.Events.ZONE_DECOR_CACHE_INVALIDATED)
    end
end

function addon:RefreshSilvermoonProfessionVendorRequirements()
    local skillLines = BuildSilvermoonProfessionVendorSkillLines()
    if not skillLines then
        local changed = silvermoonProfessionRequirementsReady
        wipe(silvermoonProfessionVendorSkillLines)
        silvermoonProfessionRequirementsReady = false
        return changed
    end

    local changed = not silvermoonProfessionRequirementsReady
        or not SetsEqual(silvermoonProfessionVendorSkillLines, skillLines)

    wipe(silvermoonProfessionVendorSkillLines)
    for npcId, skillLineID in pairs(skillLines) do
        silvermoonProfessionVendorSkillLines[npcId] = skillLineID
    end
    silvermoonProfessionRequirementsReady = true
    return changed
end

function addon:RefreshPlayerProfessionSkillLines()
    local skillLines = BuildPlayerProfessionSkillLines()
    if not skillLines then
        local changed = learnedProfessionSkillLinesReady
        learnedProfessionSkillLines = nil
        learnedProfessionSkillLinesReady = false
        return changed
    end

    local changed = not learnedProfessionSkillLinesReady
        or not SetsEqual(learnedProfessionSkillLines, skillLines)

    learnedProfessionSkillLines = skillLines
    learnedProfessionSkillLinesReady = true
    return changed
end

function addon:EnsurePlayerProfessionSkillLines()
    if learnedProfessionSkillLinesReady then
        return false
    end

    local changed = self:RefreshPlayerProfessionSkillLines()
    if changed then
        self:InvalidateVendorVisibilityCaches()
    end
    return changed
end

function addon:RefreshVendorProfessionVisibilityState(notify)
    local requirementsChanged = self:RefreshSilvermoonProfessionVendorRequirements()
    local professionsChanged = self:RefreshPlayerProfessionSkillLines()
    if requirementsChanged or professionsChanged then
        self:InvalidateVendorVisibilityCaches()
        if notify then
            self:FireEvent(self.Events.PLAYER_PROFESSIONS_CHANGED)
        end
    end
end

function addon:ShouldShowVendorForPlayerProfessionFilter(npcId)
    if not npcId then return true end

    local settings = self.db and self.db.settings
    if settings and settings.onlyShowLearnedSilvermoonProfessionVendors == false then
        return true
    end

    if not SILVERMOON_PROFESSION_VENDOR_ENUMS[npcId] then
        return true
    end

    if not silvermoonProfessionRequirementsReady or not learnedProfessionSkillLinesReady then
        return true
    end

    local requiredSkillLine = silvermoonProfessionVendorSkillLines[npcId]
    if not requiredSkillLine then
        return true
    end

    return learnedProfessionSkillLines[requiredSkillLine] == true
end

function addon:BuildVendorIndex()
    if not self.VendorSourceData then
        self:Debug("Cannot build vendor index: VendorSourceData not loaded")
        return
    end

    local startTime = debugprofilestop()

    self:BuildVendorSourceLookup()
    wipe(self.vendorIndex)
    wipe(self.vendorHierarchy)
    wipe(self.vendorZoneCache)
    wipe(self.vendorExpansionProgressCache)
    wipe(self.vendorZoneProgressCache)
    wipe(self.vendorZoneToMapId)
    self.vendorMapVendorsByMapID = nil
    self:InvalidateVendorPinCache()
    if self.Filters then
        self.Filters.currencyLookupBuilt = false
        self.Filters.decorCurrencyKeys = nil
        self.Filters.currencyFilterKeys = nil
        self.Filters.currencyFilterKeySet = nil
    end

    self.PromotionalDecorIds = self.PromotionalDecorIds or {}
    wipe(self.PromotionalDecorIds)

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
                        -- promotionalDecorIds: set of decorIds this vendor sells only during
                        -- rotating promo / event cycles (Diablo/Fanta/Pinterest collabs, holiday
                        -- items, etc.). Populated from addon.VendorPromotionalDecorIds when the
                        -- scraper emitted it; nil for vendors with no rotated stock. Consumed by
                        -- GetVendorPinProgress to split tooltip counts into active-vs-rotated.
                        local promoSet = addon.VendorPromotionalDecorIds
                            and addon.VendorPromotionalDecorIds[npcId]
                        vendorEntry = {
                            npcId = npcId,
                            npcName = vendorData.npcName,
                            cost = vendorData.cost,
                            currencyName = vendorData.currencyName,
                            itemCosts = CopyItemCosts(vendorData.itemCosts),
                            decorIds = {},
                            decorIdSet = {},
                            promotionalDecorIds = promoSet,
                        }
                        self.vendorIndex[npcId] = vendorEntry
                        vendorCount = vendorCount + 1
                    end

                    -- Merge itemCosts from subsequent zone entries for same vendor
                    if vendorData.itemCosts and not vendorEntry.itemCosts then
                        vendorEntry.itemCosts = CopyItemCosts(vendorData.itemCosts)
                    elseif vendorData.itemCosts and vendorEntry.itemCosts then
                        for did, c in pairs(vendorData.itemCosts) do
                            if not vendorEntry.itemCosts[did] then
                                vendorEntry.itemCosts[did] = c
                            end
                        end
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
                        itemCosts = vendorData.itemCosts,
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

    if self.NPCLocationData then
        for npcId, zoneInfo in pairs(self.vendorZoneCache) do
            if zoneInfo.zoneName and not self.vendorZoneToMapId[zoneInfo.zoneName] then
                local locData = self.NPCLocationData[npcId]
                if locData then
                    local isMultiLoc = type(locData[1]) == "table"
                    -- Skip roaming vendors (3+ locations) — their zone names are descriptive
                    -- and the first location's mapId would misrepresent the zone for localization
                    if not (isMultiLoc and #locData > 2) then
                        local entry = isMultiLoc and locData[1] or locData
                        if entry.uiMapId then
                            self.vendorZoneToMapId[zoneInfo.zoneName] = entry.uiMapId
                        end
                    end
                end
            end
        end
    end

    -- Flat promo-decor set: decorId -> true when any vendor sells it as promo stock.
    -- Sidecar to VendorPromotionalDecorIds[npcId][decorId]; consumers that don't care
    -- which vendor sells it (filter, tile badge, preview, progress row, search) query
    -- this set via addon:IsPromoDecor(recordID).
    for _, decorSet in pairs(addon.VendorPromotionalDecorIds or {}) do
        for decorId in pairs(decorSet) do
            self.PromotionalDecorIds[decorId] = true
        end
    end

    -- Pre-resolve promo items into fallbackRecords so the Decor tab's vendor
    -- NPC-name search, Promo-only filter augmentation, and Progress "Promotional"
    -- row all surface them even while off-rotation and hidden from the native
    -- catalog searcher. ResolveRecord hits the C_HousingCatalog API once per
    -- decorId then caches; re-entry via /hc retry is free. Invalidate the word
    -- index afterwards so the next search picks up the newly resolved name and
    -- sourceText tokens. (cachedAllRecordIDs is cleared per-resolve inside
    -- ResolveRecord itself.)
    for decorId in pairs(self.PromotionalDecorIds) do
        self:ResolveRecord(decorId)
    end
    local enriched = self:EnrichVendorSourceText()
    self.byWordIndexBuilt = false

    self.vendorIndexBuilt = true
    self:InvalidateProgressCache()

    self:Debug(string.format("Built vendor index: %d vendors, %d decor items (%d sourceText enriched) in %d ms",
        vendorCount, decorCount, enriched, math.floor(debugprofilestop() - startTime)))
end

function addon:IsPromoDecor(recordID)
    return recordID ~= nil
        and self.PromotionalDecorIds ~= nil
        and self.PromotionalDecorIds[recordID] == true
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
    table.sort(zones, function(a, b)
        return self:GetLocalizedZoneName(a) < self:GetLocalizedZoneName(b)
    end)
    return zones
end

-- GetLocalizedVendorZoneName: use addon:GetLocalizedZoneName() in Localization.lua
-- Kept as a thin wrapper for backwards compatibility
function addon:GetLocalizedVendorZoneName(zoneName)
    return self:GetLocalizedZoneName(zoneName)
end

function addon:GetVendorsForZone(expansionKey, zoneName)
    local expData = self.vendorHierarchy[expansionKey]
    return expData and expData.zones[zoneName] or {}
end

function addon:GetVendorZoneCollectionProgress(expansionKey, zoneName)
    local cacheKey = expansionKey .. ":" .. zoneName
    local cached = self.vendorZoneProgressCache[cacheKey]
    if cached then return cached.owned, cached.total end

    local owned, total = self:GetVendorScopeCollectionProgress(self:GetVendorsForZone(expansionKey, zoneName), true)

    self.vendorZoneProgressCache[cacheKey] = { owned = owned, total = total }
    return owned, total
end

function addon:GetVendorExpansionCollectionProgress(expansionKey)
    local cached = self.vendorExpansionProgressCache[expansionKey]
    if cached then return cached.owned, cached.total end

    local expData = self.vendorHierarchy[expansionKey]
    if not expData then return 0, 0 end

    local vendors = {}
    for zoneName in pairs(expData.zones) do
        for _, vendor in ipairs(self:GetVendorsForZone(expansionKey, zoneName)) do
            vendors[#vendors + 1] = vendor
        end
    end
    local owned, total = self:GetVendorScopeCollectionProgress(vendors, true)

    self.vendorExpansionProgressCache[expansionKey] = { owned = owned, total = total }
    return owned, total
end

function addon:GetVendorUniqueCollectionProgress()
    local vendors = {}
    for expansionKey, expData in pairs(self.vendorHierarchy) do
        for zoneName in pairs(expData.zones) do
            for _, vendor in ipairs(self:GetVendorsForZone(expansionKey, zoneName)) do
                vendors[#vendors + 1] = vendor
            end
        end
    end

    return self:GetVendorScopeCollectionProgress(vendors, true)
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

function addon:IsVendorDecorResolvable(decorId, requireRecord)
    if self:ResolveRecord(decorId) then return true end
    if requireRecord then return false end
    if C_HousingDecor and C_HousingDecor.GetDecorIcon then
        local icon = C_HousingDecor.GetDecorIcon(decorId)
        if icon then return true end
    end
    local fallback = self.VendorItemFallback and self.VendorItemFallback[decorId]
    return fallback and fallback.name ~= nil
end

local function GetVendorPromoSet(vendorData)
    if not vendorData or not vendorData.npcId then return nil end
    return addon.VendorPromotionalDecorIds and addon.VendorPromotionalDecorIds[vendorData.npcId]
end

local function AddDecorToProgressSet(progressSet, decorId)
    if decorId and addon:ShouldDisplayDecor(decorId) then
        progressSet[decorId] = true
    end
end

local function CountDecorSet(progressSet, requireRecord)
    local owned, total = 0, 0
    for decorId in pairs(progressSet) do
        if addon:IsVendorDecorResolvable(decorId, requireRecord) then
            total = total + 1
            if addon:IsDecorCollected(decorId) then owned = owned + 1 end
        end
    end
    return owned, total
end

local function SplitVendorDecorSets(vendorData)
    local regularSet = {}
    local promoSet = {}
    local sourcePromoSet = GetVendorPromoSet(vendorData)

    for _, decorId in ipairs(vendorData and vendorData.decorIds or {}) do
        if sourcePromoSet and sourcePromoSet[decorId] then
            AddDecorToProgressSet(promoSet, decorId)
        else
            AddDecorToProgressSet(regularSet, decorId)
        end
    end

    return regularSet, promoSet
end

function addon:GetVendorCollectionProgress(vendorData)
    local regularSet, promoSet = SplitVendorDecorSets(vendorData)
    local owned, total = CountDecorSet(regularSet)
    local promoOwned, promoTotal = CountDecorSet(promoSet)

    return owned, total, promoOwned, promoTotal
end

function addon:GetVendorScopeCollectionProgress(vendors, requireRecord)
    local regularSet = {}

    for _, vendorData in ipairs(vendors or {}) do
        local vendorRegularSet = SplitVendorDecorSets(vendorData)
        for decorId in pairs(vendorRegularSet) do
            regularSet[decorId] = true
        end
    end

    return CountDecorSet(regularSet, requireRecord)
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
    wipe(addon.vendorZoneProgressCache)
end)

addon:RegisterInternalEvent(addon.Events.DECOR_VISIBILITY_CHANGED, function()
    wipe(addon.vendorExpansionProgressCache)
    wipe(addon.vendorZoneProgressCache)
end)

-- Eagerly build vendor index at data load so tooltip overlay and map pins
-- have data immediately (instead of waiting for UI to trigger lazy build)
addon:RegisterInternalEvent("DATA_LOADED", function()
    if not addon.vendorIndexBuilt then
        addon:BuildVendorIndex()
    end
    addon:BuildVendorSourceLookup()
    addon:EnrichVendorSourceText()
    addon:RefreshVendorProfessionVisibilityState(false)
end)

addon:RegisterWoWEvent("SKILL_LINES_CHANGED", function()
    addon:RefreshVendorProfessionVisibilityState(true)
end)

addon:RegisterWoWEvent("PLAYER_ENTERING_WORLD", function()
    addon:RefreshVendorProfessionVisibilityState(true)
end)

if addon.VendorSourceData then
    addon:BuildVendorSourceLookup()
end
