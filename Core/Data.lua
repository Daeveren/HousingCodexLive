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
addon.categoryCache = {}
addon.subcategoryCache = {}
addon.needsRecordRefresh = false
addon.fallbackRecords = {}  -- Cache for items resolved via direct API (HiddenInCatalog)

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

-- Update a record's ownership fields from API info
local function RefreshRecordOwnership(record, info)
    record.quantity = info.quantity or 0
    record.numPlaced = info.numPlaced or 0
    record.remainingRedeemable = info.remainingRedeemable or 0
    record.totalOwned = CalculateTotalOwned(record)
    record.isCollected = record.totalOwned > 0
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

        -- Display
        icon = icon,
        iconType = iconType,
        isModelOnly = isModelOnly or false,  -- true if no 2D icon available

        -- Collection state (total = placed + storage + redeemable)
        quantity = info.quantity or 0,
        numPlaced = info.numPlaced or 0,
        remainingRedeemable = info.remainingRedeemable or 0,
        totalOwned = totalOwned,
        isCollected = totalOwned > 0,

        -- Categories (used by PreviewFrame for breadcrumb display)
        categoryIDs = info.categoryIDs or {},
        subcategoryIDs = info.subcategoryIDs or {},

        -- Attributes
        size = info.size or 0,
        sizeKey = GetSizeKey(info.size),  -- Localization key (nil for None/unknown)
        isIndoors = info.isAllowedIndoors or false,
        isOutdoors = info.isAllowedOutdoors or false,
        canCustomize = info.canCustomize or false,

        -- Preview
        modelAsset = info.asset,
        modelSceneID = info.uiModelSceneID,

        -- Source/Acquisition
        itemID = info.itemID,  -- For merchant overlay reverse index
        sourceText = info.sourceText or "",

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

    -- Build records, deduplicating by recordID
    -- (Same item can have multiple entryIDs from different stacks;
    -- ownership fields are per-recordID totals, not per-entry)
    local records = {}
    local recordCount = 0

    for _, entryID in ipairs(allEntries) do
        -- Check duplicate first to avoid unnecessary API call
        if not records[entryID.recordID] then
            local info = C_HousingCatalog.GetCatalogEntryInfo(entryID)
            if info and not info.isPrefab then
                local record = BuildRecord(entryID, info)
                if record then
                    records[entryID.recordID] = record
                    recordCount = recordCount + 1
                end
            end
        end
    end

    self.decorRecords = records

    -- Update tracking status for all records
    self:UpdateAllTrackingStatus()

    -- Mark as loaded
    self.dataLoaded = true

    local elapsedMs = math.floor(debugprofilestop() - (self.loadStartTime or 0))
    self:Debug(string.format("Loaded %d records in %d ms", recordCount, elapsedMs))

    -- Fire loaded event
    self:FireEvent("DATA_LOADED", recordCount)

    self:Print(string.format(self.L["LOADED_MESSAGE"], recordCount))
end

function addon:OnSearchResultsUpdated(entries)
    local recordIDs = {}
    local seen = {}
    local refreshing = self.needsRecordRefresh
    self.needsRecordRefresh = false

    -- If refreshing, update ALL records (not just filtered ones)
    -- This ensures ownership counts stay accurate for items outside current filters
    if refreshing then
        for _, record in pairs(self.decorRecords) do
            local info = C_HousingCatalog.GetCatalogEntryInfo(record.entryID)
            if info then
                RefreshRecordOwnership(record, info)
            end
        end
        self:Debug("Refreshed ownership for all records")
    end

    -- Collect unique IDs from search results
    for _, entryID in ipairs(entries or {}) do
        local recordID = entryID.recordID
        local record = self.decorRecords[recordID]
        if record and not seen[recordID] then
            seen[recordID] = true
            table.insert(recordIDs, recordID)
        end
    end

    self:Debug("Search results updated: " .. #recordIDs .. " items")
    self:FireEvent("SEARCH_RESULTS_UPDATED", recordIDs)
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
    return self.decorRecords[recordID] or self.fallbackRecords[recordID]
end

-- Resolve display name for a decorId with fallback chain:
-- 1. Record name (catalog or resolved)  2. C_HousingDecor API  3. Scraped DropDecorNames  4. "Decor #XXXX"
function addon:ResolveDecorName(decorId, record)
    if record and record.name and record.name ~= "" then return record.name end
    if C_HousingDecor and C_HousingDecor.GetDecorName then
        local name = C_HousingDecor.GetDecorName(decorId)
        if name then return name end
    end
    local scraped = self.DropDecorNames and self.DropDecorNames[decorId]
    return scraped or string.format(self.L["DROPS_DECOR_ID"], decorId)
end

-- Resolve a record by trying direct API lookup when not in catalog search results.
-- Used for items with HiddenInCatalog flag (e.g., boss drops not yet in catalog browser).
-- Results are cached in fallbackRecords (false sentinel = tried and failed).
function addon:ResolveRecord(recordID)
    -- Check primary records first
    local record = self.decorRecords[recordID]
    if record then return record end

    -- Check fallback cache
    local cached = self.fallbackRecords[recordID]
    if cached then return cached end
    if cached == false then return nil end  -- Already tried, not found

    -- Try direct API lookup (bypasses catalog search filter)
    if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByRecordID then
        self.fallbackRecords[recordID] = false
        return nil
    end

    local info = C_HousingCatalog.GetCatalogEntryInfoByRecordID(
        Enum.HousingCatalogEntryType.Decor, recordID, true)
    if not info then
        self.fallbackRecords[recordID] = false
        return nil
    end

    -- Reuse shared icon resolution (same priority chain as BuildRecord)
    local icon, iconType, isModelOnly = GetEntryIcon(nil, info)
    local totalOwned = CalculateTotalOwned(info)
    -- For showQuantity=false items, quantity fields are always 0 — entrySubtype is the ownership signal
    -- entrySubtype: 1=Unowned, 2=OwnedModifiedStack, 3=OwnedUnmodifiedStack
    local entrySubtype = info.entryID and info.entryID.entrySubtype or 1
    local entryID = info.entryID or {
        recordID = recordID,
        entryType = Enum.HousingCatalogEntryType.Decor,
        entrySubtype = 1,
        subtypeIdentifier = 0,
    }

    record = {
        entryID = entryID,
        recordID = recordID,
        name = info.name or "",
        icon = icon,
        iconType = iconType,
        isModelOnly = isModelOnly or false,
        quantity = info.quantity or 0,
        numPlaced = info.numPlaced or 0,
        remainingRedeemable = info.remainingRedeemable or 0,
        totalOwned = totalOwned,
        isCollected = totalOwned > 0 or entrySubtype > 1,
        categoryIDs = info.categoryIDs or {},
        subcategoryIDs = info.subcategoryIDs or {},
        size = info.size or 0,
        sizeKey = GetSizeKey(info.size),
        isIndoors = info.isAllowedIndoors or false,
        isOutdoors = info.isAllowedOutdoors or false,
        canCustomize = info.canCustomize or false,
        modelAsset = info.asset,
        modelSceneID = info.uiModelSceneID,
        itemID = info.itemID,
        sourceText = info.sourceText or "",
        isTrackable = false,
        isTracking = false,
    }

    self.fallbackRecords[recordID] = record
    if record.itemID and self.itemIDToRecordID then
        self.itemIDToRecordID[record.itemID] = recordID
    end
    self:Debug("Resolved hidden catalog item: " .. (info.name or recordID))
    return record
end

function addon:GetRecordCount()
    local count = 0
    for _ in pairs(self.decorRecords) do
        count = count + 1
    end
    return count
end

function addon:GetUniqueCollectedCount()
    if not self.indexesBuilt then return 0 end
    local count = 0
    for _ in pairs(self.indexes.collected) do
        count = count + 1
    end
    return count
end

function addon:GetTotalOwnedCount()
    if not self.indexesBuilt then return 0 end
    local total = 0
    for recordID in pairs(self.indexes.collected) do
        local record = self.decorRecords[recordID]
        if record and record.totalOwned then
            total = total + record.totalOwned
        end
    end
    return total
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

-- Check if a record is currently being tracked
function addon:IsRecordTracked(recordID)
    return C_ContentTracking and
        C_ContentTracking.IsTracking(TRACKING_TYPE_DECOR, recordID)
end

-- Set super tracking for map pin auto-select
local function SetSuperTracking(recordID)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedContent then
        C_SuperTrack.SetSuperTrackedContent(TRACKING_TYPE_DECOR, recordID)
    end
end

-- Error code to locale key mapping (hoisted for reuse)
local TRACKING_ERROR_MESSAGES = {
    [Enum.ContentTrackingError.MaxTracked] = "TRACKING_ERROR_MAX",
    [Enum.ContentTrackingError.Untrackable] = "TRACKING_ERROR_UNTRACKABLE",
}

-- Shared tracking toggle (used by Preview track button and Grid shift-click)
function addon:ToggleTracking(recordID)
    local record = recordID and self:GetRecord(recordID)
    if not record or not record.isTrackable then return end

    if not C_ContentTracking then
        self:Print(self.L["ERROR_API_UNAVAILABLE"])
        return
    end

    local coloredName = "|cFF82C5FF" .. record.name .. "|r"

    -- Stop tracking if already tracked
    if self:IsRecordTracked(recordID) then
        C_ContentTracking.StopTracking(TRACKING_TYPE_DECOR, recordID, Enum.ContentTrackingStopType.Manual)
        self:Print(string.format(self.L["TRACKING_STOPPED"], coloredName))
        self:FireEvent("TRACKING_CHANGED", recordID)
        return
    end

    -- Start tracking
    local err = C_ContentTracking.StartTracking(TRACKING_TYPE_DECOR, recordID)

    if not err or err == Enum.ContentTrackingError.AlreadyTracked then
        SetSuperTracking(recordID)
        if not err then
            self:Print(string.format(self.L["TRACKING_STARTED"], coloredName))
        end
    else
        local errorKey = TRACKING_ERROR_MESSAGES[err]
        self:Print(errorKey and self.L[errorKey] or self.L["TRACKING_ERROR_GENERIC"])
    end

    self:FireEvent("TRACKING_CHANGED", recordID)
end

-- Event Handlers
addon:RegisterWoWEvent("CONTENT_TRACKING_UPDATE", function(trackingType, id, isTracked)
    if trackingType == TRACKING_TYPE_DECOR then
        addon:UpdateRecordTrackingStatus(id, isTracked)
    end
end)

-- Trigger a record refresh by flagging ownership data as stale and re-running the search
local function TriggerRecordRefresh()
    addon.needsRecordRefresh = true
    addon:RunSearchNow("TriggerRecordRefresh")
end

-- Central debounced search request to coalesce rapid UI interactions
local pendingSearchTimer = nil

function addon:RequestSearch()
    if pendingSearchTimer then return end  -- Coalesce rapid calls
    if not self.catalogSearcher then return end

    pendingSearchTimer = C_Timer.NewTimer(0.05, function()
        pendingSearchTimer = nil
        if self.catalogSearcher then
            self:CountDebug("search", "debounced")
            self.catalogSearcher:RunSearch()
        end
    end)
end

function addon:CancelPendingSearch()
    if pendingSearchTimer then
        pendingSearchTimer:Cancel()
        pendingSearchTimer = nil
    end
end

-- Cancel any pending debounced search and run immediately
function addon:RunSearchNow(reason)
    self:CancelPendingSearch()
    if self.catalogSearcher then
        self:CountDebug("search", reason or "unknown")
        self.catalogSearcher:RunSearch()
    end
end

-- Toggle searcher auto-update on parameter changes (enable while frame visible)
function addon:SetSearcherVisible(isVisible)
    if self.catalogSearcher then
        self.catalogSearcher:SetAutoUpdateOnParamChanges(isVisible)
    end
end

-- Batch wrapper: suppresses auto-update during fn, runs one search at outermost close
-- Reentrant-safe (nested calls defer to outermost); error-safe via xpcall (no search on error)
local batchDepth = 0

function addon:WithSearcherBatchUpdate(reason, fn)
    batchDepth = batchDepth + 1
    if batchDepth == 1 then
        self:SetSearcherVisible(false)
    end

    local ok = xpcall(fn, CallErrorHandler)

    batchDepth = math.max(0, batchDepth - 1)
    if batchDepth == 0 then
        self:SetSearcherVisible(true)
        if ok then
            self:RunSearchNow(reason)
        end
    end
end

-- Single-entry storage update (direct record update following Blizzard's pattern)
addon:RegisterWoWEvent("HOUSING_STORAGE_ENTRY_UPDATED", function(entryID)
    if not addon.dataLoaded or not entryID then return end

    local recordID = entryID.recordID
    local record = addon.decorRecords[recordID]
    if not record then return end

    local info = C_HousingCatalog.GetCatalogEntryInfo(entryID)
    if not info then return end

    addon:Debug("Storage entry updated: " .. tostring(recordID))
    addon:CountDebug("ownership", "targeted")

    local wasCollected = record.isCollected
    RefreshRecordOwnership(record, info)
    local collectionStateChanged = (record.isCollected ~= wasCollected)

    addon:FireEvent("RECORD_OWNERSHIP_UPDATED", recordID, collectionStateChanged, "targeted")
end)

-- Bulk storage update (refresh record data and re-run searcher)
addon:RegisterWoWEvent("HOUSING_STORAGE_UPDATED", function()
    if not addon.dataLoaded then return end
    addon:CountDebug("ownership", "bulk")

    -- ALWAYS: Lightweight index rebuild (needed by LDB, merchant overlay)
    addon:BuildIndexes()

    -- ALWAYS: Fire ownership event (needed by LDB, WishlistFrame, QuestsTab, AchievementsTab)
    addon:FireEvent("RECORD_OWNERSHIP_UPDATED", nil, true, "bulk")

    -- CONDITIONAL: Heavy search only when MainFrame visible
    if addon.MainFrame and addon.MainFrame:IsShown() then
        addon:Debug("Storage updated (visible), re-running search")
        TriggerRecordRefresh()
    else
        addon:Debug("Storage updated (hidden), deferring search")
        addon.needsFullRefresh = true
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

