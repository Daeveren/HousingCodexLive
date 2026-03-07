--[[
    Housing Codex - TabBase.lua
    Shared mixin for hierarchy tabs (QuestsTab, AchievementsTab)
    Provides common toolbar, filter state, and visual helpers
]]

local _, addon = ...

addon.TabBaseMixin = {}
local TabBaseMixin = addon.TabBaseMixin

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS

--------------------------------------------------------------------------------
-- Wishlist Star Helper
--------------------------------------------------------------------------------

-- Update wishlist star visibility and position (shared across hierarchy tabs)
-- @param frame: Row frame with .wishlistStar and .label elements
-- @param isWishlisted: boolean
function TabBaseMixin:UpdateWishlistStar(frame, isWishlisted)
    if not frame or not frame.wishlistStar or not frame.label then return end
    frame.wishlistStar:SetShown(isWishlisted)
    if isWishlisted then
        frame.wishlistStar:ClearAllPoints()
        frame.wishlistStar:SetPoint("LEFT", frame.label, "LEFT", frame.label:GetStringWidth() + 4, 0)
    end
end

--------------------------------------------------------------------------------
-- Progress Color Helper
--------------------------------------------------------------------------------

-- Get progress text color based on percentage
-- @param percent: 0-100 percentage value
-- @param useAltDim: If true, use dimmer gray for low values (zones vs expansions)
-- @return color table {r, g, b, a}
function TabBaseMixin:GetProgressColor(percent, useAltDim)
    if percent == 100 then
        return COLORS.PROGRESS_COMPLETE        -- Green
    elseif percent >= 91 then
        return COLORS.PROGRESS_NEAR_COMPLETE   -- Yellow-green
    elseif percent >= 66 then
        return COLORS.GOLD                     -- Gold/yellow
    elseif percent >= 34 then
        return COLORS.PROGRESS_MID             -- Muted tan
    else
        return useAltDim and COLORS.PROGRESS_LOW_DIM or COLORS.TEXT_TERTIARY  -- Gray
    end
end

--------------------------------------------------------------------------------
-- Hierarchy Panel Factory
--------------------------------------------------------------------------------

-- Create a left-panel hierarchy selector (expansion, category, profession panels).
-- Handles frame, background, right border, scroll container, ScrollBox, view, and DataProvider.
-- @param parent: Parent frame to attach the panel to
-- @param config: Table with fields:
--   panelKey       (string)   self key to store the panel (e.g. "expansionPanel")
--   scrollBoxKey   (string)   self key to store the ScrollBox (e.g. "expansionScrollBox")
--   dataProviderKey(string)   self key to store the DataProvider (e.g. "expansionDataProvider")
--   elementExtent  (number)   row height in pixels (default: CONSTS.HIERARCHY_HEADER_HEIGHT)
--   setupFn        (function) element initializer: function(frame, elementData)
function TabBaseMixin:CreateHierarchyPanel(parent, config)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", self.toolbar, "BOTTOMLEFT", -CONSTS.SIDEBAR_WIDTH, 0)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -CONSTS.SIDEBAR_WIDTH, 0)
    panel:SetWidth(config.width or CONSTS.HIERARCHY_PANEL_WIDTH)
    self[config.panelKey] = panel

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)

    local border = panel:CreateTexture(nil, "ARTWORK")
    border:SetWidth(1)
    border:SetPoint("TOPRIGHT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(0.2, 0.2, 0.25, 1)

    local pad = CONSTS.HIERARCHY_PADDING
    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", pad, -pad)
    scrollContainer:SetPoint("BOTTOMRIGHT", -pad, pad)

    local scrollBox = CreateFrame("Frame", nil, scrollContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    self[config.scrollBoxKey] = scrollBox

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(config.elementExtent or CONSTS.HIERARCHY_HEADER_HEIGHT)
    view:SetPadding(0, 0, 0, 0, 4)
    view:SetElementInitializer("Button", config.setupFn)

    scrollBox:Init(view)
    self[config.dataProviderKey] = CreateDataProvider()
    scrollBox:SetDataProvider(self[config.dataProviderKey])

    return panel
end

--------------------------------------------------------------------------------
-- Selection Button State Helper
--------------------------------------------------------------------------------

-- Apply visual state to hierarchy panel selection buttons (expansions, categories, professions)
-- @param frame: Button frame with .bg, .selectionBorder, .label elements
-- @param isSelected: boolean
function TabBaseMixin:ApplySelectionButtonState(frame, isSelected)
    if isSelected then
        frame.bg:SetColorTexture(unpack(COLORS.PANEL_HOVER))
        frame.selectionBorder:Show()
        frame.label:SetTextColor(unpack(COLORS.GOLD))
    else
        frame.bg:SetColorTexture(unpack(COLORS.PANEL_NORMAL))
        frame.selectionBorder:Hide()
        frame.label:SetTextColor(unpack(COLORS.TEXT_SECONDARY))
    end
end

--------------------------------------------------------------------------------
-- Responsive Toolbar Layout
--------------------------------------------------------------------------------

-- Update toolbar element visibility based on available width
-- Delegates to shared addon helper, stores layout state on tab
function TabBaseMixin:UpdateToolbarLayout(toolbarWidth)
    local newLayout = addon:UpdateSimpleToolbarLayout(
        self.toolbarLayout, toolbarWidth, self.searchBox, self.filterContainer
    )
    if newLayout then
        self.toolbarLayout = newLayout
        addon:Debug((self.tabName or "Tab") .. " toolbar layout: " .. newLayout .. " (width: " .. math.floor(toolbarWidth) .. ")")
    end
end

--------------------------------------------------------------------------------
-- Search Box Debounce Wiring
--------------------------------------------------------------------------------

-- Wire up debounced search behavior for a SearchBoxTemplate EditBox.
-- Calls self:OnSearchTextChanged(text) after INPUT_DEBOUNCE delay.
-- Clear button bypasses debounce for immediate feedback.
function TabBaseMixin:WireSearchBox(searchBox)
    local searchDebounceTimer
    searchBox:HookScript("OnTextChanged", function(box, userInput)
        if userInput then
            if searchDebounceTimer then searchDebounceTimer:Cancel() end
            local text = box:GetText()
            searchDebounceTimer = C_Timer.NewTimer(CONSTS.TIMER.INPUT_DEBOUNCE, function()
                searchDebounceTimer = nil
                if self:IsShown() then
                    self:OnSearchTextChanged(text)
                end
            end)
        end
    end)

    if searchBox.clearButton then
        searchBox.clearButton:HookScript("OnClick", function()
            if searchDebounceTimer then searchDebounceTimer:Cancel(); searchDebounceTimer = nil end
            self:OnSearchTextChanged("")
        end)
    end

    searchBox:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    searchBox:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
end

--------------------------------------------------------------------------------
-- Ownership Refresh Helper
--------------------------------------------------------------------------------

-- Register debounced RECORD_OWNERSHIP_UPDATED handler for a tab
-- @param refreshFn: function to call when ownership changes affect this tab
function TabBaseMixin:RegisterOwnershipRefresh(refreshFn)
    local ownershipRefreshTimer = nil

    addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function(recordID, collectionStateChanged, updateKind)
        if collectionStateChanged == false then return end
        if not self:IsShown() then return end

        if updateKind == "targeted" then
            if ownershipRefreshTimer then ownershipRefreshTimer:Cancel() end
            ownershipRefreshTimer = C_Timer.NewTimer(CONSTS.TIMER.OWNERSHIP_REFRESH_DEBOUNCE, function()
                ownershipRefreshTimer = nil
                if self:IsShown() then
                    refreshFn()
                end
            end)
        else
            if ownershipRefreshTimer then
                ownershipRefreshTimer:Cancel()
                ownershipRefreshTimer = nil
            end
            refreshFn()
        end
    end)
end

--------------------------------------------------------------------------------
-- Tab Visibility Helper
--------------------------------------------------------------------------------

-- Register TAB_CHANGED handler to show/hide this tab frame
-- @param tabKey: string matching the tab's key (e.g., "QUESTS", "VENDORS")
function TabBaseMixin:RegisterTabVisibility(tabKey)
    addon:RegisterInternalEvent("TAB_CHANGED", function(activeKey)
        if activeKey == tabKey then
            self:Show()
        else
            self:Hide()
        end
    end)
end
