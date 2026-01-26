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

-- Version info
addon.version = "0.5.1"
addon.addonName = ADDON_NAME

-- Localization table (populated by Locales/*.lua)
addon.L = {}

-- Module registry (for cross-file communication)
addon.modules = {}

-- Data state
addon.dataLoaded = false
addon.decorRecords = {}
addon.recordIDToKey = {}

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
    MIN_FRAME_WIDTH = 800,
    MIN_FRAME_HEIGHT = 600,

    -- Layout
    SIDEBAR_WIDTH = 182,
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

    -- Wishlist star badge
    WISHLIST_STAR_SIZE_GRID = 20,     -- Star size on grid tiles
    WISHLIST_STAR_SIZE_PREVIEW = 24,  -- Star button size in preview details

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
    },

    -- Font path
    FONT_PATH = "Interface\\AddOns\\HousingCodex\\Fonts\\Roboto_Condensed_semibold.ttf",

    -- Content tracking
    TRACKING_TYPE_DECOR = 3,  -- Enum.ContentTrackingType.Decor
    MAX_TRACKED = 15,  -- Constants.ContentTrackingConsts.MaxTrackedCollectableSources

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

    -- Category navigation
    BUILTIN_ALL_CATEGORY_ID = 18,  -- WoW's built-in "All" category (filter out)

    -- Shared button styling (toolbar toggle, preview collapse)
    TOGGLE_BUTTON_SIZE = 34,
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

-- Creates a styled toggle button (used for preview toggle and collapse buttons)
-- Returns button with .text FontString for updating the symbol
function addon:CreateToggleButton(parent, symbol, tooltipKey, onClick)
    local COLORS = self.CONSTANTS.COLORS
    local SIZE = self.CONSTANTS.TOGGLE_BUTTON_SIZE

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(SIZE, SIZE)
    btn:SetBackdrop(self.CONSTANTS.TOGGLE_BUTTON_BACKDROP)
    btn:SetBackdropColor(0.15, 0.15, 0.18, 0.9)
    btn:SetBackdropBorderColor(unpack(COLORS.BORDER))

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local xOffset = (symbol == "<") and -1 or 1
    btnText:SetPoint("CENTER", xOffset, 0)
    btnText:SetText(symbol)
    btnText:SetTextColor(unpack(COLORS.GOLD))
    local font = btnText:GetFont()
    btnText:SetFont(font, 20, "OUTLINE")
    btn.text = btnText

    btn:SetScript("OnEnter", function(b)
        b:SetBackdropColor(0.2, 0.2, 0.24, 1)
        b:SetBackdropBorderColor(0.6, 0.5, 0.1, 1)
        if tooltipKey then
            GameTooltip:SetOwner(b, "ANCHOR_TOP")
            GameTooltip:SetText(self.L[tooltipKey] or tooltipKey)
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function(b)
        b:SetBackdropColor(0.15, 0.15, 0.18, 0.9)
        b:SetBackdropBorderColor(unpack(COLORS.BORDER))
        GameTooltip:Hide()
    end)

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    return btn
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
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
        addon:Print("  " .. L["HELP_PREVIEW"])
        addon:Print("  " .. L["HELP_SETTINGS"])
        addon:Print("  " .. L["HELP_RETRY"])
        addon:Print("  " .. L["HELP_HELP"])
        addon:Print("  " .. L["HELP_DEBUG"])
    elseif cmd == "preview" then
        if addon.Preview then
            addon.Preview:Toggle()
        else
            addon:Print("Preview window not yet available")
        end
    elseif cmd == "settings" or cmd == "options" then
        if addon.Settings then
            addon.Settings:Open()
        else
            addon:Print("Settings not yet available")
        end
    elseif cmd == "retry" or cmd == "reload" then
        addon:Print("Retrying data load...")
        addon.loadRetryCount = 0
        addon.dataLoaded = false
        addon:LoadData()
    elseif cmd == "debug" then
        if addon.db then
            addon.db.settings.debugMode = not addon.db.settings.debugMode
            addon:Print("Debug mode: " .. (addon.db.settings.debugMode and "ON" or "OFF"))
        end
    elseif cmd:find("^inspect ") then
        -- Debug: inspect a record by partial name match
        local searchName = cmd:sub(9):lower()
        if not addon.dataLoaded then
            addon:Print("Data not loaded yet")
            return
        end
        for recordID, record in pairs(addon.decorRecords) do
            if record.name:lower():find(searchName) then
                addon:Print("Found: " .. record.name .. " (ID: " .. recordID .. ")")
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
        addon:Print("No item found matching: " .. searchName)
    elseif addon.MainFrame then
        addon.MainFrame:Toggle()
    else
        addon:Print("v" .. addon.version .. " - Main window not yet available")
    end
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
