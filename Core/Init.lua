--[[
    Housing Codex - Init.lua
    Addon namespace initialization, event systems, and core setup
]]

-- Keybinding localization strings (must be global for WoW keybinding UI)
BINDING_HEADER_HCODEX = "|cffffd100Housing|r |cffff8000Codex|r"
BINDING_NAME_HOUSINGCODEX_TOGGLE = "|cffff8000HC|r Toggle Window"

local ADDON_NAME, addon = ...

-- Export addon table globally for other files and debugging
HousingCodex = addon

-- Version info (read from TOC at runtime - single source of truth)
addon.version = C_AddOns.GetAddOnMetadata("HousingCodex", "Version") or "unknown"
addon.addonName = ADDON_NAME

-- Localization table (populated by Locales/*.lua)
addon.L = {}

-- Module registry (for cross-file communication)
addon.modules = {}

-- Data state
addon.dataLoaded = false
addon.decorRecords = {}

-- Constants
addon.CONSTANTS = {
    -- Grid system
    GRID_OUTER_PAD = 6,
    GRID_CELL_GAP = 4,
    DEFAULT_TILE_SIZE = 180,
    MIN_TILE_SIZE = 64,
    MAX_TILE_SIZE = 350,

    -- Frame dimensions
    DEFAULT_FRAME_WIDTH = 1200,
    DEFAULT_FRAME_HEIGHT = 800,
    MIN_FRAME_WIDTH = 400,
    MIN_FRAME_HEIGHT = 400,

    -- Layout
    SIDEBAR_WIDTH = 167,
    HEADER_HEIGHT = 32,

    -- Horizontal tabs (in title bar)
    HTAB_ICON_SIZE = 18,
    HTAB_HEIGHT = 26,
    HTAB_GAP = 4,
    HTAB_PADDING_X = 10,  -- Horizontal padding inside tab

    -- Category navigation
    CATEGORY_BUTTON_HEIGHT = 32,
    CATEGORY_ICON_SIZE = 20,
    CATEGORY_PADDING = 8,

    -- Icon display
    ICON_CROP_COORDS = { 0.08, 0.92, 0.08, 0.92 },  -- Standard WoW icon border crop

    -- Wishlist star badge
    WISHLIST_STAR_SIZE_GRID = 20,     -- Star size on grid tiles
    WISHLIST_STAR_SIZE_PREVIEW = 24,  -- Star button size in preview details
    WISHLIST_STAR_SIZE_HIERARCHY = 14, -- Small star for hierarchy rows (quests/achievements)

    -- Hierarchy layout (QuestsTab, AchievementsTab)
    HIERARCHY_PADDING = 8,              -- Padding for quest/achievement hierarchies
    HIERARCHY_ROW_HEIGHT = 26,          -- Quest/achievement row height
    HIERARCHY_HEADER_HEIGHT = 32,       -- Expansion/zone/category header height
    HIERARCHY_PANEL_WIDTH = 198,        -- Left panel width (expansions/categories)

    -- Colors (DaevTools palette)
    COLORS = {
        GOLD = { 1, 0.82, 0, 1 },
        GOLD_DIM = { 0.8, 0.66, 0, 1 },
        TITLE = { 0.9, 0.85, 0.5, 1 },
        SIDEBAR_BG = { 0.05, 0.05, 0.08, 0.9 },
        CONTENT_BG = { 0, 0, 0, 0.8 },
        TAB_NORMAL = { 0.1, 0.1, 0.12, 0.8 },
        TAB_HOVER = { 0.15, 0.15, 0.17, 0.9 },
        TAB_SELECTED = { 0.12, 0.12, 0.14, 1 },
        TEXT_PRIMARY = { 1, 1, 1, 1 },
        TEXT_SECONDARY = { 0.9, 0.9, 0.9, 1 },
        TEXT_TERTIARY = { 0.7, 0.7, 0.7, 1 },
        TEXT_DISABLED = { 0.5, 0.5, 0.5, 1 },
        BORDER = { 0.3, 0.3, 0.3, 1 },

        -- Progress indicators (hierarchy tabs)
        PROGRESS_COMPLETE = { 0.2, 1, 0.2, 1 },     -- Green for 100%
        PROGRESS_NEAR_COMPLETE = { 0.6, 0.9, 0.1, 1 }, -- Yellow-green for 91-99%
        PROGRESS_MID = { 0.75, 0.65, 0.35, 1 },     -- Muted tan for 34-65%
        PROGRESS_LOW_DIM = { 0.6, 0.6, 0.6, 1 },    -- Dimmer gray for 0-33%

        -- Panel backgrounds (hierarchy panels)
        PANEL_NORMAL = { 0.14, 0.14, 0.16, 0.9 },
        PANEL_HOVER = { 0.19, 0.19, 0.21, 1 },
        PANEL_NORMAL_ALT = { 0.12, 0.12, 0.14, 0.95 },  -- Zone/darker variant
        PANEL_HOVER_ALT = { 0.16, 0.16, 0.18, 1 },

        -- Selection state
        ROW_SELECTED = { 0.20, 0.20, 0.22, 1 },
    },

    -- Font path
    FONT_PATH = "Interface\\AddOns\\HousingCodex\\Fonts\\Roboto_Condensed_semibold.ttf",

    -- Content tracking (Blizzard enums resolved at load time)
    TRACKING_TYPE_DECOR = Enum.ContentTrackingType.Decor,
    MAX_TRACKED = Constants.ContentTrackingConsts.MaxTrackedCollectableSources,

    -- Housing sizes (Enum.HousingCatalogEntrySize values → localization keys)
    -- Use these instead of magic numbers for patch-proof code
    HOUSING_SIZE_KEYS = {
        [0] = nil,             -- Enum.HousingCatalogEntrySize.None
        [65] = "SIZE_TINY",    -- Enum.HousingCatalogEntrySize.Tiny
        [66] = "SIZE_SMALL",   -- Enum.HousingCatalogEntrySize.Small
        [67] = "SIZE_MEDIUM",  -- Enum.HousingCatalogEntrySize.Medium
        [68] = "SIZE_LARGE",   -- Enum.HousingCatalogEntrySize.Large
        [69] = "SIZE_HUGE",    -- Enum.HousingCatalogEntrySize.Huge
    },

    -- Sort types (native = HousingCatalogSearcher, client-side >= 100)
    SORT_NATIVE_NEWEST = 0,    -- Enum.HousingCatalogSortType.DateAdded
    SORT_NATIVE_ALPHA = 1,     -- Enum.HousingCatalogSortType.Alphabetical
    SORT_CLIENT_SIZE = 100,    -- Client-side: by size (Huge → None)
    SORT_CLIENT_QUANTITY = 101, -- Client-side: by quantity owned
    SORT_CLIENT_PLACED = 102,   -- Client-side: by quantity placed

    -- Category navigation
    BUILTIN_ALL_CATEGORY_ID = Constants.HousingCatalogConsts.HOUSING_CATALOG_ALL_CATEGORY_ID,

    -- Camera constants (WoW globals with correct fallback values per API)
    CAMERA = {
        TRANSITION_IMMEDIATE = CAMERA_TRANSITION_TYPE_IMMEDIATE or 1,
        MODIFICATION_DISCARD = CAMERA_MODIFICATION_TYPE_DISCARD or 1,
        MODIFICATION_MAINTAIN = CAMERA_MODIFICATION_TYPE_MAINTAIN or 1,
    },

    -- Scene presets by Enum.HousingCatalogEntrySize values (0, 65-69)
    -- record.size uses these actual enum values, not 0-5 indices
    SCENE_PRESETS = {
        [0]  = Enum.HousingCatalogEntryModelScenePresets.DecorDefault,   -- None
        [65] = Enum.HousingCatalogEntryModelScenePresets.DecorTiny,
        [66] = Enum.HousingCatalogEntryModelScenePresets.DecorSmall,
        [67] = Enum.HousingCatalogEntryModelScenePresets.DecorMedium,
        [68] = Enum.HousingCatalogEntryModelScenePresets.DecorLarge,
        [69] = Enum.HousingCatalogEntryModelScenePresets.DecorHuge,
    },
    DEFAULT_SCENE_ID = Enum.HousingCatalogEntryModelScenePresets.DecorDefault,

    -- Button styling
    TOGGLE_BUTTON_BACKDROP = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    },

    -- Action button styling (same style as Collected/Uncollected filters)
    ACTION_BUTTON = {
        MIN_WIDTH = 50,
        PADDING_H = 12,  -- 6px each side
        HEIGHT = 20,
        SPACING = 4,
        -- Colors
        COLOR_NORMAL = { 0.15, 0.15, 0.18, 0.9 },
        COLOR_HOVER = { 0.2, 0.2, 0.24, 1 },
        COLOR_ACTIVE = { 0.25, 0.22, 0.1, 1 },
        COLOR_TEXT_NORMAL = { 0.7, 0.7, 0.7, 1 },
        COLOR_TEXT_ACTIVE = { 1, 0.82, 0, 1 },  -- Gold
        COLOR_BORDER_NORMAL = { 0.3, 0.3, 0.3, 1 },
        COLOR_BORDER_ACTIVE = { 0.6, 0.5, 0.1, 1 },
    },

    -- Vendor world map pins
    VENDOR_PIN = {
        SIZE = 22,
        SCALE_FACTOR = 1,
        SCALE_MIN = 0.7,
        SCALE_MAX = 1.3,
        TOOLTIP_ITEM_LIMIT = 10,
        REFRESH_DEBOUNCE = 0.1,
    },
}

-- Internal Event System
addon.internalEvents = {}

function addon:RegisterInternalEvent(event, callback)
    self.internalEvents[event] = self.internalEvents[event] or {}
    table.insert(self.internalEvents[event], callback)
end

function addon:UnregisterInternalEvent(event, callback)
    local callbacks = self.internalEvents[event]
    if not callbacks then return end

    for i, cb in ipairs(callbacks) do
        if cb == callback then
            table.remove(callbacks, i)
            return
        end
    end
end

function addon:FireEvent(event, ...)
    local callbacks = self.internalEvents[event]
    if not callbacks then return end

    for _, callback in ipairs(callbacks) do
        callback(...)
    end
end

-- WoW Event System
addon.eventFrame = CreateFrame("Frame")
addon.wowEventCallbacks = {}

function addon:RegisterWoWEvent(event, callback)
    self.wowEventCallbacks[event] = self.wowEventCallbacks[event] or {}
    table.insert(self.wowEventCallbacks[event], callback)
    self.eventFrame:RegisterEvent(event)
end

function addon:UnregisterWoWEvent(event, callback)
    local callbacks = self.wowEventCallbacks[event]
    if not callbacks then return end

    for i, cb in ipairs(callbacks) do
        if cb == callback then
            table.remove(callbacks, i)
            break
        end
    end

    if #callbacks == 0 then
        self.eventFrame:UnregisterEvent(event)
        self.wowEventCallbacks[event] = nil
    end
end

addon.eventFrame:SetScript("OnEvent", function(_, event, ...)
    local callbacks = addon.wowEventCallbacks[event]
    if not callbacks then return end

    for _, callback in ipairs(callbacks) do
        callback(...)
    end
end)

-- Utility Functions
function addon:Print(msg)
    print("|cFFFFD100Housing Codex:|r " .. tostring(msg))
end

function addon:Debug(msg)
    if self.db and self.db.settings and self.db.settings.debugMode then
        print("|cFF888888[HC Debug]|r " .. tostring(msg))
    end
end

-- Resets a background texture to a solid color mode (clears gradients)
function addon:ResetBackgroundTexture(bg)
    if not bg then return end
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1))
end

-- Helper to create a centered empty-state frame with optional description
function addon:CreateEmptyStateFrame(parent, messageKey, descKey, descWidth)
    local L = self.L
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.95)

    local hasDesc = descKey ~= nil
    local msg = self:CreateFontString(frame, "OVERLAY", hasDesc and "GameFontNormal" or "GameFontNormalLarge")
    msg:SetPoint("CENTER", 0, hasDesc and 10 or 0)
    msg:SetText(L[messageKey])
    msg:SetTextColor(hasDesc and 0.6 or 0.5, hasDesc and 0.6 or 0.5, hasDesc and 0.6 or 0.5, 1)

    if hasDesc then
        local desc = self:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        desc:SetPoint("TOP", msg, "BOTTOM", 0, -8)
        desc:SetText(L[descKey])
        desc:SetTextColor(0.5, 0.5, 0.5, 1)
        if descWidth then desc:SetWidth(descWidth) end
    end

    return frame
end

-- Helper to print content tracking results with standard error handling
function addon:PrintTrackingResult(errorCode, startedKey, failedKey, maxKey, alreadyKey)
    local L = self.L
    if errorCode == nil then
        self:Print(L[startedKey])
    elseif errorCode == Enum.ContentTrackingError.MaxTracked then
        self:Print(L[maxKey])
    elseif errorCode == Enum.ContentTrackingError.AlreadyTracked then
        self:Print(L[alreadyKey])
    else
        self:Print(L[failedKey])
    end
end

-- Creates a text-based action button (same style as Collected/Uncollected filters)
-- @param parent: Parent frame
-- @param label: Button text
-- @param onClick: Function called when button clicked
-- @param onTooltip: Optional function(btn) to show custom tooltip on hover
-- @return button: The button frame with UpdateVisuals(), SetActive(bool), SetEnabled(bool) methods
function addon:CreateActionButton(parent, label, onClick, onTooltip)
    local AB = self.CONSTANTS.ACTION_BUTTON
    local BACKDROP = self.CONSTANTS.TOGGLE_BUTTON_BACKDROP
    local COLORS = self.CONSTANTS.COLORS

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetBackdrop(BACKDROP)
    btn.isActive = false
    btn.isEnabled = true

    -- Create text first to measure width
    local text = self:CreateFontString(btn, "OVERLAY", "GameFontNormal")
    text:SetText(label)

    -- Calculate width from text, respecting minimum
    local textWidth = text:GetStringWidth()
    local btnWidth = math.max(AB.MIN_WIDTH, textWidth + AB.PADDING_H)
    btn:SetSize(btnWidth, AB.HEIGHT)

    text:SetPoint("CENTER")
    btn.text = text

    -- Update visuals based on active/enabled state
    local function UpdateVisuals()
        if not btn.isEnabled then
            -- Disabled state: dimmed appearance with darker text
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
            btn:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.6)
            btn.text:SetTextColor(0.35, 0.35, 0.35, 1)  -- Darker than TEXT_DISABLED
        elseif btn.isActive then
            btn:SetBackdropColor(unpack(AB.COLOR_ACTIVE))
            btn:SetBackdropBorderColor(unpack(AB.COLOR_BORDER_ACTIVE))
            btn.text:SetTextColor(unpack(AB.COLOR_TEXT_ACTIVE))
        else
            btn:SetBackdropColor(unpack(AB.COLOR_NORMAL))
            btn:SetBackdropBorderColor(unpack(AB.COLOR_BORDER_NORMAL))
            btn.text:SetTextColor(unpack(AB.COLOR_TEXT_NORMAL))
        end
    end
    btn.UpdateVisuals = UpdateVisuals

    -- Set active state (e.g., "currently tracking")
    function btn:SetActive(active)
        self.isActive = active
        UpdateVisuals()
    end

    -- Set enabled state (e.g., "item is trackable")
    function btn:SetEnabled(enabled)
        self.isEnabled = enabled
        UpdateVisuals()
    end

    -- Update button text
    function btn:SetText(newLabel)
        self.text:SetText(newLabel)
    end

    btn:SetScript("OnClick", function(_, mouseButton)
        if btn.isEnabled and onClick then
            onClick(btn, mouseButton)
        end
    end)

    btn:SetScript("OnEnter", function(b)
        if b.isEnabled and not b.isActive then
            b:SetBackdropColor(unpack(AB.COLOR_HOVER))
        end
        if onTooltip then
            onTooltip(b)
        end
    end)

    btn:SetScript("OnLeave", function(b)
        UpdateVisuals()
        GameTooltip:Hide()
    end)

    UpdateVisuals()
    return btn
end

function addon:MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                self:MergeDefaults(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            self:MergeDefaults(target[key], value)
        end
    end
end

-- Shared tile backdrop (used by Grid and WishlistFrame)
addon.TILE_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

-- Shared tile setup: creates icon, placed count, quantity, and wishlist star
-- Used by Grid.lua and WishlistFrame.lua to eliminate code duplication
-- @param tile: The tile frame (BackdropTemplate)
-- @param tileSize: Size of the tile
-- @param onLeaveCallback: Function(tile) called on mouse leave (for custom behavior)
function addon:SetupTileFrame(tile, tileSize, onLeaveCallback)
    local COLORS = self.CONSTANTS.COLORS
    local WISHLIST_STAR_SIZE = self.CONSTANTS.WISHLIST_STAR_SIZE_GRID

    tile:SetSize(tileSize, tileSize)
    tile:EnableMouse(true)
    tile:SetBackdrop(self.TILE_BACKDROP)
    tile:SetBackdropColor(0.06, 0.06, 0.08, 1)
    tile:SetBackdropBorderColor(unpack(COLORS.BORDER))

    -- Icon fills most of tile, leaving room for quantity at bottom
    local icon = tile:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 6, -6)
    icon:SetPoint("BOTTOMRIGHT", -6, 20)
    tile.icon = icon

    -- ModelScene created lazily on first use (see element initializer)
    -- Most items use 2D icons; only ~10% are model-only

    -- Placed count at bottom right (green)
    local placed = self:CreateFontString(tile, "OVERLAY", "GameFontHighlight")
    placed:SetPoint("BOTTOMRIGHT", -4, 3)
    placed:SetTextColor(0.4, 0.8, 0.4, 1)
    self:SetFontSize(placed, 13, "OUTLINE")
    placed:Hide()
    tile.placed = placed

    -- Quantity text at bottom right (subdued) - anchored dynamically
    local qty = self:CreateFontString(tile, "OVERLAY", "GameFontHighlight")
    qty:SetPoint("BOTTOMRIGHT", -4, 3)
    qty:SetTextColor(unpack(COLORS.TEXT_DISABLED))
    self:SetFontSize(qty, 13, "OUTLINE")
    tile.quantity = qty

    -- Wishlist star badge (top-right corner)
    local wishlistStar = tile:CreateTexture(nil, "OVERLAY")
    wishlistStar:SetSize(WISHLIST_STAR_SIZE, WISHLIST_STAR_SIZE)
    wishlistStar:SetPoint("TOPRIGHT", -2, -2)
    wishlistStar:SetAtlas("PetJournal-FavoritesIcon")
    wishlistStar:SetVertexColor(unpack(COLORS.GOLD))
    wishlistStar:Hide()
    tile.wishlistStar = wishlistStar

    -- OnLeave handler (OnEnter is set per-element in initializer)
    tile:SetScript("OnLeave", function(t)
        if onLeaveCallback then
            onLeaveCallback(t)
        end
    end)
end

-- ModelScene constants for tile 3D preview
local TILE_MODEL_SCENE_ID = 1317  -- HOUSING_CATALOG_DECOR_MODELSCENEID_DEFAULT
local TILE_MODEL_ACTOR_TAG = "decor"

-- Sets up a tile to display either a 3D model or 2D icon based on record data.
-- Creates ModelScene lazily on first use (most items use icons).
-- @param tile: The tile frame (must have .icon, optionally .modelScene)
-- @param record: The decor record (from addon:GetRecord)
-- @param cameraModType: Camera modification type (MAINTAIN or DISCARD)
function addon:SetupTileDisplay(tile, record, cameraModType)
    local useModelScene = record and record.isModelOnly and record.modelAsset

    if useModelScene then
        -- Lazy create ModelScene on first use
        if not tile.modelScene then
            local modelScene = CreateFrame("ModelScene", nil, tile, "NonInteractableModelSceneMixinTemplate")
            modelScene:SetPoint("TOPLEFT", 6, -6)
            modelScene:SetPoint("BOTTOMRIGHT", -6, 20)
            tile.modelScene = modelScene
            modelScene:TransitionToModelSceneID(TILE_MODEL_SCENE_ID, addon.CONSTANTS.CAMERA.TRANSITION_IMMEDIATE, cameraModType, true)
        end

        tile.icon:Hide()
        local modelScene = tile.modelScene
        local actor = modelScene:GetActorByTag(TILE_MODEL_ACTOR_TAG)
        if not actor then
            actor = modelScene:AcquireActor()
            if actor then
                modelScene.tagToActor = modelScene.tagToActor or {}
                modelScene.tagToActor[TILE_MODEL_ACTOR_TAG] = actor
            end
        end

        if actor then
            local success = actor:SetModelByFileID(record.modelAsset)
            if success then
                modelScene:Show()
                return true
            end
        end

        -- Fallback: model/actor failed, show icon instead
        if tile.modelScene then tile.modelScene:Hide() end
        tile.icon:SetTexture(record.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        tile.icon:Show()
        return false
    end

    -- Show 2D icon (texture or atlas)
    if tile.modelScene then tile.modelScene:Hide() end

    if record and record.iconType == "atlas" then
        tile.icon:SetAtlas(record.icon)
    elseif record then
        tile.icon:SetTexture(record.icon)
    else
        tile.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    tile.icon:Show()
    return true
end

-- Slash Commands
SLASH_HOUSINGCODEX1 = "/hc"
SLASH_HOUSINGCODEX2 = "/hcodex"
SLASH_HOUSINGCODEX3 = "/housingcodex"

SlashCmdList["HOUSINGCODEX"] = function(msg)
    local cmd = strlower(strtrim(msg or ""))
    local L = addon.L

    if cmd == "help" or cmd == "?" then
        addon:Print("|cFFFFD100" .. L["HELP_TITLE"] .. "|r")
        addon:Print("  " .. L["HELP_TOGGLE"])
        addon:Print("  " .. L["HELP_SETTINGS"])
        addon:Print("  " .. L["HELP_RESET"])
        addon:Print("  " .. L["HELP_RETRY"])
        addon:Print("  " .. L["HELP_HELP"])
        addon:Print("  " .. L["HELP_DEBUG"])
    elseif cmd == "settings" or cmd == "options" then
        if addon.Settings then
            addon.Settings:Open()
        else
            addon:Print(L["SETTINGS_NOT_AVAILABLE"])
        end
    elseif cmd == "retry" or cmd == "reload" then
        addon:Print(L["RETRYING_DATA_LOAD"])
        addon.loadRetryCount = 0
        addon.dataLoaded = false
        addon:LoadData()
    elseif cmd == "reset" then
        if addon.MainFrame then
            addon.MainFrame:ResetPosition()
        else
            addon:Print(L["MAIN_WINDOW_NOT_AVAILABLE"])
        end
    elseif cmd == "debug" then
        if addon.db then
            addon.db.settings.debugMode = not addon.db.settings.debugMode
            local status = addon.db.settings.debugMode and L["DEBUG_ON"] or L["DEBUG_OFF"]
            addon:Print(string.format(L["DEBUG_MODE_STATUS"], status))
        end
    elseif cmd:find("^inspect ") then
        -- Debug: inspect a record by partial name match
        local searchName = cmd:sub(9):lower()
        if not addon.dataLoaded then
            addon:Print(L["DATA_NOT_LOADED"])
            return
        end
        for recordID, record in pairs(addon.decorRecords) do
            if record.name:lower():find(searchName) then
                addon:Print(string.format(L["INSPECT_FOUND"], record.name, recordID))
                addon:Print("  icon: " .. tostring(record.icon) .. " (type: " .. type(record.icon) .. ")")
                addon:Print("  iconType: " .. tostring(record.iconType))
                addon:Print("  hasModelAsset: " .. tostring(record.hasModelAsset))
                addon:Print("  isModelOnly: " .. tostring(record.isModelOnly))
                addon:Print("  modelAsset: " .. tostring(record.modelAsset))
                -- Also get raw info from API
                local info = C_HousingCatalog.GetCatalogEntryInfo(record.entryID)
                if info then
                    addon:Print("  RAW iconTexture: " .. tostring(info.iconTexture) .. " (type: " .. type(info.iconTexture) .. ")")
                    addon:Print("  RAW iconAtlas: " .. tostring(info.iconAtlas) .. " (type: " .. type(info.iconAtlas) .. ")")
                    addon:Print("  RAW asset: " .. tostring(info.asset))
                    -- Try GetDecorIcon
                    local decorIcon = C_HousingDecor and C_HousingDecor.GetDecorIcon and C_HousingDecor.GetDecorIcon(recordID)
                    addon:Print("  GetDecorIcon: " .. tostring(decorIcon) .. " (type: " .. type(decorIcon) .. ")")
                end
                return
            end
        end
        addon:Print(string.format(L["INSPECT_NOT_FOUND"], searchName))
    elseif addon.MainFrame then
        addon.MainFrame:Toggle()
    else
        addon:Print("v" .. addon.version .. " - " .. L["MAIN_WINDOW_NOT_AVAILABLE"])
    end
end

-- Helper: Calculate completion progress color (orange at 0% -> green at 100%)
-- Used by QuestsTab and AchievementsTab for category/expansion completion percentages
-- @param percent: 0-100 percentage value
-- @return r, g, b, a color values
function addon:GetCompletionProgressColor(percent)
    local t = percent / 100
    local r = 0.8 - (0.4 * t)   -- 0.8 -> 0.4
    local g = 0.5 + (0.25 * t)  -- 0.5 -> 0.75
    local b = 0.2 + (0.15 * t)  -- 0.2 -> 0.35
    return r, g, b, 1
end

-- Helper: Update simple toolbar layout (search + filter container)
-- Used by QuestsTab, AchievementsTab, VendorsTab for responsive toolbar
-- Search box shrinks first, then hides; filter hides at narrower widths
-- Returns the new layout string, or nil if unchanged
local SEARCH_MAX_WIDTH = 200
local SEARCH_MIN_WIDTH = 80
local FILTER_WIDTH_ESTIMATE = 180  -- Approximate width of filter buttons + padding

function addon:UpdateSimpleToolbarLayout(currentLayout, toolbarWidth, searchBox, filterContainer)
    local paddingAndOffset = 60  -- GRID_OUTER_PAD + 40 + extra spacing

    -- Determine layout and search width
    local newLayout
    local searchWidth = SEARCH_MAX_WIDTH
    local showFilter = true

    -- Calculate available width assuming filter is shown
    local availableWithFilter = toolbarWidth - paddingAndOffset - FILTER_WIDTH_ESTIMATE

    if availableWithFilter >= SEARCH_MAX_WIDTH then
        -- Full width search box fits with filter
        newLayout = "full"
        searchWidth = SEARCH_MAX_WIDTH
    elseif availableWithFilter >= SEARCH_MIN_WIDTH then
        -- Shrink search box, keep filter
        newLayout = "full"
        searchWidth = availableWithFilter
    else
        -- Hide filter to make room for search
        showFilter = false
        local availableWithoutFilter = toolbarWidth - paddingAndOffset

        if availableWithoutFilter >= SEARCH_MAX_WIDTH then
            newLayout = "noFilter"
            searchWidth = SEARCH_MAX_WIDTH
        elseif availableWithoutFilter >= SEARCH_MIN_WIDTH then
            newLayout = "noFilter"
            searchWidth = availableWithoutFilter
        else
            -- Too narrow, hide search too
            newLayout = "minimal"
        end
    end

    -- Update search box width and visibility
    if searchBox then
        if newLayout == "minimal" then
            searchBox:Hide()
        else
            searchBox:SetWidth(searchWidth)
            searchBox:Show()
        end
    end

    -- Update filter visibility
    if filterContainer then filterContainer:SetShown(showFilter) end

    if currentLayout == newLayout then return nil end
    return newLayout
end

-- Helper: Generate Wowhead URL for a decor item
-- Used by PreviewFrame and WishlistFrame for link sharing
function addon:CreateWowheadURL(record)
    local slug = record.name:lower()
    slug = slug:gsub("%s+", "-")        -- spaces to hyphens
    slug = slug:gsub("[^%w%-]", "")     -- remove non-alphanumeric except hyphens
    slug = slug:gsub("%-+", "-")        -- collapse multiple hyphens
    return string.format("https://www.wowhead.com/decor/%s-%d", slug, record.recordID)
end

-- Shared URL popup for Wowhead link copy (lazy init, reused across frames)
addon.urlPopup = nil

function addon:CreateURLPopup()
    if self.urlPopup then return self.urlPopup end

    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetSize(480, 40)
    popup:SetFrameStrata("DIALOG")
    popup:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    popup:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    popup:SetBackdropBorderColor(0.6, 0.6, 0.6)
    popup:Hide()
    popup:EnableMouse(true)

    -- Close button (top-right)
    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 2, 2)
    closeBtn:SetSize(20, 20)
    closeBtn:SetScript("OnClick", function() popup:Hide() end)

    -- URL edit box
    local editBox = CreateFrame("EditBox", nil, popup)
    editBox:SetPoint("TOPLEFT", 10, -10)
    editBox:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    editBox:SetHeight(20)
    editBox:SetFontObject(self:GetFontObject("GameFontHighlight"))
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function() popup:Hide() end)
    popup.editBox = editBox

    popup:SetScript("OnShow", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    self.urlPopup = popup
    return popup
end

-- Show URL popup anchored to a button
function addon:ShowURLPopup(url, anchorButton)
    local popup = self:CreateURLPopup()
    popup.editBox:SetText(url)
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", anchorButton, "BOTTOMLEFT", 0, -5)
    popup:Show()
end

-- Addon Initialization
addon:RegisterWoWEvent("ADDON_LOADED", function(loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end

    -- Initialize SavedVariables (done by SavedVars.lua if loaded, fallback here)
    if addon.InitializeDB then
        addon:InitializeDB()
    else
        -- Fallback initialization
        if not HousingCodexDB then
            HousingCodexDB = {}
        end
        addon.db = HousingCodexDB
    end

    addon:Debug("Addon loaded")
end)

addon:RegisterWoWEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(0.5, function()
        if addon.LoadData then
            addon:LoadData()
        end
    end)
end)

-- Category cache invalidation (fires internal events for Categories.lua and Data.lua)
addon:RegisterWoWEvent("HOUSING_CATALOG_CATEGORY_UPDATED", function(categoryID)
    addon:FireEvent("CATEGORY_CACHE_INVALIDATED", categoryID)
end)

addon:RegisterWoWEvent("HOUSING_CATALOG_SUBCATEGORY_UPDATED", function(subcategoryID)
    addon:FireEvent("SUBCATEGORY_CACHE_INVALIDATED", subcategoryID)
end)
