# Changelog

All notable changes to Housing Codex.

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
