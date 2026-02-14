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
    { key = "ACHIEVEMENTS", labelKey = "TAB_ACHIEVEMENTS", descKey = "TAB_ACHIEVEMENTS_DESC", icon = "Interface\\Icons\\Achievement_General", enabled = true },
    { key = "VENDORS", labelKey = "TAB_VENDORS", descKey = "TAB_VENDORS_DESC", icon = "Interface\\Icons\\INV_Misc_Coin_02", enabled = true },
    { key = "DROPS", labelKey = "TAB_DROPS", descKey = "TAB_DROPS_DESC", icon = "Interface\\Icons\\INV_Misc_Bag_10_Blue", enabled = true },
    { key = "PROFESSIONS", labelKey = "TAB_PROFESSIONS", descKey = "TAB_PROFESSIONS_DESC", icon = "Interface\\Icons\\INV_Misc_Gear_01", enabled = true },
}

addon.Tabs = {}
local Tabs = addon.Tabs
Tabs.buttons = {}
Tabs.currentTab = nil
Tabs.container = nil

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
        -- Enabled but not selected - set initial color (GameFontNormal default is yellow)
        label:SetTextColor(unpack(COLORS.TEXT_TERTIARY))
        -- Enable hover effects + tooltip
        btn:SetScript("OnEnter", function(self)
            if not Tabs:IsSelected(tabConfig.key) then
                bg:SetColorTexture(unpack(COLORS.TAB_HOVER))
            end
        end)

        btn:SetScript("OnLeave", function()
            if not Tabs:IsSelected(tabConfig.key) then
                bg:SetColorTexture(unpack(COLORS.TAB_NORMAL))
            end
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
    for i, config in ipairs(TAB_CONFIG) do
        local btn = CreateTabButton(container, config, i)
        btn:SetPoint("LEFT", container, "LEFT", xOffset, 0)

        self.buttons[i] = btn
        self.buttons[config.key] = btn

        xOffset = xOffset + btn:GetWidth() + HTAB_GAP
    end

    -- Set container width to fit all tabs
    container:SetWidth(xOffset - HTAB_GAP)

    -- Always start on DECOR tab (skip save to avoid overwriting user's last session)
    self:SelectTab("DECOR", true)

    addon:Debug("Created " .. #TAB_CONFIG .. " horizontal tabs")
end

function Tabs:SelectTab(tabKey, skipSave)
    local btn = self.buttons[tabKey]
    if not btn or not btn.enabled then return end

    -- Deselect current
    if self.currentTab and self.buttons[self.currentTab] then
        local oldBtn = self.buttons[self.currentTab]
        oldBtn.bg:SetColorTexture(unpack(COLORS.TAB_NORMAL))
        oldBtn.selectBar:Hide()
        oldBtn.label:SetTextColor(unpack(COLORS.TEXT_TERTIARY))
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
