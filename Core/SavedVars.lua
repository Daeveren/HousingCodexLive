--[[
    Housing Codex - SavedVars.lua
    Account-wide data persistence and frame position/size helpers
]]

local ADDON_NAME, addon = ...

local CURRENT_DB_VERSION = 3

local defaults = {
    version = CURRENT_DB_VERSION,
    framePosition = { point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0 },
    frameSize = { width = 1200, height = 800 },
    preview = {
        width = 500,     -- Docked panel width (middle preset)
    },
    options = {
        position = { point = "CENTER", relativePoint = "CENTER", xOfs = 0, yOfs = 0 },
    },
    browser = {
        lastTab = "DECOR",
        tileSize = 180,
        sortType = 0,  -- Enum.HousingCatalogSortType.DateAdded
        filters = {
            showCollected = false,
            showUncollected = true,
            trackableState = "all",
            showWishlistOnly = false,
            showPlacedOnly = false,
            indoors = true,
            outdoors = true,
            dyeable = false,
            tagFilters = {},  -- { [groupID] = { [tagID] = bool } }
        },
        category = {
            focusedCategoryID = nil,
            focusedSubcategoryID = nil,
        },
        quests = {
            selectedQuestID = nil,
            selectedExpansionKey = nil,
            completionFilter = "incomplete",  -- "all" | "incomplete" | "complete"
            searchText = "",
            expandedZones = {},       -- { ["EXPANSION_TWW:Isle of Dorn"] = true, ... }
        },
        achievements = {
            selectedCategory = nil,
            selectedAchievementID = nil,
            selectedRecordID = nil,
            completionFilter = "incomplete",  -- "all" | "incomplete" | "complete"
            searchText = "",
        },
    },
    wishlist = {},
    settings = {
        showCollectedIndicator = true,
        useCustomFont = true,
        -- toggleKeybind removed: now uses standard WoW keybinding system via Bindings.xml
        debugMode = false,
        ldbShowText = true,  -- Show text in LDB display (false = icon-only)
        showMinimapButton = true,  -- Show LibDBIcon minimap button
        showVendorDecorIndicators = true,  -- Show decor icons on vendor items
        showVendorOwnedCheckmark = true,   -- Show checkmark on owned decor at vendors
    },
    wishlistUI = {
        tileSize = 152,      -- Separate from browser.tileSize
        position = nil,      -- Frame position
        size = { width = 1200, height = 940 },  -- Default size (clamped to screen at runtime)
    },
}

local function MigrateDB(db)
    -- v1 -> v2: Preview changed from detached window to docked panel
    if db.version < 2 then
        -- Remove old position and height data (no longer needed)
        if db.preview then
            db.preview.position = nil
            db.preview.height = nil
            -- Update width default from 700 to 400 (docked panel is narrower)
            db.preview.width = 400
        end
        db.version = 2
    end

    -- v2 -> v3: Preview width presets changed from {400,500,600,700} to {300,500,700}
    -- Map discontinued presets to middle preset (500), preserve 700 and custom values
    if db.version < 3 then
        local width = db.preview and db.preview.width
        if width == 400 or width == 600 then
            db.preview.width = 500
        end
        db.version = 3
    end

    return db
end

function addon:InitializeDB()
    if not HousingCodexDB then
        HousingCodexDB = CopyTable(defaults)
    else
        -- Fill missing fields from defaults (deep merge)
        self:MergeDefaults(HousingCodexDB, defaults)

        -- Run migrations if needed
        if HousingCodexDB.version < CURRENT_DB_VERSION then
            HousingCodexDB = MigrateDB(HousingCodexDB)
        end
    end

    self.db = HousingCodexDB
    self:Debug("Database initialized (version " .. self.db.version .. ")")
end

-- Frame Position/Size Helpers
function addon:SaveFramePosition(frame, dbKey)
    if not frame or not dbKey then return end

    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
    if not point then return end

    self.db[dbKey] = self.db[dbKey] or {}
    self.db[dbKey].position = {
        point = point,
        relativePoint = relativePoint or "CENTER",
        xOfs = xOfs or 0,
        yOfs = yOfs or 0,
    }
end

function addon:RestoreFramePosition(frame, dbKey)
    if not frame or not dbKey then return false end

    local data = self.db[dbKey]
    if not data or not data.position then return false end

    local pos = data.position
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    return true
end

function addon:SaveFrameSize(frame, dbKey)
    if not frame or not dbKey then return end

    local width, height = frame:GetSize()
    if not width or not height then return end

    self.db[dbKey] = self.db[dbKey] or {}
    self.db[dbKey].size = { width = width, height = height }
end

function addon:RestoreFrameSize(frame, dbKey, minWidth, minHeight, maxWidth, maxHeight)
    if not frame or not dbKey then return false end

    local data = self.db[dbKey]
    if not data or not data.size then return false end

    local width = data.size.width
    local height = data.size.height

    if minWidth then width = math.max(width, minWidth) end
    if minHeight then height = math.max(height, minHeight) end
    if maxWidth then width = math.min(width, maxWidth) end
    if maxHeight then height = math.min(height, maxHeight) end

    frame:SetSize(width, height)
    return true
end

function addon:SaveFrameLayout(frame, dbKey)
    self:SaveFramePosition(frame, dbKey)
    self:SaveFrameSize(frame, dbKey)
end

function addon:RestoreFrameLayout(frame, dbKey, minWidth, minHeight, maxWidth, maxHeight)
    local posRestored = self:RestoreFramePosition(frame, dbKey)
    local sizeRestored = self:RestoreFrameSize(frame, dbKey, minWidth, minHeight, maxWidth, maxHeight)
    return posRestored or sizeRestored
end

-- Wishlist Helpers
function addon:IsWishlisted(recordID)
    return self.db.wishlist[recordID] == true
end

function addon:SetWishlisted(recordID, wishlisted)
    local wasWishlisted = self:IsWishlisted(recordID)

    if wishlisted then
        self.db.wishlist[recordID] = true
    else
        self.db.wishlist[recordID] = nil
    end

    if wasWishlisted ~= wishlisted then
        self:FireEvent("WISHLIST_CHANGED", recordID, wishlisted)
    end
end

function addon:ToggleWishlist(recordID)
    local isWishlisted = not self:IsWishlisted(recordID)
    self:SetWishlisted(recordID, isWishlisted)
    return isWishlisted
end

function addon:GetWishlistCount()
    local count = 0
    for _ in pairs(self.db.wishlist) do
        count = count + 1
    end
    return count
end
