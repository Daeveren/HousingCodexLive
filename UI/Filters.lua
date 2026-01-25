--[[
    Housing Codex - Filters.lua
    Collection state filtering using HousingCatalogSearcher
]]

local ADDON_NAME, addon = ...

local L = addon.L
local COLORS = addon.CONSTANTS.COLORS

addon.Filters = {}
local Filters = addon.Filters

-- Filter states (mutually exclusive: only one can be active)
Filters.showCollected = false
Filters.showUncollected = true
Filters.trackableState = "all"   -- "all", "trackable", "not_trackable"
Filters.showWishlistOnly = false
Filters.initialized = false

-- Toggle button containers (created lazily)
Filters.collectionToggles = nil
Filters.toggleContainer = nil

-- Toggle button styling constants
local TOGGLE_MIN_WIDTH = 50
local TOGGLE_PADDING_H = 12  -- 6px each side
local TOGGLE_HEIGHT = 20
local TOGGLE_SPACING = 4

-- Toggle button colors (derived from DaevTools palette)
local COLOR_BTN_NORMAL = { 0.15, 0.15, 0.18, 0.9 }
local COLOR_BTN_HOVER = { 0.2, 0.2, 0.24, 1 }
local COLOR_BTN_ACTIVE = { 0.25, 0.22, 0.1, 1 }
local COLOR_TEXT_NORMAL = { 0.5, 0.5, 0.5, 1 }
local COLOR_TEXT_ACTIVE = COLORS.GOLD
local COLOR_BORDER_NORMAL = COLORS.BORDER
local COLOR_BORDER_ACTIVE = { 0.6, 0.5, 0.1, 1 }

-- Valid states for trackable filter
local TRACKABLE_STATES = { all = true, trackable = true, not_trackable = true }

local BUTTON_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

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
        -- Mutually exclusive: if collected is explicitly true, use that; otherwise default to uncollected
        if filters.showCollected then
            self.showCollected = true
            self.showUncollected = false
        else
            self.showCollected = false
            self.showUncollected = true
        end
        self.trackableState = filters.trackableState or "all"
        self.showWishlistOnly = filters.showWishlistOnly or false
    end

    self.initialized = true
    addon:Debug("Filters initialized, collected: " .. tostring(self.showCollected) .. ", uncollected: " .. tostring(self.showUncollected) .. ", trackable: " .. self.trackableState .. ", wishlist: " .. tostring(self.showWishlistOnly))
end

--------------------------------------------------------------------------------
-- Toggle Button Helper
--------------------------------------------------------------------------------

-- Creates a single toggle button
-- @param parent: Parent frame
-- @param label: Button text
-- @param isActive: Function returning current toggle state (boolean)
-- @param onToggle: Function called when button clicked
-- @return button: The button frame
local function CreateToggleButton(parent, label, isActive, onToggle)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetBackdrop(BUTTON_BACKDROP)

    -- Create text first to measure width
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetText(label)

    -- Calculate width from text, respecting minimum
    local textWidth = text:GetStringWidth()
    local btnWidth = math.max(TOGGLE_MIN_WIDTH, textWidth + TOGGLE_PADDING_H)
    btn:SetSize(btnWidth, TOGGLE_HEIGHT)

    text:SetPoint("CENTER")
    btn.text = text

    -- Update visuals based on active state
    local function UpdateVisuals()
        if isActive() then
            btn:SetBackdropColor(unpack(COLOR_BTN_ACTIVE))
            btn:SetBackdropBorderColor(unpack(COLOR_BORDER_ACTIVE))
            btn.text:SetTextColor(unpack(COLOR_TEXT_ACTIVE))
        else
            btn:SetBackdropColor(unpack(COLOR_BTN_NORMAL))
            btn:SetBackdropBorderColor(unpack(COLOR_BORDER_NORMAL))
            btn.text:SetTextColor(unpack(COLOR_TEXT_NORMAL))
        end
    end
    btn.UpdateVisuals = UpdateVisuals

    btn:SetScript("OnClick", function()
        onToggle()
        UpdateVisuals()
    end)

    btn:SetScript("OnEnter", function(self)
        if not isActive() then
            self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
        end
    end)

    btn:SetScript("OnLeave", function(self)
        UpdateVisuals()
    end)

    UpdateVisuals()
    return btn
end

--------------------------------------------------------------------------------
-- Collection Filter (Toggle Checkboxes)
--------------------------------------------------------------------------------

-- Helper to set a collection filter flag, persist it, and apply
local function SetCollectionFlag(filterKey, value)
    Filters[filterKey] = value

    if addon.db and addon.db.browser then
        addon.db.browser.filters = addon.db.browser.filters or {}
        addon.db.browser.filters[filterKey] = value
    end

    Filters:ApplyCollectionFilter()
    addon:Debug(filterKey .. " set to: " .. tostring(value))
end

function Filters:SetShowCollected(show)
    -- Enforce mutual exclusivity: if enabling collected, disable uncollected
    if show then
        Filters.showUncollected = false
        if addon.db and addon.db.browser and addon.db.browser.filters then
            addon.db.browser.filters.showUncollected = false
        end
    end
    SetCollectionFlag("showCollected", show)
end

function Filters:SetShowUncollected(show)
    -- Enforce mutual exclusivity: if enabling uncollected, disable collected
    if show then
        Filters.showCollected = false
        if addon.db and addon.db.browser and addon.db.browser.filters then
            addon.db.browser.filters.showCollected = false
        end
    end
    SetCollectionFlag("showUncollected", show)
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

function Filters:CreateCollectionButtons(parent)
    if self.collectionToggles then return self.toggleContainer end

    local container = CreateFrame("Frame", nil, parent)

    -- Collected toggle (mutually exclusive with uncollected)
    local collectedBtn = CreateToggleButton(
        container,
        L["FILTER_COLLECTED"] or "Collected",
        function() return self.showCollected end,
        function()
            if not self.showCollected then
                self:SetShowCollected(true)
                self:UpdateCollectionButtons()
            end
        end
    )
    collectedBtn:SetPoint("LEFT", container, "LEFT", 0, 0)

    -- Uncollected toggle (mutually exclusive with collected)
    local uncollectedBtn = CreateToggleButton(
        container,
        L["FILTER_UNCOLLECTED"] or "Uncollected",
        function() return self.showUncollected end,
        function()
            if not self.showUncollected then
                self:SetShowUncollected(true)
                self:UpdateCollectionButtons()
            end
        end
    )
    uncollectedBtn:SetPoint("LEFT", collectedBtn, "RIGHT", TOGGLE_SPACING, 0)

    -- Calculate container width dynamically from button sizes
    local totalWidth = collectedBtn:GetWidth() + TOGGLE_SPACING + uncollectedBtn:GetWidth()
    container:SetSize(totalWidth, TOGGLE_HEIGHT)

    self.toggleContainer = container
    self.collectionToggles = {
        collected = collectedBtn,
        uncollected = uncollectedBtn,
    }

    return container
end

function Filters:UpdateCollectionButtons()
    if not self.collectionToggles then return end

    for _, btn in pairs(self.collectionToggles) do
        if btn.UpdateVisuals then
            btn.UpdateVisuals()
        end
    end
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

    -- Save search text
    local searchText = addon.SearchBox and addon.SearchBox:GetText()
    db.searchText = (searchText and strtrim(searchText) ~= "") and searchText or ""

    -- Save searcher-based filters
    local searcher = addon.catalogSearcher
    if searcher then
        db.indoors = searcher:IsAllowedIndoorsActive()
        db.outdoors = searcher:IsAllowedOutdoorsActive()
        db.dyeable = searcher:IsCustomizableOnlyActive()

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

    -- Restore collection toggles (mutually exclusive)
    MigrateCollectionState(db)
    if db.showCollected then
        self.showCollected = true
        self.showUncollected = false
    else
        self.showCollected = false
        self.showUncollected = true
    end
    self:UpdateCollectionButtons()

    -- Apply collection filter to searcher
    if searcher then
        searcher:SetCollected(self.showCollected)
        searcher:SetUncollected(self.showUncollected)
    end

    -- Restore trackable state
    self:SetTrackableState(db.trackableState or "all")

    -- Restore wishlist-only filter
    self.showWishlistOnly = db.showWishlistOnly or false

    -- Restore search text
    if db.searchText and db.searchText ~= "" and addon.SearchBox and addon.SearchBox.frame then
        addon.SearchBox.frame:SetText(db.searchText)
        addon.SearchBox.lastSearchText = db.searchText
        if searcher then
            searcher:SetSearchText(db.searchText)
        end
    end

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

    -- Update FilterBar reset button state
    if addon.FilterBar and addon.FilterBar.dropdownButton then
        addon.FilterBar.dropdownButton:ValidateResetState()
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

    -- Reset collection toggles (default to showing uncollected)
    self.showCollected = false
    self.showUncollected = true
    self:UpdateCollectionButtons()

    -- Apply collection filter to searcher
    if searcher then
        searcher:SetCollected(false)
        searcher:SetUncollected(true)
    end

    -- Reset trackable state
    self:SetTrackableState("all")

    -- Reset wishlist-only filter
    self:SetWishlistOnly(false)

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

function Filters:ResetFilters()
    -- Legacy method - redirect to full reset
    self:ResetAllFilters()
end

function Filters:Show()
    if self.toggleContainer then
        self.toggleContainer:Show()
    end
end

function Filters:Hide()
    if self.toggleContainer then
        self.toggleContainer:Hide()
    end
end

-- Apply saved filters after data loads
addon:RegisterInternalEvent("DATA_LOADED", function()
    Filters:Initialize()
    -- Restore full filter state (includes collection filter)
    Filters:RestoreState()
end)
