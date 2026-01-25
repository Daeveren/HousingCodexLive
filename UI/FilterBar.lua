--[[
    Housing Codex - FilterBar.lua
    Tag group filter dropdown using modern Blizzard_Menu system
]]

local ADDON_NAME, addon = ...

local L = addon.L

addon.FilterBar = {}
local FilterBar = addon.FilterBar

FilterBar.tagGroups = nil
FilterBar.dropdownButton = nil
FilterBar.initialized = false

-- Trackable filter options (constant)
local TRACKABLE_OPTIONS = {
    { key = "all",           labelKey = "FILTER_TRACKABLE_ALL",  fallback = "All" },
    { key = "trackable",     labelKey = "FILTER_TRACKABLE",      fallback = "Trackable Only" },
    { key = "not_trackable", labelKey = "FILTER_NOT_TRACKABLE",  fallback = "Not Trackable" },
}

function FilterBar:Initialize()
    if self.initialized then return end

    -- Guard: API may not be available
    if not C_HousingCatalog or not C_HousingCatalog.GetAllFilterTagGroups then
        addon:Debug("FilterBar: GetAllFilterTagGroups API not available")
        return
    end

    -- Cache tag groups from API
    self.tagGroups = C_HousingCatalog.GetAllFilterTagGroups()
    self.initialized = true

    addon:Debug("FilterBar initialized with " .. (self.tagGroups and #self.tagGroups or 0) .. " tag groups")
end

function FilterBar:CreateDropdown(parent)
    if self.dropdownButton then return self.dropdownButton end

    -- Create dropdown using WowStyle1FilterDropdownTemplate
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1FilterDropdownTemplate")
    dropdown:SetSize(93, 22)
    dropdown:SetText(L["FILTERS"] or "Filters")
    self.dropdownButton = dropdown

    -- Setup isDefault and reset callbacks for the reset button
    dropdown:SetIsDefaultCallback(function() return self:IsAtDefault() end)
    dropdown:SetDefaultCallback(function() self:ResetToDefault() end)

    -- Setup the menu
    dropdown:SetupMenu(function(dropdownFrame, rootDescription)
        self:SetupMenu(rootDescription)
    end)

    return dropdown
end

-- Special filter checkbox configuration
-- key: localization key, fallback: English text
-- getter/toggler: HousingCatalogSearcher method names
-- default: expected state when filters are reset
local SPECIAL_FILTERS = {
    { key = "FILTER_DYEABLE",            fallback = "Dyeable",                 getter = "IsCustomizableOnlyActive",           toggler = "ToggleCustomizableOnly",           default = false },
    { key = "FILTER_INDOORS",            fallback = "Indoors",                 getter = "IsAllowedIndoorsActive",             toggler = "ToggleAllowedIndoors",             default = true },
    { key = "FILTER_OUTDOORS",           fallback = "Outdoors",                getter = "IsAllowedOutdoorsActive",            toggler = "ToggleAllowedOutdoors",            default = true },
    { key = "FILTER_FIRST_ACQUISITION",  fallback = "First Acquisition Bonus", getter = "IsFirstAcquisitionBonusOnlyActive",  toggler = "ToggleFirstAcquisitionBonusOnly",  default = false },
}

function FilterBar:SetupMenu(rootDescription)
    local searcher = addon.catalogSearcher
    if not searcher then return end

    -- Wishlist-only filter (post-search filter via addon.Filters)
    rootDescription:CreateCheckbox(
        L["FILTER_WISHLIST_ONLY"] or "Wishlist Only",
        function() return addon.Filters.showWishlistOnly end,
        function()
            addon.Filters:SetWishlistOnly(not addon.Filters.showWishlistOnly)
            addon.Filters:SaveState()
        end
    )

    rootDescription:CreateSpacer()

    -- Trackable filter submenu (post-search filter via addon.Filters)
    local trackableSubmenu = rootDescription:CreateButton(L["FILTER_TRACKABLE_HEADER"] or "Trackable")
    for _, opt in ipairs(TRACKABLE_OPTIONS) do
        local label = L[opt.labelKey] or opt.fallback
        trackableSubmenu:CreateRadio(
            label,
            function() return addon.Filters.trackableState == opt.key end,
            function()
                addon.Filters:SetTrackableState(opt.key)
                addon.Filters:SaveState()
            end
        )
    end

    rootDescription:CreateSpacer()

    -- Create checkboxes for special filters (with save on change)
    for _, filter in ipairs(SPECIAL_FILTERS) do
        local label = L[filter.key] or filter.fallback
        local getter = function() return searcher[filter.getter](searcher) end
        local toggler = function()
            searcher[filter.toggler](searcher)
            addon.Filters:SaveState()
        end
        rootDescription:CreateCheckbox(label, getter, toggler)
    end

    -- Add tag group submenus if available
    if not self.tagGroups then return end

    rootDescription:CreateSpacer()

    -- Create submenu for each tag group
    for _, tagGroup in ipairs(self.tagGroups) do
        if tagGroup.tags and next(tagGroup.tags) then
            local groupSubmenu = rootDescription:CreateButton(tagGroup.groupName)

            -- Check All / Uncheck All buttons
            groupSubmenu:CreateButton(
                L["CHECK_ALL"] or "Check All",
                function()
                    searcher:SetAllInFilterTagGroup(tagGroup.groupID, true)
                    addon.Filters:SaveState()
                    return MenuResponse.Refresh
                end,
                tagGroup.groupID
            )
            groupSubmenu:CreateButton(
                L["UNCHECK_ALL"] or "Uncheck All",
                function()
                    searcher:SetAllInFilterTagGroup(tagGroup.groupID, false)
                    addon.Filters:SaveState()
                    return MenuResponse.Refresh
                end,
                tagGroup.groupID
            )

            -- Sort tags by orderIndex before building menu
            local sortedTags = {}
            for _, tagInfo in pairs(tagGroup.tags) do
                if tagInfo.anyAssociatedEntries then
                    table.insert(sortedTags, tagInfo)
                end
            end
            table.sort(sortedTags, function(a, b) return a.orderIndex < b.orderIndex end)

            -- Add checkbox for each tag
            for _, tagInfo in ipairs(sortedTags) do
                groupSubmenu:CreateCheckbox(
                    tagInfo.tagName,
                    function() return searcher:GetFilterTagStatus(tagGroup.groupID, tagInfo.tagID) end,
                    function()
                        searcher:ToggleFilterTag(tagGroup.groupID, tagInfo.tagID)
                        addon.Filters:SaveState()
                    end
                )
            end
        end
    end
end

function FilterBar:IsAtDefault()
    local searcher = addon.catalogSearcher
    if not searcher then return true end

    -- Check wishlist-only filter (default is false)
    if addon.Filters.showWishlistOnly then
        return false
    end

    -- Check trackable filter (default is "all")
    if addon.Filters.trackableState ~= "all" then
        return false
    end

    -- Check special filters using their default values
    for _, filter in ipairs(SPECIAL_FILTERS) do
        local isActive = searcher[filter.getter](searcher)
        if isActive ~= filter.default then
            return false
        end
    end

    -- Check tag groups - all tags should be enabled in default state
    if self.tagGroups then
        for _, tagGroup in ipairs(self.tagGroups) do
            for _, tagInfo in pairs(tagGroup.tags) do
                if not searcher:GetFilterTagStatus(tagGroup.groupID, tagInfo.tagID) then
                    return false
                end
            end
        end
    end

    return true
end

function FilterBar:ResetToDefault()
    local searcher = addon.catalogSearcher
    if not searcher then return end

    -- Disable auto-update to batch all changes into a single search
    searcher:SetAutoUpdateOnParamChanges(false)

    -- Reset wishlist-only filter (post-search filter)
    addon.Filters:SetWishlistOnly(false)

    -- Reset trackable filter (post-search filter)
    addon.Filters:SetTrackableState("all")

    -- Reset special filters to their default values
    searcher:SetCustomizableOnly(false)
    searcher:SetAllowedIndoors(true)
    searcher:SetAllowedOutdoors(true)
    searcher:SetFirstAcquisitionBonusOnly(false)

    -- Reset all tag groups to enabled
    if self.tagGroups then
        for _, tagGroup in ipairs(self.tagGroups) do
            searcher:SetAllInFilterTagGroup(tagGroup.groupID, true)
        end
    end

    -- Re-enable auto-update and run search once
    searcher:SetAutoUpdateOnParamChanges(true)
    searcher:RunSearch()

    if self.dropdownButton then
        self.dropdownButton:ValidateResetState()
    end

    -- Save the reset state
    addon.Filters:SaveState()

    addon:Debug("FilterBar reset to defaults")
end

-- Initialize after data loads
addon:RegisterInternalEvent("DATA_LOADED", function()
    FilterBar:Initialize()
    -- Validate reset button state after initialization
    if FilterBar.dropdownButton then
        FilterBar.dropdownButton:ValidateResetState()
    end
end)
