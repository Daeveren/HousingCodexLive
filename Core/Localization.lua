--[[
    Housing Codex - Localization.lua
    Missing-key fallback and game-data name localization (currency, zone, profession, NPC, skill line)
]]

local _, addon = ...

-- Safety net: missing L["KEY"] returns the key name itself and reports it in debug mode.
setmetatable(addon.L, {
    __index = function(_, key)
        if addon.Debug then
            addon:Debug("Missing localization key:", key)
        end
        return key
    end,
})

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
    ["Angler Pearls"] = 3373,
    ["Apexis Crystal"] = 823,
    ["Brimming Arcana"] = 3379,
    ["Bronze"] = 2778,
    ["Community Coupons"] = 3363,
    ["Corrosive Coin"] = 3448,
    ["Dragon Isles Supplies"] = 2003,
    ["Echoes of Ny'alotha"] = 1803,
    ["Elemental Overflow"] = 2118,
    ["Garrison Resources"] = 824,
    ["Honor"] = 1792,
    ["Illusionary Coins"] = 3393,
    ["Kej"] = 3056,
    ["Luminous Dust"] = 3385,
    ["Mysterious Fragment"] = 2657,
    ["Order Resources"] = 1220,
    ["Remnant of Anguish"] = 3392,
    ["Reservoir Anima"] = 1813,
    ["Resonance Crystals"] = 2815,
    ["Seafarer's Dubloon"] = 1710,
    ["Stygia"] = 1767,
    ["Twilight's Blade Insignia"] = 3319,
    ["Unalloyed Abundance"] = 3377,
    ["Undercoin"] = 2803,
    ["Voidlight Marl"] = 3316,
    ["War Resources"] = 1560,
}

-- Item-based costs that appear as currencyName in VendorData but are items, not currencies.
-- Resolved via C_Item.GetItemNameByID instead of C_CurrencyInfo.
local ITEM_CURRENCY_TO_ID = {
    ["Mark of Honor"] = 137642,
}

local ITEM_ID_TO_CURRENCY_NAME = {}
for currencyName, itemID in pairs(ITEM_CURRENCY_TO_ID) do
    ITEM_ID_TO_CURRENCY_NAME[itemID] = currencyName
end

local currencyNameCache = {}  -- englishName -> localized name (positive only)
local currencyDisplayInfoCache = {}  -- englishName -> { name, iconFileID, currencyID/itemID } (positive only)

local function IsUsableValue(value)
    return value ~= nil
        and not (type(issecretvalue) == "function" and issecretvalue(value))
end

-- Item-token cost components (Tricky Treats, Brewfest Prize Tokens, ...) have no
-- currencyName; they get "item:<itemID>" currency keys. Items already named as a
-- currency above share that name's key, so one filter option covers both encodings.
-- The raw key is an identifier only (SavedVariables keep it); it is never shown or
-- searched. Readers go through ResolveItemCostKey / GetItemCostLabel below.
local ITEM_COST_KEY_PREFIX = "item:"
local ITEM_COST_KEY_PATTERN = "^" .. ITEM_COST_KEY_PREFIX .. "(%d+)$"
local ITEM_DATA_LOAD_RESULT_EVENT = "ITEM_DATA_LOAD_RESULT"

local itemNameCache = {}           -- itemID -> client item name (positive only)
local requestedItemNameLoads = {}  -- itemID -> true while this module awaits ITEM_DATA_LOAD_RESULT
local pendingItemNameLoadCount = 0

function addon:GetItemCostCurrencyKey(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then return nil end
    return ITEM_ID_TO_CURRENCY_NAME[itemID] or (ITEM_COST_KEY_PREFIX .. itemID)
end

local function GetItemCostKeyItemID(currencyKey)
    if type(currencyKey) ~= "string" then return nil end
    local digits = currencyKey:match(ITEM_COST_KEY_PATTERN)
    return digits and tonumber(digits) or nil
end

-- Reads a cached item name without requesting anything.
local function ReadItemName(itemID)
    local cached = itemNameCache[itemID]
    if cached then return cached end
    if not (C_Item and C_Item.GetItemNameByID) then return nil end

    local ok, name = pcall(C_Item.GetItemNameByID, itemID)
    if ok and IsUsableValue(name) and type(name) == "string" and name ~= "" then
        itemNameCache[itemID] = name
        return name
    end
    return nil
end

-- ITEM_DATA_LOAD_RESULT fires for every item load in the client, so it is registered
-- only while this module has a request outstanding and filtered to those item IDs.
local OnItemDataLoadResult

local function ClearItemNameRequest(itemID)
    if not requestedItemNameLoads[itemID] then return end
    requestedItemNameLoads[itemID] = nil
    pendingItemNameLoadCount = pendingItemNameLoadCount - 1
    if pendingItemNameLoadCount <= 0 then
        pendingItemNameLoadCount = 0
        addon:UnregisterWoWEvent(ITEM_DATA_LOAD_RESULT_EVENT, OnItemDataLoadResult)
    end
end

OnItemDataLoadResult = function(itemID, success)
    if type(itemID) ~= "number" or not IsUsableValue(itemID) then return end
    if not requestedItemNameLoads[itemID] then return end

    -- A failed load leaves the flag cleared so a later read asks again (no retry loop).
    ClearItemNameRequest(itemID)
    if not IsUsableValue(success) or success ~= true or not ReadItemName(itemID) then return end

    -- Display info built before the load holds the pre-load name (Mark of Honor's English name)
    for englishName, displayInfo in pairs(currencyDisplayInfoCache) do
        if displayInfo.itemID == itemID then
            currencyDisplayInfoCache[englishName] = nil
        end
    end
    addon:FireEvent(addon.Events.ITEM_COST_NAME_LOADED, itemID)
end

local function RequestItemNameLoad(itemID)
    if requestedItemNameLoads[itemID] then return end
    if not (C_Item and C_Item.RequestLoadItemDataByID) then return end
    -- An item the client does not know may never report a load result
    if C_Item.DoesItemExistByID then
        local ok, exists = pcall(C_Item.DoesItemExistByID, itemID)
        if not ok or exists ~= true then return end
    end

    requestedItemNameLoads[itemID] = true
    pendingItemNameLoadCount = pendingItemNameLoadCount + 1
    if pendingItemNameLoadCount == 1 then
        addon:RegisterWoWEvent(ITEM_DATA_LOAD_RESULT_EVENT, OnItemDataLoadResult)
    end
    if not pcall(C_Item.RequestLoadItemDataByID, itemID) then
        ClearItemNameRequest(itemID)
    end
end

-- Item name for a vendor cost, or nil while uncached (a load is requested).
local function GetItemCostName(itemID)
    local name = ReadItemName(itemID)
    if not name then
        RequestItemNameLoad(itemID)
        -- The load result can arrive inside the request call when the data is already cached
        name = ReadItemName(itemID)
    end
    return name
end

-- For an "item:<itemID>" cost key: returns the itemID and the client item name, or the
-- itemID and nil while the name is unresolved (a load is requested). Any other key
-- returns nil. Callers must never fall back to the raw key for display or search.
function addon:ResolveItemCostKey(currencyKey)
    local itemID = GetItemCostKeyItemID(currencyKey)
    if not itemID then return nil end
    return itemID, GetItemCostName(itemID)
end

-- Display label for an item used as a vendor cost, plus whether its name resolved.
-- While unresolved the label is a localized placeholder carrying the item ID (several
-- tokens can be pending at once); it is never cached as a name and never persisted.
function addon:GetItemCostLabel(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then return nil, false end
    local name = GetItemCostName(itemID)
    if name then return name, true end
    return string.format(self.L["CURRENCY_ITEM_PENDING_FORMAT"], itemID), false
end

-- Requests names for every unresolved item key in a currency key set (keys -> true),
-- so labels are normally cached before a filter menu first opens.
function addon:RequestItemCostKeyNames(keySet)
    if type(keySet) ~= "table" then return end
    for currencyKey in pairs(keySet) do
        -- Items keyed by a currency name (Mark of Honor) need the same early request
        local namedItemID = ITEM_CURRENCY_TO_ID[currencyKey]
        if namedItemID then
            GetItemCostName(namedItemID)
        else
            self:ResolveItemCostKey(currencyKey)
        end
    end
end

function addon:GetLocalizedCurrencyName(englishName)
    if not englishName then return englishName end

    local cached = currencyNameCache[englishName]
    if cached then return cached end

    local itemKeyID = GetItemCostKeyItemID(englishName)
    if itemKeyID then
        return (self:GetItemCostLabel(itemKeyID))
    end

    local currencyID = CURRENCY_NAME_TO_ID[englishName]
    if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
        if ok and info and IsUsableValue(info.name) and info.name ~= "" then
            currencyNameCache[englishName] = info.name
            return info.name
        end
    end

    -- Item-based currency name (e.g., Mark of Honor)
    local itemID = ITEM_CURRENCY_TO_ID[englishName]
    if itemID then
        local name = GetItemCostName(itemID)
        if name then
            currencyNameCache[englishName] = name
            return name
        end
    end

    -- No localization available -- return English name without caching
    return englishName
end

local function GetItemCurrencyIcon(itemID)
    if not itemID or not C_Item then return nil end

    if C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and IsUsableValue(icon) and type(icon) == "number" then
            return icon
        end
    end

    if C_Item.GetItemInfoInstant then
        local ok, itemIDResult, itemType, itemSubType, itemEquipLoc, icon = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok and IsUsableValue(icon) and type(icon) == "number" then
            return icon
        end
    end

    return nil
end

function addon:GetCurrencyDisplayInfo(englishName)
    if not englishName then return nil end

    local cached = currencyDisplayInfoCache[englishName]
    if cached then return cached end

    local displayInfo = {
        name = self:GetLocalizedCurrencyName(englishName) or englishName,
    }

    local currencyID = CURRENCY_NAME_TO_ID[englishName]
    if currencyID then
        displayInfo.currencyID = currencyID
        if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
            if ok and info then
                if IsUsableValue(info.name) and info.name ~= "" then
                    displayInfo.name = info.name
                end
                if IsUsableValue(info.iconFileID) and type(info.iconFileID) == "number" then
                    displayInfo.iconFileID = info.iconFileID
                end
            end
        end
    else
        local itemID = ITEM_CURRENCY_TO_ID[englishName]
        if itemID then
            displayInfo.itemID = itemID
            displayInfo.iconFileID = GetItemCurrencyIcon(itemID)
        end
    end

    if displayInfo.iconFileID then
        currencyDisplayInfoCache[englishName] = displayInfo
    end
    return displayInfo
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
    ["Atal'Aman"] = 2536,
    ["Azshara"] = 76,
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
    ["Boralus Harbor"] = 1161,
    ["Isle of Quel'Danas"] = 2424,
    ["K'aresh"] = 2371,
    ["Krokuun"] = 830,
    ["Loch Modan"] = 48,
    ["Mulgore"] = 7,
    ["Nagrand"] = 550,
    ["Northshire"] = 425,
    ["Shadowmoon Valley"] = 539,
    ["Stormheim"] = 634,
    ["The Azure Span"] = 2024,
    ["The Coiled Isle"] = 2512,
    ["Vol'dun"] = 864,
    ["Westfall"] = 52,
    ["Zuldazar"] = 862,
}

-- areaIDs for zones without uiMapIDs (used with C_Map.GetAreaInfo for localization)
-- Source: Wowhead AreaTable DBC entries
local ZONE_AREA_ID = {
    ["The Great Sea"] = 9800,
    ["Manaforge Omega"] = 16178,
}

-- Resolve a zone name to a uiMapID from either vendor data or the static table
function addon:GetMapIdForZone(zoneName)
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
    local localizedName = getLocalizedNameFromMapId(self:GetMapIdForZone(englishZoneName))
    if localizedName then
        zoneNameCache[englishZoneName] = localizedName
        return localizedName
    end

    -- For compound names like "Mudsprocket, Dustwallow Marsh" or "The Bazaar, Silvermoon City",
    -- try localizing both the parent zone (after the last comma) and the subzone prefix
    local prefix, parentZone = englishZoneName:match("^(.+),%s*([^,]+)$")
    if parentZone then
        local localizedParent = getLocalizedNameFromMapId(self:GetMapIdForZone(parentZone))
        local localizedPrefix = getLocalizedNameFromMapId(self:GetMapIdForZone(prefix))
        if localizedParent then
            local displayPrefix = localizedPrefix or prefix
            local localized = displayPrefix .. ", " .. localizedParent
            zoneNameCache[englishZoneName] = localized
            return localized
        end
    end

    -- Try areaID lookup for zones without uiMapIDs
    local areaID = ZONE_AREA_ID[englishZoneName]
    if areaID and C_Map and C_Map.GetAreaInfo then
        local areaName = C_Map.GetAreaInfo(areaID)
        if areaName and areaName ~= "" then
            zoneNameCache[englishZoneName] = areaName
            return areaName
        end
    end

    -- No localization available -- return English name without caching
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
    -- When called under addon taint, leftText can be a secret string; comparing it throws.
    if not name or (type(issecretvalue) == "function" and issecretvalue(name)) or name == "" or name == RETRIEVING_DATA then
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
                local result = localizedExpansion .. " " .. localizedProfession
                skillLineCache[englishSkillLine] = result
                return result
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
