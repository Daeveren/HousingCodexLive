--[[
    Housing Codex - deDE.lua
    German localization
]]

if GetLocale() ~= "deDE" then return end

local _, addon = ...

local L = addon.L

--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------
L["ADDON_NAME"] = "Housing Codex"
L["KEYBIND_HEADER"] = "|cffffd100Housing|r |cffff8000Codex|r"
L["KEYBIND_TOGGLE"] = "|cffff8000HC|r Fenster umschalten"
L["LOADING"] = "Laden..."
L["LOADING_DATA"] = "Dekordaten werden geladen..."
L["LOADED_MESSAGE"] = "|cFF88EE88%.1f%%|r Dekor gesammelt. Tippe |cFF88BBFF/hc|r zum Oeffnen."
L["COMBAT_LOCKDOWN_MESSAGE"] = "Kann im Kampf nicht geoeffnet werden"

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------
L["TAB_DECOR"] = "DEKOR"
L["TAB_QUESTS"] = "QUESTS"
L["TAB_ACHIEVEMENTS"] = "ERFOLGE"
L["TAB_VENDORS"] = "HAENDLER"
L["TAB_DROPS"] = "BEUTE"
L["TAB_PROFESSIONS"] = "BERUFE"
L["TAB_ACHIEVEMENTS_SHORT"] = "ERF..."
L["TAB_PROFESSIONS_SHORT"] = "BER..."
L["TAB_PROGRESS_SHORT"] = "FORT..."
L["TAB_DECOR_DESC"] = "Alle Housing-Dekorobjekte durchstoebern und durchsuchen"
L["TAB_QUESTS_DESC"] = "Questquellen fuer Housing-Dekorobjekte"
L["TAB_ACHIEVEMENTS_DESC"] = "Erfolgsquellen fuer Housing-Dekorobjekte"
L["TAB_VENDORS_DESC"] = "Haendlerstandorte fuer Housing-Dekorobjekte"
L["TAB_DROPS_DESC"] = "Beutequellen fuer Housing-Dekorobjekte"
L["TAB_PROFESSIONS_DESC"] = "Herstellbare Housing-Dekorobjekte"

--------------------------------------------------------------------------------
-- Search & Filters
--------------------------------------------------------------------------------
L["SEARCH_PLACEHOLDER"] = "Suchen..."
L["FILTER_ALL"] = "Alle Objekte"
L["FILTER_COLLECTED"] = "Gesammelt"
L["FILTER_NOT_COLLECTED"] = "Nicht gesammelt"
L["FILTER_TRACKABLE"] = "Nur verfolgbar"
L["FILTER_NOT_TRACKABLE"] = "Nicht verfolgbar"
L["FILTER_TRACKABLE_HEADER"] = "Verfolgbar"
L["FILTER_TRACKABLE_ALL"] = "Alle"
L["FILTER_INDOORS"] = "Innen"
L["FILTER_OUTDOORS"] = "Aussen"
L["FILTER_DYEABLE"] = "Faerbbar"
L["FILTER_FIRST_ACQUISITION"] = "Bonus fuer den ersten Erwerb"
L["FILTER_WISHLIST_ONLY"] = "Nur Wunschliste"
L["FILTERS"] = "Filter"
L["CHECK_ALL"] = "Alle auswaehlen"
L["UNCHECK_ALL"] = "Alle abwaehlen"

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------
L["SIZE_LABEL"] = "Groesse:"
L["SORT_BY_LABEL"] = "Sortieren"

--------------------------------------------------------------------------------
-- Sort
--------------------------------------------------------------------------------
L["SORT_NEWEST"] = "Neueste"
L["SORT_ALPHABETICAL"] = "A-Z"
L["SORT_SIZE"] = "Groesse"
L["SORT_QUANTITY"] = "Anz. im Besitz"
L["SORT_PLACED"] = "Anz. platziert"
L["SORT_NEWEST_TIP"] = "Neu hinzugefuegtes Dekor zuerst"
L["SORT_ALPHABETICAL_TIP"] = "Alphabetische Reihenfolge (A bis Z)"
L["SORT_SIZE_TIP"] = "Groesstes Dekor zuerst (Riesig bis Winzig)"
L["SORT_QUANTITY_TIP"] = "Meiste besessene Kopien zuerst"
L["SORT_PLACED_TIP"] = "Am haeufigsten in deinem Haus platziert zuerst"

--------------------------------------------------------------------------------
-- Result Count & Empty State
--------------------------------------------------------------------------------
L["RESULT_COUNT_ALL"] = "Zeige %d Objekte"
L["RESULT_COUNT_FILTERED"] = "Zeige %d von %d Objekten"
L["RESULT_COUNT_TOOLTIP_UNIQUE"] = "Einzigartig gesammelt: %d"
L["RESULT_COUNT_TOOLTIP_OWNED"] = "Gesamt im Besitz: %d"
L["RESULT_COUNT_TOOLTIP_TOTAL"] = "Gesamtdekor: %d"
L["EMPTY_STATE_MESSAGE"] = "Keine Objekte entsprechen deinen Filtern"
L["RESET_FILTERS"] = "Filter zuruecksetzen"

--------------------------------------------------------------------------------
-- Category Navigation
--------------------------------------------------------------------------------
L["CATEGORY_ALL"] = "Alle"
L["CATEGORY_BACK"] = "Zurueck"
L["CATEGORY_ALL_IN"] = "Alle %s"

--------------------------------------------------------------------------------
-- Details Panel
--------------------------------------------------------------------------------
L["DETAILS_NO_SELECTION"] = "Waehle ein Objekt aus"
L["DETAILS_OWNED"] = "Im Besitz: %d"
L["DETAILS_PLACED"] = "Platziert: %d"
L["DETAILS_NOT_OWNED"] = "Nicht im Besitz"
L["DETAILS_SIZE"] = "Groesse:"
L["DETAILS_PLACE"] = "Platzierung:"
L["DETAILS_DYEABLE"] = "Faerbbar"
L["DETAILS_NOT_DYEABLE"] = "Nicht faerbbar"
L["DETAILS_SOURCE_UNKNOWN"] = "Unbekannte Quelle"
L["UNKNOWN"] = "Unbekannt"

-- Size names
L["SIZE_TINY"] = "Winzig"
L["SIZE_SMALL"] = "Klein"
L["SIZE_MEDIUM"] = "Mittel"
L["SIZE_LARGE"] = "Gross"
L["SIZE_HUGE"] = "Riesig"

-- Placement types
L["PLACEMENT_IN"] = "Innen"
L["PLACEMENT_OUT"] = "Aussen"

--------------------------------------------------------------------------------
-- Wishlist
--------------------------------------------------------------------------------
L["WISHLIST_ADD"] = "Zur Wunschliste hinzufuegen"
L["WISHLIST_REMOVE"] = "Aus Wunschliste entfernen"
L["WISHLIST_ADDED"] = "Zur Wunschliste hinzugefuegt: %s"
L["WISHLIST_REMOVED"] = "Aus Wunschliste entfernt: %s"
L["WISHLIST_BUTTON"] = "WUNSCHL."
L["WISHLIST_BUTTON_TOOLTIP"] = "Deine Wunschliste anzeigen"
L["WISHLIST_TITLE"] = "Wunschliste"
L["WISHLIST_EMPTY"] = "Deine Wunschliste ist leer"
L["WISHLIST_EMPTY_DESC"] = "Fuege Objekte hinzu, indem du im Dekor- oder Quest-Tab auf das Sternsymbol klickst"
L["WISHLIST_SHIFT_CLICK"] = "Umschalt+Klick zum Hinzufuegen/Entfernen aus der Wunschliste"

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------
L["ACTION_TRACK"] = "Verfolgen"
L["ACTION_UNTRACK"] = "Nicht mehr verfolgen"
L["ACTION_LINK"] = "Link"
L["ACTION_TRACK_TOOLTIP"] = "Dieses Objekt in der Zielverfolgung verfolgen"
L["ACTION_UNTRACK_TOOLTIP"] = "Dieses Objekt nicht mehr verfolgen"
L["ACTION_TRACK_DISABLED_TOOLTIP"] = "Dieses Objekt kann nicht verfolgt werden"
L["ACTION_LINK_TOOLTIP"] = "Objektlink in den Chat einfuegen"
L["ACTION_LINK_TOOLTIP_RIGHTCLICK"] = "Rechtsklick: Wowhead-URL kopieren"
L["TRACKING_ERROR_MAX"] = "Kann nicht verfolgt werden: Maximale Anzahl verfolgter Objekte erreicht"
L["TRACKING_ERROR_UNTRACKABLE"] = "Dieses Objekt kann nicht verfolgt werden"
L["TRACKING_STARTED"] = "Wird jetzt verfolgt: %s"
L["TRACKING_STOPPED"] = "Verfolgung beendet: %s"
L["TOOLTIP_SHIFT_CLICK_TRACK"] = "Umschalt-Klick zum Verfolgen"
L["TOOLTIP_SHIFT_CLICK_UNTRACK"] = "Umschalt-Klick, um die Verfolgung zu beenden"
L["TRACKING_ERROR_GENERIC"] = "Verfolgung fehlgeschlagen"
L["LINK_ERROR"] = "Objektlink konnte nicht erstellt werden"
L["LINK_INSERTED"] = "Link in den Chat eingefuegt"

--------------------------------------------------------------------------------
-- Preview
--------------------------------------------------------------------------------
L["PREVIEW_NO_MODEL"] = "Kein 3D-Modell verfuegbar"
L["PREVIEW_NO_SELECTION"] = "Waehle ein Objekt fuer die Vorschau aus"
L["PREVIEW_ERROR"] = "Fehler beim Laden des Modells"
L["PREVIEW_NOT_IN_CATALOG"] = "Noch nicht im Housing-Katalog"

--------------------------------------------------------------------------------
-- Settings (WoW Native Settings UI)
--------------------------------------------------------------------------------
L["OPTIONS_SECTION_DISPLAY"] = "Anzeige"
L["OPTIONS_SECTION_MAP_NAV"]  = "Karte & Navigation"
L["OPTIONS_SECTION_MERCHANT"] = "Haendler"
L["OPTIONS_SHOW_COLLECTED"] = "Besessene Anzahl auf Kacheln anzeigen"
L["OPTIONS_SHOW_COLLECTED_TOOLTIP"] = "Besessene Anzahl auf Rasterkacheln fuer gesammelte Objekte anzeigen"
L["OPTIONS_SHOW_MINIMAP"] = "Minikarten-Button anzeigen"
L["OPTIONS_SHOW_MINIMAP_TOOLTIP"] = "Den Housing-Codex-Button auf der Minikarte anzeigen"
L["OPTIONS_VENDOR_INDICATORS"] = "Dekorobjekte bei Haendlern markieren"
L["OPTIONS_VENDOR_INDICATORS_TOOLTIP"] = "Housing-Codex-Symbol auf Haendlerobjekten anzeigen, die Housing-Dekor sind"
L["OPTIONS_VENDOR_OWNED_CHECKMARK"] = "Haekchen fuer besessenes Dekor anzeigen"
L["OPTIONS_VENDOR_OWNED_CHECKMARK_TOOLTIP"] = "Gruenes Haekchen auf Haendler-Dekorobjekten anzeigen, die du bereits besitzt"
L["OPTIONS_SECTION_CONTAINERS"] = "Taschen & Bank"
L["OPTIONS_CONTAINER_INDICATORS"] = "Dekorobjekte in Taschen und Bank markieren"
L["OPTIONS_CONTAINER_INDICATORS_TOOLTIP"] = "Housing-Codex-Symbol auf Dekorobjekten in deinen Taschen und deiner Bank anzeigen"
L["OPTIONS_CONTAINER_OWNED_CHECKMARK"] = "Haekchen fuer besessenes Dekor anzeigen"
L["OPTIONS_CONTAINER_OWNED_CHECKMARK_TOOLTIP"] = "Gruenes Haekchen auf Dekorobjekten in Taschen und Bank anzeigen, die du bereits besitzt"
L["OPTIONS_VENDOR_MAP_PINS"] = "Haendlerkartenpins anzeigen"
L["OPTIONS_VENDOR_MAP_PINS_TOOLTIP"] = "Haendler-Pins mit Sammlungsfortschritt auf der Weltkarte anzeigen"
L["OPTIONS_TREASURE_HUNT_WAYPOINTS"] = "Automatischer Wegpunkt fuer Schatzsuchen"
L["OPTIONS_TREASURE_HUNT_WAYPOINTS_TOOLTIP"] = "Beim Annehmen einer Dekor-Schatzsuche in Housing-Zonen automatisch einen Kartenwegpunkt setzen"
L["OPTIONS_USE_TOMTOM"] = "TomTom fuer Wegpunkte verwenden"
L["OPTIONS_USE_TOMTOM_TOOLTIP"] = "Bei installiertem TomTom TomTom-Wegpunkte statt des nativen Kartenpins verwenden"
L["OPTIONS_USE_TOMTOM_NOT_INSTALLED"] = "TomTom fuer Wegpunkte verwenden (Nicht installiert)"
L["OPTIONS_AUTO_ROTATE_PREVIEW"] = "3D-Vorschau automatisch drehen"
L["OPTIONS_AUTO_ROTATE_PREVIEW_TOOLTIP"] = "3D-Modell im Vorschaufenster und in der Wunschliste langsam drehen"
L["OPTIONS_RESET_POSITION"] = "Fensterposition zuruecksetzen"
L["OPTIONS_RESET_POSITION_TOOLTIP"] = "Fenster in die Bildschirmmitte zuruecksetzen"
L["OPTIONS_RESET_SIZE"] = "Fenstergroesse zuruecksetzen"
L["OPTIONS_RESET_SIZE_TOOLTIP"] = "Fenster auf Standardgroesse zuruecksetzen"
L["OPTIONS_SHOW_WELCOME"] = "Willkommensbildschirm"
L["OPTIONS_SHOW_WELCOME_TOOLTIP_DISABLED"] = "Nutze /hc welcome, um den Willkommensbildschirm anzuzeigen"
L["SIZE_RESET"] = "Fenstergroesse auf Standard zurueckgesetzt."

L["OPTIONS_SECTION_KEYBIND"] = "Tastenbelegung"
L["OPTIONS_SECTION_TROUBLESHOOTING"] = "Fehlerbehebung"
L["OPTIONS_TOGGLE_KEYBIND"] = "Fenster umschalten:"
L["OPTIONS_NOT_BOUND"] = "Nicht belegt"
L["OPTIONS_PRESS_KEY"] = "Taste druecken..."
L["OPTIONS_UNBIND_TOOLTIP"] = "Rechtsklick zum Entfernen"
L["OPTIONS_KEYBIND_HINT"] = "Klicken, um eine Taste festzulegen. Rechtsklick zum Loeschen. ESC zum Abbrechen."
L["OPTIONS_KEYBIND_CONFLICT"] = "\"%s\" ist bereits an \"%s\" gebunden.\n\nMoechtest du die Belegung zu Housing Codex aendern?"

--------------------------------------------------------------------------------
-- Slash Command Help
--------------------------------------------------------------------------------
L["HELP_TITLE"] = "Housing Codex Befehle:"
L["HELP_TOGGLE"] = "/hc - Hauptfenster umschalten"
L["HELP_SETTINGS"] = "/hc settings - Einstellungen oeffnen"
L["HELP_RESET"] = "/hc reset - Fensterposition zuruecksetzen"
L["HELP_RETRY"] = "/hc retry - Datenladen erneut versuchen"
L["HELP_HELP"] = "/hc help - Diese Hilfe anzeigen"
L["HELP_DEBUG"] = "/hc debug - Debug-Modus umschalten"
L["HELP_STATS"] = "/hc stats - Debug-Zaehler anzeigen"

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------
L["SETTINGS_NOT_AVAILABLE"] = "Einstellungen noch nicht verfuegbar"
L["RETRYING_DATA_LOAD"] = "Datenladen wird erneut versucht..."
L["DEBUG_MODE_STATUS"] = "Debug-Modus: %s"
L["FONT_MODE_STATUS"] = "Benutzerdefinierte Schrift: %s"
L["DEBUG_ON"] = "AN"
L["DEBUG_OFF"] = "AUS"
L["DATA_NOT_LOADED"] = "Daten noch nicht geladen"
L["INSPECT_FOUND"] = "Gefunden: %s (ID: %d)"
L["INSPECT_NOT_FOUND"] = "Kein passendes Objekt gefunden fuer: %s"
L["MAIN_WINDOW_NOT_AVAILABLE"] = "Hauptfenster noch nicht verfuegbar"
L["POSITION_RESET"] = "Fensterposition auf Mitte zurueckgesetzt"

--------------------------------------------------------------------------------
-- Errors
--------------------------------------------------------------------------------
L["ERROR_API_UNAVAILABLE"] = "Housing-APIs nicht verfuegbar"
L["ERROR_LOAD_FAILED"] = "Housing-Daten konnten nach mehreren Versuchen nicht geladen werden. Nutze /hc retry, um es erneut zu versuchen."
L["ERROR_LOAD_FAILED_SHORT"] = "Datenladen fehlgeschlagen. Nutze /hc retry"

--------------------------------------------------------------------------------
-- LDB (LibDataBroker)
--------------------------------------------------------------------------------
L["LDB_TOOLTIP_LEFT"] = "|cffffffffLinksklick|r zum Umschalten des Hauptfensters"
L["LDB_TOOLTIP_RIGHT"] = "|cffffffffRechtsklick|r zum Oeffnen der Optionen"
L["LDB_TOOLTIP_ALT"] = "|cffffffffAlt-Klick|r zum Konfigurieren der Broker-Anzeige"
L["LDB_OPTIONS_PLACEHOLDER"] = "Optionsfenster noch nicht verfuegbar"
L["LDB_POPUP_TITLE"] = "Broker-Anzeige"
L["LDB_POPUP_UNIQUE"] = "Einzigartig gesammelt"
L["LDB_POPUP_TOTAL_OWNED"] = "Gesamt im Besitz"
L["LDB_POPUP_TOTAL_ITEMS"] = "Gesamtobjekte"

--------------------------------------------------------------------------------
-- Quests Tab
--------------------------------------------------------------------------------
L["QUESTS_SEARCH_PLACEHOLDER"] = "Quests, Zonen oder Belohnungen suchen..."
L["QUESTS_FILTER_ALL"] = "Alle"
L["QUESTS_FILTER_INCOMPLETE"] = "Unvollstaendig"
L["QUESTS_FILTER_COMPLETE"] = "Abgeschlossen"
L["QUESTS_EMPTY_NO_SOURCES"] = "Keine Questquellen gefunden"
L["QUESTS_EMPTY_NO_SOURCES_DESC"] = "Questdaten werden von der WoW-API moeglicherweise nicht bereitgestellt"
L["QUESTS_SELECT_EXPANSION"] = "Waehle eine Erweiterung"
L["QUESTS_EMPTY_NO_RESULTS"] = "Keine Quests entsprechen deiner Suche"
L["QUESTS_UNKNOWN_QUEST"] = "Quest #%d"
L["QUESTS_UNKNOWN_ZONE"] = "Unbekannte Zone"
L["QUESTS_UNKNOWN_EXPANSION"] = "Andere"

-- Quest tracking messages
L["QUESTS_TRACKING_STARTED"] = "Objekt wird jetzt verfolgt"
L["QUESTS_TRACKING_MAX_REACHED"] = "Kann nicht verfolgt werden - Maximum erreicht (15)"
L["QUESTS_TRACKING_ALREADY"] = "Dieses Objekt wird bereits verfolgt"
L["QUESTS_TRACKING_FAILED"] = "Dieses Objekt kann nicht verfolgt werden"

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
L["ACHIEVEMENTS_SEARCH_PLACEHOLDER"] = "Erfolge, Belohnungen oder Kategorien suchen..."
L["ACHIEVEMENTS_FILTER_ALL"] = "Alle"
L["ACHIEVEMENTS_FILTER_INCOMPLETE"] = "Unvollstaendig"
L["ACHIEVEMENTS_FILTER_COMPLETE"] = "Abgeschlossen"
L["ACHIEVEMENTS_EMPTY_NO_SOURCES"] = "Keine Erfolgsquellen gefunden"
L["ACHIEVEMENTS_EMPTY_NO_SOURCES_DESC"] = "Erfolgsdaten sind moeglicherweise nicht verfuegbar"
L["ACHIEVEMENTS_SELECT_CATEGORY"] = "Waehle eine Kategorie"
L["ACHIEVEMENTS_EMPTY_NO_RESULTS"] = "Keine Erfolge entsprechen deiner Suche"
L["ACHIEVEMENTS_UNKNOWN"] = "Erfolg #%d"

-- Achievement tracking messages
L["ACHIEVEMENTS_TRACKING_STARTED"] = "Objekt wird jetzt verfolgt"
L["ACHIEVEMENTS_TRACKING_STARTED_ACHIEVEMENT"] = "Erfolg wird jetzt verfolgt"
L["ACHIEVEMENTS_TRACKING_STOPPED"] = "Erfolgsverfolgung beendet"
L["ACHIEVEMENTS_TRACKING_MAX_REACHED"] = "Kann nicht verfolgt werden - Maximum erreicht (15)"
L["ACHIEVEMENTS_TRACKING_ALREADY"] = "Dieses Objekt wird bereits verfolgt"
L["ACHIEVEMENTS_TRACKING_FAILED"] = "Dieser Erfolg kann nicht verfolgt werden"

--------------------------------------------------------------------------------
-- Context Menu
--------------------------------------------------------------------------------
L["CONTEXT_MENU_LINK_TO_CHAT"] = "Im Chat verlinken"
L["CONTEXT_MENU_COPY_WOWHEAD"] = "Wowhead-Link kopieren"

--------------------------------------------------------------------------------
-- Vendors Tab
--------------------------------------------------------------------------------
L["VENDORS_SEARCH_PLACEHOLDER"] = "Haendler, Zonen oder Objekte suchen..."
L["VENDORS_FILTER_ALL"] = "Alle"
L["VENDORS_FILTER_INCOMPLETE"] = "Unvollstaendig"
L["VENDORS_FILTER_COMPLETE"] = "Abgeschlossen"
L["VENDORS_EMPTY_NO_SOURCES"] = "Keine Haendlerquellen gefunden"
L["VENDORS_EMPTY_NO_SOURCES_DESC"] = "Haendlerdaten sind moeglicherweise nicht verfuegbar"
L["VENDORS_SELECT_EXPANSION"] = "Waehle eine Erweiterung"
L["VENDORS_UNKNOWN_EXPANSION"] = "Andere"
L["VENDORS_UNKNOWN_ZONE"] = "Unbekannte Zone"

-- Vendor waypoint messages
L["VENDOR_SET_WAYPOINT"] = "Wegpunkt setzen"
L["VENDOR_NO_LOCATION"] = "Ort unbekannt"
L["VENDOR_WAYPOINT_SET"] = "Wegpunkt fuer %s gesetzt"
L["VENDOR_MAP_RESTRICTED"] = "Auf dieser Karte kann kein Wegpunkt gesetzt werden"

-- Vendor fallback names
L["VENDOR_UNKNOWN"] = "Unbekannter Haendler"
L["VENDOR_FALLBACK_NAME"] = "Haendler"

-- Vendor world map pins
L["VENDOR_PIN_COLLECTED"] = "Gesammelt: %d/%d"
L["VENDOR_PIN_UNCOLLECTED_HEADER"] = "Nicht gesammeltes Dekor:"
L["VENDOR_PIN_ITEM_LOCKED"] = "gesperrt"
L["VENDOR_PIN_MORE"] = "+%d weitere"
L["VENDOR_PIN_CLICK_WAYPOINT"] = "Klicken, um Wegpunkt zu setzen"
L["VENDOR_PIN_FACTION_ALLIANCE"] = "Nur Allianz"
L["VENDOR_PIN_FACTION_HORDE"] = "Nur Horde"
L["VENDOR_PIN_VENDOR_COUNT"] = "%dx Haendler"
L["VENDOR_PIN_VENDOR_LIST_HEADER"] = "Haendlerliste:"
L["VENDOR_PIN_VENDOR_ENTRY"] = "%s (%d/%d)"
L["VENDOR_PIN_VENDORS_MORE"] = "+%d weitere Haendler"

-- Vendor tracking messages
L["VENDORS_TRACKING_STARTED"] = "Kartenpin fuer %s in %s hinzugefuegt"
L["VENDORS_TRACKING_STOPPED"] = "Kartenpin fuer %s in %s entfernt"
L["VENDORS_ACTION_TRACK"] = "Wegpunkt"
L["VENDORS_ACTION_UNTRACK"] = "Wegpunkt entfernen"
L["VENDORS_ACTION_TRACK_TOOLTIP"] = "Kartenwegpunkt zum Standort dieses Haendlers setzen"
L["VENDORS_ACTION_UNTRACK_TOOLTIP"] = "Haendler-Wegpunkt entfernen"
L["VENDORS_ACTION_TRACK_DISABLED_TOOLTIP"] = "Dieser Haendler hat keinen gueltigen Wegpunkt"

-- Vendor cost display
L["CURRENCY_GOLD"] = "Gold"

-- Vendor decor fallback
L["VENDORS_DECOR_ID"] = "Dekor #%d"

-- Vendor zone annotations
L["VENDOR_CLASS_HALL_SUFFIX"] = "Klassenhalle"
L["VENDOR_HOUSING_ZONE_SUFFIX"] = "Housing-Zone"
L["VENDOR_CLASS_ONLY_SUFFIX"] = "Nur %s"

-- Vendor tooltip overlay
L["OPTIONS_VENDOR_TOOLTIPS"] = "Haendler-Dekor in Tooltips anzeigen"
L["OPTIONS_VENDOR_TOOLTIPS_TOOLTIP"] = "Housing-Codex-Sammlungsfortschritt beim Ueberfahren von Dekor-Haendler-NPCs anzeigen"

--------------------------------------------------------------------------------
-- Drops Tab
--------------------------------------------------------------------------------
L["DROPS_SEARCH_PLACEHOLDER"] = "Quellen oder Objekte suchen..."
L["DROPS_FILTER_ALL"] = "Alle"
L["DROPS_FILTER_INCOMPLETE"] = "Unvollstaendig"
L["DROPS_FILTER_COMPLETE"] = "Abgeschlossen"
L["DROPS_EMPTY_NO_SOURCES"] = "Keine Beutequellen gefunden"
L["DROPS_EMPTY_NO_SOURCES_DESC"] = "Beutedaten sind moeglicherweise nicht verfuegbar"
L["DROPS_SELECT_CATEGORY"] = "Waehle eine Kategorie"

-- Drop source category labels
L["DROPS_CATEGORY_DROP"] = "Beute"
L["DROPS_CATEGORY_ENCOUNTER"] = "Bosse"
L["DROPS_CATEGORY_TREASURE"] = "Schaetze"

-- Drop source display
L["DROPS_DECOR_ID"] = "Dekor #%d"

--------------------------------------------------------------------------------
-- Professions Tab
--------------------------------------------------------------------------------
L["PROFESSIONS_SEARCH_PLACEHOLDER"] = "Berufe oder Objekte suchen..."
L["PROFESSIONS_FILTER_ALL"] = "Alle"
L["PROFESSIONS_FILTER_INCOMPLETE"] = "Unvollstaendig"
L["PROFESSIONS_FILTER_COMPLETE"] = "Abgeschlossen"
L["PROFESSIONS_EMPTY_NO_SOURCES"] = "Keine Herstellungsquellen"
L["PROFESSIONS_EMPTY_NO_SOURCES_DESC"] = "Herstellungsquelldaten sind noch nicht verfuegbar."
L["PROFESSIONS_SELECT_PROFESSION"] = "Waehle einen Beruf"
L["PROFESSIONS_EMPTY_NO_RESULTS"] = "Keine Ergebnisse"

--------------------------------------------------------------------------------
-- Treasure Hunt Waypoints
--------------------------------------------------------------------------------
L["TREASURE_HUNT_WAYPOINT_SET"] = "Schatz markiert bei"

--------------------------------------------------------------------------------
-- Progress Tab
--------------------------------------------------------------------------------
L["TAB_PROGRESS"] = "FORTSCHRITT"
L["TAB_PROGRESS_DESC"] = "Uebersicht ueber den Sammlungsfortschritt"
L["PROGRESS_COLLECTED"] = "Gesammelt"
L["PROGRESS_TOTAL"] = "Gesamt"
L["PROGRESS_REMAINING"] = "Verbleibend"
L["PROGRESS_BY_SOURCE"] = "Nach Quelle"
L["PROGRESS_VENDOR_EXPANSIONS"] = "Haendler-Erweiterungen"
L["PROGRESS_QUEST_EXPANSIONS"] = "Quest-Erweiterungen"
L["PROGRESS_PROFESSIONS"] = "Berufe"
L["PROGRESS_ALMOST_THERE"] = "Am weitesten fortgeschritten"
L["PROGRESS_OVERVIEW"] = "FORTSCHRITTSUEBERSICHT"
L["PROGRESS_ALL_DECOR_COLLECTED"] = "Alles Dekor gesammelt"
L["PROGRESS_SOURCE_ALL"] = "Alles Dekor"
L["PROGRESS_SOURCE_VENDORS"] = "Haendler"
L["PROGRESS_SOURCE_QUESTS"] = "Quests"
L["PROGRESS_SOURCE_ACHIEVEMENTS"] = "Erfolge"
L["PROGRESS_SOURCE_PROFESSIONS"] = "Berufe"
L["PROGRESS_SOURCE_PVP"] = "PvP"
L["PROGRESS_LOADING"] = "Fortschrittsdaten werden geladen..."

--------------------------------------------------------------------------------
-- Zone Overlay (World Map)
--------------------------------------------------------------------------------
L["ZONE_OVERLAY_VENDORS"] = "Haendler"
L["ZONE_OVERLAY_QUESTS"] = "Quests"
L["ZONE_OVERLAY_TREASURE"] = "Schatzsuchen"
L["ZONE_OVERLAY_COUNT"] = "%d Dekorobjekte in dieser Zone"
L["ZONE_OVERLAY_BUTTON_TOOLTIP"] = "Housing Codex"
L["ZONE_OVERLAY_SHOW"] = "Zonenoverlay anzeigen"
L["ZONE_OVERLAY_PINS"] = "Haendlerkartenpins anzeigen"
L["ZONE_OVERLAY_POSITION"] = "Panelposition"
L["ZONE_OVERLAY_POS_TOPLEFT"] = "Oben links"
L["ZONE_OVERLAY_POS_BOTTOMRIGHT"] = "Unten rechts"
L["ZONE_OVERLAY_TRANSPARENCY"] = "Transparenz"
L["ZONE_OVERLAY_INCLUDE_COLLECTED_VENDORS"] = "Bereits freigeschaltetes Dekor einschliessen"
L["ZONE_OVERLAY_SOURCE_VENDOR"] = "(Haendler)"
L["ZONE_OVERLAY_SOURCE_VENDOR_CITY"] = "(Haendler in |cFFFF8C00%s|r)"
L["ZONE_OVERLAY_CLICK_WAYPOINT"] = "Linksklick, um einen Kartenpin zu setzen"
L["ZONE_OVERLAY_CLICK_OPEN_HC"] = "Rechtsklick, um in Housing Codex zu oeffnen"
L["ZONE_OVERLAY_PREVIEW_SIZE"] = "Vorschaugroesse"
L["ZONE_OVERLAY_SECTION_HEADER"] = "Zonenoverlay"
L["VENDOR_PINS_SECTION_HEADER"] = "Haendlerkartenpins"
L["VENDOR_PINS_TRANSPARENCY"] = "Pin-Transparenz"
L["VENDOR_PINS_SCALE"] = "Pin-Groesse"
L["VENDOR_PINS_MINIMAL"] = "Nur Symbol (ohne Hintergrund)"
L["VENDOR_PINS_LAYER"] = "Ebene der Kartenpins anpassen"
L["VENDOR_PINS_LAYER_BELOW"] = "Unter anderen Symbolen"
L["VENDOR_PINS_LAYER_ABOVE"] = "Ueber anderen Symbolen"
L["OPTIONS_ZONE_OVERLAY"] = "Zonenoverlay auf der Weltkarte anzeigen"
L["OPTIONS_ZONE_OVERLAY_TOOLTIP"] = "Ein Panel auf der Weltkarte anzeigen, das verfuegbares Dekor fuer die aktuelle Zone zeigt"

--------------------------------------------------------------------------------
-- What's New Popup
--------------------------------------------------------------------------------
L["WHATSNEW_TITLE"] = "Neu in Housing Codex"
L["WHATSNEW_DONT_SHOW"] = "Fuer v%s nicht erneut anzeigen"
L["WHATSNEW_EXPLORE"] = "Housing Codex entdecken"
L["WHATS_NEW_NO_IMAGE"] = "Screenshot"

--------------------------------------------------------------------------------
-- Welcome Popup
--------------------------------------------------------------------------------
L["WELCOME_TITLE"] = "Willkommen bei Housing Codex"
L["WELCOME_SUBTITLE"] = "Dein Begleiter fuer Dekorentdeckung und alles rund ums Housing"
L["WELCOME_START"] = "Entdecken starten"
L["WELCOME_QUICK_SETUP"] = "Gut zu wissen"
L["WELCOME_OPEN_WITH"] = "Du kannst das Addon jederzeit oeffnen ueber"
L["WELCOME_SET_KEYBIND"] = "oder indem du deine eigene Tastenbelegung festlegst in"
L["WELCOME_KEYBIND_LABEL"] = "Optionen"

--------------------------------------------------------------------------------
-- What's New: v1.5.0 feature highlights
--------------------------------------------------------------------------------
L["WHATSNEW_V150_F1_TITLE"] = "Sammlungsuebersicht"
L["WHATSNEW_V150_F1_DESC"] = "Sieh deinen Dekor-Sammlungsfortschritt auf einen Blick -- Gesamtstatistiken, nach Quellentyp und am weitesten fortgeschrittene Kategorien."
L["WHATSNEW_V150_F2_TITLE"] = "Berufsverfolgung"
L["WHATSNEW_V150_F2_DESC"] = "Verfolge den Herstellungsfortschritt jedes Berufs mit eigenen Fortschrittsbalken."
L["WHATSNEW_V150_F3_TITLE"] = "Intelligente Navigation"
L["WHATSNEW_V150_F3_DESC"] = "Klicke auf eine beliebige Fortschrittszeile, um direkt zum entsprechenden Quellen-Tab zu springen."
L["WHATSNEW_V150_F4_TITLE"] = "Klickbare Wunschlisten-Links"
L["WHATSNEW_V150_F4_DESC"] = "Teile Wunschlistenobjekte im Chat als klickbare Links, die andere in der Vorschau ansehen koennen."

--------------------------------------------------------------------------------
-- Welcome feature highlights
--------------------------------------------------------------------------------
L["WELCOME_F1_TITLE"] = "Interaktive 3D-Vorschau"
L["WELCOME_F1_DESC"] = "Sieh dir beliebiges Dekor in 3D an: drehen, zoomen und die Vorschaugroesse anpassen."
L["WELCOME_F2_TITLE"] = "Dekorkatalog & Raster"
L["WELCOME_F2_DESC"] = "Durchstoebere den vollstaendigen Katalog in einem anpassbaren Raster mit schneller Suche und Filtern."
L["WELCOME_F3_TITLE"] = "Quellen & Entdeckung"
L["WELCOME_F3_DESC"] = "Sieh, wo du fehlendes Dekor erhaeltst: Quests, Erfolge, Haendler, Beute, Berufe."
L["WELCOME_F4_TITLE"] = "Haendlerindikatoren"
L["WELCOME_F4_DESC"] = "Die Haendleroberflaeche zeigt Dekorsymbole, damit Sammlerstuecke sofort auffallen."
L["WELCOME_F5_TITLE"] = "Kartenintegration"
L["WELCOME_F5_DESC"] = "Kartenpins zeigen die Standorte von Dekor-Haendlern, und ein Zonenoverlay weist auf fehlendes Dekor hin."
L["WELCOME_F6_TITLE"] = "Sammlungsfortschritt"
L["WELCOME_F6_DESC"] = "Fortschrittsbalken zeigen deinen Sammlungsstand je Kategorie auf einen Blick."

--------------------------------------------------------------------------------
-- Endeavors Panel
--------------------------------------------------------------------------------
L["ENDEAVORS_TITLE"] = "Endeavors"
L["ENDEAVORS_OPTIONS"] = "Endeavors-Optionen"
L["ENDEAVORS_OPTIONS_TOOLTIP"] = "Das Endeavors-Overlaypanel konfigurieren"
L["ENDEAVORS_MAX_LEVEL"] = "MAX"
L["ENDEAVORS_PROGRESS_FORMAT"] = "Fortschritt: %d / %d"
L["ENDEAVORS_YOUR_CONTRIBUTION"] = "Dein Beitrag: %d"
L["ENDEAVORS_MILESTONES"] = "Meilensteine"
L["ENDEAVORS_OPT_SECTION_GENERAL"]  = "Allgemein"
L["ENDEAVORS_OPT_SECTION_HOUSE_XP"] = "Haus-EP"
L["ENDEAVORS_OPT_SECTION_ENDEAVOR"] = "Endeavor-Fortschritt"
L["ENDEAVORS_OPT_SECTION_SIZE"]     = "Panelgroesse"
L["ENDEAVORS_OPT_SHOW_HOUSE_XP"] = "Haus-EP-Leiste anzeigen"
L["ENDEAVORS_OPT_SHOW_HOUSE_XP_TIP"] = "Hausstufe und EP-Fortschrittsleiste anzeigen"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR"] = "Endeavor-Fortschrittsleiste anzeigen"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TIP"] = "Fortschrittsleiste der Nachbarschafts-Endeavors anzeigen"
L["ENDEAVORS_OPT_SHOW_XP_TEXT"] = "Text auf EP-Leiste anzeigen"
L["ENDEAVORS_OPT_SHOW_XP_TEXT_TIP"] = "Zahlenwerte auf der Haus-EP-Leiste anzeigen"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT"] = "Text auf Endeavor-Leiste anzeigen"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT_TIP"] = "Zahlenwerte auf der Endeavor-Fortschrittsleiste anzeigen"
L["ENDEAVORS_OPT_SHOW_XP_PCT"] = "Prozentwert auf EP-Leiste anzeigen"
L["ENDEAVORS_OPT_SHOW_XP_PCT_TIP"] = "Prozentwert auf der Haus-EP-Leiste anzeigen"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_PCT"] = "Prozentwert auf Endeavor-Leiste anzeigen"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_PCT_TIP"] = "Prozentwert auf der Endeavor-Fortschrittsleiste anzeigen"
L["ENDEAVORS_XP_TOOLTIP_TITLE"] = "Fortschritt der Hausstufe"
L["ENDEAVORS_XP_TOOLTIP_LEVEL"] = "Hausstufe: %d"
L["ENDEAVORS_XP_TOOLTIP_LEVEL_MAX"] = "Hausstufe: %d (Max)"
L["ENDEAVORS_XP_TOOLTIP_PROGRESS"] = "EP: %s / %s (%d%%)"
L["ENDEAVORS_XP_TOOLTIP_CLICK"] = "Klicken, um das Housing-Dashboard zu oeffnen"
L["ENDEAVORS_TOOLTIP_CLICK"] = "Klicken, um Endeavors zu oeffnen"
L["ENDEAVORS_PCT_DONE"] = "FERTIG"
L["OPTIONS_SECTION_ENDEAVORS"] = "Endeavors"
L["OPTIONS_ENDEAVORS_ENABLED"] = "Endeavors-Panel aktivieren"
L["OPTIONS_ENDEAVORS_ENABLED_TOOLTIP"] = "Das Endeavors-Minipanel anzeigen, wenn du dich in einer Nachbarschaft mit Haus befindest"
L["ENDEAVORS_OPT_ENABLED"] = "Endeavors-Panel aktivieren"
L["ENDEAVORS_OPT_ENABLED_TIP"] = "Das Endeavors-Panel anzeigen, wenn du dich in einer Nachbarschaft mit Haus befindest"
L["ENDEAVORS_COMPLETED_TIMES"] = "%d |4Mal:Mal; abgeschlossen"
L["ENDEAVORS_TIME_DAYS_LEFT"] = "%d |4Tag:Tage; uebrig"
L["ENDEAVORS_TIME_HOURS_LEFT"] = "%d |4Stunde:Stunden; uebrig"
L["ENDEAVORS_COUPONS_EARNED"] = "%d/%d %s fuer dieses Endeavor verdient"
L["ENDEAVORS_OPT_SCALE"] = "Panelgroesse"
L["ENDEAVORS_OPT_SCALE_TIP"] = "Die Groesse des Endeavors-Panels aendern"
L["ENDEAVORS_OPT_SCALE_SMALL"] = "Klein"
L["ENDEAVORS_OPT_SCALE_NORMAL"] = "Normal"
L["ENDEAVORS_OPT_SCALE_BIG"] = "Gross"
L["ENDEAVORS_MILESTONE_COMPLETED"] = "abgeschlossen"

--------------------------------------------------------------------------------
-- PvP Tab
--------------------------------------------------------------------------------
L["TAB_PVP"] = "PVP"
L["TAB_PVP_DESC"] = "PvP-Quellen fuer Housing-Dekorobjekte"
L["PVP_SEARCH_PLACEHOLDER"] = "PvP-Quellen oder Objekte suchen..."
L["PVP_FILTER_ALL"] = "Alle"
L["PVP_FILTER_INCOMPLETE"] = "Unvollstaendig"
L["PVP_FILTER_COMPLETE"] = "Abgeschlossen"
L["PVP_CATEGORY_ACHIEVEMENTS"] = "Erfolge"
L["PVP_CATEGORY_VENDORS"] = "Haendler"
L["PVP_CATEGORY_DROPS"] = "Beute"
L["PVP_EMPTY_NO_SOURCES"] = "Keine PvP-Quellen gefunden"
L["PVP_EMPTY_NO_SOURCES_DESC"] = "PvP-Daten sind moeglicherweise nicht verfuegbar"
L["PVP_SELECT_CATEGORY"] = "Waehle eine Kategorie"
L["PVP_EMPTY_NO_RESULTS"] = "Keine PvP-Quellen entsprechen deiner Suche"
L["SETTINGS_CATEGORY_NAME"] = "Housing |cffFB7104Codex|r"

--------------------------------------------------------------------------------
-- Game Entity Names (drop sources, encounter names, treasure locations)
--------------------------------------------------------------------------------
local SN = addon.sourceNameLocale

-- Drops
SN["Darkshore (BfA phase) Rare Drop"] = "Seltener Beutedrop an der Dunkelkueste (BfA-Phase)"
SN["Highmountain Tauren Paragon Chest"] = "Paragontruhe der Tauren von Hochberg"
SN["Login Reward (Midnight)"] = "Login-Belohnung (Midnight)"
SN["Midnight Delves"] = "Midnight-Tiefen"
SN["Self-Assembling Homeware Kit (Mechagon)"] = "Selbstmontierendes Haushaltsset (Mechagon)"
SN["Shadowmoon Valley (Draenor) Missives"] = "Botschaften aus dem Schattenmondtal (Draenor)"
SN["Strange Recycling Requisition (Mechagon)"] = "Seltsamer Recyclingauftrag (Mechagon)"
SN["Theater Troupe event chest (Isle of Dorn)"] = "Eventtruhe der Theatertruppe (Insel von Dorn)"
SN["Twitch Drop"] = "Twitch-Drop"
SN["Twitch drop (Feb 26 to Mar 24)"] = "Twitch-Drop (26. Feb. bis 24. Maerz)"
SN["Undermine Jobs"] = "Jobs in Lorenhall"
SN["Zillow & Warcraft collab"] = "Zillow- und Warcraft-Kollaboration"
SN["Zillow for Warcraft Promotion"] = "Zillow-fuer-Warcraft-Promotion"

-- Encounters (bosses)
SN["Advisor Melandrus (Court of Stars)"] = "Berater Melandrus (Hof der Sterne)"
SN["Belo'ren, Child of Al'ar"] = "Belo'ren, Kind von Al'ar"
SN["Charonus (Voidscar Arena)"] = "Charonus (Voidscar-Arena)"
SN["Chimaerus the Undreamt God"] = "Chimaerus, der unertraeumte Gott"
SN["Crown of the Cosmos (The Voidspire)"] = "Krone des Kosmos (The Voidspire)"
SN["Dargrul the Underking"] = "Dargrul der Unterkoenig"
SN["Degentrius (Magisters' Terrace)"] = "Degentrius (Terrasse der Magister)"
SN["Echo of Doragosa (Algeth'ar Academy)"] = "Echo von Doragosa (Akademie Algeth'ar)"
SN["Emperor Dagran Thaurissan (Blackrock Depths)"] = "Imperator Dagran Thaurissan (Schwarzfelstiefen)"
SN["Fallen-King Salhadaar (The Voidspire)"] = "Gefallener Koenig Salhadaar (The Voidspire)"
SN["Garrosh Hellscream (Siege of Orgrimmar)"] = "Garrosh Hoellschrei (Schlacht um Orgrimmar)"
SN["Goldie Baronbottom (Cinderbrew Meadery)"] = "Goldie Baronbottom (Cinderbrew Meadery)"
SN["Harlan Sweete (Freehold)"] = "Harlan Sweete (Freihafen)"
SN["High Sage Viryx (Skyreach)"] = "Hochweise Viryx (Himmelsnadel)"
SN["Imperator Averzian (The Voidspire)"] = "Imperator Averzian (The Voidspire)"
SN["King Mechagon"] = "Koenig Mechagon"
SN["Kyrakka and Erkhart Stormvein"] = "Kyrakka und Erkhart Sturmader"
SN["L'ura (The Seat of the Triumvirate)"] = "L'ura (Sitz des Triumvirats)"
SN["Lightblinded Vanguard"] = "Lichtgeblendete Vorhut"
SN["Lithiel Cinderfury (Murder Row)"] = "Lithiel Aschenzorn (Murder Row)"
SN["Lord Godfrey (Shadowfang Keep)"] = "Lord Godfrey (Burg Schattenfang)"
SN["Lothraxion (Nexus-Point Xenas)"] = "Lothraxion (Nexus-Punkt Xenas)"
SN["Midnight Falls (March on Quel'Danas)"] = "Midnight Falls (Marsch auf Quel'Danas)"
SN["Nalorakk"] = "Nalorakk"
SN["Prioress Murrpray (Priory of the Sacred Flame)"] = "Priorin Murrpray (Priorat der Heiligen Flamme)"
SN["Rak'tul, Vessel of Souls"] = "Rak'tul, Gefaess der Seelen"
SN["Scourgelord Tyrannus (Pit of Saron)"] = "Geisselfuerst Tyrannus (Grube von Saron)"
SN["Sha of Doubt (Temple of the Jade Serpent)"] = "Sha des Zweifels (Tempel der Jadeschlange)"
SN["Shade of Xavius (Darkheart Thicket)"] = "Schatten von Xavius (Finsterherzdickicht)"
SN["Skulloc (Iron Docks)"] = "Skulloc (Eiserne Docks)"
SN["Spellblade Aluriel (The Nighthold)"] = "Zauberklinge Aluriel (Die Nachtfestung)"
SN["Teron'gor"] = "Teron'gor"
SN["The Darkness"] = "Die Dunkelheit"
SN["The Restless Cabal"] = "Die rastlose Kabale"
SN["The Restless Heart"] = "Das rastlose Herz"
SN["Vaelgor & Ezzorak"] = "Vaelgor & Ezzorak"
SN["Vanessa VanCleef"] = "Vanessa VanCleef"
SN["Viz'aduum the Watcher (Karazhan)"] = "Viz'aduum der Waechter (Karazhan)"
SN["Vol'zith the Whisperer (Shrine of the Storm)"] = "Vol'zith der Fluesterer (Schrein des Sturms)"
SN["Vorasius (The Voidspire)"] = "Vorasius (The Voidspire)"
SN["Warlord Sargha (Neltharus)"] = "Kriegsherrin Sargha (Neltharus)"
SN["Warlord Zaela"] = "Kriegsherrin Zaela"
SN["Ziekket (The Blinding Vale)"] = "Ziekket (The Blinding Vale)"

-- Treasures
SN["Gift of the Phoenix (Eversong Woods)"] = "Gabe des Phoenix (Immersangwald)"
SN["Golden Cloud Serpent Treasure Chest (Jade Forest)"] = "Schatztruhe der goldenen Wolkenschlange (Jadewald)"
SN["Incomplete Book of Sonnets (Eversong Woods)"] = "Unvollstaendiges Sonettenbuch (Immersangwald)"
SN["Malignant Chest (Voidstorm)"] = "Boesartige Truhe (Nethersturm)"
SN["Stellar Stash (Slayer's Rise)"] = "Sternenvorrat (Slayer's Rise)"
SN["Stone Vat (Eversong Woods)"] = "Steinbottich (Immersangwald)"
SN["Triple-Locked Safebox (Eversong Woods)"] = "Dreifach verschlossene Kassette (Immersangwald)"
SN["Undermine"] = "Lorenhall"
SN["World Glimmering Treasure Chest Drop"] = "Weltweiter Drop einer schimmernden Schatztruhe"

-- Manual quest title translations (quests without quest IDs)
local QT = addon.questTitleLocale
QT["Cheese for Glowergold"] = "Kaese fuer Glowergold"
QT["Spare A Chair"] = "Ein Stuhl uebrig"
QT["Dreamy Inspiration"] = "Vertraeumte Inspiration"
QT["Last Light"] = "Letztes Licht"
QT["Draconic Decor"] = "Drachen-Dekor"

-- Keybinding globals (must be set per-locale since enUS sets them before locale files override L values)
BINDING_HEADER_HCODEX = L["KEYBIND_HEADER"]
BINDING_NAME_HOUSINGCODEX_TOGGLE = L["KEYBIND_TOGGLE"]
