--[[
    Housing Codex - Data.lua
    Record builder from WoW Housing APIs
    Uses: C_HousingCatalog, HousingCatalogSearcher, C_ContentTracking
]]

local ADDON_NAME, addon = ...

-- Get localization key for size enum value (returns nil for None/unknown)
local function GetSizeKey(size)
    return addon.CONSTANTS.HOUSING_SIZE_KEYS[size]
end

-- Fallback icon for items without valid 2D icon (model-only items)
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Use constant from Init.lua
local TRACKING_TYPE_DECOR = addon.CONSTANTS.TRACKING_TYPE_DECOR

-- Retry configuration for data loading
local MAX_RETRIES = 5
local RETRY_DELAYS = { 0.5, 1, 2, 4, 8 }  -- Exponential backoff in seconds

addon.catalogSearcher = nil
addon.loadRetryCount = 0
addon.loadingInProgress = false
addon.loadStartTime = 0
addon.filterTagGroups = nil
addon.categoryCache = {}
addon.subcategoryCache = {}

local function IsValidFileID(id)
    -- File IDs must be positive numbers; 0 and negative are invalid
    return type(id) == "number" and id > 0
end

local function IsValidTexturePath(path)
    -- Texture paths should be non-empty strings
    return type(path) == "string" and path ~= ""
end

local function IsValidAtlas(atlas)
    -- Atlas names should be non-empty strings
    return type(atlas) == "string" and atlas ~= ""
end

-- Calculate total owned from all sources (placed + storage + redeemable)
local function CalculateTotalOwned(info)
    return (info.numPlaced or 0) + (info.quantity or 0) + (info.remainingRedeemable or 0)
end

local function GetEntryIcon(entryID, info)
    -- Priority 1: iconTexture (FileAsset - number fileID or string path)
    -- Must validate because invalid values render as bright green tiles
    local iconTex = info.iconTexture
    if iconTex then
        if IsValidFileID(iconTex) or IsValidTexturePath(iconTex) then
            return iconTex, "texture"
        end
    end

    -- Priority 2: iconAtlas
    local iconAtlas = info.iconAtlas
    if iconAtlas and IsValidAtlas(iconAtlas) then
        return iconAtlas, "atlas"
    end

    -- Final fallback - item has no icon data (model-only items)
    -- Mark as model-only so Grid can render 3D preview instead
    return FALLBACK_ICON, "texture", true  -- third return = isModelOnly
end

local function BuildRecord(entryID, info)
    if not info then return nil end

    local recordID = entryID.recordID
    local icon, iconType, isModelOnly = GetEntryIcon(entryID, info)
    local totalOwned = CalculateTotalOwned(info)

    -- Build record
    local record = {
        -- Identity
        entryID = entryID,
        recordID = recordID,
        name = info.name or "",
        entryType = entryID.entryType,  -- 1 = Decor, 2 = Room

        -- Display
        icon = icon,
        iconType = iconType,
        hasModelAsset = info.asset ~= nil,
        isModelOnly = isModelOnly or false,  -- true if no 2D icon available
        quality = info.quality,

        -- Collection state (total = placed + storage + redeemable)
        quantity = info.quantity or 0,
        numPlaced = info.numPlaced or 0,
        remainingRedeemable = info.remainingRedeemable or 0,
        totalOwned = totalOwned,
        isCollected = totalOwned > 0,

        -- Categories
        categoryIDs = info.categoryIDs or {},
        subcategoryIDs = info.subcategoryIDs or {},
        dataTags = info.dataTagsByID or {},

        -- Attributes
        size = info.size or 0,
        sizeKey = GetSizeKey(info.size),  -- Localization key (nil for None/unknown)
        isIndoors = info.isAllowedIndoors or false,
        isOutdoors = info.isAllowedOutdoors or false,
        canCustomize = info.canCustomize or false,
        isPrefab = info.isPrefab or false,

        -- Preview
        modelAsset = info.asset,
        modelSceneID = info.uiModelSceneID,

        -- Source/Acquisition
        sourceText = info.sourceText or "",
        marketInfo = info.marketInfo,
        placementCost = info.placementCost or 0,

        -- Tracking (populated later)
        isTrackable = false,
        isTracking = false,
    }

    return record
end

function addon:ScheduleRetry(reason)
    self.loadingInProgress = false
    self.loadRetryCount = self.loadRetryCount + 1

    if self.loadRetryCount > MAX_RETRIES then
        self:Debug("Max retries reached, giving up")
        self:FireEvent("DATA_LOAD_FAILED")
        self:Print(self.L["ERROR_LOAD_FAILED"])
        return
    end

    local delay = RETRY_DELAYS[self.loadRetryCount] or 8
    self:Debug(string.format("Retry %d/%d in %.1fs: %s", self.loadRetryCount, MAX_RETRIES, delay, reason or "unknown"))

    C_Timer.After(delay, function()
        self:LoadData()
    end)
end

function addon:LoadData()
    if self.dataLoaded then
        self:Debug("Data already loaded, skipping")
        return
    end

    if self.loadingInProgress then
        self:Debug("Load already in progress, skipping")
        return
    end

    self.loadStartTime = debugprofilestop()

    -- Check API availability
    if not C_HousingCatalog or not C_HousingCatalog.CreateCatalogSearcher then
        self:ScheduleRetry("C_HousingCatalog API not available")
        return
    end

    -- Check if housing service is enabled (API may not exist in all versions)
    local serviceCheck = C_Housing and C_Housing.IsHousingServiceEnabled
    if serviceCheck and not serviceCheck() then
        self:ScheduleRetry("Housing service not enabled")
        return
    end

    -- Create searcher
    local searcher = C_HousingCatalog.CreateCatalogSearcher()
    if not searcher then
        self:ScheduleRetry("Failed to create catalog searcher")
        return
    end

    self.catalogSearcher = searcher
    self.loadingInProgress = true

    -- Configure searcher to include all items (collected and uncollected)
    -- Per Blizzard's HousingCatalogFrameMixin pattern
    searcher:SetOwnedOnly(false)
    searcher:SetCollected(true)
    searcher:SetUncollected(true)
    searcher:SetAutoUpdateOnParamChanges(false)

    -- Filter to BasicDecor mode (excludes rooms/layout items)
    searcher:SetEditorModeContext(Enum.HouseEditorMode.BasicDecor)

    -- Set up callback for when search results are ready (Blizzard pattern)
    searcher:SetResultsUpdatedCallback(function()
        if self.searchTimeoutTimer then
            self.searchTimeoutTimer:Cancel()
            self.searchTimeoutTimer = nil
        end
        self:ProcessSearchResults()
    end)

    -- CRITICAL: Run the search to populate results (required before GetAllSearchItems)
    self:Debug("Running catalog search...")
    searcher:RunSearch()

    -- Timeout: if callback doesn't fire within 5 seconds, retry
    self.searchTimeoutTimer = C_Timer.NewTimer(5, function()
        self.searchTimeoutTimer = nil
        if self.loadingInProgress and not self.dataLoaded then
            self:Debug("Search callback timeout")
            -- Try to get results synchronously as fallback
            local results = searcher:GetCatalogSearchResults()
            if results and #results > 0 then
                self:Debug("Timeout fallback: found " .. #results .. " results")
                self:ProcessSearchResults()
            else
                self:ScheduleRetry("Search callback never fired")
            end
        end
    end)
end

function addon:ProcessSearchResults()
    self.loadingInProgress = false

    if not self.catalogSearcher then
        if not self.dataLoaded then
            self:ScheduleRetry("Searcher was released before results")
        end
        return
    end

    -- Get search results (NOT GetAllSearchItems which returns source collection)
    local allEntries = self.catalogSearcher:GetCatalogSearchResults()

    -- If data already loaded, this is a filter/search update
    if self.dataLoaded then
        self:OnSearchResultsUpdated(allEntries)
        return
    end

    -- Initial load: build all records
    if not allEntries or #allEntries == 0 then
        self:ScheduleRetry("No entries returned after search")
        return
    end

    self:Debug("Processing " .. #allEntries .. " catalog entries")

    -- Build records, aggregating ownership across entries with same recordID
    -- (Same item can have multiple entryIDs from different acquisition sources)
    local records = {}
    local recordCount = 0

    for _, entryID in ipairs(allEntries) do
        local info = C_HousingCatalog.GetCatalogEntryInfo(entryID)
        if info and not info.isPrefab then
            local recordID = entryID.recordID
            local existing = records[recordID]

            if existing then
                -- Aggregate ownership from additional entry
                existing.quantity = existing.quantity + (info.quantity or 0)
                existing.numPlaced = existing.numPlaced + (info.numPlaced or 0)
                existing.remainingRedeemable = existing.remainingRedeemable + (info.remainingRedeemable or 0)
                existing.totalOwned = CalculateTotalOwned(existing)
                existing.isCollected = existing.totalOwned > 0
            else
                -- First entry for this recordID
                local record = BuildRecord(entryID, info)
                if record then
                    records[recordID] = record
                    recordCount = recordCount + 1
                end
            end
        end
    end

    self.decorRecords = records

    -- Load filter tag groups
    self:LoadFilterTagGroups()

    -- Update tracking status for all records
    self:UpdateAllTrackingStatus()

    -- Mark as loaded
    self.dataLoaded = true

    local elapsedMs = math.floor(debugprofilestop() - (self.loadStartTime or 0))
    self:Debug(string.format("Loaded %d records in %d ms", recordCount, elapsedMs))

    -- Fire loaded event
    self:FireEvent("DATA_LOADED", recordCount)

    if self.L["LOADED_MESSAGE_TIME"] then
        self:Print(string.format(self.L["LOADED_MESSAGE_TIME"], recordCount, elapsedMs))
    end
end

function addon:OnSearchResultsUpdated(entries)
    local recordIDs = {}
    for _, entryID in ipairs(entries or {}) do
        -- Only include records we have (excludes prefabs filtered during initial load)
        if self.decorRecords[entryID.recordID] then
            table.insert(recordIDs, entryID.recordID)
        end
    end

    self:Debug("Search results updated: " .. #recordIDs .. " items")
    self:FireEvent("SEARCH_RESULTS_UPDATED", recordIDs)
end

function addon:LoadFilterTagGroups()
    if not C_HousingCatalog.GetAllFilterTagGroups then return end

    self.filterTagGroups = C_HousingCatalog.GetAllFilterTagGroups()
    if self.filterTagGroups then
        self:Debug("Loaded " .. #self.filterTagGroups .. " filter tag groups")
    end
end

function addon:GetFilterTagGroups()
    return self.filterTagGroups or {}
end

function addon:GetCategoryInfo(categoryID)
    local cached = self.categoryCache[categoryID]
    if cached then return cached end

    local getter = C_HousingCatalog.GetCatalogCategoryInfo
    if not getter then return nil end

    local info = getter(categoryID)
    if info then
        self.categoryCache[categoryID] = info
    end
    return info
end

function addon:GetSubcategoryInfo(subcategoryID)
    local cached = self.subcategoryCache[subcategoryID]
    if cached then return cached end

    local getter = C_HousingCatalog.GetCatalogSubcategoryInfo
    if not getter then return nil end

    local info = getter(subcategoryID)
    if info then
        self.subcategoryCache[subcategoryID] = info
    end
    return info
end

function addon:GetRecord(recordID)
    return self.decorRecords[recordID]
end

function addon:GetRecordCount()
    local count = 0
    for _ in pairs(self.decorRecords) do
        count = count + 1
    end
    return count
end

function addon:GetAllRecordIDs()
    local ids = {}
    for recordID in pairs(self.decorRecords) do
        table.insert(ids, recordID)
    end
    return ids
end

function addon:UpdateAllTrackingStatus()
    if not C_ContentTracking then return end

    local IsTrackable = C_ContentTracking.IsTrackable
    local IsTracking = C_ContentTracking.IsTracking
    if not IsTrackable and not IsTracking then return end

    local trackableCount = 0
    local trackingCount = 0

    for recordID, record in pairs(self.decorRecords) do
        if IsTrackable then
            record.isTrackable = IsTrackable(TRACKING_TYPE_DECOR, recordID)
            if record.isTrackable then
                trackableCount = trackableCount + 1
            end
        end

        if IsTracking then
            record.isTracking = IsTracking(TRACKING_TYPE_DECOR, recordID)
            if record.isTracking then
                trackingCount = trackingCount + 1
            end
        end
    end

    self:Debug(string.format("Tracking status: %d trackable, %d tracking", trackableCount, trackingCount))
end

function addon:UpdateRecordTrackingStatus(recordID, isTrackedHint)
    local record = self.decorRecords[recordID]
    if not record or not C_ContentTracking then return end

    local wasTracking = record.isTracking

    if C_ContentTracking.IsTrackable then
        record.isTrackable = C_ContentTracking.IsTrackable(TRACKING_TYPE_DECOR, recordID)
    end

    -- Use hint if provided (from CONTENT_TRACKING_UPDATE), otherwise query API
    if isTrackedHint ~= nil then
        record.isTracking = isTrackedHint
    elseif C_ContentTracking.IsTracking then
        record.isTracking = C_ContentTracking.IsTracking(TRACKING_TYPE_DECOR, recordID)
    end

    if wasTracking ~= record.isTracking then
        self:FireEvent("TRACKING_CHANGED", recordID, record.isTracking)
    end
end

function addon:StartTracking(recordID)
    if not C_ContentTracking or not C_ContentTracking.StartTracking then
        return false, "API unavailable"
    end

    local record = self.decorRecords[recordID]
    if not record then
        return false, "Record not found"
    end

    if not record.isTrackable then
        return false, self.L["TRACKING_ERROR_UNTRACKABLE"]
    end

    local err = C_ContentTracking.StartTracking(TRACKING_TYPE_DECOR, recordID)

    -- Handle result using Enum values (matches PreviewFrame.lua pattern)
    if not err or err == Enum.ContentTrackingError.AlreadyTracked then
        -- Success or already tracked (treat as success)
        self:UpdateRecordTrackingStatus(recordID)
        return true
    elseif err == Enum.ContentTrackingError.MaxTracked then
        return false, self.L["TRACKING_ERROR_MAX"]
    elseif err == Enum.ContentTrackingError.Untrackable then
        return false, self.L["TRACKING_ERROR_UNTRACKABLE"]
    end

    return false, "Tracking failed"
end

function addon:StopTracking(recordID)
    if not C_ContentTracking or not C_ContentTracking.StopTracking then
        return false, "API unavailable"
    end

    C_ContentTracking.StopTracking(TRACKING_TYPE_DECOR, recordID, Enum.ContentTrackingStopType.Manual)
    self:UpdateRecordTrackingStatus(recordID)
    return true
end

function addon:ToggleTracking(recordID)
    local record = self.decorRecords[recordID]
    if not record then return false end

    if record.isTracking then
        return self:StopTracking(recordID)
    else
        return self:StartTracking(recordID)
    end
end

-- Event Handlers
addon:RegisterWoWEvent("CONTENT_TRACKING_UPDATE", function(trackingType, id, isTracked)
    if trackingType == TRACKING_TYPE_DECOR then
        addon:UpdateRecordTrackingStatus(id, isTracked)
    end
end)

-- Single-entry storage update (efficient for individual changes)
addon:RegisterWoWEvent("HOUSING_STORAGE_ENTRY_UPDATED", function(entryID)
    if not addon.dataLoaded or not entryID then return end

    local record = addon.decorRecords[entryID.recordID]
    if not record then return end

    local info = C_HousingCatalog.GetCatalogEntryInfo(entryID)
    if not info then return end

    record.quantity = info.quantity or 0
    record.numPlaced = info.numPlaced or 0
    record.remainingRedeemable = info.remainingRedeemable or 0
    record.totalOwned = CalculateTotalOwned(info)
    record.isCollected = record.totalOwned > 0
    addon:FireEvent("RECORD_UPDATED", entryID.recordID)
    addon:Debug("Storage entry updated: " .. (record.name or entryID.recordID))
end)

-- Bulk storage update (just re-run searcher to refresh grid)
addon:RegisterWoWEvent("HOUSING_STORAGE_UPDATED", function()
    if not addon.dataLoaded then return end

    addon:Debug("Storage updated, re-running search")
    if addon.catalogSearcher then
        addon.catalogSearcher:RunSearch()
    end
end)

-- Cache invalidation for categories (fired by Init.lua from WoW events)
addon:RegisterInternalEvent("CATEGORY_CACHE_INVALIDATED", function(categoryID)
    if addon.categoryCache and categoryID then
        addon.categoryCache[categoryID] = nil
        addon:Debug("Category cache invalidated: " .. tostring(categoryID))
    end
end)

addon:RegisterInternalEvent("SUBCATEGORY_CACHE_INVALIDATED", function(subcategoryID)
    if addon.subcategoryCache and subcategoryID then
        addon.subcategoryCache[subcategoryID] = nil
        addon:Debug("Subcategory cache invalidated: " .. tostring(subcategoryID))
    end
end)

