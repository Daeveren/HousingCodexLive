--[[
    Housing Codex - VendorTooltipOverlay.lua
    Appends decor collection progress to unit tooltips for vendor NPCs
]]

local _, addon = ...
local VendorTooltipOverlay = {}
addon.VendorTooltipOverlay = VendorTooltipOverlay

local HC_ICON_PATH = "Interface\\AddOns\\HousingCodex\\HC64"
local MISSING_DISPLAY_LIMIT = 5

local initialized = false

-- Animation state
local animDriver       -- child frame driving OnUpdate
local animElapsed = 0  -- running clock
local headerFS         -- FontString reference for the header line
local animPhase        -- "typewriter" | "pause" | "pulse" | nil
local pauseStart       -- timestamp when pause began

-- The icon prefix is always fully visible; we typewrite the text after it
local ICON_PREFIX    -- "|Tpath:18:18:0:0|t " (set at Initialize)
local CHARS_PER_SEC = 14
local PAUSE_DURATION = 1.0

-- "Housing" = gold (ffd100), " Codex" = orange (ff8000)
local WORD1 = "Housing"
local WORD2 = "Codex"
local WORD1_LEN = #WORD1  -- 7
local FULL_LEN = WORD1_LEN + 1 + #WORD2 -- 14 ("Housing Codex" including space)

local function BuildHeaderAtChar(n)
    -- n = number of visible characters (0..14)
    if n <= 0 then
        return ICON_PREFIX
    elseif n <= WORD1_LEN then
        return ICON_PREFIX .. "|cffffd100" .. WORD1:sub(1, n) .. "|r"
    elseif n <= WORD1_LEN + 1 then
        return ICON_PREFIX .. "|cffffd100" .. WORD1 .. "|r "
    else
        local codexChars = n - WORD1_LEN - 1
        return ICON_PREFIX .. "|cffffd100" .. WORD1 .. "|r |cffff8000" .. WORD2:sub(1, codexChars) .. "|r"
    end
end

local function AnimOnUpdate(self, dt)
    animElapsed = animElapsed + dt

    -- Header animation (typewriter → pause → pulse)
    if headerFS and headerFS:IsVisible() then
        if animPhase == "typewriter" then
            local idx = math.floor(animElapsed * CHARS_PER_SEC)
            if idx >= FULL_LEN then
                headerFS:SetText(BuildHeaderAtChar(FULL_LEN))
                animPhase = "pause"
                pauseStart = animElapsed
            else
                headerFS:SetText(BuildHeaderAtChar(idx))
            end

        elseif animPhase == "pause" then
            if animElapsed - pauseStart >= PAUSE_DURATION then
                animPhase = "pulse"
            end

        elseif animPhase == "pulse" then
            local t = 0.6 + 0.4 * math.sin((animElapsed - pauseStart - PAUSE_DURATION) * 2.5)
            local gold_g = math.floor(0xd1 * t)
            local orange_g = math.floor(0x80 * t)
            local goldHex = string.format("ff%02x00", gold_g)
            local orangeHex = string.format("ff%02x00", orange_g)
            headerFS:SetText(
                ICON_PREFIX
                .. "|cff" .. goldHex .. WORD1 .. "|r"
                .. " |cff" .. orangeHex .. WORD2 .. "|r"
            )
        end
    end
end

local function CleanupAnimation()
    if animDriver then
        animDriver:SetScript("OnUpdate", nil)
    end
    animElapsed = 0
    animPhase = nil
    headerFS = nil
    pauseStart = nil
end

local function StartAnimations(tooltip)
    -- Create or reuse the OnUpdate driver frame
    if not animDriver then
        animDriver = CreateFrame("Frame", nil, UIParent)
    end
    animElapsed = 0
    pauseStart = nil

    -- Header is not the last line; find it by scanning for ICON_PREFIX
    for i = 1, tooltip:NumLines() do
        local fs = _G["GameTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and text:find(HC_ICON_PATH, 1, true) then
            headerFS = fs
            headerFS:SetText(ICON_PREFIX)
            break
        end
    end
    animPhase = "typewriter"

    animDriver:SetScript("OnUpdate", AnimOnUpdate)
end

local function OnTooltipUnit(tooltip)
    if not tooltip or tooltip ~= GameTooltip then return end

    -- Early-out if setting disabled
    if not addon.db or not addon.db.settings or not addon.db.settings.showVendorTooltips then return end

    local name, unit, guid = tooltip:GetUnit()
    if not name or not unit or not guid then return end

    -- Guard against secret values (WoW 12.0+ restricted unit identity)
    if issecretvalue and issecretvalue(guid) then return end

    -- Fast prefix check: skip players, pets, battle pets, etc.
    if guid:sub(1, 9) ~= "Creature-" then return end

    -- Extract NPC ID from GUID: "Creature-0-...-npcID-spawnUID"
    local npcId = tonumber(guid:match("^Creature%-.-%-.-%-.-%-.-%-(%d+)%-"))
    if not npcId then return end

    -- Check vendor index
    if not addon.vendorIndex or not addon.vendorIndex[npcId] then return end

    local owned, total, missingNames = addon:GetVendorPinProgress(npcId)
    if not total or total == 0 then return end

    -- Duplicate guard: scan existing lines for our icon path (escape codes break plain-text matching)
    for i = 1, tooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and text:find(HC_ICON_PATH, 1, true) then return end
    end

    local L = addon.L
    local COLORS = addon.CONSTANTS.COLORS

    -- Blank separator line
    tooltip:AddLine(" ")

    -- Header line — animate only when there's uncollected decor
    local animateHeader = owned < total
    if animateHeader then
        tooltip:AddLine(ICON_PREFIX)
    else
        tooltip:AddLine(ICON_PREFIX .. "|cffffd100" .. WORD1 .. "|r |cffff8000" .. WORD2 .. "|r")
    end

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
            if entry.locked then
                tooltip:AddLine("  " .. entry.name .. " (|cffcc5a40" .. L["VENDOR_PIN_ITEM_LOCKED"] .. "|r)", 0.7, 0.7, 0.7)
            else
                tooltip:AddLine("  " .. entry.name, 0.7, 0.7, 0.7)
            end
        end

        local overflow = (total - owned) - shown
        if overflow > 0 then
            tooltip:AddLine(string.format(L["VENDOR_PIN_MORE"], overflow), 0.6, 0.6, 0.6)
        end
    end

    -- Start header animation if needed
    if animateHeader then
        StartAnimations(tooltip)
    end
end

function VendorTooltipOverlay:Initialize()
    if initialized then return end
    initialized = true

    ICON_PREFIX = string.format("|T%s:18:18:0:0|t ", HC_ICON_PATH)

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipUnit)

    -- Clean up animation state when tooltip hides
    GameTooltip:HookScript("OnHide", CleanupAnimation)

    addon:Debug("VendorTooltipOverlay initialized")
end

addon:RegisterInternalEvent("DATA_LOADED", function()
    VendorTooltipOverlay:Initialize()
end)
