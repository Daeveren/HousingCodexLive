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
L["LOADED_MESSAGE"] = "Loaded |cFF88EE88%d decor|r items. Type |cFF88BBFF/hc|r to open."
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
L["TAB_DECOR_DESC"] = "Browse and search all housing decor items"
L["TAB_QUESTS_DESC"] = "Quest sources for housing items"
L["TAB_ACHIEVEMENTS_DESC"] = "Achievement sources for housing items"
L["TAB_VENDORS_DESC"] = "Vendor locations for housing items"
L["TAB_DROPS_DESC"] = "Drop sources for housing items"
L["TAB_PROFESSIONS_DESC"] = "Crafted housing items"
L["TAB_COMING_SOON"] = "Coming Soon"

--------------------------------------------------------------------------------
-- Search & Filters
--------------------------------------------------------------------------------
L["SEARCH_PLACEHOLDER"] = "Search..."
L["FILTER_ALL"] = "All Items"
L["FILTER_COLLECTED"] = "Collected"
L["FILTER_UNCOLLECTED"] = "Uncollected"
L["FILTER_NOT_COLLECTED"] = "Not Collected"
L["FILTER_TRACKABLE"] = "Trackable Only"
L["FILTER_NOT_TRACKABLE"] = "Not Trackable"
L["FILTER_TRACKABLE_HEADER"] = "Trackable"
L["FILTER_TRACKABLE_ALL"] = "All"
L["FILTER_INDOORS"] = "Indoors"
L["FILTER_OUTDOORS"] = "Outdoors"
L["FILTER_DYEABLE"] = "Dyeable"
L["FILTER_FIRST_ACQUISITION"] = "First Acquisition Bonus"
L["FILTER_WISHLIST_ONLY"] = "Wishlist Only"
L["FILTER_PLACED_IN_HOUSE"] = "Placed in House"
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
L["SORT_PLACED"] = "Qty Placed"

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
L["DETAILS_PLACED"] = "Placed: %d"
L["DETAILS_NOT_OWNED"] = "Not Owned"
L["DETAILS_SIZE"] = "Size:"
L["DETAILS_PLACE"] = "Place:"
L["DETAILS_DYEABLE"] = "Dyeable"
L["DETAILS_NOT_DYEABLE"] = "Not Dyeable"
L["DETAILS_SOURCE_UNKNOWN"] = "Unknown source"
L["UNKNOWN"] = "Unknown"

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
L["WISHLIST_BUTTON"] = "WISHLIST"
L["WISHLIST_BUTTON_TOOLTIP"] = "View your wishlist"
L["WISHLIST_TITLE"] = "Wishlist"
L["WISHLIST_EMPTY"] = "Your wishlist is empty"
L["WISHLIST_EMPTY_DESC"] = "Add items by clicking the star icon in Decor or Quests tabs"
L["WISHLIST_SHIFT_CLICK"] = "Shift+Click to add/remove from wishlist"

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
L["TRACKING_ERROR_MAX"] = "Cannot track: Maximum tracked items reached"
L["TRACKING_ERROR_UNTRACKABLE"] = "This item cannot be tracked"
L["TRACKING_STARTED"] = "Now tracking: %s"
L["TRACKING_STOPPED"] = "Stopped tracking: %s"
L["TOOLTIP_SHIFT_CLICK_TRACK"] = "Shift-click to track"
L["TOOLTIP_SHIFT_CLICK_UNTRACK"] = "Shift-click to untrack"
L["TRACKING_ERROR_GENERIC"] = "Tracking failed"
L["LINK_ERROR"] = "Unable to create item link"
L["LINK_INSERTED"] = "Link inserted into chat"

--------------------------------------------------------------------------------
-- Preview
--------------------------------------------------------------------------------
L["PREVIEW_NO_MODEL"] = "No 3D model available"
L["PREVIEW_NO_SELECTION"] = "Select an item to preview"
L["PREVIEW_ERROR"] = "Error loading model"

--------------------------------------------------------------------------------
-- Settings (WoW Native Settings UI)
--------------------------------------------------------------------------------
L["OPTIONS_SECTION_DISPLAY"] = "Display"
L["OPTIONS_USE_CUSTOM_FONT"] = "Use Housing Codex font"
L["OPTIONS_USE_CUSTOM_FONT_TOOLTIP"] = "When disabled, the addon uses the default WoW font instead"
L["OPTIONS_SHOW_COLLECTED"] = "Show owned quantity on tiles"
L["OPTIONS_SHOW_COLLECTED_TOOLTIP"] = "Display owned count on grid tiles for collected items"
L["OPTIONS_SHOW_MINIMAP"] = "Show minimap button"
L["OPTIONS_SHOW_MINIMAP_TOOLTIP"] = "Show the Housing Codex button on the minimap"
L["OPTIONS_VENDOR_INDICATORS"] = "Mark decor items at vendors"
L["OPTIONS_VENDOR_INDICATORS_TOOLTIP"] = "Display Housing Codex icon on vendor items that are housing decor"
L["OPTIONS_VENDOR_OWNED_CHECKMARK"] = "Show checkmark for owned decor"
L["OPTIONS_VENDOR_OWNED_CHECKMARK_TOOLTIP"] = "Display a green checkmark on vendor decor items you already own"

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
L["HELP_SETTINGS"] = "/hc settings - Open settings"
L["HELP_RETRY"] = "/hc retry - Retry loading data"
L["HELP_HELP"] = "/hc help - Show this help"
L["HELP_DEBUG"] = "/hc debug - Toggle debug mode"

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------
L["SETTINGS_NOT_AVAILABLE"] = "Settings not yet available"
L["RETRYING_DATA_LOAD"] = "Retrying data load..."
L["DEBUG_MODE_STATUS"] = "Debug mode: %s"
L["DEBUG_ON"] = "ON"
L["DEBUG_OFF"] = "OFF"
L["DATA_NOT_LOADED"] = "Data not loaded yet"
L["INSPECT_FOUND"] = "Found: %s (ID: %d)"
L["INSPECT_NOT_FOUND"] = "No item found matching: %s"
L["MAIN_WINDOW_NOT_AVAILABLE"] = "Main window not yet available"

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

--------------------------------------------------------------------------------
-- Quests Tab
--------------------------------------------------------------------------------
L["QUESTS_SEARCH_PLACEHOLDER"] = "Search quests, zones, or rewards..."
L["QUESTS_FILTER_ALL"] = "All"
L["QUESTS_FILTER_INCOMPLETE"] = "Incomplete"
L["QUESTS_FILTER_COMPLETE"] = "Complete"
L["QUESTS_EMPTY_NO_SOURCES"] = "No quest sources found"
L["QUESTS_EMPTY_NO_SOURCES_DESC"] = "Quest data may not be exposed by the WoW API"
L["QUESTS_SELECT_EXPANSION"] = "Select an expansion"
L["QUESTS_EMPTY_NO_RESULTS"] = "No quests match your search"
L["QUESTS_LOADING"] = "Loading..."
L["QUESTS_UNKNOWN_QUEST"] = "Quest #%d"
L["QUESTS_UNKNOWN_ZONE"] = "Unknown Zone"
L["QUESTS_UNKNOWN_EXPANSION"] = "Other"

-- Quest tracking messages
L["QUESTS_TRACKING_STARTED"] = "Now tracking item"
L["QUESTS_TRACKING_STOPPED"] = "Stopped tracking item"
L["QUESTS_TRACKING_MAX_REACHED"] = "Cannot track - maximum items reached (15)"
L["QUESTS_TRACKING_ALREADY"] = "Already tracking this item"
L["QUESTS_TRACKING_FAILED"] = "Cannot track this item"

-- Expansion names
L["EXPANSION_CLASSIC"] = "Classic"
L["EXPANSION_TBC"] = "The Burning Crusade"
L["EXPANSION_WRATH"] = "Wrath of the Lich King"
L["EXPANSION_CATA"] = "Cataclysm"
L["EXPANSION_MOP"] = "Mists of Pandaria"
L["EXPANSION_WOD"] = "Warlords of Draenor"
L["EXPANSION_LEGION"] = "Legion"
L["EXPANSION_BFA"] = "Battle for Azeroth"
L["EXPANSION_SL"] = "Shadowlands"
L["EXPANSION_DF"] = "Dragonflight"
L["EXPANSION_TWW"] = "The War Within"
L["EXPANSION_MIDNIGHT"] = "Midnight"

--------------------------------------------------------------------------------
-- Achievements Tab
--------------------------------------------------------------------------------
L["ACHIEVEMENTS_SEARCH_PLACEHOLDER"] = "Search achievements, rewards, or categories..."
L["ACHIEVEMENTS_FILTER_ALL"] = "All"
L["ACHIEVEMENTS_FILTER_INCOMPLETE"] = "Incomplete"
L["ACHIEVEMENTS_FILTER_COMPLETE"] = "Complete"
L["ACHIEVEMENTS_EMPTY_NO_SOURCES"] = "No achievement sources found"
L["ACHIEVEMENTS_EMPTY_NO_SOURCES_DESC"] = "Achievement data may not be available"
L["ACHIEVEMENTS_SELECT_CATEGORY"] = "Select a category"
L["ACHIEVEMENTS_EMPTY_NO_RESULTS"] = "No achievements match your search"
L["ACHIEVEMENTS_UNKNOWN"] = "Achievement #%d"

-- Achievement tracking messages
L["ACHIEVEMENTS_TRACKING_STARTED"] = "Now tracking item"
L["ACHIEVEMENTS_TRACKING_STARTED_ACHIEVEMENT"] = "Now tracking achievement"
L["ACHIEVEMENTS_TRACKING_STOPPED"] = "Stopped tracking achievement"
L["ACHIEVEMENTS_TRACKING_MAX_REACHED"] = "Cannot track - maximum items reached (15)"
L["ACHIEVEMENTS_TRACKING_ALREADY"] = "Already tracking this item"
L["ACHIEVEMENTS_TRACKING_FAILED"] = "Cannot track this achievement"

-- Wowhead link messages
L["WOWHEAD_LINK_COPIED"] = "Copied to clipboard: %s"
L["WOWHEAD_LINK_NO_ID"] = "Cannot copy link - quest ID unknown"

--------------------------------------------------------------------------------
-- Context Menu
--------------------------------------------------------------------------------
L["CONTEXT_MENU_LINK_TO_CHAT"] = "Link to Chat"
L["CONTEXT_MENU_COPY_WOWHEAD"] = "Copy Wowhead Link"

-- Note: Achievement category names come from WoW's GetCategoryInfo() API
-- which returns already-localized strings, so no L[] entries needed
