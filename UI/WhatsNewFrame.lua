--[[
    Housing Codex - WhatsNewFrame.lua
    What's New (upgrade) and Welcome (fresh install) popup frames
]]

local _, addon = ...

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
WhatsNew.checkboxChecked = false

-- Typewriter animation state (What's New description text)
local twDriver          -- child frame driving OnUpdate
local twFullText = ""   -- complete description string to reveal
local twDescFS          -- FontString being animated
local twElapsed = 0     -- running clock
local twActive = false  -- guard against stale OnUpdate firing
local TW_CHARS_PER_SEC = 40
local StopTypewriter    -- forward declarations (defined after Build, called before)
local StartTypewriter

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

-- Returns the variant to auto-show ("welcome"), or nil if nothing should show.
-- Slash commands (/hc whatsnew, /hc welcome) bypass this via ForceShow.
function WhatsNew:ShouldShow()
    local wn = addon.db and addon.db.whatsNew
    if wn and not wn.hasSeenWelcome then
        return "welcome"
    end
    return nil
end

--------------------------------------------------------------------------------
-- Frame Creation
--------------------------------------------------------------------------------

function WhatsNew:EnsureFrame()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "HousingCodexWhatsNewFrame", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
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

    -- Safety net: mark welcome as seen no matter how the frame is hidden
    -- (UISpecialFrames ESC, /hc toggle, keybind, etc.)
    frame:SetScript("OnHide", function()
        StopTypewriter()
        if WhatsNew.currentVariant == "welcome" and addon.db and addon.db.whatsNew then
            addon.db.whatsNew.hasSeenWelcome = true
        end
    end)

    tinsert(UISpecialFrames, "HousingCodexWhatsNewFrame")

    self.frame = frame
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

    -- Drag handle
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.1, 0.95)

    -- HC icon
    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(48, 48)
    icon:SetPoint("LEFT", 14, 0)
    icon:SetTexture("Interface\\AddOns\\HousingCodex\\HC")
    frame.headerIcon = icon

    -- Title text
    local title = addon:CreateFontString(header, "OVERLAY", "GameFont_Gigantic") -- The largest standard native font
    title:SetPoint("LEFT", icon, "RIGHT", 14, 0)
    title:SetTextColor(0.9, 0.85, 0.5, 1)
    frame.headerTitle = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function()
        WhatsNew:Close()
    end)

    -- Subtitle (Welcome only)
    local subtitle = addon:CreateFontString(header, "OVERLAY", "GameFontNormalLarge")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    subtitle:SetPoint("RIGHT", header, "RIGHT", -12, 0)
    subtitle:SetJustifyH("RIGHT")
    subtitle:SetTextColor(0.7, 0.7, 0.7, 1)
    subtitle:Hide()
    frame.headerSubtitle = subtitle

    return header
end

--------------------------------------------------------------------------------
-- Feature List (left column in What's New)
--------------------------------------------------------------------------------

local function CreateFeatureEntry(parent, index, feature, hasImage)
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
    local descText = L[feature.descKey] or feature.descKey
    desc:SetText(descText)
    desc:SetTextColor(0.9, 0.9, 0.9, 1)
    entry.desc = desc
    entry.descText = descText

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
-- Welcome Feature Grid (3x2 modern card layout)
--------------------------------------------------------------------------------

local function CreateWelcomeFeatureGrid(parent)
    local features = addon.WelcomeFeatures
    if not features then return end

    local entries = {}
    local COLUMNS = 3
    local ROWS = 2

    -- Determine width for 3 columns inside the welcome frame
    local parentWidth = WN.WELCOME_WIDTH - 12 -- margins
    local cardGap = 16
    local colWidth = (parentWidth - (cardGap * (COLUMNS + 1))) / COLUMNS
    local cardHeight = 139

    -- Cards positioned below the top of contentArea, above the quick setup row
    local startY = -32
    local startX = cardGap

    for i, feature in ipairs(features) do
        if i > COLUMNS * ROWS then break end

        local col = (i - 1) % COLUMNS
        local row = math.floor((i - 1) / COLUMNS)

        local colX = startX + (col * (colWidth + cardGap))
        local rowY = startY - (row * (cardHeight + cardGap))

        local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        card:SetSize(colWidth, cardHeight)
        card:SetPoint("TOPLEFT", parent, "TOPLEFT", colX, rowY)

        card:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        card:SetBackdropColor(0.12, 0.12, 0.14, 0.95)
        card:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

        -- Top accent bar (Gold) - used as a sweep highlight
        local accent = card:CreateTexture(nil, "OVERLAY")
        accent:SetPoint("TOPLEFT", 4, -4)
        accent:SetPoint("TOPRIGHT", -4, -4)
        accent:SetHeight(4)
        accent:SetColorTexture(unpack(COLORS.GOLD))
        accent:SetAlpha(0.15)
        card.accent = accent

        -- Title (GameFontNormalLarge base +2pt)
        local title = addon:CreateFontString(card, "OVERLAY", "GameFontNormalLarge")
        addon:SetFontSize(title, 17)
        title:SetPoint("TOPLEFT", 14, -16)
        title:SetPoint("RIGHT", -14, 0)
        title:SetJustifyH("LEFT")
        title:SetText(L[feature.titleKey] or feature.titleKey)
        title:SetTextColor(unpack(COLORS.GOLD))
        card.title = title

        -- Description (GameFontHighlight base +1pt, slightly dimmer)
        local desc = addon:CreateFontString(card, "OVERLAY", "GameFontHighlight")
        addon:SetFontSize(desc, 15)
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        desc:SetPoint("BOTTOMRIGHT", -14, 10)
        desc:SetJustifyH("LEFT")
        desc:SetJustifyV("TOP")
        desc:SetWordWrap(true)
        local descText = L[feature.descKey] or feature.descKey
        desc:SetText(descText)
        desc:SetTextColor(0.75, 0.75, 0.75, 1)
        card.desc = desc
        card.descText = descText

        card:EnableMouse(true)
        card:SetScript("OnEnter", function()
            card:SetBackdropColor(0.18, 0.18, 0.20, 1)
            card:SetBackdropBorderColor(unpack(COLORS.GOLD))
            StartTypewriter(card.desc, card.descText)
        end)
        card:SetScript("OnLeave", function()
            card:SetBackdropColor(0.12, 0.12, 0.14, 0.95)
            card:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
            -- Snap to full text on leave
            StopTypewriter()
        end)

        entries[#entries + 1] = card
    end

    -- Sweep animation: a highlight travels left-to-right across all 6 cards
    -- Card order: 1-2-3 (row 1), then 4-5-6 (row 2), looping continuously
    local SWEEP_DURATION = 4.0   -- seconds for one full pass across all 6 cards
    local SWEEP_PAUSE = 1.5      -- pause before repeating
    local SWEEP_TOTAL = SWEEP_DURATION + SWEEP_PAUSE
    local CARD_COUNT = #entries
    local MIN_ALPHA = 0.15
    local MAX_ALPHA = 0.9

    local sweepDriver = CreateFrame("Frame", nil, parent)
    sweepDriver.elapsed = 0
    sweepDriver:SetScript("OnUpdate", function(_, dt)
        sweepDriver.elapsed = sweepDriver.elapsed + dt
        local t = sweepDriver.elapsed % SWEEP_TOTAL
        if t > SWEEP_DURATION then
            -- In pause phase: all cards dim
            for _, card in ipairs(entries) do
                card.accent:SetAlpha(MIN_ALPHA)
            end
            return
        end

        -- Sweep position: 0 to CARD_COUNT over SWEEP_DURATION
        local sweepPos = (t / SWEEP_DURATION) * CARD_COUNT

        for idx, card in ipairs(entries) do
            -- Each card occupies a 1.0-wide slot; glow when sweep passes through
            local cardCenter = (idx - 1) + 0.5
            local dist = math.abs(sweepPos - cardCenter)
            -- Glow falloff: bright within 0.6 cards, fading out to 1.2
            local glow
            if dist < 0.6 then
                glow = 1.0
            elseif dist < 1.2 then
                glow = 1.0 - ((dist - 0.6) / 0.6)
            else
                glow = 0
            end
            card.accent:SetAlpha(MIN_ALPHA + (MAX_ALPHA - MIN_ALPHA) * glow)
        end
    end)

    return entries, sweepDriver
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
        check.Text:SetFontObject(addon:GetFontObject("GameFontNormalSmall"))
        addon:RegisterFontString(check.Text, "GameFontNormalSmall")
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
        btn:SetSize(180, 32)
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
    placeholder:SetText(L["WHATS_NEW_NO_IMAGE"])
    placeholder:SetTextColor(0.4, 0.4, 0.4, 1)
    frame.showcasePlaceholder = placeholder

    return showcase
end

--------------------------------------------------------------------------------
-- Welcome: Good to Know Row (instructional)
--------------------------------------------------------------------------------

local function CreateQuickSetupRow(frame, contentArea)
    local setupRow = CreateFrame("Frame", nil, contentArea, "BackdropTemplate")
    setupRow:SetPoint("BOTTOMLEFT", 12, 10)
    setupRow:SetPoint("BOTTOMRIGHT", -12, 10)
    setupRow:SetHeight(60)

    -- Background with rounded edges
    setupRow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    setupRow:SetBackdropColor(unpack(COLORS.ROW_BG))
    setupRow:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)

    -- Center content container to manage centering
    local centerHarness = CreateFrame("Frame", nil, setupRow)
    centerHarness:SetSize(WN.WELCOME_WIDTH - 60, 40)
    centerHarness:SetPoint("CENTER", 0, 0)

    -- "Good to Know" label (Icon + Text)
    local gearIcon = centerHarness:CreateTexture(nil, "ARTWORK")
    gearIcon:SetSize(22, 22)
    gearIcon:SetPoint("LEFT", 0, 0)
    gearIcon:SetAtlas("QuestNormal")
    gearIcon:SetVertexColor(unpack(COLORS.GOLD))

    local label = addon:CreateFontString(centerHarness, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("LEFT", gearIcon, "RIGHT", 6, 0)
    label:SetText(L["WELCOME_QUICK_SETUP"])
    label:SetTextColor(unpack(COLORS.GOLD))

    -- Divider
    local div1 = centerHarness:CreateTexture(nil, "ARTWORK")
    div1:SetSize(1, 40)
    div1:SetPoint("LEFT", label, "RIGHT", 20, 0)
    div1:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- Instruction Text
    local openLabel = addon:CreateFontString(centerHarness, "OVERLAY", "GameFontHighlight")
    openLabel:SetPoint("LEFT", div1, "RIGHT", 20, 0)
    openLabel:SetText(L["WELCOME_OPEN_WITH"])
    openLabel:SetTextColor(0.8, 0.8, 0.8, 1)

    local openValue = addon:CreateFontString(centerHarness, "OVERLAY", "GameFontNormalLarge")
    openValue:SetPoint("LEFT", openLabel, "RIGHT", 6, 0)
    openValue:SetText("|cFFFFD100/hc|r")

    local orLabel = addon:CreateFontString(centerHarness, "OVERLAY", "GameFontHighlight")
    orLabel:SetPoint("LEFT", openValue, "RIGHT", 6, 0)
    orLabel:SetText(L["WELCOME_SET_KEYBIND"])
    orLabel:SetTextColor(0.8, 0.8, 0.8, 1)

    local keybindLabel = addon:CreateFontString(centerHarness, "OVERLAY", "GameFontNormal")
    keybindLabel:SetPoint("LEFT", orLabel, "RIGHT", 6, 0)
    keybindLabel:SetText(L["WELCOME_KEYBIND_LABEL"])
    keybindLabel:SetTextColor(unpack(COLORS.GOLD))

    return setupRow
end

--------------------------------------------------------------------------------
-- Build Popup (variant = "whatsnew" or "welcome")
--------------------------------------------------------------------------------

-- Detach a frame child created during a previous Build (Blizzard pool pattern)
local function ReleaseChild(child)
    addon:UnregisterFontStrings(child)
    child:Hide()
    child:SetParent(nil)
end

function WhatsNew:Build(variant)
    local frame = self:EnsureFrame()
    frame:Hide()

    -- Detach previous variant's children before rebuilding
    if self.header then ReleaseChild(self.header); self.header = nil end
    if self.footer then ReleaseChild(self.footer); self.footer = nil end
    if self.showcase then
        ReleaseChild(self.showcase); self.showcase = nil
        frame.showcase = nil; frame.showcaseImage = nil; frame.showcasePlaceholder = nil
    end
    if self.sweepDriver then
        self.sweepDriver:SetScript("OnUpdate", nil)
        self.sweepDriver = nil
    end
    StopTypewriter()
    if self.contentArea then ReleaseChild(self.contentArea); self.contentArea = nil end

    -- Reset state
    self.currentVariant = variant
    self.featureEntries = {}
    self.selectedIndex = nil
    self.checkboxChecked = false

    -- Size and position based on variant (clear old anchors from previous variant/animation)
    frame:ClearAllPoints()
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
    self.header = header

    if variant == "welcome" then
        header:SetHeight(82)
        frame.headerIcon:SetPoint("LEFT", 14, 12)
        frame.headerTitle:SetPoint("LEFT", frame.headerIcon, "RIGHT", 14, 0)
        frame.headerTitle:SetText(L["WELCOME_TITLE"])
        frame.headerSubtitle:SetText(L["WELCOME_SUBTITLE"])
        frame.headerSubtitle:Show()
    else
        frame.headerTitle:SetText(L["WHATSNEW_TITLE"])
        frame.headerSubtitle:Hide()
    end

    -- Footer
    self.footer = CreateFooter(frame, variant)

    -- Content area (between header and footer)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    content:SetPoint("BOTTOMRIGHT", -3, 3 + WN.FOOTER_HEIGHT)
    self.contentArea = content

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
    self.showcase = showcase
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
    _, self.sweepDriver = CreateWelcomeFeatureGrid(content)

    -- Quick setup row above footer
    CreateQuickSetupRow(frame, content)
end

--------------------------------------------------------------------------------
-- Typewriter Animation (What's New description reveal)
--------------------------------------------------------------------------------

StopTypewriter = function()
    if twDriver then
        twDriver:SetScript("OnUpdate", nil)
    end
    if twActive and twDescFS then
        twDescFS:SetText(twFullText)
    end
    twActive = false
    twDescFS = nil
    twFullText = ""
    twElapsed = 0
end

local function TypewriterOnUpdate(_, dt)
    if not twActive or not twDescFS then
        StopTypewriter()
        return
    end

    twElapsed = twElapsed + dt
    local charCount = math.floor(twElapsed * TW_CHARS_PER_SEC)

    if charCount >= #twFullText then
        twDescFS:SetText(twFullText)
        twActive = false
        twDriver:SetScript("OnUpdate", nil)
        return
    end

    twDescFS:SetText(twFullText:sub(1, charCount))
end

StartTypewriter = function(descFontString, fullText)
    StopTypewriter()

    if not fullText or fullText == "" then return end

    -- Create driver frame once (parented to UIParent so it ticks regardless)
    if not twDriver then
        twDriver = CreateFrame("Frame", nil, UIParent)
    end

    twDescFS = descFontString
    twFullText = fullText
    twElapsed = 0
    twActive = true

    -- Start with empty text
    twDescFS:SetText("")
    twDriver:SetScript("OnUpdate", TypewriterOnUpdate)
end

--------------------------------------------------------------------------------
-- Feature Selection (What's New hover)
--------------------------------------------------------------------------------

function WhatsNew:SelectFeature(index)
    -- Skip if already selected (prevents typewriter restart on mouse jitter)
    if self.selectedIndex == index then return end

    if self.selectedIndex and self.featureEntries[self.selectedIndex] then
        local prev = self.featureEntries[self.selectedIndex].entry
        prev.accent:Hide()
        prev.hoverBg:SetColorTexture(0.1, 0.1, 0.12, 0)
        prev.desc:SetText(prev.descText)
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

        -- Typewriter the description text (title stays instant)
        StartTypewriter(current.desc, current.descText)
    end
end

-- WoW has no callback for texture load success, so we always show the image unconditionally
function WhatsNew:SetShowcaseImage(imagePath)
    if not self.frame or not self.frame.showcaseImage then return end

    self.frame.showcaseImage:SetTexture(imagePath)
    self.frame.showcaseImage:Show()
    if self.frame.showcasePlaceholder then
        self.frame.showcasePlaceholder:Hide()
    end
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

    local translate = ag:CreateAnimation("Translation")
    translate:SetOffset(0, -WN.ANIM_SLIDE_OFFSET)
    translate:SetDuration(WN.ANIM_FADE_IN)
    translate:SetSmoothing("OUT")

    ag:SetToFinalAlpha(true)

    -- Reanchor to final position when animation ends so the frame doesn't
    -- snap back to its pre-animation offset
    ag:SetScript("OnFinished", function()
        frame:ClearAllPoints()
        if WhatsNew.currentVariant == "welcome" then
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        else
            local xOff = -(GetScreenWidth() * 0.12)
            frame:SetPoint("CENTER", UIParent, "CENTER", xOff, 0)
        end
    end)

    return ag
end

local function CreateFadeOutAnimation(frame)
    local ag = frame:CreateAnimationGroup()

    local alpha = ag:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(WN.ANIM_FADE_OUT)
    alpha:SetSmoothing("IN")

    ag:SetToFinalAlpha(true)
    ag:SetScript("OnFinished", function()
        frame:Hide()
    end)

    return ag
end

--------------------------------------------------------------------------------
-- Show / Close / Dismiss
--------------------------------------------------------------------------------

local combatDeferFrame = CreateFrame("Frame")
combatDeferFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local pending = WhatsNew.pendingShow
    WhatsNew.pendingShow = nil
    WhatsNew:Show(pending)
end)

function WhatsNew:Show(variant)
    variant = variant or "whatsnew"

    if InCombatLockdown() then
        self.pendingShow = variant
        combatDeferFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        addon:Debug("WhatsNew deferred until combat ends: " .. variant)
        return
    end

    -- Skip rebuild if same variant already built
    if variant == self.currentVariant and self.header then
        self.checkboxChecked = false
    else
        self:Build(variant)
    end

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

    StopTypewriter()

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
        wn.hasSeenWelcome = true
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
    addon.db.whatsNew.hasSeenWelcome = true
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

function WhatsNew:DismissIfShowing()
    self:Close()
end

--------------------------------------------------------------------------------
-- Auto-trigger on DATA_LOADED
--------------------------------------------------------------------------------

local autoShowPending = false

addon:RegisterInternalEvent("DATA_LOADED", function()
    -- Reset dismiss count when version changes
    if addon.db and addon.db.whatsNew then
        local wn = addon.db.whatsNew
        if wn.lastSeenVersion and wn.lastSeenVersion ~= addon.version then
            wn.dismissCount = 0
            wn.dontShowForVersion = nil
        end
    end

    if autoShowPending then return end
    autoShowPending = true

    C_Timer.After(WN.SHOW_DELAY, function()
        autoShowPending = false
        local variant = WhatsNew:ShouldShow()
        if variant then
            WhatsNew:Show(variant)
        end
    end)
end)
