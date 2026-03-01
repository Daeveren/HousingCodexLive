--[[
    Housing Codex - Tabs.lua
    Horizontal tab navigation in title bar (DaevTools pattern)
]]

local ADDON_NAME, addon = ...

local COLORS = addon.CONSTANTS.COLORS
local HTAB_ICON_SIZE = addon.CONSTANTS.HTAB_ICON_SIZE
local HTAB_HEIGHT = addon.CONSTANTS.HTAB_HEIGHT
local HTAB_GAP = addon.CONSTANTS.HTAB_GAP
local HTAB_PADDING_X = addon.CONSTANTS.HTAB_PADDING_X
local ICON_CROP_COORDS = addon.CONSTANTS.ICON_CROP_COORDS

local TAB_CONFIG = {
    { key = "DECOR", labelKey = "TAB_DECOR", descKey = "TAB_DECOR_DESC", atlas = "house-decor-budget-icon", enabled = true },
    { key = "QUESTS", labelKey = "TAB_QUESTS", descKey = "TAB_QUESTS_DESC", icon = "Interface\\Icons\\INV_Misc_Book_08", enabled = true },
    { key = "ACHIEVEMENTS", labelKey = "TAB_ACHIEVEMENTS", descKey = "TAB_ACHIEVEMENTS_DESC", shortLabelKey = "TAB_ACHIEVEMENTS_SHORT", icon = "Interface\\Icons\\Achievement_General", enabled = true },
    { key = "VENDORS", labelKey = "TAB_VENDORS", descKey = "TAB_VENDORS_DESC", icon = "Interface\\Icons\\INV_Misc_Coin_02", enabled = true },
    { key = "DROPS", labelKey = "TAB_DROPS", descKey = "TAB_DROPS_DESC", icon = "Interface\\Icons\\INV_Misc_Bag_10_Blue", enabled = true },
    { key = "PVP", labelKey = "TAB_PVP", descKey = "TAB_PVP_DESC", icon = "Interface\\Icons\\achievement_bg_killxenemies_generalsroom", enabled = true },
    { key = "PROFESSIONS", labelKey = "TAB_PROFESSIONS", descKey = "TAB_PROFESSIONS_DESC", shortLabelKey = "TAB_PROFESSIONS_SHORT", icon = "Interface\\Icons\\INV_Misc_Gear_01", enabled = true },
    { key = "PROGRESS", labelKey = "TAB_PROGRESS", descKey = "TAB_PROGRESS_DESC", shortLabelKey = "TAB_PROGRESS_SHORT", icon = "Interface\\Icons\\Spell_Holy_BorrowedTime", enabled = true },
}

addon.Tabs = {}
local Tabs = addon.Tabs
Tabs.buttons = {}
Tabs.currentTab = nil
Tabs.container = nil
Tabs.layoutMode = nil      -- "full", "compact", or "iconOnly"
Tabs.fullWidth = 0
Tabs.compactWidth = 0
Tabs.iconOnlyWidth = 0

local function CreateTabButton(parent, tabConfig, index)
    local btn = CreateFrame("Button", nil, parent)
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
    label:SetText(addon.L[tabConfig.labelKey] or tabConfig.key)
    btn.label = label

    -- Calculate button width based on content
    local labelWidth = label:GetStringWidth()
    local totalWidth = HTAB_PADDING_X + iconSize + 6 + labelWidth + HTAB_PADDING_X
    btn:SetWidth(totalWidth)

    -- Store per-button width variants for responsive layout
    btn.fullWidth = totalWidth
    btn.fullText = addon.L[tabConfig.labelKey] or tabConfig.key
    btn.iconOnlyWidth = HTAB_PADDING_X + iconSize + HTAB_PADDING_X

    if tabConfig.shortLabelKey then
        local shortText = addon.L[tabConfig.shortLabelKey]
        label:SetText(shortText)
        local shortLabelWidth = label:GetStringWidth()
        label:SetText(btn.fullText)
        btn.compactText = shortText
        btn.compactWidth = HTAB_PADDING_X + iconSize + 6 + shortLabelWidth + HTAB_PADDING_X
    else
        btn.compactText = btn.fullText
        btn.compactWidth = btn.fullWidth
    end

    -- Store config
    btn.tabKey = tabConfig.key
    btn.enabled = tabConfig.enabled

    -- Visual states
    if not tabConfig.enabled then
        -- Disabled state (visual-only, keep button enabled for OnEnter/OnLeave)
        icon:SetDesaturated(true)
        icon:SetAlpha(0.5)
        label:SetTextColor(0.35, 0.35, 0.35, 1)  -- Dimmer than TEXT_DISABLED
        -- No tooltip or interaction for disabled tabs
        -- No OnClick = clicking does nothing
    else
        -- Enabled but not selected - set initial color (dimmed from TEXT_TERTIARY)
        label:SetTextColor(unpack(COLORS.TAB_TEXT_INACTIVE))
        -- Enable hover effects + tooltip
        btn:SetScript("OnEnter", function(self)
            if not Tabs:IsSelected(tabConfig.key) then
                bg:SetColorTexture(unpack(COLORS.TAB_HOVER))
            end
            -- Show tooltip in icon-only mode
            if Tabs.layoutMode == "iconOnly" then
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

    -- Create tab buttons
    local xOffset = 0
    local fullSum, compactSum, iconOnlySum = 0, 0, 0
    for i, config in ipairs(TAB_CONFIG) do
        local btn = CreateTabButton(container, config, i)
        btn:SetPoint("LEFT", container, "LEFT", xOffset, 0)

        self.buttons[i] = btn
        self.buttons[config.key] = btn

        fullSum = fullSum + btn.fullWidth
        compactSum = compactSum + btn.compactWidth
        iconOnlySum = iconOnlySum + btn.iconOnlyWidth

        xOffset = xOffset + btn:GetWidth() + HTAB_GAP
    end

    -- Compute total widths for each layout mode
    local gapTotal = (#TAB_CONFIG - 1) * HTAB_GAP
    self.fullWidth = fullSum + gapTotal
    self.compactWidth = compactSum + gapTotal
    self.iconOnlyWidth = iconOnlySum + gapTotal

    -- Set initial container width (full mode until UpdateLayout fires)
    container:SetWidth(self.fullWidth)
    self.layoutMode = "full"

    -- Always start on DECOR tab (skip save to avoid overwriting user's last session)
    self:SelectTab("DECOR", true)

    addon:Debug("Created " .. #TAB_CONFIG .. " horizontal tabs")
end

function Tabs:UpdateLayout(availableWidth)
    if not self.container then return end

    -- Determine new layout mode
    local newMode
    if availableWidth >= self.fullWidth then
        newMode = "full"
    elseif availableWidth >= self.compactWidth then
        newMode = "compact"
    else
        newMode = "iconOnly"
    end

    -- Skip redundant relayout
    if newMode == self.layoutMode then return end
    self.layoutMode = newMode

    local xOffset = 0
    for i = 1, #TAB_CONFIG do
        local btn = self.buttons[i]

        local btnWidth, labelText
        if newMode == "iconOnly" then
            btnWidth = btn.iconOnlyWidth
        elseif newMode == "compact" then
            btnWidth = btn.compactWidth
            labelText = btn.compactText
        else
            btnWidth = btn.fullWidth
            labelText = btn.fullText
        end

        btn:SetWidth(btnWidth)
        btn.label:SetShown(labelText ~= nil)
        if labelText then
            btn.label:SetText(labelText)
        end

        btn:ClearAllPoints()
        btn:SetPoint("LEFT", self.container, "LEFT", xOffset, 0)
        xOffset = xOffset + btnWidth + HTAB_GAP
    end

    self.container:SetWidth(xOffset - HTAB_GAP)
end

function Tabs:SelectTab(tabKey, skipSave)
    local btn = self.buttons[tabKey]
    if not btn or not btn.enabled then return end

    -- Deselect current
    if self.currentTab and self.buttons[self.currentTab] then
        local oldBtn = self.buttons[self.currentTab]
        oldBtn.bg:SetColorTexture(unpack(COLORS.TAB_NORMAL))
        oldBtn.selectBar:Hide()
        oldBtn.label:SetTextColor(unpack(COLORS.TAB_TEXT_INACTIVE))
    end

    -- Select new
    btn.bg:SetColorTexture(unpack(COLORS.TAB_SELECTED))
    btn.selectBar:Show()
    btn.label:SetTextColor(unpack(COLORS.TEXT_PRIMARY))

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
    self.tabRestored = true

    local savedTab = addon.db and addon.db.browser and addon.db.browser.lastTab
    if not savedTab then return end

    -- Validate saved tab key against enabled tabs
    local btn = self.buttons[savedTab]
    if not btn or not btn.enabled then return end

    -- Already on this tab (DECOR default from Create) — no-op
    if self.currentTab == savedTab then return end

    self:SelectTab(savedTab)
end
