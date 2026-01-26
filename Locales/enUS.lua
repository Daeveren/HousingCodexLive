--[[
    Housing Codex - enUS.lua
    English (US) localization - base language
]]

local ADDON_NAME, addon = ...

local L = addon.L

--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------
L["ADDON_NAME"] = "Housing Codex"
L["LOADING"] = "Loading..."
L["LOADING_DATA"] = "Loading decor data..."
L["LOADED_MESSAGE"] = "Loaded %d decor items"
L["LOADED_MESSAGE_TIME"] = "Loaded %d decor items in %d ms"
L["COMBAT_LOCKDOWN_MESSAGE"] = "Cannot open during combat"

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------
L["TAB_DECOR"] = "DECOR"
L["TAB_QUESTS"] = "QUESTS"
L["TAB_ACHIEVEMENTS"] = "ACHIEVEMENTS"
L["TAB_VENDORS"] = "VENDORS"
L["TAB_DROPS"] = "DROPS"
L["TAB_PROFESSIONS"] = "PROFESSIONS"

--------------------------------------------------------------------------------
-- Search & Filters
--------------------------------------------------------------------------------
L["SEARCH_PLACEHOLDER"] = "Search..."
L["FILTER_ALL"] = "All Items"
L["FILTER_COLLECTED"] = "Collected"
L["FILTER_UNCOLLECTED"] = "Uncollected"
L["FILTER_TRACKABLE"] = "Trackable Only"
L["FILTER_NOT_TRACKABLE"] = "Not Trackable"
L["FILTER_TRACKABLE_HEADER"] = "Trackable"
L["FILTER_TRACKABLE_ALL"] = "All"
L["FILTER_INDOORS"] = "Indoors"
L["FILTER_OUTDOORS"] = "Outdoors"
L["FILTER_DYEABLE"] = "Dyeable"
L["FILTER_FIRST_ACQUISITION"] = "First Acquisition Bonus"
L["FILTER_WISHLIST_ONLY"] = "Wishlist Only"
L["FILTERS"] = "Filters"
L["CHECK_ALL"] = "Check All"
L["UNCHECK_ALL"] = "Uncheck All"

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------
L["SIZE_LABEL"] = "Size:"
L["SORT_BY_LABEL"] = "Sort by"

--------------------------------------------------------------------------------
-- Sort
--------------------------------------------------------------------------------
L["SORT_NEWEST"] = "Newest"
L["SORT_ALPHABETICAL"] = "A-Z"
L["SORT_SIZE"] = "Size"
L["SORT_QUANTITY"] = "Qty Owned"

--------------------------------------------------------------------------------
-- Result Count & Empty State
--------------------------------------------------------------------------------
L["RESULT_COUNT_ALL"] = "Showing %d items"
L["RESULT_COUNT_FILTERED"] = "Showing %d of %d items"
L["EMPTY_STATE_MESSAGE"] = "No items match your filters"
L["RESET_FILTERS"] = "Reset Filters"

--------------------------------------------------------------------------------
-- Category Navigation
--------------------------------------------------------------------------------
L["CATEGORY_ALL"] = "All"
L["CATEGORY_BACK"] = "Back"
L["CATEGORY_ALL_IN"] = "All %s"

--------------------------------------------------------------------------------
-- Details Panel
--------------------------------------------------------------------------------
L["DETAILS_NO_SELECTION"] = "Select an item"
L["DETAILS_OWNED"] = "Owned: %d"
L["DETAILS_NOT_OWNED"] = "Not Owned"
L["DETAILS_METADATA"] = "Metadata"
L["DETAILS_SIZE"] = "Size:"
L["DETAILS_PLACE"] = "Place:"
L["DETAILS_DYEABLE"] = "Dyeable"
L["DETAILS_NOT_DYEABLE"] = "Not Dyeable"
L["DETAILS_TRACKING"] = "Track:"
L["DETAILS_SOURCE"] = "Source"
L["DETAILS_SOURCE_UNKNOWN"] = "Unknown source"
L["DETAILS_TRACKING_ACTIVE"] = "Tracking"
L["DETAILS_TRACKING_AVAILABLE"] = "Available"
L["DETAILS_TRACKING_UNAVAILABLE"] = "N/A"
L["YES"] = "Yes"
L["NO"] = "No"

-- Size names
L["SIZE_NONE"] = "None"
L["SIZE_TINY"] = "Tiny"
L["SIZE_SMALL"] = "Small"
L["SIZE_MEDIUM"] = "Medium"
L["SIZE_LARGE"] = "Large"
L["SIZE_HUGE"] = "Huge"

-- Placement types
L["PLACEMENT_INDOORS"] = "Indoors"
L["PLACEMENT_OUTDOORS"] = "Outdoors"
L["PLACEMENT_BOTH"] = "Both"
L["PLACEMENT_IN"] = "In"
L["PLACEMENT_OUT"] = "Out"

--------------------------------------------------------------------------------
-- Wishlist
--------------------------------------------------------------------------------
L["WISHLIST"] = "Wishlist"
L["WISHLIST_ADD"] = "Add to Wishlist"
L["WISHLIST_REMOVE"] = "Remove from Wishlist"
L["WISHLIST_ADDED"] = "Added to wishlist: %s"
L["WISHLIST_REMOVED"] = "Removed from wishlist: %s"

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------
L["ACTION_TRACK"] = "Track"
L["ACTION_UNTRACK"] = "Untrack"
L["ACTION_LINK"] = "Link"
L["ACTION_TRACK_TOOLTIP"] = "Track this item in the objectives tracker"
L["ACTION_UNTRACK_TOOLTIP"] = "Stop tracking this item"
L["ACTION_TRACK_DISABLED_TOOLTIP"] = "This item cannot be tracked"
L["ACTION_LINK_TOOLTIP"] = "Insert item link into chat"
L["ACTION_LINK_TOOLTIP_RIGHTCLICK"] = "Right-click: Copy Wowhead URL"
L["ACTION_LINK_DISABLED_TOOLTIP"] = "Open chat to insert link"
L["TRACKING_ERROR_MAX"] = "Cannot track: Maximum tracked items reached (15)"
L["TRACKING_ERROR_UNTRACKABLE"] = "This item cannot be tracked"
L["TRACKING_STARTED"] = "Now tracking: %s"
L["TRACKING_STOPPED"] = "Stopped tracking: %s"
L["LINK_ERROR"] = "Unable to create item link"
L["LINK_INSERTED"] = "Link inserted into chat"

--------------------------------------------------------------------------------
-- Preview
--------------------------------------------------------------------------------
L["PREVIEW_TITLE"] = "Preview"
L["PREVIEW_LOADING"] = "Loading model..."
L["PREVIEW_NO_MODEL"] = "No 3D model available"
L["PREVIEW_NO_SELECTION"] = "Select an item to preview"
L["PREVIEW_ERROR"] = "Error loading model"
L["PREVIEW_ZOOM_IN"] = "Zoom In"
L["PREVIEW_ZOOM_OUT"] = "Zoom Out"
L["PREVIEW_RESET"] = "Reset View"
L["PREVIEW_COLLAPSE"] = "Hide Preview"
L["PREVIEW_EXPAND"] = "Show Preview"

--------------------------------------------------------------------------------
-- Settings (WoW Native Settings UI)
--------------------------------------------------------------------------------
L["SETTINGS"] = "Settings"
L["OPTIONS_TITLE"] = "Housing Codex Settings"
L["OPTIONS_SECTION_DISPLAY"] = "Display"
L["OPTIONS_USE_CUSTOM_FONT"] = "Use Custom Font (Roboto Condensed)"
L["OPTIONS_USE_CUSTOM_FONT_TOOLTIP"] = "Use the custom Roboto Condensed font for addon text"
L["OPTIONS_SHOW_COLLECTED"] = "Show owned quantity on tiles"
L["OPTIONS_SHOW_COLLECTED_TOOLTIP"] = "Display owned count on grid tiles for collected items"
L["OPTIONS_SECTION_KEYBIND"] = "Keybind"
L["OPTIONS_TOGGLE_KEYBIND"] = "Toggle Window:"
L["OPTIONS_NOT_BOUND"] = "Not Bound"
L["OPTIONS_PRESS_KEY"] = "Press a key..."
L["OPTIONS_UNBIND_TOOLTIP"] = "Right-click to unbind"
L["OPTIONS_KEYBIND_HINT"] = "Click to set keybind. Right-click to clear. ESC to cancel."

--------------------------------------------------------------------------------
-- Slash Command Help
--------------------------------------------------------------------------------
L["HELP_TITLE"] = "Housing Codex Commands:"
L["HELP_TOGGLE"] = "/hc - Toggle main window"
L["HELP_PREVIEW"] = "/hc preview - Toggle preview window"
L["HELP_SETTINGS"] = "/hc settings - Open settings"
L["HELP_RETRY"] = "/hc retry - Retry loading data"
L["HELP_HELP"] = "/hc help - Show this help"
L["HELP_DEBUG"] = "/hc debug - Toggle debug mode"

--------------------------------------------------------------------------------
-- Errors
--------------------------------------------------------------------------------
L["ERROR_API_UNAVAILABLE"] = "Housing APIs not available"
L["ERROR_NO_DATA"] = "No decor data loaded"
L["ERROR_LOAD_FAILED"] = "Failed to load housing data after multiple attempts. Use /hc retry to try again."
L["ERROR_LOAD_FAILED_SHORT"] = "Failed to load data. Use /hc retry"

--------------------------------------------------------------------------------
-- LDB (LibDataBroker)
--------------------------------------------------------------------------------
L["LDB_TOOLTIP_LEFT"] = "|cffffffffLeft-click|r to toggle main window"
L["LDB_TOOLTIP_RIGHT"] = "|cffffffffRight-click|r to open options"
L["LDB_OPTIONS_PLACEHOLDER"] = "Options panel not yet available"
