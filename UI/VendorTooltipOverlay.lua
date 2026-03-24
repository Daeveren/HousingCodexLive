--[[
    Housing Codex - VendorTooltipOverlay.lua
    Appends decor collection progress to unit tooltips for vendor NPCs.
    Uses TooltipDataProcessor.AddTooltipPostCall (the standard Blizzard API for
    addon tooltip content — same approach as TSM, Raider.IO, etc.)
]]

local _, addon = ...
local VendorTooltipOverlay = {}
addon.VendorTooltipOverlay = VendorTooltipOverlay

local HC_ICON_PATH = "Interface\\AddOns\\HousingCodex\\HC64"
local MISSING_DISPLAY_LIMIT = 5

local initialized = false
local ICON_PREFIX    -- "|Tpath:18:18:0:0|t " (set at Initialize)

local function OnTooltipUnit(tooltip)
    if not tooltip or tooltip ~= GameTooltip then return end

    -- Early-out if setting disabled
    if not addon.db or not addon.db.settings or not addon.db.settings.showVendorTooltips then return end

    local name, unit, guid = tooltip:GetUnit()
    if not name or not unit or not guid then return end

    -- Guard against secret values (WoW 12.0+ restricted unit identity)
    if issecretvalue(guid) then return end

    -- Fast prefix check: skip players, pets, battle pets, etc.
    if guid:sub(1, 9) ~= "Creature-" then return end

    -- Extract NPC ID from GUID: "Creature-0-...-npcID-spawnUID"
    local npcId = tonumber(guid:match("^Creature%-.-%-.-%-.-%-.-%-(%d+)%-"))
    if not npcId then return end

    -- Check vendor index
    if not addon.vendorIndex or not addon.vendorIndex[npcId] then return end

    local owned, total, missingNames = addon:GetVendorPinProgress(npcId)
    if not owned or not total or total == 0 then return end

    local L = addon.L
    local COLORS = addon.CONSTANTS.COLORS

    -- Blank separator line
    tooltip:AddLine(" ")

    -- Header line (static — animation was removed in 12.0+ taint fix)
    tooltip:AddLine(ICON_PREFIX .. "|cffffd100Housing|r |cffff8000Codex|r")

    -- Progress line (reuses VENDOR_PIN_COLLECTED format shared with VendorMapPins)
    local progressText = string.format(L["VENDOR_PIN_COLLECTED"], owned, total)
    tooltip:AddLine(progressText, COLORS.SOURCE_NAME_GOLD[1], COLORS.SOURCE_NAME_GOLD[2], COLORS.SOURCE_NAME_GOLD[3])

    -- Missing item names (show up to MISSING_DISPLAY_LIMIT; upstream caps at VENDOR_PIN.TOOLTIP_ITEM_LIMIT)
    if owned < total and missingNames and #missingNames > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine(L["VENDOR_PIN_UNCOLLECTED_HEADER"], 0.85, 0.85, 0.85)
        local shown = math.min(#missingNames, MISSING_DISPLAY_LIMIT)
        for i = 1, shown do
            local entry = missingNames[i]
            local suffix = entry.locked and (" (|cffcc5a40" .. L["VENDOR_PIN_ITEM_LOCKED"] .. "|r)") or ""
            tooltip:AddLine("  " .. entry.name .. suffix, 0.7, 0.7, 0.7)
        end

        local overflow = (total - owned) - shown
        if overflow > 0 then
            tooltip:AddLine(string.format(L["VENDOR_PIN_MORE"], overflow), 0.6, 0.6, 0.6)
        end
    end
end

function VendorTooltipOverlay:Initialize()
    if initialized then return end
    initialized = true

    ICON_PREFIX = string.format("|T%s:18:18:0:0|t ", HC_ICON_PATH)

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipUnit)

    addon:Debug("VendorTooltipOverlay initialized")
end

addon:RegisterInternalEvent("DATA_LOADED", function()
    VendorTooltipOverlay:Initialize()
end)
