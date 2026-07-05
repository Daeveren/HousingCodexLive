--[[
    Housing Codex - Tabs.lua
    Horizontal tab navigation in title bar (DaevTools pattern)
]]

local _, addon = ...

local COLORS = addon.CONSTANTS.COLORS
local HTAB_ICON_SIZE = addon.CONSTANTS.HTAB_ICON_SIZE
local HTAB_HEIGHT = addon.CONSTANTS.HTAB_HEIGHT
local HTAB_GAP = addon.CONSTANTS.HTAB_GAP
local HTAB_PADDING_X = addon.CONSTANTS.HTAB_PADDING_X
local ICON_CROP_COORDS = addon.CONSTANTS.ICON_CROP_COORDS

-- Truncation levels: full text, then progressively shorter (6..2 chars + "...")
-- Each tab only truncates if its full text exceeds the char limit
local TRUNCATE_CHAR_LIMITS = { 6, 5, 4, 3, 2 }
local ICON_ONLY_LEVEL = #TRUNCATE_CHAR_LIMITS + 1

-- SelectBar slide animation (set to false to revert to instant show/hide)
-- "Stretch & Settle": the bar first stretches toward the target, then contracts onto it.
-- Long jumps cap the stretch (no bar flashing across the whole strip) and leave a
-- short gold-to-titlebar-gray gradient trail along the traveled path instead.
local TAB_SLIDE_ENABLED = true
local TAB_STRETCH_DURATION = 0.13     -- phase 1: expand toward the new tab
local TAB_SETTLE_DURATION = 0.16      -- phase 2: contract onto the new tab
local TAB_MAX_STRETCH_FACTOR = 2      -- stretch cap = (old + new tab width) * this
local TAB_TRAIL_LENGTH_FRAC = 0.2     -- trail length as fraction of the travel distance
local TAB_TRAIL_ALPHA = 0.2           -- trail opacity at its gold end
local TAB_TRAIL_FADE_START = 0.55     -- settle progress at which the trail starts fading
                                      -- (fully gone when the bar lands — no after-fade)

local function EaseOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

-- Animation state (only used when TAB_SLIDE_ENABLED)
local slideDriver       -- child frame for OnUpdate
local curBarX = 0       -- current bar x offset (container-relative)
local curBarW = 0       -- current bar width
local sharedSelectBar   -- the single gold texture
local sharedTrail       -- gradient trail texture behind the moving bar

local function ApplyBarPosition(x, w)
    curBarX = x
    curBarW = w
    sharedSelectBar:ClearAllPoints()
    sharedSelectBar:SetPoint("BOTTOMLEFT", sharedSelectBar:GetParent(), "BOTTOMLEFT", x, -3)
    sharedSelectBar:SetWidth(w)
end

local function SnapBarTo(btn)
    if not btn then return end
    ApplyBarPosition(btn.xOffset, btn:GetWidth())
    sharedSelectBar:Show()
end

local function CancelSlide()
    slideDriver:SetScript("OnUpdate", nil)
    if sharedTrail then
        sharedTrail:Hide()
    end
end

-- Orient the trail gradient: gold at the bar's trailing edge, fading into the
-- titlebar gray along the traveled path
local function ConfigureTrail(movingRight)
    local gold = COLORS.GOLD
    local bg = COLORS.TITLEBAR_BG
    local goldEnd = CreateColor(gold[1], gold[2], gold[3], 1)
    local fadeEnd = CreateColor(bg[1], bg[2], bg[3], 0)
    if movingRight then
        sharedTrail:SetGradient("HORIZONTAL", fadeEnd, goldEnd)
    else
        sharedTrail:SetGradient("HORIZONTAL", goldEnd, fadeEnd)
    end
end

-- Position the trail behind the bar's trailing edge, clamped to the start tab
local function UpdateTrail(movingRight, startX, startW, trailLen, alphaMul)
    if trailLen < 1 then return end

    local left, right
    if movingRight then
        right = curBarX
        left = math.max(startX, right - trailLen)
    else
        left = curBarX + curBarW
        right = math.min(startX + startW, left + trailLen)
    end

    local width = right - left
    if width < 1 or alphaMul <= 0 then
        sharedTrail:Hide()
        return
    end

    sharedTrail:SetPoint("BOTTOMLEFT", sharedTrail:GetParent(), "BOTTOMLEFT", left, -3)
    sharedTrail:SetWidth(width)
    sharedTrail:SetAlpha(TAB_TRAIL_ALPHA * alphaMul)
    sharedTrail:Show()
end

local function SlideBarTo(btn)
    if not btn then return end

    local startX, startW = curBarX, curBarW
    local targetX = btn.xOffset
    local targetW = btn:GetWidth()
    local movingRight = targetX >= startX

    -- Stretch phase target: span both tabs, capped so long jumps elongate
    -- modestly instead of flashing a bar across the whole strip. For adjacent
    -- tabs the cap is never hit, so the full-span stretch is unchanged.
    local spanX = math.min(startX, targetX)
    local spanW = math.max(startX + startW, targetX + targetW) - spanX
    local stretchW = math.min(spanW, (startW + targetW) * TAB_MAX_STRETCH_FACTOR)
    -- While stretching, the bar stays anchored on its trailing side
    local stretchX = movingRight and startX or (startX + startW - stretchW)

    local trailLen = math.abs(targetX - startX) * TAB_TRAIL_LENGTH_FRAC
    ConfigureTrail(movingRight)

    local elapsed = 0

    sharedSelectBar:Show()

    slideDriver:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt

        if elapsed < TAB_STRETCH_DURATION then
            local e = EaseOutQuad(elapsed / TAB_STRETCH_DURATION)
            ApplyBarPosition(
                startX + (stretchX - startX) * e,
                startW + (stretchW - startW) * e
            )
        else
            local t = math.min((elapsed - TAB_STRETCH_DURATION) / TAB_SETTLE_DURATION, 1)
            local e = EaseOutQuad(t)
            ApplyBarPosition(
                stretchX + (targetX - stretchX) * e,
                stretchW + (targetW - stretchW) * e
            )

            -- Trail fades out over the tail of the settle, so it is gone the
            -- moment the bar lands — no lingering after-fade
            local fade = 1
            if t > TAB_TRAIL_FADE_START then
                fade = 1 - (t - TAB_TRAIL_FADE_START) / (1 - TAB_TRAIL_FADE_START)
            end
            UpdateTrail(movingRight, startX, startW, trailLen, fade)

            if t >= 1 then
                self:SetScript("OnUpdate", nil)
                sharedTrail:Hide()
                ApplyBarPosition(targetX, targetW)
            end
        end
    end)
end

local TAB_CONFIG = {
    { key = "DECOR", labelKey = "TAB_DECOR", descKey = "TAB_DECOR_DESC", atlas = "house-decor-budget-icon", enabled = true },
    { key = "QUESTS", labelKey = "TAB_QUESTS", descKey = "TAB_QUESTS_DESC", icon = "Interface\\Icons\\INV_Misc_Book_08", enabled = true },
    { key = "ACHIEVEMENTS", labelKey = "TAB_ACHIEVEMENTS", descKey = "TAB_ACHIEVEMENTS_DESC", icon = "Interface\\Icons\\Achievement_General", enabled = true },
    { key = "VENDORS", labelKey = "TAB_VENDORS", descKey = "TAB_VENDORS_DESC", icon = "Interface\\Icons\\INV_Misc_Coin_02", enabled = true },
    { key = "DROPS", labelKey = "TAB_DROPS", descKey = "TAB_DROPS_DESC", icon = "Interface\\Icons\\INV_Misc_Bag_10_Blue", enabled = true },
    { key = "PVP", labelKey = "TAB_PVP", descKey = "TAB_PVP_DESC", icon = "Interface\\Icons\\achievement_bg_killxenemies_generalsroom", enabled = true },
    { key = "RENOWN", labelKey = "TAB_RENOWN", descKey = "TAB_RENOWN_DESC", icon = "Interface\\Icons\\Achievement_Reputation_08", enabled = true },
    { key = "PROFESSIONS", labelKey = "TAB_PROFESSIONS", descKey = "TAB_PROFESSIONS_DESC", icon = "Interface\\Icons\\INV_Misc_Gear_01", enabled = true },
    { key = "PROGRESS", labelKey = "TAB_PROGRESS", descKey = "TAB_PROGRESS_DESC", icon = "Interface\\Icons\\Spell_Holy_BorrowedTime", enabled = true },
}

addon.Tabs = {}
local Tabs = addon.Tabs
Tabs.buttons = {}
Tabs.currentTab = nil
Tabs.container = nil
Tabs.currentTruncLevel = 0  -- 0 = full, 1..5 = truncated at TRUNCATE_CHAR_LIMITS[level], ICON_ONLY_LEVEL = iconOnly
Tabs.levelWidths = {}       -- total width for each truncation level

-- Truncate text to N chars + "..." if longer than N chars
-- At 2 chars (last level before icon-only), drop the ellipsis
local function TruncateText(fullText, charLimit)
    if #fullText <= charLimit then
        return fullText
    end
    if charLimit <= 2 then
        return fullText:sub(1, charLimit)
    end
    return fullText:sub(1, charLimit) .. "..."
end

local function CreateTabButton(parent, tabConfig)
    local frameType = tabConfig.enabled and "Button" or "Frame"
    local btn = CreateFrame(frameType, nil, parent)
    btn:SetHeight(HTAB_HEIGHT)

    -- Background texture
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(COLORS.TAB_NORMAL))
    btn.bg = bg

    -- Selection indicator (gold bar on bottom edge)
    local selectBar = btn:CreateTexture(nil, "OVERLAY")
    selectBar:SetHeight(3)
    selectBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, -3)
    selectBar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, -3)
    selectBar:SetColorTexture(unpack(COLORS.GOLD))
    selectBar:Hide()
    btn.selectBar = selectBar

    -- Icon (supports both atlas and texture paths)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", btn, "LEFT", HTAB_PADDING_X, 0)
    local iconSize
    if tabConfig.atlas then
        iconSize = math.floor(HTAB_ICON_SIZE * 1.2)
        icon:SetAtlas(tabConfig.atlas)
    else
        iconSize = HTAB_ICON_SIZE
        icon:SetTexture(tabConfig.icon)
        icon:SetTexCoord(unpack(ICON_CROP_COORDS))
    end
    icon:SetSize(iconSize, iconSize)
    btn.icon = icon

    -- Label
    local label = addon:CreateFontString(btn, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    local fullText = addon.L[tabConfig.labelKey] or tabConfig.key
    label:SetText(fullText)
    btn.label = label
    btn.fullText = fullText

    -- Calculate button width based on content
    local labelWidth = label:GetStringWidth()
    local totalWidth = HTAB_PADDING_X + iconSize + 6 + labelWidth + HTAB_PADDING_X
    btn:SetWidth(totalWidth)

    btn.fullWidth = totalWidth
    btn.iconOnlyWidth = HTAB_PADDING_X + iconSize + HTAB_PADDING_X

    -- Pre-compute truncated widths (6..2 chars)
    btn.truncWidths = {}
    btn.truncTexts = {}
    for i, charLimit in ipairs(TRUNCATE_CHAR_LIMITS) do
        local truncText = TruncateText(fullText, charLimit)
        btn.truncTexts[i] = truncText
        if truncText == fullText then
            -- No truncation needed at this level — same as full
            btn.truncWidths[i] = totalWidth
        else
            label:SetText(truncText)
            local truncLabelWidth = label:GetStringWidth()
            btn.truncWidths[i] = HTAB_PADDING_X + iconSize + 6 + truncLabelWidth + HTAB_PADDING_X
        end
    end
    label:SetText(fullText)

    -- Store config
    btn.tabKey = tabConfig.key
    btn.enabled = tabConfig.enabled

    -- Visual states
    if not tabConfig.enabled then
        -- Disabled state (visual-only; plain frame so it does not swallow mouse input)
        icon:SetDesaturated(true)
        icon:SetAlpha(0.5)
        label:SetTextColor(0.35, 0.35, 0.35, 1)  -- Dimmer than TEXT_DISABLED
    else
        -- Enabled but not selected - set initial color (dimmed from TEXT_TERTIARY)
        label:SetTextColor(unpack(COLORS.TAB_TEXT_INACTIVE))
        icon:SetAlpha(COLORS.TAB_ICON_ALPHA_INACTIVE)
        -- Enable hover effects + tooltip
        btn:SetScript("OnEnter", function(self)
            if not Tabs:IsSelected(tabConfig.key) then
                bg:SetColorTexture(unpack(COLORS.TAB_HOVER))
            end
            -- Show tooltip when truncated or icon-only
            if Tabs.currentTruncLevel > 0 then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:SetText(addon.L[tabConfig.labelKey])
                GameTooltip:AddLine(addon.L[tabConfig.descKey], 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)

        btn:SetScript("OnLeave", function()
            if not Tabs:IsSelected(tabConfig.key) then
                bg:SetColorTexture(unpack(COLORS.TAB_NORMAL))
            end
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function()
            Tabs:SelectTab(tabConfig.key)
        end)
    end

    return btn
end

function Tabs:Create(titleBar, anchorAfter)
    if self.container then return end  -- Already created

    -- Create container frame for tabs (positioned after title text)
    local container = CreateFrame("Frame", nil, titleBar)
    container:SetHeight(HTAB_HEIGHT)
    container:SetPoint("LEFT", anchorAfter, "RIGHT", 16, 0)
    self.container = container

    -- Create tab buttons and compute total widths for each truncation level
    local xOffset = 0
    local gapTotal = (#TAB_CONFIG - 1) * HTAB_GAP

    -- Accumulators: level 0 = full, 1..5 = truncated, ICON_ONLY_LEVEL = iconOnly
    local levelSums = {}

    for i, config in ipairs(TAB_CONFIG) do
        local btn = CreateTabButton(container, config)
        btn:SetPoint("LEFT", container, "LEFT", xOffset, 0)
        btn.xOffset = xOffset

        self.buttons[i] = btn
        self.buttons[config.key] = btn

        -- Level 0: full width
        levelSums[0] = (levelSums[0] or 0) + btn.fullWidth
        -- Levels 1..5: truncated widths
        for lvl = 1, #TRUNCATE_CHAR_LIMITS do
            levelSums[lvl] = (levelSums[lvl] or 0) + btn.truncWidths[lvl]
        end
        -- Icon-only level
        levelSums[ICON_ONLY_LEVEL] = (levelSums[ICON_ONLY_LEVEL] or 0) + btn.iconOnlyWidth

        xOffset = xOffset + btn:GetWidth() + HTAB_GAP
    end

    -- Store total widths including gaps
    for lvl = 0, ICON_ONLY_LEVEL do
        self.levelWidths[lvl] = levelSums[lvl] + gapTotal
    end

    -- Set initial container width (full mode until UpdateLayout fires)
    container:SetWidth(self.levelWidths[0])
    self.currentTruncLevel = 0

    -- Shared selection indicator bar (animated slide between tabs)
    if TAB_SLIDE_ENABLED then
        local bar = container:CreateTexture(nil, "OVERLAY")
        bar:SetHeight(3)
        bar:SetColorTexture(unpack(COLORS.GOLD))
        bar:Hide()
        sharedSelectBar = bar

        -- Gradient trail left behind the moving bar (below the bar's sublayer)
        local trail = container:CreateTexture(nil, "OVERLAY", nil, -1)
        trail:SetHeight(3)
        trail:SetTexture("Interface\\Buttons\\WHITE8x8")
        trail:Hide()
        sharedTrail = trail

        slideDriver = CreateFrame("Frame", nil, container)
    end

    -- Always start on DECOR tab (skip save to avoid overwriting user's last session)
    self:SelectTab("DECOR", true)

    addon:Debug("Created " .. #TAB_CONFIG .. " horizontal tabs")
end

function Tabs:UpdateLayout(availableWidth)
    if not self.container then return end

    -- Find the best truncation level that fits
    -- Level 0 = full, 1..5 = truncated at 6/5/4/3/2 chars, ICON_ONLY_LEVEL = iconOnly
    local newLevel = ICON_ONLY_LEVEL  -- default to icon-only
    for lvl = 0, ICON_ONLY_LEVEL do
        if availableWidth >= self.levelWidths[lvl] then
            newLevel = lvl
            break
        end
    end

    -- Skip redundant relayout
    if newLevel == self.currentTruncLevel then return end
    self.currentTruncLevel = newLevel

    -- Cancel in-flight slide (button positions are about to change)
    if TAB_SLIDE_ENABLED then
        CancelSlide()
    end

    local isIconOnly = (newLevel == ICON_ONLY_LEVEL)
    local xOffset = 0
    for i = 1, #TAB_CONFIG do
        local btn = self.buttons[i]

        local btnWidth, labelText
        if isIconOnly then
            btnWidth = btn.iconOnlyWidth
        elseif newLevel == 0 then
            btnWidth = btn.fullWidth
            labelText = btn.fullText
        else
            btnWidth = btn.truncWidths[newLevel]
            labelText = btn.truncTexts[newLevel]
        end

        btn:SetWidth(btnWidth)
        btn.label:SetShown(not isIconOnly)
        if labelText then
            btn.label:SetText(labelText)
        end

        btn:ClearAllPoints()
        btn:SetPoint("LEFT", self.container, "LEFT", xOffset, 0)
        btn.xOffset = xOffset
        xOffset = xOffset + btnWidth + HTAB_GAP
    end

    self.container:SetWidth(xOffset - HTAB_GAP)

    -- Re-snap shared bar to current tab's new position after relayout
    if TAB_SLIDE_ENABLED and self.currentTab and self.buttons[self.currentTab] then
        SnapBarTo(self.buttons[self.currentTab])
    end
end

function Tabs:SelectTab(tabKey, skipSave, skipAnim)
    local btn = self.buttons[tabKey]
    if not btn or not btn.enabled then return end

    local previousTab = self.currentTab

    -- Deselect current
    if previousTab and self.buttons[previousTab] then
        local oldBtn = self.buttons[previousTab]
        oldBtn.bg:SetColorTexture(unpack(COLORS.TAB_NORMAL))
        oldBtn.label:SetTextColor(unpack(COLORS.TAB_TEXT_INACTIVE))
        oldBtn.icon:SetAlpha(COLORS.TAB_ICON_ALPHA_INACTIVE)
        if not TAB_SLIDE_ENABLED then
            oldBtn.selectBar:Hide()
        end
    end

    -- Select new
    btn.bg:SetColorTexture(unpack(COLORS.TAB_SELECTED))
    btn.label:SetTextColor(unpack(COLORS.TEXT_PRIMARY))
    btn.icon:SetAlpha(1.0)

    if TAB_SLIDE_ENABLED then
        -- Animated: snap on first selection or skipAnim, slide otherwise
        if not previousTab or skipAnim then
            SnapBarTo(btn)
        else
            SlideBarTo(btn)
        end
    else
        -- Original instant behavior
        btn.selectBar:Show()
    end

    self.currentTab = tabKey

    -- Save selection
    if not skipSave and addon.db and addon.db.browser then
        addon.db.browser.lastTab = tabKey
    end

    -- Fire event
    addon:FireEvent("TAB_CHANGED", tabKey)

    addon:Debug("Selected tab: " .. tabKey)
end

function Tabs:GetCurrentTab()
    return self.currentTab
end

function Tabs:IsSelected(tabKey)
    return self.currentTab == tabKey
end

function Tabs:RestoreSavedTab()
    -- One-shot: only restore once
    if self.tabRestored then return end

    local savedTab = addon.db and addon.db.browser and addon.db.browser.lastTab
    if not savedTab then return end

    -- Validate saved tab key against enabled tabs
    local btn = self.buttons[savedTab]
    if not btn or not btn.enabled then return end

    self.tabRestored = true

    -- Already on this tab (DECOR default from Create) — no-op
    if self.currentTab == savedTab then return end

    self:SelectTab(savedTab, false, true)
end
