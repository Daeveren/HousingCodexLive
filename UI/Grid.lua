--[[
    Housing Codex - Grid.lua
    Virtualized grid display for decor items using WoW ScrollBox
]]

local ADDON_NAME, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS
local GRID_OUTER_PAD = CONSTS.GRID_OUTER_PAD
local GRID_CELL_GAP = CONSTS.GRID_CELL_GAP
local DEFAULT_TILE_SIZE = CONSTS.DEFAULT_TILE_SIZE
local MIN_TILE_SIZE = CONSTS.MIN_TILE_SIZE
local MAX_TILE_SIZE = CONSTS.MAX_TILE_SIZE

local TOOLBAR_HEIGHT = 32
local WISHLIST_STAR_SIZE = CONSTS.WISHLIST_STAR_SIZE_GRID

-- Sort options for dropdown (isNative: true = HousingCatalogSearcher, false = client-side)
local SORT_OPTIONS = {
    { value = CONSTS.SORT_NATIVE_NEWEST, isNative = true },
    { value = CONSTS.SORT_NATIVE_ALPHA, isNative = true },
    { value = CONSTS.SORT_CLIENT_SIZE, isNative = false },
    { value = CONSTS.SORT_CLIENT_QUANTITY, isNative = false },
    -- NOTE: "Qty Placed" sort disabled — Blizzard API returns numPlaced=0 (bug in GetCatalogEntryInfo)
    -- { value = CONSTS.SORT_CLIENT_PLACED, isNative = false },
}

-- Lookup table: sort type value -> localization key
local SORT_LABELS = {
    [CONSTS.SORT_NATIVE_NEWEST] = "SORT_NEWEST",
    [CONSTS.SORT_NATIVE_ALPHA] = "SORT_ALPHABETICAL",
    [CONSTS.SORT_CLIENT_SIZE] = "SORT_SIZE",
    [CONSTS.SORT_CLIENT_QUANTITY] = "SORT_QUANTITY",
    [CONSTS.SORT_CLIENT_PLACED] = "SORT_PLACED",
}

-- Client-side sort field mapping: sort type -> record field name
local CLIENT_SORT_FIELDS = {
    [CONSTS.SORT_CLIENT_SIZE] = "size",           -- Huge=69 -> None=0
    [CONSTS.SORT_CLIENT_QUANTITY] = "totalOwned", -- Most owned first
    [CONSTS.SORT_CLIENT_PLACED] = "numPlaced",   -- Most placed first
}

-- Camera modification type for tile ModelScene (MAINTAIN keeps zoom/rotation on recycle)
local CAMERA_MAINTAIN = CONSTS.CAMERA.MODIFICATION_MAINTAIN

-- Tile color values
local COLOR_BG_NORMAL = { 0.06, 0.06, 0.08, 1 }
local COLOR_BG_HOVER = { 0.1, 0.1, 0.12, 1 }
local COLOR_BORDER_NORMAL = COLORS.BORDER
local COLOR_COLLECTED = { 0.2, 0.8, 0.2 }  -- Green for owned items

addon.Grid = {}
local Grid = addon.Grid

Grid.scrollBox = nil
Grid.scrollBar = nil
Grid.dataProvider = nil
Grid.currentRecordIDs = {}
Grid.selectedRecordID = nil
Grid.tileSize = DEFAULT_TILE_SIZE
Grid.parent = nil
Grid.toolbar = nil
Grid.container = nil
Grid.sortDropdown = nil
Grid.sortLabel = nil
Grid.emptyState = nil

-- Responsive toolbar state
Grid.toolbarLayout = nil  -- "full", "noSlider", "noFilter", "minimal"
Grid.toolbarElements = {} -- References to toolbar elements for responsive hiding

-- Grid uses shared SetupTileFrame with simple OnLeave (just reset color and hide tooltip)
local function SetupTileFrame(tile, tileSize)
    addon:SetupTileFrame(tile, tileSize, function(t)
        t:SetBackdropColor(unpack(COLOR_BG_NORMAL))
        GameTooltip:Hide()
    end)
end

function Grid:CreateToolbar(parent)
    if self.toolbar then return self.toolbar end

    local toolbar = CreateFrame("Frame", nil, parent)
    toolbar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    toolbar:SetHeight(TOOLBAR_HEIGHT)
    self.toolbar = toolbar

    -- Background
    local bg = toolbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.07, 0.9)

    local L = addon.L

    -- === LEFT SIDE: Size slider + Collection buttons + Filter dropdown ===

    -- Size label (shortened from "Tile Size:")
    local label = addon:CreateFontString(toolbar, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", toolbar, "LEFT", GRID_OUTER_PAD, 0)
    label:SetText(L["SIZE_LABEL"])
    label:SetTextColor(0.8, 0.8, 0.8, 1)

    -- Size value display
    local valueText = addon:CreateFontString(toolbar, "OVERLAY", "GameFontNormalSmall")
    valueText:SetPoint("LEFT", label, "RIGHT", 6, 0)
    valueText:SetTextColor(1, 0.82, 0, 1)
    valueText:SetText(tostring(self.tileSize))
    self.tileSizeValueText = valueText

    -- Size slider (halved width: 150 -> 75)
    local slider = CreateFrame("Slider", nil, toolbar, "MinimalSliderTemplate")
    slider:SetPoint("LEFT", valueText, "RIGHT", 12, 0)
    slider:SetSize(75, 16)
    slider:SetMinMaxValues(MIN_TILE_SIZE, MAX_TILE_SIZE)
    slider:SetValueStep(8)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(self.tileSize)
    self.tileSizeSlider = slider

    -- Slider change handler with debounce
    slider:SetScript("OnValueChanged", function(sliderFrame, value)
        value = math.floor(value)
        valueText:SetText(tostring(value))

        -- Debounce the rebuild to avoid excessive rebuilds while dragging
        if sliderFrame.debounceTimer then
            sliderFrame.debounceTimer:Cancel()
        end
        sliderFrame.debounceTimer = C_Timer.NewTimer(0.15, function()
            Grid:SetTileSize(value)
        end)
    end)

    -- Filter dropdown (includes collection, trackable, special filters, tags)
    local filterDropdown = addon.FilterBar:CreateDropdown(toolbar)
    filterDropdown:SetPoint("LEFT", slider, "RIGHT", 16, 0)
    self.filterDropdown = filterDropdown

    -- === RIGHT SIDE: Sort dropdown + Sort label ===

    -- Sort dropdown (rightmost element in toolbar)
    local sortDropdown = self:CreateSortDropdown(toolbar)
    sortDropdown:SetPoint("RIGHT", toolbar, "RIGHT", -GRID_OUTER_PAD, 0)
    self.sortDropdown = sortDropdown

    -- "Sort by" label (left of sort dropdown)
    local sortLabel = addon:CreateFontString(toolbar, "OVERLAY", "GameFontNormalSmall")
    sortLabel:SetPoint("RIGHT", sortDropdown, "LEFT", -6, 0)
    sortLabel:SetText(L["SORT_BY_LABEL"])
    sortLabel:SetTextColor(0.8, 0.8, 0.8, 1)
    self.sortLabel = sortLabel

    -- === CENTER: Search box (flexible width via two-point anchoring) ===
    local searchBox = addon.SearchBox:Create(toolbar)
    searchBox:SetPoint("LEFT", filterDropdown, "RIGHT", 16, 0)
    searchBox:SetPoint("RIGHT", sortLabel, "LEFT", -16, 0)
    self.searchBox = searchBox

    -- Store element references for responsive hiding
    self.toolbarElements = {
        sizeLabel = label,
        sizeValue = valueText,
        sizeSlider = slider,
        filterDropdown = filterDropdown,
        searchBox = searchBox,
        sortLabel = sortLabel,
        sortDropdown = sortDropdown,
    }

    -- Setup responsive toolbar updates
    toolbar:SetScript("OnSizeChanged", function(_, width)
        self:UpdateToolbarLayout(width)
    end)

    return toolbar
end

-- Update toolbar element visibility based on available width
-- Hide order: Size slider -> Filter dropdown -> Search box -> Sort dropdown (always visible)
-- Breakpoints (content area width):
--   >= 450px: All visible
--   350-449px: Hide size slider
--   250-349px: Hide size slider + filter dropdown
--   < 250px: Hide size slider + filter dropdown + search box
function Grid:UpdateToolbarLayout(toolbarWidth)
    local newLayout
    if toolbarWidth >= 450 then
        newLayout = "full"
    elseif toolbarWidth >= 350 then
        newLayout = "noSlider"
    elseif toolbarWidth >= 250 then
        newLayout = "noFilter"
    else
        newLayout = "minimal"
    end

    if self.toolbarLayout == newLayout then return end
    self.toolbarLayout = newLayout

    local elems = self.toolbarElements
    if not elems or not elems.sizeLabel then return end

    -- Determine visibility based on layout
    local showSlider = (newLayout == "full")
    local showFilter = (newLayout == "full" or newLayout == "noSlider")
    local showSearch = (newLayout ~= "minimal")

    -- Apply visibility
    elems.sizeLabel:SetShown(showSlider)
    elems.sizeValue:SetShown(showSlider)
    elems.sizeSlider:SetShown(showSlider)
    elems.filterDropdown:SetShown(showFilter)
    elems.searchBox:SetShown(showSearch)

    -- Determine left anchor for filter dropdown (slider if visible, otherwise toolbar edge)
    local filterLeftAnchor = showSlider and elems.sizeSlider or self.toolbar
    local filterLeftPoint = showSlider and "RIGHT" or "LEFT"
    local filterLeftOffset = showSlider and 16 or GRID_OUTER_PAD

    elems.filterDropdown:ClearAllPoints()
    if showFilter then
        elems.filterDropdown:SetPoint("LEFT", filterLeftAnchor, filterLeftPoint, filterLeftOffset, 0)
    end

    -- Determine left anchor for search box (rightmost visible element on the left)
    local searchLeftAnchor, searchLeftPoint, searchLeftOffset
    if showFilter then
        searchLeftAnchor, searchLeftPoint, searchLeftOffset = elems.filterDropdown, "RIGHT", 16
    elseif showSlider then
        searchLeftAnchor, searchLeftPoint, searchLeftOffset = elems.sizeSlider, "RIGHT", 16
    else
        searchLeftAnchor, searchLeftPoint, searchLeftOffset = self.toolbar, "LEFT", GRID_OUTER_PAD
    end

    elems.searchBox:ClearAllPoints()
    if showSearch then
        elems.searchBox:SetPoint("LEFT", searchLeftAnchor, searchLeftPoint, searchLeftOffset, 0)
        elems.searchBox:SetPoint("RIGHT", elems.sortLabel, "LEFT", -16, 0)
    end

    addon:Debug("Toolbar layout: " .. newLayout .. " (width: " .. math.floor(toolbarWidth) .. ")")
end

-- Get localized label for a sort type value
local function GetSortLabel(sortType)
    local key = SORT_LABELS[sortType] or "SORT_NEWEST"
    return addon.L[key]
end

-- Sort dropdown using modern Blizzard_Menu system
function Grid:CreateSortDropdown(parent)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetSize(100, 22)

    -- Setup menu generator
    dropdown:SetupMenu(function(dropdownFrame, rootDescription)
        for _, opt in ipairs(SORT_OPTIONS) do
            rootDescription:CreateRadio(
                GetSortLabel(opt.value),
                function() return (addon.db.browser.sortType or 0) == opt.value end,
                function()
                    Grid:SetSortType(opt.value)
                end,
                opt.value
            )
        end
    end)

    -- Set initial text
    self:UpdateSortDropdownText(dropdown)

    return dropdown
end

function Grid:SetSortType(sortType)
    if not addon.db or not addon.db.browser then return end

    addon.db.browser.sortType = sortType

    -- Native sorts are < 100, client-side sorts are >= 100
    local isNative = sortType < 100

    if isNative then
        if addon.catalogSearcher then
            addon.catalogSearcher:SetSortType(sortType)
            addon:RequestSearch()
        end
    else
        self:ReapplyFilters()
    end

    self:UpdateSortDropdownText(self.sortDropdown)
    addon:Debug("Sort type set to: " .. tostring(sortType) .. " (native: " .. tostring(isNative) .. ")")
end

function Grid:UpdateSortDropdownText(dropdown)
    if not dropdown then return end

    local sortType = addon.db and addon.db.browser and addon.db.browser.sortType or 0
    dropdown:SetDefaultText(GetSortLabel(sortType))
end

function Grid:CreateScrollBox(parent, tileSize)
    -- Create container frame below toolbar
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", self.toolbar, "BOTTOMLEFT", GRID_OUTER_PAD, 0)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -GRID_OUTER_PAD - 20, GRID_OUTER_PAD)
    self.container = container

    -- Create ScrollBox
    local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT")
    scrollBox:SetPoint("BOTTOMRIGHT")
    self.scrollBox = scrollBox

    -- Create ScrollBar
    local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", container, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", container, "BOTTOMRIGHT", 4, 0)
    self.scrollBar = scrollBar

    -- Calculate columns based on current container width
    local function GetColumnCount()
        local containerWidth = container:GetWidth()
        if containerWidth <= 0 then containerWidth = 800 end
        return math.max(1, math.floor((containerWidth + GRID_CELL_GAP) / (tileSize + GRID_CELL_GAP)))
    end

    -- Track column count for resize detection
    self.currentColumnCount = nil
    self.resizeTimer = nil

    container:SetScript("OnSizeChanged", function(_, width, height)
        if self.resizeTimer then self.resizeTimer:Cancel() end
        self.resizeTimer = C_Timer.NewTimer(0.15, function()
            self.resizeTimer = nil
            local newColumns = math.max(1, math.floor((width + GRID_CELL_GAP) / (self.tileSize + GRID_CELL_GAP)))
            if self.currentColumnCount and newColumns ~= self.currentColumnCount then
                self:Rebuild()
            end
        end)
    end)

    -- Create grid view
    local columns = GetColumnCount()
    local view = CreateScrollBoxListGridView(
        columns,
        1,  -- top padding (minimal)
        GRID_OUTER_PAD,
        GRID_OUTER_PAD,
        GRID_OUTER_PAD,
        GRID_CELL_GAP,
        GRID_CELL_GAP
    )

    -- Tell the view element sizes (BackdropTemplate has no defined size)
    view:SetElementSizeCalculator(function()
        return tileSize, tileSize
    end)

    -- Set element extent for scroll calculations
    view:SetElementExtent(tileSize)
    view:SetStrideExtent(tileSize)

    -- Element resetter for frame recycling
    view:SetElementResetter(function(tile)
        if tile.icon then
            tile.icon:SetTexture(nil)
            tile.icon:Show()  -- Reset to default visible state
        end
        if tile.modelScene then
            local actor = tile.modelScene:GetActorByTag("decor")
            if actor then
                actor:ClearModel()
            end
            tile.modelScene:Hide()
        end
        if tile.placed then tile.placed:Hide() end
        if tile.quantity then
            tile.quantity:ClearAllPoints()
            tile.quantity:SetPoint("BOTTOMRIGHT", -4, 3)
            tile.quantity:Hide()
        end
        if tile.wishlistStar then tile.wishlistStar:Hide() end
        tile:SetBackdropBorderColor(unpack(COLOR_BORDER_NORMAL))
        tile:SetBackdropColor(unpack(COLOR_BG_NORMAL))
        tile:SetScript("OnMouseDown", nil)
        tile:SetScript("OnEnter", nil)
        tile.recordID = nil
    end)

    -- Element initializer
    view:SetElementInitializer("BackdropTemplate", function(tile, elementData)
        if not tile.icon then
            SetupTileFrame(tile, tileSize)
        else
            -- Update size if tile was recycled from different size
            tile:SetSize(tileSize, tileSize)
        end

        local recordID = elementData.recordID
        local record = addon:GetRecord(recordID)
        tile.recordID = recordID

        -- Display 3D model or 2D icon (shared utility handles lazy ModelScene creation)
        addon:SetupTileDisplay(tile, record, CAMERA_MAINTAIN)

        -- Placed count (green, right side)
        if record and record.numPlaced and record.numPlaced > 0 then
            tile.placed:SetText(record.numPlaced)
            tile.placed:Show()
            tile.quantity:ClearAllPoints()
            tile.quantity:SetPoint("RIGHT", tile.placed, "LEFT", -5, 0)
        else
            tile.placed:Hide()
            tile.quantity:ClearAllPoints()
            tile.quantity:SetPoint("BOTTOMRIGHT", -4, 3)
        end

        -- Owned count (gray, left of placed or at bottom-right)
        if record and record.totalOwned and record.totalOwned > 0 then
            tile.quantity:SetText(record.totalOwned)
            tile.quantity:Show()
        end

        -- Wishlist star badge
        if tile.wishlistStar then
            tile.wishlistStar:SetShown(addon:IsWishlisted(recordID))
        end

        -- Selection state
        if Grid.selectedRecordID == recordID then
            tile:SetBackdropBorderColor(unpack(COLORS.GOLD))
        end

        -- Click handler
        tile:SetScript("OnMouseDown", function(_, button)
            if button == "RightButton" then
                addon.ContextMenu:ShowForDecor(tile, recordID)
                return
            end
            if button == "LeftButton" and IsShiftKeyDown() then
                addon:ToggleTracking(recordID)
                return
            end
            Grid:SelectRecord(recordID)
        end)

        -- Tooltip handler
        tile:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(COLOR_BG_HOVER))
            local rec = addon:GetRecord(self.recordID)
            if not rec then return end

            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(rec.name or addon.L["UNKNOWN"], 1, 1, 1)
            if rec.sourceText and rec.sourceText ~= "" then
                GameTooltip:AddLine(rec.sourceText, 0.8, 0.8, 0.8, true)
            end
            if rec.totalOwned and rec.totalOwned > 0 then
                GameTooltip:AddLine(string.format(addon.L["DETAILS_OWNED"], rec.totalOwned), unpack(COLOR_COLLECTED))
            end
            if rec.numPlaced and rec.numPlaced > 0 then
                GameTooltip:AddLine(string.format(addon.L["DETAILS_PLACED"], rec.numPlaced), 0.4, 0.8, 0.4)
            end
            if rec.isTrackable then
                local isTracked = addon:IsRecordTracked(self.recordID)
                local hint = isTracked and addon.L["TOOLTIP_SHIFT_CLICK_UNTRACK"] or addon.L["TOOLTIP_SHIFT_CLICK_TRACK"]
                GameTooltip:AddLine(hint, 0.5, 0.5, 0.5)
            end
            GameTooltip:Show()
        end)
    end)

    -- Initialize ScrollBox
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    self.view = view
    self.currentColumnCount = columns

    -- Initialize DataProvider once (reused via Flush/InsertTable in SetData)
    self.dataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(self.dataProvider)

    addon:Debug("Grid created with " .. columns .. " columns, tile size " .. tileSize)
end

function Grid:DestroyScrollBox()
    -- Cancel pending resize timer to prevent errors after teardown
    if self.resizeTimer then
        self.resizeTimer:Cancel()
        self.resizeTimer = nil
    end

    if self.scrollBox then
        self.scrollBox:Hide()
        self.scrollBox:SetParent(nil)
        self.scrollBox = nil
    end
    if self.scrollBar then
        self.scrollBar:Hide()
        self.scrollBar:SetParent(nil)
        self.scrollBar = nil
    end
    if self.container then
        self.container:Hide()
        self.container:SetParent(nil)
        self.container = nil
    end
    self.view = nil
    self.dataProvider = nil
end

function Grid:Create(parent)
    if self.toolbar and self.scrollBox then return end

    self.parent = parent

    -- Load saved tile size from db with validation
    local savedSize = addon.db and addon.db.browser and addon.db.browser.tileSize
    local isValidSize = savedSize and savedSize >= MIN_TILE_SIZE and savedSize <= MAX_TILE_SIZE
    self.tileSize = isValidSize and savedSize or DEFAULT_TILE_SIZE

    -- Create toolbar and scrollbox
    self:CreateToolbar(parent)
    self:CreateScrollBox(parent, self.tileSize)
    self:CreateEmptyState(parent)

    -- Sync slider to loaded value (toolbar may have been created with default)
    if self.tileSizeSlider then
        self.tileSizeSlider:SetValue(self.tileSize)
        self.tileSizeValueText:SetText(tostring(self.tileSize))
    end

    -- Apply saved sort type (only native sorts go to catalogSearcher)
    local savedSortType = addon.db and addon.db.browser and addon.db.browser.sortType
    if savedSortType and savedSortType < 100 and addon.catalogSearcher then
        addon.catalogSearcher:SetSortType(savedSortType)
    end

    addon:Debug("Grid created with tile size: " .. self.tileSize)

    -- Populate grid if data is already loaded and we're on DECOR tab
    -- This handles the case where DATA_LOADED and TAB_CHANGED fired before Grid was created
    if addon.dataLoaded and addon.Tabs and addon.Tabs:GetCurrentTab() == "DECOR" then
        if addon.catalogSearcher then
            -- Run search to populate grid (searcher already has current filter state)
            addon:RunSearchNow("Grid:Create initial")
        else
            -- Fallback: use all record IDs
            local recordIDs = addon:GetAllRecordIDs()
            self:SetData(recordIDs)
        end
    end
end

function Grid:UpdateResultCount()
    -- Delegate to Categories module for sidebar display
    if addon.Categories then
        local shown = #self.currentRecordIDs
        local total = #self.unfilteredRecordIDs
        addon.Categories:UpdateResultCount(shown, total)
    end
end

function Grid:CreateEmptyState(parent)
    local frame = CreateFrame("Frame", nil, self.container)
    frame:SetAllPoints(self.container)
    frame:SetFrameLevel(self.container:GetFrameLevel() + 5)
    frame:Hide()
    self.emptyState = frame

    -- Semi-transparent background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.03, 0.03, 0.05, 0.9)

    -- Message text
    local msg = addon:CreateFontString(frame, "OVERLAY", "GameFontNormalLarge")
    msg:SetPoint("CENTER", frame, "CENTER", 0, 20)
    msg:SetText(addon.L["EMPTY_STATE_MESSAGE"])
    msg:SetTextColor(0.6, 0.6, 0.6, 1)
    frame.message = msg

    -- Reset filters button
    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetSize(120, 26)
    btn:SetPoint("TOP", msg, "BOTTOM", 0, -16)
    btn:SetText(addon.L["RESET_FILTERS"])
    btn:SetScript("OnClick", function()
        addon.Filters:ResetAllFilters()
    end)
    frame.resetBtn = btn
end

function Grid:UpdateEmptyState()
    if not self.emptyState then return end

    local count = #self.currentRecordIDs
    local showEmpty = count == 0 and addon.dataLoaded
    self.emptyState:SetShown(showEmpty)

    -- Also show/hide scrollbox appropriately
    if self.scrollBox then
        self.scrollBox:SetShown(not showEmpty)
    end
    if self.scrollBar then
        self.scrollBar:SetShown(not showEmpty)
    end
end

function Grid:SetTileSize(newSize)
    newSize = math.max(MIN_TILE_SIZE, math.min(MAX_TILE_SIZE, newSize))
    if newSize == self.tileSize then return end

    self.tileSize = newSize

    -- Save to db
    if addon.db and addon.db.browser then
        addon.db.browser.tileSize = newSize
    end

    -- Rebuild the grid
    self:Rebuild()
end

function Grid:Rebuild()
    if not self.parent then return end

    -- Save current data
    local savedUnfilteredIDs = self.unfilteredRecordIDs
    local savedSelection = self.selectedRecordID

    -- Destroy and recreate
    self:DestroyScrollBox()
    self:CreateScrollBox(self.parent, self.tileSize)

    -- Recreate empty state (depends on container)
    if self.emptyState then
        self.emptyState:SetParent(nil)
        self.emptyState = nil
    end
    self:CreateEmptyState(self.parent)

    -- Restore data
    self.selectedRecordID = savedSelection
    if savedUnfilteredIDs and #savedUnfilteredIDs > 0 then
        self:SetData(savedUnfilteredIDs)
    end

    addon:Debug("Grid rebuilt with tile size " .. self.tileSize)
end

-- Store unfiltered IDs for re-filtering without new search
Grid.unfilteredRecordIDs = {}

-- Apply client-side filters that aren't supported by HousingCatalogSearcher
function Grid:ApplyPostSearchFilters(recordIDs)
    local filtered = {}
    for _, recordID in ipairs(recordIDs) do
        local record = addon:GetRecord(recordID)
        if record
            and addon.Filters:PassesTrackableFilter(record)
            and addon.Filters:PassesWishlistFilter(record)
            and addon.Filters:PassesPlacedFilter(record)
        then
            table.insert(filtered, recordID)
        end
    end
    return filtered
end

-- Sort record IDs by a field extracted from each record (descending order)
local function SortByField(recordIDs, fieldName)
    table.sort(recordIDs, function(a, b)
        local recA = addon:GetRecord(a)
        local recB = addon:GetRecord(b)
        local valA = recA and recA[fieldName] or 0
        local valB = recB and recB[fieldName] or 0
        return valA > valB
    end)
end

-- Apply client-side sorting for non-native sort types
function Grid:ApplyClientSideSort(recordIDs, sortType)
    if not recordIDs or #recordIDs == 0 then return recordIDs end

    local fieldName = CLIENT_SORT_FIELDS[sortType]
    if fieldName then
        SortByField(recordIDs, fieldName)
    end

    return recordIDs
end

function Grid:SetData(recordIDs)
    if not self.scrollBox or not self.dataProvider then return end

    -- Store unfiltered IDs for re-filtering
    self.unfilteredRecordIDs = recordIDs or {}

    if not recordIDs or #recordIDs == 0 then
        self.currentRecordIDs = {}
        self.dataProvider:Flush()
        self:UpdateResultCount()
        self:UpdateEmptyState()
        addon:Debug("Grid cleared - no items")
        return
    end

    -- Apply post-search filters (trackable, etc.)
    local filteredIDs = self:ApplyPostSearchFilters(recordIDs)

    -- Apply client-side sorting if using a non-native sort type
    local sortType = addon.db and addon.db.browser and addon.db.browser.sortType or 0
    if sortType >= 100 then
        filteredIDs = self:ApplyClientSideSort(filteredIDs, sortType)
    end

    self.currentRecordIDs = filteredIDs

    -- Convert to element data
    local elements = {}
    for _, recordID in ipairs(filteredIDs) do
        table.insert(elements, { recordID = recordID })
    end

    -- Reuse DataProvider: Flush existing data and insert new elements
    self.dataProvider:Flush()
    if #elements > 0 then
        self.dataProvider:InsertTable(elements)
    end

    -- Update result count and empty state
    self:UpdateResultCount()
    self:UpdateEmptyState()

    addon:Debug("Grid populated with " .. #filteredIDs .. " items (from " .. #recordIDs .. " search results)")
end

function Grid:ReapplyFilters()
    -- Re-apply post-search filters to the current unfiltered data
    if self.unfilteredRecordIDs and #self.unfilteredRecordIDs > 0 then
        self:SetData(self.unfilteredRecordIDs)
    end
end

function Grid:SelectRecord(recordID)
    local prevSelected = self.selectedRecordID
    self.selectedRecordID = recordID

    -- Update selection visuals on visible frames only
    if self.scrollBox then
        self.scrollBox:ForEachFrame(function(tile)
            if not tile.recordID then return end

            if tile.recordID == recordID then
                tile:SetBackdropBorderColor(unpack(COLORS.GOLD))
            elseif tile.recordID == prevSelected then
                tile:SetBackdropBorderColor(unpack(COLOR_BORDER_NORMAL))
            end
        end)
    end

    -- Fire selection event
    addon:FireEvent("RECORD_SELECTED", recordID)
    addon:Debug("Selected record: " .. tostring(recordID))
end

function Grid:ClearSelection()
    if not self.selectedRecordID then return end

    local prevSelected = self.selectedRecordID
    self.selectedRecordID = nil

    -- Remove gold border from previously selected tile
    if self.scrollBox then
        self.scrollBox:ForEachFrame(function(tile)
            if tile.recordID == prevSelected then
                tile:SetBackdropBorderColor(unpack(COLOR_BORDER_NORMAL))
            end
        end)
    end

    addon:FireEvent("RECORD_SELECTED", nil)
end

function Grid:GetSelectedRecord()
    return self.selectedRecordID
end

function Grid:Refresh()
    if self.scrollBox then
        self.scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    end
end

-- Debounced refresh to coalesce rapid successive storage events
Grid.refreshDebounceTimer = nil

function Grid:DebouncedRefresh()
    if self.refreshDebounceTimer then return end

    self.refreshDebounceTimer = C_Timer.NewTimer(0.05, function()
        self.refreshDebounceTimer = nil
        self:Refresh()
    end)
end

function Grid:Show()
    if self.toolbar then self.toolbar:Show() end
    if self.container then self.container:Show() end
    if self.scrollBar then self.scrollBar:Show() end
    self:UpdateEmptyState()
end

function Grid:Hide()
    if self.toolbar then self.toolbar:Hide() end
    if self.container then self.container:Hide() end
    if self.scrollBar then self.scrollBar:Hide() end
    if self.emptyState then self.emptyState:Hide() end

    -- Cancel pending timers
    self:CancelTimers()
end

function Grid:CancelTimers()
    if self.tileSizeSlider and self.tileSizeSlider.debounceTimer then
        self.tileSizeSlider.debounceTimer:Cancel()
        self.tileSizeSlider.debounceTimer = nil
    end
    if self.refreshDebounceTimer then
        self.refreshDebounceTimer:Cancel()
        self.refreshDebounceTimer = nil
    end
end

-- Event handlers
addon:RegisterInternalEvent("DATA_LOADED", function(recordCount)
    if addon.Tabs and addon.Tabs:GetCurrentTab() == "DECOR" then
        -- Trigger search refresh to respect current filter state
        -- SEARCH_RESULTS_UPDATED will populate grid with filtered results
        if addon.catalogSearcher then
            addon:RunSearchNow("DATA_LOADED")
        else
            -- Fallback: use all record IDs (no searcher available)
            local recordIDs = addon:GetAllRecordIDs()
            Grid:SetData(recordIDs)
        end
    end
end)

function Grid:MergeResults(listA, listB)
    local seen = {}
    local merged = {}
    for _, id in ipairs(listA) do
        if not seen[id] then
            seen[id] = true
            table.insert(merged, id)
        end
    end
    for _, id in ipairs(listB) do
        if not seen[id] then
            seen[id] = true
            table.insert(merged, id)
        end
    end
    return merged
end

addon:RegisterInternalEvent("SEARCH_RESULTS_UPDATED", function(recordIDs)
    -- Skip grid updates when MainFrame is hidden (defer until reopened)
    if not addon.MainFrame or not addon.MainFrame:IsShown() then
        addon.needsGridRefresh = true
        return
    end
    if not addon.Tabs or addon.Tabs:GetCurrentTab() ~= "DECOR" then return end
    addon.needsGridRefresh = false

    Grid:ClearSelection()

    -- Supplement native searcher results with client-side text search matches
    local searchText = addon.SearchBox and addon.SearchBox:GetText() or ""
    searchText = strtrim(searchText)
    if searchText ~= "" and addon.indexesBuilt and addon.Filters:AreAdvancedFiltersAtDefault() then
        local clientIDs = addon:SearchByText(searchText)
        local filteredClientIDs = addon.Filters:FilterBySearcherRules(clientIDs)
        recordIDs = Grid:MergeResults(recordIDs, filteredClientIDs)
    end

    Grid:SetData(recordIDs)
end)

addon:RegisterInternalEvent("TAB_CHANGED", function(tabKey)
    if tabKey == "DECOR" then
        Grid:Show()
        if addon.dataLoaded then
            -- Trigger search refresh to respect current filter state
            -- SEARCH_RESULTS_UPDATED will populate grid with filtered results
            if addon.catalogSearcher then
                addon:RunSearchNow("TAB_CHANGED")
            else
                -- Fallback: use all record IDs (no searcher available)
                local recordIDs = addon:GetAllRecordIDs()
                Grid:SetData(recordIDs)
            end
        end
    else
        Grid:Hide()
    end
end)

-- Re-apply post-search filters when filter state changes (e.g., trackable filter)
addon:RegisterInternalEvent("FILTER_CHANGED", function()
    if addon.Tabs and addon.Tabs:GetCurrentTab() == "DECOR" then
        Grid:ClearSelection()
        Grid:ReapplyFilters()
    end
end)

-- Refresh grid when a record's ownership data changes (debounced to coalesce rapid events)
addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function(recordID, collectionStateChanged, updateKind)
    -- Skip when collection state didn't change (no visual difference)
    if collectionStateChanged == false then return end
    -- Skip grid updates when MainFrame is hidden
    if not addon.MainFrame or not addon.MainFrame:IsShown() then
        addon.needsGridRefresh = true
        return
    end
    if addon.Tabs and addon.Tabs:GetCurrentTab() == "DECOR" then
        Grid:DebouncedRefresh()
    end
end)

-- Update wishlist badges when wishlist changes
addon:RegisterInternalEvent("WISHLIST_CHANGED", function(recordID, isWishlisted)
    -- Only update visible frames for performance
    if Grid.scrollBox then
        Grid.scrollBox:ForEachFrame(function(tile)
            if tile.recordID == recordID and tile.wishlistStar then
                tile.wishlistStar:SetShown(isWishlisted)
            end
        end)
    end
end)

addon.MainFrame:RegisterContentAreaInitializer("Grid", function(contentArea)
    Grid:Create(contentArea)
end)
