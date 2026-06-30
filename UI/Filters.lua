--[[
    Housing Codex - Filters.lua
    Collection state filtering using HousingCatalogSearcher
]]

local _, addon = ...

addon.Filters = {}
local Filters = addon.Filters

-- Filter states (can be combined: both, one, or none)
Filters.showCollected = true
Filters.showUncollected = true
Filters.trackableState = "all"   -- "all", "trackable", "not_trackable"
Filters.showWishlistOnly = false
Filters.showPlacedOnly = false
Filters.showPromoOnly = false
Filters.hideShopItems = false
Filters.currencyFilter = {}
Filters.addedPatchFilter = {}
Filters.initialized = false
Filters.decorCurrencyKeys = nil
Filters.currencyFilterKeys = nil
Filters.currencyFilterKeySet = nil
Filters.currencyLookupBuilt = false

local FILTER_CURRENCY_GOLD_KEY = addon.CONSTANTS.VENDOR_CURRENCY_GOLD_KEY
local FILTER_NO_ADDED_PATCH_KEY = "__no_patch_data"

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
    filters.collectionState = nil
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
        self.showPromoOnly = filters.showPromoOnly or false
        self.hideShopItems = filters.hideShopItems or false
        self.currencyFilter = type(filters.currencyFilter) == "table" and filters.currencyFilter or {}
        filters.addedPatchFilter = nil
        self.addedPatchFilter = {}
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
    addon:RequestSearch()
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

--------------------------------------------------------------------------------
-- Promo Filter
--------------------------------------------------------------------------------

function Filters:SetPromoOnly(enabled)
    self.showPromoOnly = enabled

    if addon.db and addon.db.browser then
        addon.db.browser.filters = addon.db.browser.filters or {}
        addon.db.browser.filters.showPromoOnly = enabled
    end

    addon:FireEvent("FILTER_CHANGED")

    addon:Debug("Promo-only filter set to: " .. tostring(enabled))
end

function Filters:PassesPromoFilter(record)
    if not self.showPromoOnly then return true end
    return record ~= nil and addon:IsPromoDecor(record.recordID)
end

--------------------------------------------------------------------------------
-- Global Visibility Filters
--------------------------------------------------------------------------------

function Filters:SetHideShopItems(enabled)
    local value = enabled == true
    if self.hideShopItems == value then return end

    self.hideShopItems = value

    if addon.db and addon.db.browser then
        addon.db.browser.filters = addon.db.browser.filters or {}
        addon.db.browser.filters.hideShopItems = value
    end

    addon:NotifyDecorVisibilityChanged(nil, "hide-shop-items")
    addon:Debug("Hide shop items filter set to: " .. tostring(value))
end

--------------------------------------------------------------------------------
-- Vendor Currency Filter
--------------------------------------------------------------------------------

function Filters:GetCurrencyLabel(currencyKey)
    if currencyKey == FILTER_CURRENCY_GOLD_KEY then
        return addon.L["CURRENCY_GOLD"]
    end
    return addon:GetLocalizedCurrencyName(currencyKey)
end

function Filters:GetCurrencyFilter()
    if type(self.currencyFilter) ~= "table" then
        self.currencyFilter = {}
    end

    if addon.db and addon.db.browser then
        addon.db.browser.filters = addon.db.browser.filters or {}
        if type(addon.db.browser.filters.currencyFilter) ~= "table" then
            addon.db.browser.filters.currencyFilter = self.currencyFilter
        end
    end

    return self.currencyFilter
end

function Filters:GetActiveCurrencyFilterCount(skipEnsure)
    if not skipEnsure then
        self:EnsureCurrencyLookup()
    end

    local filters = self:GetCurrencyFilter()
    local count = 0
    for _, selected in pairs(filters) do
        if selected then
            count = count + 1
        end
    end
    return count
end

function Filters:HasActiveCurrencyFilter(skipEnsure)
    return self:GetActiveCurrencyFilterCount(skipEnsure) > 0
end

function Filters:IsCurrencyFilterSelected(currencyKey)
    local filters = self:GetCurrencyFilter()
    return currencyKey ~= nil and filters[currencyKey] == true
end

function Filters:SetCurrencyFilterEnabled(currencyKey, enabled, skipApply)
    if not currencyKey then return end

    local filters = self:GetCurrencyFilter()
    if enabled then
        filters[currencyKey] = true
    else
        filters[currencyKey] = nil
    end

    if addon.db and addon.db.browser and addon.db.browser.filters then
        addon.db.browser.filters.currencyFilter = filters
    end

    if not skipApply then
        addon:FireEvent("FILTER_CHANGED")
    end
end

function Filters:ClearCurrencyFilter(skipApply)
    wipe(self:GetCurrencyFilter())
    if not skipApply then
        addon:FireEvent("FILTER_CHANGED")
    end
end

function Filters:PruneUnknownCurrencyFilters()
    local validKeys = self.currencyFilterKeySet
    if not self.currencyLookupBuilt or not validKeys then return false end

    local filters = self:GetCurrencyFilter()
    local changed = false
    for currencyKey in pairs(filters) do
        if not validKeys[currencyKey] then
            filters[currencyKey] = nil
            changed = true
        end
    end

    if changed and addon.db and addon.db.browser and addon.db.browser.filters then
        addon.db.browser.filters.currencyFilter = filters
    end
    return changed
end

function Filters:EnsureCurrencyLookup()
    if self.currencyLookupBuilt then return true end

    if not addon.vendorIndexBuilt and addon.BuildVendorIndex then
        addon:BuildVendorIndex()
    end
    if not addon.vendorIndexBuilt then
        return false
    end

    local byDecorID = {}
    local seenCurrencies = {}
    local currencyKeys = {}

    for _, expansionData in pairs(addon.vendorHierarchy or {}) do
        for _, vendors in pairs(expansionData.zones or {}) do
            for _, vendorData in ipairs(vendors) do
                local currencyKey = addon:GetVendorCurrencyKey(vendorData)
                if not seenCurrencies[currencyKey] then
                    seenCurrencies[currencyKey] = true
                    table.insert(currencyKeys, currencyKey)
                end

                for _, decorId in ipairs(vendorData.decorIds or {}) do
                    byDecorID[decorId] = byDecorID[decorId] or {}
                    byDecorID[decorId][currencyKey] = true
                end
            end
        end
    end

    table.sort(currencyKeys, function(a, b)
        return strlower(a) < strlower(b)
    end)

    local currencyKeySet = {}
    for _, currencyKey in ipairs(currencyKeys) do
        currencyKeySet[currencyKey] = true
    end

    self.currencyFilterKeys = currencyKeys
    self.currencyFilterKeySet = currencyKeySet
    self.decorCurrencyKeys = byDecorID
    self.currencyLookupBuilt = true
    self:PruneUnknownCurrencyFilters()
    return true
end

function Filters:GetCurrencyFilterOptions()
    if not self:EnsureCurrencyLookup() then
        return {}
    end

    local options = {}
    for _, currencyKey in ipairs(self.currencyFilterKeys or {}) do
        table.insert(options, {
            key = currencyKey,
            label = self:GetCurrencyLabel(currencyKey),
        })
    end

    table.sort(options, function(a, b)
        return strlower(a.label) < strlower(b.label)
    end)
    return options
end

function Filters:PassesCurrencyFilter(record)
    if not self:EnsureCurrencyLookup() then return true end
    if not self:HasActiveCurrencyFilter(true) then return true end
    if not record or not record.recordID then return false end

    local currencies = self.decorCurrencyKeys and self.decorCurrencyKeys[record.recordID]
    if not currencies then return false end

    local selected = self:GetCurrencyFilter()
    for currencyKey in pairs(currencies) do
        if selected[currencyKey] == true then
            return true
        end
    end
    return false
end


--------------------------------------------------------------------------------
-- Added Patch Filter
--------------------------------------------------------------------------------

function Filters:GetAddedPatchFilter()
    if type(self.addedPatchFilter) ~= "table" then
        self.addedPatchFilter = {}
    end
    return self.addedPatchFilter
end

function Filters:GetAddedPatchFilterOptions()
    local options = {}
    for _, patch in ipairs(addon.DecorAddedPatchVersions or {}) do
        table.insert(options, patch)
    end
    return options
end

function Filters:HasActiveAddedPatchFilter()
    for _, selected in pairs(self:GetAddedPatchFilter()) do
        if selected == false then
            return true
        end
    end
    return false
end

function Filters:IsAddedPatchSelected(patch)
    if not patch then return false end
    return self:GetAddedPatchFilter()[patch] ~= false
end

function Filters:HasSelectedAddedPatch()
    for _, patch in ipairs(addon.DecorAddedPatchVersions or {}) do
        if self:IsAddedPatchSelected(patch) then
            return true
        end
    end
    return false
end

function Filters:IsNoAddedPatchSelected()
    return self:IsAddedPatchSelected(FILTER_NO_ADDED_PATCH_KEY)
end

function Filters:SetAddedPatchEnabled(patch, enabled, skipApply)
    if not patch then return end

    local filters = self:GetAddedPatchFilter()
    if enabled then
        filters[patch] = nil
    else
        filters[patch] = false
    end

    if not skipApply then
        addon:FireEvent("FILTER_CHANGED")
    end
end

function Filters:SetAllAddedPatchesEnabled(enabled, skipApply)
    local filters = self:GetAddedPatchFilter()
    wipe(filters)
    if not enabled then
        for _, patch in ipairs(addon.DecorAddedPatchVersions or {}) do
            filters[patch] = false
        end
    end

    if not skipApply then
        addon:FireEvent("FILTER_CHANGED")
    end
end

function Filters:PassesAddedPatchFilter(record)
    if not self:HasActiveAddedPatchFilter() then return true end
    if not record then return false end
    if not record.addedPatch or record.addedPatch == "" then
        return self:IsNoAddedPatchSelected()
    end
    return self:IsAddedPatchSelected(record.addedPatch) == true
end

-- Returns true if id exists in a numerically-indexed list
local function ContainsID(list, id)
    for _, v in ipairs(list) do
        if v == id then return true end
    end
    return false
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

    local searcher = addon.catalogSearcher
    if searcher then
        -- Category/subcategory filter: read from the searcher (authoritative state).
        -- UI state (focusedCategoryID/selectedCategoryID) can diverge — the direct-
        -- selection path writes the searcher directly without populating focusedCategoryID.
        local filteredCat = searcher.GetFilteredCategoryID and searcher:GetFilteredCategoryID()
        if filteredCat and record.categoryIDs and not ContainsID(record.categoryIDs, filteredCat) then
            return false
        end
        local filteredSub = searcher.GetFilteredSubcategoryID and searcher:GetFilteredSubcategoryID()
        if filteredSub and record.subcategoryIDs and not ContainsID(record.subcategoryIDs, filteredSub) then
            return false
        end

        -- Indoor/outdoor and dyeable filters (from searcher state)
        local isIndoorOnly = record.isIndoors and not record.isOutdoors
        local isOutdoorOnly = record.isOutdoors and not record.isIndoors
        if not searcher:IsAllowedIndoorsActive() and isIndoorOnly then return false end
        if not searcher:IsAllowedOutdoorsActive() and isOutdoorOnly then return false end
        if searcher:IsCustomizableOnlyActive() and not record.canCustomize then return false end
    end

    return true
end

-- Check if advanced filters are at default (for client-side search safety)
function Filters:AreAdvancedFiltersAtDefault(ignoreAddedPatchFilter)
    local searcher = addon.catalogSearcher
    if not searcher then return true end

    -- First Acquisition must be disabled (default is false)
    if searcher:IsFirstAcquisitionBonusOnlyActive() then return false end
    if not ignoreAddedPatchFilter and self:HasActiveAddedPatchFilter() then return false end

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
    if not addon.db or not addon.db.browser or not addon.db.browser.filters then return end

    local db = addon.db.browser.filters
    db.showCollected = self.showCollected
    db.showUncollected = self.showUncollected
    db.trackableState = self.trackableState
    db.showWishlistOnly = self.showWishlistOnly
    db.showPlacedOnly = self.showPlacedOnly
    db.showPromoOnly = self.showPromoOnly
    db.hideShopItems = self.hideShopItems
    db.currencyFilter = self:GetCurrencyFilter()

    -- Save searcher-based filters
    local searcher = addon.catalogSearcher
    if searcher then
        db.indoors = searcher:IsAllowedIndoorsActive()
        db.outdoors = searcher:IsAllowedOutdoorsActive()
        db.dyeable = searcher:IsCustomizableOnlyActive()
        db.firstAcquisition = searcher:IsFirstAcquisitionBonusOnlyActive()

        -- Save tag filter states (sparse: only disabled tags, default is enabled)
        if addon.FilterBar and addon.FilterBar.tagGroups then
            db.tagFilters = {}
            for _, group in ipairs(addon.FilterBar.tagGroups) do
                for _, tag in pairs(group.tags) do
                    local state = searcher:GetFilterTagStatus(group.groupID, tag.tagID)
                    if state == false then
                        db.tagFilters[group.groupID] = db.tagFilters[group.groupID] or {}
                        db.tagFilters[group.groupID][tag.tagID] = false
                    end
                end
            end
        end
    end

    addon:Debug("Filter state saved")
end

-- Restore filter state from SavedVariables (called after searcher ready)
function Filters:RestoreState()
    if not addon.db or not addon.db.browser or not addon.db.browser.filters then return end

    local db = addon.db.browser.filters
    local searcher = addon.catalogSearcher
    local restoredHideShopItems = db.hideShopItems == true

    -- Ensure FilterBar is initialized before tag restore (Filters loads before FilterBar in TOC)
    if addon.FilterBar then
        addon.FilterBar:Initialize()
    end

    addon:WithSearcherBatchUpdate("RestoreState", function()
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

        -- Restore promo-only filter
        self.showPromoOnly = db.showPromoOnly or false

        -- Restore global shop visibility filter
        self.hideShopItems = restoredHideShopItems

        -- Restore vendor currency filter
        self.currencyFilter = type(db.currencyFilter) == "table" and db.currencyFilter or {}
        db.addedPatchFilter = nil
        self.addedPatchFilter = {}

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
        end
    end)

    -- Earlier DATA_LOADED listeners (for example LDB) can compute visible-count
    -- caches before Filters restores this global filter. Refresh once after
    -- restore so persisted Hide Shop Items is reflected immediately on login.
    if restoredHideShopItems then
        addon:NotifyDecorVisibilityChanged(nil, "restore-hide-shop-items")
    end

    addon:Debug("Filter state restored")
end

--------------------------------------------------------------------------------
-- Common Operations
--------------------------------------------------------------------------------

-- Reset all filters to defaults
function Filters:ResetAllFilters(options)
    options = options or {}
    addon:WithSearcherBatchUpdate("ResetAllFilters", function()
        -- Clear search box
        if addon.SearchBox then
            addon.SearchBox:Clear()
            if addon.catalogSearcher then
                addon.catalogSearcher:SetSearchText(nil)
            end
        end

        -- Reset collection filters (default: show both collected and uncollected)
        self:SetCollectionDirect(true, true)

        -- Reset trackable state
        self:SetTrackableState("all")

        -- Reset wishlist-only filter
        self:SetWishlistOnly(false)

        -- Reset placed-only filter
        self:SetPlacedOnly(false)

        -- Reset promo-only filter
        self:SetPromoOnly(false)

        -- Explicit reset clears global visibility filters; programmatic tab
        -- navigation can preserve them with preserveGlobalVisibility.
        if not options.preserveGlobalVisibility then
            self:SetHideShopItems(false)
        end

        -- Reset vendor currency filter
        self:ClearCurrencyFilter(true)

        -- Reset added patch filter
        self:SetAllAddedPatchesEnabled(true, true)

        -- Reset category/subcategory filters
        if addon.Categories then
            addon.Categories:ClearFocusOnly()
        end
        if addon.catalogSearcher then
            addon.catalogSearcher:SetFilteredCategoryID(nil)
            addon.catalogSearcher:SetFilteredSubcategoryID(nil)
        end

        -- Reset FilterBar (special filters + tags)
        if addon.FilterBar then
            addon.FilterBar:ResetToDefault(options)
        elseif addon.catalogSearcher then
            -- Manual reset if FilterBar not available
            addon.catalogSearcher:SetCustomizableOnly(false)
            addon.catalogSearcher:SetAllowedIndoors(true)
            addon.catalogSearcher:SetAllowedOutdoors(true)
        end
    end)

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
