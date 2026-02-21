--[[
    Housing Codex - SettingsPanel.lua
    WoW native Settings UI integration (Settings > AddOns > Housing Codex)
]]

local ADDON_NAME, addon = ...

addon.Settings = {}

-- The binding action name from Bindings.xml
local BINDING_ACTION = "HOUSINGCODEX_TOGGLE"

--------------------------------------------------------------------------------
-- Helper: Get current keybind from standard WoW binding system
--------------------------------------------------------------------------------
local function GetCurrentKeybind()
    -- Query the standard WoW keybinding system for our action
    local key1, key2 = GetBindingKey(BINDING_ACTION)
    return key1  -- Return primary binding (WoW supports 2 per action)
end

--------------------------------------------------------------------------------
-- Helper: Get display text for keybind
--------------------------------------------------------------------------------
local function GetKeybindDisplayText()
    local key = GetCurrentKeybind()
    if key then
        return GetBindingText(key)  -- Human-readable (e.g., "Alt-C" instead of "ALT-C")
    end
    return nil
end

--------------------------------------------------------------------------------
-- Helper: Create checkbox with tooltip
--------------------------------------------------------------------------------
local function CreateCheckbox(parent, label, tooltip, getValue, setValue)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check.Text:SetFontObject(GameFontNormal)
    check.Text:SetTextColor(1, 0.82, 0)
    check.Text:SetText(label)
    check:SetChecked(getValue())

    check:SetScript("OnClick", function(self)
        setValue(self:GetChecked())
    end)

    check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip)
        GameTooltip:Show()
    end)

    check:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return check
end

local function RefreshVendorMapPins()
    local provider = addon.vendorMapProvider
    if not provider then return end

    local map = provider:GetMap()
    if map and map:IsShown() then
        provider:RefreshAllData()
    end
end

--------------------------------------------------------------------------------
-- Helper: Create section divider line
--------------------------------------------------------------------------------
local function CreateDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 16, yOffset - 5)
    divider:SetPoint("TOPRIGHT", -16, yOffset - 5)
    divider:SetColorTexture(0.3, 0.3, 0.35, 0.6)
end

-- Maps each checkbox field on self to its SavedVariables key (used by Refresh)
local CHECKBOX_REFRESH_MAP = {
    { field = "fontCheck",          settingKey = "useCustomFont"             },
    { field = "collectedCheck",     settingKey = "showCollectedIndicator"    },
    { field = "minimapCheck",       settingKey = "showMinimapButton"         },
    { field = "autoRotateCheck",    settingKey = "autoRotatePreview"         },
    { field = "vendorMapPinsCheck", settingKey = "showVendorMapPins"         },
    { field = "zoneOverlayCheck",   settingKey = "showZoneOverlay"           },
    { field = "treasureHuntCheck",  settingKey = "treasureHuntWaypoints"     },
    { field = "vendorCheck",        settingKey = "showVendorDecorIndicators" },
    { field = "vendorOwnedCheck",   settingKey = "showVendorOwnedCheckmark"  },
    { field = "midnightCheck",      settingKey = "showMidnightDrops"         },
}

--------------------------------------------------------------------------------
-- Settings Panel Initialization
--------------------------------------------------------------------------------
function addon.Settings:Initialize()
    local L = addon.L

    -- Create the settings panel frame
    local panel = CreateFrame("Frame", "HousingCodexSettingsPanel", UIParent)
    panel.name = L["ADDON_NAME"]
    self.panel = panel

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["ADDON_NAME"])
    title:SetTextColor(1, 0.82, 0)

    local yOffset = -50
    local COL1_X = 16
    local COL2_X = 300

    --------------------------------------------------------------------------------
    -- DISPLAY SECTION
    --------------------------------------------------------------------------------
    local displayHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    displayHeader:SetPoint("TOPLEFT", 16, yOffset)
    displayHeader:SetText(L["OPTIONS_SECTION_DISPLAY"])
    displayHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 30

    -- Use Custom Font checkbox
    local fontCheck = CreateCheckbox(
        panel,
        L["OPTIONS_USE_CUSTOM_FONT"],
        L["OPTIONS_USE_CUSTOM_FONT_TOOLTIP"],
        function() return addon.db and addon.db.settings.useCustomFont end,
        function(checked)
            if addon.db then
                addon.db.settings.useCustomFont = checked
                if addon.ApplyFontSettings then
                    addon:ApplyFontSettings()
                end
            end
        end
    )
    fontCheck:SetPoint("TOPLEFT", COL1_X, yOffset)
    self.fontCheck = fontCheck

    -- Show Collected Indicator checkbox
    local collectedCheck = CreateCheckbox(
        panel,
        L["OPTIONS_SHOW_COLLECTED"],
        L["OPTIONS_SHOW_COLLECTED_TOOLTIP"],
        function() return addon.db and addon.db.settings.showCollectedIndicator end,
        function(checked)
            if addon.db then
                addon.db.settings.showCollectedIndicator = checked
                if addon.Grid and addon.MainFrame and addon.MainFrame.frame and addon.MainFrame.frame:IsShown() then
                    addon.Grid:Refresh()
                end
            end
        end
    )
    collectedCheck:SetPoint("TOPLEFT", COL2_X, yOffset)
    self.collectedCheck = collectedCheck
    yOffset = yOffset - 30

    -- Show Minimap Button checkbox
    local minimapCheck = CreateCheckbox(
        panel,
        L["OPTIONS_SHOW_MINIMAP"],
        L["OPTIONS_SHOW_MINIMAP_TOOLTIP"],
        function() return addon.db and addon.db.settings.showMinimapButton end,
        function(checked)
            if addon.db then
                addon.db.settings.showMinimapButton = checked
                if addon.LDB then
                    addon.LDB:SetMinimapShown(checked)
                end
            end
        end
    )
    minimapCheck:SetPoint("TOPLEFT", COL1_X, yOffset)
    self.minimapCheck = minimapCheck

    -- Auto-rotate 3D preview checkbox
    local autoRotateCheck = CreateCheckbox(
        panel,
        L["OPTIONS_AUTO_ROTATE_PREVIEW"],
        L["OPTIONS_AUTO_ROTATE_PREVIEW_TOOLTIP"],
        function() return addon.db and addon.db.settings.autoRotatePreview end,
        function(checked)
            if addon.db then
                addon.db.settings.autoRotatePreview = checked
            end
        end
    )
    autoRotateCheck:SetPoint("TOPLEFT", COL2_X, yOffset)
    self.autoRotateCheck = autoRotateCheck
    yOffset = yOffset - 30

    CreateDivider(panel, yOffset)
    yOffset = yOffset - 20

    --------------------------------------------------------------------------------
    -- MAP & NAVIGATION SECTION
    --------------------------------------------------------------------------------
    local mapNavHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    mapNavHeader:SetPoint("TOPLEFT", 16, yOffset)
    mapNavHeader:SetText(L["OPTIONS_SECTION_MAP_NAV"])
    mapNavHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 30

    -- Show Vendor Map Pins checkbox
    local vendorMapPinsCheck = CreateCheckbox(
        panel,
        L["OPTIONS_VENDOR_MAP_PINS"],
        L["OPTIONS_VENDOR_MAP_PINS_TOOLTIP"],
        function() return addon.db and addon.db.settings.showVendorMapPins end,
        function(checked)
            if addon.db then
                addon.db.settings.showVendorMapPins = checked
                RefreshVendorMapPins()
            end
        end
    )
    vendorMapPinsCheck:SetPoint("TOPLEFT", COL1_X, yOffset)
    self.vendorMapPinsCheck = vendorMapPinsCheck

    -- Show Zone Overlay checkbox
    local zoneOverlayCheck = CreateCheckbox(
        panel,
        L["OPTIONS_ZONE_OVERLAY"],
        L["OPTIONS_ZONE_OVERLAY_TOOLTIP"],
        function() return addon.db and addon.db.settings.showZoneOverlay end,
        function(checked)
            if addon.db then
                addon.db.settings.showZoneOverlay = checked
                if addon.ZoneOverlay then
                    addon.ZoneOverlay:UpdateVisibility()
                end
            end
        end
    )
    zoneOverlayCheck:SetPoint("TOPLEFT", COL2_X, yOffset)
    self.zoneOverlayCheck = zoneOverlayCheck
    yOffset = yOffset - 30

    -- Treasure Hunt Waypoints checkbox
    local treasureHuntCheck = CreateCheckbox(
        panel,
        L["OPTIONS_TREASURE_HUNT_WAYPOINTS"],
        L["OPTIONS_TREASURE_HUNT_WAYPOINTS_TOOLTIP"],
        function() return addon.db and addon.db.settings.treasureHuntWaypoints end,
        function(checked)
            if addon.db then
                addon.db.settings.treasureHuntWaypoints = checked
                if addon.TreasureHuntWaypoints then
                    addon.TreasureHuntWaypoints.UpdateListenerState()
                end
            end
        end
    )
    treasureHuntCheck:SetPoint("TOPLEFT", COL1_X, yOffset)
    self.treasureHuntCheck = treasureHuntCheck
    yOffset = yOffset - 30

    CreateDivider(panel, yOffset)
    yOffset = yOffset - 20

    --------------------------------------------------------------------------------
    -- MERCHANT SECTION
    --------------------------------------------------------------------------------
    local merchantHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    merchantHeader:SetPoint("TOPLEFT", 16, yOffset)
    merchantHeader:SetText(L["OPTIONS_SECTION_MERCHANT"])
    merchantHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 30

    -- Show Vendor Decor Indicators checkbox
    local vendorCheck = CreateCheckbox(
        panel,
        L["OPTIONS_VENDOR_INDICATORS"],
        L["OPTIONS_VENDOR_INDICATORS_TOOLTIP"],
        function() return addon.db and addon.db.settings.showVendorDecorIndicators end,
        function(checked)
            if addon.db then
                addon.db.settings.showVendorDecorIndicators = checked
                if addon.MerchantOverlay then
                    if checked then
                        addon.MerchantOverlay:UpdateMerchantButtons()
                    else
                        addon.MerchantOverlay:HideAllOverlays()
                    end
                end
            end
        end
    )
    vendorCheck:SetPoint("TOPLEFT", COL1_X, yOffset)
    self.vendorCheck = vendorCheck

    -- Show Vendor Owned Checkmark checkbox
    local vendorOwnedCheck = CreateCheckbox(
        panel,
        L["OPTIONS_VENDOR_OWNED_CHECKMARK"],
        L["OPTIONS_VENDOR_OWNED_CHECKMARK_TOOLTIP"],
        function() return addon.db and addon.db.settings.showVendorOwnedCheckmark end,
        function(checked)
            if addon.db then
                addon.db.settings.showVendorOwnedCheckmark = checked
                if addon.MerchantOverlay then
                    addon.MerchantOverlay:UpdateMerchantButtons()
                end
            end
        end
    )
    vendorOwnedCheck:SetPoint("TOPLEFT", COL2_X, yOffset)
    self.vendorOwnedCheck = vendorOwnedCheck
    yOffset = yOffset - 30

    CreateDivider(panel, yOffset)
    yOffset = yOffset - 20

    --------------------------------------------------------------------------------
    -- CONTENT SECTION
    --------------------------------------------------------------------------------
    local contentHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    contentHeader:SetPoint("TOPLEFT", 16, yOffset)
    contentHeader:SetText(L["OPTIONS_SECTION_CONTENT"])
    contentHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 30

    -- Show Midnight Drops checkbox
    local midnightCheck = CreateCheckbox(
        panel,
        L["OPTIONS_SHOW_MIDNIGHT_DROPS"],
        L["OPTIONS_SHOW_MIDNIGHT_DROPS_TOOLTIP"],
        function() return addon.db and addon.db.settings.showMidnightDrops end,
        function(checked)
            if addon.db then
                addon.db.settings.showMidnightDrops = checked
                addon:BuildDropIndex()
                if addon.DropsTab and addon.DropsTab:IsShown() then
                    addon.DropsTab:RefreshDisplay()
                end
            end
        end
    )
    midnightCheck:SetPoint("TOPLEFT", COL1_X, yOffset)
    self.midnightCheck = midnightCheck
    yOffset = yOffset - 40

    -- Reset Position button
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", 16, yOffset)
    resetBtn:SetSize(160, 24)
    resetBtn:SetText(L["OPTIONS_RESET_POSITION"])
    resetBtn:SetScript("OnClick", function()
        if addon.MainFrame then
            addon.MainFrame:ResetPosition()
        end
    end)
    resetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["OPTIONS_RESET_POSITION_TOOLTIP"])
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    yOffset = yOffset - 40

    --------------------------------------------------------------------------------
    -- KEYBIND SECTION
    --------------------------------------------------------------------------------
    local keybindHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    keybindHeader:SetPoint("TOPLEFT", 16, yOffset)
    keybindHeader:SetText(L["OPTIONS_SECTION_KEYBIND"])
    keybindHeader:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 30

    -- Keybind label
    local keybindLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    keybindLabel:SetPoint("TOPLEFT", 16, yOffset)
    keybindLabel:SetText(L["OPTIONS_TOGGLE_KEYBIND"])
    keybindLabel:SetTextColor(0.9, 0.9, 0.9)

    -- Keybind button
    local keybindBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    keybindBtn:SetPoint("LEFT", keybindLabel, "RIGHT", 10, 0)
    keybindBtn:SetSize(140, 28)
    keybindBtn:RegisterForClicks("AnyUp")
    self.keybindBtn = keybindBtn

    -- Update button text based on current keybind from standard WoW system
    local function UpdateKeybindButtonText()
        local displayText = GetKeybindDisplayText()
        keybindBtn:SetText(displayText or L["OPTIONS_NOT_BOUND"])
    end
    self.UpdateKeybindButtonText = UpdateKeybindButtonText
    UpdateKeybindButtonText()

    -- Listen for binding changes from the standard Keybindings UI
    panel:RegisterEvent("UPDATE_BINDINGS")
    panel:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_BINDINGS" then
            UpdateKeybindButtonText()
        end
    end)

    -- Stop listening for key input
    local function StopKeyCapture(btn)
        btn:EnableKeyboard(false)
        btn:SetScript("OnKeyDown", nil)
        UpdateKeybindButtonText()
    end

    -- Modifier keys to ignore when pressed alone
    local MODIFIER_KEYS = {
        LSHIFT = true, RSHIFT = true,
        LCTRL = true, RCTRL = true,
        LALT = true, RALT = true,
    }

    -- Handle key press during capture
    local function OnKeyCaptured(btn, key)
        if MODIFIER_KEYS[key] then return end

        if key == "ESCAPE" then
            StopKeyCapture(btn)
            return
        end

        -- Build full key with modifiers
        local modifiers = {}
        if IsAltKeyDown() then modifiers[#modifiers + 1] = "ALT" end
        if IsControlKeyDown() then modifiers[#modifiers + 1] = "CTRL" end
        if IsShiftKeyDown() then modifiers[#modifiers + 1] = "SHIFT" end
        modifiers[#modifiers + 1] = key

        local fullKey = table.concat(modifiers, "-")

        -- Write to standard WoW binding system (not SavedVariables)
        -- First clear existing binding for our action
        local existingKey = GetCurrentKeybind()
        if existingKey then
            SetBinding(existingKey, nil)  -- Unbind old key
        end

        -- Set new binding
        SetBinding(fullKey, BINDING_ACTION)
        SaveBindings(GetCurrentBindingSet())

        StopKeyCapture(btn)
        UpdateKeybindButtonText()
        addon:Debug("Keybind set via standard system: " .. fullKey)
    end

    keybindBtn:SetScript("OnEnter", function(btn)
        local displayText = GetKeybindDisplayText()
        if displayText then
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L["ADDON_NAME"] .. " (" .. displayText .. ")", 1, 1, 1)
            GameTooltip:AddLine(L["OPTIONS_UNBIND_TOOLTIP"], 1, 1, 1)
            GameTooltip:Show()
        end
    end)

    keybindBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    keybindBtn:SetScript("OnClick", function(btn, button)
        if button == "RightButton" then
            -- Unbind from standard WoW system
            local existingKey = GetCurrentKeybind()
            if existingKey then
                SetBinding(existingKey, nil)
                SaveBindings(GetCurrentBindingSet())
                addon:Debug("Keybind cleared via standard system")
            end
            UpdateKeybindButtonText()
            GameTooltip:Hide()
        else
            btn:SetText(L["OPTIONS_PRESS_KEY"])
            btn:EnableKeyboard(true)
            btn:SetScript("OnKeyDown", OnKeyCaptured)
        end
    end)

    yOffset = yOffset - 40

    -- Hint text
    local hintText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hintText:SetPoint("TOPLEFT", 16, yOffset)
    hintText:SetText(L["OPTIONS_KEYBIND_HINT"])
    hintText:SetTextColor(0.6, 0.6, 0.6)

    --------------------------------------------------------------------------------
    -- Register with WoW Settings system
    --------------------------------------------------------------------------------
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Housing |cffFB7104Codex|r")
    Settings.RegisterAddOnCategory(category)
    self.category = category

    addon:Debug("Settings panel initialized")
end

--------------------------------------------------------------------------------
-- Open the settings panel
--------------------------------------------------------------------------------
function addon.Settings:Open()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end

--------------------------------------------------------------------------------
-- Refresh settings panel values from SavedVariables
-- Called when panel is shown or DB is reloaded
--------------------------------------------------------------------------------
function addon.Settings:Refresh()
    if not addon.db then return end

    for _, binding in ipairs(CHECKBOX_REFRESH_MAP) do
        local checkbox = self[binding.field]
        if checkbox then
            checkbox:SetChecked(addon.db.settings[binding.settingKey])
        end
    end

    if self.UpdateKeybindButtonText then
        self.UpdateKeybindButtonText()
    end
end

--------------------------------------------------------------------------------
-- Initialize Settings after data is loaded
-- This ensures SavedVariables are available
--------------------------------------------------------------------------------
addon:RegisterInternalEvent("DATA_LOADED", function()
    addon.Settings:Initialize()
end)
