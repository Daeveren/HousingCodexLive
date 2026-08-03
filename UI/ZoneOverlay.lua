--[[
    Housing Codex - ZoneOverlay.lua
    World map overlay panel showing uncollected decor items for the current zone
    The panel and its hover preview are both WorldMapFrame children, so they render
    inside the map's framebuffer and composite with the map; other UI panels draw over
    them without intervention. The preview is a sibling of the panel, not a child, so
    the panel's SetClipsChildren does not crop it.
]]

local _, addon = ...

addon.ZoneOverlay = {}

local ZoneOverlay = addon.ZoneOverlay

local function GetMapTooltip()
    return HousingCodexMapTooltip
end

-- Tooltip color objects
local COLOR_VENDOR_NAME = CreateColor(0, 0.8, 0, 1)
local COLOR_DIM = CreateColor(0.67, 0.67, 0.67, 1)
local COLOR_GOLD = CreateColor(1, 0.82, 0, 1)

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

-- Map pins start at 2000 and the top band ends at 2748 + C_QuestLog.GetMaxNumQuests(),
-- because PIN_FRAME_LEVEL_ACTIVE_QUEST sizes itself from that runtime quest cap
-- (Blizzard_WorldMap.lua, AddStandardDataProviders). Only used when the live pin-level
-- query is unavailable, so keep wide headroom against a future cap increase rather than
-- hugging today's total; the pin manager itself refuses to allocate past 9000.
local OVERLAY_FRAME_LEVEL_FALLBACK = 5000

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function IsFrameShown(targetFrame)
    if not targetFrame then return false end
    local shown = targetFrame:IsShown()
    return not IsSecretValue(shown) and shown
end

-- The panel is a WorldMapFrame child and inherits the map's scale directly, so fixed layout
-- values are plain numbers and this is only a rounding clamp for the two genuinely
-- fractional inputs: the expand/collapse tween and the user preview-scale setting.
-- Re-applying a map/UIParent scale ratio here would square the map's scale on top of the
-- inherited one.
local function RoundMin(value, minimum)
    return math.max(minimum or 1, math.floor((value or 0) + 0.5))
end

-- One level above the topmost pin band, which places the panel over every map pin within
-- the map's own strata. What keeps it *below* the map border and quest panel is strata,
-- not this level: both are explicitly HIGH while we inherit the map's. GetValidFrameLevel
-- clamps the index to the band's range, so math.huge resolves to that band's top level.
--
-- Re-read rather than cached: MapCanvasPinFrameLevelsManagerMixin:AddDefinition shifts
-- existing bands upward when a new one is registered, so a data provider that appears
-- after our init would otherwise end up above a one-shot level.
local function GetOverlayFrameLevel()
    if type(WorldMapFrame.GetPinFrameLevelsManager) ~= "function" then
        return OVERLAY_FRAME_LEVEL_FALLBACK
    end

    local manager = WorldMapFrame:GetPinFrameLevelsManager()
    if not manager or type(manager.GetValidFrameLevel) ~= "function" then
        return OVERLAY_FRAME_LEVEL_FALLBACK
    end

    local topPinLevel = manager:GetValidFrameLevel("PIN_FRAME_LEVEL_TOPMOST", math.huge)
    if type(topPinLevel) ~= "number" or IsSecretValue(topPinLevel) then
        return OVERLAY_FRAME_LEVEL_FALLBACK
    end

    return topPinLevel + 1
end

-- Model scene constants (same as tile display)
local MODEL_SCENE_ID = addon.CONSTANTS.MODEL_SCENE_ID

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

-- Animation constants
local ANIM_EXPAND_DURATION = 0.25
local ANIM_COLLAPSE_DURATION = 0.20

-- Animation state (all tracked locally — never read from frame, secret value risk)
local animDriver = nil
local animating = false
local animTargetW, animTargetH, animTargetTBH, animTargetCA, animTargetAA = 0, 0, 0, 0, 0
-- Current tracked values (written forward to frame, never read back)
local curWidth = PANEL_WIDTH_MINIMIZED
local curHeight = COLLAPSED_HEIGHT
local curTitleBarHeight = COLLAPSED_HEIGHT
local curContentAlpha = 0
local curArrowAngle = ARROW_COLLAPSED
-- Minimize state tracking (nil = first render, true/false = last known state)
local lastMinimizedState = nil
local pendingShowScrollBar = false
local CancelAnimation  -- forward declaration (called in OnHide, defined in Animation section)

-- Helper: get preview size based on scale setting
local function GetPreviewSize()
    local scale = addon.db and addon.db.settings.zoneOverlayPreviewScale or 1.0
    return RoundMin(PREVIEW_SIZE * scale)
end

local function GetPreviewIconSize(size)
    return RoundMin(size - 16)
end

-- Helper: place a map pin for a vendor NPC
local function PlaceVendorWaypoint(npcId, npcName)
    local L = addon.L
    npcName = addon:GetLocalizedNPCName(npcId, npcName)
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
    -- A WorldMapFrame child, like the panel, so the popout composites with the map and
    -- other UI panels draw over it. A sibling of the panel rather than a child: the panel
    -- sets SetClipsChildren(true) for its expand animation, which would crop the popout.
    -- Nothing clips it here — BlackoutFrame is a WorldMapFrame child anchored to the full
    -- UIParent and renders unclipped, so the buffer sizes to subtree bounds, not the map rect.
    -- DIALOG, not TOOLTIP: it must clear the panel and the map's HIGH BorderFrame, and no
    -- Blizzard TOOLTIP-strata descendant of WorldMapFrame exists to model that on.
    -- Blizzard precedent for the ModelScene: WorldMapThreatFrameTemplate is registered via
    -- AddOverlayFrame (parent = WorldMapFrame) and holds two ModelScenes on this same
    -- NonInteractableModelSceneMixinTemplate.
    previewFrame = CreateFrame("Frame", nil, WorldMapFrame, "BackdropTemplate")
    previewFrame:SetFrameStrata("DIALOG")
    previewFrame:SetSize(size + 8, size + 8)
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
    local iconSize = GetPreviewIconSize(size)
    icon:SetSize(iconSize, iconSize)
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
    local iconSize = GetPreviewIconSize(size)
    previewFrame.icon:SetSize(iconSize, iconSize)

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
            previewModelScene:TransitionToModelSceneID(MODEL_SCENE_ID,
                addon.CONSTANTS.CAMERA.TRANSITION_IMMEDIATE,
                addon.CONSTANTS.CAMERA.MODIFICATION_MAINTAIN, true)

            -- Auto-rotate via child driver frame (avoids taint on ModelScene OnUpdate)
            local rotationDriver = CreateFrame("Frame", nil, previewModelScene)
            previewModelScene.rotationDriver = rotationDriver
            rotationDriver:SetScript("OnUpdate", function(self, elapsed)
                local actor = self.actor
                if actor then
                    local yaw = actor:GetYaw() or 0
                    actor:SetYaw(yaw + elapsed * ROTATION_SPEED)
                end
            end)
        end
        previewModelScene:ClearAllPoints()
        previewModelScene:SetPoint("TOPLEFT", 4, -4)
        previewModelScene:SetPoint("BOTTOMRIGHT", -4, 4)

        local actor = previewModelScene:GetActorByTag("decor") or previewModelScene:GetActorByTag("item")
        if actor then
            previewModelScene.rotationDriver.actor = actor
            actor:SetPreferModelCollisionBounds(true)
            actor:SetModelByFileID(record.modelAsset)
            actor:SetYaw(0)
            previewModelScene:Show()
            previewFrame.icon:Hide()
            previewFrame:Show()
            return
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
local function ApplyStaticLayout()
    if not frame then return end

    if frame.titleBar then
        frame.titleBar:SetHeight(TITLE_BAR_HEIGHT)
    end
    if frame.titleIcon then
        frame.titleIcon:SetSize(16, 16)
        frame.titleIcon:ClearAllPoints()
        frame.titleIcon:SetPoint("LEFT", 8, 0)
    end
    if frame.titleText then
        frame.titleText:ClearAllPoints()
        frame.titleText:SetPoint("LEFT", frame.titleIcon, "RIGHT", 6, 0)
        frame.titleText:SetPoint("RIGHT", -28, 0)
        addon:SetFontSize(frame.titleText, TITLE_FONT_SIZE, "")
    end
    if frame.toggleBtn then
        frame.toggleBtn:SetSize(20, 20)
        frame.toggleBtn:ClearAllPoints()
        frame.toggleBtn:SetPoint("RIGHT", -4, 0)
    end
    if frame.toggleArrow then
        frame.toggleArrow:SetSize(12, 12)
        frame.toggleArrow:ClearAllPoints()
        frame.toggleArrow:SetPoint("CENTER")
    end
    if frame.scrollBox then
        frame.scrollBox:ClearAllPoints()
        frame.scrollBox:SetPoint("TOPLEFT", 0, 0)
        frame.scrollBox:SetPoint("BOTTOMRIGHT", -10, 0)
    end
    if frame.scrollBar and frame.scrollBox then
        frame.scrollBar:ClearAllPoints()
        frame.scrollBar:SetPoint("TOPLEFT", frame.scrollBox, "TOPRIGHT", -1, 0)
        frame.scrollBar:SetPoint("BOTTOMLEFT", frame.scrollBox, "BOTTOMRIGHT", -1, 0)
        local track = frame.scrollBar:GetTrack()
        track:ClearAllPoints()
        track:SetPoint("TOP", 0, 0)
        track:SetPoint("BOTTOM", 0, 5)
    end
end

local function ApplyRowLayout(row)
    row.headerArrow:SetSize(10, 10)
    row.headerArrow:ClearAllPoints()
    row.headerArrow:SetPoint("LEFT", PADDING, 0)

    row.headerText:ClearAllPoints()
    row.headerText:SetPoint("LEFT", row.headerArrow, "RIGHT", 4, 0)
    row.headerText:SetPoint("RIGHT", -PADDING, 0)
    addon:SetFontSize(row.headerText, ITEM_FONT_SIZE, "")

    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", 4, 0)

    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetPoint("RIGHT", -4, 0)
    addon:SetFontSize(row.name, ITEM_FONT_SIZE, "")
end

local function CreateOverlayFrame()
    if frame then return end

    -- Parent to WorldMapFrame at creation only (SetParent is protected, never reparent
    -- later) so the panel renders inside the map's framebuffer. Deliberately no strata:
    -- the map re-applies a game-rule strata to itself on every OnShow, and an inherited
    -- strata follows it, where a pinned one would break out of the map's ordering.
    -- No SetClampedToScreen either: UpdatePosition single-point anchors the panel inside
    -- ScrollContainer and ApplyLayout sizes it explicitly, so it cannot leave the map
    -- canvas; screen clamping could only fight that anchor.
    frame = CreateFrame("Frame", "HousingCodexZoneOverlayFrame", WorldMapFrame, "BackdropTemplate")
    frame:SetFrameLevel(GetOverlayFrameLevel())
    frame:SetClipsChildren(true)
    frame:EnableMouse(false)  -- let clicks pass through to the map; titleBar and rows handle their own mouse
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

    titleBar:SetScript("OnEnter", function(self)
        if not addon.db or not addon.db.settings.zoneOverlayMinimized then return end
        local tooltip = GetMapTooltip()
        tooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
        GameTooltip_SetTitle(tooltip, addon.L["ZONE_OVERLAY_BUTTON_TOOLTIP"], COLOR_GOLD)
        GameTooltip_AddNormalLine(tooltip, addon.L["ZONE_OVERLAY_COLLAPSED_TOOLTIP"])
        tooltip:Show()
        addon:StyleMapTooltip(tooltip)
    end)

    titleBar:SetScript("OnLeave", function()
        local tooltip = GetMapTooltip()
        if tooltip:GetOwner() == titleBar then
            tooltip:Hide()
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
                local tooltip = GetMapTooltip()
                tooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
                local L = addon.L
                if self.categoryKey == "vendors" and self.sourceName then
                    local locationLine = self.cityName
                        and string.format(L["ZONE_OVERLAY_SOURCE_VENDOR_CITY"], self.cityName)
                        or L["ZONE_OVERLAY_SOURCE_VENDOR"]
                    GameTooltip_SetTitle(tooltip, addon:GetLocalizedNPCName(self.sourceId, self.sourceName), COLOR_VENDOR_NAME)
                    GameTooltip_AddColoredLine(tooltip, locationLine, COLOR_DIM)
                    GameTooltip_AddBlankLineToTooltip(tooltip)
                    GameTooltip_AddInstructionLine(tooltip, L["ZONE_OVERLAY_CLICK_WAYPOINT"])
                    GameTooltip_AddInstructionLine(tooltip, L["ZONE_OVERLAY_CLICK_OPEN_HC"])
                elseif self.sourceName then
                    GameTooltip_SetTitle(tooltip, self.sourceName, COLOR_DIM)
                end
                tooltip:Show()
                addon:StyleMapTooltip(tooltip)
            end)

            row:SetScript("OnLeave", function(self)
                if self.isHeader then return end
                HidePreview()
                local tooltip = GetMapTooltip()
                if tooltip:GetOwner() == self then
                    tooltip:Hide()
                end
            end)
        end
        ApplyRowLayout(row)

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

    -- Fires on every hide: empty zone, setting toggled off, and WorldMapFrame hiding this
    -- frame as its parent. Drops the preview, stops any animation, and forgets the minimize
    -- state so the next show renders instantly — keeping that state would let a flip that
    -- happened while hidden animate from stale geometry.
    frame:SetScript("OnHide", function()
        HidePreview()
        CancelAnimation()
        lastMinimizedState = nil
    end)

    -- CreateFrame returns a shown frame. Nothing is laid out yet, so start hidden rather
    -- than leaving IsFrameShown(frame) true until the deferred UpdateVisibility runs.
    frame:Hide()

    ApplyStaticLayout()
    ZoneOverlay:UpdatePosition()
    ZoneOverlay:UpdateAlpha()
end

--------------------------------------------------------------------------------
-- Animation helpers
--------------------------------------------------------------------------------
local function EaseOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

-- Write all animated properties forward (never reads from frame)
local function ApplyLayout(w, h, tbh, ca, aa)
    curWidth, curHeight, curTitleBarHeight, curContentAlpha, curArrowAngle = w, h, tbh, ca, aa
    frame:SetSize(RoundMin(w), RoundMin(h))
    frame.titleBar:SetHeight(RoundMin(tbh))
    frame.toggleArrow:SetRotation(aa)
    contentFrame:SetAlpha(ca)
end

-- Cancel animation without snapping (used on frame hide)
CancelAnimation = function()
    if not animating then return end
    animating = false
    if animDriver then animDriver:SetScript("OnUpdate", nil) end
end

-- Stop animation and snap to target (used when data refresh during animation)
local function StopAnimation()
    if not animating then return end
    CancelAnimation()
    ApplyLayout(animTargetW, animTargetH, animTargetTBH, animTargetCA, animTargetAA)
    if animTargetCA == 0 then
        contentFrame:Hide()
    end
    if pendingShowScrollBar then
        frame.scrollBar:Show()
    end
    frame.scrollBox:FullUpdate(ScrollBoxConstants.UpdateQueued)
end

local function StartAnimation(targetW, targetH, targetTBH, targetCA, targetAA, expanding)
    -- Capture current tracked values as start (NOT from frame — secret value risk)
    local startW, startH, startTBH = curWidth, curHeight, curTitleBarHeight
    local startCA, startAA = curContentAlpha, curArrowAngle
    animTargetW, animTargetH, animTargetTBH = targetW, targetH, targetTBH
    animTargetCA, animTargetAA = targetCA, targetAA
    local duration = expanding and ANIM_EXPAND_DURATION or ANIM_COLLAPSE_DURATION
    local elapsed = 0
    animating = true

    -- Expand: show content at alpha 0 so it fades in
    if expanding then
        contentFrame:SetAlpha(0)
        contentFrame:Show()
    end

    -- Hide scrollbar during animation (prevents layout fights with changing dimensions)
    frame.scrollBar:Hide()

    -- Lazy-create driver frame (same pattern as EndeavorsPanel)
    if not animDriver then
        animDriver = CreateFrame("Frame", nil, frame)
    end

    animDriver:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = math.min(elapsed / duration, 1)
        local e = EaseOutQuad(t)

        ApplyLayout(
            Lerp(startW, animTargetW, e),
            Lerp(startH, animTargetH, e),
            Lerp(startTBH, animTargetTBH, e),
            Lerp(startCA, animTargetCA, e),
            Lerp(startAA, animTargetAA, e)
        )

        if t >= 1 then
            self:SetScript("OnUpdate", nil)
            animating = false
            -- Collapse complete: hide content
            if animTargetCA == 0 then
                contentFrame:Hide()
            end
            -- Restore scrollbar if needed
            if pendingShowScrollBar then
                frame.scrollBar:Show()
            end
            frame.scrollBox:FullUpdate(ScrollBoxConstants.UpdateQueued)
        end
    end)
end

--------------------------------------------------------------------------------
-- Layout refresh
--------------------------------------------------------------------------------
-- OnHide carries the minimize-state reset so a parent-driven hide (WorldMapFrame closing)
-- is covered too. Reset here as well rather than relying on it: Hide() on an already-hidden
-- frame does not fire OnHide, and a refresh that ran while hidden can have repopulated the
-- state in between. Both paths are idempotent.
local function HideOverlay()
    if not frame then return end
    frame:Hide()
    lastMinimizedState = nil
end

function ZoneOverlay:RefreshLayout()
    if not frame or not addon.db then return end

    local db = addon.db
    local isMinimized = db.settings.zoneOverlayMinimized
    local L = addon.L

    -- Update position (may change per zone due to floor dropdowns)
    self:UpdatePosition()

    -- If animating and minimize state hasn't changed, stop animation and snap
    -- (data refresh from ownership/cache update — let the instant layout proceed cleanly)
    if animating and isMinimized == lastMinimizedState then
        StopAnimation()
    end

    -- Get data for current zone
    if not currentMapID then
        HideOverlay()
        return
    end
    local items = addon:GetZoneDecorItems(currentMapID)
    local uncollected, total = addon:GetZoneDecorProgress(currentMapID)

    if not items or total == 0 then
        HideOverlay()
        return
    end

    -- Ensure frame is visible (may have been hidden by empty zone). No combat guard: the
    -- panel is map content rather than a standalone window, and everything here acts on
    -- addon-owned unprotected frames. See UpdateVisibility for the full rationale.
    if db.settings.showZoneOverlay and IsFrameShown(WorldMapFrame) then
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

    local isBottomRight = db.settings.zoneOverlayPosition == "bottomRight"

    -- Minimized state: compact title bar
    if isMinimized then
        local targetArrow = isBottomRight and ARROW_EXPANDED or ARROW_COLLAPSED
        pendingShowScrollBar = false
        if lastMinimizedState == false and IsFrameShown(frame) then
            -- Transition from expanded → minimized: animate
            StartAnimation(PANEL_WIDTH_MINIMIZED, COLLAPSED_HEIGHT, COLLAPSED_HEIGHT, 0, targetArrow, false)
        else
            -- First render, frame hidden, or already minimized: instant
            contentFrame:Hide()
            ApplyLayout(PANEL_WIDTH_MINIMIZED, COLLAPSED_HEIGHT, COLLAPSED_HEIGHT, 0, targetArrow)
        end
        lastMinimizedState = true
        return
    end

    -- Reset category state on zone change
    if currentMapID ~= lastCategoryMapID then
        lastCategoryMapID = currentMapID
        wipe(expandedCategories)
    end

    -- Expanded state: build flat data list with category expand/collapse

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

    local targetH = TITLE_BAR_HEIGHT + visibleHeight + PADDING
    local showScrollBar = #flatData > MAX_VISIBLE_ENTRIES
    pendingShowScrollBar = showScrollBar

    -- Set content height and populate data before animation
    -- (content renders at target size, clipped by parent during expand)
    contentFrame:SetHeight(visibleHeight + PADDING)
    frame.dataProvider:Flush()
    frame.dataProvider:InsertTable(flatData)

    local targetArrow = isBottomRight and ARROW_COLLAPSED or ARROW_EXPANDED
    if lastMinimizedState == true and IsFrameShown(frame) then
        -- Transition from minimized → expanded: animate
        StartAnimation(PANEL_WIDTH, targetH, TITLE_BAR_HEIGHT, 1, targetArrow, true)
    else
        -- First render, content refresh, or category toggle: instant
        contentFrame:Show()
        ApplyLayout(PANEL_WIDTH, targetH, TITLE_BAR_HEIGHT, 1, targetArrow)
        if showScrollBar then frame.scrollBar:Show() else frame.scrollBar:Hide() end
        frame.scrollBox:FullUpdate(ScrollBoxConstants.UpdateQueued)
    end
    lastMinimizedState = false
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
    local iconSize = GetPreviewIconSize(size)
    previewFrame.icon:SetSize(iconSize, iconSize)
end

-- Deliberately no combat guard. The project suppresses its standalone *windows* mid-combat,
-- but this panel is map content: the map itself opens in combat, so blanking part of it only
-- removes information. Verified in game (2026-08-04) — the frame is unprotected (no secure
-- template or attribute, EnableMouse(false)), so showing, expanding and hovering all work
-- under lockdown with no ADDON_ACTION_BLOCKED. The guard's only observable effect was that
-- reopening the map mid-combat left the panel hidden until PLAYER_REGEN_ENABLED, while a
-- panel already open stayed fully interactive — same state, different outcome.
--
-- The PLAYER_REGEN_ENABLED handler in InitializeOverlay stays as a self-heal: if this frame
-- ever gains a secure template and Show() becomes genuinely blockable, it recovers instead
-- of staying stuck.
function ZoneOverlay:UpdateVisibility()
    if not frame or not addon.db then return end

    if addon.db.settings.showZoneOverlay and IsFrameShown(WorldMapFrame) then
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

    -- No panel-occlusion tracking is needed: as a WorldMapFrame child the panel renders
    -- inside the map's framebuffer, so CharacterFrame, AchievementFrame and other panels
    -- draw over it on their own.

    -- Refresh data when the map shows. The panel itself follows its parent's visibility;
    -- this restores it after an explicit hide (empty zone, setting off, combat guard).
    hooksecurefunc(WorldMapFrame, "Show", function()
        C_Timer.After(0, function()
            -- Re-assert the level each open: a data provider registering after our init
            -- shifts the pin bands upward, which would leave a level captured at creation
            -- underneath them.
            if frame then
                frame:SetFrameLevel(GetOverlayFrameLevel())
            end
            if addon.db and addon.db.settings.showZoneOverlay and IsFrameShown(WorldMapFrame) then
                ScheduleMapUpdate()
            end
            ZoneOverlay:UpdateVisibility()
        end)
    end)

    -- The parent hide already blanks both surfaces, but IsShown() stays true for a child
    -- hidden via its parent, and IsFrameShown(frame) guards elsewhere key off it. Hide
    -- both explicitly so those guards stay meaningful.
    hooksecurefunc(WorldMapFrame, "Hide", function()
        C_Timer.After(0, function()
            HidePreview()
            HideOverlay()
        end)
    end)

    -- Refresh on ownership changes (debounced to coalesce rapid updates)
    addon:RegisterInternalEvent("ZONE_DECOR_CACHE_INVALIDATED", function()
        -- Test the map too, not just our own shown flag. A child hidden through its parent
        -- keeps IsShown() true, and the map's Hide hook that resyncs the flag is one frame
        -- late and never runs at all when the map goes away without Hide() being called
        -- (UIParent:Hide() during cinematics or pet battles).
        if not IsFrameShown(frame) or not IsFrameShown(WorldMapFrame) then return end
        if ownershipTimer then ownershipTimer:Cancel() end
        ownershipTimer = C_Timer.NewTimer(0.05, function()
            ownershipTimer = nil
            ZoneOverlay:RefreshLayout()
        end)
    end)

    -- Recover after combat ends (combat guards may have blocked Show/RefreshLayout)
    addon:RegisterWoWEvent("PLAYER_REGEN_ENABLED", function()
        ZoneOverlay:UpdateVisibility()
    end)

    -- Initial state (deferred to clean execution context)
    C_Timer.After(0, function()
        if addon.db and addon.db.settings.showZoneOverlay and IsFrameShown(WorldMapFrame) then
            ScheduleMapUpdate()
        end
        ZoneOverlay:UpdateVisibility()
    end)

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
