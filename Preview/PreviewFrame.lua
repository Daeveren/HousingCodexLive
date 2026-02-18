--[[
    Housing Codex - PreviewFrame.lua
    Docked 3D preview panel (right side of MainFrame)
]]

local ADDON_NAME, addon = ...

-- Add preview constants to central CONSTANTS table
addon.CONSTANTS.PREVIEW_DEFAULT_WIDTH = 500  -- Fixed docked width

local COLORS = addon.CONSTANTS.COLORS

-- Details panel constants (1C.6)
local DETAILS_MIN_HEIGHT = 60   -- Minimum height when empty/placeholder
local PADDING = 8
local SPACING_SMALL = 2
local METADATA_GAP = 4          -- Extra spacing before metadata row
local DIVIDER_OFFSET = 1        -- Inset from left edge to clear MainFrame divider

-- Camera constants (from centralized CONSTANTS)
local CONSTS = addon.CONSTANTS
local CAMERA_IMMEDIATE = CONSTS.CAMERA.TRANSITION_IMMEDIATE
local CAMERA_DISCARD = CONSTS.CAMERA.MODIFICATION_DISCARD
local ORBIT_MOUSE_YAW = CONSTS.CAMERA.ORBIT_MOUSE_YAW
local ORBIT_MOUSE_PITCH = CONSTS.CAMERA.ORBIT_MOUSE_PITCH
local ORBIT_MOUSE_ZOOM = CONSTS.CAMERA.ORBIT_MOUSE_ZOOM
local ORBIT_MOUSE_PAN_HORIZONTAL = CONSTS.CAMERA.ORBIT_MOUSE_PAN_HORIZONTAL
local ORBIT_MOUSE_PAN_VERTICAL = CONSTS.CAMERA.ORBIT_MOUSE_PAN_VERTICAL
local PREVIEW_MIN_ZOOM_SCALE = CONSTS.CAMERA.PREVIEW_MIN_ZOOM_SCALE or 0.5
local ROTATION_SPEED = CONSTS.CAMERA.ROTATION_SPEED
local SCENE_PRESETS = CONSTS.SCENE_PRESETS
local DEFAULT_SCENE_ID = CONSTS.DEFAULT_SCENE_ID

-- Width preset buttons (widths only, labels generated from index)
local WIDTH_PRESETS = { 300, 500, 700 }

-- Preset button colors
local COLOR_PRESET_INACTIVE = { 0.5, 0.5, 0.5, 0.8 }
local COLOR_PRESET_HOVER = { 0.8, 0.8, 0.8, 1 }
local COLOR_PRESET_ACTIVE = { 0.9, 0.75, 0.3, 1 }  -- Gold

-- Zoom constant: 2% per wheel notch (50 steps for full range)
local ZOOM_STEP = 0.02

-- Category text color (light purple)
local COLOR_CATEGORY = { 0.75, 0.65, 0.9 }

addon.Preview = {}
local Preview = addon.Preview

-- Helper: Set texture icon (handles atlas vs texture path)
local function SetIcon(texture, icon, iconType)
    if iconType == "atlas" then
        texture:SetAtlas(icon)
    else
        texture:SetTexture(icon)
    end
end


-- Helper: Format category path as "Category > Subcategory"
function Preview:FormatCategoryPath(record)
    local categoryID = record.categoryIDs and record.categoryIDs[1]
    local catInfo = categoryID and addon:GetCategoryInfo(categoryID)
    if not catInfo or not catInfo.name then return "" end

    local subcategoryID = record.subcategoryIDs and record.subcategoryIDs[1]
    local subInfo = subcategoryID and addon:GetSubcategoryInfo(subcategoryID)
    if not subInfo or not subInfo.name then return catInfo.name end

    return catInfo.name .. " > " .. subInfo.name
end

function Preview:Create()
    if self.frame then return self.frame end

    -- Use MainFrame's preview region instead of creating separate frame
    local region = addon.MainFrame and addon.MainFrame.previewRegion
    if not region then
        addon:Debug("PreviewFrame: MainFrame.previewRegion not ready")
        return nil
    end

    self.frame = region  -- Reuse region for API compatibility

    -- Create content directly in region (no backdrop needed - inherits main window)
    self:CreateContentArea()

    addon:Debug("PreviewFrame created (integrated)")
    return region
end

function Preview:CreateContentArea()
    local region = self.frame

    -- Details area (top portion, dynamic height) - no background, inherits main frame
    local details = CreateFrame("Frame", nil, region)
    details:SetPoint("TOPLEFT", region, "TOPLEFT", DIVIDER_OFFSET, 0)
    details:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0)
    details:SetHeight(DETAILS_MIN_HEIGHT)  -- Initial minimum, recalculated on content update
    self.detailsArea = details

    -- Create identity block in details area (item name is first row)
    self:CreateIdentityBlock()

    -- Separator between details and model
    local separator = region:CreateTexture(nil, "ARTWORK")
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", details, "BOTTOMLEFT", 0, 0)
    separator:SetPoint("TOPRIGHT", details, "BOTTOMRIGHT", 0, 0)
    separator:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- Model area (below details, fills remaining space)
    local modelArea = CreateFrame("Frame", nil, region)
    modelArea:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 0, 0)
    modelArea:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
    self.modelArea = modelArea
    self.contentArea = modelArea  -- For compatibility with existing code

    -- Model background (solid black for 3D)
    local modelBg = modelArea:CreateTexture(nil, "BACKGROUND")
    modelBg:SetAllPoints()
    modelBg:SetColorTexture(0, 0, 0, 1)

    -- Create ModelScene in model area
    self:CreateModelScene()
    self:CreateFallbackUI()
    self:CreateWidthPresets()
end

function Preview:CreateModelScene()
    local modelScene = CreateFrame("ModelScene", nil, self.modelArea, "ModelSceneMixinTemplate")
    modelScene:SetAllPoints()
    modelScene:TransitionToModelSceneID(DEFAULT_SCENE_ID, CAMERA_IMMEDIATE, CAMERA_DISCARD, true)
    self.modelScene = modelScene
    self.currentSceneID = DEFAULT_SCENE_ID  -- Track current scene to avoid unnecessary transitions
    self.sceneCameraBaselines = self.sceneCameraBaselines or {}

    -- Enable ModelScene mouse interaction for drag rotation.
    modelScene:EnableMouse(true)

    -- Enable mouse wheel zoom
    modelScene:EnableMouseWheel(true)
    modelScene:SetScript("OnMouseWheel", function(_, delta)
        self:OnModelSceneMouseWheel(delta)
    end)

    -- Apply per-frame camera adjustments (vertical drag inversion).
    modelScene:HookScript("OnUpdate", function(_, elapsed)
        self:OnModelSceneUpdate(elapsed)
    end)
end

function Preview:OnModelSceneMouseWheel(delta)
    local camera = self.modelScene and self.modelScene:GetActiveCamera()
    if not camera or not camera.ZoomByPercent then return end

    camera:ZoomByPercent(delta * ZOOM_STEP)
end

function Preview:GetActiveOrbitCamera()
    local camera = self.modelScene and self.modelScene:GetActiveCamera()
    if not camera or not camera.GetCameraType then return nil end
    if camera:GetCameraType() ~= "OrbitCamera" then return nil end
    return camera
end

function Preview:ConfigureOrbitCameraControls(camera)
    if not camera then return end

    if camera.SetLeftMouseButtonXMode then
        camera:SetLeftMouseButtonXMode(ORBIT_MOUSE_YAW, true)
    end
    if camera.SetLeftMouseButtonYMode then
        camera:SetLeftMouseButtonYMode(ORBIT_MOUSE_PITCH, true)
    end
    if camera.SetRightMouseButtonXMode then
        camera:SetRightMouseButtonXMode(ORBIT_MOUSE_PAN_HORIZONTAL, true)
    end
    if camera.SetRightMouseButtonYMode then
        camera:SetRightMouseButtonYMode(ORBIT_MOUSE_PAN_VERTICAL, true)
    end
    if camera.SetMouseWheelMode then
        camera:SetMouseWheelMode(ORBIT_MOUSE_ZOOM, false)
    end
end

function Preview:CaptureSceneCameraBaseline(sceneID, camera)
    if not sceneID or not camera or not camera.GetYaw or not camera.GetPitch then return end
    if self.sceneCameraBaselines[sceneID] then return end

    local minZoomDistance = camera.GetMinZoomDistance and camera:GetMinZoomDistance() or nil
    local maxZoomDistance = camera.GetMaxZoomDistance and camera:GetMaxZoomDistance() or nil

    self.sceneCameraBaselines[sceneID] = {
        yaw = camera:GetYaw(),
        pitch = camera:GetPitch(),
        minZoomDistance = minZoomDistance,
        maxZoomDistance = maxZoomDistance,
    }
end

function Preview:ResetCameraToSceneBaseline(sceneID, camera)
    local baseline = self.sceneCameraBaselines and self.sceneCameraBaselines[sceneID]
    if not baseline or not camera then return end

    if camera.SetYaw then
        camera:SetYaw(baseline.yaw)
        if camera.SnapToTargetInterpolationYaw then
            camera:SnapToTargetInterpolationYaw()
        end
    end

    if camera.SetPitch then
        camera:SetPitch(baseline.pitch)
        if camera.SnapToTargetInterpolationPitch then
            camera:SnapToTargetInterpolationPitch()
        end
    end
end

function Preview:ApplySceneZoomRange(sceneID, camera)
    local baseline = self.sceneCameraBaselines and self.sceneCameraBaselines[sceneID]
    if not baseline or not camera then return end
    if not camera.SetMinZoomDistance or not camera.SetMaxZoomDistance then return end

    local minZoomDistance = baseline.minZoomDistance
    local maxZoomDistance = baseline.maxZoomDistance
    if not minZoomDistance or not maxZoomDistance then return end

    local extendedMinZoomDistance = math.max(0.05, minZoomDistance * PREVIEW_MIN_ZOOM_SCALE)
    if extendedMinZoomDistance > maxZoomDistance then
        extendedMinZoomDistance = maxZoomDistance
    end

    camera:SetMaxZoomDistance(maxZoomDistance)
    camera:SetMinZoomDistance(extendedMinZoomDistance)

    if camera.SnapToTargetInterpolationZoom then
        camera:SnapToTargetInterpolationZoom()
    end
end

function Preview:ApplyInvertedVerticalDrag(camera)
    if not camera or not camera.GetPitch or not camera.SetPitch then return end

    local currentPitch = camera:GetPitch()
    if self.lastPitchCamera ~= camera then
        self.lastPitchCamera = camera
        self.lastPitchValue = currentPitch
        return
    end

    if not self.lastPitchValue then return end
    if not (camera.IsLeftMouseButtonDown and camera:IsLeftMouseButtonDown()) then return end

    local pitchDelta = currentPitch - self.lastPitchValue
    if pitchDelta == 0 then return end

    -- Invert default Orbit camera vertical drag direction.
    camera:SetPitch(self.lastPitchValue - pitchDelta)
    if camera.SnapToTargetInterpolationPitch then
        camera:SnapToTargetInterpolationPitch()
    end
end

function Preview:OnModelSceneUpdate(elapsed)
    if not self.modelScene or not self.modelScene:IsShown() then return end

    local camera = self:GetActiveOrbitCamera()
    if not camera then return end

    -- Inverted vertical drag
    self:ApplyInvertedVerticalDrag(camera)
    self.lastPitchValue = camera:GetPitch()

    -- Auto-rotation (requires elapsed for delta-based yaw)
    if not elapsed then return end
    if not (addon.db and addon.db.settings.autoRotatePreview) then return end

    -- Pause when user is dragging
    if self.modelScene:IsLeftMouseButtonDown() or self.modelScene:IsRightMouseButtonDown() then
        return
    end

    local yaw = camera:GetYaw() or 0
    camera:SetYaw(yaw + elapsed * ROTATION_SPEED)
    if camera.SnapToTargetInterpolationYaw then
        camera:SnapToTargetInterpolationYaw()
    end
end

function Preview:CreateFallbackUI()
    -- Fallback container: shown when model cannot load (displays icon + message)
    local fallback = CreateFrame("Frame", nil, self.modelArea)
    fallback:SetAllPoints()
    fallback:Hide()
    self.fallbackContainer = fallback

    local icon = fallback:CreateTexture(nil, "ARTWORK")
    icon:SetSize(64, 64)
    icon:SetPoint("CENTER", 0, 20)
    self.fallbackIcon = icon

    local message = addon:CreateFontString(fallback, "OVERLAY", "GameFontNormalLarge")
    message:SetPoint("TOP", icon, "BOTTOM", 0, -12)
    message:SetTextColor(unpack(COLORS.TEXT_TERTIARY))
    self.fallbackMessage = message

    -- Placeholder: shown when no item selected
    local placeholder = addon:CreateFontString(self.modelArea, "OVERLAY", "GameFontNormalLarge")
    placeholder:SetPoint("CENTER")
    placeholder:SetText(addon.L["PREVIEW_NO_SELECTION"])
    placeholder:SetTextColor(unpack(COLORS.TEXT_TERTIARY))
    self.placeholderText = placeholder
end

function Preview:CreateWidthPresets()
    local BUTTON_WIDTH = 18
    local BUTTON_SPACING = 2

    local container = CreateFrame("Frame", nil, self.modelArea)
    container:SetSize(#WIDTH_PRESETS * (BUTTON_WIDTH + BUTTON_SPACING), 16)
    container:SetPoint("BOTTOMRIGHT", self.modelArea, "BOTTOMRIGHT", -21, 1)
    container:SetFrameLevel(self.modelArea:GetFrameLevel() + 10)

    self.widthPresetButtons = {}

    for i, presetWidth in ipairs(WIDTH_PRESETS) do
        local btn = CreateFrame("Button", nil, container)
        btn:SetSize(BUTTON_WIDTH, 14)
        btn:SetPoint("LEFT", container, "LEFT", (i - 1) * (BUTTON_WIDTH + BUTTON_SPACING), 0)

        local label = addon:CreateFontString(btn, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER")
        label:SetText(string.rep(".", i))  -- ".", "..", "..."
        label:SetTextColor(unpack(COLOR_PRESET_INACTIVE))
        btn.label = label
        btn.width = presetWidth

        btn:SetScript("OnEnter", function()
            label:SetTextColor(unpack(COLOR_PRESET_HOVER))
        end)

        btn:SetScript("OnLeave", function()
            self:UpdateWidthPresetHighlight()
        end)

        btn:SetScript("OnClick", function()
            if addon.MainFrame then
                addon.MainFrame:SetPreviewWidth(presetWidth)
                self:UpdateWidthPresetHighlight()
                self:UpdateMetadataLayout()
            end
        end)

        self.widthPresetButtons[i] = btn
    end

    self:UpdateWidthPresetHighlight()
end

function Preview:UpdateWidthPresetHighlight()
    local buttons = self.widthPresetButtons
    if not buttons then return end

    local currentWidth = addon.MainFrame and addon.MainFrame:GetPreviewWidth()
        or addon.CONSTANTS.PREVIEW_DEFAULT_WIDTH

    for _, btn in ipairs(buttons) do
        local isActive = btn.width == currentWidth
        btn.label:SetTextColor(unpack(isActive and COLOR_PRESET_ACTIVE or COLOR_PRESET_INACTIVE))
    end
end

-- ============================================================================
-- Details Panel (1C.6 + 1C.7)
-- ============================================================================

function Preview:CreateIdentityBlock()
    local details = self.detailsArea

    -- Item name (at top of details area, no icon)
    local name = addon:CreateFontString(details, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", details, "TOPLEFT", PADDING, -PADDING)
    name:SetPoint("RIGHT", details, "RIGHT", -PADDING, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(true)
    name:SetMaxLines(2)
    name:SetTextColor(1, 1, 1)
    self.detailsName = name

    -- Owned count (below name)
    local owned = addon:CreateFontString(details, "OVERLAY", "GameFontHighlight")
    owned:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    owned:SetTextColor(0.7, 0.7, 0.7)
    self.detailsOwned = owned

    -- Placed count (inline, right of owned)
    local placed = addon:CreateFontString(details, "OVERLAY", "GameFontHighlight")
    placed:SetPoint("LEFT", owned, "RIGHT", 8, 0)
    placed:SetTextColor(0.4, 0.8, 0.4)
    self.detailsPlaced = placed

    -- Source text container (hyperlink-enabled for currency/quest/item tooltips)
    local sourceContainer = CreateFrame("Frame", nil, details)
    sourceContainer:SetPoint("TOPLEFT", owned, "BOTTOMLEFT", 0, -PADDING)
    sourceContainer:SetPoint("RIGHT", details, "RIGHT", -PADDING, 0)
    sourceContainer:SetHeight(60)  -- Resized based on content
    sourceContainer:SetHyperlinksEnabled(true)
    sourceContainer:SetScript("OnHyperlinkEnter", function(frame, link)
        GameTooltip:SetOwner(frame, "ANCHOR_CURSOR_RIGHT", 10, 0)
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    sourceContainer:SetScript("OnHyperlinkLeave", function()
        GameTooltip:Hide()
    end)
    self.sourceContainer = sourceContainer

    local source = sourceContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    source:SetAllPoints()
    source:SetJustifyH("LEFT")
    source:SetJustifyV("TOP")
    source:SetWordWrap(true)
    source:SetTextColor(0.8, 0.8, 0.8)
    self.detailsSource = source

    -- ========== Metadata Section (1C.7) ==========
    -- Row 1: Size + Place (always on first row)
    local sizeLabel = addon:CreateFontString(details, "OVERLAY", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", sourceContainer, "BOTTOMLEFT", 0, -PADDING - METADATA_GAP)
    sizeLabel:SetText(addon.L["DETAILS_SIZE"])
    sizeLabel:SetTextColor(0.5, 0.5, 0.5)
    self.detailsSizeLabel = sizeLabel

    local sizeValue = addon:CreateFontString(details, "OVERLAY", "GameFontHighlight")
    sizeValue:SetPoint("LEFT", sizeLabel, "RIGHT", 4, 0)
    sizeValue:SetTextColor(1, 1, 1)
    self.detailsSize = sizeValue

    local placeLabel = addon:CreateFontString(details, "OVERLAY", "GameFontHighlight")
    placeLabel:SetPoint("LEFT", sizeValue, "RIGHT", 12, 0)
    placeLabel:SetText(addon.L["DETAILS_PLACE"])
    placeLabel:SetTextColor(0.5, 0.5, 0.5)

    local placeValue = addon:CreateFontString(details, "OVERLAY", "GameFontHighlight")
    placeValue:SetPoint("LEFT", placeLabel, "RIGHT", 4, 0)
    placeValue:SetTextColor(1, 1, 1)
    self.detailsPlacement = placeValue

    -- Dyeable + Category (position set dynamically based on preview width)
    local dyeableValue = addon:CreateFontString(details, "OVERLAY", "GameFontHighlight")
    self.detailsDyeable = dyeableValue

    local categoryValue = addon:CreateFontString(details, "OVERLAY", "GameFontHighlight")
    categoryValue:SetJustifyH("LEFT")
    categoryValue:SetTextColor(unpack(COLOR_CATEGORY))
    self.detailsCategory = categoryValue

    -- ========== Actions Row (1C.9) ==========
    self:CreateActionsRow(details, sizeLabel)  -- Initial anchor, updated by UpdateMetadataLayout

    -- Set initial metadata layout based on preview width
    self:UpdateMetadataLayout()

    -- Initialize with placeholder state
    self:ClearDetails()
end


function Preview:CreateActionsRow(details, anchorElement)
    local AB = addon.CONSTANTS.ACTION_BUTTON

    -- Actions row container (below metadata)
    local actionsRow = CreateFrame("Frame", nil, details)
    actionsRow:SetHeight(AB.HEIGHT + 4)  -- Button height + padding
    actionsRow:SetPoint("TOPLEFT", anchorElement, "BOTTOMLEFT", 0, -PADDING)
    actionsRow:SetPoint("RIGHT", details, "RIGHT", -PADDING, 0)
    self.actionsRow = actionsRow

    -- Wishlist star button (first in row)
    local wishlistBtn = self:CreateWishlistButton(actionsRow)
    wishlistBtn:SetPoint("LEFT", actionsRow, "LEFT", 0, 0)
    self.wishlistButton = wishlistBtn

    -- Track/Untrack button (uses shared action button style)
    local trackBtn = addon:CreateActionButton(
        actionsRow,
        addon.L["ACTION_TRACK"],
        function() self:OnTrackButtonClick() end,
        function(btn) self:ShowTrackButtonTooltip(btn) end
    )
    trackBtn:SetPoint("LEFT", wishlistBtn, "RIGHT", AB.SPACING + 4, 0)
    self.trackButton = trackBtn

    -- Link to Chat button (left-click: chat link, right-click: Wowhead URL)
    local linkBtn = addon:CreateActionButton(
        actionsRow,
        addon.L["ACTION_LINK"],
        function(btn, mouseButton)
            if mouseButton == "RightButton" then
                self:OnLinkButtonRightClick()
            else
                self:OnLinkButtonClick()
            end
        end,
        function(btn) self:ShowLinkButtonTooltip(btn) end
    )
    linkBtn:SetPoint("LEFT", trackBtn, "RIGHT", AB.SPACING, 0)
    linkBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.linkButton = linkBtn
end


-- Star button sizing and colors
local WISHLIST_STAR_SIZE = addon.CONSTANTS.WISHLIST_STAR_SIZE_PREVIEW
local COLOR_STAR_EMPTY = { 0.4, 0.4, 0.4, 1 }
local COLOR_STAR_FILLED = COLORS.GOLD
local COLOR_STAR_HOVER = { 0.7, 0.7, 0.7, 1 }

function Preview:CreateWishlistButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(WISHLIST_STAR_SIZE, WISHLIST_STAR_SIZE)

    -- Star texture (using common star atlas)
    local star = btn:CreateTexture(nil, "ARTWORK")
    star:SetAllPoints()
    star:SetAtlas("PetJournal-FavoritesIcon")  -- Filled star shape
    star:SetDesaturated(true)
    star:SetVertexColor(unpack(COLOR_STAR_EMPTY))
    btn.star = star

    btn:SetScript("OnClick", function()
        local recordID = self.currentRecordID
        if not recordID then return end

        local isNowWishlisted = addon:ToggleWishlist(recordID)
        local record = addon:GetRecord(recordID)
        local name = record and record.name or addon.L["UNKNOWN"]

        if isNowWishlisted then
            addon:Print(string.format(addon.L["WISHLIST_ADDED"], name))
        else
            addon:Print(string.format(addon.L["WISHLIST_REMOVED"], name))
        end
        self:UpdateWishlistButton()
    end)

    btn:SetScript("OnEnter", function(b)
        local recordID = self.currentRecordID
        if not recordID then return end

        local isWishlisted = addon:IsWishlisted(recordID)
        if not isWishlisted then
            b.star:SetVertexColor(unpack(COLOR_STAR_HOVER))
        end

        local tooltipText = isWishlisted
            and addon.L["WISHLIST_REMOVE"]
            or addon.L["WISHLIST_ADD"]
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipText)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        self:UpdateWishlistButton()
        GameTooltip:Hide()
    end)

    return btn
end

function Preview:UpdateWishlistButton()
    if not self.wishlistButton then return end

    local isWishlisted = self.currentRecordID and addon:IsWishlisted(self.currentRecordID)
    local star = self.wishlistButton.star

    star:SetDesaturated(not isWishlisted)
    star:SetVertexColor(unpack(isWishlisted and COLOR_STAR_FILLED or COLOR_STAR_EMPTY))
end

function Preview:UpdateDetails(record)
    if not record then
        self:ClearDetails()
        return
    end

    -- Name
    self.detailsName:SetText(record.name or addon.L["UNKNOWN"])
    self.detailsName:SetTextColor(1, 1, 1)

    -- Owned count (use totalOwned = placed + storage + redeemable)
    if record.totalOwned and record.totalOwned > 0 then
        self.detailsOwned:SetText(string.format(addon.L["DETAILS_OWNED"], record.totalOwned))
        self.detailsOwned:SetTextColor(0.2, 0.8, 0.2)
    else
        self.detailsOwned:SetText(addon.L["DETAILS_NOT_OWNED"])
        self.detailsOwned:SetTextColor(0.6, 0.6, 0.6)
    end

    -- Placed count (inline with owned)
    if record.numPlaced and record.numPlaced > 0 then
        self.detailsPlaced:SetText(string.format(addon.L["DETAILS_PLACED"], record.numPlaced))
        self.detailsPlaced:Show()
    else
        self.detailsPlaced:SetText("")
        self.detailsPlaced:Hide()
    end

    -- Source (hyperlink-enabled container handles tooltips automatically)
    if record.sourceText and record.sourceText ~= "" then
        self.detailsSource:SetText(record.sourceText)
    else
        self.detailsSource:SetText(addon.L["DETAILS_SOURCE_UNKNOWN"])
    end
    self.sourceContainer:SetHeight(self.detailsSource:GetStringHeight() or 20)

    -- ========== Metadata (1C.7) ==========

    -- Size (use localized name or dash if no size)
    self.detailsSize:SetText(record.sizeKey and addon.L[record.sizeKey] or "-")

    -- Place
    local placement = {}
    if record.isIndoors then table.insert(placement, addon.L["PLACEMENT_IN"]) end
    if record.isOutdoors then table.insert(placement, addon.L["PLACEMENT_OUT"]) end
    self.detailsPlacement:SetText(#placement > 0 and table.concat(placement, "/") or "-")

    -- Dyeable
    if record.canCustomize then
        self.detailsDyeable:SetText(addon.L["DETAILS_DYEABLE"])
        self.detailsDyeable:SetTextColor(0.6, 0.8, 1)  -- Light blue
    else
        self.detailsDyeable:SetText(addon.L["DETAILS_NOT_DYEABLE"])
        self.detailsDyeable:SetTextColor(0.5, 0.5, 0.5)  -- Gray
    end

    -- Category (show "Category > Subcategory" format)
    self.detailsCategory:SetText(self:FormatCategoryPath(record))

    -- ========== Actions (1C.9) ==========
    self:UpdateActionButtons(record)

    -- Recalculate height after content is set
    self:RecalculateDetailsHeight()
end

function Preview:ClearDetails()
    if not self.detailsName then return end  -- Not yet created

    self.detailsName:SetText(addon.L["PREVIEW_NO_SELECTION"])
    self.detailsName:SetTextColor(0.5, 0.5, 0.5)
    self.detailsOwned:SetText("")
    self.detailsPlaced:SetText("")
    self.detailsPlaced:Hide()
    self.detailsSource:SetText("")
    self.detailsSize:SetText("-")
    self.detailsPlacement:SetText("-")
    self.detailsDyeable:SetText("")
    self.detailsCategory:SetText("")

    -- Reset action buttons to disabled state (wishlist uses UpdateWishlistButton which handles nil recordID)
    self:UpdateWishlistButton()
    if self.trackButton then
        self.trackButton:SetText(addon.L["ACTION_TRACK"])
        self.trackButton:SetEnabled(false)
        self.trackButton:SetActive(false)
    end
    if self.linkButton then
        self.linkButton:SetEnabled(false)
    end

    -- Reset to minimum height
    self.detailsArea:SetHeight(DETAILS_MIN_HEIGHT)
end

function Preview:RecalculateDetailsHeight()
    if not self.detailsArea then return end

    local height = PADDING  -- Top padding

    -- Name (up to 2 lines, word wrapped)
    height = height + self.detailsName:GetStringHeight()
    height = height + SPACING_SMALL

    -- Owned (1 line, may be empty)
    local ownedText = self.detailsOwned:GetText()
    if ownedText and ownedText ~= "" then
        height = height + self.detailsOwned:GetStringHeight()
    end
    height = height + PADDING

    -- Source (FontString)
    local sourceText = self.detailsSource:GetText()
    if sourceText and sourceText ~= "" then
        height = height + self.detailsSource:GetStringHeight()
        height = height + PADDING + METADATA_GAP
    end

    -- Metadata row(s) - layout depends on preview width
    height = height + self.detailsSize:GetStringHeight()
    if self.metadataTwoRows then
        -- Two-row layout: Size+Place on row 1, Dyeable+Category on row 2
        height = height + SPACING_SMALL
        height = height + self.detailsDyeable:GetStringHeight()
    end
    height = height + PADDING

    -- Actions row (1C.9) - uses shared button height constant
    local AB = addon.CONSTANTS.ACTION_BUTTON
    height = height + AB.HEIGHT + 4  -- Button height + padding
    height = height + PADDING  -- Bottom padding before divider

    -- Apply calculated height (with minimum)
    self.detailsArea:SetHeight(math.max(DETAILS_MIN_HEIGHT, height))
end

-- Small preset threshold for switching to two-row metadata layout
local SMALL_WIDTH_THRESHOLD = 300

function Preview:UpdateMetadataLayout()
    if not self.detailsDyeable or not self.detailsCategory then return end

    local currentWidth = addon.MainFrame and addon.MainFrame:GetPreviewWidth()
        or addon.CONSTANTS.PREVIEW_DEFAULT_WIDTH
    local useTwoRows = (currentWidth <= SMALL_WIDTH_THRESHOLD)

    -- Skip if layout hasn't changed
    if self.metadataTwoRows == useTwoRows then return end
    self.metadataTwoRows = useTwoRows

    -- Clear existing points before repositioning
    self.detailsDyeable:ClearAllPoints()
    self.detailsCategory:ClearAllPoints()
    self.actionsRow:ClearAllPoints()

    -- Position elements based on layout mode
    if useTwoRows then
        -- Two-row layout: Dyeable + Category on separate row below Size/Place
        self.detailsDyeable:SetPoint("TOPLEFT", self.detailsSizeLabel, "BOTTOMLEFT", 0, -SPACING_SMALL)
        self.detailsCategory:SetPoint("LEFT", self.detailsDyeable, "RIGHT", 12, 0)
        self.detailsCategory:SetPoint("RIGHT", self.detailsArea, "RIGHT", -PADDING, 0)
        self.actionsRow:SetPoint("TOPLEFT", self.detailsDyeable, "BOTTOMLEFT", 0, -PADDING)
    else
        -- Single-row layout: All metadata on one line
        self.detailsDyeable:SetPoint("LEFT", self.detailsPlacement, "RIGHT", 12, 0)
        self.detailsCategory:SetPoint("LEFT", self.detailsDyeable, "RIGHT", 12, 0)
        self.actionsRow:SetPoint("TOPLEFT", self.detailsSizeLabel, "BOTTOMLEFT", 0, -PADDING)
    end
    self.actionsRow:SetPoint("RIGHT", self.detailsArea, "RIGHT", -PADDING, 0)

    -- Category text truncation: only needed in two-row layout where width is constrained
    self.detailsCategory:SetWordWrap(not useTwoRows)

    -- Recalculate height for new layout
    self:RecalculateDetailsHeight()
end

-- Note: ESC handling is done by MainFrame (cascading: preview closes first, then MainFrame)

-- ============================================================================
-- Actions (1C.9)
-- ============================================================================

local function GetVendorsTrackingContext()
    if not addon.Tabs or not addon.Tabs:IsSelected("VENDORS") then
        return nil, nil
    end

    local vendorsTab = addon.VendorsTab
    if not vendorsTab or not vendorsTab.IsShown or not vendorsTab:IsShown() then
        return nil, nil
    end

    local npcId = vendorsTab.selectedVendorNpcId
    if not npcId then
        return nil, nil
    end

    return vendorsTab, npcId
end

function Preview:UpdateActionButtons(record)
    if not self.trackButton or not self.linkButton then return end

    -- Wishlist button state
    self:UpdateWishlistButton()

    local recordID = (record and record.recordID) or self.currentRecordID
    local vendorsTab, npcId = GetVendorsTrackingContext()

    -- Vendors tab: all items use vendor waypoint tracking
    if vendorsTab and recordID then
        local canTrack = vendorsTab:CanVendorTrackDecor(npcId)
        if canTrack then
            self.trackButton:SetEnabled(true)
            local isTracking = vendorsTab:IsVendorDecorTracked(npcId, recordID)
            self.trackButton:SetActive(isTracking)
            if isTracking then
                self.trackButton:SetText(addon.L["ACTION_UNTRACK"])
            else
                self.trackButton:SetText(addon.L["ACTION_TRACK"])
            end
        else
            self.trackButton:SetEnabled(false)
            self.trackButton:SetActive(false)
            self.trackButton:SetText(addon.L["ACTION_TRACK"])
        end
    else
        -- Native tracking behavior on non-Vendors tabs
        if record and record.isTrackable then
            self.trackButton:SetEnabled(true)
            local isTracking = addon:IsRecordTracked(record.recordID)
            self.trackButton:SetActive(isTracking)  -- Gold highlight when tracking
            if isTracking then
                self.trackButton:SetText(addon.L["ACTION_UNTRACK"])
            else
                self.trackButton:SetText(addon.L["ACTION_TRACK"])
            end
        else
            self.trackButton:SetEnabled(false)
            self.trackButton:SetActive(false)
            self.trackButton:SetText(addon.L["ACTION_TRACK"])
        end
    end

    -- Link button is always enabled when an item is selected
    self.linkButton:SetEnabled(record ~= nil)
end

function Preview:OnTrackButtonClick()
    local recordID = self.currentRecordID
    local vendorsTab, npcId = GetVendorsTrackingContext()
    if vendorsTab and recordID then
        vendorsTab:ToggleVendorDecorTracking(npcId, recordID)
    else
        addon:ToggleTracking(recordID)
    end

    -- Update preview button state
    local record = recordID and addon:GetRecord(recordID)
    self:UpdateActionButtons(record)
end

function Preview:OnLinkButtonClick()
    addon:InsertItemChatLink(self.currentRecordID)
end

function Preview:OnLinkButtonRightClick()
    addon:OpenItemWowheadURL(self.currentRecordID, self.linkButton)
end

function Preview:ShowTrackButtonTooltip(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")

    local recordID = self.currentRecordID
    local record = recordID and addon:GetRecord(recordID)
    local L = addon.L
    local vendorsTab, npcId = GetVendorsTrackingContext()

    if vendorsTab and recordID then
        local title, description, r, g, b
        if not vendorsTab:CanVendorTrackDecor(npcId) then
            title = L["ACTION_TRACK"]
            description = L["VENDORS_ACTION_TRACK_DISABLED_TOOLTIP"]
            r, g, b = 1, 0.5, 0.5
        elseif vendorsTab:IsVendorDecorTracked(npcId, recordID) then
            title = L["ACTION_UNTRACK"]
            description = L["VENDORS_ACTION_UNTRACK_TOOLTIP"]
            r, g, b = 1, 1, 1
        else
            title = L["ACTION_TRACK"]
            description = L["VENDORS_ACTION_TRACK_TOOLTIP"]
            r, g, b = 1, 1, 1
        end

        GameTooltip:SetText(title)
        GameTooltip:AddLine(description, r, g, b)
        GameTooltip:Show()
        return
    end

    -- Determine tooltip content based on tracking state
    local title, description, r, g, b
    if not record or not record.isTrackable then
        title = L["ACTION_TRACK"]
        description = L["ACTION_TRACK_DISABLED_TOOLTIP"]
        r, g, b = 1, 0.5, 0.5
    elseif addon:IsRecordTracked(recordID) then
        title = L["ACTION_UNTRACK"]
        description = L["ACTION_UNTRACK_TOOLTIP"]
        r, g, b = 1, 1, 1
    else
        title = L["ACTION_TRACK"]
        description = L["ACTION_TRACK_TOOLTIP"]
        r, g, b = 1, 1, 1
    end

    GameTooltip:SetText(title)
    GameTooltip:AddLine(description, r, g, b)
    GameTooltip:Show()
end

function Preview:ShowLinkButtonTooltip(btn)
    addon:ShowActionLinkTooltip(btn)
end

-- ============================================================================
-- Model Display
-- ============================================================================

-- Helper to find actor in scene (scenes define actors via "decor" or "item" tags)
function Preview:GetActor()
    if not self.modelScene then return nil end
    return self.modelScene:GetActorByTag("decor") or self.modelScene:GetActorByTag("item")
end

function Preview:ShowDecor(recordID)
    if not self.frame then
        self:Create()
    end

    local record = addon:GetRecord(recordID)
    if not record then
        -- Item not in catalog (HiddenInCatalog flag) - show name via shared fallback chain
        self.placeholderText:Hide()
        self.currentRecordID = recordID
        self:ClearDetails()
        self:UpdateActionButtons(nil)
        self.detailsName:SetText(addon:ResolveDecorName(recordID, nil))
        self.detailsName:SetTextColor(1, 1, 1)
        self:ShowFallback(addon.L["PREVIEW_NOT_IN_CATALOG"])
        return
    end

    self.placeholderText:Hide()
    self.currentRecordID = recordID

    -- Update details panel (1C.6 + 1C.7)
    self:UpdateDetails(record)

    -- No model asset available - show fallback with icon
    if not record.modelAsset then
        self:ShowFallback(addon.L["PREVIEW_NO_MODEL"], record.icon, record.iconType)
        return
    end

    -- Transition to appropriate scene preset (only if changed to avoid flash)
    local sceneID = record.modelSceneID or SCENE_PRESETS[record.size] or DEFAULT_SCENE_ID
    if sceneID ~= self.currentSceneID then
        self.modelScene:TransitionToModelSceneID(sceneID, CAMERA_IMMEDIATE, CAMERA_DISCARD, true)
        self.currentSceneID = sceneID
    end

    local camera = self:GetActiveOrbitCamera()
    if camera then
        self:ConfigureOrbitCameraControls(camera)
        self:CaptureSceneCameraBaseline(sceneID, camera)
        self:ApplySceneZoomRange(sceneID, camera)
        self:ResetCameraToSceneBaseline(sceneID, camera)
    end

    local actor = self:GetActor()
    if not actor then
        self:ShowFallback(addon.L["PREVIEW_ERROR"], record.icon, record.iconType)
        addon:Debug("Preview: no actor found in scene " .. sceneID)
        return
    end

    -- Configure and load model
    actor:SetPreferModelCollisionBounds(true)
    actor:SetModelByFileID(record.modelAsset)

    self:HideFallback()
    self.modelScene:Show()
    addon:Debug("Preview showing model for: " .. record.name)
end

function Preview:ShowFallback(message, icon, iconType)
    if self.modelScene then self.modelScene:Hide() end

    -- Configure fallback icon
    if icon then
        SetIcon(self.fallbackIcon, icon, iconType)
    end
    self.fallbackIcon:SetShown(icon ~= nil)
    self.fallbackMessage:SetText(message or "")
    self.fallbackContainer:Show()
    self.placeholderText:Hide()
end

function Preview:HideFallback()
    self.fallbackContainer:Hide()
    self.modelScene:Show()
end

function Preview:ClearModel()
    local actor = self:GetActor()
    if actor then actor:ClearModel() end
    if self.modelScene then self.modelScene:Hide() end

    self.currentRecordID = nil
    self.currentSceneID = nil  -- Reset scene tracking for fresh state
    self:ClearDetails()
    self.fallbackContainer:Hide()
    self.placeholderText:Show()
end

function Preview:GetCurrentRecordID()
    return self.currentRecordID
end

-- ============================================================================
-- Visibility
-- ============================================================================

function Preview:Show()
    if self:IsShown() then return true end

    if InCombatLockdown() then
        addon:Print(addon.L["COMBAT_LOCKDOWN_MESSAGE"])
        return false
    end

    if not addon.MainFrame or not addon.MainFrame.frame then
        addon:Debug("Preview:Show() - MainFrame not ready")
        return false
    end

    if not self.frame and not self:Create() then
        return false
    end

    addon.MainFrame:ExpandForPreview()
    return true
end

function Preview:IsShown()
    local region = addon.MainFrame and addon.MainFrame.previewRegion
    return region and region:IsShown()
end

function Preview:OnMainFrameHide()
    -- Explicitly hide ModelScene to free GPU resources
    -- (Frame hierarchy hides it, but explicit hide is Blizzard's pattern)
    if self.modelScene then
        self.modelScene:Hide()
    end
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

-- Update preview when selection changes
addon:RegisterInternalEvent("RECORD_SELECTED", function(recordID)
    if not recordID then
        -- Selection cleared
        if Preview:IsShown() then
            Preview:ClearModel()
        end
        return
    end

    -- Update preview content when selection changes
    if Preview:IsShown() then
        Preview:ShowDecor(recordID)
    end
end)

-- Clear preview when search changes (selection becomes invalid)
addon:RegisterInternalEvent("SEARCH_TEXT_CHANGED", function()
    if Preview:IsShown() then
        Preview:ClearModel()
    end
end)

-- Helper: Refresh action buttons for the current preview item
local function RefreshCurrentActionButtons()
    if not Preview:IsShown() or not Preview.currentRecordID then return end
    local record = addon:GetRecord(Preview.currentRecordID)
    Preview:UpdateActionButtons(record)
end

-- Update track button when tracking state changes externally
addon:RegisterInternalEvent("TRACKING_CHANGED", function(recordID)
    if Preview.currentRecordID == recordID then
        RefreshCurrentActionButtons()
    end
end)

addon:RegisterInternalEvent("VENDOR_TRACKING_CHANGED", function()
    RefreshCurrentActionButtons()
end)

addon:RegisterInternalEvent("TAB_CHANGED", function()
    if Preview:IsShown() then
        Preview:ClearModel()
    end
end)

-- Listen for WoW's tracking update event (catches changes from other UI)
-- Event payload: trackingType (ContentTrackingType), id (number), isTracked (bool)
addon:RegisterWoWEvent("CONTENT_TRACKING_UPDATE", function(trackingType, id, isTracked)
    if trackingType == Enum.ContentTrackingType.Decor then
        RefreshCurrentActionButtons()
    end
end)

-- Update wishlist button when wishlist changes (could be toggled from grid)
addon:RegisterInternalEvent("WISHLIST_CHANGED", function(recordID, isWishlisted)
    if Preview.currentRecordID == recordID then
        Preview:UpdateWishlistButton()
    end
end)
