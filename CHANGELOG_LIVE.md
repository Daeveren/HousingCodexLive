# Changelog

All notable changes to Housing Codex.

## [1.7.10] - 2026-03-03

### Added
- Endeavor task tooltips — hover a task row to see the task name, how many times you've completed it, and what rewards it gives
- Endeavor bar tooltip now shows how much time is left until the current endeavor ends
- Endeavor bar tooltip now shows your current community coupons

## [1.7.9] - 2026-03-03

### Fixed
- URL popup now closes with the ESC key
- `/hc retry` now properly refreshes all data indexes

### Changed
- Codebase improvements in order to make the addon run more smooth

## [1.7.8] - 2026-03-01

### Added
- Vendor Tooltip Overlay — hovering over an NPC vendor that sells housing decor now shows your collection progress and uncollected item names directly in the tooltip (toggle in Settings)

### Changed
- Locale cleanup

## [1.7.7] - 2026-03-01

### Added
- Midnight decor vendor updates

### Changed
- Main UI tab tweaks

## [1.7.6] - 2026-03-01

### Changed
- Endeavors panel now shows in any neighborhood you visit (no longer requires owning a house there)

### Fixed
- Drops tab now correctly shows owned status for some items that were previously appearing as uncollected
- Item selection in Vendors and Drops tabs no longer highlights the wrong row when the same decor appears under multiple sources
- Quest zone toggle no longer requires two clicks to collapse on first use
- Search clear button no longer briefly re-applies the old search text after clearing
- Re-enabling the Endeavors panel in settings now correctly checks if you're in a neighborhood
- Stability and performance improvements

## [1.7.5] - 2026-02-28

### Fixed
- Improved item display in the zone overlay
- Removed a non-existent item from the Drops tab
- Endeavors panel now detects task progress in real-time while in your neighborhood
- Items that temporarily fail to load no longer get permanently stuck as missing
- Performance improvements across search, animations, quest loading, and map pins

## [1.7.4] - 2026-02-28

### Fixed
- Promotional vendors (Dennia, Gabbi, Tuuran) no longer show inflated item counts — inventories now match what they actually sell in-game
- Improved vendor overlay checkmark reliability when opening a vendor
- Quest names in the Quests tab now load more reliably

## [1.7.3] - 2026-02-28

### Added
- Class hall vendor tooltips and labels now show class-specific colors

### Changed
- Updated item database with new vendor items and improved vendor location coverage

### Fixed
- Midnight zone vendors now appear correctly on the map and in the zone overlay
- Stability improvements

## [1.7.2] - 2026-02-27

### Added
- New quest and achievement sources added to the item database

### Fixed
- Fixed a memory leak that occurred each time the welcome screen was opened
- Waypoint sound and chat message no longer play when the waypoint fails to set
- Endeavors panel no longer errors when you don't have a house

## [1.7.1] - 2026-02-27

### Added
- TomTom waypoint support - enable in Settings to use TomTom for all waypoints instead of the native map pin (requires TomTom addon)
- Keybind conflict detection - when setting a keybind already used by another action, a confirmation dialog lets you choose to reassign it
- PvP source progress now shows in the Progress tab alongside other source types
- Responsive tabs - tabs now adapt to window width - labels shorten or switch to icon-only when the window is narrow

### Changed
- Login chat message now shows your overall collection percentage instead of just item count
- Updated item database with corrected sources and new data

### Fixed
- Fixed PvP tab items highlighting incorrectly when different vendors share the same decor items
- Fixed PvP tab not showing an empty state message when search filters out all results
- Codebase improvements for smoother performance

## [1.7.0] - 2026-02-26

### Added
- NEW - PvP tab - see all housing items obtainable through PvP in one place
  - Browse by source type: Achievements, Vendors, and Arena Drops
  - Search across PvP sources and items

## [1.6.1] - 2026-02-26

### Changed
- Updated item database with corrected vendor and drop sources

### Fixed
- Various improvements for vendor map pins and quest tracking
- Codebase improvements for smoother performance

## [1.6.0] - 2026-02-25

### Added
- NEW - Endeavors panel - a compact progress tracker that appears while in your neighborhood
  - Includes two progress bars: one for House Level XP and one for the Endeavor progress
  - Community Endeavor initiative progress bar with milestone tracking
  - Shows the recently progressed endeavor tasks (up to max 3 visible)
  - Hover progress bars to see detailed stats, milestones, and your contribution
  - Click progress bars to open the Housing Dashboard directly
  - Optional percentage display on progress bars (toggle in settings)
  - Auto-minimizes after 2 minutes of inactivity; auto-expands when new tasks appear
  - The Endeavors panel can be disabled from the Housing Codex settings

## [1.5.4] - 2026-02-25

### Added
- Junkyard Tinkering profession added to the Professions tab with 6 new craftable decor items

### Changed
- Midnight expansion drops are now always shown (removed the toggle from Settings)

## [1.5.3] - 2026-02-24

### Added
- German language support for the addon category label in the AddOns list

### Changed
- Progress tab now refreshes when reopening the addon, so collection changes are reflected immediately
- For feature discoverability purposes, the welcome screen will be shown to the existing users, once (previously it was only for fresh installs)

### Fixed
- Fixed keybind capture failing silently when attempted during combat
- Fixed old keybinds sometimes persisting after rebinding the addon shortcut

## [1.5.2] - 2026-02-24

### Added
- Redesigned the welcome screen with a visual card grid showcasing main features of Housing Codex
- Welcome screen now automatically shows once for fresh installs
- Welcome screen can now be moved by dragging the header

### Fixed
- Added protection for the Welcome screen so it won't fail when the player is in combat

## [1.5.1] - 2026-02-23

### Added
- Hovering sort options drop-down menu in the Decor tab now shows a description of what each sort does
- New "Qty Placed" sort option to sort by how many copies you've placed in your house
- New "Reset Window Size" button in Settings > Troubleshooting to restore the default window size

### Changed
- Settings page tweaks
- Wider search boxes across all tabs so that 'search hint text' is easier to read

### Fixed
- Fixed search placeholder text (e.g., "Search achievements, rewards, or categories...") overflowing outside the search box on narrow windows

## [1.5.0] - 2026-02-22

### Added
- NEW - Progress tab showing your overall collection status at a glance
  - See your total collected percentage with a progress bar
  - Breakdown by source: Vendors, Quests, Achievements, Drops, Professions
  - Per-profession crafting progress
  - Vendor and Quest progress by expansion
  - "Most Progressed" section highlighting what you're closest to completing
  - Click any row to jump directly to that tab
  - Updates in real-time as you collect items

### Fixed
- Fixed a 3D preview crash that could happen after rotating a model for a while
- Riica vendor now shows all items for sale
- Fixed quests showing under "Unknown Zone" — now correctly placed under their expansion and zone
- Fixed some vendors appearing under "Unknown" instead of their correct zone

## [1.4.4] - 2026-02-21

### Added
- Wishlist chat messages now show clickable item links - hover to preview, click to interact
- Professions tab remembers your last selected profession between sessions

### Changed
- Settings panel reorganized into clear groups (Display, Map & Navigation, Merchant, Content) with a cleaner layout

### Fixed
- Fixed a 3D preview error in the wishlist window

## [1.4.3] - 2026-02-20

### Added
- Vendor map pin tooltips now show "(locked)" next to items that need a prerequisite before you can buy them

### Fixed
- Vendor map pins now show the correct collection progress (some owned items were incorrectly shown as missing)
- Vendors in multiple cities (Alliance/Horde variants) now show up correctly with faction tags on the map

## [1.4.2] - 2026-02-19

### Changed
- Decor vendors in cities now show the city name in the zone overlay tooltip (ie: "Vendor in Stormwind")

### Fixed
- Decor vendors in cities now correctly appear in the parent zone's overlay

## [1.4.1] - 2026-02-18

### Added
- Auto-rotate is no longer exclusive to the tooltips, has now been added to the main and Wishlist UI too
- New toggle in Settings to turn auto-rotate on/off
- Wishlist UI 3D preview now supports full rotation and panning (matching the main preview)
- Zone overlay now includes housing decor from cities within a parent zone

### Fixed
- Codebase improvements for smoother performance

## [1.4.0] - 2026-02-16

### Added
- NEW - Zone Overlay on the world map - see uncollected housing decor in the current zone
  - Expand the overlay to see the list of uncollected decor in the zone
  - See vendor name, set waypoints, show the 3D item preview
  - New Housing Codex button on the world map with settings: overlay toggle, position, transparency, preview size
- "Include already unlocked decor vendors" toggle in the world map dropdown - shows collected vendor items dimmed

### Changed
- Multi-level maps like Dalaran now correctly show housing data

### Fixed
- Vendors in sub-zones (e.g., City of Threads in Azj-Kahet) now appear in the parent zone's overlay

## [1.3.4] - 2026-02-15

### Changed
- Updated item database with newly discovered decor items (quests, achievements, crafting, drops)

### Fixed
- Codebase improvements for smoother performance

## [1.3.3] - 2026-02-14

### Added
- Vendor tracking chat messages now include a clickable map link

### Changed
- Updated for WoW 12.0.1 compatibility

### Fixed
- Fixed a rare crash that could occur when placing or picking up certain decor items
- Codebase improvements for smoother performance

## [1.3.2] - 2026-02-10

### Changed
- Green checkmarks at vendors now appear instantly instead of loading in with a delay

### Fixed
- Corrected map pin locations for 4 daily treasure hunt quests

## [1.3.1] - 2026-02-10

### Added
- Right-click drag to pan in the 3D preview panel
- Minimap broker text is now configurable - Alt-click the minimap icon to choose which stats to display (Unique Collected, Total Owned, Total Items)
- Collection stats tooltip - hover the result count in bottom left in the Decor tab to see a quick summary of your collection
- You can now zoom-in even more in the 3D preview

## [1.3.0] - 2026-02-08

### Added
- NEW - Professions tab - browse crafted housing items
  - See which professions can craft housing decor items
  - Collection progress per profession
  - Search across professions and crafted items
  - Filter by completion status

## [1.2.2] - 2026-02-08

### Added
- Unlocked vertical rotation in 3D preview - drag to rotate in any direction (previously horizontal only)

## [1.2.1] - 2026-02-08

### Changed
- Shift-clicking items in the Vendors tab now places a map pin on the vendor instead of tracking the item
- Chat messages when tracking/untracking a vendor now show the vendor name and zone

## [1.2.0] - 2026-02-07

### Added
- NEW feature - Decor vendors shown on map
  - See where housing vendors are on the map
  - Shows both in zone maps and continent maps
  - Hover a pin to see collection progress and which items you're missing
  - Click a pin to set a waypoint to the vendor
  - Toggle on/off in addon settings

## [1.1.0] - 2026-02-07

### Added
- NEW Drops tab - find decor that drops from mobs, bosses or is found in treasure chests
  - Option to show upcoming Midnight expansion drops (off by default)
- Search vendors by currency name (ie: "resonance crystals")

### Fixed
- Minor fixes and UI tweaks

## [1.0.0] - 2026-02-06

### Added
- Automatically adding a map pin for the daily treasure hunt secret quest. Enabled by default, can be disabled in addon options

### Fixed
- Minor fixes and UI tweaks

## [0.9.0] - 2026-02-05

### Added
- NEW Vendors tab - browse housing items by vendor source
  - View vendors organized by expansion and zone
  - See all decor items each vendor sells
  - Set waypoints to vendor locations
  - Alliance/Horde faction indicators for faction specific vendors
  - Search across vendors, zones, and decor items

## [0.8.10] - 2026-02-03

### Added
- New "Reset Window Position" button in addon settings to reset the window to the center of the screen
- New `/hc reset` slash command for the same purpose

### Changed
- If the window was dragged off-screen, after a relog or reloadui it will be moved onscreen

### Fixed
- Improved checks for the green checkmarks at the vendor screen

## [0.8.9] - 2026-02-02

### Fixed
- The currency tooltip now actually works

## [0.8.8] - 2026-02-02

### Added
- Currency tooltips for vendor items - hover the currency icon to see more details

### Fixed
- Reduced memory usage

## [0.8.7] - 2026-02-01

### Added
- Right-click context menu on all item lists
  - Add or remove items from wishlist
  - Track items on the map (if trackable)
  - Link items to chat
  - Copy Wowhead link to clipboard

### Fixed
- Reduced memory usage and improved performance

## [0.8.6] - 2026-01-31

### Changed
- Changed the way window resizing works
- Disabled screen clamp, now the window resize is more smooth and consistent

### Fixed
- Codebase improvements in order to make the addon run more smooth

## [0.8.5] - 2026-01-31

### Changed
- Adjusted preview panel width presets (Small: 300px, Medium: 500px, Large: 700px)
- Decor details panel in the preview section now adapts to panel width (two rows when narrow, one row when wide)

### Fixed
- Several code improvements to make the addon use less resources

## [0.8.4] - 2026-01-31

### Changed
- UI is more responsive
- Window size can be made smaller
- Toolbar elements hide progressively when window is narrow
- Several code improvements

## [0.8.3] - 2026-01-30

### Added
- NEW feature! Vendor decor indicators - Housing Codex icon appears on vendor item buttons for housing decor items
- Green checkmark on vendor items you already own
- Two new settings to control vendor indicators independently

## [0.8.2] - 2026-01-30

### Fixed
- Bug fixes and UI tweaks

## [0.8.1] - 2026-01-30

### Fixed
- Achievement categories now correctly match in-game achievement panel

### Changed
- UI and font size tweaks for better readability

## [0.8.0] - 2026-01-30

### Added
- Achievements tab - browse housing items by achievement source
  - Category navigation (Class Hall, Delves, PvP, Quests, Professions, etc.)
  - Completion percentage display per category
  - Achievement tooltips with real-time criteria progress
  - Shift-click to track achievements in objective tracker
  - Right-click to copy Wowhead link
- Quest completion percentages on expansion buttons
- Quest tooltips showing objectives and progress
- Right-click on quests to copy Wowhead link

## [0.7.0] - 2026-01-29

### Added
- Standalone wishlist window - view all wishlisted items in a dedicated UI
  - Grid display with 3D preview panel
  - Hover to preview, click to lock selection

## [0.6.0] - 2026-01-29

### Added
- New Quests tab - browse housing items by quest source
  - Quest completion tracking (account-wide)
  - Collection progress at expansion, zone, and quest levels
  - Search and filter by completion status
  - Reward preview for each quest
- Midnight expansion initial support

### Fixed
- Search results more accurate

## [0.5.3] - 2026-01-28

### Added
- Minimap button
- Search now finds items by source and description (zone, vendor, quest, etc.)

### Fixed
- Various bug fixes

## [0.5.2] - 2026-01-26

### Changed
- Minor UI polish and bug fixes

## [0.5.1] - 2026-01-26

### Fixed
- Fixed collected items incorrectly showing as "Uncollected" when the same item exists from multiple sources

## [0.5.0] - 2026-01-26

### Added
- Browsable grid of all housing decorations with adjustable tile sizes
- 3D preview panel with model display, item details, source info, and category
- Search box with instant filtering across all items
- Category navigation sidebar with drill-down to subcategories
- Collection filters (Collected / Uncollected toggle)
- Tag filters dropdown (Size, Style, Expansion, Indoor/Outdoor, Dyeable, and more)
- Trackable filter to find items you can track on the map
- Wishlist system - star items and filter to show only wishlisted
- Track button to add items to WoW's native map objectives
- Link button to share items in chat (left-click) or copy Wowhead URL (right-click)
- Sort options: Newest, A-Z, Size, Quantity Owned
- Quantity owned display on grid tiles
- Mouse wheel zoom in preview panel
- Preview width presets (3 sizes)
- Settings panel with custom font toggle, quantity display toggle, and keybind
- Minimap button via LibDataBroker (shows collected/total count)
- Keybind support via WoW Key Bindings menu
- Slash commands: `/hc`, `/hcodex`, `/housingcodex`
