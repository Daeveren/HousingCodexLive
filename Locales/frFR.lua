--[[
    Housing Codex - frFR.lua
    French localization
]]

if GetLocale() ~= "frFR" then return end

local _, addon = ...

local L = addon.L

--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------
L["ADDON_NAME"] = "Housing Codex"
L["KEYBIND_HEADER"] = "|cffffd100Housing|r |cffff8000Codex|r"
L["KEYBIND_TOGGLE"] = "|cffff8000Housing Codex|r Afficher/Masquer"
L["LOADING"] = "Chargement..."
L["LOADING_DATA"] = "Chargement des données de décor..."
L["LOADED_MESSAGE"] = "|cFF88EE88%.1f%%|r des décors collectés. Tapez |cFF88BBFF/hc|r pour ouvrir."
L["COMBAT_LOCKDOWN_MESSAGE"] = "Impossible d'ouvrir en combat"

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------
L["TAB_DECOR"] = "DÉCOR"
L["TAB_QUESTS"] = "QUÊTES"
L["TAB_ACHIEVEMENTS"] = "HAUTS FAITS"
L["TAB_VENDORS"] = "MARCHANDS"
L["TAB_DROPS"] = "BUTINS"
L["TAB_PROFESSIONS"] = "MÉTIERS"
L["TAB_ACHIEVEMENTS_SHORT"] = "HF..."
L["TAB_PROFESSIONS_SHORT"] = "MÉT..."
L["TAB_PROGRESS_SHORT"] = "PROG..."
L["TAB_DECOR_DESC"] = "Parcourir et rechercher tous les objets de décor"
L["TAB_QUESTS_DESC"] = "Sources de quêtes pour les objets de décor"
L["TAB_ACHIEVEMENTS_DESC"] = "Sources de hauts faits pour les objets de décor"
L["TAB_VENDORS_DESC"] = "Emplacements des marchands pour les objets de décor"
L["TAB_DROPS_DESC"] = "Sources de butin pour les objets de décor"
L["TAB_PROFESSIONS_DESC"] = "Objets de décor fabriqués"

--------------------------------------------------------------------------------
-- Search & Filters
--------------------------------------------------------------------------------
L["SEARCH_PLACEHOLDER"] = "Rechercher..."
L["FILTER_ALL"] = "Tous les objets"
L["FILTER_COLLECTED"] = "Collectés"
L["FILTER_NOT_COLLECTED"] = "Non collectés"
L["FILTER_TRACKABLE"] = "Suivables uniquement"
L["FILTER_NOT_TRACKABLE"] = "Non suivables"
L["FILTER_TRACKABLE_HEADER"] = "Suivable"
L["FILTER_TRACKABLE_ALL"] = "Tous"
L["FILTER_INDOORS"] = "Intérieur"
L["FILTER_OUTDOORS"] = "Extérieur"
L["FILTER_DYEABLE"] = "Teignable"
L["FILTER_FIRST_ACQUISITION"] = "Bonus de première acquisition"
L["FILTER_WISHLIST_ONLY"] = "Liste de souhaits uniquement"
L["FILTERS"] = "Filtres"
L["CHECK_ALL"] = "Tout cocher"
L["UNCHECK_ALL"] = "Tout décocher"

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------
L["SIZE_LABEL"] = "Taille :"
L["SORT_BY_LABEL"] = "Trier"

--------------------------------------------------------------------------------
-- Sort
--------------------------------------------------------------------------------
L["SORT_NEWEST"] = "Récents"
L["SORT_ALPHABETICAL"] = "A-Z"
L["SORT_SIZE"] = "Taille"
L["SORT_QUANTITY"] = "Qté possédée"
L["SORT_PLACED"] = "Qté placée"
L["SORT_NEWEST_TIP"] = "Décors ajoutés le plus récemment en premier"
L["SORT_ALPHABETICAL_TIP"] = "Ordre alphabétique (A à Z)"
L["SORT_SIZE_TIP"] = "Plus grands décors en premier (Énorme à Minuscule)"
L["SORT_QUANTITY_TIP"] = "Plus de copies possédées en premier"
L["SORT_PLACED_TIP"] = "Plus de décors placés dans votre maison en premier"

--------------------------------------------------------------------------------
-- Result Count & Empty State
--------------------------------------------------------------------------------
L["RESULT_COUNT_ALL"] = "%d objets affichés"
L["RESULT_COUNT_FILTERED"] = "%d sur %d objets affichés"
L["RESULT_COUNT_TOOLTIP_UNIQUE"] = "Décors uniques collectés : %d / %d (%.1f%%)"
L["RESULT_COUNT_TOOLTIP_ROOMS"] = "Pièces débloquées : %d / %d"
L["RESULT_COUNT_TOOLTIP_OWNED"] = "Total décors possédés : %d"
L["RESULT_COUNT_TOOLTIP_TOTAL"] = "Total objets : %d (%d décors, %d pièces)"
L["EMPTY_STATE_MESSAGE"] = "Aucun objet ne correspond à vos filtres"
L["RESET_FILTERS"] = "Réinitialiser les filtres"

--------------------------------------------------------------------------------
-- Category Navigation
--------------------------------------------------------------------------------
L["CATEGORY_ALL"] = "Tous"
L["CATEGORY_BACK"] = "Retour"
L["CATEGORY_ALL_IN"] = "Tous les %s"

--------------------------------------------------------------------------------
-- Details Panel
--------------------------------------------------------------------------------
L["DETAILS_NO_SELECTION"] = "Sélectionnez un objet"
L["DETAILS_OWNED"] = "Possédé : %d"
L["DETAILS_PLACED"] = "Placé : %d"
L["DETAILS_NOT_OWNED"] = "Non possédé"
L["DETAILS_SIZE"] = "Taille :"
L["DETAILS_PLACE"] = "Emplacement :"
L["DETAILS_DYEABLE"] = "Teignable"
L["DETAILS_NOT_DYEABLE"] = "Non teignable"
L["DETAILS_SOURCE_UNKNOWN"] = "Source inconnue"
L["UNKNOWN"] = "Inconnu"

-- Size names
L["SIZE_TINY"] = "Minuscule"
L["SIZE_SMALL"] = "Petit"
L["SIZE_MEDIUM"] = "Moyen"
L["SIZE_LARGE"] = "Grand"
L["SIZE_HUGE"] = "Énorme"

-- Placement types
L["PLACEMENT_IN"] = "Int."
L["PLACEMENT_OUT"] = "Ext."

--------------------------------------------------------------------------------
-- Wishlist
--------------------------------------------------------------------------------
L["WISHLIST_ADD"] = "Ajouter à la liste de souhaits"
L["WISHLIST_REMOVE"] = "Retirer de la liste de souhaits"
L["WISHLIST_ADDED"] = "Ajouté à la liste de souhaits : %s"
L["WISHLIST_REMOVED"] = "Retiré de la liste de souhaits : %s"
L["WISHLIST_BUTTON"] = "SOUHAITS"
L["WISHLIST_BUTTON_TOOLTIP"] = "Voir votre liste de souhaits"
L["CODEX_BUTTON"] = "HOUSING CODEX"
L["CODEX_BUTTON_TOOLTIP"] = "Retour à l'interface principale"
L["WISHLIST_TITLE"] = "Liste de souhaits"
L["WISHLIST_EMPTY"] = "Votre liste de souhaits est vide"
L["WISHLIST_EMPTY_DESC"] = "Ajoutez des objets en cliquant sur l'étoile dans les onglets Décor ou Quêtes"
L["WISHLIST_SHIFT_CLICK"] = "Maj+Clic pour ajouter/retirer de la liste de souhaits"

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------
L["ACTION_TRACK"] = "Suivre"
L["ACTION_UNTRACK"] = "Ne plus suivre"
L["ACTION_LINK"] = "Lien"
L["ACTION_TRACK_TOOLTIP"] = "Suivre cet objet dans le suivi d'objectifs"
L["ACTION_UNTRACK_TOOLTIP"] = "Arrêter de suivre cet objet"
L["ACTION_TRACK_DISABLED_TOOLTIP"] = "Cet objet ne peut pas être suivi"
L["ACTION_LINK_TOOLTIP"] = "Insérer le lien de l'objet dans le chat"
L["ACTION_LINK_TOOLTIP_RIGHTCLICK"] = "Clic droit : Copier l'URL Wowhead"
L["TRACKING_ERROR_MAX"] = "Impossible de suivre : nombre maximum d'objets suivis atteint"
L["TRACKING_ERROR_UNTRACKABLE"] = "Cet objet ne peut pas être suivi"
L["TRACKING_STARTED"] = "Suivi activé : %s"
L["TRACKING_STOPPED"] = "Suivi arrêté : %s"
L["TOOLTIP_SHIFT_CLICK_TRACK"] = "Maj-clic pour suivre"
L["TOOLTIP_SHIFT_CLICK_UNTRACK"] = "Maj-clic pour ne plus suivre"
L["TRACKING_ERROR_GENERIC"] = "Échec du suivi"
L["LINK_ERROR"] = "Impossible de créer le lien de l'objet"
L["LINK_INSERTED"] = "Lien inséré dans le chat"

--------------------------------------------------------------------------------
-- Preview
--------------------------------------------------------------------------------
L["PREVIEW_NO_MODEL"] = "Aucun modèle 3D disponible"
L["PREVIEW_NO_SELECTION"] = "Sélectionnez un objet pour le prévisualiser"
L["PREVIEW_ERROR"] = "Erreur de chargement du modèle"
L["PREVIEW_NOT_IN_CATALOG"] = "Pas encore dans le catalogue de logement"

--------------------------------------------------------------------------------
-- Settings (WoW Native Settings UI)
--------------------------------------------------------------------------------
L["OPTIONS_SECTION_DISPLAY"] = "Affichage"
L["OPTIONS_SECTION_MAP_NAV"]  = "Carte et navigation"
L["OPTIONS_SECTION_VENDOR"] = "Marchand"
L["OPTIONS_SHOW_COLLECTED"] = "Afficher les indicateurs de quantité"
L["OPTIONS_SHOW_COLLECTED_TOOLTIP"] = "Afficher les compteurs possédés et placés sur les tuiles"
L["OPTIONS_SHOW_MINIMAP"] = "Afficher le bouton de la minicarte"
L["OPTIONS_SHOW_MINIMAP_TOOLTIP"] = "Afficher le bouton Housing Codex sur la minicarte"
L["OPTIONS_VENDOR_INDICATORS"] = "Marquer les décors chez les marchands"
L["OPTIONS_VENDOR_INDICATORS_TOOLTIP"] = "Afficher l'icône Housing Codex sur les objets de décor chez les marchands"
L["OPTIONS_VENDOR_OWNED_CHECKMARK"] = "Afficher une coche pour les décors possédés"
L["OPTIONS_VENDOR_OWNED_CHECKMARK_TOOLTIP"] = "Afficher une coche verte sur les décors de marchand que vous possédez déjà"
L["OPTIONS_SECTION_CONTAINERS"] = "Sacs et banque"
L["OPTIONS_CONTAINER_INDICATORS"] = "Marquer les décors dans les sacs et la banque"
L["OPTIONS_CONTAINER_INDICATORS_TOOLTIP"] = "Afficher l'icône Housing Codex sur les objets de décor dans vos sacs et votre banque"
L["OPTIONS_CONTAINER_OWNED_CHECKMARK"] = "Afficher une coche pour les décors possédés"
L["OPTIONS_CONTAINER_OWNED_CHECKMARK_TOOLTIP"] = "Afficher une coche verte sur les décors dans les sacs et la banque que vous possédez déjà"
L["OPTIONS_VENDOR_MAP_PINS"] = "Afficher les repères de marchands sur la carte"
L["OPTIONS_VENDOR_MAP_PINS_TOOLTIP"] = "Afficher les repères de marchands sur la carte du monde avec la progression de collection"
L["OPTIONS_TREASURE_HUNT_WAYPOINTS"] = "Point de passage auto pour les chasses au trésor"
L["OPTIONS_TREASURE_HUNT_WAYPOINTS_TOOLTIP"] = "Placer automatiquement un point de passage sur la carte lors de l'acceptation d'une quête de chasse au trésor de décor dans les zones de logement"
L["OPTIONS_USE_TOMTOM"] = "Utiliser TomTom pour les points de passage"
L["OPTIONS_USE_TOMTOM_TOOLTIP"] = "Utiliser les points de passage TomTom au lieu du repère natif quand TomTom est installé"
L["OPTIONS_USE_TOMTOM_NOT_INSTALLED"] = "Utiliser TomTom pour les points de passage (Non installé)"
L["OPTIONS_AUTO_ROTATE_PREVIEW"] = "Rotation auto de l'aperçu 3D"
L["OPTIONS_AUTO_ROTATE_PREVIEW_TOOLTIP"] = "Faire tourner lentement le modèle 3D dans le panneau d'aperçu et la liste de souhaits"
L["OPTIONS_SECTION_BROKER"] = "Bouton minicarte / Affichage du broker"
L["OPTIONS_LDB_UNIQUE"] = "Afficher les décors uniques collectés"
L["OPTIONS_LDB_UNIQUE_TOOLTIP"] = "Afficher le nombre de décors uniques collectés dans le texte du broker minicarte"
L["OPTIONS_LDB_ROOMS"] = "Afficher les pièces débloquées"
L["OPTIONS_LDB_ROOMS_TOOLTIP"] = "Afficher le nombre de pièces débloquées dans le texte du broker minicarte"
L["OPTIONS_LDB_TOTAL_OWNED"] = "Afficher le total de décors possédés"
L["OPTIONS_LDB_TOTAL_OWNED_TOOLTIP"] = "Afficher le total de décors possédés (avec doublons) dans le texte du broker minicarte"
L["OPTIONS_LDB_TOTAL"] = "Afficher le total des objets"
L["OPTIONS_LDB_TOTAL_TOOLTIP"] = "Afficher le nombre total d'objets du catalogue dans le texte du broker minicarte"
L["OPTIONS_RESET_POSITION"] = "Réinitialiser la position de la fenêtre"
L["OPTIONS_RESET_POSITION_TOOLTIP"] = "Réinitialiser la fenêtre au centre de l'écran"
L["OPTIONS_RESET_SIZE"] = "Réinitialiser la taille de la fenêtre"
L["OPTIONS_RESET_SIZE_TOOLTIP"] = "Réinitialiser la fenêtre à sa taille par défaut"
L["OPTIONS_SHOW_WELCOME"] = "Écran d'accueil"
L["OPTIONS_SHOW_WELCOME_TOOLTIP"] = "Afficher l'écran d'accueil"
L["SIZE_RESET"] = "Taille de la fenêtre réinitialisée."

L["OPTIONS_SECTION_KEYBIND"] = "Raccourci"
L["OPTIONS_SECTION_TROUBLESHOOTING"] = "Dépannage"
L["OPTIONS_TOGGLE_KEYBIND"] = "Afficher/Masquer :"
L["OPTIONS_NOT_BOUND"] = "Non assigné"
L["OPTIONS_PRESS_KEY"] = "Appuyez sur une touche..."
L["OPTIONS_UNBIND_TOOLTIP"] = "Clic droit pour désassigner"
L["OPTIONS_KEYBIND_HINT"] = "Cliquez pour définir le raccourci. Clic droit pour effacer. Échap pour annuler."
L["OPTIONS_KEYBIND_CONFLICT"] = "\"%s\" est déjà assigné à \"%s\".\n\nVoulez-vous le réassigner à Housing Codex ?"

--------------------------------------------------------------------------------
-- Slash Command Help
--------------------------------------------------------------------------------
L["HELP_TITLE"] = "Commandes Housing Codex :"
L["HELP_TOGGLE"] = "/hc - Afficher/masquer la fenêtre"
L["HELP_SETTINGS"] = "/hc settings - Ouvrir les options"
L["HELP_RESET"] = "/hc reset - Réinitialiser la position"
L["HELP_RETRY"] = "/hc retry - Réessayer le chargement"
L["HELP_HELP"] = "/hc help - Afficher cette aide"
L["HELP_DEBUG"] = "/hc debug - Activer/désactiver le mode débogage"
L["HELP_STATS"] = "/hc stats - Afficher les compteurs de débogage"

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------
L["SETTINGS_NOT_AVAILABLE"] = "Options pas encore disponibles"
L["RETRYING_DATA_LOAD"] = "Nouvelle tentative de chargement..."
L["DEBUG_MODE_STATUS"] = "Mode débogage : %s"
L["FONT_MODE_STATUS"] = "Police personnalisée : %s"
L["DEBUG_ON"] = "ACTIVÉ"
L["DEBUG_OFF"] = "DÉSACTIVÉ"
L["DATA_NOT_LOADED"] = "Données pas encore chargées"
L["INSPECT_FOUND"] = "Trouvé : %s (ID : %d)"
L["INSPECT_NOT_FOUND"] = "Aucun objet trouvé correspondant à : %s"
L["MAIN_WINDOW_NOT_AVAILABLE"] = "Fenêtre principale pas encore disponible"
L["POSITION_RESET"] = "Position de la fenêtre réinitialisée au centre"

--------------------------------------------------------------------------------
-- Errors
--------------------------------------------------------------------------------
L["ERROR_API_UNAVAILABLE"] = "API de logement non disponibles"
L["ERROR_LOAD_FAILED"] = "Échec du chargement des données après plusieurs tentatives. Utilisez /hc retry pour réessayer."
L["ERROR_LOAD_FAILED_SHORT"] = "Échec du chargement. Utilisez /hc retry"

--------------------------------------------------------------------------------
-- LDB (LibDataBroker)
--------------------------------------------------------------------------------
L["LDB_TOOLTIP_LEFT"] = "|cffffffffClic gauche|r pour afficher/masquer la fenêtre"
L["LDB_TOOLTIP_RIGHT"] = "|cffffffffClic droit|r pour ouvrir les options"
L["LDB_TOOLTIP_ALT"] = "|cffffffffAlt-clic|r pour configurer l'affichage du broker"
L["LDB_OPTIONS_PLACEHOLDER"] = "Panneau d'options pas encore disponible"
L["LDB_POPUP_TITLE"] = "Affichage du broker"
L["LDB_TOOLTIP_DECOR_HEADER"] = "Statistiques de collection"
L["LDB_POPUP_UNIQUE"] = "Décors uniques"
L["LDB_POPUP_ROOMS"] = "Pièces débloquées"
L["LDB_POPUP_TOTAL_OWNED"] = "Total décors possédés"
L["LDB_POPUP_TOTAL_ITEMS"] = "Total des objets"

--------------------------------------------------------------------------------
-- Quests Tab
--------------------------------------------------------------------------------
L["QUESTS_SEARCH_PLACEHOLDER"] = "Rechercher des quêtes, zones ou récompenses..."
L["QUESTS_FILTER_ALL"] = "Toutes"
L["QUESTS_FILTER_INCOMPLETE"] = "Incomplètes"
L["QUESTS_FILTER_COMPLETE"] = "Complètes"
L["QUESTS_EMPTY_NO_SOURCES"] = "Aucune source de quête trouvée"
L["QUESTS_EMPTY_NO_SOURCES_DESC"] = "Les données de quête peuvent ne pas être exposées par l'API WoW"
L["QUESTS_SELECT_EXPANSION"] = "Sélectionnez une extension"
L["QUESTS_EMPTY_NO_RESULTS"] = "Aucune quête ne correspond à votre recherche"
L["QUESTS_UNKNOWN_QUEST"] = "Quête #%d"
L["QUESTS_UNKNOWN_ZONE"] = "Zone inconnue"
L["QUESTS_UNKNOWN_EXPANSION"] = "Autre"

-- Quest tracking messages
L["QUESTS_TRACKING_STARTED"] = "Suivi de l'objet activé"
L["QUESTS_TRACKING_MAX_REACHED"] = "Impossible de suivre - maximum atteint (15)"
L["QUESTS_TRACKING_ALREADY"] = "Cet objet est déjà suivi"
L["QUESTS_TRACKING_FAILED"] = "Impossible de suivre cet objet"

-- Expansion names (official French names from Blizzard)
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
-- Note: Blizzard keeps expansion names in English for all locales (no French equivalents)

--------------------------------------------------------------------------------
-- Achievements Tab
--------------------------------------------------------------------------------
L["ACHIEVEMENTS_SEARCH_PLACEHOLDER"] = "Rechercher des hauts faits, récompenses ou catégories..."
L["ACHIEVEMENTS_FILTER_ALL"] = "Tous"
L["ACHIEVEMENTS_FILTER_INCOMPLETE"] = "Incomplets"
L["ACHIEVEMENTS_FILTER_COMPLETE"] = "Complétés"
L["ACHIEVEMENTS_EMPTY_NO_SOURCES"] = "Aucune source de haut fait trouvée"
L["ACHIEVEMENTS_EMPTY_NO_SOURCES_DESC"] = "Les données de hauts faits peuvent ne pas être disponibles"
L["ACHIEVEMENTS_SELECT_CATEGORY"] = "Sélectionnez une catégorie"
L["ACHIEVEMENTS_EMPTY_NO_RESULTS"] = "Aucun haut fait ne correspond à votre recherche"
L["ACHIEVEMENTS_UNKNOWN"] = "Haut fait #%d"

-- Achievement tracking messages
L["ACHIEVEMENTS_TRACKING_STARTED"] = "Suivi de l'objet activé"
L["ACHIEVEMENTS_TRACKING_STARTED_ACHIEVEMENT"] = "Suivi du haut fait activé"
L["ACHIEVEMENTS_TRACKING_STOPPED"] = "Suivi du haut fait arrêté"
L["ACHIEVEMENTS_TRACKING_MAX_REACHED"] = "Impossible de suivre - maximum atteint (15)"
L["ACHIEVEMENTS_TRACKING_ALREADY"] = "Cet objet est déjà suivi"
L["ACHIEVEMENTS_TRACKING_FAILED"] = "Impossible de suivre ce haut fait"

--------------------------------------------------------------------------------
-- Context Menu
--------------------------------------------------------------------------------
L["CONTEXT_MENU_LINK_TO_CHAT"] = "Lier dans le chat"
L["CONTEXT_MENU_COPY_WOWHEAD"] = "Copier le lien Wowhead"

--------------------------------------------------------------------------------
-- Vendors Tab
--------------------------------------------------------------------------------
L["VENDORS_SEARCH_PLACEHOLDER"] = "Rechercher des marchands, zones ou objets..."
L["VENDORS_FILTER_ALL"] = "Tous"
L["VENDORS_FILTER_INCOMPLETE"] = "Incomplets"
L["VENDORS_FILTER_COMPLETE"] = "Complétés"
L["VENDORS_CURRENT_ZONE"] = "Zone actuelle"
L["VENDORS_EMPTY_NO_SOURCES"] = "Aucune source de marchand trouvée"
L["VENDORS_EMPTY_NO_SOURCES_DESC"] = "Les données de marchands peuvent ne pas être disponibles"
L["VENDORS_SELECT_EXPANSION"] = "Sélectionnez une extension"
L["VENDORS_UNKNOWN_EXPANSION"] = "Autre"
L["VENDORS_UNKNOWN_ZONE"] = "Zone inconnue"

-- Vendor waypoint messages
L["VENDOR_SET_WAYPOINT"] = "Placer un repère"
L["VENDOR_NO_LOCATION"] = "Emplacement inconnu"
L["VENDOR_WAYPOINT_SET"] = "Repère placé pour %s"
L["VENDOR_MAP_RESTRICTED"] = "Impossible de placer un repère sur cette carte"

-- Vendor fallback names
L["VENDOR_UNKNOWN"] = "Marchand inconnu"
L["VENDOR_FALLBACK_NAME"] = "marchand"

-- Vendor world map pins
L["VENDOR_PIN_COLLECTED"] = "Collectés : %d/%d"
L["VENDOR_PIN_UNCOLLECTED_HEADER"] = "Décors non collectés :"
L["VENDOR_PIN_ITEM_LOCKED"] = "verrouillé"
L["VENDOR_PIN_MORE"] = "+%d autres"
L["VENDOR_PIN_CLICK_WAYPOINT"] = "Cliquez pour placer un repère"
L["VENDOR_PIN_FACTION_ALLIANCE"] = "Alliance uniquement"
L["VENDOR_PIN_FACTION_HORDE"] = "Horde uniquement"
L["VENDOR_PIN_VENDOR_COUNT"] = "%dx Marchands"
L["VENDOR_PIN_VENDOR_LIST_HEADER"] = "Liste des marchands :"
L["VENDOR_PIN_VENDOR_ENTRY"] = "%s (%d/%d)"
L["VENDOR_PIN_VENDORS_MORE"] = "+%d marchands supplémentaires"

-- Vendor tracking messages
L["VENDORS_TRACKING_STARTED"] = "Repère ajouté pour %s dans %s"
L["VENDORS_TRACKING_STOPPED"] = "Repère retiré pour %s dans %s"
L["VENDORS_ACTION_TRACK"] = "Repère"
L["VENDORS_ACTION_UNTRACK"] = "Retirer le repère"
L["VENDORS_ACTION_TRACK_TOOLTIP"] = "Placer un repère sur la carte vers ce marchand"
L["VENDORS_ACTION_UNTRACK_TOOLTIP"] = "Retirer le repère du marchand"
L["VENDORS_ACTION_TRACK_DISABLED_TOOLTIP"] = "Ce marchand n'a pas d'emplacement valide"

-- Vendor cost display
L["CURRENCY_GOLD"] = "or"
-- Vendor decor fallback
L["VENDORS_DECOR_ID"] = "Décor #%d"
L["VENDOR_CAT_ACCENTS"] = "Accents"
L["VENDOR_CAT_FUNCTIONAL"] = "Fonctionnel"
L["VENDOR_CAT_FURNISHINGS"] = "Mobilier"
L["VENDOR_CAT_LIGHTING"] = "Éclairage"
L["VENDOR_CAT_MISCELLANEOUS"] = "Divers"
L["VENDOR_CAT_NATURE"] = "Nature"
L["VENDOR_CAT_STRUCTURAL"] = "Structure"
L["VENDOR_CAT_UNCATEGORIZED"] = "Non classé"

-- Vendor zone annotations
L["VENDOR_CLASS_HALL_SUFFIX"] = "fief de classe"
L["VENDOR_HOUSING_ZONE_SUFFIX"] = "zone de logement"
L["VENDOR_CLASS_ONLY_SUFFIX"] = "%s uniquement"

-- Vendor tooltip overlay
L["OPTIONS_VENDOR_TOOLTIPS"] = "Afficher les décors dans les infobulles des marchands"
L["OPTIONS_VENDOR_TOOLTIPS_TOOLTIP"] = "Afficher la progression de collection Housing Codex au survol des PNJ marchands de décor"

--------------------------------------------------------------------------------
-- Drops Tab
--------------------------------------------------------------------------------
L["DROPS_SEARCH_PLACEHOLDER"] = "Rechercher des sources ou objets..."
L["DROPS_FILTER_ALL"] = "Tous"
L["DROPS_FILTER_INCOMPLETE"] = "Incomplets"
L["DROPS_FILTER_COMPLETE"] = "Complétés"
L["DROPS_EMPTY_NO_SOURCES"] = "Aucune source de butin trouvée"
L["DROPS_EMPTY_NO_SOURCES_DESC"] = "Les données de butin peuvent ne pas être disponibles"
L["DROPS_SELECT_CATEGORY"] = "Sélectionnez une catégorie"
L["DROPS_EMPTY_NO_RESULTS"] = "Aucune source de butin ne correspond a votre recherche"

-- Drop source category labels
L["DROPS_CATEGORY_DROP"] = "Butins"
L["DROPS_CATEGORY_ENCOUNTER"] = "Boss"
L["DROPS_CATEGORY_TREASURE"] = "Trésors"

-- Drop source display
L["DROPS_DECOR_ID"] = "Décor #%d"

--------------------------------------------------------------------------------
-- Professions Tab
--------------------------------------------------------------------------------
L["PROFESSIONS_SEARCH_PLACEHOLDER"] = "Rechercher des métiers ou objets..."
L["PROFESSIONS_FILTER_ALL"] = "Tous"
L["PROFESSIONS_FILTER_INCOMPLETE"] = "Incomplets"
L["PROFESSIONS_FILTER_COMPLETE"] = "Complétés"
L["PROFESSIONS_EMPTY_NO_SOURCES"] = "Aucune source d'artisanat"
L["PROFESSIONS_EMPTY_NO_SOURCES_DESC"] = "Les données d'artisanat ne sont pas encore disponibles."
L["PROFESSIONS_SELECT_PROFESSION"] = "Sélectionnez un métier"
L["PROFESSIONS_EMPTY_NO_RESULTS"] = "Aucun résultat"

--------------------------------------------------------------------------------
-- Treasure Hunt Waypoints
--------------------------------------------------------------------------------
L["TREASURE_HUNT_WAYPOINT_SET"] = "Trésor marqué à"

--------------------------------------------------------------------------------
-- Progress Tab
--------------------------------------------------------------------------------
L["TAB_PROGRESS"] = "PROGRESSION"
L["TAB_PROGRESS_DESC"] = "Aperçu de la progression de collection"
L["PROGRESS_COLLECTED"] = "Collectés"
L["PROGRESS_TOTAL"] = "Total"
L["PROGRESS_REMAINING"] = "Restants"
L["PROGRESS_BY_SOURCE"] = "Par source"
L["PROGRESS_VENDOR_EXPANSIONS"] = "Marchands par extension"
L["PROGRESS_QUEST_EXPANSIONS"] = "Quêtes par extension"
L["PROGRESS_RENOWN_EXPANSIONS"] = "Renom par extension"
L["PROGRESS_PROFESSIONS"] = "Métiers"
L["PROGRESS_ALMOST_THERE"] = "Les plus avancés"
L["PROGRESS_OVERVIEW"] = "APERÇU DE LA PROGRESSION"
L["PROGRESS_ALL_DECOR_COLLECTED"] = "Tous les décors collectés"
L["PROGRESS_SOURCE_ALL"] = "Tous les décors"
L["PROGRESS_SOURCE_VENDORS"] = "Marchands"
L["PROGRESS_SOURCE_QUESTS"] = "Quêtes"
L["PROGRESS_SOURCE_ACHIEVEMENTS"] = "Hauts faits"
L["PROGRESS_SOURCE_PROFESSIONS"] = "Métiers"
L["PROGRESS_SOURCE_PVP"] = "JcJ"
L["PROGRESS_SOURCE_DROPS"] = "Butins"
L["PROGRESS_SOURCE_RENOWN"] = "Renom"
L["PROGRESS_LOADING"] = "Chargement des données de progression..."

--------------------------------------------------------------------------------
-- Zone Overlay (World Map)
--------------------------------------------------------------------------------
L["ZONE_OVERLAY_VENDORS"] = "Marchands"
L["ZONE_OVERLAY_QUESTS"] = "Quêtes"
L["ZONE_OVERLAY_TREASURE"] = "Chasses au trésor"
L["ZONE_OVERLAY_COUNT"] = "%d décors dans cette zone"
L["ZONE_OVERLAY_BUTTON_TOOLTIP"] = "Housing Codex"
L["ZONE_OVERLAY_SHOW"] = "Afficher la superposition de zone"
L["ZONE_OVERLAY_PINS"] = "Afficher les repères de marchands"
L["ZONE_OVERLAY_POSITION"] = "Position du panneau"
L["ZONE_OVERLAY_POS_TOPLEFT"] = "Haut-gauche"
L["ZONE_OVERLAY_POS_BOTTOMRIGHT"] = "Bas-droite"
L["ZONE_OVERLAY_TRANSPARENCY"] = "Transparence"
L["ZONE_OVERLAY_INCLUDE_COLLECTED_VENDORS"] = "Inclure les décors déjà débloqués"
L["ZONE_OVERLAY_SOURCE_VENDOR"] = "(Marchand)"
L["ZONE_OVERLAY_SOURCE_VENDOR_CITY"] = "(Marchand à |cFFFF8C00%s|r)"
L["ZONE_OVERLAY_CLICK_WAYPOINT"] = "Clic gauche pour placer un repère"
L["ZONE_OVERLAY_CLICK_OPEN_HC"] = "Clic droit pour ouvrir dans Housing Codex"
L["ZONE_OVERLAY_PREVIEW_SIZE"] = "Taille de l'aperçu"
L["ZONE_OVERLAY_SECTION_HEADER"] = "Superposition de zone"
L["ZONE_OVERLAY_COLLAPSED_TOOLTIP"] = "Cliquez pour voir les décors de cette zone"
L["VENDOR_PINS_SECTION_HEADER"] = "Repères de marchands"
L["VENDOR_PINS_TRANSPARENCY"] = "Transparence des repères"
L["VENDOR_PINS_SCALE"] = "Taille des repères"
-- VENDOR_PINS_LAYER removed: custom frame levels tainted WorldMapFrame (WoWUIBugs #811)
L["OPTIONS_ZONE_OVERLAY"] = "Afficher la superposition de zone sur la carte du monde"
L["OPTIONS_ZONE_OVERLAY_TOOLTIP"] = "Afficher un panneau sur la carte du monde montrant les décors disponibles dans la zone actuelle"

--------------------------------------------------------------------------------
-- What's New Popup
--------------------------------------------------------------------------------
L["WHATSNEW_TITLE"] = "Nouveautés de Housing Codex"
L["WHATSNEW_DONT_SHOW"] = "Ne plus afficher pour la v%s"
L["WHATSNEW_EXPLORE"] = "Explorer Housing Codex"
L["WHATS_NEW_NO_IMAGE"] = "Capture d'écran"

--------------------------------------------------------------------------------
-- Welcome Popup
--------------------------------------------------------------------------------
L["WELCOME_TITLE"] = "Bienvenue dans Housing Codex"
L["WELCOME_SUBTITLE"] = "Votre compagnon pour la découverte de décors et tout ce qui touche au logement"
L["WELCOME_START"] = "Commencer l'exploration"
L["WELCOME_QUICK_SETUP"] = "Bon à savoir"
L["WELCOME_OPEN_WITH"] = "Vous pouvez ouvrir l'addon à tout moment via"
L["WELCOME_SET_KEYBIND"] = "ou en définissant votre propre raccourci dans"
L["WELCOME_KEYBIND_LABEL"] = "Options"

--------------------------------------------------------------------------------
-- What's New: v1.5.0 feature highlights
--------------------------------------------------------------------------------
L["WHATSNEW_V150_F1_TITLE"] = "Tableau de bord de collection"
L["WHATSNEW_V150_F1_DESC"] = "Consultez votre progression de collection en un coup d'œil -- statistiques globales, par type de source, et catégories les plus avancées."
L["WHATSNEW_V150_F2_TITLE"] = "Suivi des métiers"
L["WHATSNEW_V150_F2_DESC"] = "Suivez la progression d'artisanat pour chaque métier avec des barres de progression dédiées."
L["WHATSNEW_V150_F3_TITLE"] = "Navigation intelligente"
L["WHATSNEW_V150_F3_DESC"] = "Cliquez sur une ligne de progression pour accéder directement à l'onglet source correspondant."
L["WHATSNEW_V150_F4_TITLE"] = "Liens de liste de souhaits"
L["WHATSNEW_V150_F4_DESC"] = "Partagez les objets de votre liste de souhaits dans le chat sous forme de liens cliquables."

--------------------------------------------------------------------------------
-- Welcome feature highlights
--------------------------------------------------------------------------------
L["WELCOME_F1_TITLE"] = "Aperçu 3D interactif"
L["WELCOME_F1_DESC"] = "Prévisualisez n'importe quel décor en 3D : rotation, zoom, et redimensionnement."
L["WELCOME_F2_TITLE"] = "Catalogue et grille de décors"
L["WELCOME_F2_DESC"] = "Parcourez le catalogue complet dans une grille personnalisable avec recherche rapide et filtres."
L["WELCOME_F3_TITLE"] = "Sources et découverte"
L["WELCOME_F3_DESC"] = "Découvrez où obtenir les décors manquants : quêtes, hauts faits, marchands, butins, métiers."
L["WELCOME_F4_TITLE"] = "Indicateurs de marchands"
L["WELCOME_F4_DESC"] = "L'interface marchand affiche les icônes de décor pour repérer les objets à collectionner."
L["WELCOME_F5_TITLE"] = "Intégration de la carte"
L["WELCOME_F5_DESC"] = "Des repères sur la carte montrent l'emplacement des marchands de décor, et une superposition indique les décors manquants."
L["WELCOME_F6_TITLE"] = "Progression de collection"
L["WELCOME_F6_DESC"] = "Des barres de progression montrent votre avancement par catégorie en un coup d'œil."

--------------------------------------------------------------------------------
-- Endeavors Panel
--------------------------------------------------------------------------------
L["ENDEAVORS_TITLE"] = "Endeavors"
L["ENDEAVORS_OPTIONS"] = "Options des Endeavors"
L["ENDEAVORS_OPTIONS_TOOLTIP"] = "Configurer le panneau des Endeavors"
L["ENDEAVORS_MAX_LEVEL"] = "MAX"
L["ENDEAVORS_PROGRESS_FORMAT"] = "Progression : %d / %d"
L["ENDEAVORS_YOUR_CONTRIBUTION"] = "Votre contribution : %d"
L["ENDEAVORS_MILESTONES"] = "Jalons"
L["ENDEAVORS_OPT_SECTION_GENERAL"]  = "Général"
L["ENDEAVORS_OPT_SECTION_HOUSE_XP"] = "XP de maison"
L["ENDEAVORS_OPT_SECTION_ENDEAVOR"] = "Progression des Endeavors"
L["ENDEAVORS_OPT_SECTION_SIZE"]     = "Taille du panneau"
L["ENDEAVORS_OPT_SHOW_HOUSE_XP"] = "Afficher la barre d'XP de maison"
L["ENDEAVORS_OPT_SHOW_HOUSE_XP_TIP"] = "Afficher le niveau de maison et la barre de progression d'XP"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR"] = "Afficher la barre des Endeavors"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TIP"] = "Afficher la barre de progression des Endeavors du voisinage"
L["ENDEAVORS_OPT_SHOW_XP_TEXT"] = "Afficher le texte de la barre d'XP"
L["ENDEAVORS_OPT_SHOW_XP_TEXT_TIP"] = "Afficher les valeurs numériques sur la barre d'XP de maison"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT"] = "Afficher le texte de la barre des Endeavors"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT_TIP"] = "Afficher les valeurs numériques sur la barre de progression des Endeavors"
L["ENDEAVORS_OPT_SHOW_XP_PCT"] = "Afficher le pourcentage d'XP"
L["ENDEAVORS_OPT_SHOW_XP_PCT_TIP"] = "Afficher le pourcentage sur la barre d'XP de maison"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_PCT"] = "Afficher le pourcentage des Endeavors"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_PCT_TIP"] = "Afficher le pourcentage sur la barre de progression des Endeavors"
L["ENDEAVORS_XP_TOOLTIP_TITLE"] = "Progression du niveau de maison"
L["ENDEAVORS_XP_TOOLTIP_LEVEL"] = "Niveau de maison : %d"
L["ENDEAVORS_XP_TOOLTIP_LEVEL_MAX"] = "Niveau de maison : %d (Max)"
L["ENDEAVORS_XP_TOOLTIP_PROGRESS"] = "XP : %s / %s (%d%%)"
L["ENDEAVORS_XP_TOOLTIP_CLICK"] = "Cliquez pour ouvrir le tableau de bord de logement"
L["ENDEAVORS_TOOLTIP_CLICK"] = "Cliquez pour ouvrir les Endeavors"
L["ENDEAVORS_PCT_DONE"] = "TERMINÉ"
L["OPTIONS_SECTION_ENDEAVORS"] = "Endeavors"
L["OPTIONS_ENDEAVORS_ENABLED"] = "Activer le panneau des Endeavors"
L["OPTIONS_ENDEAVORS_ENABLED_TOOLTIP"] = "Afficher le mini-panneau des Endeavors dans un voisinage avec une maison"
L["ENDEAVORS_OPT_ENABLED"] = "Activer le panneau des Endeavors"
L["ENDEAVORS_OPT_ENABLED_TIP"] = "Afficher le panneau des Endeavors dans un voisinage avec une maison"
L["ENDEAVORS_COMPLETED_TIMES"] = "Complété %d |4fois:fois;"
L["ENDEAVORS_TIME_DAYS_LEFT"] = "%d |4jour:jours; restant"
L["ENDEAVORS_TIME_HOURS_LEFT"] = "%d |4heure:heures; restant"
L["ENDEAVORS_COUPONS_EARNED"] = "%s: %d/%d"
L["ENDEAVORS_OPT_SCALE"] = "Taille du panneau"
L["ENDEAVORS_OPT_SCALE_TIP"] = "Modifier la taille du panneau des Endeavors"
L["ENDEAVORS_OPT_SCALE_SMALL"] = "Petit"
L["ENDEAVORS_OPT_SCALE_NORMAL"] = "Normal"
L["ENDEAVORS_OPT_SCALE_BIG"] = "Grand"
L["ENDEAVORS_MILESTONE_COMPLETED"] = "terminé"

--------------------------------------------------------------------------------
-- PvP Tab
--------------------------------------------------------------------------------
L["TAB_PVP"] = "JCJ"
L["TAB_PVP_DESC"] = "Sources JcJ pour les objets de décor"
L["PVP_SEARCH_PLACEHOLDER"] = "Rechercher des sources JcJ ou objets..."
L["PVP_FILTER_ALL"] = "Tous"
L["PVP_FILTER_INCOMPLETE"] = "Incomplets"
L["PVP_FILTER_COMPLETE"] = "Complétés"
L["PVP_CATEGORY_ACHIEVEMENTS"] = "Hauts faits"
L["PVP_CATEGORY_VENDORS"] = "Marchands"
L["PVP_CATEGORY_DROPS"] = "Butins"
L["PVP_EMPTY_NO_SOURCES"] = "Aucune source JcJ trouvée"
L["PVP_EMPTY_NO_SOURCES_DESC"] = "Les données JcJ peuvent ne pas être disponibles"
L["PVP_SELECT_CATEGORY"] = "Sélectionnez une catégorie"
L["PVP_EMPTY_NO_RESULTS"] = "Aucune source JcJ ne correspond à votre recherche"
L["SETTINGS_CATEGORY_NAME"] = "Housing |cffFB7104Codex|r"

--------------------------------------------------------------------------------
-- Renown Tab
--------------------------------------------------------------------------------
L["TAB_RENOWN"] = "Renommée"
L["TAB_RENOWN_DESC"] = "Sources de réputation pour les décors"
L["RENOWN_SEARCH_PLACEHOLDER"] = "Rechercher des factions..."
L["RENOWN_FILTER_ALL"] = "Tous"
L["RENOWN_FILTER_INCOMPLETE"] = "Incomplets"
L["RENOWN_FILTER_COMPLETE"] = "Complétés"
L["RENOWN_SELECT_EXPANSION"] = "Sélectionnez une extension"
L["RENOWN_EMPTY_NO_RESULTS"] = "Aucune faction ne correspond à vos filtres"
L["RENOWN_EMPTY_NO_DATA"] = "Les données de réputation sont en cours de chargement..."
L["RENOWN_LOCKED"] = "Pas encore débloqué"
L["RENOWN_REQUIRED"] = "Nécessite %s"
L["RENOWN_REP_MET"] = "Réputation atteinte"
L["RENOWN_CURRENTLY_AT"] = "actuellement à : "
L["RENOWN_NEEDS_ALLIANCE"] = "Nécessite un personnage de l'Alliance"
L["RENOWN_NEEDS_HORDE"] = "Nécessite un personnage de la Horde"
L["RENOWN_WAYPOINT_VENDOR"] = "%s (%s)"
L["RENOWN_PROGRESS_FORMAT"] = "%d/%d"
L["RENOWN_RANK_FORMAT"] = "Rang %d"

--------------------------------------------------------------------------------
-- Game Entity Names (drop sources, encounter names, treasure locations)
--------------------------------------------------------------------------------
local SN = addon.sourceNameLocale

-- Drops
SN["Darkshore (BfA phase) Rare Drop"] = "Butin rare de Sombrivage (phase BfA)"
SN["Highmountain Tauren Paragon Chest"] = "Coffre de parangon des Taurens de Haut-Roc"
SN["Login Reward (Midnight)"] = "Récompense de connexion (Midnight)"
SN["Midnight Delves"] = "Gouffres de Midnight"
SN["Self-Assembling Homeware Kit (Mechagon)"] = "Kit d'ameublement auto-assemblable (Mécagone)"
SN["Shadowmoon Valley (Draenor) Missives"] = "Missives de la vallée de l'Ombre-de-la-Lune (Draenor)"
SN["Strange Recycling Requisition (Mechagon)"] = "Étrange demande de recyclage (Mécagone)"
SN["Theater Troupe event chest (Isle of Dorn)"] = "Coffre de la troupe de théâtre (Île de Dorn)"
SN["Twitch Drop"] = "Récompense Twitch"
SN["Twitch drop (Feb 26 to Mar 24)"] = "Récompense Twitch (26 fév. au 24 mars)"
SN["Undermine Jobs"] = "Travaux de Creux-de-Brasier"
SN["Zillow & Warcraft collab"] = "Collaboration Zillow et Warcraft"
SN["Zillow for Warcraft Promotion"] = "Promotion Zillow pour Warcraft"

-- Encounters (bosses)
SN["Advisor Melandrus (Court of Stars)"] = "Conseiller Melandrus (La Cour des Étoiles)"
SN["Belo'ren, Child of Al'ar"] = "Belo'ren, enfant d'Al'ar"
SN["Charonus (Voidscar Arena)"] = "Charonus (Arène de la Balafre du Vide)"
SN["Chimaerus the Undreamt God"] = "Chimaerus le Dieu non rêvé"
SN["Crown of the Cosmos (The Voidspire)"] = "Couronne du cosmos (La Flèche du Vide)"
SN["Dargrul the Underking"] = "Dargrul le Roi Souterrain"
SN["Degentrius (Magisters' Terrace)"] = "Degentrius (Terrasse des Magistères)"
SN["Echo of Doragosa (Algeth'ar Academy)"] = "Écho de Doragosa (Académie d'Algeth'ar)"
SN["Emperor Dagran Thaurissan (Blackrock Depths)"] = "Empereur Dagran Thaurissan (Profondeurs de Rochenoire)"
SN["Fallen-King Salhadaar (The Voidspire)"] = "Roi déchu Salhadaar (La Flèche du Vide)"
SN["Garrosh Hellscream (Siege of Orgrimmar)"] = "Garrosh Hurlenfer (Siège d'Orgrimmar)"
SN["Goldie Baronbottom (Cinderbrew Meadery)"] = "Doriane Fondubaron (Hydromelerie des Braisebières)"
SN["Harlan Sweete (Freehold)"] = "Harlan Sweete (Port-Franc)"
SN["High Sage Viryx (Skyreach)"] = "Haut-sage Viryx (Haute-Flèche)"
SN["Imperator Averzian (The Voidspire)"] = "Imperator Averzian (La Flèche du Vide)"
SN["King Mechagon"] = "Roi Mécagone"
SN["Kyrakka and Erkhart Stormvein"] = "Kyrakka et Erkhart Cœur-de-tempête"
SN["L'ura (The Seat of the Triumvirate)"] = "L'ura (Le Siège du Triumvirat)"
SN["Lightblinded Vanguard"] = "Avant-garde aveuglée par la lumière"
SN["Lithiel Cinderfury (Murder Row)"] = "Lithiel Furiebraise (Allée du Meurtre)"
SN["Lord Godfrey (Shadowfang Keep)"] = "Seigneur Godfrey (Donjon d'Ombrecroc)"
SN["Lothraxion (Nexus-Point Xenas)"] = "Lothraxion (Point-nexus Xenas)"
SN["Midnight Falls (March on Quel'Danas)"] = "Midnight tombe (Marche sur Quel'Danas)"
SN["Nalorakk"] = "Nalorakk"
SN["Prioress Murrpray (Priory of the Sacred Flame)"] = "Prieure Murrpray (Prieuré de la Flamme sacrée)"
SN["Rak'tul, Vessel of Souls"] = "Rak'tul, Vaisseau des âmes"
SN["Scourgelord Tyrannus (Pit of Saron)"] = "Seigneur du Fléau Tyrannus (Fosse de Saron)"
SN["Sha of Doubt (Temple of the Jade Serpent)"] = "Sha du Doute (Temple du Serpent de jade)"
SN["Shade of Xavius (Darkheart Thicket)"] = "Ombre de Xavius (Fourré Sombrecoeur)"
SN["Skulloc (Iron Docks)"] = "Skulloc (Docks de Fer)"
SN["Spellblade Aluriel (The Nighthold)"] = "Lame-de-sort Aluriel (Le Palais Sacrenuit)"
SN["Teron'gor"] = "Teron'gor"
SN["The Darkness"] = "Les Ténèbres"
SN["The Restless Cabal"] = "La Cabale agitée"
SN["The Restless Heart"] = "Le Cœur agité"
SN["Vaelgor & Ezzorak"] = "Vaelgor et Ezzorak"
SN["Vanessa VanCleef"] = "Vanessa VanCleef"
SN["Viz'aduum the Watcher (Karazhan)"] = "Viz'aduum le Guetteur (Karazhan)"
SN["Vol'zith the Whisperer (Shrine of the Storm)"] = "Vol'zith le Chuchoteur (Sanctuaire des Tempêtes)"
SN["Vorasius (The Voidspire)"] = "Vorasius (La Flèche du Vide)"
SN["Warlord Sargha (Neltharus)"] = "Seigneur de guerre Sargha (Neltharus)"
SN["Warlord Zaela"] = "Seigneur de guerre Zaela"
SN["Ziekket (The Blinding Vale)"] = "Ziekket (Le Val aveuglant)"

-- Treasures
SN["Gift of the Phoenix (Eversong Woods)"] = "Don du Phénix (Bois des Chants éternels)"
SN["Golden Cloud Serpent Treasure Chest (Jade Forest)"] = "Coffre au trésor du Serpent-nuage doré (Forêt de Jade)"
SN["Incomplete Book of Sonnets (Eversong Woods)"] = "Recueil de sonnets incomplet (Bois des Chants éternels)"
SN["Malignant Chest (Voidstorm)"] = "Coffre malfaisant (Tempête du Vide)"
SN["Stellar Stash (Slayer's Rise)"] = "Réserve stellaire (Ascension du Tueur)"
SN["Stone Vat (Eversong Woods)"] = "Cuve en pierre (Bois des Chants éternels)"
SN["Triple-Locked Safebox (Eversong Woods)"] = "Coffret à triple verrou (Bois des Chants éternels)"
SN["Undermine"] = "Creux-de-Brasier"
SN["World Glimmering Treasure Chest Drop"] = "Butin de coffre au trésor scintillant mondial"

-- Manual quest title translations (quests without quest IDs)
local QT = addon.questTitleLocale

-- Keybinding globals (must be set per-locale since enUS sets them before frFR overrides L values)
BINDING_HEADER_HCODEX = L["KEYBIND_HEADER"]
BINDING_NAME_HOUSINGCODEX_TOGGLE = L["KEYBIND_TOGGLE"]
