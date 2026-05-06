--[[
    Housing Codex - VendorTooltipOverlay.lua
    Appends decor collection progress to unit tooltips for vendor NPCs.
    Uses TooltipDataProcessor.AddTooltipPostCall (the standard Blizzard API for
    addon tooltip augmentation)
]]

local _, addon = ...
local VendorTooltipOverlay = {}
addon.VendorTooltipOverlay = VendorTooltipOverlay

local HC_ICON_PATH = "Interface\\AddOns\\HousingCodex\\HC64"
local MISSING_DISPLAY_LIMIT = 5
local COMPLETE_CHECKMARK = "|A:common-icon-checkmark:14:14:0:-1|a"

local initialized = false
local ICON_PREFIX    -- "|Tpath:18:18:0:0|t " (set at Initialize)

local function OnTooltipUnit(tooltip)
    if not tooltip or tooltip ~= GameTooltip then return end

    -- Early-out if setting disabled
    if not addon.db or not addon.db.settings or not addon.db.settings.showVendorTooltips then return end

    -- Avoid tooltip:GetUnit() / TooltipUtil.GetDisplayedUnit — it calls UnitName(unit) on a
    -- secret unit token, which is disallowed under the addon-tainted PostCall dispatch.
    if not tooltip:IsTooltipType(Enum.TooltipDataType.Unit) then return end
    local tooltipData = tooltip:GetPrimaryTooltipData()
    if not tooltipData then return end
    local guid = tooltipData.guid
    if not guid or issecretvalue(guid) then return end

    -- Fast prefix check: skip players, pets, battle pets, etc.
    if guid:sub(1, 9) ~= "Creature-" then return end

    -- Extract NPC ID from GUID: "Creature-0-...-npcID-spawnUID"
    local npcId = tonumber(guid:match("^Creature%-.-%-.-%-.-%-.-%-(%d+)%-"))
    if not npcId then return end

    -- Check vendor index
    if not addon.vendorIndex or not addon.vendorIndex[npcId] then return end
    if not addon:ShouldShowVendorForPlayerProfessionFilter(npcId) then return end

    local owned, total, missingNames, promoOwned, promoTotal = addon:GetVendorPinProgress(npcId)
    if not owned or not total then return end
    if total == 0 and (promoTotal or 0) == 0 then return end

    local L = addon.L
    local COLORS = addon.CONSTANTS.COLORS

    -- Blank separator line
    tooltip:AddLine(" ")

    -- Header line (static — animation was removed in 12.0+ taint fix)
    tooltip:AddLine(ICON_PREFIX .. "|cffffd100Housing|r |cffff8000Codex|r")

    -- Progress line (reuses VENDOR_PIN_COLLECTED format shared with VendorMapPins)
    local progressText = string.format(L["VENDOR_PIN_COLLECTED"], owned, total)
    local promoCount = promoTotal or 0
    local isVendorComplete = (total > 0 or promoCount > 0) and owned >= total and (promoOwned or 0) >= promoCount
    if isVendorComplete then
        progressText = progressText .. " " .. COMPLETE_CHECKMARK
    end
    tooltip:AddLine(progressText, COLORS.SOURCE_NAME_GOLD[1], COLORS.SOURCE_NAME_GOLD[2], COLORS.SOURCE_NAME_GOLD[3])

    -- Promo (rotated / event-gated) sub-total if this vendor has any
    if promoTotal and promoTotal > 0 then
        tooltip:AddLine(string.format(L["VENDOR_PIN_PROMO"], promoOwned, promoTotal), 0.6, 0.6, 0.6)
    end

    -- Missing item names (show up to MISSING_DISPLAY_LIMIT; upstream caps at VENDOR_PIN.TOOLTIP_ITEM_LIMIT)
    if missingNames and #missingNames > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine(L["VENDOR_PIN_UNCOLLECTED_HEADER"], 0.85, 0.85, 0.85)
        local shown = math.min(#missingNames, MISSING_DISPLAY_LIMIT)
        for i = 1, shown do
            local entry = missingNames[i]
            -- Promo takes precedence over locked (rotation moots the achievement gate).
            local suffix
            if entry.promotional then
                suffix = " (|cff9090a0" .. L["VENDOR_PIN_ITEM_PROMO"] .. "|r)"
            elseif entry.locked then
                suffix = " (|cffcc5a40" .. L["VENDOR_PIN_ITEM_LOCKED"] .. "|r)"
            else
                suffix = ""
            end
            tooltip:AddLine("  " .. entry.name .. suffix, 0.7, 0.7, 0.7)
        end

        local missingTotal = (total - owned) + ((promoTotal or 0) - (promoOwned or 0))
        local overflow = missingTotal - shown
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
