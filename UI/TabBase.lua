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
-- Standard Toolbar Factory
--------------------------------------------------------------------------------

-- Create a standard toolbar with search box and completion filter buttons.
-- All 6 hierarchy tabs use identical toolbar layout; only L-key prefixes differ.
-- @param parent: Parent frame
-- @param config: { searchPlaceholderKey, filterPrefix, defaultFilter }
--   filterPrefix: e.g. "VENDORS" → uses L["VENDORS_FILTER_ALL"], L["VENDORS_FILTER_INCOMPLETE"], L["VENDORS_FILTER_COMPLETE"]
function TabBaseMixin:CreateStandardToolbar(parent, config)
    local L = addon.L

    local toolbar = CreateFrame("Frame", nil, parent)
    toolbar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    toolbar:SetHeight(CONSTS.HEADER_HEIGHT)
    toolbar:SetClipsChildren(true)
    self.toolbar = toolbar

    local bg = toolbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.07, 0.9)

    local searchBox = CreateFrame("EditBox", nil, toolbar, "SearchBoxTemplate")
    searchBox:SetPoint("LEFT", toolbar, "LEFT", CONSTS.GRID_OUTER_PAD + 40, 0)
    searchBox:SetSize(250, 20)
    searchBox:SetAutoFocus(false)
    searchBox.Instructions:SetText(L[config.searchPlaceholderKey])
    searchBox.Instructions:SetWordWrap(false)
    self.searchBox = searchBox

    self:WireSearchBox(searchBox)

    local filterContainer = CreateFrame("Frame", nil, toolbar)
    filterContainer:SetPoint("LEFT", searchBox, "RIGHT", 16, 0)
    filterContainer:SetHeight(22)
    self.filterContainer = filterContainer

    local prefix = config.filterPrefix
    local filters = {
        { key = "all", label = L[prefix .. "_FILTER_ALL"] },
        { key = "incomplete", label = L[prefix .. "_FILTER_INCOMPLETE"] },
        { key = "complete", label = L[prefix .. "_FILTER_COMPLETE"] },
    }

    local xOffset = 0
    for _, filterInfo in ipairs(filters) do
        local btn = addon:CreateActionButton(filterContainer, filterInfo.label, function()
            self:SetCompletionFilter(filterInfo.key)
        end)
        btn:SetPoint("LEFT", filterContainer, "LEFT", xOffset, 0)
        btn.filterKey = filterInfo.key
        self.filterButtons[filterInfo.key] = btn
        xOffset = xOffset + btn:GetWidth() + 4
    end

    filterContainer:SetWidth(xOffset - 4)
    self:SetCompletionFilter(config.defaultFilter or "incomplete")

    toolbar:SetScript("OnSizeChanged", function(_, width)
        self:UpdateToolbarLayout(width)
    end)
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
    self.ownershipRefreshFn = refreshFn

    addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function(recordID, collectionStateChanged, updateKind)
        if collectionStateChanged == false then return end
        if not self:IsShown() then self.ownershipDirty = true; return end

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
            if self.ownershipDirty and self.ownershipRefreshFn then
                self.ownershipDirty = nil
                self.ownershipRefreshFn()
                self.ownershipRefreshedThisShow = true
            end
            self:Show()
        else
            self:Hide()
        end
    end)
end

--------------------------------------------------------------------------------
-- Source-Category Tab Framework
-- Shared lifecycle, panels, selection, and display-building for tabs that use
-- a Category > Source > Decor hierarchy (DropsTab, PvPTab).
-- Tabs opt-in by setting self.cfg before relying on these methods.
-- Tabs MUST override SetupSourceRow. May override SourceMatchesSearch,
-- SourcePassesCompletionFilter.
--------------------------------------------------------------------------------

local SOURCE_ROW_BASE_HEIGHT = 32
local DECOR_ROW_HEIGHT = 24
local DECOR_ICON_SIZE = 22
local CATEGORY_ICON_SIZE = 20
local ICON_CROP_COORDS = CONSTS.ICON_CROP_COORDS
local VALID_FILTERS = { all = true, incomplete = true, complete = true }

local function FindCategoryInList(elements, category)
    for _, elem in ipairs(elements) do
        if elem.category == category then return true end
    end
    return false
end

local function FindSourceInList(elements, sourceName)
    for _, elem in ipairs(elements) do
        if elem.sourceName == sourceName then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- DB Accessor
--------------------------------------------------------------------------------

function TabBaseMixin:GetDB()
    return addon.db and addon.db.browser and addon.db.browser[self.cfg.dbKey]
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function TabBaseMixin:Create(parent)
    if self.frame then return end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    self.frame = frame

    self:CreateToolbar(frame)
    self:CreateCategoryPanel(frame)
    self:CreateSourcePanel(frame)
    self:CreateEmptyStates()

    addon:Debug(self.cfg.tabDebugLabel)
end

function TabBaseMixin:Show()
    if not self.frame then return end

    local skipRefresh = self.ownershipRefreshedThisShow
    self.ownershipRefreshedThisShow = nil

    local flag = self.cfg.indexBuiltFlag
    if not addon[flag] then
        addon[self.cfg.buildIndexFn](addon)
    end

    self.frame:Show()

    if self.pendingNavigation then
        self.pendingNavigation = nil
        return
    end

    local saved = self:GetDB()
    if saved then
        self.selectedCategory = saved.selectedCategory
        self:SetCompletionFilter(saved.completionFilter or "incomplete", skipRefresh)
    end

    self:UpdateEmptyStates()
end

function TabBaseMixin:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function TabBaseMixin:IsShown()
    return self.frame and self.frame:IsShown()
end

--------------------------------------------------------------------------------
-- Toolbar (delegates to existing CreateStandardToolbar)
--------------------------------------------------------------------------------

function TabBaseMixin:CreateToolbar(parent)
    self:CreateStandardToolbar(parent, {
        searchPlaceholderKey = self.cfg.searchPlaceholderKey,
        filterPrefix = self.cfg.filterPrefix,
    })
end

function TabBaseMixin:SetCompletionFilter(filterKey, skipRefresh)
    if not VALID_FILTERS[filterKey] then filterKey = "incomplete" end
    for key, btn in pairs(self.filterButtons) do
        btn:SetActive(key == filterKey)
    end
    local db = self:GetDB()
    if db then db.completionFilter = filterKey end
    if not skipRefresh then
        self:RefreshDisplay()
    end
end

function TabBaseMixin:GetCompletionFilter()
    local db = self:GetDB()
    return db and db.completionFilter or "incomplete"
end

function TabBaseMixin:NavigateFromProgress(category, filter)
    if self.searchBox then
        self.searchBox:SetText("")
    end
    self:SetCompletionFilter(filter or "incomplete", true)
    self:BuildCategoryDisplay()
    if category then
        self:SelectCategory(category)
    end
end

function TabBaseMixin:OnSearchTextChanged(_)
    self:RefreshDisplay()
end

--------------------------------------------------------------------------------
-- Category Panel (Left Column)
--------------------------------------------------------------------------------

function TabBaseMixin:CreateCategoryPanel(parent)
    self:CreateHierarchyPanel(parent, {
        panelKey        = "categoryPanel",
        scrollBoxKey    = "categoryScrollBox",
        dataProviderKey = "categoryDataProvider",
        elementExtent   = CONSTS.HIERARCHY_HEADER_HEIGHT,
        setupFn         = function(frame, elementData)
            self:SetupCategoryButton(frame, elementData)
        end,
    })
end

function TabBaseMixin:SetupCategoryButton(frame, elementData)
    local L = addon.L

    if not frame.bg then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        frame.bg = bg

        local border = frame:CreateTexture(nil, "ARTWORK")
        border:SetWidth(3)
        border:SetPoint("TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMLEFT", 0, 0)
        border:SetColorTexture(unpack(COLORS.GOLD))
        border:Hide()
        frame.selectionBorder = border

        local catIcon = frame:CreateTexture(nil, "ARTWORK")
        catIcon:SetSize(CATEGORY_ICON_SIZE, CATEGORY_ICON_SIZE)
        catIcon:SetPoint("LEFT", 8, 0)
        frame.catIcon = catIcon

        local pct = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        pct:SetPoint("RIGHT", -8, 0)
        pct:SetJustifyH("RIGHT")
        frame.percentLabel = pct

        local label = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", catIcon, "RIGHT", 6, 0)
        label:SetPoint("RIGHT", pct, "LEFT", -4, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        frame.label = label

        frame:EnableMouse(true)
        frame:SetScript("OnClick", function(f) self:SelectCategory(f.category) end)
        frame:SetScript("OnEnter", function(f)
            if self.selectedCategory ~= f.category then
                f.bg:SetColorTexture(unpack(COLORS.PANEL_HOVER))
            end
        end)
        frame:SetScript("OnLeave", function(f)
            self:ApplySelectionButtonState(f, self.selectedCategory == f.category)
        end)
    end

    frame.category = elementData.category

    local isSelected = self.selectedCategory == elementData.category
    self:ApplySelectionButtonState(frame, isSelected)

    local catInfo = self.cfg.getCategoryInfo(elementData.category)
    if catInfo then
        if catInfo.atlas then
            frame.catIcon:SetAtlas(catInfo.atlas)
        else
            frame.catIcon:SetTexture(catInfo.icon)
            frame.catIcon:SetTexCoord(unpack(ICON_CROP_COORDS))
        end
        frame.label:SetText(L[catInfo.labelKey] or elementData.category)
    else
        frame.catIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        frame.label:SetText(elementData.category)
    end
    addon:SetFontSize(frame.label, 13, "")

    local owned, total = self.cfg.getCategoryProgress(elementData.category)
    local pctValue = total > 0 and (owned / total * 100) or 0
    frame.percentLabel:SetText(string.format("%.0f%%", pctValue))
    frame.percentLabel:SetTextColor(addon:GetCompletionProgressColor(pctValue))
    addon:SetFontSize(frame.percentLabel, 11, "")
end

function TabBaseMixin:SelectCategory(category)
    local prevSelected = self.selectedCategory
    self.selectedCategory = category

    local db = self:GetDB()
    if db then db.selectedCategory = category end

    if self.categoryScrollBox then
        self.categoryScrollBox:ForEachFrame(function(frame)
            if frame.category then
                self:ApplySelectionButtonState(frame, frame.category == category)
            end
        end)
    end

    self:BuildSourceDisplay()

    if prevSelected ~= category then
        self.selectedSourceName = nil
        self.selectedDecorId = nil
        addon:FireEvent("RECORD_SELECTED", nil)
    end

    self:UpdateEmptyStates()
end

--------------------------------------------------------------------------------
-- Source Panel (Right Side)
--------------------------------------------------------------------------------

function TabBaseMixin:CreateSourcePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", self.categoryPanel, "TOPRIGHT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.sourcePanel = panel

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)

    local pad = CONSTS.HIERARCHY_PADDING
    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", pad, -pad)
    scrollContainer:SetPoint("BOTTOMRIGHT", -pad - 16, pad)

    local scrollBox = CreateFrame("Frame", nil, scrollContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    self.sourceScrollBox = scrollBox

    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollContainer, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollContainer, "BOTTOMRIGHT", 4, 0)
    self.sourceScrollBar = scrollBar

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, elementData)
        local decorCount = elementData.decorIds and #elementData.decorIds or 0
        return SOURCE_ROW_BASE_HEIGHT + (decorCount * DECOR_ROW_HEIGHT)
    end)
    view:SetElementInitializer("Button", function(frame, elementData)
        self:SetupSourceButton(frame, elementData)
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    self.sourceView = view

    self.sourceDataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(self.sourceDataProvider)
end

function TabBaseMixin:SetupSourceButton(frame, elementData)
    if not frame.initialized then
        self:InitializeSourceFrame(frame)
        frame.initialized = true
    end
    self:ResetSourceFrame(frame)
    self:SetupSourceRow(frame, elementData)
end

function TabBaseMixin:InitializeSourceFrame(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.bg = bg

    local border = frame:CreateTexture(nil, "ARTWORK")
    border:SetWidth(3)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMLEFT", 0, 0)
    border:SetColorTexture(unpack(COLORS.GOLD))
    border:Hide()
    frame.selectionBorder = border

    local sourceContainer = CreateFrame("Frame", nil, frame)
    sourceContainer:SetPoint("TOPLEFT", 8, 0)
    sourceContainer:SetPoint("TOPRIGHT", -8, 0)
    sourceContainer:SetHeight(SOURCE_ROW_BASE_HEIGHT)
    frame.sourceContainer = sourceContainer

    local sourceName = addon:CreateFontString(sourceContainer, "OVERLAY", "GameFontNormal")
    sourceName:SetPoint("TOPLEFT", 4, -8)
    sourceName:SetJustifyH("LEFT")
    sourceName:SetPoint("RIGHT", -60, 0)
    sourceName:SetWordWrap(false)
    frame.sourceName = sourceName

    local sourceProgress = addon:CreateFontString(sourceContainer, "OVERLAY", "GameFontNormal")
    sourceProgress:SetPoint("TOPRIGHT", -4, -8)
    sourceProgress:SetJustifyH("RIGHT")
    frame.sourceProgress = sourceProgress

    local decorContainer = CreateFrame("Frame", nil, frame)
    decorContainer:SetPoint("TOPLEFT", sourceContainer, "BOTTOMLEFT", 0, 0)
    decorContainer:SetPoint("TOPRIGHT", sourceContainer, "BOTTOMRIGHT", 0, 0)
    frame.decorContainer = decorContainer

    frame.decorRows = {}
    frame:EnableMouse(true)

    frame:SetScript("OnClick", function(f, button)
        if button == "RightButton" then return end
        local decorIds = f.decorIds
        if not decorIds or #decorIds == 0 then return end
        self:HandleItemSelection({
            decorId = decorIds[1],
            sourceNameKey = f.sourceNameKey,
            isSourceRow = true,
            sourceFrame = f,
        })
    end)
    frame:SetScript("OnEnter", function(f)
        if self.selectedSourceName ~= f.sourceNameKey then
            f.bg:SetColorTexture(0.12, 0.12, 0.14, 1)
        end
        local decorIds = f.decorIds
        if decorIds and #decorIds > 0 then
            addon:FireEvent("RECORD_SELECTED", decorIds[1])
        end
    end)
    frame:SetScript("OnLeave", function(f)
        if self.selectedSourceName ~= f.sourceNameKey then
            f.bg:SetColorTexture(unpack(COLORS.ROW_BG))
        end
        self:RestoreSelectionOnLeave()
    end)
end

function TabBaseMixin:ResetSourceFrame(frame)
    frame.selectionBorder:Hide()
    frame.sourceContainer:Hide()
    frame.decorContainer:Hide()
    frame.sourceNameKey = nil
    frame.decorIds = nil

    for _, row in ipairs(frame.decorRows) do
        row:Hide()
        if row.selectionHighlight then
            row.selectionHighlight:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Selection Helpers
--------------------------------------------------------------------------------

function TabBaseMixin:UpdateSourceSelectionVisual(frame, isSelected)
    if not frame then return end
    if isSelected then
        frame.selectionBorder:Show()
        frame.bg:SetColorTexture(0.12, 0.12, 0.14, 1)
    else
        frame.selectionBorder:Hide()
        frame.bg:SetColorTexture(unpack(COLORS.ROW_BG))
    end
end

function TabBaseMixin:UpdateDecorSelectionVisual(row, isSelected, textBrightness)
    if not row then return end
    if row.selectionHighlight then
        row.selectionHighlight:SetShown(isSelected)
    end
    if isSelected then
        row.name:SetTextColor(unpack(COLORS.GOLD))
    else
        row.name:SetTextColor(textBrightness, textBrightness, textBrightness, 1)
    end
end

function TabBaseMixin:HandleItemSelection(params)
    local isCurrentlySelected = self.selectedSourceName == params.sourceNameKey
        and self.selectedDecorId == params.decorId

    if isCurrentlySelected then
        if params.isSourceRow then
            self:UpdateSourceSelectionVisual(params.sourceFrame, false)
        else
            self:UpdateDecorSelectionVisual(params.decorRow, false, params.decorRow.textBrightness)
        end
        self.selectedSourceName = nil
        self.selectedDecorId = nil
        addon:FireEvent("RECORD_SELECTED", nil)
    else
        if self.selectedSourceName then
            self.sourceScrollBox:ForEachFrame(function(f)
                if f.sourceNameKey == self.selectedSourceName then
                    self:UpdateSourceSelectionVisual(f, false)
                end
            end)
        end
        if self.selectedDecorId then
            self.sourceScrollBox:ForEachFrame(function(f)
                if f.decorRows then
                    for _, row in pairs(f.decorRows) do
                        if row.decorId == self.selectedDecorId and f.sourceNameKey == self.selectedSourceName then
                            self:UpdateDecorSelectionVisual(row, false, row.textBrightness or 0.7)
                        end
                    end
                end
            end)
        end

        self.selectedSourceName = params.sourceNameKey
        self.selectedDecorId = params.decorId
        if params.isSourceRow then
            self:UpdateSourceSelectionVisual(params.sourceFrame, true)
        else
            self:UpdateDecorSelectionVisual(params.decorRow, true, params.decorRow.textBrightness)
        end
        addon:FireEvent("RECORD_SELECTED", params.decorId)
    end
end

function TabBaseMixin:RestoreSelectionOnLeave()
    addon:FireEvent("RECORD_SELECTED", self.selectedDecorId)
end

--------------------------------------------------------------------------------
-- Decor Rows (inside source frames)
--------------------------------------------------------------------------------

function TabBaseMixin:SetupDecorRows(frame, decorIds)
    for i, decorId in ipairs(decorIds) do
        local row = frame.decorRows[i]
        if not row then
            row = CreateFrame("Button", nil, frame.decorContainer)
            row:SetHeight(DECOR_ROW_HEIGHT)

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(DECOR_ICON_SIZE, DECOR_ICON_SIZE)
            icon:SetPoint("LEFT", 20, 0)
            row.icon = icon

            local checkIcon = row:CreateTexture(nil, "OVERLAY")
            checkIcon:SetSize(14, 14)
            checkIcon:SetPoint("LEFT", 4, 0)
            checkIcon:SetAtlas("common-icon-checkmark")
            checkIcon:SetVertexColor(0.4, 0.9, 0.4, 1)
            checkIcon:Hide()
            row.checkIcon = checkIcon

            local name = addon:CreateFontString(row, "OVERLAY", "GameFontNormal")
            name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            name:SetPoint("RIGHT", -60, 0)
            name:SetJustifyH("LEFT")
            name:SetWordWrap(false)
            row.name = name

            local selHighlight = row:CreateTexture(nil, "BACKGROUND")
            selHighlight:SetWidth(2)
            selHighlight:SetPoint("TOPLEFT", 0, 0)
            selHighlight:SetPoint("BOTTOMLEFT", 0, 0)
            selHighlight:SetColorTexture(unpack(COLORS.GOLD))
            selHighlight:Hide()
            row.selectionHighlight = selHighlight

            row:EnableMouse(true)
            row:SetScript("OnClick", function(r)
                local did = r.decorId
                if IsShiftKeyDown() then
                    addon:ToggleTracking(did)
                    return
                end
                self:HandleItemSelection({
                    decorId = did,
                    sourceNameKey = r.sourceNameKey,
                    isSourceRow = false,
                    decorRow = r,
                })
            end)
            row:SetScript("OnEnter", function(r)
                local did = r.decorId
                if not (self.selectedSourceName == r.sourceNameKey and self.selectedDecorId == did) then
                    r.name:SetTextColor(1, 1, 1, 1)
                end
                addon:FireEvent("RECORD_SELECTED", did)

                addon:AnchorTooltipToCursor(r)
                GameTooltip:SetText(addon:ResolveDecorName(did, r.record), 1, 1, 1)
                if r.isCollected then
                    GameTooltip:AddLine(addon.L["FILTER_COLLECTED"], 0.4, 0.9, 0.4)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function(r)
                local did = r.decorId
                if not (self.selectedSourceName == r.sourceNameKey and self.selectedDecorId == did) then
                    r.name:SetTextColor(r.textBrightness, r.textBrightness, r.textBrightness, 1)
                end
                GameTooltip:Hide()
                self:RestoreSelectionOnLeave()
            end)
            frame.decorRows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.decorContainer, "TOPLEFT", 0, -((i - 1) * DECOR_ROW_HEIGHT))
        row:SetPoint("RIGHT", frame.decorContainer, "RIGHT", 0, 0)
        row:Show()

        local record = addon:ResolveRecord(decorId)

        row.decorId = decorId
        row.record = record
        row.isCollected = record and record.isCollected
        row.sourceNameKey = frame.sourceNameKey

        if record then
            if record.iconType == "atlas" then
                row.icon:SetAtlas(record.icon)
            else
                row.icon:SetTexture(record.icon)
            end
        else
            row.icon:SetTexture(addon:ResolveDecorIcon(decorId))
        end

        row.checkIcon:SetShown(row.isCollected)

        local textBrightness = row.isCollected and 0.4 or 0.7
        row.textBrightness = textBrightness
        local displayName = addon:ResolveDecorName(decorId, record)
        row.name:SetText(displayName)
        addon:SetFontSize(row.name, 13, "")

        local isItemSelected = self.selectedSourceName == frame.sourceNameKey and self.selectedDecorId == decorId
        self:UpdateDecorSelectionVisual(row, isItemSelected, textBrightness)
    end
end

--------------------------------------------------------------------------------
-- Search/Filter (default implementations — override per tab if needed)
--------------------------------------------------------------------------------

function TabBaseMixin:SourceMatchesSearch(sourceData, searchText, category)
    if searchText == "" then return true end

    if sourceData.sourceName and strlower(sourceData.sourceName):find(searchText, 1, true) then
        return true
    end

    local localizedName = addon:GetLocalizedSourceName(sourceData.sourceName)
    if localizedName and localizedName ~= sourceData.sourceName and strlower(localizedName):find(searchText, 1, true) then
        return true
    end

    local catInfo = self.cfg.getCategoryInfo(category)
    if catInfo then
        local catLabel = strlower(addon.L[catInfo.labelKey] or "")
        if catLabel:find(searchText, 1, true) then return true end
    end

    for _, decorId in ipairs(sourceData.decorIds or {}) do
        local name = addon:ResolveDecorName(decorId, addon:GetRecord(decorId))
        if name and strlower(name):find(searchText, 1, true) then
            return true
        end
    end

    return false
end

function TabBaseMixin:SourcePassesCompletionFilter(sourceData, filter)
    if filter == "all" then return true end

    local owned, total
    local getProgress = self.cfg.getSourceProgress
    if getProgress then
        owned, total = getProgress(sourceData)
    else
        owned, total = 0, 0
        for _, decorId in ipairs(sourceData.decorIds or {}) do
            total = total + 1
            if addon:IsDecorCollected(decorId) then owned = owned + 1 end
        end
    end

    local isComplete = total > 0 and owned == total
    if filter == "complete" then return isComplete end
    if filter == "incomplete" then return not isComplete end
end

function TabBaseMixin:BuildSourceVisibilityCache(filter, searchText)
    local cache = {}
    for _, category in ipairs(self.cfg.getSortedCategories()) do
        for _, sourceData in ipairs(self.cfg.getSourcesForCategory(category)) do
            if self:SourcePassesCompletionFilter(sourceData, filter)
                and self:SourceMatchesSearch(sourceData, searchText, category) then
                cache[category .. "\0" .. sourceData.sourceName] = true
            end
        end
    end
    return cache
end

function TabBaseMixin:IsSourceVisible(sourceData, category, filter, searchText, visCache)
    if visCache then
        return visCache[category .. "\0" .. sourceData.sourceName] or false
    end
    return self:SourcePassesCompletionFilter(sourceData, filter)
        and self:SourceMatchesSearch(sourceData, searchText, category)
end

--------------------------------------------------------------------------------
-- Display Building
--------------------------------------------------------------------------------

function TabBaseMixin:BuildCategoryDisplay(visCache)
    if not self.categoryScrollBox or not self.categoryDataProvider then return false end

    local elements = {}
    local filter = self:GetCompletionFilter()
    local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

    for _, category in ipairs(self.cfg.getSortedCategories()) do
        local hasVisibleContent = false
        for _, sourceData in ipairs(self.cfg.getSourcesForCategory(category)) do
            if self:IsSourceVisible(sourceData, category, filter, searchText, visCache) then
                hasVisibleContent = true
                break
            end
        end
        if hasVisibleContent then
            table.insert(elements, { category = category })
        end
    end

    self.categoryDataProvider:Flush()
    if #elements > 0 then
        self.categoryDataProvider:InsertTable(elements)
    end

    if #elements > 0 and not FindCategoryInList(elements, self.selectedCategory) then
        self:SelectCategory(elements[1].category)
        return true
    elseif self.selectedCategory and not FindCategoryInList(elements, self.selectedCategory) then
        self.selectedCategory = nil
        self.selectedSourceName = nil
        self.selectedDecorId = nil
        local db = self:GetDB()
        if db then db.selectedCategory = nil end
        addon:FireEvent("RECORD_SELECTED", nil)
        self:BuildSourceDisplay()
        return true
    end
    return false
end

function TabBaseMixin:BuildSourceDisplay(visCache)
    if not self.sourceScrollBox or not self.sourceDataProvider then return end

    local elements = {}
    local category = self.selectedCategory

    if category then
        local filter = self:GetCompletionFilter()
        local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

        for _, sourceData in ipairs(self.cfg.getSourcesForCategory(category)) do
            if self:IsSourceVisible(sourceData, category, filter, searchText, visCache) then
                table.insert(elements, sourceData)
            end
        end
    end

    self.sourceDataProvider:Flush()
    if #elements > 0 then
        self.sourceDataProvider:InsertTable(elements)
    end

    if self.selectedSourceName and not FindSourceInList(elements, self.selectedSourceName) then
        self.selectedSourceName = nil
        self.selectedDecorId = nil
        addon:FireEvent("RECORD_SELECTED", nil)
    end

    self:UpdateEmptyStates()
end

function TabBaseMixin:RefreshDisplay()
    addon:CountDebug("rebuild", self.cfg.countDebugLabel)

    local filter = self:GetCompletionFilter()
    local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))
    local visCache = self:BuildSourceVisibilityCache(filter, searchText)

    local rebuilt = self:BuildCategoryDisplay(visCache)
    if not rebuilt then self:BuildSourceDisplay(visCache) end
end

--------------------------------------------------------------------------------
-- Empty States
--------------------------------------------------------------------------------

function TabBaseMixin:GetActiveSearchText()
    return strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))
end

function TabBaseMixin:CreateEmptyStates()
    local cfg = self.cfg
    self.emptyState = addon:CreateEmptyStateFrame(
        self.categoryPanel,
        cfg.emptyNoSourcesKey,
        cfg.emptyNoSourcesDescKey,
        CONSTS.HIERARCHY_PANEL_WIDTH - 16
    )
    self.noCategoryState = addon:CreateEmptyStateFrame(self.sourcePanel, cfg.emptySelectCategoryKey)
    self.noResultsState = addon:CreateEmptyStateFrame(self.sourcePanel, cfg.emptyNoResultsKey)
end

function TabBaseMixin:UpdateEmptyStates()
    local hasSources = self.cfg.getSourceCount() > 0
    local hasSelection = self.selectedCategory ~= nil
    local dataProvider = self.sourceScrollBox and self.sourceScrollBox:GetDataProvider()
    local hasResults = dataProvider and dataProvider:GetSize() > 0
    local searchText = self:GetActiveSearchText()
    local hasActiveFilter = (searchText ~= "") or (self:GetCompletionFilter() ~= "all")
    local showSourceList = hasSources and hasSelection and hasResults

    if self.emptyState then self.emptyState:SetShown(not hasSources) end
    if self.noCategoryState then self.noCategoryState:SetShown(hasSources and not hasSelection and not hasActiveFilter) end
    if self.noResultsState then self.noResultsState:SetShown(hasSources and not hasResults and (hasSelection or hasActiveFilter)) end
    if self.categoryScrollBox then self.categoryScrollBox:SetShown(hasSources) end
    if self.sourceScrollBox then self.sourceScrollBox:SetShown(showSourceList) end
    if self.sourceScrollBar then self.sourceScrollBar:SetShown(showSourceList) end
end
