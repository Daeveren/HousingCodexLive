--[[
    Housing Codex - DropsTab.lua
    Drop sources tab with Category > Source hierarchy.
    Left panel: source categories (Drops, Bosses, Treasure)
    Right panel: source entries with decor items

    Shared framework lives in TabBaseMixin (TabBase.lua).
    This file provides config and the per-tab SetupSourceRow override.
]]

local _, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS

local SOURCE_ROW_BASE_HEIGHT = 32
local DECOR_ROW_HEIGHT = 24

addon.DropsTab = {}
local DropsTab = addon.DropsTab

Mixin(DropsTab, addon.TabBaseMixin)
DropsTab.tabName = "DropsTab"

DropsTab.cfg = {
    dbKey                 = "drops",
    indexBuiltFlag        = "dropIndexBuilt",
    buildIndexFn          = "BuildDropIndex",
    countDebugLabel       = "DropsTab",
    tabDebugLabel         = "DropsTab created",
    searchPlaceholderKey  = "DROPS_SEARCH_PLACEHOLDER",
    filterPrefix          = "DROPS",

    getSortedCategories   = function() return addon:GetSortedDropCategories() end,
    getSourcesForCategory = function(cat) return addon:GetDropsForCategory(cat) end,
    getCategoryInfo       = function(cat) return addon:GetSourceCategoryInfo(cat) end,
    getCategoryProgress   = function(cat) return addon:GetDropCategoryCollectionProgress(cat) end,
    getSourceCount        = function() return addon:GetDropCount() end,
    getSourceProgress     = function(source) return addon:GetDropSourceCollectionProgress(source) end,

    emptyNoSourcesKey     = "DROPS_EMPTY_NO_SOURCES",
    emptyNoSourcesDescKey = "DROPS_EMPTY_NO_SOURCES_DESC",
    emptySelectCategoryKey= "DROPS_SELECT_CATEGORY",
    emptyNoResultsKey     = "DROPS_EMPTY_NO_RESULTS",
}

-- Instance state (must be per-tab, not on mixin)
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
-- SetupSourceRow (per-tab override — simple drop source display)
--------------------------------------------------------------------------------

local function CopySourceDataWithDecorIds(sourceData, decorIds)
    local copy = {}
    for key, value in pairs(sourceData) do
        copy[key] = value
    end
    copy.decorIds = decorIds
    return copy
end

local function SourceHeaderMatchesSearch(sourceData, searchText, category)
    if searchText == "" then return true end

    if sourceData.sourceName and strlower(sourceData.sourceName):find(searchText, 1, true) then
        return true
    end

    local localizedName = addon:GetLocalizedSourceName(sourceData.sourceName)
    if localizedName and localizedName ~= sourceData.sourceName and strlower(localizedName):find(searchText, 1, true) then
        return true
    end

    local catInfo = DropsTab.cfg.getCategoryInfo(category)
    if catInfo then
        local catLabel = strlower(addon.L[catInfo.labelKey] or "")
        if catLabel:find(searchText, 1, true) then return true end
    end

    return false
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
    frame.sourceTooltipHint = displayName
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

    local isSourceSelected = self.selectedSourceName == elementData.sourceName
    self:UpdateSourceSelectionVisual(frame, isSourceSelected)
end

function DropsTab:GetVisibleSourceElement(sourceData, category, filter, searchText, visCache)
    if visCache then
        return visCache[category .. "\0" .. sourceData.sourceName]
    end

    local visibleSourceData = self:GetVisibleSourceData(sourceData)
    if not visibleSourceData then return nil end

    local sourceForFilter = visibleSourceData
    if searchText ~= "" and not SourceHeaderMatchesSearch(visibleSourceData, searchText, category) then
        local matchingDecorIds = {}
        for _, decorId in ipairs(visibleSourceData.decorIds or {}) do
            local name = addon:ResolveDecorName(decorId, addon:GetRecord(decorId))
            if name and strlower(name):find(searchText, 1, true) then
                matchingDecorIds[#matchingDecorIds + 1] = decorId
            end
        end

        if #matchingDecorIds == 0 then return nil end
        sourceForFilter = CopySourceDataWithDecorIds(visibleSourceData, matchingDecorIds)
    end

    if self:SourcePassesCompletionFilter(sourceForFilter, filter) then
        return sourceForFilter
    end
    return nil
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
