--[[
    Housing Codex - ruRU.lua
    Russiab localization ZamestoTV
]]

if GetLocale() ~= "deDE" then return end

local _, addon = ...

local L = addon.L

--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------
L["ADDON_NAME"] = "Housing Codex"
L["KEYBIND_HEADER"] = "|cffffd100Housing|r |cffff8000Codex|r"
L["KEYBIND_TOGGLE"] = "Открыть/закрыть окно |cffff8000Housing Codex|r"
L["LOADING"] = "Загрузка..."
L["LOADING_DATA"] = "Загрузка данных о декоре..."
L["LOADED_MESSAGE"] = "Собрано |cFF88EE88%.1f%%|r декора. Введите |cFF88BBFF/hc|r, чтобы открыть."
L["COMBAT_LOCKDOWN_MESSAGE"] = "Нельзя открыть во время боя"

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------
L["TAB_DECOR"] = "ДЕКОР"
L["TAB_QUESTS"] = "ЗАДАНИЯ"
L["TAB_ACHIEVEMENTS"] = "ДОСТИЖЕНИЯ"
L["TAB_VENDORS"] = "ТОРГОВЦЫ"
L["TAB_DROPS"] = "ДОБЫЧА"
L["TAB_PROFESSIONS"] = "ПРОФЕССИИ"
L["TAB_ACHIEVEMENTS_SHORT"] = "ДОСТ..."
L["TAB_PROFESSIONS_SHORT"] = "ПРОФ..."
L["TAB_PROGRESS_SHORT"] = "ПРОГ..."
L["TAB_DECOR_DESC"] = "Просмотр и поиск всех предметов декора для дома"
L["TAB_QUESTS_DESC"] = "Задания, в награду за которые дается декор"
L["TAB_ACHIEVEMENTS_DESC"] = "Достижения, за которые можно получить декор"
L["TAB_VENDORS_DESC"] = "Местоположение торговцев предметами декора"
L["TAB_DROPS_DESC"] = "Источники выпадения предметов декора"
L["TAB_PROFESSIONS_DESC"] = "Предметы декора, создаваемые игроками"
--------------------------------------------------------------------------------
-- Search & Filters
--------------------------------------------------------------------------------
L["SEARCH_PLACEHOLDER"] = "Поиск..."
L["FILTER_ALL"] = "Все предметы"
L["FILTER_COLLECTED"] = "Собрано"
L["FILTER_NOT_COLLECTED"] = "Не собрано"
L["FILTER_TRACKABLE"] = "Только отслеживаемые"
L["FILTER_NOT_TRACKABLE"] = "Неотслеживаемые"
L["FILTER_TRACKABLE_HEADER"] = "Отслеживание"
L["FILTER_TRACKABLE_ALL"] = "Все"
L["FILTER_INDOORS"] = "В помещении"
L["FILTER_OUTDOORS"] = "На улице"
L["FILTER_DYEABLE"] = "Можно перекрасить"
L["FILTER_FIRST_ACQUISITION"] = "Бонус за первое получение"
L["FILTER_WISHLIST_ONLY"] = "Только список желаемого"
L["FILTERS"] = "Фильтры"
L["CHECK_ALL"] = "Отметить все"
L["UNCHECK_ALL"] = "Снять все отметки"

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------
L["SIZE_LABEL"] = "Размер:"
L["SORT_BY_LABEL"] = "Сортировка"

--------------------------------------------------------------------------------
-- Sort
--------------------------------------------------------------------------------
L["SORT_NEWEST"] = "Новинки"
L["SORT_ALPHABETICAL"] = "А–Я"
L["SORT_SIZE"] = "Размер"
L["SORT_QUANTITY"] = "Кол-во: в наличии"
L["SORT_PLACED"] = "Кол-во: размещено"
L["SORT_NEWEST_TIP"] = "Сначала недавно добавленный декор"
L["SORT_ALPHABETICAL_TIP"] = "По алфавиту (А–Я)"
L["SORT_SIZE_TIP"] = "По размеру (от огромных к крошечным)"
L["SORT_QUANTITY_TIP"] = "Сначала предметы, которых у вас больше всего"
L["SORT_PLACED_TIP"] = "Сначала предметы, чаще всего используемые в доме"

--------------------------------------------------------------------------------
-- Result Count & Empty State
--------------------------------------------------------------------------------
L["RESULT_COUNT_ALL"] = "Показано предметов: %d"
L["RESULT_COUNT_FILTERED"] = "Показано %d из %d предметов"
L["RESULT_COUNT_TOOLTIP_UNIQUE"] = "Собрано уникального декора: %d / %d (%.1f%%)"
L["RESULT_COUNT_TOOLTIP_ROOMS"] = "Открыто комнат: %d / %d"
L["RESULT_COUNT_TOOLTIP_OWNED"] = "Всего предметов во владении: %d"
L["RESULT_COUNT_TOOLTIP_TOTAL"] = "Всего объектов: %d (%d декора, %d комнат)"
L["EMPTY_STATE_MESSAGE"] = "Нет предметов, подходящих под фильтры"
L["RESET_FILTERS"] = "Сбросить фильтры"

--------------------------------------------------------------------------------
-- Category Navigation
--------------------------------------------------------------------------------
L["CATEGORY_ALL"] = "Все"
L["CATEGORY_BACK"] = "Назад"
L["CATEGORY_ALL_IN"] = "Все: %s"

--------------------------------------------------------------------------------
-- Details Panel
--------------------------------------------------------------------------------
L["DETAILS_NO_SELECTION"] = "Выберите предмет"
L["DETAILS_OWNED"] = "В наличии: %d"
L["DETAILS_PLACED"] = "Размещено: %d"
L["DETAILS_NOT_OWNED"] = "Нет в наличии"
L["DETAILS_SIZE"] = "Размер:"
L["DETAILS_PLACE"] = "Тип:"
L["DETAILS_DYEABLE"] = "Можно перекрасить"
L["DETAILS_NOT_DYEABLE"] = "Нельзя перекрасить"
L["DETAILS_SOURCE_UNKNOWN"] = "Источник неизвестен"
L["UNKNOWN"] = "Неизвестно"

-- Size names
L["SIZE_TINY"] = "Крошечный"
L["SIZE_SMALL"] = "Маленький"
L["SIZE_MEDIUM"] = "Средний"
L["SIZE_LARGE"] = "Большой"
L["SIZE_HUGE"] = "Огромный"

-- Placement types
L["PLACEMENT_IN"] = "Внутр."
L["PLACEMENT_OUT"] = "Уличн."

--------------------------------------------------------------------------------
-- Wishlist
--------------------------------------------------------------------------------
L["WISHLIST_ADD"] = "Добавить в список желаемого"
L["WISHLIST_REMOVE"] = "Удалить из списка желаемого"
L["WISHLIST_ADDED"] = "Добавлено в список желаемого: %s"
L["WISHLIST_REMOVED"] = "Удалено из списка желаемого: %s"
L["WISHLIST_BUTTON"] = "ЖЕЛАЕМОЕ"
L["WISHLIST_BUTTON_TOOLTIP"] = "Посмотреть список желаемого"
L["CODEX_BUTTON"] = "HOUSING CODEX"
L["CODEX_BUTTON_TOOLTIP"] = "Вернуться в главное меню"
L["WISHLIST_TITLE"] = "Список желаемого"
L["WISHLIST_EMPTY"] = "Ваш список желаемого пуст"
L["WISHLIST_EMPTY_DESC"] = "Добавляйте предметы, нажимая на иконку звезды во вкладках «Декор» или «Задания»"
L["WISHLIST_SHIFT_CLICK"] = "Shift+Клик: добавить/удалить из списка желаемого"

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------
L["ACTION_TRACK"] = "Отслеживать"
L["ACTION_UNTRACK"] = "Не отслеживать"
L["ACTION_LINK"] = "Ссылка"
L["ACTION_TRACK_TOOLTIP"] = "Отслеживать этот предмет в журнале задач"
L["ACTION_UNTRACK_TOOLTIP"] = "Прекратить отслеживание предмета"
L["ACTION_TRACK_DISABLED_TOOLTIP"] = "Этот предмет нельзя отследить"
L["ACTION_LINK_TOOLTIP"] = "Вставить ссылку на предмет в чат"
L["ACTION_LINK_TOOLTIP_RIGHTCLICK"] = "ПКМ: Копировать ссылку на Wowhead"
L["TRACKING_ERROR_MAX"] = "Ошибка: Достигнут лимит отслеживаемых предметов"
L["TRACKING_ERROR_UNTRACKABLE"] = "Этот предмет невозможно отследить"
L["TRACKING_STARTED"] = "Отслеживается: %s"
L["TRACKING_STOPPED"] = "Отслеживание прекращено: %s"
L["TOOLTIP_SHIFT_CLICK_TRACK"] = "Shift+клик: отслеживать"
L["TOOLTIP_SHIFT_CLICK_UNTRACK"] = "Shift+клик: не отслеживать"
L["TRACKING_ERROR_GENERIC"] = "Ошибка отслеживания"
L["LINK_ERROR"] = "Не удалось создать ссылку на предмет"
L["LINK_INSERTED"] = "Ссылка вставлена в чат"

--------------------------------------------------------------------------------
-- Preview
--------------------------------------------------------------------------------
L["PREVIEW_NO_MODEL"] = "3D-модель недоступна"
L["PREVIEW_NO_SELECTION"] = "Выберите предмет для просмотра"
L["PREVIEW_ERROR"] = "Ошибка загрузки модели"
L["PREVIEW_NOT_IN_CATALOG"] = "Еще не добавлено в каталог жилища"

--------------------------------------------------------------------------------
-- Settings (WoW Native Settings UI)
--------------------------------------------------------------------------------
L["OPTIONS_SECTION_DISPLAY"] = "Отображение"
L["OPTIONS_SECTION_MAP_NAV"]  = "Карта и навигация"
L["OPTIONS_SECTION_VENDOR"] = "Торговцы"
L["OPTIONS_SHOW_COLLECTED"] = "Индикаторы количества на плитках"
L["OPTIONS_SHOW_COLLECTED_TOOLTIP"] = "Отображать количество имеющихся и размещенных предметов прямо на плитках сетки"
L["OPTIONS_SHOW_MINIMAP"] = "Кнопка у миникарты"
L["OPTIONS_SHOW_MINIMAP_TOOLTIP"] = "Отображать кнопку Housing Codex у миникарты"
L["OPTIONS_VENDOR_INDICATORS"] = "Помечать декор у торговцев"
L["OPTIONS_VENDOR_INDICATORS_TOOLTIP"] = "Отображать иконку Housing Codex на предметах у торговцев, если они являются декором"
L["OPTIONS_VENDOR_OWNED_CHECKMARK"] = "Галочка для имеющегося декора"
L["OPTIONS_VENDOR_OWNED_CHECKMARK_TOOLTIP"] = "Отображать зеленую галочку на товарах торговца, которые у вас уже есть"
L["OPTIONS_SECTION_CONTAINERS"] = "Сумки и банк"
L["OPTIONS_CONTAINER_INDICATORS"] = "Помечать декор в сумках и банке"
L["OPTIONS_CONTAINER_INDICATORS_TOOLTIP"] = "Отображать иконку Housing Codex на предметах в ваших сумках и банке, если они являются декором"
L["OPTIONS_CONTAINER_OWNED_CHECKMARK"] = "Галочка для имеющегося декора"
L["OPTIONS_CONTAINER_OWNED_CHECKMARK_TOOLTIP"] = "Отображать зеленую галочку на предметах декора в сумках и банке, которые у вас уже есть"
L["OPTIONS_VENDOR_MAP_PINS"] = "Метки торговцев на карте"
L["OPTIONS_VENDOR_MAP_PINS_TOOLTIP"] = "Отображать метки торговцев на карте мира с прогрессом коллекции"
L["OPTIONS_TREASURE_HUNT_WAYPOINTS"] = "Автопуть для «Охоты за предметами декора»"
L["OPTIONS_TREASURE_HUNT_WAYPOINTS_TOOLTIP"] = "Автоматически ставить метку на карте при принятии задания на поиск декора в жилых зонах"
L["OPTIONS_USE_TOMTOM"] = "Использовать TomTom для меток"
L["OPTIONS_USE_TOMTOM_TOOLTIP"] = "Использовать систему TomTom вместо стандартных меток карты (если аддон установлен)"
L["OPTIONS_USE_TOMTOM_NOT_INSTALLED"] = "Использовать TomTom для меток (не установлен)"
L["OPTIONS_AUTO_ROTATE_PREVIEW"] = "Автоповорот 3D-модели"
L["OPTIONS_AUTO_ROTATE_PREVIEW_TOOLTIP"] = "Медленно вращать 3D-модель в окне предпросмотра и списке желаемого"
L["OPTIONS_SECTION_BROKER"] = "Кнопка миникарты и инфо-панели"
L["OPTIONS_LDB_UNIQUE"] = "Показывать кол-во уникального декора"
L["OPTIONS_LDB_UNIQUE_TOOLTIP"] = "Отображать количество уникального декора в тексте инфо-панели у миникарты"
L["OPTIONS_LDB_ROOMS"] = "Показывать открытые комнаты"
L["OPTIONS_LDB_ROOMS_TOOLTIP"] = "Отображать количество открытых комнат в тексте инфо-панели у миникарты"
L["OPTIONS_LDB_TOTAL_OWNED"] = "Показывать общее кол-во декора"
L["OPTIONS_LDB_TOTAL_OWNED_TOOLTIP"] = "Отображать общее количество декора (включая дубликаты) в тексте инфо-панели у миникарты"
L["OPTIONS_LDB_TOTAL"] = "Показывать все предметы"
L["OPTIONS_LDB_TOTAL_TOOLTIP"] = "Отображать общее количество предметов в каталоге в тексте инфо-панели у миникарты"
L["OPTIONS_RESET_POSITION"] = "Сбросить положение окна"
L["OPTIONS_RESET_POSITION_TOOLTIP"] = "Вернуть окно в центр экрана"
L["OPTIONS_RESET_SIZE"] = "Сбросить размер окна"
L["OPTIONS_RESET_SIZE_TOOLTIP"] = "Вернуть окну размер по умолчанию"
L["OPTIONS_SHOW_WELCOME"] = "Экран приветствия"
L["OPTIONS_SHOW_WELCOME_TOOLTIP"] = "Показывать приветственное окно"
L["SIZE_RESET"] = "Размер окна сброшен до стандартного."

L["OPTIONS_SECTION_KEYBIND"] = "Горячая клавиша"
L["OPTIONS_SECTION_TROUBLESHOOTING"] = "Устранение неполадок"
L["OPTIONS_TOGGLE_KEYBIND"] = "Открыть/закрыть окно:"
L["OPTIONS_NOT_BOUND"] = "Не назначена"
L["OPTIONS_PRESS_KEY"] = "Нажмите клавишу..."
L["OPTIONS_UNBIND_TOOLTIP"] = "Нажмите правую кнопку мыши, чтобы сбросить"
L["OPTIONS_KEYBIND_HINT"] = "Клик: назначить клавишу. ПКМ: очистить. ESC: отмена."
L["OPTIONS_KEYBIND_CONFLICT"] = "Клавиша \"%s\" уже назначена на \"%s\".\n\nХотите переназначить её для Housing Codex?"

--------------------------------------------------------------------------------
-- Slash Command Help
--------------------------------------------------------------------------------
L["HELP_TITLE"] = "Команды Housing Codex:"
L["HELP_TOGGLE"] = "/hc — открыть/закрыть главное окно"
L["HELP_SETTINGS"] = "/hc settings — открыть настройки"
L["HELP_RESET"] = "/hc reset — сбросить положение окна"
L["HELP_RETRY"] = "/hc retry — повторить попытку загрузки данных"
L["HELP_HELP"] = "/hc help — показать эту справку"
L["HELP_DEBUG"] = "/hc debug — включить/выключить режим отладки"
L["HELP_STATS"] = "/hc stats — показать счетчики отладки"

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------
L["SETTINGS_NOT_AVAILABLE"] = "Настройки пока недоступны"
L["RETRYING_DATA_LOAD"] = "Повторная попытка загрузки данных..."
L["DEBUG_MODE_STATUS"] = "Режим отладки: %s"
L["FONT_MODE_STATUS"] = "Пользовательский шрифт: %s"
L["DEBUG_ON"] = "ВКЛ"
L["DEBUG_OFF"] = "ВЫКЛ"
L["DATA_NOT_LOADED"] = "Данные еще не загружены"
L["INSPECT_FOUND"] = "Найдено: %s (ID: %d)"
L["INSPECT_NOT_FOUND"] = "Не найдено предметов, соответствующих: %s"
L["MAIN_WINDOW_NOT_AVAILABLE"] = "Главное окно пока недоступно"
L["POSITION_RESET"] = "Положение окна сброшено по центру"

--------------------------------------------------------------------------------
-- Errors
--------------------------------------------------------------------------------
L["ERROR_API_UNAVAILABLE"] = "API жилья недоступно"
L["ERROR_LOAD_FAILED"] = "Не удалось загрузить данные жилья после нескольких попыток. Используйте /hc retry, чтобы повторить."
L["ERROR_LOAD_FAILED_SHORT"] = "Ошибка загрузки данных. Введите /hc retry"

--------------------------------------------------------------------------------
-- LDB (LibDataBroker)
--------------------------------------------------------------------------------
L["LDB_TOOLTIP_LEFT"] = "|cffffffffЛКМ|r: открыть/закрыть главное окно"
L["LDB_TOOLTIP_RIGHT"] = "|cffffffffПКМ|r: открыть настройки"
L["LDB_TOOLTIP_ALT"] = "|cffffffffAlt+клик|r: настроить вид инфо-панели"
L["LDB_OPTIONS_PLACEHOLDER"] = "Панель настроек еще не доступна"
L["LDB_POPUP_TITLE"] = "Вид инфо-панели"
L["LDB_TOOLTIP_DECOR_HEADER"] = "Статистика коллекции"
L["LDB_POPUP_UNIQUE"] = "Уникальный декор"
L["LDB_POPUP_ROOMS"] = "Открыто комнат"
L["LDB_POPUP_TOTAL_OWNED"] = "Всего во владении (с дубликатами)"
L["LDB_POPUP_TOTAL_ITEMS"] = "Всего предметов"
L["LDB_POPUP_PERCENT"] = "% коллекции"
L["LDB_TOOLTIP_WISHLIST"] = "Список желаемого"
L["LDB_TOOLTIP_WISHLIST_COUNT"] = "Предметов: %d"
L["LDB_TOOLTIP_SHIFT_RIGHT"] = "|cffffffffShift+ПКМ|r: прогресс коллекции"

--------------------------------------------------------------------------------
-- Quests Tab
--------------------------------------------------------------------------------
L["QUESTS_SEARCH_PLACEHOLDER"] = "Поиск заданий, зон или наград..."
L["QUESTS_FILTER_ALL"] = "Все"
L["QUESTS_FILTER_INCOMPLETE"] = "Незавершенные"
L["QUESTS_FILTER_COMPLETE"] = "Завершенные"
L["QUESTS_EMPTY_NO_SOURCES"] = "Источники заданий не найдены"
L["QUESTS_EMPTY_NO_SOURCES_DESC"] = "Данные о заданиях могут быть недоступны через WoW API"
L["QUESTS_SELECT_EXPANSION"] = "Выберите дополнение"
L["QUESTS_EMPTY_NO_RESULTS"] = "Задания не найдены"
L["QUESTS_UNKNOWN_QUEST"] = "Задание №%d"
L["QUESTS_UNKNOWN_ZONE"] = "Неизвестная зона"
L["QUESTS_UNKNOWN_EXPANSION"] = "Прочее"

-- Quest tracking messages
L["QUESTS_TRACKING_STARTED"] = "Предмет отслеживается"
L["QUESTS_TRACKING_MAX_REACHED"] = "Ошибка: достигнут лимит отслеживания (15)"
L["QUESTS_TRACKING_ALREADY"] = "Этот предмет уже отслеживается"
L["QUESTS_TRACKING_FAILED"] = "Не удалось отследить этот предмет"

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
L["ACHIEVEMENTS_SEARCH_PLACEHOLDER"] = "Поиск достижений, наград или категорий..."
L["ACHIEVEMENTS_FILTER_ALL"] = "Все"
L["ACHIEVEMENTS_FILTER_INCOMPLETE"] = "Незавершенные"
L["ACHIEVEMENTS_FILTER_COMPLETE"] = "Завершенные"
L["ACHIEVEMENTS_EMPTY_NO_SOURCES"] = "Источники достижений не найдены"
L["ACHIEVEMENTS_EMPTY_NO_SOURCES_DESC"] = "Данные о достижениях могут быть недоступны"
L["ACHIEVEMENTS_SELECT_CATEGORY"] = "Выберите категорию"
L["ACHIEVEMENTS_EMPTY_NO_RESULTS"] = "Достижения не найдены"
L["ACHIEVEMENTS_UNKNOWN"] = "Достижение №%d"

-- Achievement tracking messages
L["ACHIEVEMENTS_TRACKING_STARTED"] = "Предмет отслеживается"
L["ACHIEVEMENTS_TRACKING_STARTED_ACHIEVEMENT"] = "Достижение отслеживается"
L["ACHIEVEMENTS_TRACKING_STOPPED"] = "Отслеживание достижения прекращено"
L["ACHIEVEMENTS_TRACKING_MAX_REACHED"] = "Ошибка: достигнут лимит отслеживания (15)"
L["ACHIEVEMENTS_TRACKING_ALREADY"] = "Этот предмет уже отслеживается"
L["ACHIEVEMENTS_TRACKING_FAILED"] = "Не удалось отследить это достижение"

--------------------------------------------------------------------------------
-- Context Menu
--------------------------------------------------------------------------------
L["CONTEXT_MENU_LINK_TO_CHAT"] = "Вставить ссылку в чат"
L["CONTEXT_MENU_COPY_WOWHEAD"] = "Копировать ссылку на Wowhead"

-- Note: Achievement category names come from WoW's GetCategoryInfo() API
-- which returns already-localized strings, so no L[] entries needed

--------------------------------------------------------------------------------
-- Vendors Tab
--------------------------------------------------------------------------------
L["VENDORS_SEARCH_PLACEHOLDER"] = "Поиск торговцев, зон или предметов..."
L["VENDORS_FILTER_ALL"] = "Все"
L["VENDORS_FILTER_INCOMPLETE"] = "Не все куплено"
L["VENDORS_FILTER_COMPLETE"] = "Все куплено"
L["VENDORS_CURRENT_ZONE"] = "Текущая зона"
L["VENDORS_EMPTY_NO_SOURCES"] = "Торговцы не найдены"
L["VENDORS_EMPTY_NO_SOURCES_DESC"] = "Данные о торговцах могут быть недоступны"
L["VENDORS_SELECT_EXPANSION"] = "Выберите дополнение"
L["VENDORS_EMPTY_NO_RESULTS"] = "Нет торговцев, подходящих под фильтры"
L["VENDORS_UNKNOWN_EXPANSION"] = "Прочее"
L["VENDORS_UNKNOWN_ZONE"] = "Неизвестная зона"

-- Vendor waypoint messages
L["VENDOR_SET_WAYPOINT"] = "Установить метку"
L["VENDOR_NO_LOCATION"] = "Местоположение неизвестно"
L["VENDOR_WAYPOINT_SET"] = "Установлена метка: %s"
L["VENDOR_MAP_RESTRICTED"] = "На этой карте нельзя установить метку"

-- Vendor fallback names
L["VENDOR_UNKNOWN"] = "Неизвестный торговец"
L["VENDOR_FALLBACK_NAME"] = "торговец"

-- Vendor world map pins
L["VENDOR_PIN_COLLECTED"] = "Собрано: %d/%d"
L["VENDOR_PIN_UNCOLLECTED_HEADER"] = "Не собранный декор:"
L["VENDOR_PIN_ITEM_LOCKED"] = "недоступно"
L["VENDOR_PIN_MORE"] = "+ еще %d"
L["VENDOR_PIN_CLICK_WAYPOINT"] = "Клик: установить метку"
L["VENDOR_PIN_FACTION_ALLIANCE"] = "Только Альянс"
L["VENDOR_PIN_FACTION_HORDE"] = "Только Орда"
L["VENDOR_PIN_VENDOR_COUNT"] = "Торговцев: %dx"
L["VENDOR_PIN_VENDOR_LIST_HEADER"] = "Список торговцев:"
L["VENDOR_PIN_VENDOR_ENTRY"] = "%s (%d/%d)"
L["VENDOR_PIN_VENDORS_MORE"] = "+ еще %d торговцев"

-- Vendor tracking messages
L["VENDORS_TRACKING_STARTED"] = "Метка добавлена: %s (%s)"
L["VENDORS_TRACKING_STOPPED"] = "Метка удалена: %s (%s)"
L["VENDORS_ACTION_TRACK"] = "К точке"
L["VENDORS_ACTION_UNTRACK"] = "Удалить метку"
L["VENDORS_ACTION_TRACK_TOOLTIP"] = "Установить метку на карте к этому торговцу"
L["VENDORS_ACTION_UNTRACK_TOOLTIP"] = "Удалить метку торговца с карты"
L["VENDORS_ACTION_TRACK_DISABLED_TOOLTIP"] = "У этого торговца нет координат для метки"

-- Vendor cost display
L["CURRENCY_GOLD"] = "золото"
-- Vendor decor fallback
L["VENDORS_DECOR_ID"] = "Декор №%d"
L["VENDOR_CAT_ACCENTS"] = "Аксессуары"
L["VENDOR_CAT_FUNCTIONAL"] = "Функциональное"
L["VENDOR_CAT_FURNISHINGS"] = "Мебель"
L["VENDOR_CAT_LIGHTING"] = "Освещение"
L["VENDOR_CAT_MISCELLANEOUS"] = "Разное"
L["VENDOR_CAT_NATURE"] = "Природа"
L["VENDOR_CAT_STRUCTURAL"] = "Строения"
L["VENDOR_CAT_UNCATEGORIZED"] = "Без категории"

-- Vendor zone annotations
L["VENDOR_CLASS_HALL_SUFFIX"] = "оплот класса"
L["VENDOR_HOUSING_ZONE_SUFFIX"] = "жилая зона"
L["VENDOR_CLASS_ONLY_SUFFIX"] = "Только для: %s"

-- Vendor tooltip overlay
L["OPTIONS_VENDOR_TOOLTIPS"] = "Декор торговца в подсказках"
L["OPTIONS_VENDOR_TOOLTIPS_TOOLTIP"] = "Отображать прогресс коллекции Housing Codex во всплывающей подсказке при наведении на торговца декором"

--------------------------------------------------------------------------------
-- Drops Tab
--------------------------------------------------------------------------------
L["DROPS_SEARCH_PLACEHOLDER"] = "Поиск источников или предметов..."
L["DROPS_FILTER_ALL"] = "Все"
L["DROPS_FILTER_INCOMPLETE"] = "Не собрано"
L["DROPS_FILTER_COMPLETE"] = "Собрано"
L["DROPS_EMPTY_NO_SOURCES"] = "Источники добычи не найдены"
L["DROPS_EMPTY_NO_SOURCES_DESC"] = "Данные о добыче могут быть недоступны"
L["DROPS_SELECT_CATEGORY"] = "Выберите категорию"
L["DROPS_EMPTY_NO_RESULTS"] = "Нет источников добычи, подходящих под поиск"

-- Drop source category labels
L["DROPS_CATEGORY_DROP"] = "Добыча"
L["DROPS_CATEGORY_ENCOUNTER"] = "Боссы"
L["DROPS_CATEGORY_TREASURE"] = "Сокровища"

-- Drop source display
L["DROPS_DECOR_ID"] = "Декор №%d"

--------------------------------------------------------------------------------
-- Professions Tab
--------------------------------------------------------------------------------
L["PROFESSIONS_SEARCH_PLACEHOLDER"] = "Поиск профессий или предметов..."
L["PROFESSIONS_FILTER_ALL"] = "Все"
L["PROFESSIONS_FILTER_INCOMPLETE"] = "Не изучено"
L["PROFESSIONS_FILTER_COMPLETE"] = "Изучено"
L["PROFESSIONS_EMPTY_NO_SOURCES"] = "Нет данных об изготовлении"
L["PROFESSIONS_EMPTY_NO_SOURCES_DESC"] = "Данные об изготовлении предметов пока недоступны."
L["PROFESSIONS_SELECT_PROFESSION"] = "Выберите профессию"
L["PROFESSIONS_EMPTY_NO_RESULTS"] = "Нет результатов"

--------------------------------------------------------------------------------
-- Treasure Hunt Waypoints
--------------------------------------------------------------------------------
L["TREASURE_HUNT_WAYPOINT_SET"] = "Сокровище отмечено на"

--------------------------------------------------------------------------------
-- Progress Tab
--------------------------------------------------------------------------------
L["TAB_PROGRESS"] = "ПРОГРЕСС"
L["TAB_PROGRESS_DESC"] = "Обзор прогресса коллекции"
L["PROGRESS_COLLECTED"] = "Собрано"
L["PROGRESS_TOTAL"] = "Всего"
L["PROGRESS_REMAINING"] = "Осталось"
L["PROGRESS_BY_SOURCE"] = "По источникам"
L["PROGRESS_VENDOR_EXPANSIONS"] = "Торговцы (по дополнениям)"
L["PROGRESS_QUEST_EXPANSIONS"] = "Задания (по дополнениям)"
L["PROGRESS_RENOWN_EXPANSIONS"] = "Известность (по дополнениям)"
L["PROGRESS_PROFESSIONS"] = "Профессии"
L["PROGRESS_ALMOST_THERE"] = "Близко к завершению"
L["PROGRESS_OVERVIEW"] = "ОБЗОР ПРОГРЕССА"
L["PROGRESS_ALL_DECOR_COLLECTED"] = "Весь декор собран"
L["PROGRESS_SOURCE_ALL"] = "Весь декор"
L["PROGRESS_SOURCE_VENDORS"] = "Торговцы"
L["PROGRESS_SOURCE_QUESTS"] = "Задания"
L["PROGRESS_SOURCE_ACHIEVEMENTS"] = "Достижения"
L["PROGRESS_SOURCE_PROFESSIONS"] = "Профессии"
L["PROGRESS_SOURCE_PVP"] = "PvP"
L["PROGRESS_SOURCE_DROPS"] = "Добыча"
L["PROGRESS_SOURCE_RENOWN"] = "Известность"
L["PROGRESS_LOADING"] = "Загрузка данных о прогрессе..."

--------------------------------------------------------------------------------
-- Zone Overlay (World Map)
--------------------------------------------------------------------------------
L["ZONE_OVERLAY_VENDORS"] = "Торговцы"
L["ZONE_OVERLAY_QUESTS"] = "Задания"
L["ZONE_OVERLAY_TREASURE"] = "Охота за предметами декора"
L["ZONE_OVERLAY_COUNT"] = "Декора в этой зоне: %d"
L["ZONE_OVERLAY_BUTTON_TOOLTIP"] = "Housing Codex"
L["ZONE_OVERLAY_SHOW"] = "Показывать оверлей зоны"
L["ZONE_OVERLAY_PINS"] = "Метки торговцев на карте"
L["ZONE_OVERLAY_POSITION"] = "Позиция панели"
L["ZONE_OVERLAY_POS_TOPLEFT"] = "Сверху слева"
L["ZONE_OVERLAY_POS_BOTTOMRIGHT"] = "Снизу справа"
L["ZONE_OVERLAY_TRANSPARENCY"] = "Прозрачность"
L["ZONE_OVERLAY_INCLUDE_COLLECTED_VENDORS"] = "Включая собранный декор"
L["ZONE_OVERLAY_SOURCE_VENDOR"] = "(Торговец)"
L["ZONE_OVERLAY_SOURCE_VENDOR_CITY"] = "(Торговец в: |cFFFF8C00%s|r)"
L["ZONE_OVERLAY_CLICK_WAYPOINT"] = "ЛКМ: установить метку на карте"
L["ZONE_OVERLAY_CLICK_OPEN_HC"] = "ПКМ: открыть в Housing Codex"
L["ZONE_OVERLAY_PREVIEW_SIZE"] = "Размер предпросмотра"
L["ZONE_OVERLAY_SECTION_HEADER"] = "Оверлей зоны"
L["ZONE_OVERLAY_COLLAPSED_TOOLTIP"] = "Кликните, чтобы увидеть декор в этой зоне"
L["VENDOR_PINS_SECTION_HEADER"] = "Метки торговцев на карте"
L["VENDOR_PINS_TRANSPARENCY"] = "Прозрачность меток"
L["VENDOR_PINS_SCALE"] = "Размер меток"
-- VENDOR_PINS_LAYER removed: custom frame levels tainted WorldMapFrame (WoWUIBugs #811)
L["OPTIONS_ZONE_OVERLAY"] = "Оверлей зоны на карте мира"
L["OPTIONS_ZONE_OVERLAY_TOOLTIP"] = "Отображать на карте мира панель со списком доступного декора в текущей зоне"

--------------------------------------------------------------------------------
-- What's New Popup
--------------------------------------------------------------------------------
L["WHATSNEW_TITLE"] = "Что нового в Housing Codex"
L["WHATSNEW_DONT_SHOW"] = "Не показывать снова для v%s"
L["WHATSNEW_EXPLORE"] = "Посмотреть Housing Codex"
L["WHATS_NEW_NO_IMAGE"] = "Скриншот"

--------------------------------------------------------------------------------
-- Welcome Popup
--------------------------------------------------------------------------------
L["WELCOME_TITLE"] = "Добро пожаловать в Housing Codex"
L["WELCOME_SUBTITLE"] = "Ваш помощник в поиске декора и обустройстве дома"
L["WELCOME_START"] = "Начать обзор"
L["WELCOME_QUICK_SETUP"] = "Полезно знать"
L["WELCOME_OPEN_WITH"] = "Вы можете открыть аддон в любое время через"
L["WELCOME_SET_KEYBIND"] = "или назначив клавишу в меню"
L["WELCOME_KEYBIND_LABEL"] = "Настройки"

--------------------------------------------------------------------------------
-- What's New: v1.5.0 feature highlights
--------------------------------------------------------------------------------
L["WHATSNEW_V150_F1_TITLE"] = "Панель прогресса"
L["WHATSNEW_V150_F1_DESC"] = "Мгновенный обзор вашей коллекции: общая статистика, данные по типам источников и категории, близкие к завершению."
L["WHATSNEW_V150_F2_TITLE"] = "Отслеживание профессий"
L["WHATSNEW_V150_F2_DESC"] = "Следите за прогрессом изготовления предметов для каждой профессии с помощью специальных индикаторов."
L["WHATSNEW_V150_F3_TITLE"] = "Умная навигация"
L["WHATSNEW_V150_F3_DESC"] = "Нажмите на любую строку прогресса, чтобы мгновенно перейти к соответствующей вкладке источника."
L["WHATSNEW_V150_F4_TITLE"] = "Ссылки из списка желаемого"
L["WHATSNEW_V150_F4_DESC"] = "Делитесь предметами из списка желаемого в чате в виде активных ссылок, которые другие игроки смогут просмотреть."

--------------------------------------------------------------------------------
-- Welcome feature highlights
--------------------------------------------------------------------------------
L["WELCOME_F1_TITLE"] = "Интерактивный 3D-просмотр"
L["WELCOME_F1_DESC"] = "Предварительный просмотр декора в 3D: вращайте, приближайте и меняйте размер окна просмотра."
L["WELCOME_F2_TITLE"] = "Каталог и сетка декора"
L["WELCOME_F2_DESC"] = "Просматривайте весь каталог в настраиваемой сетке с быстрым поиском и фильтрами."
L["WELCOME_F3_TITLE"] = "Источники и поиск"
L["WELCOME_F3_DESC"] = "Узнайте, где получить недостающий декор: задания, достижения, торговцы, добыча, профессии, известность и PvP."
L["WELCOME_F4_TITLE"] = "Индикаторы у торговцев"
L["WELCOME_F4_DESC"] = "Иконки декора в окне торговца сразу выделяют коллекционные предметы. Также помечает декор в сумках и банке."
L["WELCOME_F5_TITLE"] = "Интеграция с картой"
L["WELCOME_F5_DESC"] = "Метки на карте показывают расположение торговцев, а оверлей зоны подскажет, какой декор здесь можно найти."
L["WELCOME_F6_TITLE"] = "Прогресс коллекции"
L["WELCOME_F6_DESC"] = "Вкладка «Прогресс» мгновенно показывает состояние вашей коллекции по источникам и дополнениям."

--------------------------------------------------------------------------------
-- Endeavors Panel
--------------------------------------------------------------------------------
L["ENDEAVORS_TITLE"] = "Предприятия"
L["ENDEAVORS_OPTIONS"] = "Настройки предприятий"
L["ENDEAVORS_OPTIONS_TOOLTIP"] = "Настроить панель оверлея предприятий"
L["ENDEAVORS_MAX_LEVEL"] = "МАКС"
L["ENDEAVORS_PROGRESS_FORMAT"] = "Прогресс: %d / %d"
L["ENDEAVORS_YOUR_CONTRIBUTION"] = "Ваш вклад: %d"
L["ENDEAVORS_MILESTONES"] = "Этапы"
L["ENDEAVORS_OPT_SECTION_GENERAL"]  = "Общие"
L["ENDEAVORS_OPT_SECTION_HOUSE_XP"] = "Опыт дома"
L["ENDEAVORS_OPT_SECTION_ENDEAVOR"] = "Прогресс предприятия"
L["ENDEAVORS_OPT_SECTION_SIZE"]     = "Размер панели"
L["ENDEAVORS_OPT_SHOW_HOUSE_XP"] = "Показывать полосу опыта дома"
L["ENDEAVORS_OPT_SHOW_HOUSE_XP_TIP"] = "Отображать уровень дома и полосу прогресса опыта"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR"] = "Показывать полосу предприятия"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TIP"] = "Отображать полосу прогресса предприятия района"
L["ENDEAVORS_OPT_SHOW_XP_TEXT"] = "Текст на полосе опыта"
L["ENDEAVORS_OPT_SHOW_XP_TEXT_TIP"] = "Отображать числовые значения на полосе опыта дома"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT"] = "Текст на полосе предприятия"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT_TIP"] = "Отображать числовые значения на полосе прогресса предприятия"
L["ENDEAVORS_OPT_SHOW_XP_PCT"] = "Проценты на полосе опыта"
L["ENDEAVORS_OPT_SHOW_XP_PCT_TIP"] = "Отображать проценты на полосе опыта дома"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_PCT"] = "Проценты на полосе предприятия"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_PCT_TIP"] = "Отображать проценты на полосе прогресса предприятия"
L["ENDEAVORS_XP_TOOLTIP_TITLE"] = "Прогресс уровня дома"
L["ENDEAVORS_XP_TOOLTIP_LEVEL"] = "Уровень дома: %d"
L["ENDEAVORS_XP_TOOLTIP_LEVEL_MAX"] = "Уровень дома: %d (Макс.)"
L["ENDEAVORS_XP_TOOLTIP_PROGRESS"] = "Опыт: %s / %s (%d%%)"
L["ENDEAVORS_XP_TOOLTIP_CLICK"] = "Клик: открыть панель дома"
L["ENDEAVORS_TOOLTIP_CLICK"] = "Клик: открыть меню предприятий"
L["ENDEAVORS_PCT_DONE"] = "ГОТОВО"
L["OPTIONS_SECTION_ENDEAVORS"] = "Предприятия"
L["OPTIONS_ENDEAVORS_ENABLED"] = "Включить панель предприятий"
L["OPTIONS_ENDEAVORS_ENABLED_TOOLTIP"] = "Показывать мини-панель предприятий, когда вы находитесь в жилом районе с домом"
L["ENDEAVORS_OPT_ENABLED"] = "Включить панель предприятий"
L["ENDEAVORS_OPT_ENABLED_TIP"] = "Показывать панель предприятий, когда вы находитесь в жилом районе с домом"
L["ENDEAVORS_COMPLETED_TIMES"] = "Завершено %d |4раз:раза:раз;"
L["ENDEAVORS_TIME_DAYS_LEFT"] = "Осталось %d |4день:дня:дней;"
L["ENDEAVORS_TIME_HOURS_LEFT"] = "Осталось %d |4час:часа:часов;"
L["ENDEAVORS_COUPONS_EARNED"] = "%s: %d/%d"
L["ENDEAVORS_OPT_SCALE"] = "Размер панели"
L["ENDEAVORS_OPT_SCALE_TIP"] = "Изменить масштаб панели предприятий"
L["ENDEAVORS_OPT_SCALE_SMALL"] = "Маленький"
L["ENDEAVORS_OPT_SCALE_NORMAL"] = "Обычный"
L["ENDEAVORS_OPT_SCALE_BIG"] = "Большой"
L["ENDEAVORS_MILESTONE_COMPLETED"] = "завершено"

--------------------------------------------------------------------------------
-- PvP Tab
--------------------------------------------------------------------------------
L["TAB_PVP"] = "PVP"
L["TAB_PVP_DESC"] = "PvP-источники предметов декора"
L["PVP_SEARCH_PLACEHOLDER"] = "Поиск PvP-источников или предметов..."
L["PVP_FILTER_ALL"] = "Все"
L["PVP_FILTER_INCOMPLETE"] = "Не собрано"
L["PVP_FILTER_COMPLETE"] = "Собрано"
L["PVP_CATEGORY_ACHIEVEMENTS"] = "Достижения"
L["PVP_CATEGORY_VENDORS"] = "Торговцы"
L["PVP_CATEGORY_DROPS"] = "Добыча"
L["PVP_EMPTY_NO_SOURCES"] = "PvP-источники не найдены"
L["PVP_EMPTY_NO_SOURCES_DESC"] = "Данные о PvP могут быть недоступны"
L["PVP_SELECT_CATEGORY"] = "Выберите категорию"
L["PVP_EMPTY_NO_RESULTS"] = "Нет PvP-источников, подходящих под поиск"
L["SETTINGS_CATEGORY_NAME"] = "Housing |cffFB7104Codex|r"

--------------------------------------------------------------------------------
-- Renown Tab
--------------------------------------------------------------------------------
L["TAB_RENOWN"] = "ИЗВЕСТНОСТЬ"
L["TAB_RENOWN_DESC"] = "Источники декора за репутацию"
L["RENOWN_SEARCH_PLACEHOLDER"] = "Поиск фракций..."
L["RENOWN_FILTER_ALL"] = "Все"
L["RENOWN_FILTER_INCOMPLETE"] = "Не все собрано"
L["RENOWN_FILTER_COMPLETE"] = "Все собрано"
L["RENOWN_LOCKED"] = "Еще не открыто"
L["RENOWN_REQUIRED"] = "Требуется: %s"
L["RENOWN_REP_MET"] = "Репутация получена"
L["RENOWN_CURRENTLY_AT"] = "текущий уровень: "
L["RENOWN_NEEDS_ALLIANCE"] = "Требуется персонаж Альянса"
L["RENOWN_NEEDS_HORDE"] = "Требуется персонаж Орды"
L["RENOWN_WAYPOINT_VENDOR"] = "%s (%s)"
L["RENOWN_PROGRESS_FORMAT"] = "%d/%d"
L["RENOWN_RANK_FORMAT"] = "Ранг %d"
L["RENOWN_STANDING_GOOD_FRIEND"] = "Почтенный друг"
L["RENOWN_FACTION_UNKNOWN_FORMAT"] = "Фракция №%d"
L["RENOWN_SELECT_EXPANSION"] = "Выберите дополнение"
L["RENOWN_EMPTY_NO_RESULTS"] = "Нет фракций, подходящих под фильтры"
L["RENOWN_EMPTY_NO_DATA"] = "Загрузка данных о репутации..."

--------------------------------------------------------------------------------
-- Game Entity Names (drop sources, encounter names, treasure locations)
-- Translators: copy this block to your locale file, change the values.
-- These names appear in the Drops tab and PvP tab source lists.
--------------------------------------------------------------------------------
local SN = addon.sourceNameLocale

-- Drops
SN["Darkshore (BfA phase) Rare Drop"] = "Редкая добыча: Темные берега (фаза BfA)"
SN["Highmountain Tauren Paragon Chest"] = "Сундук идеала тауренов Крутогорья"
SN["In-Game Shop"] = "Внутриигровой магазин"
SN["Login Reward (Midnight)"] = "Награда за вход (Midnight)"
SN["Midnight Delves"] = "Вылазки: Midnight"
SN["Self-Assembling Homeware Kit (Mechagon)"] = "Самособирающийся хозяйственный набор (Мехагон)"
SN["Shadowmoon Valley (Draenor) Missives"] = "Донесения: Долина Призрачной Луны (Дренор)"
SN["Strange Recycling Requisition (Mechagon)"] = "Странное вторичное сырье (Мехагон)"
SN["Theater Troupe event chest (Isle of Dorn)"] = "Сундук события «Театральная труппа» (Остров Дорн)"
SN["Twitch Drop"] = "Twitch Drop"
SN["Twitch drop (Feb 26 to Mar 24)"] = "Twitch Drop (с 26 фев по 24 мар)"
SN["Undermine Jobs"] = "Работа в Нижней Шахте"
SN["Victorious Stormarion Cache"] = "Тайник штормарионского победителя"
SN["Zillow & Warcraft collab"] = "Коллаборация Zillow и Warcraft"
SN["Zillow for Warcraft Promotion"] = "Акция «Zillow для Warcraft»"

-- Encounters (bosses)
SN["Advisor Melandrus (Court of Stars)"] = "Советник Меландр (Квартал Звезд)"
SN["Belo'ren, Child of Al'ar"] = "Бело'рен, дитя Ал'ара"
SN["Charonus (Voidscar Arena)"] = "Харон (Арена Шрама Бездны)"
SN["Chimaerus the Undreamt God"] = "Химерий, Неприснившийся Бог"
SN["Crown of the Cosmos (The Voidspire)"] = "Корона Космоса (Шпиль Бездны)"
SN["Dargrul the Underking"] = "Даргрул Король подземелий"
SN["Degentrius (Magisters' Terrace)"] = "Дегентрий (Терраса Магистров)"
SN["Echo of Doragosa (Algeth'ar Academy)"] = "Эхо Дорагосы (Академия Алгет'ар)"
SN["Emperor Dagran Thaurissan (Blackrock Depths)"] = "Император Дагран Тауриссан (Глубины Черной горы)"
SN["Fallen-King Salhadaar (The Voidspire)"] = "Падший король Салхадаар (Шпиль Бездны)"
SN["Garrosh Hellscream (Siege of Orgrimmar)"] = "Гаррош Адский Крик (Осада Оргриммара)"
SN["Goldie Baronbottom (Cinderbrew Meadery)"] = "Голди Барондон (Искроварня)"
SN["Harlan Sweete (Freehold)"] = "Красавчик Харлан (Вольная Гавань)"
SN["High Sage Viryx (Skyreach)"] = "Высший мудрец Вирикс (Небесный Путь)"
SN["Imperator Averzian (The Voidspire)"] = "Император Аверзиан (Шпиль Бездны)"
SN["King Mechagon"] = "Король Мехагон"
SN["Kyrakka and Erkhart Stormvein"] = "Киракка и Эркхарт Кровь Бури"
SN["L'ura (The Seat of the Triumvirate)"] = "Л'ура (Престол Триумвирата)"
SN["Lightblinded Vanguard"] = "Ослепленный Светом авангард"
SN["Lithiel Cinderfury (Murder Row)"] = "Литиэль Пепельная Ярость (Закоулок душегубов)"
SN["Lord Godfrey (Shadowfang Keep)"] = "Лорд Годфри (Крепость Темного Клыка)"
SN["Lothraxion (Nexus-Point Xenas)"] = "Лотраксион (Узел Нексуса Зенас)"
SN["Midnight Falls (March on Quel'Danas)"] = "Торжество Полуночи (Марш на Кель'Данас)"
SN["Nalorakk"] = "Налоракк"
SN["Prioress Murrpray (Priory of the Sacred Flame)"] = "Настоятельница Муррпрэй (Приорат Священного Пламени)"
SN["Rak'tul, Vessel of Souls"] = "Рак'тул, Сосуд душ"
SN["Scourgelord Tyrannus (Pit of Saron)"] = "Повелитель Плети Тираний (Яма Сарона)"
SN["Sha of Doubt (Temple of the Jade Serpent)"] = "Ша Сомнения (Храм Нефритовой Змеи)"
SN["Shade of Xavius (Darkheart Thicket)"] = "Тень Ксавия (Чаща Темного Сердца)"
SN["Skulloc (Iron Docks)"] = "Черепон (Железные доки)"
SN["Spellblade Aluriel (The Nighthold)"] = "Заклинательница клинков Алуриэль (Цитадель Ночи)"
SN["Teron'gor"] = "Терон'кров"
SN["The Darkness"] = "Тьма"
SN["The Restless Cabal"] = "Неутомимый конклав"
SN["The Restless Heart"] = "Неупокоенное сердце"
SN["Vaelgor & Ezzorak"] = "Велгор и Эззорак"
SN["Vanessa VanCleef"] = "Ванесса ван Клиф"
SN["Viz'aduum the Watcher (Karazhan)"] = "Виз'адуум Всевидящий (Каражан)"
SN["Vol'zith the Whisperer (Shrine of the Storm)"] = "Вол'зит Шепчущая (Святилище Штормов)"
SN["Vorasius (The Voidspire)"] = "Ненасытникус (Шпиль Бездны)"
SN["Warlord Sargha (Neltharus)"] = "Полководец Сарга (Нелтарий)"
SN["Warlord Zaela"] = "Полководец Зела"
SN["Ziekket (The Blinding Vale)"] = "Зиккет (Слепящая долина)"

-- Treasures
SN["Gift of the Phoenix (Eversong Woods)"] = "Дар феникса (Леса Вечной Песни)"
SN["Golden Cloud Serpent Treasure Chest (Jade Forest)"] = "Золотой сундук облачного змея (Нефритовый лес)"
SN["Incomplete Book of Sonnets (Eversong Woods)"] = "Неполная книга сонетов (Леса Вечной Песни)"
SN["Malignant Chest (Voidstorm)"] = "Тлетворный сундук (Буря Бездны)"
SN["Stellar Stash (Slayer's Rise)"] = "Звездный тайник (Зубец убийцы)"
SN["Stone Vat (Eversong Woods)"] = "Каменный чан (Леса Вечной Песни)"
SN["Triple-Locked Safebox (Eversong Woods)"] = "Сейф с тремя замками (Леса Вечной Песни)"
SN["Undermine"] = "Нижняя Шахта"
SN["World Glimmering Treasure Chest Drop"] = "Добыча из Сверкающих сундуков с сокровищами (мир)"

-- Manual quest title translations (quests without quest IDs)
local QT = addon.questTitleLocale

-- Keybinding globals (deferred from Init.lua — WoW resolves these lazily when Keybindings UI opens)
BINDING_HEADER_HCODEX = L["KEYBIND_HEADER"]
BINDING_NAME_HOUSINGCODEX_TOGGLE = L["KEYBIND_TOGGLE"]
