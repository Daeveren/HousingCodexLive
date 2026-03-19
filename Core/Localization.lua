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

--------------------------------------------------------------------------------
-- Zone name localization
-- Uses vendorZoneToMapId (populated by VendorIndex from NPCLocationData) to
-- resolve English scraper zone names to locale-aware names via C_Map.GetMapInfo.
-- Works for all tabs (quests, vendors, zone overlay).
--
-- Only positive results are cached. Negative results are NOT cached so that
-- lookups succeed after vendorZoneToMapId is populated (e.g., initial load
-- timing, /hc retry). The uncached path is two table lookups -- negligible.
--------------------------------------------------------------------------------
local zoneNameCache = {}  -- englishZoneName -> localized name (positive only)

function addon:GetLocalizedZoneName(englishZoneName)
    if not englishZoneName then return englishZoneName end

    local cached = zoneNameCache[englishZoneName]
    if cached then return cached end

    -- Try direct mapID lookup from vendor NPC location data
    local mapId = self.vendorZoneToMapId and self.vendorZoneToMapId[englishZoneName]
    if mapId then
        local mapInfo = C_Map and C_Map.GetMapInfo(mapId)
        if mapInfo and mapInfo.name then
            zoneNameCache[englishZoneName] = mapInfo.name
            return mapInfo.name
        end
    end

    -- For compound names like "Mudsprocket, Dustwallow Marsh" or "The Bazaar, Silvermoon City",
    -- try localizing the parent zone (after the last comma)
    local parentZone = englishZoneName:match(",.-([^,]+)$")
    if parentZone then
        parentZone = parentZone:match("^%s*(.-)%s*$")  -- trim whitespace
        local parentMapId = self.vendorZoneToMapId and self.vendorZoneToMapId[parentZone]
        if parentMapId then
            local parentInfo = C_Map and C_Map.GetMapInfo(parentMapId)
            if parentInfo and parentInfo.name then
                local prefix = englishZoneName:match("^(.+,)%s*[^,]+$")
                local localized = prefix .. " " .. parentInfo.name
                zoneNameCache[englishZoneName] = localized
                return localized
            end
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
-- Positive results cached as the name string; false cached when RETRIEVING_DATA
-- was seen, to skip re-querying until cache wipe.
--------------------------------------------------------------------------------
local npcNameCache = {}  -- npcID -> name string, or false (RETRIEVING_DATA sentinel)

function addon:GetLocalizedNPCName(npcID, fallbackName)
    if not npcID or npcID <= 0 then return fallbackName end

    -- Check cache: false sentinel means RETRIEVING_DATA was seen, skip re-query
    local cached = npcNameCache[npcID]
    if cached ~= nil then return cached or fallbackName end

    -- AllowedWhenUntainted: safe from normal addon code, do not call from tainted context
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return fallbackName end

    local ok, tooltipData = pcall(C_TooltipInfo.GetHyperlink, ("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID))
    if not ok or not (tooltipData and tooltipData.lines) then return fallbackName end

    local name = tooltipData.lines[1] and tooltipData.lines[1].leftText
    if not name or name == "" or name == RETRIEVING_DATA then
        npcNameCache[npcID] = false  -- Sentinel: avoid re-querying until cache wipe
        return fallbackName
    end

    npcNameCache[npcID] = name
    return name
end

-- Flush false sentinels so stale RETRIEVING_DATA entries can be re-queried
-- Called on DATA_LOADED (e.g., /hc retry) when game client data may now be available
function addon:ClearNPCNameSentinels()
    for k, v in pairs(npcNameCache) do
        if v == false then npcNameCache[k] = nil end
    end
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

    return englishSkillLine
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

addon:RegisterInternalEvent("DATA_LOADED", function()
    addon:ClearNPCNameSentinels()
end)
