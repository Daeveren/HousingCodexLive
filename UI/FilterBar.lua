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
    dropdown:SetText(L["FILTERS"])
    self.dropdownButton = dropdown

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

    -- Collection filters (can be combined: both, one, or none)
    rootDescription:CreateCheckbox(
        L["FILTER_COLLECTED"],
        function() return addon.Filters.showCollected end,
        function()
            addon.Filters:SetShowCollected(not addon.Filters.showCollected)
            addon.Filters:SaveState()
        end
    )
    rootDescription:CreateCheckbox(
        L["FILTER_NOT_COLLECTED"],
        function() return addon.Filters.showUncollected end,
        function()
            addon.Filters:SetShowUncollected(not addon.Filters.showUncollected)
            addon.Filters:SaveState()
        end
    )

    rootDescription:CreateSpacer()

    -- Wishlist-only filter (post-search filter via addon.Filters)
    rootDescription:CreateCheckbox(
        L["FILTER_WISHLIST_ONLY"],
        function() return addon.Filters.showWishlistOnly end,
        function()
            addon.Filters:SetWishlistOnly(not addon.Filters.showWishlistOnly)
            addon.Filters:SaveState()
        end
    )

    -- NOTE: "Placed in House" filter disabled — Blizzard API returns numPlaced=0
    -- for all items (bug in GetCatalogEntryInfo). Re-enable when Blizzard fixes.

    rootDescription:CreateSpacer()

    -- Trackable filter submenu (post-search filter via addon.Filters)
    local trackableSubmenu = rootDescription:CreateButton(L["FILTER_TRACKABLE_HEADER"])
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
                L["CHECK_ALL"],
                function()
                    searcher:SetAllInFilterTagGroup(tagGroup.groupID, true)
                    addon.Filters:SaveState()
                    return MenuResponse.Refresh
                end,
                tagGroup.groupID
            )
            groupSubmenu:CreateButton(
                L["UNCHECK_ALL"],
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

function FilterBar:ResetToDefault()
    local searcher = addon.catalogSearcher
    if not searcher then return end

    addon:WithSearcherBatchUpdate("ResetToDefault", function()
        -- Reset collection filters (default: show uncollected only)
        addon.Filters:SetCollectionDirect(false, true)

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
    end)

    -- Save the reset state
    addon.Filters:SaveState()

    addon:Debug("FilterBar reset to defaults")
end

-- Initialize after data loads
addon:RegisterInternalEvent("DATA_LOADED", function()
    FilterBar:Initialize()
end)
