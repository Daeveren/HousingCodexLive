--[[
    Housing Codex - WishlistFrame.lua
    Standalone wishlist popup window with grid and preview panel
]]

local _, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS
local GRID_OUTER_PAD = CONSTS.GRID_OUTER_PAD
local GRID_CELL_GAP = CONSTS.GRID_CELL_GAP
local DEFAULT_TILE_SIZE = CONSTS.DEFAULT_TILE_SIZE
local MIN_TILE_SIZE = CONSTS.MIN_TILE_SIZE
local MAX_TILE_SIZE = CONSTS.MAX_TILE_SIZE

-- Frame dimensions
local MIN_WIDTH = 600
local MIN_HEIGHT = 400
local DEFAULT_WIDTH = 1200
local DEFAULT_HEIGHT = 940

-- Model scene viewport (fixed size to prevent scaling with window height)
local MODEL_VIEWPORT_WIDTH = 364   -- PREVIEW_WIDTH - padding
local MODEL_VIEWPORT_HEIGHT = 450  -- Fixed height for consistent model scale

-- Layout constants
local HEADER_HEIGHT = 32
local TOOLBAR_HEIGHT = 32
local PREVIEW_WIDTH = 380  -- Embedded preview panel width
local DETAILS_MIN_HEIGHT = 60  -- Minimum details area height
local DETAILS_PADDING = 8
local DETAILS_SPACING = 4

-- Tile color values
local COLOR_BG_NORMAL = { 0.06, 0.06, 0.08, 1 }
local COLOR_BG_HOVER = { 0.1, 0.1, 0.12, 1 }
local COLOR_BORDER_NORMAL = COLORS.BORDER
local COLOR_COLLECTED = { 0.2, 0.8, 0.2 }

-- Camera constants (from centralized CONSTANTS)
local CAMERA_IMMEDIATE = CONSTS.CAMERA.TRANSITION_IMMEDIATE
local CAMERA_DISCARD = CONSTS.CAMERA.MODIFICATION_DISCARD
local SCENE_PRESETS = CONSTS.SCENE_PRESETS
local DEFAULT_SCENE_ID = CONSTS.DEFAULT_SCENE_ID
local ROTATION_SPEED = CONSTS.CAMERA.ROTATION_SPEED
local ZOOM_STEP = CONSTS.CAMERA.ZOOM_STEP

local MAIN_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

addon.WishlistFrame = {}
local WishlistFrame = addon.WishlistFrame

-- UI elements
WishlistFrame.frame = nil
WishlistFrame.titleBar = nil
WishlistFrame.toolbar = nil
WishlistFrame.gridContainer = nil
WishlistFrame.scrollBox = nil
WishlistFrame.scrollBar = nil
WishlistFrame.previewPanel = nil
WishlistFrame.emptyState = nil

-- State
WishlistFrame.tileSize = DEFAULT_TILE_SIZE
WishlistFrame.selectedRecordID = nil

-- Helper to get wishlist UI db
local function GetWishlistDB()
    return addon.db and addon.db.wishlistUI
end

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------

function WishlistFrame:Create()
    if self.frame then return self.frame end

    local L = addon.L

    -- Main frame (initial size clamped to screen bounds)
    local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
    local initialWidth = math.min(DEFAULT_WIDTH, screenWidth)
    local initialHeight = math.min(DEFAULT_HEIGHT, screenHeight)

    local frame = CreateFrame("Frame", "HousingCodexWishlistFrame", UIParent, "BackdropTemplate")
    frame:SetSize(initialWidth, initialHeight)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, screenWidth, screenHeight)
    frame:EnableMouse(true)
    frame:Hide()

    self.frame = frame

    -- Apply backdrop
    frame:SetBackdrop(MAIN_BACKDROP)
    frame:SetBackdropColor(0, 0, 0, 0.95)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Create layout
    self:CreateTitleBar()
    self:CreateToolbar()
    self:CreatePreviewPanel()
    self:CreateGrid()
    self:CreateEmptyState()
    self:CreateResizeHandle()
    self:SetupESCHandling()

    -- Restore saved layout
    self:RestoreLayout()

    -- Add to special frames for ESC handling
    tinsert(UISpecialFrames, "HousingCodexWishlistFrame")

    addon:Debug("WishlistFrame created")
    return frame
end

function WishlistFrame:CreateTitleBar()
    local frame = self.frame
    local L = addon.L

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 3, -3)
    titleBar:SetPoint("TOPRIGHT", -3, -3)
    titleBar:SetHeight(HEADER_HEIGHT)
    self.titleBar = titleBar

    -- Title bar background
    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.08, 0.08, 0.1, 0.95)

    -- Star icon
    local starIcon = titleBar:CreateTexture(nil, "ARTWORK")
    starIcon:SetSize(20, 20)
    starIcon:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    starIcon:SetAtlas("PetJournal-FavoritesIcon")
    starIcon:SetVertexColor(unpack(COLORS.GOLD))

    -- Title text
    local title = addon:CreateFontString(titleBar, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", starIcon, "RIGHT", 8, 0)
    title:SetText(L["WISHLIST_TITLE"])
    title:SetTextColor(unpack(COLORS.TITLE))
    self.titleText = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function()
        WishlistFrame:Hide()
    end)
    self.closeButton = closeBtn

    -- Codex button (return to main UI)
    self:CreateCodexButton(titleBar)

    -- Make title bar draggable
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        WishlistFrame:SaveLayout()
    end)
end

function WishlistFrame:CreateCodexButton(titleBar)
    local AB = addon.CONSTANTS.ACTION_BUTTON
    local L = addon.L

    local btn = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    btn:SetBackdrop(addon.CONSTANTS.TOGGLE_BUTTON_BACKDROP)
    btn:SetBackdropColor(unpack(AB.COLOR_NORMAL))
    btn:SetBackdropBorderColor(unpack(AB.COLOR_BORDER_NORMAL))

    -- Codex icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(19, 19)
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexture("Interface\\AddOns\\HousingCodex\\HC64")

    -- Text label
    local label = addon:CreateFontString(btn, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    label:SetText(L["CODEX_BUTTON"])
    label:SetTextColor(unpack(COLORS.GOLD))

    -- Calculate button width based on content
    local btnWidth = 8 + 19 + 4 + label:GetStringWidth() + 8
    btn:SetSize(btnWidth, 24)

    -- Position before close button
    btn:SetPoint("RIGHT", self.closeButton, "LEFT", -8, -3)

    btn:SetScript("OnEnter", function(b)
        b:SetBackdropColor(unpack(AB.COLOR_HOVER))
        b:SetBackdropBorderColor(0.6, 0.5, 0.1, 1)
        GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["CODEX_BUTTON_TOOLTIP"])
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(b)
        b:SetBackdropColor(unpack(AB.COLOR_NORMAL))
        b:SetBackdropBorderColor(unpack(AB.COLOR_BORDER_NORMAL))
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function()
        if InCombatLockdown() then
            addon:Print(L["COMBAT_LOCKDOWN_MESSAGE"])
            return
        end
        WishlistFrame:Hide()
        if addon.MainFrame then
            addon.MainFrame:Show()
        end
    end)

    self.codexButton = btn
end

function WishlistFrame:CreateToolbar()
    local L = addon.L

    local toolbar = CreateFrame("Frame", nil, self.frame)
    toolbar:SetPoint("TOPLEFT", self.titleBar, "BOTTOMLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", self.titleBar, "BOTTOMRIGHT", 0, 0)
    toolbar:SetHeight(TOOLBAR_HEIGHT)
    self.toolbar = toolbar

    -- Background
    local bg = toolbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.07, 0.9)

    -- Size label
    local label = addon:CreateFontString(toolbar, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", toolbar, "LEFT", GRID_OUTER_PAD, 0)
    label:SetText(L["SIZE_LABEL"])
    label:SetTextColor(0.8, 0.8, 0.8, 1)

    -- Size value display
    local valueText = addon:CreateFontString(toolbar, "OVERLAY", "GameFontNormal")
    valueText:SetPoint("LEFT", label, "RIGHT", 6, 0)
    valueText:SetTextColor(unpack(COLORS.GOLD))
    self.tileSizeValueText = valueText

    -- Size slider
    local slider = CreateFrame("Slider", nil, toolbar, "MinimalSliderTemplate")
    slider:SetPoint("LEFT", valueText, "RIGHT", 12, 0)
    slider:SetSize(100, 16)
    slider:SetMinMaxValues(MIN_TILE_SIZE, MAX_TILE_SIZE)
    slider:SetValueStep(8)
    slider:SetObeyStepOnDrag(true)
    self.tileSizeSlider = slider

    addon:AttachTileSizeSlider(slider, valueText, WishlistFrame)

    -- Item count (right side)
    local countText = addon:CreateFontString(toolbar, "OVERLAY", "GameFontNormal")
    countText:SetPoint("RIGHT", toolbar, "RIGHT", -GRID_OUTER_PAD, 0)
    countText:SetTextColor(0.7, 0.7, 0.7, 1)
    self.itemCountText = countText
end

function WishlistFrame:CreateGrid()
    local db = GetWishlistDB()
    local savedSize = db and db.tileSize
    local isValidSize = savedSize and savedSize >= MIN_TILE_SIZE and savedSize <= MAX_TILE_SIZE
    self.tileSize = isValidSize and savedSize or DEFAULT_TILE_SIZE

    -- Update slider to match
    if self.tileSizeSlider then
        self.tileSizeSlider:SetValue(self.tileSize)
        self.tileSizeValueText:SetText(tostring(self.tileSize))
    end

    -- Grid container (between toolbar and bottom, leaves room for preview on right)
    local container = CreateFrame("Frame", nil, self.frame)
    container:SetPoint("TOPLEFT", self.toolbar, "BOTTOMLEFT", GRID_OUTER_PAD, 0)
    container:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -3 - PREVIEW_WIDTH - GRID_OUTER_PAD, 3 + GRID_OUTER_PAD)
    self.gridContainer = container

    -- Background for grid area (extends 7px beyond container to cover gaps)
    local containerBg = container:CreateTexture(nil, "BACKGROUND")
    containerBg:SetPoint("TOPLEFT", -7, 7)
    containerBg:SetPoint("BOTTOMRIGHT", 7, -7)
    containerBg:SetColorTexture(0.02, 0.02, 0.04, 0.75)

    -- ScrollBox
    local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT")
    scrollBox:SetPoint("BOTTOMRIGHT", -20, 0)
    self.scrollBox = scrollBox

    -- ScrollBar
    local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)
    self.scrollBar = scrollBar

    -- Debounced resize handler — FullUpdate triggers GetStride() re-derivation
    addon:AttachGridResizeHandler(container, self)

    -- Create grid view
    local containerWidth = container:GetWidth()
    if containerWidth <= 0 then containerWidth = DEFAULT_WIDTH - PREVIEW_WIDTH - GRID_OUTER_PAD * 2 - 20 end
    local columns = math.max(1, math.floor((containerWidth + GRID_CELL_GAP) / (self.tileSize + GRID_CELL_GAP)))
    local view = CreateScrollBoxListGridView(
        columns,
        1,
        GRID_OUTER_PAD,
        GRID_OUTER_PAD,
        GRID_OUTER_PAD,
        GRID_CELL_GAP,
        GRID_CELL_GAP
    )

    -- Uses self.tileSize so in-place tile-size changes take effect without rebuild
    view:SetElementSizeCalculator(function()
        return self.tileSize, self.tileSize
    end)

    view:SetElementExtent(self.tileSize)
    view:SetStrideExtent(self.tileSize)

    -- Element resetter
    view:SetElementResetter(function(tile)
        if tile.icon then
            tile.icon:SetTexture(nil)
            tile.icon:Show()
        end
        if tile.modelScene then
            local actor = tile.modelScene:GetActorByTag("decor")
            if actor then actor:ClearModel() end
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
            self:SetupTileFrame(tile, self.tileSize)
        else
            tile:SetSize(self.tileSize, self.tileSize)
        end

        local recordID = elementData.recordID
        local record = addon:GetRecord(recordID)
        tile.recordID = recordID

        -- Display 3D model or 2D icon (shared utility handles lazy ModelScene creation)
        addon:SetupTileDisplay(tile, record, CAMERA_DISCARD)

        -- Placed count
        local showIndicators = addon.db and addon.db.settings.showCollectedIndicator
        if showIndicators and record and record.numPlaced and record.numPlaced > 0 then
            tile.placed:SetText(record.numPlaced)
            tile.placed:Show()
            tile.quantity:ClearAllPoints()
            tile.quantity:SetPoint("RIGHT", tile.placed, "LEFT", -5, 0)
        else
            tile.placed:Hide()
            tile.quantity:ClearAllPoints()
            tile.quantity:SetPoint("BOTTOMRIGHT", -4, 3)
        end

        -- Owned count
        if showIndicators and record and record.totalOwned and record.totalOwned > 0 then
            tile.quantity:SetText(record.totalOwned)
            tile.quantity:Show()
        end

        -- Always show wishlist star (items are wishlisted)
        if tile.wishlistStar then
            tile.wishlistStar:Show()
        end

        -- Selection state
        if self.selectedRecordID == recordID then
            tile:SetBackdropBorderColor(unpack(COLORS.GOLD))
        end

        -- Click handler
        tile:SetScript("OnMouseDown", function(_, button)
            if button == "RightButton" then
                addon.ContextMenu:ShowForDecor(tile, recordID)
                return
            end
            if button == "LeftButton" and IsShiftKeyDown() then
                -- Shift+Click: Remove from wishlist
                addon:SetWishlisted(recordID, false)
                addon:GetDecorLink(recordID, function(link)
                    addon:Print(string.format(addon.L["WISHLIST_REMOVED"], link))
                end)
                return
            end
            self:SelectRecord(recordID)
        end)

        -- Tooltip and hover preview handler
        tile:SetScript("OnEnter", function(t)
            t:SetBackdropColor(unpack(COLOR_BG_HOVER))
            local rec = addon:GetRecord(t.recordID)
            if not rec then return end

            -- Show preview for hovered item
            self:ShowPreview(t.recordID)

            GameTooltip:SetOwner(t, "ANCHOR_RIGHT")
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
            GameTooltip:AddLine(addon.L["WISHLIST_SHIFT_CLICK"], 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
    end)

    -- Initialize ScrollBox
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    self.view = view

    -- Initialize DataProvider once (reused via Flush/InsertTable in RefreshData)
    self.dataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(self.dataProvider)

    addon:Debug("WishlistFrame grid created with " .. columns .. " columns")
end

-- WishlistFrame uses shared SetupTileFrame with custom OnLeave (restores preview)
function WishlistFrame:SetupTileFrame(tile, tileSize)
    addon:SetupTileFrame(tile, tileSize, function(t)
        t:SetBackdropColor(unpack(COLOR_BG_NORMAL))
        GameTooltip:Hide()

        -- Restore selected item's preview (if any), otherwise clear
        if WishlistFrame.selectedRecordID then
            WishlistFrame:ShowPreview(WishlistFrame.selectedRecordID)
        else
            WishlistFrame:ClearPreview()
        end
    end)
end

function WishlistFrame:CreatePreviewPanel()
    local L = addon.L

    -- Preview panel (right side)
    local panel = CreateFrame("Frame", nil, self.frame)
    panel:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -3, -3 - HEADER_HEIGHT - TOOLBAR_HEIGHT)
    panel:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -3, 3)
    panel:SetWidth(PREVIEW_WIDTH)
    self.previewPanel = panel

    -- Background
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.03, 0.03, 0.05, 1)

    -- Left border divider
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", 0, 0)
    divider:SetPoint("BOTTOMLEFT", 0, 0)
    divider:SetColorTexture(0.2, 0.2, 0.25, 1)

    -- Details area (top portion, with room for source text and action buttons)
    local detailsArea = CreateFrame("Frame", nil, panel)
    detailsArea:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    detailsArea:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    detailsArea:SetHeight(DETAILS_MIN_HEIGHT)  -- Initial minimum, recalculated on content update
    self.detailsArea = detailsArea

    -- Item name
    local name = addon:CreateFontString(detailsArea, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", 0, 0)
    name:SetPoint("RIGHT", 0, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(true)
    name:SetMaxLines(2)
    name:SetTextColor(1, 1, 1)
    self.detailsName = name

    -- Owned count
    local owned = addon:CreateFontString(detailsArea, "OVERLAY", "GameFontHighlight")
    owned:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    owned:SetTextColor(0.7, 0.7, 0.7)
    self.detailsOwned = owned

    -- Placed count
    local placed = addon:CreateFontString(detailsArea, "OVERLAY", "GameFontHighlight")
    placed:SetPoint("LEFT", owned, "RIGHT", 8, 0)
    placed:SetTextColor(0.4, 0.8, 0.4)
    self.detailsPlaced = placed

    -- Source text (no MaxLines limit - sourceText can contain multiple lines with formatting)
    local source = addon:CreateFontString(detailsArea, "OVERLAY", "GameFontHighlight")
    source:SetPoint("TOPLEFT", owned, "BOTTOMLEFT", 0, -8)
    source:SetPoint("RIGHT", detailsArea, "RIGHT", 0, 0)
    source:SetJustifyH("LEFT")
    source:SetWordWrap(true)
    source:SetTextColor(0.8, 0.8, 0.8)
    self.detailsSource = source

    -- Actions row (Wishlist, Track, Link buttons)
    self:CreateActionsRow(detailsArea, source)

    -- Placeholder for no selection
    local placeholder = addon:CreateFontString(detailsArea, "OVERLAY", "GameFontNormal")
    placeholder:SetPoint("CENTER", detailsArea, "CENTER", 0, 0)
    placeholder:SetText(L["DETAILS_NO_SELECTION"])
    placeholder:SetTextColor(0.5, 0.5, 0.5)
    self.detailsPlaceholder = placeholder

    -- Model area (below details)
    local modelArea = CreateFrame("Frame", nil, panel)
    modelArea:SetPoint("TOPLEFT", detailsArea, "BOTTOMLEFT", 0, -8)
    modelArea:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    self.modelArea = modelArea

    -- Model background
    local modelBg = modelArea:CreateTexture(nil, "BACKGROUND")
    modelBg:SetAllPoints()
    modelBg:SetColorTexture(0, 0, 0, 1)

    -- ModelScene (capped size viewport - scales down if area is smaller, but won't exceed max)
    local modelScene = CreateFrame("ModelScene", nil, modelArea, "ModelSceneMixinTemplate")
    modelScene:SetPoint("TOP", modelArea, "TOP", 0, 0)
    modelScene:SetSize(MODEL_VIEWPORT_WIDTH, MODEL_VIEWPORT_HEIGHT)  -- Initial size before OnSizeChanged fires; camera setup requires a valid viewport
    modelScene:TransitionToModelSceneID(DEFAULT_SCENE_ID, CAMERA_IMMEDIATE, CAMERA_DISCARD, true)
    self.modelScene = modelScene

    -- Dynamically size the ModelScene: use available space but cap at max viewport size
    -- OnSizeChanged fires when frame is shown, handling initial sizing automatically
    modelArea:SetScript("OnSizeChanged", function(_, areaWidth, areaHeight)
        modelScene:SetSize(
            math.min(areaWidth, MODEL_VIEWPORT_WIDTH),
            math.min(areaHeight, MODEL_VIEWPORT_HEIGHT)
        )
    end)

    -- Enable mouse interaction (drag rotation + zoom)
    modelScene:EnableMouse(true)
    modelScene:EnableMouseWheel(true)
    modelScene:SetScript("OnMouseWheel", function(_, delta)
        local camera = modelScene:GetActiveCamera()
        if not camera or not camera.ZoomByPercent then return end
        camera:ZoomByPercent(delta * ZOOM_STEP)
    end)

    -- Per-frame: inverted vertical drag + auto-rotation (delegated to shared Preview method).
    addon.Preview:CreateCameraUpdateDriver(modelScene)

    -- Fallback UI (icon + message)
    local fallback = CreateFrame("Frame", nil, modelArea)
    fallback:SetAllPoints()
    fallback:Hide()
    self.fallbackContainer = fallback

    local fallbackIcon = fallback:CreateTexture(nil, "ARTWORK")
    fallbackIcon:SetSize(64, 64)
    fallbackIcon:SetPoint("CENTER", 0, 20)
    self.fallbackIcon = fallbackIcon

    local fallbackMsg = addon:CreateFontString(fallback, "OVERLAY", "GameFontNormal")
    fallbackMsg:SetPoint("TOP", fallbackIcon, "BOTTOM", 0, -12)
    fallbackMsg:SetTextColor(0.5, 0.5, 0.5)
    self.fallbackMessage = fallbackMsg

    -- Initialize with no selection
    self:ClearPreview()
end

function WishlistFrame:CreateEmptyState()
    local L = addon.L

    local frame = CreateFrame("Frame", nil, self.gridContainer)
    frame:SetAllPoints()
    frame:SetFrameLevel(self.gridContainer:GetFrameLevel() + 5)
    frame:Hide()
    self.emptyState = frame

    -- Background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.03, 0.03, 0.05, 0.95)

    -- Message
    local msg = addon:CreateFontString(frame, "OVERLAY", "GameFontNormalLarge")
    msg:SetPoint("CENTER", 0, 20)
    msg:SetText(L["WISHLIST_EMPTY"])
    msg:SetTextColor(0.6, 0.6, 0.6, 1)

    -- Description
    local desc = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOP", msg, "BOTTOM", 0, -12)
    desc:SetText(L["WISHLIST_EMPTY_DESC"])
    desc:SetTextColor(0.5, 0.5, 0.5, 1)
    desc:SetWidth(300)
end

function WishlistFrame:CreateResizeHandle()
    local GRIP_SIZE = 16
    local GRIP_FRAME_LEVEL_OFFSET = 20

    local grip = CreateFrame("Frame", nil, self.frame)
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(self.frame:GetFrameLevel() + GRIP_FRAME_LEVEL_OFFSET)
    grip:EnableMouse(true)
    self.resizeGrip = grip

    local gripTex = grip:CreateTexture(nil, "OVERLAY")
    gripTex:SetAllPoints()
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    grip:SetScript("OnEnter", function()
        gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    end)

    grip:SetScript("OnLeave", function()
        gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    end)

    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self.frame:StartSizing("BOTTOMRIGHT", true)
        end
    end)

    grip:SetScript("OnMouseUp", function()
        self.frame:StopMovingOrSizing()
        self:SaveLayout()
    end)
end

function WishlistFrame:SetupESCHandling()
    local frame = self.frame

    frame:SetScript("OnKeyDown", function(f, key)
        if key == "ESCAPE" then
            f:SetPropagateKeyboardInput(false)
            WishlistFrame:Hide()
        else
            f:SetPropagateKeyboardInput(true)
        end
    end)
    frame:EnableKeyboard(true)
end

--------------------------------------------------------------------------------
-- Actions Row
--------------------------------------------------------------------------------

function WishlistFrame:CreateActionsRow(detailsArea, anchorElement)
    addon:CreateActionsRow(self, detailsArea, anchorElement, 8, 8)
end

function WishlistFrame:UpdateWishlistButton()
    if not self.wishlistButton then return end
    self.wishlistButton:UpdateState(self.currentRecordID)
end

function WishlistFrame:UpdateActionButtons(record)
    if not self.trackButton or not self.linkButton then return end

    self:UpdateWishlistButton()

    local canTrack = record and record.isTrackable
    addon:ApplyTrackButtonState(self.trackButton, canTrack, canTrack and addon:IsRecordTracked(record.recordID), false)

    self.linkButton:SetEnabled(record ~= nil)
end

function WishlistFrame:OnTrackButtonClick()
    local recordID = self.currentRecordID
    addon:ToggleTracking(recordID)

    -- Update preview button state
    local record = recordID and addon:GetRecord(recordID)
    if record then
        self:UpdateActionButtons(record)
    end
end

function WishlistFrame:OnLinkButtonClick()
    addon:InsertItemChatLink(self.currentRecordID)
end

function WishlistFrame:OnLinkButtonRightClick()
    addon:OpenItemWowheadURL(self.currentRecordID, self.linkButton)
end

function WishlistFrame:ShowTrackButtonTooltip(btn)
    local recordID = self.currentRecordID
    local record = recordID and addon:GetRecord(recordID)
    local L = addon.L

    if not record or not record.isTrackable then
        addon:ShowTrackTooltip(btn, L["ACTION_TRACK"], L["ACTION_TRACK_DISABLED_TOOLTIP"], 1, 0.5, 0.5)
    elseif addon:IsRecordTracked(recordID) then
        addon:ShowTrackTooltip(btn, L["ACTION_UNTRACK"], L["ACTION_UNTRACK_TOOLTIP"], 1, 1, 1)
    else
        addon:ShowTrackTooltip(btn, L["ACTION_TRACK"], L["ACTION_TRACK_TOOLTIP"], 1, 1, 1)
    end
end

function WishlistFrame:ShowLinkButtonTooltip(btn)
    addon:ShowActionLinkTooltip(btn)
end

--------------------------------------------------------------------------------
-- Data Management
--------------------------------------------------------------------------------

function WishlistFrame:RefreshData()
    if not self.scrollBox or not self.dataProvider then return end

    -- Get all wishlisted record IDs
    local recordIDs = {}
    if addon.db and addon.db.wishlist then
        for recordID, isWishlisted in pairs(addon.db.wishlist) do
            if isWishlisted then
                table.insert(recordIDs, recordID)
            end
        end
    end

    -- Sort alphabetically by name
    table.sort(recordIDs, function(a, b)
        local recA = addon:GetRecord(a)
        local recB = addon:GetRecord(b)
        local nameA = recA and recA.name or ""
        local nameB = recB and recB.name or ""
        return nameA < nameB
    end)

    -- Update empty state
    local isEmpty = #recordIDs == 0
    if self.emptyState then
        self.emptyState:SetShown(isEmpty)
    end
    if self.scrollBox then
        self.scrollBox:SetShown(not isEmpty)
    end
    if self.scrollBar then
        self.scrollBar:SetShown(not isEmpty)
    end

    -- Update item count
    if self.itemCountText then
        local L = addon.L
        self.itemCountText:SetText(string.format(L["RESULT_COUNT_ALL"], #recordIDs))
    end

    -- Convert to element data
    local elements = {}
    for _, recordID in ipairs(recordIDs) do
        table.insert(elements, { recordID = recordID })
    end

    -- Reuse DataProvider: Flush existing data and insert new elements
    self.dataProvider:Flush()
    if #elements > 0 then
        self.dataProvider:InsertTable(elements)
    end

    addon:Debug("WishlistFrame refreshed with " .. #recordIDs .. " items")
end

function WishlistFrame:SetTileSize(newSize)
    newSize = math.max(MIN_TILE_SIZE, math.min(MAX_TILE_SIZE, newSize))
    if newSize == self.tileSize then return end

    self.tileSize = newSize

    -- Save to db
    local db = GetWishlistDB()
    if db then
        db.tileSize = newSize
    end

    addon:ApplyTileSizeToView(self)
end

function WishlistFrame:SelectRecord(recordID)
    local prevSelected = self.selectedRecordID
    self.selectedRecordID = recordID
    self.currentRecordID = recordID  -- For action buttons context

    -- Update selection visuals
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

    -- Update preview
    self:ShowPreview(recordID)
end

--------------------------------------------------------------------------------
-- Preview
--------------------------------------------------------------------------------

function WishlistFrame:RecalculateDetailsHeight()
    if not self.detailsArea then return end

    local AB = CONSTS.ACTION_BUTTON
    local height = DETAILS_PADDING  -- Top padding

    -- Name (word wrapped, up to 2 lines)
    if self.detailsName:IsShown() then
        height = height + self.detailsName:GetStringHeight() + DETAILS_SPACING
    end

    -- Owned row (may include placed count inline)
    if self.detailsOwned:IsShown() then
        height = height + self.detailsOwned:GetStringHeight() + DETAILS_PADDING
    end

    -- Source text (word wrapped, variable lines)
    local sourceText = self.detailsSource:GetText()
    if self.detailsSource:IsShown() and sourceText and sourceText ~= "" then
        height = height + self.detailsSource:GetStringHeight() + DETAILS_PADDING
    end

    -- Actions row
    height = height + AB.HEIGHT + 4 + DETAILS_PADDING

    self.detailsArea:SetHeight(math.max(DETAILS_MIN_HEIGHT, height))
end

-- Lightweight ownership-only refresh (no model rebuild, no name/source update)
function WishlistFrame:UpdateOwnershipDetails(record)
    local L = addon.L

    -- Owned count
    if record.totalOwned and record.totalOwned > 0 then
        self.detailsOwned:SetText(string.format(L["DETAILS_OWNED"], record.totalOwned))
        self.detailsOwned:SetTextColor(0.2, 0.8, 0.2)
    else
        self.detailsOwned:SetText(L["DETAILS_NOT_OWNED"])
        self.detailsOwned:SetTextColor(0.6, 0.6, 0.6)
    end
    self.detailsOwned:Show()

    -- Placed count
    if record.numPlaced and record.numPlaced > 0 then
        self.detailsPlaced:SetText(string.format(L["DETAILS_PLACED"], record.numPlaced))
        self.detailsPlaced:Show()
    else
        self.detailsPlaced:Hide()
    end

    -- Action buttons (track/wishlist state may depend on ownership)
    self:UpdateActionButtons(record)

    -- Recalculate details height (owned/placed visibility may have changed)
    self:RecalculateDetailsHeight()
end

function WishlistFrame:ShowPreview(recordID)
    -- Guard against preview updates when frame is hidden (edge case from hover transitions)
    if not self.frame or not self.frame:IsShown() then return end

    local L = addon.L
    local record = addon:GetRecord(recordID)

    if not record then
        self:ClearPreview()
        return
    end

    -- Store current record ID for action buttons
    self.currentRecordID = recordID

    -- Hide placeholder
    self.detailsPlaceholder:Hide()

    -- Name
    self.detailsName:SetText(record.name or L["UNKNOWN"])
    self.detailsName:Show()

    -- Owned count
    if record.totalOwned and record.totalOwned > 0 then
        self.detailsOwned:SetText(string.format(L["DETAILS_OWNED"], record.totalOwned))
        self.detailsOwned:SetTextColor(0.2, 0.8, 0.2)
    else
        self.detailsOwned:SetText(L["DETAILS_NOT_OWNED"])
        self.detailsOwned:SetTextColor(0.6, 0.6, 0.6)
    end
    self.detailsOwned:Show()

    -- Placed count
    if record.numPlaced and record.numPlaced > 0 then
        self.detailsPlaced:SetText(string.format(L["DETAILS_PLACED"], record.numPlaced))
        self.detailsPlaced:Show()
    else
        self.detailsPlaced:Hide()
    end

    -- Source
    if record.sourceText and record.sourceText ~= "" then
        self.detailsSource:SetText(record.sourceText)
    else
        self.detailsSource:SetText(L["DETAILS_SOURCE_UNKNOWN"])
    end
    self.detailsSource:Show()

    -- Update action buttons
    self:UpdateActionButtons(record)

    -- Recalculate details area height based on content
    self:RecalculateDetailsHeight()

    -- Model
    if not record.modelAsset then
        self:ShowFallback(L["PREVIEW_NO_MODEL"], record.icon, record.iconType)
        return
    end

    -- Transition to appropriate scene
    local sceneID = record.modelSceneID or SCENE_PRESETS[record.size] or DEFAULT_SCENE_ID
    self.modelScene:TransitionToModelSceneID(sceneID, CAMERA_IMMEDIATE, CAMERA_DISCARD, true)

    -- Configure orbit camera controls (re-apply after each CAMERA_DISCARD transition)
    local camera = self.modelScene:GetActiveCamera()
    if camera then
        addon.Preview:ConfigureOrbitCameraControls(camera)
    end

    local actor = self.modelScene:GetActorByTag("decor") or self.modelScene:GetActorByTag("item")
    if not actor then
        self:ShowFallback(L["PREVIEW_ERROR"], record.icon, record.iconType)
        return
    end

    actor:SetPreferModelCollisionBounds(true)
    actor:SetModelByFileID(record.modelAsset)

    self.fallbackContainer:Hide()
    self.modelScene:Show()
end

function WishlistFrame:ShowFallback(message, icon, iconType)
    if self.modelScene then self.modelScene:Hide() end

    if icon then
        addon:SetIcon(self.fallbackIcon, icon, iconType)
    end
    self.fallbackIcon:SetShown(icon ~= nil)

    self.fallbackMessage:SetText(message or "")
    self.fallbackContainer:Show()
end

function WishlistFrame:ClearPreview()
    -- Clear current record
    self.currentRecordID = nil

    -- Show placeholder, hide details
    self.detailsPlaceholder:Show()
    self.detailsName:Hide()
    self.detailsOwned:Hide()
    self.detailsPlaced:Hide()
    self.detailsSource:Hide()

    -- Reset action buttons to disabled state
    self:UpdateWishlistButton()
    self.trackButton:SetText(addon.L["ACTION_TRACK"])
    self.trackButton:SetEnabled(false)
    self.trackButton:SetActive(false)
    self.linkButton:SetEnabled(false)

    -- Clear model
    if self.modelScene then
        local actor = self.modelScene:GetActorByTag("decor") or self.modelScene:GetActorByTag("item")
        if actor then actor:ClearModel() end
        self.modelScene:Hide()
    end
    self.fallbackContainer:Hide()

    -- Reset details area to minimum height
    self.detailsArea:SetHeight(DETAILS_MIN_HEIGHT)
end

--------------------------------------------------------------------------------
-- Visibility & Layout
--------------------------------------------------------------------------------

function WishlistFrame:Show()
    if InCombatLockdown() then
        addon:Print(addon.L["COMBAT_LOCKDOWN_MESSAGE"])
        return false
    end

    if not self.frame then
        self:Create()
    end

    self:RefreshData()

    -- Validate selection still exists in wishlist
    if self.selectedRecordID and not addon:IsWishlisted(self.selectedRecordID) then
        self.selectedRecordID = nil
        self.currentRecordID = nil
        self:ClearPreview()
    end

    self.frame:Show()
    self.frame:Raise()

    return true
end

function WishlistFrame:Hide()
    if not self.frame then return end

    -- Cancel pending timers before hiding
    self:CancelTimers()
    self.frame:Hide()
end

function WishlistFrame:CancelTimers()
    if self.tileSizeSlider and self.tileSizeSlider.debounceTimer then
        self.tileSizeSlider.debounceTimer:Cancel()
        self.tileSizeSlider.debounceTimer = nil
    end
    if self.resizeTimer then
        self.resizeTimer:Cancel()
        self.resizeTimer = nil
    end
end

function WishlistFrame:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function WishlistFrame:IsShown()
    return self.frame and self.frame:IsShown()
end

function WishlistFrame:SaveLayout()
    local db = GetWishlistDB()
    if not db or not self.frame then return end

    -- Save position
    local point, _, relativePoint, xOfs, yOfs = self.frame:GetPoint()
    if point then
        db.position = {
            point = point,
            relativePoint = relativePoint or "CENTER",
            xOfs = xOfs or 0,
            yOfs = yOfs or 0,
        }
    end

    -- Save size
    local width, height = self.frame:GetSize()
    if width and height then
        db.size = { width = width, height = height }
    end
end

function WishlistFrame:RestoreLayout()
    local db = GetWishlistDB()
    if not db or not self.frame then return end

    local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()

    -- Restore position
    if db.position then
        local pos = db.position
        self.frame:ClearAllPoints()
        self.frame:SetPoint(pos.point, UIParent, pos.relativePoint or "CENTER", pos.xOfs or 0, pos.yOfs or 0)
    end

    -- Restore size (clamped to screen bounds)
    local size = db.size or {}
    local w = math.min(math.max(size.width or DEFAULT_WIDTH, MIN_WIDTH), screenWidth)
    local h = math.min(math.max(size.height or DEFAULT_HEIGHT, MIN_HEIGHT), screenHeight)
    self.frame:SetSize(w, h)
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

-- Helper: Refresh action buttons for current preview item
local function RefreshCurrentActionButtons()
    if not WishlistFrame:IsShown() or not WishlistFrame.currentRecordID then return end
    local record = addon:GetRecord(WishlistFrame.currentRecordID)
    if record then
        WishlistFrame:UpdateActionButtons(record)
    end
end

-- Refresh when wishlist changes
addon:RegisterInternalEvent("WISHLIST_CHANGED", function(recordID, isWishlisted)
    if WishlistFrame:IsShown() then
        WishlistFrame:RefreshData()

        -- Clear selection if selected item was removed
        if not isWishlisted and WishlistFrame.selectedRecordID == recordID then
            WishlistFrame.selectedRecordID = nil
            WishlistFrame.currentRecordID = nil
            WishlistFrame:ClearPreview()
        elseif WishlistFrame.currentRecordID == recordID then
            -- Update wishlist button state
            WishlistFrame:UpdateWishlistButton()
        end
    end
end)

-- Refresh when record ownership changes
addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function(recordID)
    if not WishlistFrame:IsShown() then return end

    -- Always refresh tiles (owned state affects all visible items)
    if WishlistFrame.scrollBox then
        WishlistFrame.scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    end

    -- Only update preview details if this record matches (or bulk refresh)
    if WishlistFrame.currentRecordID then
        if recordID ~= nil and recordID ~= WishlistFrame.currentRecordID then return end
        local record = addon:GetRecord(WishlistFrame.currentRecordID)
        if record then
            WishlistFrame:UpdateOwnershipDetails(record)
        end
    end
end)

-- Update track button when tracking state changes externally
addon:RegisterInternalEvent("TRACKING_CHANGED", function(recordID)
    if WishlistFrame.currentRecordID == recordID then
        RefreshCurrentActionButtons()
    end
end)
