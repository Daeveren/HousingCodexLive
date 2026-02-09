--[[
    Housing Codex - LDB.lua
    LibDataBroker support for broker display addons (Titan Panel, ChocolateBar, etc.)
]]

local ADDON_NAME, addon = ...

-- Create LDB module
addon.LDB = {}
local LDB = addon.LDB

local L = addon.L
local dataObject = nil
local libDBIcon = nil
local brokerPopup = nil

-- ============================================================================
-- Broker Display Popup (Alt-click configuration)
-- ============================================================================

local function CreateBrokerPopup()
    if brokerPopup then return brokerPopup end

    local popup = CreateFrame("Frame", "HousingCodexBrokerPopup", UIParent, "BackdropTemplate")
    popup:SetSize(220, 120)
    popup:SetFrameStrata("DIALOG")
    popup:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    popup:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    popup:SetBackdropBorderColor(0.6, 0.6, 0.6)
    popup:Hide()
    popup:EnableMouse(true)

    -- ESC closes
    tinsert(UISpecialFrames, "HousingCodexBrokerPopup")

    -- Title
    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText(L["LDB_POPUP_TITLE"])
    title:SetTextColor(1, 0.82, 0, 1)

    -- Checkbox helper
    local function CreatePopupCheckbox(parent, yOffset, label, settingsKey)
        local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 12, yOffset)
        check.Text:SetFontObject(GameFontHighlightSmall)
        check.Text:SetText(label)
        check.settingsKey = settingsKey
        check:SetChecked(addon.db.settings[settingsKey])
        check:SetScript("OnClick", function(self)
            addon.db.settings[self.settingsKey] = self:GetChecked()
            LDB:UpdateText()
        end)
        return check
    end

    popup.checks = {
        CreatePopupCheckbox(popup, -28, L["LDB_POPUP_UNIQUE"], "ldbShowUnique"),
        CreatePopupCheckbox(popup, -52, L["LDB_POPUP_TOTAL_OWNED"], "ldbShowTotalOwned"),
        CreatePopupCheckbox(popup, -76, L["LDB_POPUP_TOTAL_ITEMS"], "ldbShowTotal"),
    }

    brokerPopup = popup
    return popup
end

local function ToggleBrokerPopup(anchorFrame)
    local popup = CreateBrokerPopup()

    if popup:IsShown() then
        popup:Hide()
        return
    end

    -- Refresh checkbox states
    for _, check in ipairs(popup.checks) do
        check:SetChecked(addon.db.settings[check.settingsKey])
    end

    -- Anchor below the clicked frame, or at cursor
    popup:ClearAllPoints()
    if anchorFrame and anchorFrame.GetCenter then
        popup:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -5)
    else
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        popup:SetPoint("TOP", UIParent, "BOTTOMLEFT", x / scale, y / scale - 5)
    end

    popup:Show()
end

-- ============================================================================
-- Click and Tooltip Handlers
-- ============================================================================

-- Shared click handler for LDB and AddonCompartment
local function HandleClick(clickedFrame, button)
    if InCombatLockdown() then
        addon:Print(L["COMBAT_LOCKDOWN_MESSAGE"])
        return
    end

    if button == "LeftButton" then
        if IsAltKeyDown() then
            ToggleBrokerPopup(clickedFrame)
        elseif addon.MainFrame then
            addon.MainFrame:Toggle()
        end
    elseif button == "RightButton" then
        if addon.Settings and addon.Settings.Open then
            addon.Settings:Open()
        else
            addon:Print(L["LDB_OPTIONS_PLACEHOLDER"])
        end
    end
end

-- Shared tooltip builder for LDB and AddonCompartment
local function ShowTooltip(tooltip)
    if not tooltip or not tooltip.AddLine then return end
    tooltip:AddLine(L["ADDON_NAME"])
    tooltip:AddLine(" ")
    tooltip:AddLine(L["LDB_TOOLTIP_LEFT"], 0.8, 0.8, 0.8)
    tooltip:AddLine(L["LDB_TOOLTIP_RIGHT"], 0.8, 0.8, 0.8)
    tooltip:AddLine(L["LDB_TOOLTIP_ALT"], 0.8, 0.8, 0.8)
end

-- ============================================================================
-- LDB Core
-- ============================================================================

function LDB:Initialize()
    -- Check for LibDataBroker availability (provided by broker display addons)
    local LibStub = _G.LibStub
    if not LibStub then return end

    local LDBLib = LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not LDBLib then return end

    -- Create data object
    dataObject = LDBLib:NewDataObject(ADDON_NAME, {
        type = "launcher",
        icon = "Interface\\AddOns\\HousingCodex\\HC",
        text = "",
        OnClick = HandleClick,
        OnTooltipShow = ShowTooltip,
    })

    addon:Debug("LDB data object created")

    -- Register with LibDBIcon for standalone minimap button
    libDBIcon = LibStub("LibDBIcon-1.0", true)
    if libDBIcon then
        addon.db.minimap = addon.db.minimap or {}
        libDBIcon:Register(ADDON_NAME, dataObject, addon.db.minimap)
        -- Apply saved visibility setting
        self:SetMinimapShown(addon.db.settings.showMinimapButton)
        addon:Debug("LibDBIcon registered")
    end
end

function LDB:SetMinimapShown(show)
    if not libDBIcon then return end

    if show then
        libDBIcon:Show(ADDON_NAME)
    else
        libDBIcon:Hide(ADDON_NAME)
    end
end

function LDB:UpdateText()
    if not dataObject then return end

    local settings = addon.db and addon.db.settings
    if not settings then
        dataObject.text = ""
        return
    end

    local segments = {}

    if addon.indexesBuilt then
        if settings.ldbShowUnique then
            segments[#segments + 1] = tostring(addon:GetUniqueCollectedCount())
        end

        if settings.ldbShowTotalOwned then
            segments[#segments + 1] = tostring(addon:GetTotalOwnedCount())
        end

        if settings.ldbShowTotal then
            segments[#segments + 1] = tostring(addon:GetRecordCount())
        end
    end

    -- Join segments with "/" or empty for icon-only
    dataObject.text = table.concat(segments, "/")
end

-- Debounced refresh: rebuild indexes and update broker text
local function DebouncedRefresh(delay)
    if LDB.updatePending then return end
    LDB.updatePending = true
    C_Timer.After(delay, function()
        LDB.updatePending = false
        if addon.indexesBuilt then
            addon:BuildIndexes()
        end
        LDB:UpdateText()
    end)
end

-- Event handlers
addon:RegisterInternalEvent("DATA_LOADED", function()
    LDB:Initialize()
    LDB:UpdateText()
end)

addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
    DebouncedRefresh(0.1)
end)

-- ============================================================================
-- Addon Compartment (built-in minimap dropdown, no libs required)
-- ============================================================================

function HousingCodex_OnAddonCompartmentClick(addonInfo, button)
    HandleClick(nil, button)
end

function HousingCodex_OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    ShowTooltip(GameTooltip)
    GameTooltip:Show()
end

function HousingCodex_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

-- Also listen for bulk storage updates
addon:RegisterWoWEvent("HOUSING_STORAGE_UPDATED", function()
    if not addon.dataLoaded then return end
    DebouncedRefresh(0.5)
end)
