--[[
    Housing Codex - WhatsNewFrame.lua
    What's New (upgrade) and Welcome (fresh install) popup frames
]]

local ADDON_NAME, addon = ...

local L = addon.L
local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS
local WN = CONSTS.WHATSNEW

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

addon.WhatsNew = {}
local WhatsNew = addon.WhatsNew

-- State
WhatsNew.frame = nil
WhatsNew.currentVariant = nil  -- "whatsnew" or "welcome"
WhatsNew.featureEntries = {}
WhatsNew.selectedIndex = nil
WhatsNew.showcaseTexture = nil
WhatsNew.checkboxChecked = false

--------------------------------------------------------------------------------
-- Version Comparison
--------------------------------------------------------------------------------

-- Parse "1.5.0" -> { 1, 5, 0 }
local function ParseVersion(versionStr)
    if not versionStr then return nil end
    local parts = {}
    for num in versionStr:gmatch("(%d+)") do
        parts[#parts + 1] = tonumber(num)
    end
    if #parts < 3 then return nil end
    return parts
end

-- Returns true if verA > verB
local function IsNewerVersion(verA, verB)
    local a = ParseVersion(verA)
    local b = ParseVersion(verB)
    if not a or not b then return false end
    for i = 1, 3 do
        if a[i] > b[i] then return true end
        if a[i] < b[i] then return false end
    end
    return false
end

-- Get the features to show for current version (features from versions newer than lastSeen)
local function GetFeaturesForUpdate(lastSeenVersion)
    local features = {}
    local latestVersion = nil

    for _, versionData in ipairs(addon.WhatsNewVersions) do
        if not lastSeenVersion or IsNewerVersion(versionData.version, lastSeenVersion) then
            if not latestVersion then
                latestVersion = versionData.version
            end
            for _, feature in ipairs(versionData.features) do
                features[#features + 1] = feature
            end
        end
    end

    return features, latestVersion
end

--------------------------------------------------------------------------------
-- ShouldShow Logic
--------------------------------------------------------------------------------

function WhatsNew:ShouldShow()
    -- Disabled: popups need polish before public release
    -- Slash commands (/hc whatsnew, /hc welcome) still work for testing via ForceShow
    return false
end

--------------------------------------------------------------------------------
-- Frame Creation
--------------------------------------------------------------------------------

local function CreateMainFrame()
    local frame = CreateFrame("Frame", "HousingCodexWhatsNewFrame", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(0, 0, 0, 0.95)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- ESC handling
    frame:SetScript("OnKeyDown", function(f, key)
        if key == "ESCAPE" then
            f:SetPropagateKeyboardInput(false)
            WhatsNew:Close()
        else
            f:SetPropagateKeyboardInput(true)
        end
    end)
    frame:EnableKeyboard(true)

    -- Add to UISpecialFrames only once (frame is recreated each Build)
    local found = false
    for _, name in ipairs(UISpecialFrames) do
        if name == "HousingCodexWhatsNewFrame" then
            found = true
            break
        end
    end
    if not found then
        tinsert(UISpecialFrames, "HousingCodexWhatsNewFrame")
    end

    return frame
end

--------------------------------------------------------------------------------
-- Header
--------------------------------------------------------------------------------

local function CreateHeader(frame)
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 3, -3)
    header:SetPoint("TOPRIGHT", -3, -3)
    header:SetHeight(WN.HEADER_HEIGHT)

    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.1, 0.95)

    -- HC icon
    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT", 14, 0)
    icon:SetTexture("Interface\\AddOns\\HousingCodex\\HC")
    frame.headerIcon = icon

    -- Title text
    local title = addon:CreateFontString(header, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    title:SetTextColor(0.9, 0.85, 0.5, 1)
    frame.headerTitle = title

    -- Subtitle (Welcome only)
    local subtitle = addon:CreateFontString(header, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("LEFT", title, "RIGHT", 10, 0)
    subtitle:SetTextColor(0.7, 0.7, 0.7, 1)
    subtitle:Hide()
    frame.headerSubtitle = subtitle

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function()
        WhatsNew:Close()
    end)

    return header
end

--------------------------------------------------------------------------------
-- Feature List (left column in What's New)
--------------------------------------------------------------------------------

local function CreateFeatureEntry(parent, index, feature, hasImage)
    local L = addon.L
    local entry = CreateFrame("Frame", nil, parent)
    entry:SetHeight(1)  -- Auto-sized by content

    -- Accent bar (hidden by default, shown on hover/select)
    local accent = entry:CreateTexture(nil, "ARTWORK")
    accent:SetWidth(WN.ACCENT_BAR_WIDTH)
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetColorTexture(unpack(COLORS.GOLD))
    accent:Hide()
    entry.accent = accent

    -- Hover background
    local hoverBg = entry:CreateTexture(nil, "BACKGROUND")
    hoverBg:SetAllPoints()
    hoverBg:SetColorTexture(0.1, 0.1, 0.12, 0)
    entry.hoverBg = hoverBg

    -- Title
    local title = addon:CreateFontString(entry, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", WN.ACCENT_BAR_WIDTH + WN.ENTRY_PADDING, -WN.ENTRY_PADDING)
    title:SetPoint("RIGHT", -WN.ENTRY_PADDING, 0)
    title:SetJustifyH("LEFT")
    title:SetText(L[feature.titleKey] or feature.titleKey)
    title:SetTextColor(unpack(COLORS.GOLD))
    entry.title = title

    -- Description
    local desc = addon:CreateFontString(entry, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("RIGHT", -WN.ENTRY_PADDING, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText(L[feature.descKey] or feature.descKey)
    desc:SetTextColor(0.9, 0.9, 0.9, 1)
    entry.desc = desc

    -- Mouse interaction
    entry:EnableMouse(true)
    entry:SetScript("OnEnter", function()
        if WhatsNew.selectedIndex ~= index then
            hoverBg:SetColorTexture(0.1, 0.1, 0.12, 0.6)
        end
        if hasImage and feature.image then
            WhatsNew:SetShowcaseImage(feature.image)
        end
        WhatsNew:SelectFeature(index)
    end)

    entry:SetScript("OnLeave", function()
        if WhatsNew.selectedIndex ~= index then
            hoverBg:SetColorTexture(0.1, 0.1, 0.12, 0)
        end
    end)

    return entry
end

-- Calculate entry height after text layout
local function LayoutFeatureEntry(entry)
    local titleH = entry.title:GetStringHeight() or 14
    local descH = entry.desc:GetStringHeight() or 14
    local totalH = WN.ENTRY_PADDING + titleH + 4 + descH + WN.ENTRY_PADDING
    entry:SetHeight(totalH)
    return totalH
end

--------------------------------------------------------------------------------
-- Welcome Feature Grid (2-column layout)
--------------------------------------------------------------------------------

local function CreateWelcomeFeatureGrid(parent)
    local L = addon.L
    local features = addon.WelcomeFeatures
    if not features then return end

    -- Use Welcome width for column calculation (parent may not have width yet)
    local parentWidth = WN.WELCOME_WIDTH - 6  -- minus border insets
    local colWidth = (parentWidth - 40) / 2  -- 2 columns with padding

    local entries = {}

    -- Create left and right column anchor frames
    for i, feature in ipairs(features) do
        local isLeftCol = (i % 2 == 1)
        local colX = isLeftCol and 16 or (colWidth + 24)

        local entry = CreateFrame("Frame", nil, parent)
        entry:SetWidth(colWidth)

        -- Title
        local title = addon:CreateFontString(entry, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 0, 0)
        title:SetPoint("RIGHT", -8, 0)
        title:SetJustifyH("LEFT")
        title:SetText(L[feature.titleKey] or feature.titleKey)
        title:SetTextColor(unpack(COLORS.GOLD))
        entry.title = title

        -- Description
        local desc = addon:CreateFontString(entry, "OVERLAY", "GameFontHighlight")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        desc:SetPoint("RIGHT", -8, 0)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetText(L[feature.descKey] or feature.descKey)
        desc:SetTextColor(0.9, 0.9, 0.9, 1)
        entry.desc = desc

        entry.colX = colX
        entries[#entries + 1] = entry
    end

    -- Layout pass (deferred for string height measurement)
    C_Timer.After(0, function()
        local rowY = -10
        local maxRowHeight = 0

        for i, entry in ipairs(entries) do
            local isLeftCol = (i % 2 == 1)

            if isLeftCol and i > 1 then
                rowY = rowY - maxRowHeight - WN.ENTRY_SPACING
                maxRowHeight = 0
            end

            entry:ClearAllPoints()
            entry:SetPoint("TOPLEFT", parent, "TOPLEFT", entry.colX, rowY)

            local titleH = entry.title:GetStringHeight() or 14
            local descH = entry.desc:GetStringHeight() or 14
            local entryH = titleH + 4 + descH
            entry:SetHeight(entryH)

            if entryH > maxRowHeight then
                maxRowHeight = entryH
            end
        end
    end)

    return entries
end

--------------------------------------------------------------------------------
-- Footer
--------------------------------------------------------------------------------

local function CreateFooter(frame, variant)
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", 3, 3)
    footer:SetPoint("BOTTOMRIGHT", -3, 3)
    footer:SetHeight(WN.FOOTER_HEIGHT)

    local bg = footer:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.06, 0.08, 0.95)

    -- Top border
    local border = footer:CreateTexture(nil, "ARTWORK")
    border:SetHeight(1)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetPoint("TOPRIGHT", 0, 0)
    border:SetColorTexture(0.25, 0.25, 0.25, 1)

    if variant == "whatsnew" then
        -- Checkbox: "Don't show this again for v1.5.0"
        local check = CreateFrame("CheckButton", nil, footer, "UICheckButtonTemplate")
        check:SetPoint("LEFT", 12, 0)
        check:SetSize(22, 22)
        check.Text:SetFontObject(GameFontNormalSmall)
        check.Text:SetText(string.format(L["WHATSNEW_DONT_SHOW"], addon.version))
        check.Text:SetTextColor(0.7, 0.7, 0.7, 1)
        check:SetScript("OnClick", function(self)
            WhatsNew.checkboxChecked = self:GetChecked()
        end)
        frame.dontShowCheckbox = check

        -- "Explore Housing Codex" button (gold tinted)
        local btn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
        btn:SetPoint("RIGHT", -14, 0)
        btn:SetSize(180, 28)
        btn:SetText(L["WHATSNEW_EXPLORE"])
        btn:SetScript("OnClick", function()
            WhatsNew:OnExploreClick()
        end)
        frame.exploreButton = btn
    else
        -- Welcome variant: "Start Exploring" centered button
        local btn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
        btn:SetPoint("CENTER", 0, 0)
        btn:SetSize(180, 28)
        btn:SetText(L["WELCOME_START"])
        btn:SetScript("OnClick", function()
            WhatsNew:OnStartExploringClick()
        end)
        frame.startButton = btn
    end

    return footer
end

--------------------------------------------------------------------------------
-- Showcase Image (right column in What's New)
--------------------------------------------------------------------------------

local function CreateShowcase(frame)
    local showcase = CreateFrame("Frame", nil, frame)
    frame.showcase = showcase

    -- Image texture
    local img = showcase:CreateTexture(nil, "ARTWORK")
    img:SetAllPoints()
    img:SetTexCoord(0, 1, 0, 1)
    frame.showcaseImage = img

    -- Placeholder text (when no image available)
    local placeholder = addon:CreateFontString(showcase, "OVERLAY", "GameFontNormal")
    placeholder:SetPoint("CENTER")
    placeholder:SetText("Screenshot")
    placeholder:SetTextColor(0.4, 0.4, 0.4, 1)
    frame.showcasePlaceholder = placeholder

    return showcase
end

--------------------------------------------------------------------------------
-- Welcome: Quick Setup Row
--------------------------------------------------------------------------------

local function CreateQuickSetupRow(frame, contentArea)
    local setupRow = CreateFrame("Frame", nil, contentArea)
    setupRow:SetPoint("BOTTOMLEFT", 0, 0)
    setupRow:SetPoint("BOTTOMRIGHT", 0, 0)
    setupRow:SetHeight(44)

    -- Background
    local bg = setupRow:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.06, 0.08, 0.8)

    -- Top border
    local border = setupRow:CreateTexture(nil, "ARTWORK")
    border:SetHeight(1)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetPoint("TOPRIGHT", 0, 0)
    border:SetColorTexture(0.25, 0.25, 0.25, 1)

    -- "Quick Setup" label
    local label = addon:CreateFontString(setupRow, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 16, 0)
    label:SetText(L["WELCOME_QUICK_SETUP"])
    label:SetTextColor(unpack(COLORS.GOLD))

    -- "Open with: /hc"
    local openLabel = addon:CreateFontString(setupRow, "OVERLAY", "GameFontHighlight")
    openLabel:SetPoint("LEFT", label, "RIGHT", 20, 0)
    openLabel:SetText(L["WELCOME_OPEN_WITH"])
    openLabel:SetTextColor(0.8, 0.8, 0.8, 1)

    local openValue = addon:CreateFontString(setupRow, "OVERLAY", "GameFontHighlight")
    openValue:SetPoint("LEFT", openLabel, "RIGHT", 6, 0)
    openValue:SetText("|cFFFFD100/hc|r")

    -- "Set keybind: [Click to bind]"
    local keybindLabel = addon:CreateFontString(setupRow, "OVERLAY", "GameFontHighlight")
    keybindLabel:SetPoint("LEFT", openValue, "RIGHT", 30, 0)
    keybindLabel:SetText(L["WELCOME_SET_KEYBIND"])
    keybindLabel:SetTextColor(0.8, 0.8, 0.8, 1)

    -- Keybind capture button
    local keybindBtn = CreateFrame("Button", nil, setupRow, "UIPanelButtonTemplate")
    keybindBtn:SetPoint("LEFT", keybindLabel, "RIGHT", 8, 0)
    keybindBtn:SetSize(120, 22)
    keybindBtn:RegisterForClicks("AnyUp")

    local function UpdateKeybindText()
        local displayText = addon.GetKeybindDisplayText()
        keybindBtn:SetText(displayText or L["OPTIONS_NOT_BOUND"])
    end
    UpdateKeybindText()
    frame.updateKeybindText = UpdateKeybindText

    local function StopKeyCapture(btn)
        btn:EnableKeyboard(false)
        btn:SetScript("OnKeyDown", nil)
        UpdateKeybindText()
    end

    local function OnKeyCaptured(btn, key)
        if addon.MODIFIER_KEYS[key] then return end

        if key == "ESCAPE" then
            StopKeyCapture(btn)
            return
        end

        local modifiers = {}
        if IsAltKeyDown() then modifiers[#modifiers + 1] = "ALT" end
        if IsControlKeyDown() then modifiers[#modifiers + 1] = "CTRL" end
        if IsShiftKeyDown() then modifiers[#modifiers + 1] = "SHIFT" end
        modifiers[#modifiers + 1] = key

        local fullKey = table.concat(modifiers, "-")

        local existingKey = addon.GetCurrentKeybind()
        if existingKey then
            SetBinding(existingKey, nil)
        end

        SetBinding(fullKey, addon.BINDING_ACTION)
        SaveBindings(GetCurrentBindingSet())

        StopKeyCapture(btn)
    end

    keybindBtn:SetScript("OnClick", function(btn, button)
        if button == "RightButton" then
            local key1, key2 = GetBindingKey(addon.BINDING_ACTION)
            if key1 then SetBinding(key1, nil) end
            if key2 then SetBinding(key2, nil) end
            if key1 or key2 then
                SaveBindings(GetCurrentBindingSet())
            end
            UpdateKeybindText()
        else
            btn:SetText(L["OPTIONS_PRESS_KEY"])
            btn:EnableKeyboard(true)
            btn:SetScript("OnKeyDown", OnKeyCaptured)
        end
    end)

    return setupRow
end

--------------------------------------------------------------------------------
-- Build Popup (variant = "whatsnew" or "welcome")
--------------------------------------------------------------------------------

function WhatsNew:Build(variant)
    if self.frame then
        self.frame:Hide()
        self.frame:SetParent(nil)
        self.frame = nil
    end

    self.currentVariant = variant
    self.featureEntries = {}
    self.selectedIndex = nil
    self.checkboxChecked = false

    local frame = CreateMainFrame()
    self.frame = frame

    -- Size and position based on variant
    if variant == "welcome" then
        frame:SetSize(WN.WELCOME_WIDTH, WN.WELCOME_HEIGHT)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    else
        frame:SetSize(WN.WIDTH, WN.HEIGHT)
        local offset = -(GetScreenWidth() * 0.12)
        frame:SetPoint("CENTER", UIParent, "CENTER", offset, 30)
    end

    -- Header
    local header = CreateHeader(frame)

    if variant == "welcome" then
        frame.headerTitle:SetText(L["WELCOME_TITLE"])
        frame.headerSubtitle:SetText(L["WELCOME_SUBTITLE"])
        frame.headerSubtitle:Show()
    else
        frame.headerTitle:SetText(L["WHATSNEW_TITLE"])
        frame.headerSubtitle:Hide()
    end

    -- Footer
    CreateFooter(frame, variant)

    -- Content area (between header and footer)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", -3, 3 + WN.FOOTER_HEIGHT)
    frame.contentArea = content

    if variant == "whatsnew" then
        self:BuildWhatsNewContent(content)
    else
        self:BuildWelcomeContent(content, frame)
    end
end

function WhatsNew:BuildWhatsNewContent(content)
    local features, latestVersion = GetFeaturesForUpdate(
        addon.db and addon.db.whatsNew and addon.db.whatsNew.lastSeenVersion
    )

    -- Use all features from latest version if no specific update features
    if #features == 0 and addon.WhatsNewVersions[1] then
        features = addon.WhatsNewVersions[1].features
        latestVersion = addon.WhatsNewVersions[1].version
    end

    -- Left column: feature list (use known frame width for initial sizing)
    local featureList = CreateFrame("Frame", nil, content)
    featureList:SetPoint("TOPLEFT", 0, 0)
    featureList:SetPoint("BOTTOMLEFT", 0, 0)
    local contentWidth = WN.WIDTH - 6  -- frame width minus border insets
    featureList:SetWidth(contentWidth * WN.FEATURE_LIST_RATIO)
    self.frame.featureList = featureList

    -- Right column: showcase image
    local showcase = CreateShowcase(self.frame)
    showcase:SetPoint("TOPLEFT", featureList, "TOPRIGHT", 0, -8)
    showcase:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 8)

    -- Lay out feature entries
    local yOffset = -8
    local hasImages = false

    for i, feature in ipairs(features) do
        if feature.image then hasImages = true end

        local entry = CreateFeatureEntry(featureList, i, feature, hasImages)
        entry:SetPoint("TOPLEFT", WN.ENTRY_PADDING, yOffset)
        entry:SetPoint("RIGHT", featureList, "RIGHT", -WN.ENTRY_PADDING, 0)

        -- Defer height calculation until text can be measured
        self.featureEntries[i] = { entry = entry, feature = feature }
    end

    -- Layout pass: calculate entry heights after anchoring
    -- (need a frame delay for string measurement to work)
    C_Timer.After(0, function()
        if not self.frame or not self.frame:IsShown() then return end
        local y = -8
        for i, data in ipairs(self.featureEntries) do
            data.entry:ClearAllPoints()
            data.entry:SetPoint("TOPLEFT", featureList, "TOPLEFT", WN.ENTRY_PADDING, y)
            data.entry:SetPoint("RIGHT", featureList, "RIGHT", -WN.ENTRY_PADDING, 0)
            local h = LayoutFeatureEntry(data.entry)
            y = y - h - WN.ENTRY_SPACING
        end

        -- Auto-select first feature
        if #self.featureEntries > 0 then
            self:SelectFeature(1)
        end
    end)

    -- Anchor feature list width from content
    content:SetScript("OnSizeChanged", function(_, width)
        featureList:SetWidth(width * WN.FEATURE_LIST_RATIO)
    end)
end

function WhatsNew:BuildWelcomeContent(content, frame)
    -- Welcome uses a 2-column feature grid (no image panel)
    CreateWelcomeFeatureGrid(content)

    -- Quick setup row above footer
    CreateQuickSetupRow(frame, content)
end

--------------------------------------------------------------------------------
-- Feature Selection (What's New hover)
--------------------------------------------------------------------------------

function WhatsNew:SelectFeature(index)
    -- Deselect previous
    if self.selectedIndex and self.featureEntries[self.selectedIndex] then
        local prev = self.featureEntries[self.selectedIndex].entry
        prev.accent:Hide()
        prev.hoverBg:SetColorTexture(0.1, 0.1, 0.12, 0)
    end

    self.selectedIndex = index

    -- Select new
    if index and self.featureEntries[index] then
        local current = self.featureEntries[index].entry
        current.accent:Show()
        current.hoverBg:SetColorTexture(0.1, 0.1, 0.12, 0.6)

        -- Update showcase image
        local feature = self.featureEntries[index].feature
        if feature.image then
            self:SetShowcaseImage(feature.image)
        end
    end
end

function WhatsNew:SetShowcaseImage(imagePath)
    if not self.frame or not self.frame.showcaseImage then return end

    local img = self.frame.showcaseImage
    local placeholder = self.frame.showcasePlaceholder

    -- Try to set the texture
    img:SetTexture(imagePath)

    -- If the texture is valid, show it; otherwise show placeholder
    -- (WoW doesn't provide a way to check if a texture loaded, so we always show it)
    img:Show()
    if placeholder then placeholder:Hide() end
end

--------------------------------------------------------------------------------
-- Animations
--------------------------------------------------------------------------------

local function CreateFadeInAnimation(frame)
    local ag = frame:CreateAnimationGroup()

    local alpha = ag:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(WN.ANIM_FADE_IN)
    alpha:SetSmoothing("OUT")
    alpha:SetOrder(1)

    local translate = ag:CreateAnimation("Translation")
    translate:SetOffset(0, -WN.ANIM_SLIDE_OFFSET)
    translate:SetDuration(WN.ANIM_FADE_IN)
    translate:SetSmoothing("OUT")
    translate:SetOrder(1)

    ag:SetToFinalAlpha(true)
    return ag
end

local function CreateFadeOutAnimation(frame)
    local ag = frame:CreateAnimationGroup()

    local alpha = ag:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(WN.ANIM_FADE_OUT)
    alpha:SetSmoothing("IN")
    alpha:SetOrder(1)

    ag:SetToFinalAlpha(true)
    ag:SetScript("OnFinished", function()
        frame:Hide()
    end)

    return ag
end

--------------------------------------------------------------------------------
-- Show / Close / Dismiss
--------------------------------------------------------------------------------

function WhatsNew:Show(variant)
    if InCombatLockdown() then return end

    variant = variant or "whatsnew"
    self:Build(variant)

    -- Pre-animation: set invisible
    self.frame:SetAlpha(0)
    self.frame:Show()

    -- Create and play entrance animation
    if not self.frame.fadeIn then
        self.frame.fadeIn = CreateFadeInAnimation(self.frame)
    end
    self.frame.fadeIn:Stop()
    self.frame.fadeIn:Play()

    addon:Debug("WhatsNew shown: " .. variant)
end

function WhatsNew:Close()
    if not self.frame or not self.frame:IsShown() then return end

    -- Save state before animating out
    self:SaveDismissState()

    -- Create and play exit animation
    if not self.frame.fadeOut then
        self.frame.fadeOut = CreateFadeOutAnimation(self.frame)
    end
    self.frame.fadeOut:Stop()
    self.frame.fadeOut:Play()
end

function WhatsNew:SaveDismissState()
    if not addon.db or not addon.db.whatsNew then return end
    local wn = addon.db.whatsNew

    if self.currentVariant == "welcome" then
        -- Welcome popup: always mark as seen on any close
        wn.lastSeenVersion = addon.version
        wn.dismissCount = 0
        wn.dontShowForVersion = nil
        return
    end

    -- What's New variant
    if self.checkboxChecked then
        -- Explicit suppress
        wn.dontShowForVersion = addon.version
        wn.lastSeenVersion = addon.version
    else
        -- Dismissed without checkbox
        wn.dismissCount = (wn.dismissCount or 0) + 1
        if wn.dismissCount >= WN.MAX_DISMISS_COUNT then
            -- Auto-suppress after MAX_DISMISS_COUNT closes
            wn.lastSeenVersion = addon.version
        end
    end
end

function WhatsNew:OnExploreClick()
    if not addon.db or not addon.db.whatsNew then return end

    -- Mark as seen (positive action)
    addon.db.whatsNew.lastSeenVersion = addon.version
    addon.db.whatsNew.dontShowForVersion = addon.version

    -- Close popup (no fade needed, instant)
    if self.frame then
        self.frame:Hide()
    end

    -- Open MainFrame to Progress tab
    if addon.MainFrame then
        addon.MainFrame:Show()
        if addon.Tabs then
            addon.Tabs:SelectTab("PROGRESS")
        end
    end
end

function WhatsNew:OnStartExploringClick()
    if not addon.db or not addon.db.whatsNew then return end

    -- Mark as seen
    addon.db.whatsNew.lastSeenVersion = addon.version

    -- Close popup
    if self.frame then
        self.frame:Hide()
    end

    -- Open MainFrame
    if addon.MainFrame then
        addon.MainFrame:Show()
    end
end

function WhatsNew:ForceShow(variant)
    -- Bypass all version/dismiss checks (slash command testing)
    self:Show(variant or "whatsnew")
end

--------------------------------------------------------------------------------
-- Auto-trigger on DATA_LOADED
--------------------------------------------------------------------------------

addon:RegisterInternalEvent("DATA_LOADED", function()
    -- Reset dismiss count when version changes
    if addon.db and addon.db.whatsNew then
        local wn = addon.db.whatsNew
        if wn.lastSeenVersion and wn.lastSeenVersion ~= addon.version then
            wn.dismissCount = 0
            wn.dontShowForVersion = nil
        end
    end

    C_Timer.After(WN.SHOW_DELAY, function()
        if WhatsNew:ShouldShow() then
            WhatsNew:Show()
        end
    end)
end)
