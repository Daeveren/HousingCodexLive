--[[
    Housing Codex - ZoneOverlay.lua
    World map overlay panel showing uncollected decor items for the current zone
    Parented to WorldMapFrame.ScrollContainer (no taint per Blizzard pattern)
]]

local _, addon = ...

addon.ZoneOverlay = {}

local ZoneOverlay = addon.ZoneOverlay

-- Layout constants
local PANEL_WIDTH = 240
local PANEL_WIDTH_MINIMIZED = 170
local ITEM_ROW_HEIGHT = 22
local HEADER_HEIGHT = 24
local TITLE_BAR_HEIGHT = 28
local ICON_SIZE = 20
local PREVIEW_SIZE = 240
local PADDING = 8
local MAX_VISIBLE_ENTRIES = 10
local COLLAPSED_HEIGHT = TITLE_BAR_HEIGHT - 6
local TITLE_FONT_SIZE = 11
local ITEM_FONT_SIZE = 10
local BACKDROP_ALPHA_FACTOR = 0.95  -- Reduce backdrop alpha slightly vs user setting for visual separation

-- Model scene constants (same as tile display)
local MODEL_SCENE_ID = addon.CONSTANTS.MODEL_SCENE_ID
local MODEL_ACTOR_TAG = "decor"

-- Auto-rotation speed (centralized in CONSTANTS.CAMERA)
local ROTATION_SPEED = addon.CONSTANTS.CAMERA.ROTATION_SPEED

-- Arrow rotation angles (bag-arrow atlas points right by default)
local ARROW_COLLAPSED = math.pi / 2        -- Points down
local ARROW_EXPANDED = 3 * math.pi / 2    -- Points up

-- Fallback icon for missing textures
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Debounce timer handles
local updateTimer = nil
local ownershipTimer = nil

-- State
local currentMapID = nil
local frame = nil
local contentFrame = nil
local previewFrame = nil
local previewModelScene = nil
local expandedCategories = {}   -- categoryKey -> true/false
local lastCategoryMapID = nil   -- reset on zone change

-- Helper: get preview size based on scale setting
local function GetPreviewSize()
    local scale = addon.db and addon.db.settings.zoneOverlayPreviewScale or 1.0
    return math.floor(PREVIEW_SIZE * scale)
end

-- Helper: place a map pin for a vendor NPC
local function PlaceVendorWaypoint(npcId, npcName)
    local L = addon.L
    local point, locData, errorKey = addon.VendorsTab:GetVendorTrackPoint(npcId)
    if not point then
        addon:Print(L[errorKey or "VENDOR_NO_LOCATION"])
        return
    end

    if not addon.Waypoints:Set(locData.uiMapId, locData.x / 100, locData.y / 100, npcName or L["VENDOR_FALLBACK_NAME"]) then
        return
    end

    addon:Print(string.format(L["VENDOR_WAYPOINT_SET"], npcName or L["VENDOR_FALLBACK_NAME"]))
end

-- Helper: schedule update for current world map zone
local function ScheduleMapUpdate()
    local mapID = WorldMapFrame:GetMapID()
    if mapID then
        ZoneOverlay:ScheduleUpdate(mapID)
    end
end

--------------------------------------------------------------------------------
-- Preview tooltip (3D model on hover)
--------------------------------------------------------------------------------
local function CreatePreviewFrame()
    if previewFrame then return end

    local size = GetPreviewSize()
    previewFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    previewFrame:SetSize(size + 8, size + 8)
    previewFrame:SetFrameStrata("TOOLTIP")
    previewFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    previewFrame:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
    previewFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    previewFrame:Hide()

    -- Icon fallback (for items without models)
    local icon = previewFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size - 16, size - 16)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(unpack(addon.CONSTANTS.ICON_CROP_COORDS))
    previewFrame.icon = icon
end

local function ShowPreview(itemRow, recordID)
    CreatePreviewFrame()

    local record = addon:GetRecord(recordID)
    if not record then
        previewFrame:Hide()
        return
    end

    -- Apply current preview size
    local size = GetPreviewSize()
    previewFrame:SetSize(size + 8, size + 8)
    previewFrame.icon:SetSize(size - 16, size - 16)

    -- Position beside the overlay panel
    previewFrame:ClearAllPoints()
    local db = addon.db
    if db and db.settings.zoneOverlayPosition == "bottomRight" then
        previewFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -4, 0)
    else
        previewFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
    end

    -- Try 3D model first
    local useModel = record.modelAsset and record.modelAsset > 0
    if useModel then
        if not previewModelScene then
            previewModelScene = CreateFrame("ModelScene", nil, previewFrame, "NonInteractableModelSceneMixinTemplate")
            previewModelScene:SetPoint("TOPLEFT", 4, -4)
            previewModelScene:SetPoint("BOTTOMRIGHT", -4, 4)
            previewModelScene:TransitionToModelSceneID(MODEL_SCENE_ID,
                addon.CONSTANTS.CAMERA.TRANSITION_IMMEDIATE,
                addon.CONSTANTS.CAMERA.MODIFICATION_MAINTAIN, true)

            -- Auto-rotate model in tooltip
            previewModelScene:SetScript("OnUpdate", function(self, elapsed)
                local actor = self:GetActorByTag(MODEL_ACTOR_TAG)
                if actor then
                    local yaw = actor:GetYaw() or 0
                    actor:SetYaw(yaw + elapsed * ROTATION_SPEED)
                end
            end)
        end

        local actor = previewModelScene:GetActorByTag(MODEL_ACTOR_TAG)
        if not actor then
            actor = previewModelScene:AcquireActor()
            if actor then
                previewModelScene.tagToActor = previewModelScene.tagToActor or {}
                previewModelScene.tagToActor[MODEL_ACTOR_TAG] = actor
            end
        end

        if actor then
            local success = actor:SetModelByFileID(record.modelAsset)
            if success then
                actor:SetYaw(0)
                previewModelScene:Show()
                previewFrame.icon:Hide()
                previewFrame:Show()
                return
            end
        end
    end

    -- Fallback: 2D icon
    if previewModelScene then previewModelScene:Hide() end
    addon:SetIcon(previewFrame.icon, record.icon or FALLBACK_ICON, record.iconType)
    previewFrame.icon:Show()
    previewFrame:Show()
end

local function HidePreview()
    if previewFrame then
        previewFrame:Hide()
    end
end

--------------------------------------------------------------------------------
-- Frame creation
--------------------------------------------------------------------------------
local function CreateOverlayFrame()
    if frame then return end

    frame = CreateFrame("Frame", "HousingCodexZoneOverlayFrame", WorldMapFrame.ScrollContainer, "BackdropTemplate")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetHeight(TITLE_BAR_HEIGHT)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    frame.titleBar = titleBar

    -- Click anywhere on title bar to toggle collapse/expand
    titleBar:EnableMouse(true)
    titleBar:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and addon.db then
            addon.db.settings.zoneOverlayMinimized = not addon.db.settings.zoneOverlayMinimized
            ZoneOverlay:RefreshLayout()
        end
    end)

    -- HC icon in title bar
    local titleIcon = titleBar:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(16, 16)
    titleIcon:SetPoint("LEFT", 8, 0)
    titleIcon:SetTexture("Interface\\AddOns\\HousingCodex\\HC64")
    frame.titleIcon = titleIcon

    -- Title text
    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetPoint("LEFT", titleIcon, "RIGHT", 6, 0)
    titleText:SetPoint("RIGHT", -28, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    titleText:SetFont(addon:GetFontPath(), TITLE_FONT_SIZE, "")
    addon:RegisterFontStringWithSize(titleText, "GameFontNormal", TITLE_FONT_SIZE, "")
    titleText:SetTextColor(1, 0.82, 0, 1)
    frame.titleText = titleText

    -- Toggle button (expand/collapse) with arrow
    local toggleBtn = CreateFrame("Button", nil, titleBar)
    toggleBtn:SetSize(20, 20)
    toggleBtn:SetPoint("RIGHT", -4, 0)

    local toggleArrow = toggleBtn:CreateTexture(nil, "ARTWORK")
    toggleArrow:SetSize(12, 12)
    toggleArrow:SetPoint("CENTER")
    toggleArrow:SetAtlas("bag-arrow")
    toggleArrow:SetVertexColor(1, 0.82, 0, 1)
    frame.toggleArrow = toggleArrow

    toggleBtn:SetScript("OnClick", function()
        if not addon.db then return end
        addon.db.settings.zoneOverlayMinimized = not addon.db.settings.zoneOverlayMinimized
        ZoneOverlay:RefreshLayout()
    end)

    -- Highlight for toggle button
    local toggleHighlight = toggleBtn:CreateTexture(nil, "HIGHLIGHT")
    toggleHighlight:SetAllPoints()
    toggleHighlight:SetColorTexture(1, 1, 1, 0.1)

    frame.toggleBtn = toggleBtn

    -- Content area (hidden when minimized)
    contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    contentFrame:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    frame.contentFrame = contentFrame

    -- WowScrollBoxList + MinimalScrollBar (same pattern as Grid.lua)
    local scrollBox = CreateFrame("Frame", nil, contentFrame, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 0, 0)
    scrollBox:SetPoint("BOTTOMRIGHT", -10, 0)

    local scrollBar = CreateFrame("EventFrame", nil, contentFrame, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", -1, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", -1, 0)

    local view = CreateScrollBoxListLinearView()

    -- Mixed heights: headers vs items
    view:SetElementExtentCalculator(function(dataIndex, elementData)
        return elementData.isHeader and HEADER_HEIGHT or ITEM_ROW_HEIGHT
    end)

    -- Single frame type, differentiated in initializer
    view:SetElementInitializer("Frame", function(row, elementData)
        if not row.initialized then
            row.initialized = true

            -- Header sub-elements: arrow + text
            local headerArrow = row:CreateTexture(nil, "ARTWORK")
            headerArrow:SetSize(10, 10)
            headerArrow:SetPoint("LEFT", PADDING, 0)
            headerArrow:SetAtlas("bag-arrow")
            headerArrow:SetVertexColor(0.7, 0.7, 0.7, 1)
            row.headerArrow = headerArrow

            local headerText = row:CreateFontString(nil, "OVERLAY")
            headerText:SetPoint("LEFT", headerArrow, "RIGHT", 4, 0)
            headerText:SetPoint("RIGHT", -PADDING, 0)
            headerText:SetJustifyH("LEFT")
            headerText:SetFont(addon:GetFontPath(), ITEM_FONT_SIZE, "")
            addon:RegisterFontStringWithSize(headerText, "GameFontNormal", ITEM_FONT_SIZE, "")
            headerText:SetTextColor(0.7, 0.7, 0.7, 1)
            row.headerText = headerText

            -- Item sub-elements
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(ICON_SIZE, ICON_SIZE)
            icon:SetPoint("LEFT", 4, 0)
            icon:SetTexCoord(unpack(addon.CONSTANTS.ICON_CROP_COORDS))
            row.icon = icon

            local name = row:CreateFontString(nil, "OVERLAY")
            name:SetPoint("LEFT", icon, "RIGHT", 4, 0)
            name:SetPoint("RIGHT", -4, 0)
            name:SetJustifyH("LEFT")
            name:SetWordWrap(false)
            name:SetFont(addon:GetFontPath(), ITEM_FONT_SIZE, "")
            addon:RegisterFontStringWithSize(name, "GameFontNormal", ITEM_FONT_SIZE, "")
            row.name = name

            local highlight = row:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(1, 1, 1, 0.08)
            row.highlight = highlight

            row:EnableMouse(true)

            -- Static unified handlers (branch on self.isHeader at runtime)
            row:SetScript("OnMouseUp", function(self, button)
                if self.isHeader then
                    if button == "LeftButton" and self.categoryKey then
                        expandedCategories[self.categoryKey] = not expandedCategories[self.categoryKey]
                        ZoneOverlay:RefreshLayout()
                    end
                else
                    if self.categoryKey ~= "vendors" or not self.sourceId then return end
                    if button == "LeftButton" then
                        PlaceVendorWaypoint(self.sourceId, self.sourceName)
                    elseif button == "RightButton" then
                        if InCombatLockdown() then
                            addon:Print(addon.L["COMBAT_LOCKDOWN_MESSAGE"])
                            return
                        end
                        addon.MainFrame:Show()
                        addon.Tabs:SelectTab("VENDORS")
                        addon.VendorsTab:NavigateToVendor(self.sourceId)
                    end
                end
            end)

            row:SetScript("OnEnter", function(self)
                if self.isHeader or not self.recordID then return end
                ShowPreview(self, self.recordID)
                GameTooltip:SetOwner(self, "ANCHOR_NONE")
                GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
                local L = addon.L
                if self.categoryKey == "vendors" and self.sourceName then
                    local locationLine = self.cityName
                        and string.format(L["ZONE_OVERLAY_SOURCE_VENDOR_CITY"], self.cityName)
                        or L["ZONE_OVERLAY_SOURCE_VENDOR"]
                    GameTooltip:SetText(self.sourceName, 0, 0.8, 0)
                    GameTooltip:AddLine(locationLine, 0.67, 0.67, 0.67)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L["ZONE_OVERLAY_CLICK_WAYPOINT"], 0.7, 0.7, 0.7)
                    GameTooltip:AddLine(L["ZONE_OVERLAY_CLICK_OPEN_HC"], 0.7, 0.7, 0.7)
                elseif self.sourceName then
                    GameTooltip:SetText("|cFFaaaaaa" .. self.sourceName .. "|r")
                end
                GameTooltip:Show()
            end)

            row:SetScript("OnLeave", function(self)
                if self.isHeader then return end
                HidePreview()
                GameTooltip:Hide()
            end)
        end

        if elementData.isHeader then
            row.headerArrow:Show()
            row.headerArrow:SetRotation(elementData.isExpanded and ARROW_EXPANDED or ARROW_COLLAPSED)
            row.headerText:SetText(elementData.label)
            row.headerText:Show()
            row.icon:Hide()
            row.name:Hide()
            row.isHeader = true
            row.categoryKey = elementData.categoryKey
        else
            row.headerArrow:Hide()
            row.headerText:Hide()
            row.icon:Show()
            row.name:Show()
            row.isHeader = false

            addon:SetIcon(row.icon, elementData.icon or FALLBACK_ICON, elementData.iconType)

            row.name:SetText(elementData.decorName or "")
            if elementData.isCollected then
                row.name:SetTextColor(0.5, 0.5, 0.5, 0.7)
            else
                row.name:SetTextColor(1, 1, 1, 1)
            end

            row.recordID = elementData.recordID
            row.decorName = elementData.decorName
            row.sourceName = elementData.sourceName
            row.sourceId = elementData.sourceId
            row.categoryKey = elementData.categoryKey
            row.isCollected = elementData.isCollected
            row.cityName = elementData.cityName
        end
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

    -- Hide scrollbar arrows and extend track to full height
    scrollBar:GetBackStepper():Hide()
    scrollBar:GetForwardStepper():Hide()
    local track = scrollBar:GetTrack()
    track:ClearAllPoints()
    track:SetPoint("TOP", 0, 0)
    track:SetPoint("BOTTOM", 0, 5)

    frame.scrollBox = scrollBox
    frame.scrollBar = scrollBar

    local dp = CreateDataProvider()
    scrollBox:SetDataProvider(dp)
    frame.dataProvider = dp

    ZoneOverlay:UpdatePosition()
    ZoneOverlay:UpdateAlpha()
end

--------------------------------------------------------------------------------
-- Layout refresh
--------------------------------------------------------------------------------
local function HideOverlay()
    frame:Hide()
    HidePreview()
end

function ZoneOverlay:RefreshLayout()
    if not frame or not addon.db then return end

    local db = addon.db
    local isMinimized = db.settings.zoneOverlayMinimized
    local L = addon.L

    -- Update position (may change per zone due to floor dropdowns)
    self:UpdatePosition()

    -- Get data for current zone
    local items = currentMapID and addon:GetZoneDecorItems(currentMapID)
    local uncollected, total = addon:GetZoneDecorProgress(currentMapID or 0)

    if not items or total == 0 then
        HideOverlay()
        return
    end

    -- Ensure frame is visible (may have been hidden by empty zone)
    if db.settings.showZoneOverlay and WorldMapFrame:IsShown() then
        frame:Show()
    end

    -- Compute display count (adds collected vendor items when toggle is ON)
    local displayCount = uncollected
    local includeCollected = db.settings.includeCollectedVendorDecor
    if includeCollected and items.vendors then
        for _, item in ipairs(items.vendors) do
            if item.isCollected then
                displayCount = displayCount + 1
            end
        end
    end

    if displayCount == 0 then
        HideOverlay()
        return
    end

    -- Update title
    frame.titleText:SetText(string.format(L["ZONE_OVERLAY_COUNT"], displayCount))

    -- Toggle arrow direction (flipped for bottom-right: up when collapsed, down when expanded)
    local isBottomRight = db.settings.zoneOverlayPosition == "bottomRight"
    if isBottomRight then
        frame.toggleArrow:SetRotation(isMinimized and ARROW_EXPANDED or ARROW_COLLAPSED)
    else
        frame.toggleArrow:SetRotation(isMinimized and ARROW_COLLAPSED or ARROW_EXPANDED)
    end

    -- Minimized state: compact title bar
    if isMinimized then
        contentFrame:Hide()
        frame.titleBar:SetHeight(COLLAPSED_HEIGHT)
        frame:SetSize(PANEL_WIDTH_MINIMIZED, COLLAPSED_HEIGHT)
        return
    end

    -- Restore title bar height for expanded state
    frame.titleBar:SetHeight(TITLE_BAR_HEIGHT)

    -- Reset category state on zone change
    if currentMapID ~= lastCategoryMapID then
        lastCategoryMapID = currentMapID
        wipe(expandedCategories)
    end

    -- Expanded state: build flat data list with category expand/collapse
    contentFrame:Show()

    -- Prepare sections: collect items per category
    local sections = {}
    local function PrepareSection(sourceItems, sectionLabel, categoryKey, includeCollectedItems)
        local displayItems = {}
        local uncollectedCount = 0
        local uncollectedSources = {}  -- unique sourceIds with uncollected items
        for _, item in ipairs(sourceItems) do
            if not item.isCollected then
                uncollectedCount = uncollectedCount + 1
                if item.sourceId then
                    uncollectedSources[item.sourceId] = true
                end
                table.insert(displayItems, item)
            elseif includeCollectedItems then
                table.insert(displayItems, item)
            end
        end
        if #displayItems == 0 then return end

        -- Count unique sources with uncollected items
        local sourceCount = 0
        for _ in pairs(uncollectedSources) do sourceCount = sourceCount + 1 end

        table.insert(sections, {
            label = sectionLabel,
            categoryKey = categoryKey,
            items = displayItems,
            uncollectedCount = uncollectedCount,
            uncollectedSourceCount = sourceCount,
        })
    end

    PrepareSection(items.vendors, L["ZONE_OVERLAY_VENDORS"], "vendors", includeCollected)
    PrepareSection(items.quests, L["ZONE_OVERLAY_QUESTS"], "quests", false)
    PrepareSection(items.treasures, L["ZONE_OVERLAY_TREASURE"], "treasures", false)

    -- Auto-expand single-category zones; multi-category zones start collapsed
    if not next(expandedCategories) and #sections == 1 then
        expandedCategories[sections[1].categoryKey] = true
    end

    -- Build flatData with header + conditional item rows
    local flatData = {}
    for _, section in ipairs(sections) do
        local isExpanded = expandedCategories[section.categoryKey] or false
        -- Vendors: "x vendors" (vendor count); others: "Label (xx)" (item count)
        local headerLabel
        if section.categoryKey == "vendors" then
            headerLabel = section.uncollectedSourceCount .. " " .. section.label
        else
            headerLabel = section.label .. " (" .. section.uncollectedCount .. ")"
        end
        table.insert(flatData, {
            isHeader = true,
            label = headerLabel,
            categoryKey = section.categoryKey,
            isExpanded = isExpanded,
        })

        if isExpanded then
            for _, item in ipairs(section.items) do
                local record = addon:GetRecord(item.recordID)
                table.insert(flatData, {
                    recordID = item.recordID,
                    decorName = item.decorName,
                    sourceName = item.sourceName,
                    sourceId = item.sourceId,
                    categoryKey = section.categoryKey,
                    icon = record and record.icon or FALLBACK_ICON,
                    iconType = record and record.iconType,
                    isCollected = item.isCollected,
                    cityName = item.cityName,
                })
            end
        end
    end

    -- Calculate visible content height, capped at MAX_VISIBLE_ENTRIES rows
    local visibleHeight = 0
    for i, entry in ipairs(flatData) do
        if i > MAX_VISIBLE_ENTRIES then break end
        visibleHeight = visibleHeight + (entry.isHeader and HEADER_HEIGHT or ITEM_ROW_HEIGHT)
    end

    contentFrame:SetHeight(math.max(visibleHeight + 8, 1))
    frame:SetSize(PANEL_WIDTH, TITLE_BAR_HEIGHT + visibleHeight + 8)

    -- Hide scrollbar when all entries fit without scrolling
    if #flatData <= MAX_VISIBLE_ENTRIES then
        frame.scrollBar:Hide()
    else
        frame.scrollBar:Show()
    end

    -- Update data provider (triggers scroll box refresh)
    frame.dataProvider:Flush()
    frame.dataProvider:InsertTable(flatData)
end

--------------------------------------------------------------------------------
-- Position and appearance
--------------------------------------------------------------------------------
function ZoneOverlay:UpdatePosition()
    if not frame or not addon.db then return end

    frame:ClearAllPoints()
    local pos = addon.db.settings.zoneOverlayPosition
    if pos == "bottomRight" then
        frame:SetPoint("BOTTOMRIGHT", WorldMapFrame.ScrollContainer, "BOTTOMRIGHT", -35, 5)
    else
        -- Shift down if current map has a floor dropdown (multi-level maps like Dalaran)
        local groupID = currentMapID and C_Map.GetMapGroupID(currentMapID)
        local yOffset = groupID and -31 or -6
        frame:SetPoint("TOPLEFT", WorldMapFrame.ScrollContainer, "TOPLEFT", 7, yOffset)
    end
end

function ZoneOverlay:UpdateAlpha()
    if not frame or not addon.db then return end

    local alpha = (addon.db.settings.zoneOverlayAlpha or 0.9) * BACKDROP_ALPHA_FACTOR
    frame:SetBackdropColor(0.08, 0.08, 0.1, alpha)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, alpha)
end

function ZoneOverlay:UpdatePreviewSize()
    if not previewFrame then return end
    local size = GetPreviewSize()
    previewFrame:SetSize(size + 8, size + 8)
    previewFrame.icon:SetSize(size - 16, size - 16)
end

-- No combat guard needed: overlay is a child of WorldMapFrame.ScrollContainer (not a top-level frame)
function ZoneOverlay:UpdateVisibility()
    if not frame or not addon.db then return end

    if addon.db.settings.showZoneOverlay and WorldMapFrame:IsShown() then
        frame:Show()
        self:RefreshLayout()
    else
        HideOverlay()
    end
end

--------------------------------------------------------------------------------
-- Zone change handling (debounced)
--------------------------------------------------------------------------------
function ZoneOverlay:ScheduleUpdate(mapID)
    -- Collapse on zone change
    if mapID ~= currentMapID and addon.db then
        addon.db.settings.zoneOverlayMinimized = true
    end
    currentMapID = mapID

    -- Skip data work when overlay is disabled (after mapID update for re-enable correctness)
    if not addon.db or not addon.db.settings.showZoneOverlay then
        if updateTimer then
            updateTimer:Cancel()
            updateTimer = nil
        end
        return
    end

    if updateTimer then
        updateTimer:Cancel()
    end

    updateTimer = C_Timer.NewTimer(0.05, function()
        updateTimer = nil
        self:RefreshLayout()
    end)
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------
local initialized = false
local waitingForWorldMap = false

local function InitializeOverlay()
    if initialized then return end
    initialized = true

    CreateOverlayFrame()

    -- Hook zone changes
    hooksecurefunc(WorldMapFrame, "OnMapChanged", ScheduleMapUpdate)

    -- Show/hide with world map
    WorldMapFrame:HookScript("OnShow", function()
        if addon.db and addon.db.settings.showZoneOverlay then
            addon.db.settings.zoneOverlayMinimized = true
            frame:Show()
            ScheduleMapUpdate()
        end
    end)

    WorldMapFrame:HookScript("OnHide", function()
        HideOverlay()
    end)

    -- Refresh on ownership changes (debounced to coalesce rapid updates)
    addon:RegisterInternalEvent("ZONE_DECOR_CACHE_INVALIDATED", function()
        if not frame or not frame:IsShown() then return end
        if ownershipTimer then ownershipTimer:Cancel() end
        ownershipTimer = C_Timer.NewTimer(0.05, function()
            ownershipTimer = nil
            ZoneOverlay:RefreshLayout()
        end)
    end)

    -- Initial state (always start collapsed)
    if WorldMapFrame:IsShown() and addon.db and addon.db.settings.showZoneOverlay then
        addon.db.settings.zoneOverlayMinimized = true
        frame:Show()
        ScheduleMapUpdate()
    else
        frame:Hide()
    end

    addon:Debug("Zone overlay initialized")
end

-- Deferred init: wait for DATA_LOADED + WorldMapFrame availability
addon:RegisterInternalEvent("DATA_LOADED", function()
    if initialized then return end

    if WorldMapFrame and WorldMapFrame.ScrollContainer then
        InitializeOverlay()
    elseif not waitingForWorldMap then
        waitingForWorldMap = true
        local function onAddonLoaded(loadedAddon)
            if loadedAddon == "Blizzard_WorldMap" then
                waitingForWorldMap = false
                InitializeOverlay()
                addon:UnregisterWoWEvent("ADDON_LOADED", onAddonLoaded)
            end
        end
        addon:RegisterWoWEvent("ADDON_LOADED", onAddonLoaded)
    end
end)
