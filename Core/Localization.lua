--[[
    Housing Codex - Localization.lua
    Locale detection and string table management
]]

local _, addon = ...

-- Safety net: missing L["KEY"] returns the key name itself (debug aid)
setmetatable(addon.L, { __index = function(_, key) return key end })

-- Game entity name overrides for non-English clients (drop sources, vendor names, etc.)
-- Populated by locale files (e.g., frFR.lua). English fallback is the original name.
addon.sourceNameLocale = {}

-- Manual quest title overrides for quests without quest IDs (cannot use C_QuestLog API)
-- Populated by locale files. English fallback is the original name.
addon.questTitleLocale = {}

function addon:GetLocalizedSourceName(name)
    if not name then return name end
    return self.sourceNameLocale[name] or name
end

-- Vendor fallback category localization
-- Maps English category strings from VendorItemFallback to L["KEY"] entries
local VENDOR_CAT_KEYS = {
    ["Accents"] = "VENDOR_CAT_ACCENTS",
    ["Functional"] = "VENDOR_CAT_FUNCTIONAL",
    ["Furnishings"] = "VENDOR_CAT_FURNISHINGS",
    ["Lighting"] = "VENDOR_CAT_LIGHTING",
    ["Miscellaneous"] = "VENDOR_CAT_MISCELLANEOUS",
    ["Nature"] = "VENDOR_CAT_NATURE",
    ["Structural"] = "VENDOR_CAT_STRUCTURAL",
    ["Uncategorized"] = "VENDOR_CAT_UNCATEGORIZED",
}

function addon:GetLocalizedCategory(englishCategory)
    if not englishCategory then return englishCategory end
    local key = VENDOR_CAT_KEYS[englishCategory]
    return key and self.L[key] or englishCategory
end

--------------------------------------------------------------------------------
-- Currency name localization
-- Uses C_CurrencyInfo.GetCurrencyInfo() with known currency IDs to resolve
-- English scraped currency names to locale-aware names.
-- Positive results cached. Negative results not cached (MayReturnNothing).
--------------------------------------------------------------------------------
local CURRENCY_NAME_TO_ID = {
    ["Ancient Mana"] = 1155,
    ["Apexis Crystal"] = 823,
    ["Brimming Arcana"] = 3379,
    ["Bronze"] = 2778,
    ["Community Coupons"] = 3363,
    ["Dragon Isles Supplies"] = 2003,
    ["Echoes of Ny'alotha"] = 1803,
    ["Elemental Overflow"] = 2118,
    ["Garrison Resources"] = 824,
    ["Honor"] = 1792,
    ["Kej"] = 3056,
    ["Mysterious Fragment"] = 2657,
    ["Order Resources"] = 1220,
    ["Remnant of Anguish"] = 3089,
    ["Reservoir Anima"] = 1813,
    ["Resonance Crystals"] = 2815,
    ["Seafarer's Dubloon"] = 1710,
    ["Stygia"] = 1767,
    ["Twilight's Blade Insignia"] = 3319,
    ["Unalloyed Abundance"] = 3377,
    ["Voidlight Marl"] = 3316,
    ["War Resources"] = 1560,
    -- Note: "Mark of Honor" is an item (itemID 137642), not a currency.
    -- C_CurrencyInfo.GetCurrencyInfo cannot resolve it. Needs C_Item path or manual locale entries.
}

local currencyNameCache = {}  -- englishName -> localized name (positive only)

function addon:GetLocalizedCurrencyName(englishName)
    if not englishName then return englishName end

    local cached = currencyNameCache[englishName]
    if cached then return cached end

    local currencyID = CURRENCY_NAME_TO_ID[englishName]
    if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info and info.name and info.name ~= "" then
            currencyNameCache[englishName] = info.name
            return info.name
        end
    end

    -- No localization available -- return English name without caching
    return englishName
end

--------------------------------------------------------------------------------
-- Zone name localization
-- Resolves English scraper zone names to locale-aware names via C_Map.GetMapInfo.
-- Two mapID sources: vendorZoneToMapId (dynamic, from NPCLocationData) and
-- ZONE_TO_MAP_ID (static, for quest-only zones with no vendor NPC data).
-- Works for all tabs (quests, vendors, zone overlay).
--
-- Only positive results are cached. Negative results are NOT cached so that
-- lookups succeed after vendorZoneToMapId is populated (e.g., initial load
-- timing, /hc retry). The uncached path is two table lookups -- negligible.
--------------------------------------------------------------------------------
local zoneNameCache = {}  -- englishZoneName -> localized name (positive only)

-- Static mapIDs for zones that have no vendor NPC location data (quest-only zones)
-- Source: WoW uiMapID values from C_Map.GetMapChildrenInfo traversal
local ZONE_TO_MAP_ID = {
    ["Azj-Kahet"] = 2255,
    ["Blasted Lands"] = 17,
    ["Drustvar"] = 896,
    ["Dustwallow Marsh"] = 70,
    ["Elwynn Forest"] = 37,
    ["Emerald Dream"] = 2200,
    ["Eredath"] = 882,
    ["Felwood"] = 77,
    ["Frostfire Ridge"] = 525,
    ["Gilneas"] = 217,
    ["Loch Modan"] = 48,
    ["Mulgore"] = 7,
    ["Nagrand"] = 550,
    ["Northshire"] = 425,
    ["Shadowmoon Valley"] = 539,
    ["Stormheim"] = 634,
    ["The Azure Span"] = 2024,
    ["Vol'dun"] = 864,
    ["Westfall"] = 52,
    ["Zuldazar"] = 862,
    -- Note: "The Great Sea" and "Manaforge Omega" lack standalone uiMapIDs.
    -- They need manual locale translations or in-game mapID verification.
}

-- Resolve a zone name to a uiMapID from either vendor data or the static table
local function getMapIdForZone(self, zoneName)
    return (self.vendorZoneToMapId and self.vendorZoneToMapId[zoneName])
        or ZONE_TO_MAP_ID[zoneName]
end

-- Resolve a uiMapID to a localized zone name via C_Map
local function getLocalizedNameFromMapId(mapId)
    if not mapId then return nil end
    local mapInfo = C_Map and C_Map.GetMapInfo(mapId)
    return mapInfo and mapInfo.name
end

function addon:GetLocalizedZoneName(englishZoneName)
    if not englishZoneName then return englishZoneName end

    local cached = zoneNameCache[englishZoneName]
    if cached then return cached end

    -- Try direct mapID lookup
    local localizedName = getLocalizedNameFromMapId(getMapIdForZone(self, englishZoneName))
    if localizedName then
        zoneNameCache[englishZoneName] = localizedName
        return localizedName
    end

    -- For compound names like "Mudsprocket, Dustwallow Marsh" or "The Bazaar, Silvermoon City",
    -- try localizing both the parent zone (after the last comma) and the subzone prefix
    local prefix, parentZone = englishZoneName:match("^(.+),%s*([^,]+)$")
    if parentZone then
        local localizedParent = getLocalizedNameFromMapId(getMapIdForZone(self, parentZone))
        local localizedPrefix = getLocalizedNameFromMapId(getMapIdForZone(self, prefix))
        if localizedParent then
            local displayPrefix = localizedPrefix or prefix
            local localized = displayPrefix .. ", " .. localizedParent
            zoneNameCache[englishZoneName] = localized
            return localized
        end
    end

    -- No mapID available -- return English name without caching
    return englishZoneName
end

--------------------------------------------------------------------------------
-- Profession name localization
-- Uses C_TradeSkillUI.GetTradeSkillDisplayName() with known base skill line IDs
-- to resolve English profession names to locale-aware names.
-- Only positive results are cached (same rationale as zone names).
--------------------------------------------------------------------------------
local PROFESSION_SKILL_LINE_IDS = {
    ["Alchemy"] = 171,
    ["Blacksmithing"] = 164,
    ["Cooking"] = 185,
    ["Enchanting"] = 333,
    ["Engineering"] = 202,
    ["Inscription"] = 773,
    ["Jewelcrafting"] = 755,
    ["Leatherworking"] = 165,
    ["Mining"] = 186,
    ["Skinning"] = 393,
    ["Tailoring"] = 197,
    ["Fishing"] = 356,
    ["Junkyard Tinkering"] = 2720,
}

local professionNameCache = {}  -- englishName -> localized name (positive only)

function addon:GetLocalizedProfessionName(englishName)
    if not englishName then return englishName end

    local cached = professionNameCache[englishName]
    if cached then return cached end

    local skillLineID = PROFESSION_SKILL_LINE_IDS[englishName]
    if skillLineID and C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
        local displayName = C_TradeSkillUI.GetTradeSkillDisplayName(skillLineID)
        if displayName and displayName ~= "" then
            professionNameCache[englishName] = displayName
            return displayName
        end
    end

    -- No localization available -- return English name without caching
    return englishName
end

--------------------------------------------------------------------------------
-- NPC name localization
-- Uses C_TooltipInfo.GetHyperlink with a synthetic unit GUID to resolve
-- English NPC names to locale-aware names. Only vendor NPCs have npcId in our
-- data; drop sources remain under the sourceNameLocale manual system.
-- Positive results cached as the name string. RETRIEVING_DATA responses are
-- not cached, allowing natural retry on next call (220 NPCs, negligible cost).
--------------------------------------------------------------------------------
local npcNameCache = {}  -- npcID -> name string (positive results only)

function addon:GetLocalizedNPCName(npcID, fallbackName)
    if not npcID or npcID <= 0 then return fallbackName end

    local cached = npcNameCache[npcID]
    if cached then return cached end

    -- AllowedWhenUntainted: safe from normal addon code, do not call from tainted context
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return fallbackName end

    local ok, tooltipData = pcall(C_TooltipInfo.GetHyperlink, ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID))
    if not ok or not (tooltipData and tooltipData.lines) then return fallbackName end

    local name = tooltipData.lines[1] and tooltipData.lines[1].leftText
    if not name or name == "" or name == RETRIEVING_DATA then
        return fallbackName
    end

    npcNameCache[npcID] = name
    return name
end

--------------------------------------------------------------------------------
-- Skill-line label localization
-- Expansion-prefixed skill lines (e.g., "Classic Alchemy", "Midnight Cooking")
-- come from scraped English data. We split the prefix and profession, localize
-- each separately, then recombine.
--------------------------------------------------------------------------------
local SKILL_LINE_EXPANSION_PREFIXES = {
    ["Classic"]            = "EXPANSION_CLASSIC",
    ["Outland"]            = "EXPANSION_TBC",
    ["Northrend"]          = "EXPANSION_WRATH",
    ["Cataclysm"]          = "EXPANSION_CATA",
    ["Pandaria"]           = "EXPANSION_MOP",
    ["Draenor"]            = "EXPANSION_WOD",
    ["Legion"]             = "EXPANSION_LEGION",
    ["Battle for Azeroth"] = "EXPANSION_BFA",
    ["Shadowlands"]        = "EXPANSION_SL",
    ["Dragon Isles"]       = "EXPANSION_DF",
    ["Khaz Algar"]         = "EXPANSION_TWW",
    ["Midnight"]           = "EXPANSION_MIDNIGHT",
}

local skillLineCache = {}

function addon:GetLocalizedSkillLine(englishSkillLine)
    if not englishSkillLine then return englishSkillLine end

    local cached = skillLineCache[englishSkillLine]
    if cached then return cached end

    for prefix, locKey in pairs(SKILL_LINE_EXPANSION_PREFIXES) do
        if englishSkillLine:sub(1, #prefix) == prefix then
            local professionPart = englishSkillLine:sub(#prefix + 2)  -- skip prefix + space
            if professionPart ~= "" then
                local localizedExpansion = self.L[locKey]
                local localizedProfession = self:GetLocalizedProfessionName(professionPart)
                if localizedExpansion and localizedProfession then
                    local result = localizedExpansion .. " " .. localizedProfession
                    skillLineCache[englishSkillLine] = result
                    return result
                end
            end
        end
    end

    -- Unprefixed skill line (e.g., "Junkyard Tinkering") — try profession name lookup
    local localizedName = self:GetLocalizedProfessionName(englishSkillLine)
    if localizedName ~= englishSkillLine then
        skillLineCache[englishSkillLine] = localizedName
        return localizedName
    end

    return englishSkillLine
end
