--[[
    Housing Codex - SettingsPanel.lua
    WoW native Settings UI integration (Settings > AddOns > Housing Codex)
]]

local _, addon = ...

addon.Settings = {}

-- Shared keybind helpers (defined in Init.lua)
local BINDING_ACTION = addon.BINDING_ACTION
local GetKeybindDisplayText = addon.GetKeybindDisplayText
local L = addon.L

-- Keybind conflict confirmation dialog
StaticPopupDialogs["HOUSINGCODEX_KEYBIND_CONFLICT"] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(dialog, data)
        if InCombatLockdown() then return end
        local key1, key2 = GetBindingKey(BINDING_ACTION)
        if key1 then SetBinding(key1, nil) end
        if key2 then SetBinding(key2, nil) end
        SetBinding(data.fullKey, BINDING_ACTION)
        -- Preserve secondary binding (Blizzard RebindKeysInOrder pattern)
        if key2 and key2 ~= data.fullKey then
            SetBinding(key2, BINDING_ACTION)
        end
        SaveBindings(GetCurrentBindingSet())
        if data.updateFunc then data.updateFunc() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

--------------------------------------------------------------------------------
-- Helper: Create checkbox with tooltip
--------------------------------------------------------------------------------
local function CreateCheckbox(parent, label, tooltip, getValue, setValue)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check.Text:SetFontObject(addon:GetFontObject("GameFontNormal"))
    addon:RegisterFontString(check.Text, "GameFontNormal")
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
local SECTION_GAP = 20  -- vertical gap before each section header

local function CreateSectionHeader(parent, text, yOffset)
    local label = addon:CreateFontString(parent, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 16, yOffset)
    label:SetText(text)
    label:SetTextColor(1, 1, 1)

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("LEFT", label, "RIGHT", 8, 0)
    divider:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    divider:SetColorTexture(0.3, 0.3, 0.35, 0.6)

    return label
end

local function CreateResetButton(parent, labelKey, tooltipKey, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(160, 24)
    btn:SetText(L[labelKey])
    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[tooltipKey])
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return btn
end

--------------------------------------------------------------------------------
-- Settings Panel Initialization
--------------------------------------------------------------------------------
function addon.Settings:Initialize()
    if self.panel then return end

    -- Create the settings panel frame
    local panel = CreateFrame("Frame", "HousingCodexSettingsPanel", UIParent)
    panel.name = L["ADDON_NAME"]
    self.panel = panel

    -- Title icon
    local titleIcon = panel:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(24, 24)
    titleIcon:SetPoint("TOPLEFT", 16, -16)
    titleIcon:SetTexture("Interface\\AddOns\\HousingCodex\\HC64")

    -- Title text
    local title = addon:CreateFontString(panel, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleIcon, "RIGHT", 6, 0)
    title:SetText(L["ADDON_NAME"])
    title:SetTextColor(1, 0.82, 0)
    addon:SetFontSize(title, 16)

    local yOffset = -50
    local COL1_X = 16
    local COL2_X = 300

    --------------------------------------------------------------------------------
    -- DISPLAY SECTION
    --------------------------------------------------------------------------------
    CreateSectionHeader(panel, L["OPTIONS_SECTION_DISPLAY"], yOffset)
    yOffset = yOffset - 20

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
    collectedCheck:SetPoint("TOPLEFT", COL1_X, yOffset)
    self.collectedCheck = collectedCheck

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
    yOffset = yOffset - 26

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
    yOffset = yOffset - 26

    --------------------------------------------------------------------------------
    -- KEYBIND SECTION
    --------------------------------------------------------------------------------
    yOffset = yOffset - SECTION_GAP
    CreateSectionHeader(panel, L["OPTIONS_SECTION_KEYBIND"], yOffset)
    yOffset = yOffset - 20

    -- Keybind label
    local keybindLabel = addon:CreateFontString(panel, "ARTWORK", "GameFontNormal")
    keybindLabel:SetPoint("TOPLEFT", 16, yOffset)
    keybindLabel:SetText(L["OPTIONS_TOGGLE_KEYBIND"])
    keybindLabel:SetTextColor(1, 0.82, 0)

    -- Keybind button
    local keybindBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    keybindBtn:SetPoint("LEFT", keybindLabel, "RIGHT", 10, 0)
    keybindBtn:SetSize(140, 28)
    keybindBtn:RegisterForClicks("AnyUp")
    self.keybindBtn = keybindBtn

    -- Hint text (inline, right of keybind button)
    local hintText = addon:CreateFontString(panel, "ARTWORK", "GameFontNormalSmall")
    hintText:SetPoint("LEFT", keybindBtn, "RIGHT", 12, 0)
    hintText:SetText(L["OPTIONS_KEYBIND_HINT"])
    hintText:SetTextColor(0.6, 0.6, 0.6)

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

    -- Apply a keybind (no conflict check)
    local function ApplyKeybind(fullKey)
        local key1, key2 = GetBindingKey(BINDING_ACTION)
        if key1 then SetBinding(key1, nil) end
        if key2 then SetBinding(key2, nil) end
        SetBinding(fullKey, BINDING_ACTION)
        -- Preserve secondary binding (Blizzard RebindKeysInOrder pattern)
        if key2 and key2 ~= fullKey then
            SetBinding(key2, BINDING_ACTION)
        end
        SaveBindings(GetCurrentBindingSet())
        UpdateKeybindButtonText()
        addon:Debug("Keybind set via standard system: " .. fullKey)
    end

    -- Handle key press during capture
    local function OnKeyCaptured(btn, key)
        if addon.MODIFIER_KEYS[key] then return end

        if key == "ESCAPE" or InCombatLockdown() then
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

        StopKeyCapture(btn)

        -- Check for conflict with existing binding
        local existingAction = GetBindingAction(fullKey)
        if existingAction and existingAction ~= "" and existingAction ~= BINDING_ACTION then
            local existingName = GetBindingName(existingAction)
            local keyDisplay = GetBindingText(fullKey)
            local msg = L["OPTIONS_KEYBIND_CONFLICT"]:format(keyDisplay, existingName)
            StaticPopup_Show("HOUSINGCODEX_KEYBIND_CONFLICT", msg, nil, { fullKey = fullKey, updateFunc = UpdateKeybindButtonText })
            return
        end

        ApplyKeybind(fullKey)
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
            if InCombatLockdown() then return end
            -- Unbind both primary and secondary from standard WoW system
            local key1, key2 = GetBindingKey(BINDING_ACTION)
            if key1 then SetBinding(key1, nil) end
            if key2 then SetBinding(key2, nil) end
            if key1 or key2 then
                SaveBindings(GetCurrentBindingSet())
                addon:Debug("Keybind cleared via standard system")
            end
            UpdateKeybindButtonText()
            GameTooltip:Hide()
        else
            if InCombatLockdown() then return end
            btn:SetText(L["OPTIONS_PRESS_KEY"])
            btn:EnableKeyboard(true)
            btn:SetScript("OnKeyDown", OnKeyCaptured)
        end
    end)

    -- Clean up keybind capture mode when Settings panel closes
    panel:SetScript("OnHide", function()
        StopKeyCapture(keybindBtn)
    end)

    yOffset = yOffset - 26

    --------------------------------------------------------------------------------
    -- MAP & NAVIGATION SECTION
    --------------------------------------------------------------------------------
    yOffset = yOffset - SECTION_GAP
    CreateSectionHeader(panel, L["OPTIONS_SECTION_MAP_NAV"], yOffset)
    yOffset = yOffset - 20

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
    yOffset = yOffset - 26

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

    -- TomTom Waypoints checkbox (state updates dynamically — TomTom detection runs after Settings init)
    local tomtomCheck = CreateCheckbox(
        panel,
        L["OPTIONS_USE_TOMTOM_NOT_INSTALLED"],
        L["OPTIONS_USE_TOMTOM_TOOLTIP"],
        function() return addon.db and addon.db.settings.useTomTom end,
        function(checked)
            if addon.db then
                addon.db.settings.useTomTom = checked
            end
        end
    )
    tomtomCheck:SetPoint("TOPLEFT", COL2_X, yOffset)
    tomtomCheck:Disable()
    tomtomCheck.Text:SetTextColor(0.5, 0.5, 0.5)
    self.tomtomCheck = tomtomCheck

    local function UpdateTomTomState()
        local available = addon.Waypoints and addon.Waypoints:IsTomTomAvailable()
        if available then
            tomtomCheck:Enable()
            tomtomCheck.Text:SetText(L["OPTIONS_USE_TOMTOM"])
            tomtomCheck.Text:SetTextColor(1, 0.82, 0)
        else
            tomtomCheck:Disable()
            tomtomCheck.Text:SetText(L["OPTIONS_USE_TOMTOM_NOT_INSTALLED"])
            tomtomCheck.Text:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    self.UpdateTomTomState = UpdateTomTomState
    yOffset = yOffset - 26

    --------------------------------------------------------------------------------
    -- VENDOR SECTION
    --------------------------------------------------------------------------------
    yOffset = yOffset - SECTION_GAP
    CreateSectionHeader(panel, L["OPTIONS_SECTION_VENDOR"], yOffset)
    yOffset = yOffset - 20

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
                    if not checked then
                        addon.MerchantOverlay:HideAllOverlays()
                    end
                    addon.MerchantOverlay:UpdateMerchantButtons()
                end
            end
        end
    )
    vendorOwnedCheck:SetPoint("TOPLEFT", COL2_X, yOffset)
    self.vendorOwnedCheck = vendorOwnedCheck
    yOffset = yOffset - 26

    -- Show Vendor Tooltips checkbox
    local vendorTooltipsCheck = CreateCheckbox(
        panel,
        L["OPTIONS_VENDOR_TOOLTIPS"],
        L["OPTIONS_VENDOR_TOOLTIPS_TOOLTIP"],
        function() return addon.db and addon.db.settings.showVendorTooltips end,
        function(checked)
            if addon.db then
                addon.db.settings.showVendorTooltips = checked
            end
        end
    )
    vendorTooltipsCheck:SetPoint("TOPLEFT", COL1_X, yOffset)
    self.vendorTooltipsCheck = vendorTooltipsCheck
    yOffset = yOffset - 26

    --------------------------------------------------------------------------------
    -- BAGS & BANK SECTION
    --------------------------------------------------------------------------------
    yOffset = yOffset - SECTION_GAP
    CreateSectionHeader(panel, L["OPTIONS_SECTION_CONTAINERS"], yOffset)
    yOffset = yOffset - 20

    -- Show Container Decor Indicators checkbox
    local containerCheck = CreateCheckbox(
        panel,
        L["OPTIONS_CONTAINER_INDICATORS"],
        L["OPTIONS_CONTAINER_INDICATORS_TOOLTIP"],
        function() return addon.db and addon.db.settings.showContainerDecorIndicators end,
        function(checked)
            if addon.db then
                addon.db.settings.showContainerDecorIndicators = checked
                if addon.ContainerOverlay then
                    if checked then
                        addon.ContainerOverlay:UpdateAllContainerFrames()
                    else
                        addon.ContainerOverlay:HideAllOverlays()
                    end
                end
            end
        end
    )
    containerCheck:SetPoint("TOPLEFT", COL1_X, yOffset)
    self.containerCheck = containerCheck

    -- Show Container Owned Checkmark checkbox
    local containerOwnedCheck = CreateCheckbox(
        panel,
        L["OPTIONS_CONTAINER_OWNED_CHECKMARK"],
        L["OPTIONS_CONTAINER_OWNED_CHECKMARK_TOOLTIP"],
        function() return addon.db and addon.db.settings.showContainerOwnedCheckmark end,
        function(checked)
            if addon.db then
                addon.db.settings.showContainerOwnedCheckmark = checked
                if addon.ContainerOverlay then
                    addon.ContainerOverlay:UpdateAllContainerFrames()
                end
            end
        end
    )
    containerOwnedCheck:SetPoint("TOPLEFT", COL2_X, yOffset)
    self.containerOwnedCheck = containerOwnedCheck
    yOffset = yOffset - 26

    --------------------------------------------------------------------------------
    -- ENDEAVORS SECTION
    --------------------------------------------------------------------------------
    yOffset = yOffset - SECTION_GAP
    CreateSectionHeader(panel, L["OPTIONS_SECTION_ENDEAVORS"], yOffset)
    yOffset = yOffset - 20

    local endeavorsEnabledCheck = CreateCheckbox(
        panel,
        L["OPTIONS_ENDEAVORS_ENABLED"],
        L["OPTIONS_ENDEAVORS_ENABLED_TOOLTIP"],
        function() return addon.db and addon.db.endeavors and addon.db.endeavors.enabled end,
        function(checked)
            if addon.db and addon.db.endeavors then
                addon.db.endeavors.enabled = checked
                if addon.EndeavorsPanel and addon.EndeavorsData then
                    if checked then
                        addon.EndeavorsData:RecheckNeighborhoodZone()
                        addon.EndeavorsPanel:TryShow()
                    else
                        addon.EndeavorsPanel:TryHide()
                    end
                end
            end
        end
    )
    endeavorsEnabledCheck:SetPoint("TOPLEFT", COL1_X, yOffset)
    self.endeavorsEnabledCheck = endeavorsEnabledCheck

    local endeavorsBtn = CreateResetButton(panel, "ENDEAVORS_OPTIONS", "ENDEAVORS_OPTIONS_TOOLTIP", function(self)
        if addon.EndeavorsPanel then
            addon.EndeavorsPanel:OpenConfigFromSettings(self)
        end
    end)
    endeavorsBtn:SetPoint("LEFT", endeavorsEnabledCheck, "RIGHT", 140, 0)
    yOffset = yOffset - 26

    --------------------------------------------------------------------------------
    -- TROUBLESHOOTING SECTION
    --------------------------------------------------------------------------------
    yOffset = yOffset - SECTION_GAP
    CreateSectionHeader(panel, L["OPTIONS_SECTION_TROUBLESHOOTING"], yOffset)
    yOffset = yOffset - 20

    -- Reset Position button
    local resetPosBtn = CreateResetButton(panel, "OPTIONS_RESET_POSITION", "OPTIONS_RESET_POSITION_TOOLTIP", function()
        if addon.MainFrame then
            addon.MainFrame:ResetPosition()
        end
    end)
    resetPosBtn:SetPoint("TOPLEFT", 16, yOffset)

    -- Reset Size button
    local resetSizeBtn = CreateResetButton(panel, "OPTIONS_RESET_SIZE", "OPTIONS_RESET_SIZE_TOOLTIP", function()
        if addon.MainFrame then
            addon.MainFrame:ResetSize()
        end
    end)
    resetSizeBtn:SetPoint("LEFT", resetPosBtn, "RIGHT", 10, 0)

    -- Welcome Screen button
    local welcomeBtn = CreateResetButton(panel, "OPTIONS_SHOW_WELCOME", "OPTIONS_SHOW_WELCOME_TOOLTIP", function()
        if addon.WhatsNew then
            addon.WhatsNew:ForceShow("welcome")
        end
    end)
    welcomeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, yOffset)

    --------------------------------------------------------------------------------
    -- Register with WoW Settings system
    --------------------------------------------------------------------------------
    local category = Settings.RegisterCanvasLayoutCategory(panel, L["SETTINGS_CATEGORY_NAME"])
    Settings.RegisterAddOnCategory(category)
    self.category = category

    -- Resync all checkbox states when the settings panel is shown
    -- (Blizzard calls panel.OnRefresh via securecallfunction each time the category is displayed)
    local settings = self
    panel.OnRefresh = function()
        local db = addon.db
        if not db then return end
        local s = db.settings
        if not s then return end
        settings.collectedCheck:SetChecked(s.showCollectedIndicator)
        settings.autoRotateCheck:SetChecked(s.autoRotatePreview)
        settings.minimapCheck:SetChecked(s.showMinimapButton)
        settings.vendorMapPinsCheck:SetChecked(s.showVendorMapPins)
        settings.zoneOverlayCheck:SetChecked(s.showZoneOverlay)
        settings.treasureHuntCheck:SetChecked(s.treasureHuntWaypoints)
        settings.tomtomCheck:SetChecked(s.useTomTom)
        settings.vendorCheck:SetChecked(s.showVendorDecorIndicators)
        settings.vendorOwnedCheck:SetChecked(s.showVendorOwnedCheckmark)
        settings.vendorTooltipsCheck:SetChecked(s.showVendorTooltips)
        settings.containerCheck:SetChecked(s.showContainerDecorIndicators)
        settings.containerOwnedCheck:SetChecked(s.showContainerOwnedCheckmark)
        settings.endeavorsEnabledCheck:SetChecked(db.endeavors and db.endeavors.enabled)
        UpdateKeybindButtonText()
    end

    -- Update TomTom state once detection has run (DATA_LOADED fires after ADDON_LOADED)
    addon:RegisterInternalEvent("DATA_LOADED", UpdateTomTomState)

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

