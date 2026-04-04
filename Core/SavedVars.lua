--[[
    Housing Codex - SavedVars.lua
    Account-wide data persistence and frame position/size helpers
]]

local _, addon = ...

local CURRENT_DB_VERSION = 7

local defaults = {
    version = CURRENT_DB_VERSION,
    framePosition = { point = "TOPLEFT", relativePoint = "TOPLEFT", xOfs = 100, yOfs = -100 },
    frameSize = { width = 1200, height = 800 },
    preview = {
        width = 500,     -- Docked panel width (middle preset)
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
            firstAcquisition = false,
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
            expandedZones = {},       -- { ["EXPANSION_TWW:Isle of Dorn"] = true, ... }
        },
        achievements = {
            selectedCategory = nil,
            selectedAchievementID = nil,
            selectedRecordID = nil,
            completionFilter = "incomplete",  -- "all" | "incomplete" | "complete"
        },
        renown = {
            selectedExpansion = nil,
            completionFilter = "incomplete",  -- "all" | "incomplete" | "complete"
        },
    },
    whatsNew = {
        lastSeenVersion = nil,
        dismissCount = 0,
        dontShowForVersion = nil,
        hasSeenWelcome = false,
    },
    wishlist = {},
    settings = {
        showCollectedIndicator = true,
        useCustomFont = true,
        -- toggleKeybind removed: now uses standard WoW keybinding system via Bindings.xml
        debugMode = false,
        ldbShowUnique = true,       -- Show unique decor collected count in broker
        ldbShowRooms = false,       -- Show rooms unlocked count in broker
        ldbShowTotalOwned = false,  -- Show total decor owned (with duplicates) in broker
        ldbShowTotal = true,        -- Show total catalog item count in broker
        showMinimapButton = true,  -- Show LibDBIcon minimap button
        showVendorDecorIndicators = true,  -- Show decor icons on vendor items
        showVendorOwnedCheckmark = true,   -- Show checkmark on owned decor at vendors
        showContainerDecorIndicators = true,  -- Show decor icons in bags/bank
        showContainerOwnedCheckmark = true,   -- Show checkmark on owned decor in bags/bank
        showVendorMapPins = true,  -- Show vendor pins on world map
        treasureHuntWaypoints = true,  -- Auto-set waypoints for Decor Treasure Hunts
        showZoneOverlay = true,       -- Show zone overlay on world map
        zoneOverlayMinimized = false, -- Minimized state
        zoneOverlayPosition = "topLeft",  -- "topLeft" or "bottomRight"
        zoneOverlayAlpha = 0.9,       -- Panel transparency (0.6 - 1.0)
        includeCollectedVendorDecor = false,  -- Include already-collected vendor decor in zone overlay
        zoneOverlayPreviewScale = 1.0,        -- Preview size scale (0.5, 1.0, 1.5)
        vendorPinAlpha = 1.0,                -- Vendor pin transparency (0.4 - 1.0)
        vendorPinScale = 1.0,                -- Vendor pin scale multiplier (0.6 - 1.4)
        -- vendorPinLayer removed: custom frame levels tainted WorldMapFrame (WoWUIBugs #811)
        autoRotatePreview = true,             -- Auto-rotate 3D preview models
        useTomTom = false,                   -- Use TomTom waypoints instead of native
        showVendorTooltips = true,           -- Show decor progress in vendor NPC tooltips
    },
    wishlistUI = {
        tileSize = 152,      -- Separate from browser.tileSize
        position = nil,      -- Frame position
        size = { width = 1200, height = 940 },  -- Default size (clamped to screen at runtime)
    },
    endeavors = {
        enabled = true,
        showHouseXP = true,
        showEndeavorProgress = true,
        showXPText = false,
        showEndeavorText = false,
        showXPPct = false,
        showEndeavorPct = false,
        scale = "normal",
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

    -- v3 -> v4: Convert CENTER anchor to TOPLEFT for stable resize behavior
    if db.version < 4 then
        local pos = db.framePosition

        -- Set default point if missing
        if pos and not pos.point then
            pos.point = "CENTER"
        end

        if pos and pos.point == "CENTER" then
            local size = db.frameSize or { width = 1200, height = 800 }
            local screenW = GetScreenWidth()
            local screenH = GetScreenHeight()

            -- CENTER offsets are relative to screen center
            local centerX = (screenW / 2) + (pos.xOfs or 0)
            local centerY = (screenH / 2) + (pos.yOfs or 0)

            -- Calculate TOPLEFT corner in screen coords (Y from bottom, top is ABOVE center)
            local topLeftX = centerX - (size.width / 2)
            local topLeftY = centerY + (size.height / 2)

            db.framePosition = {
                point = "TOPLEFT",
                relativePoint = "TOPLEFT",
                xOfs = topLeftX,
                yOfs = topLeftY - screenH,
            }
        end
        db.version = 4
    end

    -- v4 -> v5: Replace ldbShowText with granular broker segment toggles
    if db.version < 5 then
        if db.settings then
            if db.settings.ldbShowText == false then
                db.settings.ldbShowUnique = false
                db.settings.ldbShowTotalOwned = false
                db.settings.ldbShowTotal = false
            end
            db.settings.ldbShowText = nil
        end
        db.version = 5
    end

    -- v5 -> v6: Add endeavors scale setting, default to "normal"
    if db.version < 6 then
        if db.endeavors then
            db.endeavors.scale = "normal"
        end
        db.version = 6
    end

    -- v6 -> v7: Renown tab (browser.renown defaults handled by MergeDefaults)
    if db.version < 7 then
        db.characters = nil  -- Clean up if present from testing
        db.version = 7
    end

    return db
end

-- Remove dead keys from retired features (blocklist — never whitelist,
-- because browser.vendors/drops/pvp/professions and minimap are created
-- dynamically by Ensure*DB() functions and are NOT in the defaults table)
local function SanitizeDB(db)
    db.options = nil
    db.characters = nil
    db.extractedVendorInfo = nil
    db.extractedNPCLocations = nil

    if db.settings then
        db.settings.toggleKeybind = nil
        db.settings.previewAutoOpen = nil
        db.settings.showFullyCollectedVendorsOnMap = nil
        db.settings.showMidnightDrops = nil
    end

    if db.preview then
        db.preview.isOpen = nil
    end

    if db.minimap then
        db.minimap.showInCompartment = nil
    end

    local browser = db.browser
    if browser then
        if browser.quests then browser.quests.expandedExpansions = nil end
        if browser.filters then
            browser.filters.collectionState = nil
            browser.filters.searchText = nil
        end
        if browser.achievements then browser.achievements.searchText = nil end
    end
end

function addon:InitializeDB()
    if not HousingCodexDB then
        HousingCodexDB = CopyTable(defaults)
    else
        -- Coerce version first (nil/non-numeric → 0 so migrations fire correctly)
        if type(HousingCodexDB.version) ~= "number" then
            HousingCodexDB.version = 0
        end

        -- Run migrations before merging defaults (merge would backfill current version)
        if HousingCodexDB.version < CURRENT_DB_VERSION then
            HousingCodexDB = MigrateDB(HousingCodexDB)
        end

        -- Fill missing fields from defaults (deep merge)
        self:MergeDefaults(HousingCodexDB, defaults)
    end

    -- Clean up dead keys from retired features
    SanitizeDB(HousingCodexDB)

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

