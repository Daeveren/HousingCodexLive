**Changelog**

All notable changes to Housing Codex.

**2.2.0** (2026-04-05)

**Added**
- New button in the Wishlist window to navigate back to the main Housing Codex window
- Progress tab "Most Progressed" section now covers all source types (achievements, drops, PvP, professions)
- Reworked collection counting — decor and rooms are now tracked and displayed separately in the minimap and broker button tooltip
- Added the housing rooms unlocked in the minimap button or broker button tooltip
- Added missing drop sources for a couple of items

**Fixed**
- Improved localized vendor search and zone names for non-English clients

**2.1.4** (2026-04-04)

**Changed**
- Improvements to make the addon load faster at startup

**Fixed**
- Improved world map overlay stability
- Improved layering of the map overlay and world map button
- Hidden a vendor that is not yet active in-game and was showing up in vendor lists
- Improvements to the Drops tab, added missing source info for several dropped items

**2.1.3** (2026-04-03)

**Fixed**
- Zone overlay items now appear immediately
- World map button no longer overlaps other windows dragged over the map

**2.1.2** (2026-04-02)

**Added**
- Reenabled the minimap button toggle in settings, inadvertently removed in a previous update

**Fixed**
- Changing a keybind in addon settings no longer erases a secondary binding set via WoW's Keybindings UI
- Improved usability of the broker config popup when near screen edges
- Improved profession expansion and skill details for some Professions tab items

**2.1.1** (2026-04-01)

**Added**
- Updated Kalimdor decor vendor data

**Fixed**
- Improved reliability of green checkmarks at vendor and bag/bank screens
- Fixed duplicate vendor entries caused by inconsistent zone naming

**2.1.0** (2026-03-30)

**Added**
- Hovering the minimap button or addon compartment now shows your decor collection stats (unique collected, total owned, total items)

**Changed**
- Addon settings panel has a cleaner layout with improved section headers and spacing
- Improvements to "Reset Window Position" and "Reset Window Size" logic
- Keybind display now shows both bindings when two keys are set (e.g., "Ctrl-H / F6")

**Fixed**
- Fixed a duplicate addon compartment entry that could appear after certain settings changes
- Keybind capture is now blocked during combat, matching the existing unbind behavior

**2.0.17** (2026-03-29)

**Changed**
- Data broker addons (Titan Panel, Chocolate Bar, etc.) now display the Housing Codex item count instead of just an icon
- Updated Midnight and Dragon Isles decor vendor data for accuracy

**Fixed**
- Minimap button left-click and alt-click now work during combat
- Vendor tab no longer snaps back to a hidden item in the preview after searching or filtering
- Zone headers in the Vendors tab now show the correct +/- indicator when searching or filtering
- Collapsing and expanding zones in the Vendors tab is now remembered when switching within the same expansion
- Class-specific vendor zone labels now show the correct class for vendors that appear in multiple zones
- Waypoint pins for multi-location vendors now prefer the location matching the zone you clicked
- Dragon Isles vendors that appear in multiple zones now show their full zone description instead of just one zone

**2.0.16** (2026-03-27)

**Fixed**
- Fixed another world map error that could occur when hovering quest objectives, event icons, and other map pins (continued fix for WoW UI Bug #811)

**2.0.15** (2026-03-27)

**Fixed**
- Vendor category labels (Accents, Furnishings, Lighting, etc.) now display in your game language for non-English game clients
- Removed an item incorrectly listed under Void Researcher Aemely — the Ornate Void Elf Banner is only sold by Anomander

**2.0.14** (2026-03-26)

**Changed**
- Currency names in vendor search now match your game language instead of always showing English
- Zone names and profession names in quest lists now display more accurately in non-English languages

**Fixed**
- Improved how the green checkmarks are applied at vendor and bag/bank screens
- Added a missing German translation for the quest "Sky's Hope"

**2.0.13** (2026-03-25)

**Fixed**
- Vendor waypoints no longer accidentally remove map pins you placed yourself
- Quests available in multiple zones now appear under all applicable zones in the world map overlay
- Vendor tab now remembers which zones you had expanded when switching between tabs
- Fixed world map button positioning and size after the recent map stability update

**2.0.12** (2026-03-24)

**Changed**
- Rewrote a large part of the addon's world map and tooltip code to work around WoW UI Bug #811, a bug on Blizzard's side that caused crashes when addons interact with the world map
- Removed the "Adjust Map Pin Layer" setting from the world map button — vendor pins now always appear at a fixed layer
- Removed the vendor NPC tooltip animation to improve world map stability

**Fixed**
- Fixed rare crashes that could occur when hovering quest objectives, event icons, and other map pins on the world map

**2.0.11** (2026-03-23)

**Fixed**
- Quests available in multiple zones now correctly appear under all applicable zones instead of only one
- Re-clicking the same expansion in the Quests tab no longer resets your collapsed zones
- Fixed a crash that could occur when using the zone overlay on the world map
- Changing tile size or resizing the window is now smoother

**2.0.10** (2026-03-22)

**Added**
- Renown sources now appear in the Progress tab — see your renown collection progress alongside other sources, and click to jump to the Renown tab

**Changed**
- "Merchant" section in Settings renamed to "Vendor" for consistency

**Fixed**
- Fixed a crash that could occur when hovering certain map icons after using vendor tooltips
- Fixed Settings showing TomTom as "Not Installed" even when the addon was loaded
- Fixed Welcome Screen button in Settings being permanently disabled
- Fixed preview panel layout not updating properly when changing the preview width
- Fixed some items from Achievements and Quests not showing full details in the 3D preview
- Fixed vendor progress in the Progress tab double-counting items sold by multiple vendors in the same expansion
- Fixed a potential crash on login if saved data was corrupted
- Old unused settings are now automatically cleaned up

**2.0.9** (2026-03-22)

**Changed**
- Tabs now shrink their labels smoothly when the window gets narrow, instead of jumping straight to icon-only mode
- Tweaked inactive tab styling so the active tab is easier to notice

**Fixed**
- Clicking "Junkyard Tinkering" in the Progress tab no longer tries to open the Professions tab
- Drops tab now shows a "no results" message when search or filters remove all sources
- Shift-click tracking state now updates reliably when track limits change
- Tab filter settings no longer silently blank a tab if saved data was corrupted
- Drop and PvP source lists now sort correctly in non-English languages

**2.0.8** (2026-03-21)

**Added**
- New task names in the Endeavors panel now play a subtle typewriter animation when they first appear

**Fixed**
- Clicking a source row in the Progress tab now correctly shows all items in the destination tab
- Professions tab now remembers your selected craft when switching between tabs
- Profession names in the Progress tab now display in your game language

**2.0.7** (2026-03-20)

**Added**
- Adjusted the Welcome panel with animated text effects

**Changed**
- Updated Welcome screen descriptions to highlight recent features (renown, PvP, bags, Progress tab)
- Item tooltips now appear near your cursor instead of off to the side

**Fixed**
- Vendor NPC names that initially failed to load now retry automatically instead of staying blank

**2.0.6** (2026-03-20)

**Added**
- More objects and categories in the Decor tab browser (Rooms, doors, windows, exterior items, and other previously hidden categories)

**Changed**
- "Reset Filters" button now also clears the selected category

**Fixed**
- Improved localization for Renown tab standing labels and level text on non-English clients
- Added missing German, French, and Chinese translations for the Renown tab and other recent features
- Codebase improvements in order to make the addon run smoother

**2.0.5** (2026-03-20)

**Added**
- Vendor NPC tooltips now play a subtle animation when the vendor has uncollected decor items

**Changed**
- Adjusted how locked items are displayed in vendor tooltips and map pins to make them more visible

**Fixed**
- Fixed Renown tab showing inflated progress when vendors are shared between factions
- Renown tab standing requirements and faction names now display in your game language
- Fixed Renown level requirements not working correctly on non-English clients
- Renown tab search now matches both English and localized names
- Improved the decor counting algorithm to be more resilient and accurate
- Fixed Progress tab sometimes showing stale data after collecting items

**2.0.4** (2026-03-19)

**Fixed**
- Fixed Renown tab showing 0/0 progress if opened before housing data finished loading
- Fixed search sometimes matching a faction but showing an empty card with no items
- Renown tab now correctly shows "No factions match your filters" when all results are filtered out
- Renown level labels now display in your game language instead of English-only

**2.0.3** (2026-03-19)

**Added**
- Right-click a faction card in the Renown tab to set a waypoint to its vendor

**Fixed**
- Fixed world map errors that could occur when hovering certain map icons
- Fixed some items missing from the addon's total item count and progress tracking
- Fixed vendor zone progress showing inflated item counts in the Progress tab
- Fixed PvP progress bar not appearing in the Progress tab
- Clicking a source row in the Progress tab now properly filters the destination tab

**2.0.2** (2026-03-18)

**Added**
- 5 new Midnight standard factions in the Renown tab (The Magisters, Blood Knights, Farstriders, Shades of the Row, Slayer's Duellum)
- Additional reputation vendors for Nightfallen and Honorbound factions

**Fixed**
- Renown tab no longer double-counts items shared between factions in expansion progress totals
- Fixed reputation progress bars showing incorrect values for some factions
- Keybind capture mode no longer gets stuck if the Settings panel is closed while setting a keybind
- Wishlist 3D preview no longer resets camera angle when collecting unrelated items

**2.0.1** (2026-03-18)

**Fixed**
- Fixed Quests and Achievements tabs showing empty if opened before housing data finished loading
- Removed a phantom vendor and items that showed with "?" icons in the Vendors tab
- Fixed friendship factions (Tillers, Brawlers) in the Renown tab showing wrong progress and permanently unmet unlock requirements
- Renown tab reputation tracking fixes
- Fixed newly unlocked major factions staying shown as "Locked" in the Renown tab
- Fixed some decor items showing "?" icons instead of their category icon in the Renown tab and other lists

**2.0.0** (2026-03-17)

**Added**
- NEW - Renown tab — browse reputation-gated housing decor across all expansions
  - See which factions sell housing items and what reputation level you need
  - Per-item reputation markers for items you haven't unlocked yet
  - Alliance/Horde faction indicators
  - Search across factions and items, filter by completion status

**Changed**
- More Midnight decor item vendor updates
- Updated some Midnight achievements
- Vendor zones now auto-expand when searching, showing matching vendors immediately
- Localization improvements for quest search

**1.9.15** (2026-03-16)

**Changed**
- Improved keybinding text for clarity in the Options keybindings UI

**Fixed**
- Fixed map tooltips causing errors when hovering vendor pins, zone overlay items, and the world map button in certain UI states
- Fixed some decor items shown as "?" in the map overlay list

**1.9.14** (2026-03-15)

**Added**
- New "Current Zone" checkbox in the Vendors tab — check it to see only vendors in the zone you're currently in

**Changed**
- Adjusted the community coupons text in the Endeavors bar tooltip

**1.9.13** (2026-03-15)

**Fixed**
- Fixes for Endeavors config
- Fixed map tooltips losing their dark styling when hovering vendor pins, zone overlay items, and the world map button
- Fixed a tooltip error that could occur when hovering certain map icons after viewing zone overlay items
- Zone overlay scrollbar thumb now appears immediately when the list is long enough to scroll
- Hovering the collapsed zone overlay now shows a tooltip hint
- Removed a phantom item that showed with a ? icon and no preview in some vendor and zone overlay lists
- Fixed a brief visual flash when switching categories in the Achievements and Quests tabs

**1.9.12** (2026-03-14)

**Changed**
- Endeavors panel no longer auto-minimizes after being idle — it stays visible while you're in your neighborhood

**Fixed**
- Fixed a potential crash with the minimap button when entering certain protected UI states

**1.9.11** (2026-03-14)

**Added**
- Smooth animations for the zone overlay expanding and collapsing on the world map

**Changed**
- Faster addon startup

**Fixed**
- Improvements to the zone overlay code
- Fixed a crash when pressing ESC to close the world map while the zone overlay was visible
- Quest tab no longer shows a stale preview when the selected quest is hidden by search or filters
- Quest and vendor zone lists now sort correctly in non-English languages

**1.9.10** (2026-03-13)

**Added**
- Full German localization — all addon text is now translated to German

**1.9.9** (2026-03-13)

**Fixed**
- Expanding or collapsing a zone in the Vendors tab no longer jumps the scroll to the top of the list
- Zone overlay 3D preview on the world map no longer shows blank or invisible models when hovering items

**1.9.8** (2026-03-13)

**Changed**
- Updated decor items at promotional vendors (Dennia, Gabbi, Tuuran)

**Fixed**
- Opening Housing Codex settings during combat no longer causes a "blocked action" error
- Treasure hunt waypoints no longer move your map pin during combat — placement waits until combat ends
- Fixed a memory leak when resizing the browse grid or changing tile size

**1.9.7** (2026-03-12)

**Fixed**
- Fixed many quests showing under "Unknown Zone" instead of their correct expansion and zone
- Fixed two vendors (Fiona, Artificer Kallaes) appearing under the wrong expansion category
- Fixed some catalog items not appearing in quest, vendor, and drop lookups

**1.9.6** (2026-03-12)

**Fixed**
- Fixed a taint error on the world map that could occur after previewing items in the zone overlay

**1.9.5** (2026-03-12)

**Added**
- Full Simplified Chinese localization — all addon text is now translated to Chinese (thanks to XingDvD)

**Changed**
- Zone names, class names, profession names, and vendor names now display more accurately in French and Chinese
- Redesigned map tooltips
- Updated item database with refreshed vendor, quest, achievement, and drop data

**Fixed**
- Endeavors panel no longer shows stale tasks from a previous neighborhood when teleporting between neighborhoods
- Toggling the Endeavors panel on while in a neighborhood now immediately starts tracking
- Endeavors config popup now always shows current settings when reopened
- Improvements to vendor items when using fallback data
- Clicking the Endeavors progress bar during combat no longer causes a "blocked action" error
- Codebase improvements in order to make the addon run smoother

**1.9.4** (2026-03-11)

**Fixed**
- Resolved a taint issue on the world map - fixes #5

**1.9.3** (2026-03-11)

**Fixed**
- Duplicate quest entries no longer appear under the "Other" category
- Codebase improvements in order to make the addon run more smooth

**1.9.2** (2026-10-03)

**Changed**
- Zone names, profession names, and vendor NPC names now display in your game language instead of English

**Fixed**
- Treasure hunt waypoints now restore correctly after login or reload
- Setting a vendor waypoint no longer silently removes your existing waypoint if the new one can't be placed
- Clearing a vendor waypoint no longer removes waypoints you set yourself

**1.9.1** (2026-09-09)

**Added**
- Full French localization — all addon text is now translated to French

**Fixed**
- Re-enabling the Endeavors panel from Settings now shows it immediately when in a neighborhood
- Endeavors panel auto-minimize no longer gets overridden when tasks are active
- Endeavors panel no longer shows stale task data when switching neighborhoods or entering a new endeavor cycle
- Endeavors panel now correctly tracks tasks with multiple requirements

**1.9.0** (2026-09-09)

**Added**
- Localization support — quest titles, vendor zone names, and drop source names now display in your game language

**Fixed**
- Zone overlay expand/collapse preference now stays as you set it when reopening the map
- Turning off vendor checkmarks in settings now properly clears existing checkmarks
- Wishlist window now updates correctly when collecting items or removing items from the wishlist
- 3D preview panel now updates owned/placed counts live when collecting items
- Tab switching now refreshes stale ownership data
- Removed a phantom vendor item that appeared in tooltips but doesn't exist in the game

**1.8.13** (2026-08-03)

**Fixed**
- Vendor map pins now appear at the correct position when vendors are in sub-zones
- Vendors with multiple locations now all show on the map instead of some being hidden
- Clicking a zone aggregate vendor pin now correctly drills into that zone's map
- Collecting items now immediately updates the grid, filters, and ownership counts
- Removing an item from wishlist while filtering by wishlist now immediately hides it from the grid
- Fixes for the endeavors panel timers
- Re-enabling the Endeavors panel from the endeavor menu now shows it instantly
- Endeavors panel layout now resets properly when re-entering your neighborhood
- Tweaks to the Endeavors config popup spacing

**1.8.12** (2026-08-03)

**Changed**
- Redesigned endeavors panel settings

**Fixed**
- Tweaks to the Achievements tab
- Fixes for Professions tab for rare cases when the tab was ready before housing data loaded
- Fixed a rare crash when using /hc retry

**1.8.11** (2026-07-08)

**Fixed**
- Minimap button and Settings now work even if housing data fails to load
- Welcome panel subtitle text no longer overflows past the frame edge

**1.8.10** (2026-07-08)

**Changed**
- Improvements to the owned decor logic when visiting decor vendors
- Improvements to the text on progress bars in the Endeavors panel
- Tweaks to the Endeavors config panel

**1.8.9** (2026-07-03)

**Added**
- Endeavors panel size can now be adjusted — choose between Small, Normal, or Big from the cogwheel settings menu
- Existing users are migrated to Normal size — if you want the previous size before this update, that is now the "Small" one

**Fixed**
- Progress tab now shows quest progress broken down by expansion — click to jump to the Quests tab filtered by that expansion
- PvP progress bars in the Progress tab now appear correctly without needing to visit the PvP tab first
- Quest and Achievement tabs now show a proper "no results" message when search or filters match nothing
- Vendor tab filters and search now return more accurate results

**1.8.8** (2026-06-07)

**Added**
- New "Adjust Map Pin Layer" option in the world map button menu — choose whether vendor pins appear below or on top of other map icons

**Fixed**
- Vendor map pins no longer overlap with event icons (e.g., Saltheril's Soiree)
- Corrected vendor pin positions for The Den vendors in Harandar

**1.8.7** (2026-06-03)

**Changed**
- Track button in the Vendors tab renamed to "Waypoint" for clarity

**Fixed**
- Fixes for #1 and #2 on issue tracker
- Improvements on how buttons width auto-adjusts

**1.8.6** (2026-05-03)

**Added**
- On Eversong Woods map, the vendors in Silvermoon City are shown as one vendor icon (stacked map pin) instead of individual pins

**1.8.5** (2026-04-03)

**Changed**
- Adjustments to the Decor tab:
- Reordered UI elements, search bar is now first, consistent with the other tabs
- Tweaks to the UI elements to better accommodate smaller window sizes

**1.8.4** (2026-03-05)

**Added**
- Achievement-locked vendor items (such as the crafting vendors in Silvermoon selling the "shop sign" decor) now show "locked" in vendor tooltips, map pin tooltips, and NPC tooltips
- 4 missing Midnight profession shop sign vendors added (Eriden, Yatheon, Amwa'ana, Mowaia)

**1.8.3** (2026-03-04)

**Added**
- Added Dethelin decor vendor in Silvermoon City (sells the Twilight Ascension decor)

**1.8.2** (2026-03-04)

**Fixed**
- Vendor NPC tooltips now appear immediately — previously they wouldn't show until the Vendors tab or world map was opened at least once

**1.8.1** (2026-03-04)

**Changed**
- Updated Midnight decor vendor data

**1.8.0** (2026-03-03)

**Added**
- NEW - Bag & Bank decor indicators — housing decor items in your bags, character bank, and warband bank now show a Housing Codex icon and a green checkmark if you already own them
- Only works with the default UI for now, extended support for popular bag addons coming in the future
- Two new settings under "Bags & Bank" to toggle the decor icon and ownership checkmark independently

**1.7.11** (2026-03-03)

**Added**
- Vendor map pin transparency setting — choose how visible the vendor pins are on the world map (100/80/60/40%)
- Vendor map pin size setting — adjust the size of vendor pins on the world map (60/80/100/120/140%)

**Changed**
- World map button menu reorganized

**1.7.10** (2026-03-03)

**Added**
- Endeavor task tooltips — hover a task row to see the task name, how many times you've completed it, and what rewards it gives
- Endeavor bar tooltip now shows how much time is left until the current endeavor ends
- Endeavor bar tooltip now shows your current community coupons

**1.7.9** (2026-03-03)

**Fixed**
- URL popup now closes with the ESC key
- `/hc retry` now properly refreshes all data indexes

**Changed**
- Codebase improvements in order to make the addon run more smooth

**1.7.8** (2026-03-01)

**Added**
- Vendor Tooltip Overlay — hovering over an NPC vendor that sells housing decor now shows your collection progress and uncollected item names directly in the tooltip (toggle in Settings)

**Changed**
- Locale cleanup

**1.7.7** (2026-03-01)

**Added**
- Midnight decor vendor updates

**Changed**
- Main UI tab tweaks

**1.7.6** (2026-03-01)

**Changed**
- Endeavors panel now shows in any neighborhood you visit (no longer requires owning a house there)

**Fixed**
- Drops tab now correctly shows owned status for some items that were previously appearing as uncollected
- Item selection in Vendors and Drops tabs no longer highlights the wrong row when the same decor appears under multiple sources
- Quest zone toggle no longer requires two clicks to collapse on first use
- Search clear button no longer briefly re-applies the old search text after clearing
- Re-enabling the Endeavors panel in settings now correctly checks if you're in a neighborhood
- Stability and performance improvements

**1.7.5** (2026-02-28)

**Fixed**
- Improved item display in the zone overlay
- Removed a non-existent item from the Drops tab
- Endeavors panel now detects task progress in real-time while in your neighborhood
- Items that temporarily fail to load no longer get permanently stuck as missing
- Performance improvements across search, animations, quest loading, and map pins

**1.7.4** (2026-02-28)

**Fixed**
- Promotional vendors (Dennia, Gabbi, Tuuran) no longer show inflated item counts — inventories now match what they actually sell in-game
- Improved vendor overlay checkmark reliability when opening a vendor
- Quest names in the Quests tab now load more reliably

**1.7.3** (2026-02-28)

**Added**
- Class hall vendor tooltips and labels now show class-specific colors

**Changed**
- Updated item database with new vendor items and improved vendor location coverage

**Fixed**
- Midnight zone vendors now appear correctly on the map and in the zone overlay
- Stability improvements

**1.7.2** (2026-02-27)

**Added**
- New quest and achievement sources added to the item database

**Fixed**
- Fixed a memory leak that occurred each time the welcome screen was opened
- Waypoint sound and chat message no longer play when the waypoint fails to set
- Endeavors panel no longer errors when you don't have a house

**1.7.1** (2026-02-27)

**Added**
- TomTom waypoint support - enable in Settings to use TomTom for all waypoints instead of the native map pin (requires TomTom addon)
- Keybind conflict detection - when setting a keybind already used by another action, a confirmation dialog lets you choose to reassign it
- PvP source progress now shows in the Progress tab alongside other source types
- Responsive tabs - tabs now adapt to window width - labels shorten or switch to icon-only when the window is narrow

**Changed**
- Login chat message now shows your overall collection percentage instead of just item count
- Updated item database with corrected sources and new data

**Fixed**
- Fixed PvP tab items highlighting incorrectly when different vendors share the same decor items
- Fixed PvP tab not showing an empty state message when search filters out all results
- Codebase improvements for smoother performance

**1.7.0** (2026-02-26)

**Added**
- NEW - PvP tab - see all housing items obtainable through PvP in one place
  - Browse by source type: Achievements, Vendors, and Arena Drops
  - Search across PvP sources and items

**1.6.1** (2026-02-26)

**Changed**
- Updated item database with corrected vendor and drop sources

**Fixed**
- Various improvements for vendor map pins and quest tracking
- Codebase improvements for smoother performance

**1.6.0** (2026-02-25)

**Added**
- NEW - Endeavors panel - a compact progress tracker that appears while in your neighborhood
  - Includes two progress bars: one for House Level XP and one for the Endeavor progress
  - Community Endeavor initiative progress bar with milestone tracking
  - Shows the recently progressed endeavor tasks (up to max 3 visible)
  - Hover progress bars to see detailed stats, milestones, and your contribution
  - Click progress bars to open the Housing Dashboard directly
  - Optional percentage display on progress bars (toggle in settings)
  - Auto-minimizes after 2 minutes of inactivity; auto-expands when new tasks appear
  - The Endeavors panel can be disabled from the Housing Codex settings

**1.5.4** (2026-02-25)

**Added**
- Junkyard Tinkering profession added to the Professions tab with 6 new craftable decor items

**Changed**
- Midnight expansion drops are now always shown (removed the toggle from Settings)

**1.5.3** (2026-02-24)

**Added**
- German language support for the addon category label in the AddOns list

**Changed**
- Progress tab now refreshes when reopening the addon, so collection changes are reflected immediately
- For feature discoverability purposes, the welcome screen will be shown to the existing users, once (previously it was only for fresh installs)

**Fixed**
- Fixed keybind capture failing silently when attempted during combat
- Fixed old keybinds sometimes persisting after rebinding the addon shortcut

**1.5.2** (2026-02-24)

**Added**
- Redesigned the welcome screen with a visual card grid showcasing main features of Housing Codex
- Welcome screen now automatically shows once for fresh installs
- Welcome screen can now be moved by dragging the header

**Fixed**
- Added protection for the Welcome screen so it won't fail when the player is in combat

**1.5.1** (2026-02-23)

**Added**
- Hovering sort options drop-down menu in the Decor tab now shows a description of what each sort does
- New "Qty Placed" sort option to sort by how many copies you've placed in your house
- New "Reset Window Size" button in Settings > Troubleshooting to restore the default window size

**Changed**
- Settings page tweaks
- Wider search boxes across all tabs so that 'search hint text' is easier to read

**Fixed**
- Fixed search placeholder text (e.g., "Search achievements, rewards, or categories...") overflowing outside the search box on narrow windows

**1.5.0** (2026-02-22)

**Added**
- NEW - Progress tab showing your overall collection status at a glance
  - See your total collected percentage with a progress bar
  - Breakdown by source: Vendors, Quests, Achievements, Drops, Professions
  - Per-profession crafting progress
  - Vendor and Quest progress by expansion
  - "Most Progressed" section highlighting what you're closest to completing
  - Click any row to jump directly to that tab
  - Updates in real-time as you collect items

**Fixed**
- Fixed a 3D preview crash that could happen after rotating a model for a while
- Riica vendor now shows all items for sale
- Fixed quests showing under "Unknown Zone" — now correctly placed under their expansion and zone
- Fixed some vendors appearing under "Unknown" instead of their correct zone

**1.4.4** (2026-02-21)

**Added**
- Wishlist chat messages now show clickable item links - hover to preview, click to interact
- Professions tab remembers your last selected profession between sessions

**Changed**
- Settings panel reorganized into clear groups (Display, Map & Navigation, Merchant, Content) with a cleaner layout

**Fixed**
- Fixed a 3D preview error in the wishlist window

**1.4.3** (2026-02-20)

**Added**
- Vendor map pin tooltips now show "(locked)" next to items that need a prerequisite before you can buy them

**Fixed**
- Vendor map pins now show the correct collection progress (some owned items were incorrectly shown as missing)
- Vendors in multiple cities (Alliance/Horde variants) now show up correctly with faction tags on the map

**1.4.2** (2026-02-19)

**Changed**
- Decor vendors in cities now show the city name in the zone overlay tooltip (ie: "Vendor in Stormwind")

**Fixed**
- Decor vendors in cities now correctly appear in the parent zone's overlay

**1.4.1** (2026-02-18)

**Added**
- Auto-rotate is no longer exclusive to the tooltips, has now been added to the main and Wishlist UI too
- New toggle in Settings to turn auto-rotate on/off
- Wishlist UI 3D preview now supports full rotation and panning (matching the main preview)
- Zone overlay now includes housing decor from cities within a parent zone

**Fixed**
- Codebase improvements for smoother performance

**1.4.0** (2026-02-16)

**Added**
- NEW - Zone Overlay on the world map - see uncollected housing decor in the current zone
  - Expand the overlay to see the list of uncollected decor in the zone
  - See vendor name, set waypoints, show the 3D item preview
  - New Housing Codex button on the world map with settings: overlay toggle, position, transparency, preview size
- "Include already unlocked decor vendors" toggle in the world map dropdown - shows collected vendor items dimmed

**Changed**
- Multi-level maps like Dalaran now correctly show housing data

**Fixed**
- Vendors in sub-zones (e.g., City of Threads in Azj-Kahet) now appear in the parent zone's overlay

**1.3.4** (2026-02-15)

**Changed**
- Updated item database with newly discovered decor items (quests, achievements, crafting, drops)

**Fixed**
- Codebase improvements for smoother performance

**1.3.3** (2026-02-14)

**Added**
- Vendor tracking chat messages now include a clickable map link

**Changed**
- Updated for WoW 12.0.1 compatibility

**Fixed**
- Fixed a rare crash that could occur when placing or picking up certain decor items
- Codebase improvements for smoother performance

**1.3.2** (2026-02-10)

**Changed**
- Green checkmarks at vendors now appear instantly instead of loading in with a delay

**Fixed**
- Corrected map pin locations for 4 daily treasure hunt quests

**1.3.1** (2026-02-10)

**Added**
- Right-click drag to pan in the 3D preview panel
- Minimap broker text is now configurable - Alt-click the minimap icon to choose which stats to display (Unique Collected, Total Owned, Total Items)
- Collection stats tooltip - hover the result count in bottom left in the Decor tab to see a quick summary of your collection
- You can now zoom-in even more in the 3D preview

**1.3.0** (2026-02-08)

**Added**
- NEW - Professions tab - browse crafted housing items
  - See which professions can craft housing decor items
  - Collection progress per profession
  - Search across professions and crafted items
  - Filter by completion status

**1.2.2** (2026-02-08)

**Added**
- Unlocked vertical rotation in 3D preview - drag to rotate in any direction (previously horizontal only)

**1.2.1** (2026-02-08)

**Changed**
- Shift-clicking items in the Vendors tab now places a map pin on the vendor instead of tracking the item
- Chat messages when tracking/untracking a vendor now show the vendor name and zone

**1.2.0** (2026-02-07)

**Added**
- NEW feature - Decor vendors shown on map
  - See where housing vendors are on the map
  - Shows both in zone maps and continent maps
  - Hover a pin to see collection progress and which items you're missing
  - Click a pin to set a waypoint to the vendor
  - Toggle on/off in addon settings

**1.1.0** (2026-02-07)

**Added**
- NEW Drops tab - find decor that drops from mobs, bosses or is found in treasure chests
  - Option to show upcoming Midnight expansion drops (off by default)
- Search vendors by currency name (ie: "resonance crystals")

**Fixed**
- Minor fixes and UI tweaks

**1.0.0** (2026-02-06)

**Added**
- Automatically adding a map pin for the daily treasure hunt secret quest. Enabled by default, can be disabled in addon options

**Fixed**
- Minor fixes and UI tweaks

**0.9.0** (2026-02-05)

**Added**
- NEW Vendors tab - browse housing items by vendor source
  - View vendors organized by expansion and zone
  - See all decor items each vendor sells
  - Set waypoints to vendor locations
  - Alliance/Horde faction indicators for faction specific vendors
  - Search across vendors, zones, and decor items

**0.8.10** (2026-02-03)

**Added**
- New "Reset Window Position" button in addon settings to reset the window to the center of the screen
- New `/hc reset` slash command for the same purpose

**Changed**
- If the window was dragged off-screen, after a relog or reloadui it will be moved onscreen

**Fixed**
- Improved checks for the green checkmarks at the vendor screen

**0.8.9** (2026-02-02)

**Fixed**
- The currency tooltip now actually works

**0.8.8** (2026-02-02)

**Added**
- Currency tooltips for vendor items - hover the currency icon to see more details

**Fixed**
- Reduced memory usage

**0.8.7** (2026-02-01)

**Added**
- Right-click context menu on all item lists
  - Add or remove items from wishlist
  - Track items on the map (if trackable)
  - Link items to chat
  - Copy Wowhead link to clipboard

**Fixed**
- Reduced memory usage and improved performance

**0.8.6** (2026-01-31)

**Changed**
- Changed the way window resizing works
- Disabled screen clamp, now the window resize is more smooth and consistent

**Fixed**
- Codebase improvements in order to make the addon run more smooth

**0.8.5** (2026-01-31)

**Changed**
- Adjusted preview panel width presets (Small: 300px, Medium: 500px, Large: 700px)
- Decor details panel in the preview section now adapts to panel width (two rows when narrow, one row when wide)

**Fixed**
- Several code improvements to make the addon use less resources

**0.8.4** (2026-01-31)

**Changed**
- UI is more responsive
- Window size can be made smaller
- Toolbar elements hide progressively when window is narrow
- Several code improvements

**0.8.3** (2026-01-30)

**Added**
- NEW feature! Vendor decor indicators - Housing Codex icon appears on vendor item buttons for housing decor items
- Green checkmark on vendor items you already own
- Two new settings to control vendor indicators independently

**0.8.2** (2026-01-30)

**Fixed**
- Bug fixes and UI tweaks

**0.8.1** (2026-01-30)

**Fixed**
- Achievement categories now correctly match in-game achievement panel

**Changed**
- UI and font size tweaks for better readability

**0.8.0** (2026-01-30)

**Added**
- Achievements tab - browse housing items by achievement source
  - Category navigation (Class Hall, Delves, PvP, Quests, Professions, etc.)
  - Completion percentage display per category
  - Achievement tooltips with real-time criteria progress
  - Shift-click to track achievements in objective tracker
  - Right-click to copy Wowhead link
- Quest completion percentages on expansion buttons
- Quest tooltips showing objectives and progress
- Right-click on quests to copy Wowhead link

**0.7.0** (2026-01-29)

**Added**
- Standalone wishlist window - view all wishlisted items in a dedicated UI
  - Grid display with 3D preview panel
  - Hover to preview, click to lock selection

**0.6.0** (2026-01-29)

**Added**
- New Quests tab - browse housing items by quest source
  - Quest completion tracking (account-wide)
  - Collection progress at expansion, zone, and quest levels
  - Search and filter by completion status
  - Reward preview for each quest
- Midnight expansion initial support

**Fixed**
- Search results more accurate

**0.5.3** (2026-01-28)

**Added**
- Minimap button
- Search now finds items by source and description (zone, vendor, quest, etc.)

**Fixed**
- Various bug fixes

**0.5.2** (2026-01-26)

**Changed**
- Minor UI polish and bug fixes

**0.5.1** (2026-01-26)

**Fixed**
- Fixed collected items incorrectly showing as "Uncollected" when the same item exists from multiple sources

**0.5.0** (2026-01-26)

**Added**
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
