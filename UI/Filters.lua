--[[
    Housing Codex - Filters.lua
    Collection state filtering using HousingCatalogSearcher
]]

local ADDON_NAME, addon = ...

addon.Filters = {}
local Filters = addon.Filters

-- Filter states (can be combined: both, one, or none)
Filters.showCollected = false
Filters.showUncollected = true
Filters.trackableState = "all"   -- "all", "trackable", "not_trackable"
Filters.showWishlistOnly = false
Filters.showPlacedOnly = false
Filters.initialized = false

-- Valid states for trackable filter
local TRACKABLE_STATES = { all = true, trackable = true, not_trackable = true }

-- Migrate old collectionState format to new showCollected/showUncollected booleans
local function MigrateCollectionState(filters)
    if filters.showCollected == nil and filters.collectionState then
        filters.showCollected = filters.collectionState ~= "uncollected"
    end
    if filters.showUncollected == nil and filters.collectionState then
        filters.showUncollected = filters.collectionState ~= "collected"
    end
end

function Filters:Initialize()
    if self.initialized then return end

    local filters = addon.db and addon.db.browser and addon.db.browser.filters
    if filters then
        MigrateCollectionState(filters)
        -- Load saved state (both can be true/false independently)
        if filters.showCollected ~= nil then
            self.showCollected = filters.showCollected
        end
        if filters.showUncollected ~= nil then
            self.showUncollected = filters.showUncollected
        end
        self.trackableState = filters.trackableState or "all"
        self.showWishlistOnly = filters.showWishlistOnly or false
        self.showPlacedOnly = filters.showPlacedOnly or false
    end

    self.initialized = true
    addon:Debug("Filters initialized, collected: " .. tostring(self.showCollected) .. ", uncollected: " .. tostring(self.showUncollected) .. ", trackable: " .. self.trackableState .. ", wishlist: " .. tostring(self.showWishlistOnly))
end

--------------------------------------------------------------------------------
-- Collection Filter
--------------------------------------------------------------------------------

-- Helper to set a collection filter flag and persist it (does NOT apply)
local function SetCollectionFlag(filterKey, value)
    Filters[filterKey] = value

    if addon.db and addon.db.browser then
        addon.db.browser.filters = addon.db.browser.filters or {}
        addon.db.browser.filters[filterKey] = value
    end

    addon:Debug(filterKey .. " set to: " .. tostring(value))
end

function Filters:SetShowCollected(show)
    SetCollectionFlag("showCollected", show)
    self:ApplyCollectionFilter()
end

function Filters:SetShowUncollected(show)
    SetCollectionFlag("showUncollected", show)
    self:ApplyCollectionFilter()
end

-- Set collection filters without triggering a search (for batched operations)
function Filters:SetCollectionDirect(showCollected, showUncollected)
    SetCollectionFlag("showCollected", showCollected)
    SetCollectionFlag("showUncollected", showUncollected)

    -- Update searcher state without running search
    if addon.catalogSearcher then
        addon.catalogSearcher:SetCollected(showCollected)
        addon.catalogSearcher:SetUncollected(showUncollected)
    end
end

function Filters:ApplyCollectionFilter()
    if not addon.catalogSearcher then
        addon:Debug("Filters: Searcher not available")
        return
    end

    addon.catalogSearcher:SetCollected(self.showCollected)
    addon.catalogSearcher:SetUncollected(self.showUncollected)
    addon.catalogSearcher:RunSearch()
end

--------------------------------------------------------------------------------
-- Trackable Filter
--------------------------------------------------------------------------------

function Filters:SetTrackableState(state)
    if not TRACKABLE_STATES[state] then
        addon:Debug("Invalid trackable state: " .. tostring(state))
        return
    end

    self.trackableState = state

    -- Save to SavedVariables
    if addon.db and addon.db.browser then
        addon.db.browser.filters = addon.db.browser.filters or {}
        addon.db.browser.filters.trackableState = state
    end

    -- Fire event to trigger grid re-filter (post-search filter)
    addon:FireEvent("FILTER_CHANGED")

    addon:Debug("Trackable state set to: " .. state)
end

function Filters:PassesTrackableFilter(record)
    local state = self.trackableState
    if state == "all" then return true end
    if state == "trackable" then return record.isTrackable == true end
    return not record.isTrackable  -- "not_trackable": matches false or nil
end

--------------------------------------------------------------------------------
-- Wishlist Filter
--------------------------------------------------------------------------------

function Filters:SetWishlistOnly(enabled)
    self.showWishlistOnly = enabled

    -- Save to SavedVariables
    if addon.db and addon.db.browser then
        addon.db.browser.filters = addon.db.browser.filters or {}
        addon.db.browser.filters.showWishlistOnly = enabled
    end

    -- Fire event to trigger grid re-filter (post-search filter)
    addon:FireEvent("FILTER_CHANGED")

    addon:Debug("Wishlist-only filter set to: " .. tostring(enabled))
end

function Filters:PassesWishlistFilter(record)
    if not self.showWishlistOnly then return true end
    return addon:IsWishlisted(record.recordID)
end

--------------------------------------------------------------------------------
-- Placed Filter
--------------------------------------------------------------------------------

function Filters:SetPlacedOnly(enabled)
    self.showPlacedOnly = enabled

    -- Save to SavedVariables
    if addon.db and addon.db.browser then
        addon.db.browser.filters = addon.db.browser.filters or {}
        addon.db.browser.filters.showPlacedOnly = enabled
    end

    -- Fire event to trigger grid re-filter (post-search filter)
    addon:FireEvent("FILTER_CHANGED")

    addon:Debug("Placed-only filter set to: " .. tostring(enabled))
end

function Filters:PassesPlacedFilter(record)
    if not self.showPlacedOnly then return true end
    return record.numPlaced and record.numPlaced > 0
end

-- Filter a list of record IDs to only include those passing searcher-level filters
-- Used to filter client-side text search results that bypass the native searcher
function Filters:FilterBySearcherRules(recordIDs)
    local filtered = {}
    for _, id in ipairs(recordIDs) do
        local record = addon:GetRecord(id)
        if record and self:PassesSearcherFilters(record) then
            table.insert(filtered, id)
        end
    end
    return filtered
end

-- Check if a record passes the current searcher-level filters
function Filters:PassesSearcherFilters(record)
    if not record then return false end

    -- Collection filter: record must match at least one enabled state
    -- (both enabled = show all, neither enabled = show nothing)
    local matchesCollection = (self.showCollected and record.isCollected)
                           or (self.showUncollected and not record.isCollected)
    if not matchesCollection then return false end

    -- Indoor/outdoor and dyeable filters (from searcher state)
    local searcher = addon.catalogSearcher
    if searcher then
        local isIndoorOnly = record.isIndoors and not record.isOutdoors
        local isOutdoorOnly = record.isOutdoors and not record.isIndoors
        if not searcher:IsAllowedIndoorsActive() and isIndoorOnly then return false end
        if not searcher:IsAllowedOutdoorsActive() and isOutdoorOnly then return false end
        if searcher:IsCustomizableOnlyActive() and not record.canCustomize then return false end
    end

    return true
end

-- Check if advanced filters are at default (for client-side search safety)
function Filters:AreAdvancedFiltersAtDefault()
    local searcher = addon.catalogSearcher
    if not searcher then return true end

    -- First Acquisition must be disabled (default is false)
    if searcher:IsFirstAcquisitionBonusOnlyActive() then return false end

    -- All tag filters must be enabled (default is true)
    if addon.FilterBar and addon.FilterBar.tagGroups then
        for _, group in ipairs(addon.FilterBar.tagGroups) do
            for _, tag in pairs(group.tags) do
                if not searcher:GetFilterTagStatus(group.groupID, tag.tagID) then
                    return false
                end
            end
        end
    end

    return true
end

--------------------------------------------------------------------------------
-- Filter State Persistence
--------------------------------------------------------------------------------

-- Save complete filter state to SavedVariables
function Filters:SaveState()
    if not addon.db or not addon.db.browser then return end

    local db = addon.db.browser.filters
    db.showCollected = self.showCollected
    db.showUncollected = self.showUncollected
    db.trackableState = self.trackableState
    db.showWishlistOnly = self.showWishlistOnly
    db.showPlacedOnly = self.showPlacedOnly

    -- Save searcher-based filters
    local searcher = addon.catalogSearcher
    if searcher then
        db.indoors = searcher:IsAllowedIndoorsActive()
        db.outdoors = searcher:IsAllowedOutdoorsActive()
        db.dyeable = searcher:IsCustomizableOnlyActive()
        db.firstAcquisition = searcher:IsFirstAcquisitionBonusOnlyActive()

        -- Save tag filter states
        if addon.FilterBar and addon.FilterBar.tagGroups then
            db.tagFilters = {}
            for _, group in ipairs(addon.FilterBar.tagGroups) do
                db.tagFilters[group.groupID] = {}
                for _, tag in pairs(group.tags) do
                    db.tagFilters[group.groupID][tag.tagID] = searcher:GetFilterTagStatus(group.groupID, tag.tagID)
                end
            end
        end
    end

    addon:Debug("Filter state saved")
end

-- Restore filter state from SavedVariables (called after searcher ready)
function Filters:RestoreState()
    if not addon.db or not addon.db.browser then return end

    local db = addon.db.browser.filters
    local searcher = addon.catalogSearcher

    -- Disable auto-update while restoring to batch changes
    if searcher then
        searcher:SetAutoUpdateOnParamChanges(false)
    end

    -- Restore collection filters (can be combined)
    MigrateCollectionState(db)
    if db.showCollected ~= nil then
        self.showCollected = db.showCollected
    end
    if db.showUncollected ~= nil then
        self.showUncollected = db.showUncollected
    end

    -- Apply collection filter to searcher
    if searcher then
        searcher:SetCollected(self.showCollected)
        searcher:SetUncollected(self.showUncollected)
    end

    -- Restore trackable state
    self:SetTrackableState(db.trackableState or "all")

    -- Restore wishlist-only filter
    self.showWishlistOnly = db.showWishlistOnly or false

    -- Restore placed-only filter
    self.showPlacedOnly = db.showPlacedOnly or false

    -- Restore searcher-based filters
    if searcher then
        -- Restore sort type (only native sorts go to catalogSearcher)
        local sortType = addon.db.browser.sortType or 0
        if sortType < 100 then
            searcher:SetSortType(sortType)
        end

        searcher:SetAllowedIndoors(db.indoors ~= false)
        searcher:SetAllowedOutdoors(db.outdoors ~= false)
        searcher:SetCustomizableOnly(db.dyeable or false)
        searcher:SetFirstAcquisitionBonusOnly(db.firstAcquisition or false)

        -- Restore tag filters
        if db.tagFilters and addon.FilterBar and addon.FilterBar.tagGroups then
            for _, group in ipairs(addon.FilterBar.tagGroups) do
                local savedGroup = db.tagFilters[group.groupID]
                if savedGroup then
                    for _, tag in pairs(group.tags) do
                        local savedState = savedGroup[tag.tagID]
                        -- Only set if we have a saved state; default is true (enabled)
                        if savedState ~= nil then
                            searcher:SetFilterTagStatus(group.groupID, tag.tagID, savedState)
                        end
                    end
                end
            end
        end

        -- Re-enable auto-update and run search once
        searcher:SetAutoUpdateOnParamChanges(true)
        searcher:RunSearch()
    end

    addon:Debug("Filter state restored")
end

--------------------------------------------------------------------------------
-- Common Operations
--------------------------------------------------------------------------------

-- Reset all filters to defaults
function Filters:ResetAllFilters()
    local searcher = addon.catalogSearcher

    -- Disable auto-update to batch all changes
    if searcher then
        searcher:SetAutoUpdateOnParamChanges(false)
    end

    -- Clear search box
    if addon.SearchBox then
        addon.SearchBox:Clear()
        if searcher then
            searcher:SetSearchText(nil)
        end
    end

    -- Reset collection filters (default: show uncollected only)
    self:SetCollectionDirect(false, true)

    -- Reset trackable state
    self:SetTrackableState("all")

    -- Reset wishlist-only filter
    self:SetWishlistOnly(false)

    -- Reset placed-only filter
    self:SetPlacedOnly(false)

    -- Reset FilterBar (special filters + tags)
    if addon.FilterBar then
        addon.FilterBar:ResetToDefault()
    elseif searcher then
        -- Manual reset if FilterBar not available
        searcher:SetCustomizableOnly(false)
        searcher:SetAllowedIndoors(true)
        searcher:SetAllowedOutdoors(true)
        searcher:SetAutoUpdateOnParamChanges(true)
        searcher:RunSearch()
    end

    -- Save the reset state
    self:SaveState()

    addon:Debug("All filters reset to defaults")
end

-- Apply saved filters after data loads
addon:RegisterInternalEvent("DATA_LOADED", function()
    Filters:Initialize()
    -- Restore full filter state (includes collection filter)
    Filters:RestoreState()
end)
