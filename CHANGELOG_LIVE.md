# Changelog

All notable changes to Housing Codex.

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
