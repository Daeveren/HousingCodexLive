--[[
    Housing Codex - PvPTab.lua
    PvP sources tab aggregating achievements, vendors, and drops.
    Left panel: source categories (Achievements, Vendors, Drops)
    Right panel: source entries with decor items

    Shared framework lives in TabBaseMixin (TabBase.lua).
    This file provides config and per-tab overrides for source row display,
    search matching (vendor NPC names, zones), and progress calculation.
]]

local _, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS

local SOURCE_ROW_BASE_HEIGHT = 32
local DECOR_ROW_HEIGHT = 24

addon.PvPTab = {}
local PvPTab = addon.PvPTab

Mixin(PvPTab, addon.TabBaseMixin)
PvPTab.tabName = "PvPTab"

PvPTab.cfg = {
    dbKey                 = "pvp",
    indexBuiltFlag        = "pvpIndexBuilt",
    buildIndexFn          = "BuildPvPIndex",
    countDebugLabel       = "PvPTab",
    tabDebugLabel         = "PvPTab created",
    searchPlaceholderKey  = "PVP_SEARCH_PLACEHOLDER",
    filterPrefix          = "PVP",

    getSortedCategories   = function() return addon:GetSortedPvPCategories() end,
    getSourcesForCategory = function(cat) return addon:GetPvPSourcesForCategory(cat) end,
    getCategoryInfo       = function(cat) return addon:GetPvPSourceCategoryInfo(cat) end,
    getCategoryProgress   = function(cat) return addon:GetPvPCategoryCollectionProgress(cat) end,
    getSourceCount        = function() return addon:GetPvPSourceCount() end,
    -- No getSourceProgress — PvP counts manually in SourcePassesCompletionFilter override

    emptyNoSourcesKey     = "PVP_EMPTY_NO_SOURCES",
    emptyNoSourcesDescKey = "PVP_EMPTY_NO_SOURCES_DESC",
    emptySelectCategoryKey= "PVP_SELECT_CATEGORY",
    emptyNoResultsKey     = "PVP_EMPTY_NO_RESULTS",
}

-- Instance state (must be per-tab, not on mixin)
PvPTab.frame = nil
PvPTab.toolbar = nil
PvPTab.categoryPanel = nil
PvPTab.categoryScrollBox = nil
PvPTab.sourcePanel = nil
PvPTab.sourceScrollBox = nil
PvPTab.sourceScrollBar = nil
PvPTab.searchBox = nil
PvPTab.filterButtons = {}
PvPTab.emptyState = nil
PvPTab.noCategoryState = nil
PvPTab.noResultsState = nil

PvPTab.selectedCategory = nil
PvPTab.selectedSourceName = nil
PvPTab.selectedDecorId = nil
PvPTab.toolbarLayout = nil
PvPTab.filterContainer = nil

--------------------------------------------------------------------------------
-- SetupSourceRow (per-tab override — complex PvP source display)
-- Handles vendor NPC names, zone suffixes, achievement completion checkmarks,
-- and manual progress counting.
--------------------------------------------------------------------------------

function PvPTab:SetupSourceRow(frame, elementData)
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

    local displayName
    if elementData.sourceCategory == "vendors" and elementData.npcId then
        displayName = addon:GetLocalizedNPCName(elementData.npcId, elementData.sourceName) or L["UNKNOWN"]
    else
        displayName = addon:GetLocalizedSourceName(elementData.sourceName) or L["UNKNOWN"]
    end

    if elementData.sourceCategory == "achievements" and elementData.achievementID then
        local isCompleted = addon:IsAchievementCompleted(elementData.achievementID)
        if isCompleted then
            displayName = displayName .. "  |cFF66EE66[X]|r"
        end
    elseif elementData.sourceCategory == "vendors" and elementData.zoneName then
        displayName = displayName .. "  |cFF888888(" .. addon:GetLocalizedVendorZoneName(elementData.zoneName) .. ")|r"
    end

    frame.sourceName:SetText(displayName)
    frame.sourceName:SetTextColor(unpack(COLORS.SOURCE_NAME_GOLD))
    addon:SetFontSize(frame.sourceName, 14, "")

    -- Progress (manual counting — no dedicated PvP progress helper)
    local owned = 0
    for _, decorId in ipairs(decorIds) do
        if addon:IsDecorCollected(decorId) then owned = owned + 1 end
    end
    frame.sourceProgress:SetText(string.format("%d/%d", owned, decorCount))
    local progressComplete = owned == decorCount and decorCount > 0
    frame.sourceProgress:SetTextColor(unpack(progressComplete and COLORS.PROGRESS_COMPLETE or COLORS.TEXT_TERTIARY))
    addon:SetFontSize(frame.sourceProgress, 11, "")

    self:SetupDecorRows(frame, decorIds)

    local isSourceSelected = self.selectedSourceName == elementData.sourceName
    self:UpdateSourceSelectionVisual(frame, isSourceSelected)
end

--------------------------------------------------------------------------------
-- SourceMatchesSearch (per-tab override — adds vendor NPC name + zone matching)
--------------------------------------------------------------------------------

function PvPTab:SourceMatchesSearch(sourceData, searchText, category)
    if searchText == "" then return true end

    if sourceData.sourceName and strlower(sourceData.sourceName):find(searchText, 1, true) then
        return true
    end

    -- Vendor NPC name vs generic localized name
    local localizedName
    if sourceData.sourceCategory == "vendors" and sourceData.npcId then
        localizedName = addon:GetLocalizedNPCName(sourceData.npcId, sourceData.sourceName)
    else
        localizedName = addon:GetLocalizedSourceName(sourceData.sourceName)
    end
    if localizedName and localizedName ~= sourceData.sourceName and strlower(localizedName):find(searchText, 1, true) then
        return true
    end

    -- Zone name for vendors (raw + localized)
    if sourceData.zoneName then
        if strlower(sourceData.zoneName):find(searchText, 1, true) then
            return true
        end
        local localizedZone = addon:GetLocalizedVendorZoneName(sourceData.zoneName)
        if localizedZone ~= sourceData.zoneName and strlower(localizedZone):find(searchText, 1, true) then
            return true
        end
    end

    -- Category label
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

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

PvPTab:RegisterTabVisibility("PVP")

addon:RegisterInternalEvent("DATA_LOADED", function()
    if PvPTab:IsShown() and not addon.pvpIndexBuilt then
        addon:BuildPvPIndex()
        PvPTab:RefreshDisplay()
    end
end)

PvPTab:RegisterOwnershipRefresh(function() PvPTab:RefreshDisplay() end)

addon:RegisterInternalEvent("ACHIEVEMENT_COMPLETION_CHANGED", function()
    if PvPTab:IsShown() then
        PvPTab:RefreshDisplay()
    end
end)

addon.MainFrame:RegisterContentAreaInitializer("PvPTab", function(contentArea)
    PvPTab:Create(contentArea)
end)
