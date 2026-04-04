--[[
    Housing Codex - zhCN.lua
    Simplified Chinese localization
]]

if GetLocale() ~= "zhCN" then return end

local _, addon = ...
local L = addon.L

--------------------------------------------------------------------------------
-- General
--------------------------------------------------------------------------------
L["ADDON_NAME"] = "Housing Codex"
L["KEYBIND_HEADER"] = "|cffffd100Housing|r |cffff8000Codex|r"
L["KEYBIND_TOGGLE"] = "|cffff8000Housing Codex|r 切换窗口"
L["LOADING"] = "加载中..."
L["LOADING_DATA"] = "正在加载装饰数据..."
L["LOADED_MESSAGE"] = "已收集 |cFF88EE88%.1f%%|r 装饰物品。输入 |cFF88BBFF/hc|r 打开。"
L["COMBAT_LOCKDOWN_MESSAGE"] = "战斗中无法打开界面"

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------
L["TAB_DECOR"] = "装饰"
L["TAB_QUESTS"] = "任务"
L["TAB_ACHIEVEMENTS"] = "成就"
L["TAB_VENDORS"] = "商人"
L["TAB_DROPS"] = "掉落"
L["TAB_PROFESSIONS"] = "专业"
L["TAB_ACHIEVEMENTS_SHORT"] = "成就"
L["TAB_PROFESSIONS_SHORT"] = "专业"
L["TAB_PROGRESS_SHORT"] = "进度"
L["TAB_DECOR_DESC"] = "浏览和搜索所有住宅装饰物品"
L["TAB_QUESTS_DESC"] = "住宅装饰物品的任务来源"
L["TAB_ACHIEVEMENTS_DESC"] = "住宅装饰物品的成就来源"
L["TAB_VENDORS_DESC"] = "出售住宅装饰物品的商人位置"
L["TAB_DROPS_DESC"] = "住宅装饰物品的掉落来源"
L["TAB_PROFESSIONS_DESC"] = "专业制作的住宅装饰物品"

--------------------------------------------------------------------------------
-- Search & Filters
--------------------------------------------------------------------------------
L["SEARCH_PLACEHOLDER"] = "搜索..."
L["FILTER_ALL"] = "所有物品"
L["FILTER_COLLECTED"] = "已收集"
L["FILTER_NOT_COLLECTED"] = "未收集"
L["FILTER_TRACKABLE"] = "仅可追踪"
L["FILTER_NOT_TRACKABLE"] = "不可追踪"
L["FILTER_TRACKABLE_HEADER"] = "可追踪"
L["FILTER_TRACKABLE_ALL"] = "全部"
L["FILTER_INDOORS"] = "室内"
L["FILTER_OUTDOORS"] = "室外"
L["FILTER_DYEABLE"] = "可染色"
L["FILTER_FIRST_ACQUISITION"] = "收集奖励"
L["FILTER_WISHLIST_ONLY"] = "仅愿望清单"
L["FILTERS"] = "过滤器"
L["CHECK_ALL"] = "勾选所有"
L["UNCHECK_ALL"] = "撤选所有"

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------
L["SIZE_LABEL"] = "尺寸："
L["SORT_BY_LABEL"] = "排序方式"

--------------------------------------------------------------------------------
-- Sort
--------------------------------------------------------------------------------
L["SORT_NEWEST"] = "添加日期"
L["SORT_ALPHABETICAL"] = "字母顺序"
L["SORT_SIZE"] = "尺寸大小"
L["SORT_QUANTITY"] = "拥有数量"
L["SORT_PLACED"] = "放置数量"
L["SORT_NEWEST_TIP"] = "首先显示最新添加的装饰"
L["SORT_ALPHABETICAL_TIP"] = "按字母顺序排序 (A 到 Z)"
L["SORT_SIZE_TIP"] = "首先显示最大装饰 (超大到微小)"
L["SORT_QUANTITY_TIP"] = "首先显示拥有数量最多的物品"
L["SORT_PLACED_TIP"] = "首先显示在住宅中放置数量最多的物品"

--------------------------------------------------------------------------------
-- Result Count & Empty State
--------------------------------------------------------------------------------
L["RESULT_COUNT_ALL"] = "显示 %d 件物品"
L["RESULT_COUNT_FILTERED"] = "显示 %d / %d 件物品"
L["RESULT_COUNT_TOOLTIP_UNIQUE"] = "独特装饰收集: %d / %d (%.1f%%)"
L["RESULT_COUNT_TOOLTIP_ROOMS"] = "已解锁房间: %d / %d"
L["RESULT_COUNT_TOOLTIP_OWNED"] = "装饰拥有总数: %d"
L["RESULT_COUNT_TOOLTIP_TOTAL"] = "物品总数: %d (%d 装饰, %d 房间)"
L["EMPTY_STATE_MESSAGE"] = "没有物品符合您的筛选条件"
L["RESET_FILTERS"] = "重置过滤器"

--------------------------------------------------------------------------------
-- Category Navigation
--------------------------------------------------------------------------------
L["CATEGORY_ALL"] = "全部"
L["CATEGORY_BACK"] = "返回"
L["CATEGORY_ALL_IN"] = "所有 %s"

--------------------------------------------------------------------------------
-- Details Panel
--------------------------------------------------------------------------------
L["DETAILS_NO_SELECTION"] = "请选择一件物品"
L["DETAILS_OWNED"] = "已拥有: %d"
L["DETAILS_PLACED"] = "已放置: %d"
L["DETAILS_NOT_OWNED"] = "未拥有"
L["DETAILS_SIZE"] = "尺寸："
L["DETAILS_PLACE"] = "放置位置："
L["DETAILS_DYEABLE"] = "可染色"
L["DETAILS_NOT_DYEABLE"] = "不可染色"
L["DETAILS_SOURCE_UNKNOWN"] = "来源未知"
L["UNKNOWN"] = "未知"

-- Size names
L["SIZE_TINY"] = "微小"
L["SIZE_SMALL"] = "小号"
L["SIZE_MEDIUM"] = "中号"
L["SIZE_LARGE"] = "大号"
L["SIZE_HUGE"] = "超大"

-- Placement types
L["PLACEMENT_IN"] = "室内"
L["PLACEMENT_OUT"] = "室外"

--------------------------------------------------------------------------------
-- Wishlist
--------------------------------------------------------------------------------
L["WISHLIST_ADD"] = "添加到愿望清单"
L["WISHLIST_REMOVE"] = "从愿望清单中移除"
L["WISHLIST_ADDED"] = "已添加到愿望清单: %s"
L["WISHLIST_REMOVED"] = "已从愿望清单移除: %s"
L["WISHLIST_BUTTON"] = "愿望清单"
L["WISHLIST_BUTTON_TOOLTIP"] = "查看您的愿望清单"
L["CODEX_BUTTON"] = "HOUSING CODEX"
L["CODEX_BUTTON_TOOLTIP"] = "返回主界面"
L["WISHLIST_TITLE"] = "愿望清单"
L["WISHLIST_EMPTY"] = "您的愿望清单是空的"
L["WISHLIST_EMPTY_DESC"] = "通过点击装饰或任务标签页中的星形图标添加物品"
L["WISHLIST_SHIFT_CLICK"] = "Shift+点击 以添加/移除愿望清单"

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------
L["ACTION_TRACK"] = "追踪"
L["ACTION_UNTRACK"] = "取消追踪"
L["ACTION_LINK"] = "链接"
L["ACTION_TRACK_TOOLTIP"] = "在目标追踪器中追踪此物品"
L["ACTION_UNTRACK_TOOLTIP"] = "停止追踪此物品"
L["ACTION_TRACK_DISABLED_TOOLTIP"] = "此物品无法被追踪"
L["ACTION_LINK_TOOLTIP"] = "将物品链接插入聊天"
L["ACTION_LINK_TOOLTIP_RIGHTCLICK"] = "右键点击: 复制Wowhead链接"
L["TRACKING_ERROR_MAX"] = "无法追踪: 已达到最大追踪物品数量"
L["TRACKING_ERROR_UNTRACKABLE"] = "此物品无法被追踪"
L["TRACKING_STARTED"] = "正在追踪: %s"
L["TRACKING_STOPPED"] = "已停止追踪: %s"
L["TOOLTIP_SHIFT_CLICK_TRACK"] = "Shift+点击 以追踪"
L["TOOLTIP_SHIFT_CLICK_UNTRACK"] = "Shift+点击 以取消追踪"
L["TRACKING_ERROR_GENERIC"] = "追踪失败"
L["LINK_ERROR"] = "无法创建物品链接"
L["LINK_INSERTED"] = "链接已插入聊天"

--------------------------------------------------------------------------------
-- Preview
--------------------------------------------------------------------------------
L["PREVIEW_NO_MODEL"] = "无可用3D模型"
L["PREVIEW_NO_SELECTION"] = "选择一件物品进行预览"
L["PREVIEW_ERROR"] = "加载模型错误"
L["PREVIEW_NOT_IN_CATALOG"] = "尚未加入住宅目录"

--------------------------------------------------------------------------------
-- Settings (WoW Native Settings UI)
--------------------------------------------------------------------------------
L["OPTIONS_SECTION_DISPLAY"] = "显示"
L["OPTIONS_SECTION_MAP_NAV"] = "地图与导航"
L["OPTIONS_SECTION_VENDOR"] = "商人"
L["OPTIONS_SHOW_COLLECTED"] = "在格子上显示数量指示器"
L["OPTIONS_SHOW_COLLECTED_TOOLTIP"] = "在网格格子上显示拥有和放置数量"
L["OPTIONS_SHOW_MINIMAP"] = "显示小地图按钮"
L["OPTIONS_SHOW_MINIMAP_TOOLTIP"] = "在小地图上显示住宅图鉴按钮"
L["OPTIONS_VENDOR_INDICATORS"] = "在商人处标记装饰物品"
L["OPTIONS_VENDOR_INDICATORS_TOOLTIP"] = "在出售住宅装饰物品的商人处显示住宅图鉴图标"
L["OPTIONS_VENDOR_OWNED_CHECKMARK"] = "为已拥有的装饰显示勾选标记"
L["OPTIONS_VENDOR_OWNED_CHECKMARK_TOOLTIP"] = "在您已拥有的商人装饰物品上显示绿色勾选标记"
L["OPTIONS_SECTION_CONTAINERS"] = "背包与银行"
L["OPTIONS_CONTAINER_INDICATORS"] = "标记背包与银行中的装饰物品"
L["OPTIONS_CONTAINER_INDICATORS_TOOLTIP"] = "在背包与银行中属于住宅装饰的物品上显示住宅图鉴图标"
L["OPTIONS_CONTAINER_OWNED_CHECKMARK"] = "已拥有装饰物品显示对勾"
L["OPTIONS_CONTAINER_OWNED_CHECKMARK_TOOLTIP"] = "在背包与银行中，为您已拥有的装饰物品显示绿色对勾标记"
L["OPTIONS_VENDOR_MAP_PINS"] = "显示商人地图标记"
L["OPTIONS_VENDOR_MAP_PINS_TOOLTIP"] = "在世界地图上显示包含收集进度的商人标记"
L["OPTIONS_TREASURE_HUNT_WAYPOINTS"] = "寻宝自动路径点"
L["OPTIONS_TREASURE_HUNT_WAYPOINTS_TOOLTIP"] = "在接受住宅区域的装饰寻宝任务时自动设置地图路径点"
L["OPTIONS_USE_TOMTOM"] = "使用TomTom设置路径点"
L["OPTIONS_USE_TOMTOM_TOOLTIP"] = "当TomTom插件已安装时，使用其路径点功能替代游戏原生地图标记"
L["OPTIONS_USE_TOMTOM_NOT_INSTALLED"] = "使用TomTom设置路径点（未安装）"
L["OPTIONS_AUTO_ROTATE_PREVIEW"] = "自动旋转3D预览"
L["OPTIONS_AUTO_ROTATE_PREVIEW_TOOLTIP"] = "在预览面板和愿望清单中缓慢旋转3D模型"
L["OPTIONS_SECTION_BROKER"] = "小地图按钮 / 信息栏显示"
L["OPTIONS_LDB_UNIQUE"] = "显示独特装饰收集数"
L["OPTIONS_LDB_UNIQUE_TOOLTIP"] = "在小地图信息栏文本中显示独特装饰收集数量"
L["OPTIONS_LDB_ROOMS"] = "显示已解锁房间数"
L["OPTIONS_LDB_ROOMS_TOOLTIP"] = "在小地图信息栏文本中显示已解锁房间数量"
L["OPTIONS_LDB_TOTAL_OWNED"] = "显示装饰拥有总数"
L["OPTIONS_LDB_TOTAL_OWNED_TOOLTIP"] = "在小地图信息栏文本中显示装饰拥有总数（包括重复）"
L["OPTIONS_LDB_TOTAL"] = "显示物品总数"
L["OPTIONS_LDB_TOTAL_TOOLTIP"] = "在小地图信息栏文本中显示目录物品总数"
L["OPTIONS_RESET_POSITION"] = "重置窗口位置"
L["OPTIONS_RESET_POSITION_TOOLTIP"] = "将窗口重置到屏幕中央"
L["OPTIONS_RESET_SIZE"] = "重置窗口大小"
L["OPTIONS_RESET_SIZE_TOOLTIP"] = "将窗口重置为其默认大小"
L["OPTIONS_SHOW_WELCOME"] = "欢迎屏幕"
L["OPTIONS_SHOW_WELCOME_TOOLTIP"] = "显示欢迎屏幕"
L["SIZE_RESET"] = "窗口大小已重置为默认值。"

L["OPTIONS_SECTION_KEYBIND"] = "按键绑定"
L["OPTIONS_SECTION_TROUBLESHOOTING"] = "故障排除"
L["OPTIONS_TOGGLE_KEYBIND"] = "切换窗口："
L["OPTIONS_NOT_BOUND"] = "未绑定"
L["OPTIONS_PRESS_KEY"] = "请按一个键..."
L["OPTIONS_UNBIND_TOOLTIP"] = "右键点击取消绑定"
L["OPTIONS_KEYBIND_HINT"] = "点击设置按键绑定。右键点击清除。ESC取消。"
L["OPTIONS_KEYBIND_CONFLICT"] = ""%s" 已被绑定到 "%s"。\n\n是否要将其重新分配给住宅图鉴？"

--------------------------------------------------------------------------------
-- Slash Command Help
--------------------------------------------------------------------------------
L["HELP_TITLE"] = "住宅图鉴命令："
L["HELP_TOGGLE"] = "/hc - 切换主窗口"
L["HELP_SETTINGS"] = "/hc settings - 打开设置"
L["HELP_RESET"] = "/hc reset - 重置窗口位置"
L["HELP_RETRY"] = "/hc retry - 重试加载数据"
L["HELP_HELP"] = "/hc help - 显示此帮助"
L["HELP_DEBUG"] = "/hc debug - 切换调试模式"
L["HELP_STATS"] = "/hc stats - 显示调试计数器"

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------
L["SETTINGS_NOT_AVAILABLE"] = "设置暂不可用"
L["RETRYING_DATA_LOAD"] = "重试加载数据..."
L["DEBUG_MODE_STATUS"] = "调试模式: %s"
L["FONT_MODE_STATUS"] = "自定义字体: %s"
L["DEBUG_ON"] = "开启"
L["DEBUG_OFF"] = "关闭"
L["DATA_NOT_LOADED"] = "数据尚未加载"
L["INSPECT_FOUND"] = "找到: %s (ID: %d)"
L["INSPECT_NOT_FOUND"] = "未找到匹配: %s 的物品"
L["MAIN_WINDOW_NOT_AVAILABLE"] = "主窗口暂不可用"
L["POSITION_RESET"] = "窗口位置已重置到中央"

--------------------------------------------------------------------------------
-- Errors
--------------------------------------------------------------------------------
L["ERROR_API_UNAVAILABLE"] = "住宅API不可用"
L["ERROR_LOAD_FAILED"] = "多次尝试后仍未能加载住宅数据。使用 /hc retry 重试。"
L["ERROR_LOAD_FAILED_SHORT"] = "加载数据失败。使用 /hc retry 重试"

--------------------------------------------------------------------------------
-- LDB (LibDataBroker)
--------------------------------------------------------------------------------
L["LDB_TOOLTIP_LEFT"] = "|cffffffff左键点击|r 切换主窗口"
L["LDB_TOOLTIP_RIGHT"] = "|cffffffff右键点击|r 打开选项"
L["LDB_TOOLTIP_ALT"] = "|cffffffffAlt+点击|r 配置信息显示"
L["LDB_OPTIONS_PLACEHOLDER"] = "选项面板暂不可用"
L["LDB_POPUP_TITLE"] = "信息显示"
L["LDB_TOOLTIP_DECOR_HEADER"] = "收藏统计"
L["LDB_POPUP_UNIQUE"] = "独特装饰"
L["LDB_POPUP_ROOMS"] = "已解锁房间"
L["LDB_POPUP_TOTAL_OWNED"] = "装饰拥有总数"
L["LDB_POPUP_TOTAL_ITEMS"] = "物品总数"

--------------------------------------------------------------------------------
-- Quests Tab
--------------------------------------------------------------------------------
L["QUESTS_SEARCH_PLACEHOLDER"] = "搜索任务、区域或奖励..."
L["QUESTS_FILTER_ALL"] = "全部"
L["QUESTS_FILTER_INCOMPLETE"] = "未完成"
L["QUESTS_FILTER_COMPLETE"] = "已完成"
L["QUESTS_EMPTY_NO_SOURCES"] = "未找到任务来源"
L["QUESTS_EMPTY_NO_SOURCES_DESC"] = "任务数据可能未通过魔兽世界API公开"
L["QUESTS_SELECT_EXPANSION"] = "选择一个资料片"
L["QUESTS_EMPTY_NO_RESULTS"] = "未找到匹配的任务。"
L["QUESTS_UNKNOWN_QUEST"] = "任务 #%d"
L["QUESTS_UNKNOWN_ZONE"] = "未知区域"
L["QUESTS_UNKNOWN_EXPANSION"] = "其他"

-- Quest tracking messages
L["QUESTS_TRACKING_STARTED"] = "正在追踪物品"
L["QUESTS_TRACKING_MAX_REACHED"] = "无法追踪 - 已达到最大物品数量 (15)"
L["QUESTS_TRACKING_ALREADY"] = "已在追踪此物品"
L["QUESTS_TRACKING_FAILED"] = "无法追踪此物品"

-- Expansion names
L["EXPANSION_CLASSIC"] = "经典旧世"
L["EXPANSION_TBC"] = "燃烧的远征"
L["EXPANSION_WRATH"] = "巫妖王之怒"
L["EXPANSION_CATA"] = "大地的裂变"
L["EXPANSION_MOP"] = "熊猫人之谜"
L["EXPANSION_WOD"] = "德拉诺之王"
L["EXPANSION_LEGION"] = "军团再临"
L["EXPANSION_BFA"] = "争霸艾泽拉斯"
L["EXPANSION_SL"] = "暗影国度"
L["EXPANSION_DF"] = "巨龙时代"
L["EXPANSION_TWW"] = "地心之战"
L["EXPANSION_MIDNIGHT"] = "至暗之夜"

--------------------------------------------------------------------------------
-- Achievements Tab
--------------------------------------------------------------------------------
L["ACHIEVEMENTS_SEARCH_PLACEHOLDER"] = "搜索成就、奖励或类别..."
L["ACHIEVEMENTS_FILTER_ALL"] = "全部"
L["ACHIEVEMENTS_FILTER_INCOMPLETE"] = "未完成"
L["ACHIEVEMENTS_FILTER_COMPLETE"] = "已完成"
L["ACHIEVEMENTS_EMPTY_NO_SOURCES"] = "未找到成就来源"
L["ACHIEVEMENTS_EMPTY_NO_SOURCES_DESC"] = "成就数据可能不可用"
L["ACHIEVEMENTS_SELECT_CATEGORY"] = "选择一个类别"
L["ACHIEVEMENTS_EMPTY_NO_RESULTS"] = "没有成就符合您的搜索"
L["ACHIEVEMENTS_UNKNOWN"] = "成就 #%d"

-- Achievement tracking messages
L["ACHIEVEMENTS_TRACKING_STARTED"] = "正在追踪物品"
L["ACHIEVEMENTS_TRACKING_STARTED_ACHIEVEMENT"] = "正在追踪成就"
L["ACHIEVEMENTS_TRACKING_STOPPED"] = "已停止追踪成就"
L["ACHIEVEMENTS_TRACKING_MAX_REACHED"] = "无法追踪 - 已达到最大物品数量 (15)"
L["ACHIEVEMENTS_TRACKING_ALREADY"] = "已在追踪此物品"
L["ACHIEVEMENTS_TRACKING_FAILED"] = "无法追踪此成就"

--------------------------------------------------------------------------------
-- Context Menu
--------------------------------------------------------------------------------
L["CONTEXT_MENU_LINK_TO_CHAT"] = "链接到聊天"
L["CONTEXT_MENU_COPY_WOWHEAD"] = "复制Wowhead链接"

--------------------------------------------------------------------------------
-- Vendors Tab
--------------------------------------------------------------------------------
L["VENDORS_SEARCH_PLACEHOLDER"] = "搜索商人、区域或物品..."
L["VENDORS_FILTER_ALL"] = "全部"
L["VENDORS_FILTER_INCOMPLETE"] = "未完成"
L["VENDORS_FILTER_COMPLETE"] = "已完成"
L["VENDORS_CURRENT_ZONE"] = "当前区域"
L["VENDORS_EMPTY_NO_SOURCES"] = "未找到商人来源"
L["VENDORS_EMPTY_NO_SOURCES_DESC"] = "商人数据可能不可用"
L["VENDORS_SELECT_EXPANSION"] = "选择一个资料片"
L["VENDORS_UNKNOWN_EXPANSION"] = "其他"
L["VENDORS_UNKNOWN_ZONE"] = "未知区域"

-- Vendor waypoint messages
L["VENDOR_SET_WAYPOINT"] = "设置路径点"
L["VENDOR_NO_LOCATION"] = "位置未知"
L["VENDOR_WAYPOINT_SET"] = "已为 %s 设置路径点"
L["VENDOR_MAP_RESTRICTED"] = "无法在此地图上设置路径点"

-- Vendor fallback names
L["VENDOR_UNKNOWN"] = "未知商人"
L["VENDOR_FALLBACK_NAME"] = "商人"

-- Vendor world map pins
L["VENDOR_PIN_COLLECTED"] = "已收集: %d/%d"
L["VENDOR_PIN_UNCOLLECTED_HEADER"] = "未收集的装饰:"
L["VENDOR_PIN_ITEM_LOCKED"] = "已锁定"
L["VENDOR_PIN_MORE"] = "+%d 更多"
L["VENDOR_PIN_CLICK_WAYPOINT"] = "点击设置路径点"
L["VENDOR_PIN_FACTION_ALLIANCE"] = "仅限联盟"
L["VENDOR_PIN_FACTION_HORDE"] = "仅限部落"
L["VENDOR_PIN_VENDOR_COUNT"] = "%d 个商人"
L["VENDOR_PIN_VENDOR_LIST_HEADER"] = "商人列表:"
L["VENDOR_PIN_VENDOR_ENTRY"] = "%s (%d/%d)"
L["VENDOR_PIN_VENDORS_MORE"] = "+%d 更多商人"

-- Vendor tracking messages
L["VENDORS_TRACKING_STARTED"] = "已为 %s 在 %s 添加地图标记"
L["VENDORS_TRACKING_STOPPED"] = "已移除 %s 在 %s 的地图标记"
L["VENDORS_ACTION_TRACK"] = "路径点"
L["VENDORS_ACTION_UNTRACK"] = "移除路径点"
L["VENDORS_ACTION_TRACK_TOOLTIP"] = "通过设置前往商人的路径点来追踪此商人物品"
L["VENDORS_ACTION_UNTRACK_TOOLTIP"] = "停止此物品的商人路径点追踪"
L["VENDORS_ACTION_TRACK_DISABLED_TOOLTIP"] = "此商人没有有效的路径点位置"

-- Vendor cost display
L["CURRENCY_GOLD"] = "金币"
-- Vendor decor fallback
L["VENDORS_DECOR_ID"] = "装饰 #%d"
L["VENDOR_CAT_ACCENTS"] = "装饰品"
L["VENDOR_CAT_FUNCTIONAL"] = "功能性"
L["VENDOR_CAT_FURNISHINGS"] = "家具"
L["VENDOR_CAT_LIGHTING"] = "照明"
L["VENDOR_CAT_MISCELLANEOUS"] = "杂项"
L["VENDOR_CAT_NATURE"] = "自然"
L["VENDOR_CAT_STRUCTURAL"] = "建筑"
L["VENDOR_CAT_UNCATEGORIZED"] = "未分类"

-- Vendor zone annotations
L["VENDOR_CLASS_HALL_SUFFIX"] = "职业大厅"
L["VENDOR_HOUSING_ZONE_SUFFIX"] = "住宅区域"
L["VENDOR_CLASS_ONLY_SUFFIX"] = "仅 %s"

-- Vendor tooltip overlay
L["OPTIONS_VENDOR_TOOLTIPS"] = "在提示信息中显示住宅装饰物品"
L["OPTIONS_VENDOR_TOOLTIPS_TOOLTIP"] = "鼠标悬停于装饰商人NPC时，显示住宅图鉴收集进度"

--------------------------------------------------------------------------------
-- Drops Tab
--------------------------------------------------------------------------------
L["DROPS_SEARCH_PLACEHOLDER"] = "搜索掉落来源或物品..."
L["DROPS_FILTER_ALL"] = "全部"
L["DROPS_FILTER_INCOMPLETE"] = "未完成"
L["DROPS_FILTER_COMPLETE"] = "已完成"
L["DROPS_EMPTY_NO_SOURCES"] = "未找到掉落来源"
L["DROPS_EMPTY_NO_SOURCES_DESC"] = "掉落数据可能不可用"
L["DROPS_SELECT_CATEGORY"] = "选择一个类别"
L["DROPS_EMPTY_NO_RESULTS"] = "没有符合您搜索条件的掉落来源"

-- Drop source category labels
L["DROPS_CATEGORY_DROP"] = "掉落"
L["DROPS_CATEGORY_ENCOUNTER"] = "首领"
L["DROPS_CATEGORY_TREASURE"] = "宝箱"

-- Drop source display
L["DROPS_DECOR_ID"] = "装饰 #%d"

--------------------------------------------------------------------------------
-- Professions Tab
--------------------------------------------------------------------------------
L["PROFESSIONS_SEARCH_PLACEHOLDER"] = "搜索专业或物品..."
L["PROFESSIONS_FILTER_ALL"] = "全部"
L["PROFESSIONS_FILTER_INCOMPLETE"] = "未完成"
L["PROFESSIONS_FILTER_COMPLETE"] = "已完成"
L["PROFESSIONS_EMPTY_NO_SOURCES"] = "无制作来源"
L["PROFESSIONS_EMPTY_NO_SOURCES_DESC"] = "制作来源数据尚不可用。"
L["PROFESSIONS_SELECT_PROFESSION"] = "选择一个专业"
L["PROFESSIONS_EMPTY_NO_RESULTS"] = "无结果"

--------------------------------------------------------------------------------
-- Treasure Hunt Waypoints
--------------------------------------------------------------------------------
L["TREASURE_HUNT_WAYPOINT_SET"] = "已标记宝藏位置"

--------------------------------------------------------------------------------
-- Progress Tab
--------------------------------------------------------------------------------
L["TAB_PROGRESS"] = "进度"
L["TAB_PROGRESS_DESC"] = "收集进度概览"
L["PROGRESS_COLLECTED"] = "已收集"
L["PROGRESS_TOTAL"] = "总计"
L["PROGRESS_REMAINING"] = "剩余"
L["PROGRESS_BY_SOURCE"] = "按来源"
L["PROGRESS_VENDOR_EXPANSIONS"] = "商人(按资料片)"
L["PROGRESS_QUEST_EXPANSIONS"] = "任务(按资料片)"
L["PROGRESS_RENOWN_EXPANSIONS"] = "名望(按资料片)"
L["PROGRESS_PROFESSIONS"] = "专业"
L["PROGRESS_ALMOST_THERE"] = "进度最高"
L["PROGRESS_OVERVIEW"] = "进度概览"
L["PROGRESS_ALL_DECOR_COLLECTED"] = "已收集所有装饰"
L["PROGRESS_SOURCE_ALL"] = "所有装饰"
L["PROGRESS_SOURCE_VENDORS"] = "商人"
L["PROGRESS_SOURCE_QUESTS"] = "任务"
L["PROGRESS_SOURCE_ACHIEVEMENTS"] = "成就"
L["PROGRESS_SOURCE_PROFESSIONS"] = "专业"
L["PROGRESS_SOURCE_PVP"] = "PvP"
L["PROGRESS_SOURCE_DROPS"] = "掉落"
L["PROGRESS_SOURCE_RENOWN"] = "名望"
L["PROGRESS_LOADING"] = "加载进度数据中..."

--------------------------------------------------------------------------------
-- Zone Overlay (World Map)
--------------------------------------------------------------------------------
L["ZONE_OVERLAY_VENDORS"] = "商人"
L["ZONE_OVERLAY_QUESTS"] = "任务"
L["ZONE_OVERLAY_TREASURE"] = "寻宝"
L["ZONE_OVERLAY_COUNT"] = "此区域有 %d 件装饰"
L["ZONE_OVERLAY_BUTTON_TOOLTIP"] = "Housing Codex"
L["ZONE_OVERLAY_SHOW"] = "显示区域覆盖"
L["ZONE_OVERLAY_PINS"] = "显示商人地图标记"
L["ZONE_OVERLAY_POSITION"] = "面板位置"
L["ZONE_OVERLAY_POS_TOPLEFT"] = "左上"
L["ZONE_OVERLAY_POS_BOTTOMRIGHT"] = "右下"
L["ZONE_OVERLAY_TRANSPARENCY"] = "透明度"
L["ZONE_OVERLAY_INCLUDE_COLLECTED_VENDORS"] = "包括已解锁的装饰"
L["ZONE_OVERLAY_SOURCE_VENDOR"] = "(商人)"
L["ZONE_OVERLAY_SOURCE_VENDOR_CITY"] = "(|cFFFF8C00%s|r 的商人)"
L["ZONE_OVERLAY_CLICK_WAYPOINT"] = "左键点击设置地图标记"
L["ZONE_OVERLAY_CLICK_OPEN_HC"] = "右键点击在住宅图鉴中打开"
L["ZONE_OVERLAY_PREVIEW_SIZE"] = "预览大小"
L["ZONE_OVERLAY_SECTION_HEADER"] = "区域覆盖层"
L["ZONE_OVERLAY_COLLAPSED_TOOLTIP"] = "点击查看此区域的装饰物品"
L["VENDOR_PINS_SECTION_HEADER"] = "商人地图标记"
L["VENDOR_PINS_TRANSPARENCY"] = "标记透明度"
L["VENDOR_PINS_SCALE"] = "标记大小"
-- VENDOR_PINS_LAYER removed: custom frame levels tainted WorldMapFrame (WoWUIBugs #811)
L["OPTIONS_ZONE_OVERLAY"] = "在世界地图上显示区域覆盖"
L["OPTIONS_ZONE_OVERLAY_TOOLTIP"] = "在世界地图上显示一个面板，展示当前区域可用的装饰物品"

--------------------------------------------------------------------------------
-- What's New Popup
--------------------------------------------------------------------------------
L["WHATSNEW_TITLE"] = "住宅图鉴新功能"
L["WHATSNEW_DONT_SHOW"] = "不再为此版本(v%s)显示"
L["WHATSNEW_EXPLORE"] = "探索住宅图鉴"
L["WHATS_NEW_NO_IMAGE"] = "截图"

--------------------------------------------------------------------------------
-- Welcome Popup
--------------------------------------------------------------------------------
L["WELCOME_TITLE"] = "欢迎使用住宅图鉴"
L["WELCOME_SUBTITLE"] = "您发现装饰物品和管理住宅的好帮手"
L["WELCOME_START"] = "开始探索"
L["WELCOME_QUICK_SETUP"] = "快速设置"
L["WELCOME_OPEN_WITH"] = "您可以随时通过以下方式打开插件"
L["WELCOME_SET_KEYBIND"] = "或按下您设置的"
L["WELCOME_KEYBIND_LABEL"] = "按键绑定："

--------------------------------------------------------------------------------
-- What's New: v1.5.0 feature highlights
--------------------------------------------------------------------------------
L["WHATSNEW_V150_F1_TITLE"] = "收集仪表盘"
L["WHATSNEW_V150_F1_DESC"] = "一目了然地查看您的装饰收集进度——总体统计、按来源类型，以及进度最高的类别。"
L["WHATSNEW_V150_F2_TITLE"] = "专业追踪"
L["WHATSNEW_V150_F2_DESC"] = "通过专用进度条追踪每个专业的制作进度。"
L["WHATSNEW_V150_F3_TITLE"] = "智能导航"
L["WHATSNEW_V150_F3_DESC"] = "点击任意进度行直接跳转到对应来源标签页。"
L["WHATSNEW_V150_F4_TITLE"] = "可点击的愿望清单链接"
L["WHATSNEW_V150_F4_DESC"] = "在聊天中分享愿望清单物品作为可点击链接，他人可以预览。"

--------------------------------------------------------------------------------
-- Welcome feature highlights
--------------------------------------------------------------------------------
L["WELCOME_F1_TITLE"] = "互动3D预览"
L["WELCOME_F1_DESC"] = "以3D预览任何装饰：旋转、缩放和调整查看器大小。"
L["WELCOME_F2_TITLE"] = "装饰目录与网格"
L["WELCOME_F2_DESC"] = "在可自定义的网格中浏览完整目录，快速搜索和筛选。"
L["WELCOME_F3_TITLE"] = "来源与发现"
L["WELCOME_F3_DESC"] = "查看如何获取缺失的装饰：任务、成就、商人、掉落、专业。"
L["WELCOME_F4_TITLE"] = "商人标识"
L["WELCOME_F4_DESC"] = "商人界面显示装饰图标，使可收集物品一目了然。"
L["WELCOME_F5_TITLE"] = "地图整合"
L["WELCOME_F5_DESC"] = "地图标记显示装饰商人的位置，区域覆盖指引您找到缺失的装饰。"
L["WELCOME_F6_TITLE"] = "收集进度"
L["WELCOME_F6_DESC"] = "进度条一目了然地显示您按类别划分的收集状态。"

--------------------------------------------------------------------------------
-- Endeavors Panel
--------------------------------------------------------------------------------
L["ENDEAVORS_TITLE"] = "家园任务"
L["ENDEAVORS_OPTIONS"] = "家园任务选项"
L["ENDEAVORS_OPTIONS_TOOLTIP"] = "配置家园任务覆盖面板"
L["ENDEAVORS_MAX_LEVEL"] = "满级"
L["ENDEAVORS_PROGRESS_FORMAT"] = "进度：%d / %d"
L["ENDEAVORS_YOUR_CONTRIBUTION"] = "您的贡献：%d"
L["ENDEAVORS_MILESTONES"] = "里程碑"
L["ENDEAVORS_OPT_SECTION_GENERAL"]  = "常规"
L["ENDEAVORS_OPT_SECTION_HOUSE_XP"] = "家园经验"
L["ENDEAVORS_OPT_SECTION_ENDEAVOR"] = "征程进度"
L["ENDEAVORS_OPT_SECTION_SIZE"]     = "面板大小"
L["ENDEAVORS_OPT_SHOW_HOUSE_XP"] = "显示家园经验条"
L["ENDEAVORS_OPT_SHOW_HOUSE_XP_TIP"] = "显示家园等级与经验进度条"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR"] = "显示征程进度条"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TIP"] = "显示区域征程进度条"
L["ENDEAVORS_OPT_SHOW_XP_TEXT"] = "显示经验条数值"
L["ENDEAVORS_OPT_SHOW_XP_TEXT_TIP"] = "在家园经验条上显示具体数值"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT"] = "显示征程条数值"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_TEXT_TIP"] = "在征程进度条上显示具体数值"
L["ENDEAVORS_OPT_SHOW_XP_PCT"] = "显示经验条百分比"
L["ENDEAVORS_OPT_SHOW_XP_PCT_TIP"] = "在家园经验条上显示百分比"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_PCT"] = "显示征程条百分比"
L["ENDEAVORS_OPT_SHOW_ENDEAVOR_PCT_TIP"] = "在征程进度条上显示百分比"
L["ENDEAVORS_XP_TOOLTIP_TITLE"] = "住宅等级进度"
L["ENDEAVORS_XP_TOOLTIP_LEVEL"] = "住宅等级：%d"
L["ENDEAVORS_XP_TOOLTIP_LEVEL_MAX"] = "住宅等级：%d（满级）"
L["ENDEAVORS_XP_TOOLTIP_PROGRESS"] = "经验：%s / %s (%d%%)"
L["ENDEAVORS_XP_TOOLTIP_CLICK"] = "点击打开住宅控制台"
L["ENDEAVORS_TOOLTIP_CLICK"] = "点击打开家园任务"
L["ENDEAVORS_PCT_DONE"] = "已完成"
L["OPTIONS_SECTION_ENDEAVORS"] = "家园任务"
L["OPTIONS_ENDEAVORS_ENABLED"] = "启用家园任务面板"
L["OPTIONS_ENDEAVORS_ENABLED_TOOLTIP"] = "当身处拥有住宅的社区时，显示家园任务迷你面板"
L["ENDEAVORS_OPT_ENABLED"] = "启用家园任务面板"
L["ENDEAVORS_OPT_ENABLED_TIP"] = "当身处拥有住宅的社区时，显示家园任务面板"
L["ENDEAVORS_COMPLETED_TIMES"] = "已完成 %d |4次:次;"
L["ENDEAVORS_TIME_DAYS_LEFT"] = "剩余 %d |4天:天;"
L["ENDEAVORS_TIME_HOURS_LEFT"] = "剩余 %d |4小时:小时;"
L["ENDEAVORS_COUPONS_EARNED"] = "%s: %d/%d"
L["ENDEAVORS_OPT_SCALE"] = "面板大小"
L["ENDEAVORS_OPT_SCALE_TIP"] = "调整家园任务面板的尺寸"
L["ENDEAVORS_OPT_SCALE_SMALL"] = "小"
L["ENDEAVORS_OPT_SCALE_NORMAL"] = "中"
L["ENDEAVORS_OPT_SCALE_BIG"] = "大"
L["ENDEAVORS_MILESTONE_COMPLETED"] = "已完成"

--------------------------------------------------------------------------------
-- PvP Tab
--------------------------------------------------------------------------------
L["TAB_PVP"] = "PvP"
L["TAB_PVP_DESC"] = "住宅装饰物品的PvP来源"
L["PVP_SEARCH_PLACEHOLDER"] = "搜索PvP来源或物品..."
L["PVP_FILTER_ALL"] = "全部"
L["PVP_FILTER_INCOMPLETE"] = "未完成"
L["PVP_FILTER_COMPLETE"] = "已完成"
L["PVP_CATEGORY_ACHIEVEMENTS"] = "成就"
L["PVP_CATEGORY_VENDORS"] = "商人"
L["PVP_CATEGORY_DROPS"] = "掉落"
L["PVP_EMPTY_NO_SOURCES"] = "未找到PvP来源"
L["PVP_EMPTY_NO_SOURCES_DESC"] = "PvP数据可能暂不可用"
L["PVP_SELECT_CATEGORY"] = "选择类别"
L["PVP_EMPTY_NO_RESULTS"] = "没有符合您搜索条件的PvP来源"
L["SETTINGS_CATEGORY_NAME"] = "Housing |cffFB7104Codex|r"

--------------------------------------------------------------------------------
-- Renown Tab
--------------------------------------------------------------------------------
L["TAB_RENOWN"] = "声望"
L["TAB_RENOWN_DESC"] = "房屋装饰的声望来源"
L["RENOWN_SEARCH_PLACEHOLDER"] = "搜索阵营..."
L["RENOWN_FILTER_ALL"] = "全部"
L["RENOWN_FILTER_INCOMPLETE"] = "未完成"
L["RENOWN_FILTER_COMPLETE"] = "已完成"
L["RENOWN_SELECT_EXPANSION"] = "选择一个资料片"
L["RENOWN_EMPTY_NO_RESULTS"] = "没有阵营符合您的筛选条件"
L["RENOWN_EMPTY_NO_DATA"] = "声望数据加载中..."
L["RENOWN_LOCKED"] = "尚未解锁"
L["RENOWN_REQUIRED"] = "需要 %s"
L["RENOWN_REP_MET"] = "声望已达成"
L["RENOWN_CURRENTLY_AT"] = "当前进度："
L["RENOWN_NEEDS_ALLIANCE"] = "需要一个联盟角色"
L["RENOWN_NEEDS_HORDE"] = "需要一个部落角色"
L["RENOWN_WAYPOINT_VENDOR"] = "%s（%s）"
L["RENOWN_PROGRESS_FORMAT"] = "%d/%d"
L["RENOWN_RANK_FORMAT"] = "等级 %d"

--------------------------------------------------------------------------------
-- Game Entity Names (drop sources, encounter names, treasure locations)
--------------------------------------------------------------------------------
local SN = addon.sourceNameLocale

-- Drops
SN["Darkshore (BfA phase) Rare Drop"] = "黑海岸（争霸艾泽拉斯）稀有掉落"
SN["Highmountain Tauren Paragon Chest"] = "至高岭牛头人巅峰宝箱"
SN["Login Reward (Midnight)"] = "登录奖励（至暗之夜）"
SN["Midnight Delves"] = "至暗之夜地下堡"
SN["Self-Assembling Homeware Kit (Mechagon)"] = "自组装家居套件（麦卡贡）"
SN["Shadowmoon Valley (Draenor) Missives"] = "影月谷（德拉诺）密文"
SN["Strange Recycling Requisition (Mechagon)"] = "奇怪的回收申请单（麦卡贡）"
SN["Theater Troupe event chest (Isle of Dorn)"] = "剧场巡演宝箱（多恩岛）"
SN["Twitch Drop"] = "Twitch平台掉落"
SN["Undermine Jobs"] = "安德麦任务"
SN["Twitch drop (Feb 26 to Mar 24)"] = "Twitch平台掉落（2月26日至3月24日）"
SN["Zillow & Warcraft collab"] = "Zillow与魔兽世界联动"
SN["Zillow for Warcraft Promotion"] = "Zillow魔兽世界推广活动"

-- Encounters (bosses)
SN["Advisor Melandrus (Court of Stars)"] = "顾问麦兰杜斯（群星庭院）"
SN["Belo'ren, Child of Al'ar"] = "贝洛朗，奥的子嗣"
SN["Charonus (Voidscar Arena)"] = "煞戎努斯（虚空之痕竞技场）"
SN["Chimaerus the Undreamt God"] = "奇美鲁斯，未梦之神"
SN["Crown of the Cosmos (The Voidspire)"] = "宇宙之冕（虚影尖塔）"
SN["Dargrul the Underking"] = "地底之王达古尔"
SN["Degentrius (Magisters' Terrace)"] = "迪詹崔乌斯（魔导师平台）"
SN["Echo of Doragosa (Algeth'ar Academy)"] = "多拉苟萨的回响（艾杰斯亚学院）"
SN["Emperor Dagran Thaurissan (Blackrock Depths)"] = "达格兰·索瑞森大帝（黑石深渊）"
SN["Fallen-King Salhadaar (The Voidspire)"] = "陨落之王萨哈达尔（虚影尖塔）"
SN["Garrosh Hellscream (Siege of Orgrimmar)"] = "加尔鲁什·地狱咆哮（决战奥格瑞玛）"
SN["Goldie Baronbottom (Cinderbrew Meadery)"] = "戈尔迪·底爵（燧酿酒庄）"
SN["Harlan Sweete (Freehold)"] = "哈兰·斯威提（自由镇）"
SN["High Sage Viryx (Skyreach)"] = "高阶贤者维里克斯（通天峰）"
SN["Imperator Averzian (The Voidspire)"] = "元首阿福扎恩（虚影尖塔）"
SN["King Mechagon"] = "麦卡贡国王"
SN["Kyrakka and Erkhart Stormvein"] = "基拉卡与厄克哈特·风脉"
SN["L'ura (The Seat of the Triumvirate)"] = "鲁拉（执政团之座）"
SN["Lightblinded Vanguard"] = "光盲先锋军"
SN["Lithiel Cinderfury (Murder Row)"] = "利希尔·烬怒（密谋小径）"
SN["Lord Godfrey (Shadowfang Keep)"] = "高弗雷勋爵（影牙城堡）"
SN["Lothraxion (Nexus-Point Xenas)"] = "洛萨克森（节点希纳斯）"
SN["Midnight Falls (March on Quel'Danas)"] = "至暗之夜降临（进军奎尔丹纳斯）"
SN["Nalorakk"] = "纳洛拉克"
SN["Prioress Murrpray (Priory of the Sacred Flame)"] = "隐修院长穆普雷（圣焰隐修院）"
SN["Rak'tul, Vessel of Souls"] = "拉克图尔，灵魂容器"
SN["Scourgelord Tyrannus (Pit of Saron)"] = "天灾领主泰兰努斯（萨隆矿坑）"
SN["Sha of Doubt (Temple of the Jade Serpent)"] = "疑之煞（青龙寺）"
SN["Shade of Xavius (Darkheart Thicket)"] = "萨维斯之影（黑心林地）"
SN["Skulloc (Iron Docks)"] = "斯古洛克（钢铁码头）"
SN["Spellblade Aluriel (The Nighthold)"] = "魔剑士奥鲁瑞尔（暗夜要塞）"
SN["Teron'gor"] = "塔隆戈尔"
SN["The Darkness"] = "黑暗之主"
SN["The Restless Cabal"] = "无眠秘党"
SN["The Restless Heart"] = "无眠之心"
SN["Vaelgor & Ezzorak"] = "威厄高尔与艾佐拉克"
SN["Vanessa VanCleef"] = "梵妮莎·范克里夫"
SN["Viz'aduum the Watcher (Karazhan)"] = "监视者维兹艾德姆（重返卡拉赞）"
SN["Vol'zith the Whisperer (Shrine of the Storm)"] = "低语者沃尔兹斯（风暴神殿）"
SN["Vorasius (The Voidspire)"] = "弗拉希乌斯（虚影尖塔）"
SN["Warlord Sargha (Neltharus)"] = "督军莎尔佳（奈萨鲁斯）"
SN["Warlord Zaela"] = "督军扎伊拉"
SN["Ziekket (The Blinding Vale)"] = "兹欧凯特（夺目谷）"

-- Treasures
SN["Gift of the Phoenix (Eversong Woods)"] = "凤凰的礼物（永歌森林）"
SN["Golden Cloud Serpent Treasure Chest (Jade Forest)"] = "金色云端翔龙宝箱（翡翠林）"
SN["Incomplete Book of Sonnets (Eversong Woods)"] = "未完成的十四行诗集（永歌森林）"
SN["Malignant Chest (Voidstorm)"] = "怨毒宝箱（虚影风暴）"
SN["Stellar Stash (Slayer's Rise)"] = "星穹贮藏（屠戮者高地）"
SN["Stone Vat (Eversong Woods)"] = "石缸（永歌森林）"
SN["Triple-Locked Safebox (Eversong Woods)"] = "三道锁的保险箱（永歌森林）"
SN["Undermine"] = "安德麦"
SN["World Glimmering Treasure Chest Drop"] = "世界闪闪光光的宝箱掉落"

-- Manual quest title translations (quests without quest IDs)
local QT = addon.questTitleLocale

-- Keybinding globals (deferred from Init.lua -- WoW resolves these lazily when Keybindings UI opens)
BINDING_HEADER_HCODEX = L["KEYBIND_HEADER"]
BINDING_NAME_HOUSINGCODEX_TOGGLE = L["KEYBIND_TOGGLE"]
