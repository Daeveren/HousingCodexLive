--[[
    Housing Codex - enUS.lua
    English (US) localization - base language
]]

local _, addon = ...

local L = addon.L

--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------
L["ADDON_NAME"] = "Housing Codex"
L["KEYBIND_HEADER"] = "|cffffd100Housing|r |cffff8000Codex|r"
L["KEYBIND_TOGGLE"] = "|cffff8000Housing Codex|r Toggle Window"
L["LOADING"] = "Loading..."
L["LOADING_DATA"] = "Loading decor data..."
L["LOADED_MESSAGE"] = "|cFF88EE88%.1f%%|r decor collected. Type |cFF88BBFF/hc|r to open."
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
L["TAB_ACHIEVEMENTS_SHORT"] = "ACH..."
L["TAB_PROFESSIONS_SHORT"] = "PROF..."
L["TAB_PROGRESS_SHORT"] = "PROG..."
L["TAB_DECOR_DESC"] = "Browse and search all housing decor items"
L["TAB_QUESTS_DESC"] = "Quest sources for housing items"
L["TAB_ACHIEVEMENTS_DESC"] = "Achievement sources for housing items"
L["TAB_VENDORS_DESC"] = "Vendor locations for housing items"
L["TAB_DROPS_DESC"] = "Drop sources for housing items"
L["TAB_PROFESSIONS_DESC"] = "Crafted housing items"
--------------------------------------------------------------------------------
-- Search & Filters
--------------------------------------------------------------------------------
L["SEARCH_PLACEHOLDER"] = "Search..."
L["FILTER_ALL"] = "All Items"
L["FILTER_COLLECTED"] = "Collected"
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
L["FILTERS"] = "Filters"
L["CHECK_ALL"] = "Check All"
L["UNCHECK_ALL"] = "Uncheck All"

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------
L["SIZE_LABEL"] = "Size:"
L["SORT_BY_LABEL"] = "Sort"

--------------------------------------------------------------------------------
-- Sort
--------------------------------------------------------------------------------
L["SORT_NEWEST"] = "Newest"
L["SORT_ALPHABETICAL"] = "A-Z"
L["SORT_SIZE"] = "Size"
L["SORT_QUANTITY"] = "Qty Owned"
L["SORT_PLACED"] = "Qty Placed"
L["SORT_NEWEST_TIP"] = "Most recently added decor first"
L["SORT_ALPHABETICAL_TIP"] = "Alphabetical order (A to Z)"
L["SORT_SIZE_TIP"] = "Largest decor first (Huge to Tiny)"
L["SORT_QUANTITY_TIP"] = "Most owned copies first"
L["SORT_PLACED_TIP"] = "Most placed in your house first"

--------------------------------------------------------------------------------
-- Result Count & Empty State
--------------------------------------------------------------------------------
L["RESULT_COUNT_ALL"] = "Showing %d items"
L["RESULT_COUNT_FILTERED"] = "Showing %d of %d items"
L["RESULT_COUNT_TOOLTIP_UNIQUE"] = "Unique Decor Collected: %d / %d (%.1f%%)"
L["RESULT_COUNT_TOOLTIP_ROOMS"] = "Rooms Unlocked: %d / %d"
L["RESULT_COUNT_TOOLTIP_OWNED"] = "Total Decor Owned: %d"
L["RESULT_COUNT_TOOLTIP_TOTAL"] = "Total Items: %d (%d decor, %d rooms)"
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
L["SIZE_TINY"] = "Tiny"
L["SIZE_SMALL"] = "Small"
L["SIZE_MEDIUM"] = "Medium"
L["SIZE_LARGE"] = "Large"
L["SIZE_HUGE"] = "Huge"

-- Placement types
L["PLACEMENT_IN"] = "In"
L["PLACEMENT_OUT"] = "Out"

--------------------------------------------------------------------------------
-- Wishlist
--------------------------------------------------------------------------------
L["WISHLIST_ADD"] = "Add to Wishlist"
L["WISHLIST_REMOVE"] = "Remove from Wishlist"
L["WISHLIST_ADDED"] = "Added to wishlist: %s"
L["WISHLIST_REMOVED"] = "Removed from wishlist: %s"
L["WISHLIST_BUTTON"] = "WISHLIST"
L["WISHLIST_BUTTON_TOOLTIP"] = "View your wishlist"
L["CODEX_BUTTON"] = "HOUSING CODEX"
L["CODEX_BUTTON_TOOLTIP"] = "Back to main UI"
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
L["PREVIEW_NOT_IN_CATALOG"] = "Not yet in housing catalog"

--------------------------------------------------------------------------------
-- Settings (WoW Native Settings UI)
--------------------------------------------------------------------------------
L["OPTIONS_SECTION_DISPLAY"] = "Display"
L["OPTIONS_SECTION_MAP_NAV"]  = "Map & Navigation"
L["OPTIONS_SECTION_VENDOR"] = "Vendor"
L["OPTIONS_SHOW_COLLECTED"] = "Show quantity indicators on tiles"
L["OPTIONS_SHOW_COLLECTED_TOOLTIP"] = "Display owned and placed counts on grid tiles"
L["OPTIONS_SHOW_MINIMAP"] = "Show minimap button"
L["OPTIONS_SHOW_MINIMAP_TOOLTIP"] = "Show the Housing Codex button on the minimap"
L["OPTIONS_VENDOR_INDICATORS"] = "Mark decor items at vendors"
L["OPTIONS_VENDOR_INDICATORS_TOOLTIP"] = "Display Housing Codex icon on vendor items that are housing decor"
L["OPTIONS_VENDOR_OWNED_CHECKMARK"] = "Show checkmark for owned decor"
L["OPTIONS_VENDOR_OWNED_CHECKMARK_TOOLTIP"] = "Display a green checkmark on vendor decor items you already own"
L["OPTIONS_SECTION_CONTAINERS"] = "Bags & Bank"
L["OPTIONS_CONTAINER_INDICATORS"] = "Mark decor items in bags and bank"
L["OPTIONS_CONTAINER_INDICATORS_TOOLTIP"] = "Display Housing Codex icon on items in your bags and bank that are housing decor"
L["OPTIONS_CONTAINER_OWNED_CHECKMARK"] = "Show checkmark for owned decor"
L["OPTIONS_CONTAINER_OWNED_CHECKMARK_TOOLTIP"] = "Display a green checkmark on decor items in bags and bank that you already own"
L["OPTIONS_VENDOR_MAP_PINS"] = "Show Vendor Map Pins"
L["OPTIONS_VENDOR_MAP_PINS_TOOLTIP"] = "Display vendor pins on the world map with collection progress"
L["OPTIONS_TREASURE_HUNT_WAYPOINTS"] = "Auto-waypoint for Treasure Hunts"
L["OPTIONS_TREASURE_HUNT_WAYPOINTS_TOOLTIP"] = "Automatically set a map waypoint when accepting a Decor Treasure Hunt quest in housing zones"
L["OPTIONS_USE_TOMTOM"] = "Use TomTom for waypoints"
L["OPTIONS_USE_TOMTOM_TOOLTIP"] = "Use TomTom waypoints instead of the native map pin when TomTom is installed"
L["OPTIONS_USE_TOMTOM_NOT_INSTALLED"] = "Use TomTom for waypoints (Not Installed)"
L["OPTIONS_AUTO_ROTATE_PREVIEW"] = "Auto-rotate 3D preview"
L["OPTIONS_AUTO_ROTATE_PREVIEW_TOOLTIP"] = "Slowly rotate the 3D model in the preview panel and wishlist"
L["OPTIONS_SECTION_BROKER"] = "Minimap Button / Broker Display"
L["OPTIONS_LDB_UNIQUE"] = "Show unique decor collected"
L["OPTIONS_LDB_UNIQUE_TOOLTIP"] = "Display unique decor collected count in the minimap broker text"
L["OPTIONS_LDB_ROOMS"] = "Show rooms unlocked"
L["OPTIONS_LDB_ROOMS_TOOLTIP"] = "Display rooms unlocked count in the minimap broker text"
L["OPTIONS_LDB_TOTAL_OWNED"] = "Show total decor owned"
L["OPTIONS_LDB_TOTAL_OWNED_TOOLTIP"] = "Display total decor owned count (including duplicates) in the minimap broker text"
L["OPTIONS_LDB_TOTAL"] = "Show total items"
L["OPTIONS_LDB_TOTAL_TOOLTIP"] = "Display total catalog item count in the minimap broker text"
L["OPTIONS_RESET_POSITION"] = "Reset Window Position"
L["OPTIONS_RESET_POSITION_TOOLTIP"] = "Reset the window to the center of your screen"
L["OPTIONS_RESET_SIZE"] = "Reset Window Size"
L["OPTIONS_RESET_SIZE_TOOLTIP"] = "Reset the window to its default size"
L["OPTIONS_SHOW_WELCOME"] = "Welcome Screen"
L["OPTIONS_SHOW_WELCOME_TOOLTIP"] = "Show the welcome screen"
L["SIZE_RESET"] = "Window size reset to default."

L["OPTIONS_SECTION_KEYBIND"] = "Keybind"
L["OPTIONS_SECTION_TROUBLESHOOTING"] = "Troubleshooting"
L["OPTIONS_TOGGLE_KEYBIND"] = "Toggle Window:"
L["OPTIONS_NOT_BOUND"] = "Not Bound"
L["OPTIONS_PRESS_KEY"] = "Press a key..."
L["OPTIONS_UNBIND_TOOLTIP"] = "Right-click to unbind"
L["OPTIONS_KEYBIND_HINT"] = "Click to set keybind. Right-click to clear. ESC to cancel."
L["OPTIONS_KEYBIND_CONFLICT"] = "\"%s\" is already bound to \"%s\".\n\nDo you want to reassign it to Housing Codex?"

--------------------------------------------------------------------------------
-- Slash Command Help
--------------------------------------------------------------------------------
L["HELP_TITLE"] = "Housing Codex Commands:"
L["HELP_TOGGLE"] = "/hc - Toggle main window"
L["HELP_SETTINGS"] = "/hc settings - Open settings"
L["HELP_RESET"] = "/hc reset - Reset window position"
L["HELP_RETRY"] = "/hc retry - Retry loading data"
L["HELP_HELP"] = "/hc help - Show this help"
L["HELP_DEBUG"] = "/hc debug - Toggle debug mode"
L["HELP_STATS"] = "/hc stats - Show debug counters"

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------
L["SETTINGS_NOT_AVAILABLE"] = "Settings not yet available"
L["RETRYING_DATA_LOAD"] = "Retrying data load..."
L["DEBUG_MODE_STATUS"] = "Debug mode: %s"
L["FONT_MODE_STATUS"] = "Custom font: %s"
L["DEBUG_ON"] = "ON"
L["DEBUG_OFF"] = "OFF"
L["DATA_NOT_LOADED"] = "Data not loaded yet"
L["INSPECT_FOUND"] = "Found: %s (ID: %d)"
L["INSPECT_NOT_FOUND"] = "No item found matching: %s"
L["MAIN_WINDOW_NOT_AVAILABLE"] = "Main window not yet available"
L["POSITION_RESET"] = "Window position reset to center"

--------------------------------------------------------------------------------
-- Errors
--------------------------------------------------------------------------------
L["ERROR_API_UNAVAILABLE"] = "Housing APIs not available"
L["ERROR_LOAD_FAILED"] = "Failed to load housing data after multiple attempts. Use /hc retry to try again."
L["ERROR_LOAD_FAILED_SHORT"] = "Failed to load data. Use /hc retry"

--------------------------------------------------------------------------------
-- LDB (LibDataBroker)
--------------------------------------------------------------------------------
L["LDB_TOOLTIP_LEFT"] = "|cffffffffLeft-click|r to toggle main window"
L["LDB_TOOLTIP_RIGHT"] = "|cffffffffRight-click|r to open options"
L["LDB_TOOLTIP_ALT"] = "|cffffffffAlt-click|r to configure broker display"
L["LDB_OPTIONS_PLACEHOLDER"] = "Options panel not yet available"
L["LDB_POPUP_TITLE"] = "Broker Display"
L["LDB_TOOLTIP_DECOR_HEADER"] = "Collection Stats"
L["LDB_POPUP_UNIQUE"] = "Unique Decor"
L["LDB_POPUP_ROOMS"] = "Rooms Unlocked"
L["LDB_POPUP_TOTAL_OWNED"] = "Total Decor Owned"
L["LDB_POPUP_TOTAL_ITEMS"] = "Total Items"

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
L["QUESTS_UNKNOWN_QUEST"] = "Quest #%d"
L["QUESTS_UNKNOWN_ZONE"] = "Unknown Zone"
L["QUESTS_UNKNOWN_EXPANSION"] = "Other"

-- Quest tracking messages
L["QUESTS_TRACKING_STARTED"] = "Now tracking item"
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

--------------------------------------------------------------------------------
-- Context Menu
--------------------------------------------------------------------------------
L["CONTEXT_MENU_LINK_TO_CHAT"] = "Link to Chat"
L["CONTEXT_MENU_COPY_WOWHEAD"] = "Copy Wowhead Link"

-- Note: Achievement category names come from WoW's GetCategoryInfo() API
-- which returns already-localized strings, so no L[] entries needed

--------------------------------------------------------------------------------
-- Vendors Tab
--------------------------------------------------------------------------------
L["VENDORS_SEARCH_PLACEHOLDER"] = "Search vendors, zones, or items..."
L["VENDORS_FILTER_ALL"] = "All"
L["VENDORS_FILTER_INCOMPLETE"] = "Incomplete"
L["VENDORS_FILTER_COMPLETE"] = "Complete"
L["VENDORS_CURRENT_ZONE"] = "Current Zone"
L["VENDORS_EMPTY_NO_SOURCES"] = "No vendor sources found"
L["VENDORS_EMPTY_NO_SOURCES_DESC"] = "Vendor data may not be available"
L["VENDORS_SELECT_EXPANSION"] = "Select an expansion"
L["VENDORS_UNKNOWN_EXPANSION"] = "Other"
L["VENDORS_UNKNOWN_ZONE"] = "Unknown Zone"

-- Vendor waypoint messages
L["VENDOR_SET_WAYPOINT"] = "Set Waypoint"
L["VENDOR_NO_LOCATION"] = "Location unknown"
L["VENDOR_WAYPOINT_SET"] = "Waypoint set for %s"
L["VENDOR_MAP_RESTRICTED"] = "Cannot set waypoint on this map"

-- Vendor fallback names
L["VENDOR_UNKNOWN"] = "Unknown Vendor"
L["VENDOR_FALLBACK_NAME"] = "vendor"

-- Vendor world map pins
L["VENDOR_PIN_COLLECTED"] = "Collected: %d/%d"
L["VENDOR_PIN_UNCOLLECTED_HEADER"] = "Decor uncollected:"
L["VENDOR_PIN_ITEM_LOCKED"] = "locked"
L["VENDOR_PIN_MORE"] = "+%d more"
L["VENDOR_PIN_CLICK_WAYPOINT"] = "Click to set waypoint"
L["VENDOR_PIN_FACTION_ALLIANCE"] = "Alliance Only"
L["VENDOR_PIN_FACTION_HORDE"] = "Horde Only"
L["VENDOR_PIN_VENDOR_COUNT"] = "%dx Vendors"
L["VENDOR_PIN_VENDOR_LIST_HEADER"] = "Vendor list:"
L["VENDOR_PIN_VENDOR_ENTRY"] = "%s (%d/%d)"
L["VENDOR_PIN_VENDORS_MORE"] = "+%d more vendors"

-- Vendor tracking messages
L["VENDORS_TRACKING_STARTED"] = "Added a map pin to %s in %s"
L["VENDORS_TRACKING_STOPPED"] = "Removed map pin for %s in %s"
L["VENDORS_ACTION_TRACK"] = "Waypoint"
L["VENDORS_ACTION_UNTRACK"] = "Remove Waypoint"
L["VENDORS_ACTION_TRACK_TOOLTIP"] = "Set a map waypoint to this vendor's location"
L["VENDORS_ACTION_UNTRACK_TOOLTIP"] = "Remove the vendor waypoint"
L["VENDORS_ACTION_TRACK_DISABLED_TOOLTIP"] = "This vendor has no valid waypoint location"

-- Vendor cost display
L["CURRENCY_GOLD"] = "gold"
-- Vendor decor fallback
L["VENDORS_DECOR_ID"] = "Decor #%d"
L["VENDOR_CAT_ACCENTS"] = "Accents"
L["VENDOR_CAT_FUNCTIONAL"] = "Functional"
L["VENDOR_CAT_FURNISHINGS"] = "Furnishings"
L["VENDOR_CAT_LIGHTING"] = "Lighting"
L["VENDOR_CAT_MISCELLANEOUS"] = "Miscellaneous"
L["VENDOR_CAT_NATURE"] = "Nature"
L["VENDOR_CAT_STRUCTURAL"] = "Structural"
L["VENDOR_CAT_UNCATEGORIZED"] = "Uncategorized"

-- Vendor zone annotations
L["VENDOR_CLASS_HALL_SUFFIX"] = "class hall"
L["VENDOR_HOUSING_ZONE_SUFFIX"] = "housing zone"
L["VENDOR_CLASS_ONLY_SUFFIX"] = "%s Only"

-- Vendor tooltip overlay
L["OPTIONS_VENDOR_TOOLTIPS"] = "Show vendor decor in tooltips"
L["OPTIONS_VENDOR_TOOLTIPS_TOOLTIP"] = "Display Housing Codex collection progress when mousing over decor vendor NPCs"

--------------------------------------------------------------------------------
-- Drops Tab
--------------------------------------------------------------------------------
L["DROPS_SEARCH_PLACEHOLDER"] = "Search sources or items..."
L["DROPS_FILTER_ALL"] = "All"
L["DROPS_FILTER_INCOMPLETE"] = "Incomplete"
L["DROPS_FILTER_COMPLETE"] = "Complete"
L["DROPS_EMPTY_NO_SOURCES"] = "No drop sources found"
L["DROPS_EMPTY_NO_SOURCES_DESC"] = "Drop data may not be available"
L["DROPS_SELECT_CATEGORY"] = "Select a category"
L["DROPS_EMPTY_NO_RESULTS"] = "No drop sources match your search"

-- Drop source category labels
L["DROPS_CATEGORY_DROP"] = "Drops"
L["DROPS_CATEGORY_ENCOUNTER"] = "Bosses"
L["DROPS_CATEGORY_TREASURE"] = "Treasure"

-- Drop source display
L["DROPS_DECOR_ID"] = "Decor #%d"

--------------------------------------------------------------------------------
-- Professions Tab
--------------------------------------------------------------------------------
L["PROFESSIONS_SEARCH_PLACEHOLDER"] = "Search professions or items..."
L["PROFESSIONS_FILTER_ALL"] = "All"
L["PROFESSIONS_FILTER_INCOMPLETE"] = "Incomplete"
L["PROFESSIONS_FILTER_COMPLETE"] = "Complete"
L["PROFESSIONS_EMPTY_NO_SOURCES"] = "No Crafting Sources"
L["PROFESSIONS_EMPTY_NO_SOURCES_DESC"] = "Crafting source data is not yet available."
L["PROFESSIONS_SELECT_PROFESSION"] = "Select a Profession"
L["PROFESSIONS_EMPTY_NO_RESULTS"] = "No Results"

--------------------------------------------------------------------------------
-- Treasure Hunt Waypoints
--------------------------------------------------------------------------------
L["TREASURE_HUNT_WAYPOINT_SET"] = "Marked treasure at"

--------------------------------------------------------------------------------
-- Progress Tab
--------------------------------------------------------------------------------
L["TAB_PROGRESS"] = "PROGRESS"
L["TAB_PROGRESS_DESC"] = "Collection progress overview"
L["PROGRESS_COLLECTED"] = "Collected"
L["PROGRESS_TOTAL"] = "Total"
L["PROGRESS_REMAINING"] = "Remaining"
L["PROGRESS_BY_SOURCE"] = "By Source"
L["PROGRESS_VENDOR_EXPANSIONS"] = "Vendor Expansions"
L["PROGRESS_QUEST_EXPANSIONS"] = "Quest Expansions"
L["PROGRESS_RENOWN_EXPANSIONS"] = "Renown Expansions"
L["PROGRESS_PROFESSIONS"] = "Professions"
L["PROGRESS_ALMOST_THERE"] = "Most Progressed"
L["PROGRESS_OVERVIEW"] = "PROGRESS OVERVIEW"
L["PROGRESS_ALL_DECOR_COLLECTED"] = "All Decor Collected"
L["PROGRESS_SOURCE_ALL"] = "All Decor"
L["PROGRESS_SOURCE_VENDORS"] = "Vendors"
L["PROGRESS_SOURCE_QUESTS"] = "Quests"
L["PROGRESS_SOURCE_ACHIEVEMENTS"] = "Achievements"
L["PROGRESS_SOURCE_PROFESSIONS"] = "Professions"
L["PROGRESS_SOURCE_PVP"] = "PvP"
L["PROGRESS_SOURCE_DROPS"] = "Drops"
L["PROGRESS_SOURCE_RENOWN"] = "Renown"
L["PROGRESS_LOADING"] = "Loading progress data..."

--------------------------------------------------------------------------------
-- Zone Overlay (World Map)
--------------------------------------------------------------------------------
L["ZONE_OVERLAY_VENDORS"] = "Vendors"
L["ZONE_OVERLAY_QUESTS"] = "Quests"
L["ZONE_OVERLAY_TREASURE"] = "Treasure Hunts"
L["ZONE_OVERLAY_COUNT"] = "%d decor in this zone"
L["ZONE_OVERLAY_BUTTON_TOOLTIP"] = "Housing Codex"
L["ZONE_OVERLAY_SHOW"] = "Show Zone Overlay"
L["ZONE_OVERLAY_PINS"] = "Show Vendor Map Pins"
L["ZONE_OVERLAY_POSITION"] = "Panel Position"
L["ZONE_OVERLAY_POS_TOPLEFT"] = "Top-Left"
L["ZONE_OVERLAY_POS_BOTTOMRIGHT"] = "Bottom-Right"
L["ZONE_OVERLAY_TRANSPARENCY"] = "Transparency"
L["ZONE_OVERLAY_INCLUDE_COLLECTED_VENDORS"] = "Include already unlocked decor"
L["ZONE_OVERLAY_SOURCE_VENDOR"] = "(Vendor)"
L["ZONE_OVERLAY_SOURCE_VENDOR_CITY"] = "(Vendor in |cFFFF8C00%s|r)"
L["ZONE_OVERLAY_CLICK_WAYPOINT"] = "Left-click to set a map pin"
L["ZONE_OVERLAY_CLICK_OPEN_HC"] = "Right-click to open in Housing Codex"
L["ZONE_OVERLAY_PREVIEW_SIZE"] = "Preview Size"
L["ZONE_OVERLAY_SECTION_HEADER"] = "Zone Overlay"
L["ZONE_OVERLAY_COLLAPSED_TOOLTIP"] = "Click to see decor items in this zone"
L["VENDOR_PINS_SECTION_HEADER"] = "Vendor Map Pins"
L["VENDOR_PINS_TRANSPARENCY"] = "Pin Transparency"
L["VENDOR_PINS_SCALE"] = "Pin Size"
-- VENDOR_PINS_LAYER removed: custom frame levels tainted WorldMapFrame (WoWUIBugs #811)
L["OPTIONS_ZONE_OVERLAY"] = "Show Zone Overlay on World Map"
L["OPTIONS_ZONE_OVERLAY_TOOLTIP"] = "Display a panel on the world map showing available decor items for the current zone"

--------------------------------------------------------------------------------
-- What's New Popup
--------------------------------------------------------------------------------
L["WHATSNEW_TITLE"] = "What's New in Housing Codex"
L["WHATSNEW_DONT_SHOW"] = "Don't show this again for v%s"
L["WHATSNEW_EXPLORE"] = "Explore Housing Codex"
L["WHATS_NEW_NO_IMAGE"] = "Screenshot"

--------------------------------------------------------------------------------
-- Welcome Popup
--------------------------------------------------------------------------------
L["WELCOME_TITLE"] = "Welcome to Housing Codex"
L["WELCOME_SUBTITLE"] = "Your companion for decor discovery and all things housing"
L["WELCOME_START"] = "Start Exploring"
L["WELCOME_QUICK_SETUP"] = "Good to Know"
L["WELCOME_OPEN_WITH"] = "You can open the addon at any time via"
L["WELCOME_SET_KEYBIND"] = "or by setting your own keybind in"
L["WELCOME_KEYBIND_LABEL"] = "Options"

--------------------------------------------------------------------------------
-- What's New: v1.5.0 feature highlights
--------------------------------------------------------------------------------
L["WHATSNEW_V150_F1_TITLE"] = "Collection Dashboard"
L["WHATSNEW_V150_F1_DESC"] = "See your decor collection progress at a glance -- overall stats, by source type, and most progressed categories."
L["WHATSNEW_V150_F2_TITLE"] = "Profession Tracking"
L["WHATSNEW_V150_F2_DESC"] = "Track crafting progress for each profession with dedicated progress bars."
L["WHATSNEW_V150_F3_TITLE"] = "Smart Navigation"
L["WHATSNEW_V150_F3_DESC"] = "Click any progress row to jump directly to that source tab."
L["WHATSNEW_V150_F4_TITLE"] = "Clickable Wishlist Links"
L["WHATSNEW_V150_F4_DESC"] = "Share wishlisted items in chat as clickable links that others can preview."

--------------------------------------------------------------------------------
-- Welcome feature highlights
--------------------------------------------------------------------------------
L["WELCOME_F1_TITLE"] = "Interactive 3D Preview"
L["WELCOME_F1_DESC"] = "Preview any decor in 3D: rotate, zoom, and resize the viewer."
L["WELCOME_F2_TITLE"] = "Decor Catalog & Grid"
L["WELCOME_F2_DESC"] = "Browse the full catalog in a customizable grid with fast search and filters."
L["WELCOME_F3_TITLE"] = "Sources & Discovery"
L["WELCOME_F3_DESC"] = "See where to get missing decor: quests, achievements, vendors, drops, professions, renown, and PvP."
L["WELCOME_F4_TITLE"] = "Vendor Indicators"
L["WELCOME_F4_DESC"] = "Vendor UI shows decor icons, so collectibles stand out instantly. Also marks decor in your bags and bank."
L["WELCOME_F5_TITLE"] = "Map Integration"
L["WELCOME_F5_DESC"] = "Map pins show decor vendor locations, and a zone overlay points you to missing decor."
L["WELCOME_F6_TITLE"] = "Collection Progress"
L["WELCOME_F6_DESC"] = "The Progress tab shows your collection status by source and expansion at a glance."

--------------------------------------------------------------------------------
-- Endeavors Panel
--------------------------------------------------------------------------------
L["ENDEAVORS_TITLE"] = "Endeavors"
L["ENDEAVORS_OPTIONS"] = "Endeavor Options"
L["ENDEAVORS_OPTIONS_TOOLTIP"] = "Configure the Endeavors overlay panel"
L["ENDEAVORS_MAX_LEVEL"] = "MAX"
L["ENDEAVORS_PROGRESS_FORMAT"] = "Progress: %d / %d"
L["ENDEAVORS_YOUR_CONTRIBUTION"] = "Your contribution: %d"
L["ENDEAVORS_MILESTONES"] = "Milestones"
L["ENDEAVORS_OPT_SECTION_GENERAL"]  = "General"
L["ENDEAVORS_OPT_SECTION_HOUSE_XP"] = "House XP"
L["ENDEAVORS_OPT_SECTION_ENDEAVOR"] = "Endeavor Progress"
L["ENDEAVORS_OPT_SECTION_SIZE"]     = "Panel Size"
L["ENDEAVORS_OPT_SHOW_HOUSE_XP"] = "Show House XP Bar"
L["ENDEAVORS_OPT_SHOW_HOUSE_XP_TIP"] = "Display the house level and XP progress bar"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR"] = "Show Endeavor Progress Bar"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TIP"] = "Display the neighborhood endeavor progress bar"
L["ENDEAVORS_OPT_SHOW_XP_TEXT"] = "Show XP Bar Text"
L["ENDEAVORS_OPT_SHOW_XP_TEXT_TIP"] = "Display numeric values on the house XP bar"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT"] = "Show Endeavor Bar Text"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT_TIP"] = "Display numeric values on the endeavor progress bar"
L["ENDEAVORS_OPT_SHOW_XP_PCT"] = "Show XP Bar Percentage"
L["ENDEAVORS_OPT_SHOW_XP_PCT_TIP"] = "Display percentage on the house XP bar"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_PCT"] = "Show Endeavor Bar Percentage"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_PCT_TIP"] = "Display percentage on the endeavor progress bar"
L["ENDEAVORS_XP_TOOLTIP_TITLE"] = "House Level Progress"
L["ENDEAVORS_XP_TOOLTIP_LEVEL"] = "House Level: %d"
L["ENDEAVORS_XP_TOOLTIP_LEVEL_MAX"] = "House Level: %d (Max)"
L["ENDEAVORS_XP_TOOLTIP_PROGRESS"] = "XP: %s / %s (%d%%)"
L["ENDEAVORS_XP_TOOLTIP_CLICK"] = "Click to open Housing Dashboard"
L["ENDEAVORS_TOOLTIP_CLICK"] = "Click to open Endeavors"
L["ENDEAVORS_PCT_DONE"] = "DONE"
L["OPTIONS_SECTION_ENDEAVORS"] = "Endeavors"
L["OPTIONS_ENDEAVORS_ENABLED"] = "Enable Endeavors Panel"
L["OPTIONS_ENDEAVORS_ENABLED_TOOLTIP"] = "Show the Endeavors mini-panel when in a neighborhood with a house"
L["ENDEAVORS_OPT_ENABLED"] = "Enable Endeavors Panel"
L["ENDEAVORS_OPT_ENABLED_TIP"] = "Show the Endeavors panel when in a neighborhood with a house"
L["ENDEAVORS_COMPLETED_TIMES"] = "Completed %d |4time:times;"
L["ENDEAVORS_TIME_DAYS_LEFT"] = "%d |4day:days; left"
L["ENDEAVORS_TIME_HOURS_LEFT"] = "%d |4hour:hours; left"
L["ENDEAVORS_COUPONS_EARNED"] = "%s: %d/%d"
L["ENDEAVORS_OPT_SCALE"] = "Panel Size"
L["ENDEAVORS_OPT_SCALE_TIP"] = "Change the size of the Endeavors panel"
L["ENDEAVORS_OPT_SCALE_SMALL"] = "Small"
L["ENDEAVORS_OPT_SCALE_NORMAL"] = "Normal"
L["ENDEAVORS_OPT_SCALE_BIG"] = "Big"
L["ENDEAVORS_MILESTONE_COMPLETED"] = "completed"

--------------------------------------------------------------------------------
-- PvP Tab
--------------------------------------------------------------------------------
L["TAB_PVP"] = "PVP"
L["TAB_PVP_DESC"] = "PvP sources for housing items"
L["PVP_SEARCH_PLACEHOLDER"] = "Search PvP sources or items..."
L["PVP_FILTER_ALL"] = "All"
L["PVP_FILTER_INCOMPLETE"] = "Incomplete"
L["PVP_FILTER_COMPLETE"] = "Complete"
L["PVP_CATEGORY_ACHIEVEMENTS"] = "Achievements"
L["PVP_CATEGORY_VENDORS"] = "Vendors"
L["PVP_CATEGORY_DROPS"] = "Drops"
L["PVP_EMPTY_NO_SOURCES"] = "No PvP sources found"
L["PVP_EMPTY_NO_SOURCES_DESC"] = "PvP data may not be available"
L["PVP_SELECT_CATEGORY"] = "Select a category"
L["PVP_EMPTY_NO_RESULTS"] = "No PvP sources match your search"
L["SETTINGS_CATEGORY_NAME"] = "Housing |cffFB7104Codex|r"

--------------------------------------------------------------------------------
-- Renown Tab
--------------------------------------------------------------------------------
L["TAB_RENOWN"] = "RENOWN"
L["TAB_RENOWN_DESC"] = "Reputation sources for housing decor"
L["RENOWN_SEARCH_PLACEHOLDER"] = "Search factions..."
L["RENOWN_FILTER_ALL"] = "All"
L["RENOWN_FILTER_INCOMPLETE"] = "Incomplete"
L["RENOWN_FILTER_COMPLETE"] = "Complete"
L["RENOWN_LOCKED"] = "Not yet unlocked"
L["RENOWN_REQUIRED"] = "Requires %s"
L["RENOWN_REP_MET"] = "Reputation met"
L["RENOWN_CURRENTLY_AT"] = "currently at: "
L["RENOWN_NEEDS_ALLIANCE"] = "Requires an Alliance character"
L["RENOWN_NEEDS_HORDE"] = "Requires a Horde character"
L["RENOWN_WAYPOINT_VENDOR"] = "%s (%s)"
L["RENOWN_PROGRESS_FORMAT"] = "%d/%d"
L["RENOWN_RANK_FORMAT"] = "Rank %d"
L["RENOWN_SELECT_EXPANSION"] = "Select an expansion"
L["RENOWN_EMPTY_NO_RESULTS"] = "No factions match your filters"
L["RENOWN_EMPTY_NO_DATA"] = "Reputation data is loading..."

--------------------------------------------------------------------------------
-- Game Entity Names (drop sources, encounter names, treasure locations)
-- Translators: copy this block to your locale file, change the values.
-- These names appear in the Drops tab and PvP tab source lists.
--------------------------------------------------------------------------------
local SN = addon.sourceNameLocale

-- Drops
SN["Darkshore (BfA phase) Rare Drop"] = "Darkshore (BfA phase) Rare Drop"
SN["Highmountain Tauren Paragon Chest"] = "Highmountain Tauren Paragon Chest"
SN["Login Reward (Midnight)"] = "Login Reward (Midnight)"
SN["Midnight Delves"] = "Midnight Delves"
SN["Self-Assembling Homeware Kit (Mechagon)"] = "Self-Assembling Homeware Kit (Mechagon)"
SN["Shadowmoon Valley (Draenor) Missives"] = "Shadowmoon Valley (Draenor) Missives"
SN["Strange Recycling Requisition (Mechagon)"] = "Strange Recycling Requisition (Mechagon)"
SN["Theater Troupe event chest (Isle of Dorn)"] = "Theater Troupe event chest (Isle of Dorn)"
SN["Twitch Drop"] = "Twitch Drop"
SN["Twitch drop (Feb 26 to Mar 24)"] = "Twitch drop (Feb 26 to Mar 24)"
SN["Undermine Jobs"] = "Undermine Jobs"
SN["Zillow & Warcraft collab"] = "Zillow & Warcraft collab"
SN["Zillow for Warcraft Promotion"] = "Zillow for Warcraft Promotion"

-- Encounters (bosses)
SN["Advisor Melandrus (Court of Stars)"] = "Advisor Melandrus (Court of Stars)"
SN["Belo'ren, Child of Al'ar"] = "Belo'ren, Child of Al'ar"
SN["Charonus (Voidscar Arena)"] = "Charonus (Voidscar Arena)"
SN["Chimaerus the Undreamt God"] = "Chimaerus the Undreamt God"
SN["Crown of the Cosmos (The Voidspire)"] = "Crown of the Cosmos (The Voidspire)"
SN["Dargrul the Underking"] = "Dargrul the Underking"
SN["Degentrius (Magisters' Terrace)"] = "Degentrius (Magisters' Terrace)"
SN["Echo of Doragosa (Algeth'ar Academy)"] = "Echo of Doragosa (Algeth'ar Academy)"
SN["Emperor Dagran Thaurissan (Blackrock Depths)"] = "Emperor Dagran Thaurissan (Blackrock Depths)"
SN["Fallen-King Salhadaar (The Voidspire)"] = "Fallen-King Salhadaar (The Voidspire)"
SN["Garrosh Hellscream (Siege of Orgrimmar)"] = "Garrosh Hellscream (Siege of Orgrimmar)"
SN["Goldie Baronbottom (Cinderbrew Meadery)"] = "Goldie Baronbottom (Cinderbrew Meadery)"
SN["Harlan Sweete (Freehold)"] = "Harlan Sweete (Freehold)"
SN["High Sage Viryx (Skyreach)"] = "High Sage Viryx (Skyreach)"
SN["Imperator Averzian (The Voidspire)"] = "Imperator Averzian (The Voidspire)"
SN["King Mechagon"] = "King Mechagon"
SN["Kyrakka and Erkhart Stormvein"] = "Kyrakka and Erkhart Stormvein"
SN["L'ura (The Seat of the Triumvirate)"] = "L'ura (The Seat of the Triumvirate)"
SN["Lightblinded Vanguard"] = "Lightblinded Vanguard"
SN["Lithiel Cinderfury (Murder Row)"] = "Lithiel Cinderfury (Murder Row)"
SN["Lord Godfrey (Shadowfang Keep)"] = "Lord Godfrey (Shadowfang Keep)"
SN["Lothraxion (Nexus-Point Xenas)"] = "Lothraxion (Nexus-Point Xenas)"
SN["Midnight Falls (March on Quel'Danas)"] = "Midnight Falls (March on Quel'Danas)"
SN["Nalorakk"] = "Nalorakk"
SN["Prioress Murrpray (Priory of the Sacred Flame)"] = "Prioress Murrpray (Priory of the Sacred Flame)"
SN["Rak'tul, Vessel of Souls"] = "Rak'tul, Vessel of Souls"
SN["Scourgelord Tyrannus (Pit of Saron)"] = "Scourgelord Tyrannus (Pit of Saron)"
SN["Sha of Doubt (Temple of the Jade Serpent)"] = "Sha of Doubt (Temple of the Jade Serpent)"
SN["Shade of Xavius (Darkheart Thicket)"] = "Shade of Xavius (Darkheart Thicket)"
SN["Skulloc (Iron Docks)"] = "Skulloc (Iron Docks)"
SN["Spellblade Aluriel (The Nighthold)"] = "Spellblade Aluriel (The Nighthold)"
SN["Teron'gor"] = "Teron'gor"
SN["The Darkness"] = "The Darkness"
SN["The Restless Cabal"] = "The Restless Cabal"
SN["The Restless Heart"] = "The Restless Heart"
SN["Vaelgor & Ezzorak"] = "Vaelgor & Ezzorak"
SN["Vanessa VanCleef"] = "Vanessa VanCleef"
SN["Viz'aduum the Watcher (Karazhan)"] = "Viz'aduum the Watcher (Karazhan)"
SN["Vol'zith the Whisperer (Shrine of the Storm)"] = "Vol'zith the Whisperer (Shrine of the Storm)"
SN["Vorasius (The Voidspire)"] = "Vorasius (The Voidspire)"
SN["Warlord Sargha (Neltharus)"] = "Warlord Sargha (Neltharus)"
SN["Warlord Zaela"] = "Warlord Zaela"
SN["Ziekket (The Blinding Vale)"] = "Ziekket (The Blinding Vale)"

-- Treasures
SN["Gift of the Phoenix (Eversong Woods)"] = "Gift of the Phoenix (Eversong Woods)"
SN["Golden Cloud Serpent Treasure Chest (Jade Forest)"] = "Golden Cloud Serpent Treasure Chest (Jade Forest)"
SN["Incomplete Book of Sonnets (Eversong Woods)"] = "Incomplete Book of Sonnets (Eversong Woods)"
SN["Malignant Chest (Voidstorm)"] = "Malignant Chest (Voidstorm)"
SN["Stellar Stash (Slayer's Rise)"] = "Stellar Stash (Slayer's Rise)"
SN["Stone Vat (Eversong Woods)"] = "Stone Vat (Eversong Woods)"
SN["Triple-Locked Safebox (Eversong Woods)"] = "Triple-Locked Safebox (Eversong Woods)"
SN["Undermine"] = "Undermine"
SN["World Glimmering Treasure Chest Drop"] = "World Glimmering Treasure Chest Drop"

-- Keybinding globals (deferred from Init.lua — WoW resolves these lazily when Keybindings UI opens)
BINDING_HEADER_HCODEX = L["KEYBIND_HEADER"]
BINDING_NAME_HOUSINGCODEX_TOGGLE = L["KEYBIND_TOGGLE"]
