--[[
    Housing Codex - DropsTab.lua
    Drop sources tab with Category > Source hierarchy.
    Left panel: source categories (Drops, Bosses, Treasure)
    Right panel: source entries with decor items
]]

local _, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS
local ICON_CROP_COORDS = CONSTS.ICON_CROP_COORDS

local CATEGORY_PANEL_WIDTH = CONSTS.HIERARCHY_PANEL_WIDTH
local HIERARCHY_PADDING = CONSTS.HIERARCHY_PADDING
local HEADER_HEIGHT = CONSTS.HIERARCHY_HEADER_HEIGHT

local SOURCE_ROW_BASE_HEIGHT = 32
local DECOR_ROW_HEIGHT = 24
local DECOR_ICON_SIZE = 22
local CATEGORY_ICON_SIZE = 20

addon.DropsTab = {}
local DropsTab = addon.DropsTab
local VALID_FILTERS = { all = true, incomplete = true, complete = true }

Mixin(DropsTab, addon.TabBaseMixin)
DropsTab.tabName = "DropsTab"

local function GetDropsDB()
    return addon.db and addon.db.browser and addon.db.browser.drops
end

local function EnsureDropsDB()
    if not addon.db then return nil end
    addon.db.browser = addon.db.browser or {}
    addon.db.browser.drops = addon.db.browser.drops or {
        selectedCategory = nil,
        completionFilter = "incomplete",
    }
    return addon.db.browser.drops
end

DropsTab.frame = nil
DropsTab.toolbar = nil
DropsTab.categoryPanel = nil
DropsTab.categoryScrollBox = nil
DropsTab.sourcePanel = nil
DropsTab.sourceScrollBox = nil
DropsTab.sourceScrollBar = nil
DropsTab.searchBox = nil
DropsTab.filterButtons = {}
DropsTab.emptyState = nil
DropsTab.noCategoryState = nil
DropsTab.noResultsState = nil

DropsTab.selectedCategory = nil
DropsTab.selectedSourceName = nil
DropsTab.selectedDecorId = nil
DropsTab.toolbarLayout = nil
DropsTab.filterContainer = nil

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------

function DropsTab:Create(parent)
    if self.frame then return end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    self.frame = frame

    self:CreateToolbar(frame)
    self:CreateCategoryPanel(frame)
    self:CreateSourcePanel(frame)
    self:CreateEmptyStates()

    addon:Debug("DropsTab created")
end

function DropsTab:Show()
    if not self.frame then return end

    if not addon.dropIndexBuilt then
        addon:BuildDropIndex()
    end

    self.frame:Show()
    EnsureDropsDB()

    -- Skip default rebuild when navigating from Progress
    if self.pendingNavigation then
        self.pendingNavigation = nil
        return
    end

    local saved = GetDropsDB()
    if saved then
        self.selectedCategory = saved.selectedCategory
        self:SetCompletionFilter(saved.completionFilter or "incomplete")
    end

    self:UpdateEmptyStates()
end

function DropsTab:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function DropsTab:IsShown()
    return self.frame and self.frame:IsShown()
end

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------

function DropsTab:CreateToolbar(parent)
    self:CreateStandardToolbar(parent, {
        searchPlaceholderKey = "DROPS_SEARCH_PLACEHOLDER",
        filterPrefix = "DROPS",
    })
end

function DropsTab:SetCompletionFilter(filterKey, skipRefresh)
    if not VALID_FILTERS[filterKey] then filterKey = "incomplete" end
    for key, btn in pairs(self.filterButtons) do
        btn:SetActive(key == filterKey)
    end
    local db = GetDropsDB()
    if db then db.completionFilter = filterKey end
    if not skipRefresh then
        self:RefreshDisplay()
    end
end

function DropsTab:GetCompletionFilter()
    local db = GetDropsDB()
    return db and db.completionFilter or "incomplete"
end

function DropsTab:NavigateFromProgress(category)
    if self.searchBox then
        self.searchBox:SetText("")
    end
    self:SetCompletionFilter("incomplete", true)
    self:SelectCategory(category)
end

function DropsTab:OnSearchTextChanged(_)
    self:RefreshDisplay()
end

--------------------------------------------------------------------------------
-- Category Panel (Left Column)
--------------------------------------------------------------------------------

function DropsTab:CreateCategoryPanel(parent)
    self:CreateHierarchyPanel(parent, {
        panelKey        = "categoryPanel",
        scrollBoxKey    = "categoryScrollBox",
        dataProviderKey = "categoryDataProvider",
        elementExtent   = HEADER_HEIGHT,
        setupFn         = function(frame, elementData)
            self:SetupCategoryButton(frame, elementData)
        end,
    })
end

-- Named handlers for category buttons (bound once, read data from frame fields)
local function DropCategoryButtonOnClick(frame)
    DropsTab:SelectCategory(frame.category)
end

local function DropCategoryButtonOnEnter(frame)
    if DropsTab.selectedCategory ~= frame.category then
        frame.bg:SetColorTexture(unpack(COLORS.PANEL_HOVER))
    end
end

local function DropCategoryButtonOnLeave(frame)
    DropsTab:ApplySelectionButtonState(frame, DropsTab.selectedCategory == frame.category)
end

-- Named handlers for source rows (bound once, read data from frame fields)
local function DropSourceRowOnClick(frame, button)
    if button == "RightButton" then return end
    local decorIds = frame.decorIds
    if not decorIds or #decorIds == 0 then return end
    DropsTab:HandleItemSelection({
        decorId = decorIds[1],
        sourceNameKey = frame.sourceNameKey,
        isSourceRow = true,
        sourceFrame = frame,
    })
end

local function DropSourceRowOnEnter(frame)
    if DropsTab.selectedSourceName ~= frame.sourceNameKey then
        frame.bg:SetColorTexture(0.12, 0.12, 0.14, 1)
    end
    local decorIds = frame.decorIds
    if decorIds and #decorIds > 0 then
        addon:FireEvent("RECORD_SELECTED", decorIds[1])
    end
end

local function DropSourceRowOnLeave(frame)
    if DropsTab.selectedSourceName ~= frame.sourceNameKey then
        frame.bg:SetColorTexture(unpack(COLORS.ROW_BG))
    end
    DropsTab:RestoreSelectionOnLeave()
end

-- Named handlers for decor rows (bound once, read data from row fields)
local function DropDecorRowOnClick(row)
    local decorId = row.decorId
    if IsShiftKeyDown() then
        addon:ToggleTracking(decorId)
        return
    end
    DropsTab:HandleItemSelection({
        decorId = decorId,
        sourceNameKey = row.sourceNameKey,
        isSourceRow = false,
        decorRow = row,
    })
end

local function DropDecorRowOnEnter(row)
    local decorId = row.decorId
    if not (DropsTab.selectedSourceName == row.sourceNameKey and DropsTab.selectedDecorId == decorId) then
        row.name:SetTextColor(1, 1, 1, 1)
    end
    addon:FireEvent("RECORD_SELECTED", decorId)

    addon:AnchorTooltipToCursor(row)
    GameTooltip:SetText(addon:ResolveDecorName(decorId, row.record), 1, 1, 1)
    if row.isCollected then
        GameTooltip:AddLine(addon.L["FILTER_COLLECTED"], 0.4, 0.9, 0.4)
    end
    GameTooltip:Show()
end

local function DropDecorRowOnLeave(row)
    local decorId = row.decorId
    if not (DropsTab.selectedSourceName == row.sourceNameKey and DropsTab.selectedDecorId == decorId) then
        row.name:SetTextColor(row.textBrightness, row.textBrightness, row.textBrightness, 1)
    end
    GameTooltip:Hide()
    DropsTab:RestoreSelectionOnLeave()
end

function DropsTab:SetupCategoryButton(frame, elementData)
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
        frame:SetScript("OnClick", DropCategoryButtonOnClick)
        frame:SetScript("OnEnter", DropCategoryButtonOnEnter)
        frame:SetScript("OnLeave", DropCategoryButtonOnLeave)
    end

    frame.category = elementData.category

    local isSelected = self.selectedCategory == elementData.category
    self:ApplySelectionButtonState(frame, isSelected)

    local catInfo = addon:GetSourceCategoryInfo(elementData.category)
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

    local owned, total = addon:GetDropCategoryCollectionProgress(elementData.category)
    local pctValue = total > 0 and (owned / total * 100) or 0
    frame.percentLabel:SetText(string.format("%.0f%%", pctValue))
    frame.percentLabel:SetTextColor(addon:GetCompletionProgressColor(pctValue))
    addon:SetFontSize(frame.percentLabel, 11, "")
end

function DropsTab:SelectCategory(category)
    local prevSelected = self.selectedCategory
    self.selectedCategory = category

    local db = GetDropsDB()
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

function DropsTab:CreateSourcePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", self.categoryPanel, "TOPRIGHT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.sourcePanel = panel

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)

    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", HIERARCHY_PADDING, -HIERARCHY_PADDING)
    scrollContainer:SetPoint("BOTTOMRIGHT", -HIERARCHY_PADDING - 16, HIERARCHY_PADDING)

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

function DropsTab:SetupSourceButton(frame, elementData)
    -- One-time frame setup
    if not frame.initialized then
        self:InitializeSourceFrame(frame)
        frame.initialized = true
    end

    -- Reset frame state
    self:ResetSourceFrame(frame)
    self:SetupSourceRow(frame, elementData)
end

function DropsTab:InitializeSourceFrame(frame)
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
    frame:SetScript("OnClick", DropSourceRowOnClick)
    frame:SetScript("OnEnter", DropSourceRowOnEnter)
    frame:SetScript("OnLeave", DropSourceRowOnLeave)
end

function DropsTab:ResetSourceFrame(frame)
    frame.selectionBorder:Hide()
    frame.sourceContainer:Hide()
    frame.decorContainer:Hide()
    frame.sourceNameKey = nil
    frame.decorIds = nil

    -- Hide all decor rows
    for _, row in ipairs(frame.decorRows) do
        row:Hide()
        if row.selectionHighlight then
            row.selectionHighlight:Hide()
        end
    end
end

-- Helper to update source row selection visual
function DropsTab:UpdateSourceSelectionVisual(frame, isSelected)
    if not frame then return end
    if isSelected then
        frame.selectionBorder:Show()
        frame.bg:SetColorTexture(0.12, 0.12, 0.14, 1)
    else
        frame.selectionBorder:Hide()
        frame.bg:SetColorTexture(unpack(COLORS.ROW_BG))
    end
end

-- Helper to update decor row selection visual
function DropsTab:UpdateDecorSelectionVisual(row, isSelected, textBrightness)
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

-- Shared selection toggle for source rows and decor rows
function DropsTab:HandleItemSelection(params)
    local isCurrentlySelected = self.selectedSourceName == params.sourceNameKey
        and self.selectedDecorId == params.decorId

    if isCurrentlySelected then
        -- Deselect
        if params.isSourceRow then
            self:UpdateSourceSelectionVisual(params.sourceFrame, false)
        else
            self:UpdateDecorSelectionVisual(params.decorRow, false, params.decorRow.textBrightness)
        end
        self.selectedSourceName = nil
        self.selectedDecorId = nil
        addon:FireEvent("RECORD_SELECTED", nil)
    else
        -- Clear previous source highlight
        if self.selectedSourceName then
            self.sourceScrollBox:ForEachFrame(function(f)
                if f.sourceNameKey == self.selectedSourceName then
                    self:UpdateSourceSelectionVisual(f, false)
                end
            end)
        end
        -- Clear previous decor highlight
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

        -- Select new
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

-- Shared OnLeave handler to restore selection state
function DropsTab:RestoreSelectionOnLeave()
    addon:FireEvent("RECORD_SELECTED", self.selectedDecorId)
end

function DropsTab:SetupSourceRow(frame, elementData)
    local L = addon.L
    local decorIds = elementData.decorIds or {}
    local decorCount = #decorIds
    frame:SetHeight(SOURCE_ROW_BASE_HEIGHT + (decorCount * DECOR_ROW_HEIGHT))
    frame.sourceNameKey = elementData.sourceName
    frame.decorIds = decorIds

    addon:ResetBackgroundTexture(frame.bg)
    frame.bg:SetColorTexture(unpack(COLORS.ROW_BG))

    frame.sourceContainer:Show()
    frame.decorContainer:Show()
    frame.decorContainer:SetHeight(decorCount * DECOR_ROW_HEIGHT)

    local displayName = addon:GetLocalizedSourceName(elementData.sourceName) or L["UNKNOWN"]
    frame.sourceName:SetText(displayName)
    frame.sourceName:SetTextColor(unpack(COLORS.SOURCE_NAME_GOLD))
    addon:SetFontSize(frame.sourceName, 14, "")

    -- Progress
    local owned = addon:GetDropSourceCollectionProgress(elementData)
    frame.sourceProgress:SetText(string.format("%d/%d", owned, decorCount))
    local progressComplete = owned == decorCount and decorCount > 0
    frame.sourceProgress:SetTextColor(unpack(progressComplete and COLORS.PROGRESS_COMPLETE or COLORS.TEXT_TERTIARY))
    addon:SetFontSize(frame.sourceProgress, 11, "")

    self:SetupDecorRows(frame, decorIds)

    -- Check if this source is currently selected
    local isSourceSelected = self.selectedSourceName == elementData.sourceName
    self:UpdateSourceSelectionVisual(frame, isSourceSelected)
end

function DropsTab:SetupDecorRows(frame, decorIds)
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

            -- Selection highlight (subtle left border)
            local selHighlight = row:CreateTexture(nil, "BACKGROUND")
            selHighlight:SetWidth(2)
            selHighlight:SetPoint("TOPLEFT", 0, 0)
            selHighlight:SetPoint("BOTTOMLEFT", 0, 0)
            selHighlight:SetColorTexture(unpack(COLORS.GOLD))
            selHighlight:Hide()
            row.selectionHighlight = selHighlight

            row:EnableMouse(true)
            row:SetScript("OnClick", DropDecorRowOnClick)
            row:SetScript("OnEnter", DropDecorRowOnEnter)
            row:SetScript("OnLeave", DropDecorRowOnLeave)
            frame.decorRows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.decorContainer, "TOPLEFT", 0, -((i - 1) * DECOR_ROW_HEIGHT))
        row:SetPoint("RIGHT", frame.decorContainer, "RIGHT", 0, 0)
        row:Show()

        -- ResolveRecord tries direct API lookup for items hidden from catalog search
        local record = addon:ResolveRecord(decorId)

        -- Store per-row data for named handlers
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

        -- Check if this item is currently selected (composite key: source + decor)
        local isItemSelected = self.selectedSourceName == frame.sourceNameKey and self.selectedDecorId == decorId
        self:UpdateDecorSelectionVisual(row, isItemSelected, textBrightness)
    end
end

--------------------------------------------------------------------------------
-- Search/Filter Logic
--------------------------------------------------------------------------------

local function SourceMatchesSearch(sourceData, searchText, category)
    if searchText == "" then return true end

    if sourceData.sourceName and strlower(sourceData.sourceName):find(searchText, 1, true) then
        return true
    end

    -- Also match localized source name
    local localizedName = addon:GetLocalizedSourceName(sourceData.sourceName)
    if localizedName and localizedName ~= sourceData.sourceName and strlower(localizedName):find(searchText, 1, true) then
        return true
    end

    -- Category label
    local catInfo = addon:GetSourceCategoryInfo(category)
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

local function SourcePassesCompletionFilter(sourceData, filter)
    if filter == "all" then return true end

    local owned, total = addon:GetDropSourceCollectionProgress(sourceData)
    local isComplete = total > 0 and owned == total
    if filter == "complete" then return isComplete end
    if filter == "incomplete" then return not isComplete end
end

--------------------------------------------------------------------------------
-- Display Building
--------------------------------------------------------------------------------

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

-- Evaluate source visibility once, keyed by "category\0sourceName" → true
local function BuildSourceVisibilityCache(filter, searchText)
    local cache = {}
    for _, category in ipairs(addon:GetSortedDropCategories()) do
        for _, sourceData in ipairs(addon:GetDropsForCategory(category)) do
            if SourcePassesCompletionFilter(sourceData, filter)
                and SourceMatchesSearch(sourceData, searchText, category) then
                cache[category .. "\0" .. sourceData.sourceName] = true
            end
        end
    end
    return cache
end

local function IsSourceVisible(sourceData, category, filter, searchText, visCache)
    if visCache then
        return visCache[category .. "\0" .. sourceData.sourceName] or false
    end
    return SourcePassesCompletionFilter(sourceData, filter)
        and SourceMatchesSearch(sourceData, searchText, category)
end

function DropsTab:BuildCategoryDisplay(visCache)
    if not self.categoryScrollBox or not self.categoryDataProvider then return false end

    local elements = {}
    local filter = self:GetCompletionFilter()
    local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

    for _, category in ipairs(addon:GetSortedDropCategories()) do
        local hasVisibleContent = false
        for _, sourceData in ipairs(addon:GetDropsForCategory(category)) do
            if IsSourceVisible(sourceData, category, filter, searchText, visCache) then
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

    if not self.selectedCategory and #elements > 0 then
        self:SelectCategory(elements[1].category)
        return true
    elseif self.selectedCategory and not FindCategoryInList(elements, self.selectedCategory) then
        if #elements > 0 then
            self:SelectCategory(elements[1].category)
            return true
        else
            self.selectedCategory = nil
            self:BuildSourceDisplay()
            return true
        end
    end
    return false
end

function DropsTab:BuildSourceDisplay(visCache)
    if not self.sourceScrollBox or not self.sourceDataProvider then return end

    local elements = {}
    local category = self.selectedCategory

    if category then
        local filter = self:GetCompletionFilter()
        local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

        for _, sourceData in ipairs(addon:GetDropsForCategory(category)) do
            if IsSourceVisible(sourceData, category, filter, searchText, visCache) then
                table.insert(elements, sourceData)
            end
        end
    end

    self.sourceDataProvider:Flush()
    if #elements > 0 then
        self.sourceDataProvider:InsertTable(elements)
    end

    -- Revalidate selection: clear if selected source was filtered out
    if self.selectedSourceName and not FindSourceInList(elements, self.selectedSourceName) then
        self.selectedSourceName = nil
        self.selectedDecorId = nil
        addon:FireEvent("RECORD_SELECTED", nil)
    end

    self:UpdateEmptyStates()
end

-- Rebuild categories, then sources if categories didn't already trigger a source rebuild
function DropsTab:RefreshDisplay()
    addon:CountDebug("rebuild", "DropsTab")

    local filter = self:GetCompletionFilter()
    local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))
    local visCache = BuildSourceVisibilityCache(filter, searchText)

    local rebuilt = self:BuildCategoryDisplay(visCache)
    if not rebuilt then self:BuildSourceDisplay(visCache) end
end

--------------------------------------------------------------------------------
-- Empty States
--------------------------------------------------------------------------------

function DropsTab:CreateEmptyStates()
    self.emptyState = addon:CreateEmptyStateFrame(
        self.categoryPanel,
        "DROPS_EMPTY_NO_SOURCES",
        "DROPS_EMPTY_NO_SOURCES_DESC",
        CATEGORY_PANEL_WIDTH - 16
    )
    self.noCategoryState = addon:CreateEmptyStateFrame(self.sourcePanel, "DROPS_SELECT_CATEGORY")
    self.noResultsState = addon:CreateEmptyStateFrame(self.sourcePanel, "DROPS_EMPTY_NO_RESULTS")
end

function DropsTab:UpdateEmptyStates()
    local hasDrops = addon:GetDropCount() > 0
    local hasSelection = self.selectedCategory ~= nil
    local dataProvider = self.sourceScrollBox and self.sourceScrollBox:GetDataProvider()
    local hasResults = dataProvider and dataProvider:GetSize() > 0
    local showSourceList = hasDrops and hasSelection and hasResults

    if self.emptyState then self.emptyState:SetShown(not hasDrops) end
    if self.noCategoryState then self.noCategoryState:SetShown(hasDrops and not hasSelection) end
    if self.noResultsState then self.noResultsState:SetShown(hasDrops and hasSelection and not hasResults) end
    if self.categoryScrollBox then self.categoryScrollBox:SetShown(hasDrops) end
    if self.sourceScrollBox then self.sourceScrollBox:SetShown(showSourceList) end
    if self.sourceScrollBar then self.sourceScrollBar:SetShown(showSourceList) end
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

DropsTab:RegisterTabVisibility("DROPS")

addon:RegisterInternalEvent("DATA_LOADED", function()
    if DropsTab:IsShown() and not addon.dropIndexBuilt then
        addon:BuildDropIndex()
        DropsTab:RefreshDisplay()
    end
end)

DropsTab:RegisterOwnershipRefresh(function() DropsTab:RefreshDisplay() end)

addon.MainFrame:RegisterContentAreaInitializer("DropsTab", function(contentArea)
    DropsTab:Create(contentArea)
end)
