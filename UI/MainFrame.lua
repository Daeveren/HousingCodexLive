--[[
    Housing Codex - MainFrame.lua
    Main window with DaevTools styling
]]

local _, addon = ...

local COLORS = addon.CONSTANTS.COLORS
local MIN_WIDTH = addon.CONSTANTS.MIN_FRAME_WIDTH
local MIN_HEIGHT = addon.CONSTANTS.MIN_FRAME_HEIGHT
local DEFAULT_WIDTH = addon.CONSTANTS.DEFAULT_FRAME_WIDTH
local DEFAULT_HEIGHT = addon.CONSTANTS.DEFAULT_FRAME_HEIGHT
local SIDEBAR_WIDTH = addon.CONSTANTS.SIDEBAR_WIDTH
local HEADER_HEIGHT = addon.CONSTANTS.HEADER_HEIGHT
local SCREEN_MARGIN = 20

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function IsUsableNumber(value)
    return type(value) == "number" and not IsSecretValue(value)
end

local function GetUsableScreenSize()
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()

    if not IsUsableNumber(screenWidth) or screenWidth <= 0 then
        screenWidth = DEFAULT_WIDTH
    end
    if not IsUsableNumber(screenHeight) or screenHeight <= 0 then
        screenHeight = DEFAULT_HEIGHT
    end

    return screenWidth, screenHeight
end

local MAIN_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

addon.MainFrame = {}
local MainFrame = addon.MainFrame

-- Content area initializer registry
MainFrame.contentAreaInitializers = {}

function MainFrame:RegisterContentAreaInitializer(key, fn)
    for _, entry in ipairs(self.contentAreaInitializers) do
        if entry.key == key then
            addon:Debug("RegisterContentAreaInitializer: duplicate key '" .. key .. "', ignoring")
            return
        end
    end

    table.insert(self.contentAreaInitializers, { key = key, fn = fn })

    if self.contentArea then
        xpcall(fn, CallErrorHandler, self.contentArea)
    end
end

function MainFrame:RunContentAreaInitializers()
    if not self.contentArea then return end

    for _, entry in ipairs(self.contentAreaInitializers) do
        xpcall(entry.fn, CallErrorHandler, self.contentArea)
    end
end

function MainFrame:Create()
    if self.frame then return self.frame end

    -- Main frame
    local frame = CreateFrame("Frame", "HousingCodexMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(false)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, GetScreenWidth(), GetScreenHeight())
    frame:EnableMouse(true)
    frame:Hide()

    self.frame = frame

    -- Apply backdrop
    frame:SetBackdrop(MAIN_BACKDROP)
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Create layout regions
    self:CreateTitleBar()
    self:CreateSidebar()
    self:CreateContentArea()
    self:CreateLoadingOverlay()
    self:CreateResizeHandle()
    self:CreatePreviewRegion()

    -- Setup behaviors
    self:SetupResizing()
    self:SetupESCHandling()

    -- Restore saved layout
    self:RestoreLayout()

    -- Deferred initial tab layout (titleBar anchor widths resolve next frame)
    C_Timer.After(0, function()
        self:UpdateTabLayout()
    end)

    -- Add to special frames for ESC handling
    tinsert(UISpecialFrames, "HousingCodexMainFrame")

    addon:Debug("MainFrame created")

    return frame
end

function MainFrame:CreateTitleBar()
    local frame = self.frame

    -- Title bar background
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 3, -3)
    titleBar:SetPoint("TOPRIGHT", -3, -3)
    titleBar:SetHeight(HEADER_HEIGHT)
    self.titleBar = titleBar

    -- Title bar texture
    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(unpack(COLORS.TITLEBAR_BG))

    -- Addon icon
    local icon = titleBar:CreateTexture(nil, "ARTWORK")
    icon:SetSize(25, 25)
    icon:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    icon:SetTexture("Interface\\AddOns\\HousingCodex\\HC64")
    self.titleIcon = icon

    -- Title text (anchored after icon)
    local title = addon:CreateFontString(titleBar, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText(addon.L["ADDON_NAME"])
    title:SetTextColor(unpack(COLORS.TITLE))
    self.titleText = title

    -- Idle gold shimmer: a soft highlight sweeps the title every few seconds
    -- while shown (interval/direction logic lives in UI/Animations.lua)
    addon:AttachGoldShimmer(title, frame, COLORS.TITLE)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function()
        MainFrame:Hide()
    end)
    self.closeButton = closeBtn

    -- Wishlist button (before close button)
    self:CreateWishlistButton(titleBar)

    -- Create horizontal tabs in title bar (after title text)
    if addon.Tabs then
        addon.Tabs:Create(titleBar, title)
    end

    -- Make title bar draggable
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        frame:SetUserPlaced(false)
        MainFrame:SavePosition()
    end)
end

function MainFrame:UpdateTabLayout()
    if not addon.Tabs or not addon.Tabs.container then return end
    if not self.titleBar then return end

    local titleBarWidth = self.titleBar:GetWidth()
    if not titleBarWidth or titleBarWidth <= 0 then return end

    -- Left reserved: icon offset(12) + icon(25) + gap(8) + titleText + gap(16)
    local titleTextWidth = self.titleText and self.titleText:GetStringWidth() or 120
    local leftReserved = 12 + 25 + 8 + titleTextWidth + 16

    -- Right reserved: wishlist button + gap(8) + close button(~32)
    local wishlistWidth = self.wishlistButton and self.wishlistButton:GetWidth() or 100
    local rightReserved = wishlistWidth + 8 + 32

    local availableForTabs = titleBarWidth - leftReserved - rightReserved
    addon.Tabs:UpdateLayout(availableForTabs)
end

function MainFrame:CreateWishlistButton(titleBar)
    local AB = addon.CONSTANTS.ACTION_BUTTON
    local L = addon.L

    -- Button container with star icon + text
    local btn = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    btn:SetBackdrop(addon.CONSTANTS.TOGGLE_BUTTON_BACKDROP)
    btn:SetBackdropColor(unpack(AB.COLOR_NORMAL))
    btn:SetBackdropBorderColor(unpack(AB.COLOR_BORDER_NORMAL))

    -- Star icon
    local starIcon = btn:CreateTexture(nil, "ARTWORK")
    starIcon:SetSize(19, 19)
    starIcon:SetPoint("LEFT", 8, 0)
    starIcon:SetAtlas("PetJournal-FavoritesIcon")
    starIcon:SetVertexColor(unpack(COLORS.GOLD))
    btn.starIcon = starIcon

    -- Text label
    local label = addon:CreateFontString(btn, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", starIcon, "RIGHT", 4, 0)
    label:SetText(L["WISHLIST_BUTTON"])
    label:SetTextColor(unpack(COLORS.GOLD))
    btn.label = label

    -- Calculate button width based on content
    local btnWidth = 8 + 19 + 4 + label:GetStringWidth() + 8
    btn:SetSize(btnWidth, 24)

    -- Position before close button (3px below to align visually)
    btn:SetPoint("RIGHT", self.closeButton, "LEFT", -8, -3)

    btn:SetScript("OnEnter", function(b)
        b:SetBackdropColor(unpack(AB.COLOR_HOVER))
        b:SetBackdropBorderColor(0.6, 0.5, 0.1, 1)
        GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["WISHLIST_BUTTON_TOOLTIP"])
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
        -- Hide main frame and show wishlist
        MainFrame:Hide()
        if addon.WishlistFrame then
            addon.WishlistFrame:Show()
        end
    end)

    self.wishlistButton = btn
end

function MainFrame:CreateSidebar()
    local frame = self.frame

    -- Sidebar frame
    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", self.titleBar, "BOTTOMLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, 3)
    sidebar:SetWidth(SIDEBAR_WIDTH)
    self.sidebar = sidebar

    -- Sidebar background
    local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
    sidebarBg:SetAllPoints()
    sidebarBg:SetColorTexture(unpack(COLORS.SIDEBAR_BG))

    -- Initialize category navigation
    if addon.Categories then
        addon.Categories:Initialize(sidebar)
    end
end

function MainFrame:CreateContentArea()
    local frame = self.frame

    -- Content area (between sidebar and details panel)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    self.contentArea = content

    local contentBg = content:CreateTexture(nil, "BACKGROUND")
    contentBg:SetAllPoints()
    contentBg:SetColorTexture(unpack(COLORS.CONTENT_BG))

    self:RunContentAreaInitializers()

    -- Restore saved tab after all initializers have run
    if addon.Tabs then
        addon.Tabs:RestoreSavedTab()
    end
end

function MainFrame:CreateLoadingOverlay()
    local overlay = CreateFrame("Frame", nil, self.contentArea)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(self.contentArea:GetFrameLevel() + 10)
    self.loadingOverlay = overlay

    local bg = overlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.7)

    local text = addon:CreateFontString(overlay, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    text:SetText(addon.L["LOADING_DATA"])
    text:SetTextColor(unpack(COLORS.TITLE))
    self.loadingText = text

    addon:RegisterInternalEvent("DATA_LOADED", function()
        overlay:Hide()
    end)

    addon:RegisterInternalEvent("DATA_LOAD_FAILED", function()
        text:SetText(addon.L["ERROR_LOAD_FAILED_SHORT"])
        text:SetTextColor(1, 0.4, 0.4, 1)
    end)

    overlay:SetShown(not addon.dataLoaded)
end

function MainFrame:CreateResizeHandle()
    local GRIP_SIZE = 16
    local GRIP_FRAME_LEVEL_OFFSET = 20  -- Must be above preview ModelScene

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
end

function MainFrame:CreatePreviewRegion()
    local frame = self.frame
    local DIVIDER_WIDTH = 1

    -- Preview region (always visible, expanded on first MainFrame:Show)
    local region = CreateFrame("Frame", nil, frame)
    region:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3 - HEADER_HEIGHT)
    region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    region:SetWidth(addon.CONSTANTS.PREVIEW_DEFAULT_WIDTH)
    region:Hide()
    self.previewRegion = region

    -- Solid background prevents ModelScene transparency bleed-through
    local bg = region:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1)

    -- Vertical divider separating content area from preview
    local divider = region:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(DIVIDER_WIDTH)
    divider:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    divider:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0)
    divider:SetColorTexture(0, 0, 0, 1)
end

function MainFrame:GetMaxFrameSize()
    local screenWidth, screenHeight = GetUsableScreenSize()
    return math.max(1, screenWidth - (SCREEN_MARGIN * 2)),
        math.max(1, screenHeight - (SCREEN_MARGIN * 2))
end

function MainFrame:GetMaxPreviewWidth()
    local maxFrameWidth = self:GetMaxFrameSize()
    return math.max(1, maxFrameWidth - math.min(MIN_WIDTH, maxFrameWidth))
end

function MainFrame:ClampPreviewWidth(width)
    local previewWidth = IsUsableNumber(width) and width or addon.CONSTANTS.PREVIEW_DEFAULT_WIDTH
    return math.max(1, math.min(previewWidth, self:GetMaxPreviewWidth()))
end

function MainFrame:GetPreviewWidth()
    local db = addon.db
    local previewWidth = db and db.preview and db.preview.width or addon.CONSTANTS.PREVIEW_DEFAULT_WIDTH
    return self:ClampPreviewWidth(previewWidth)
end

function MainFrame:GetAppliedPreviewWidth()
    if self.previewRegion and (self.previewRegion:IsShown() or self.previewCollapsed) then
        return self:GetPreviewWidth()
    end

    return 0
end

function MainFrame:ApplyResizeBounds(previewWidth)
    local frame = self.frame
    if not frame then return end

    local maxWidth, maxHeight = self:GetMaxFrameSize()
    local preview = previewWidth and previewWidth > 0 and self:ClampPreviewWidth(previewWidth) or 0
    local minWidth = math.min(MIN_WIDTH + preview, maxWidth)
    local minHeight = math.min(MIN_HEIGHT, maxHeight)

    frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)

    local width, height = frame:GetSize()
    if not IsUsableNumber(width) or not IsUsableNumber(height) then return end

    local clampedWidth = math.min(math.max(width, minWidth), maxWidth)
    local clampedHeight = math.min(math.max(height, minHeight), maxHeight)

    if clampedWidth ~= width or clampedHeight ~= height then
        frame:SetSize(clampedWidth, clampedHeight)
    end
end

function MainFrame:ExpandForPreview()
    local frame = self.frame
    local previewWidth = self:GetPreviewWidth()
    local frameWidth = frame:GetWidth()

    self.previewRegion:SetWidth(previewWidth)
    if IsUsableNumber(frameWidth) then
        frame:SetWidth(frameWidth + previewWidth)
    end
    self:ApplyResizeBounds(previewWidth)

    -- Anchor content to stop at preview region
    self.contentArea:ClearAllPoints()
    self.contentArea:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 0, 0)
    self.contentArea:SetPoint("BOTTOMRIGHT", self.previewRegion, "BOTTOMLEFT", 0, 0)

    self.previewRegion:Show()
    self.previewCollapsed = false
    self:ClampToScreen()
end

function MainFrame:CollapsePreview()
    if not self.previewRegion or not self.previewRegion:IsShown() then return end

    -- Hide ModelScene for GPU cleanup (same as OnMainFrameHide pattern)
    if addon.Preview then
        addon.Preview:OnMainFrameHide()
    end

    self.previewRegion:Hide()
    self.previewCollapsed = true  -- Preview space still allocated in frame width

    -- Expand content area to fill full width (frame stays same size)
    self.contentArea:ClearAllPoints()
    self.contentArea:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 0, 0)
    self.contentArea:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -3, 3)
end

function MainFrame:RestorePreview()
    if not self.previewRegion or self.previewRegion:IsShown() then return end
    if not addon.Preview then return end

    -- First-show edge case: preview never created yet
    if not addon.Preview.frame then
        if self.previewCollapsed then
            -- Frame already has preview width (expanded by delayed timer); just create preview
            addon.Preview:Create()
        else
            self.previewCollapsed = false
            addon.Preview:Show()  -- calls Create() + ExpandForPreview()
            return
        end
    end

    -- Normal case: frame already includes preview width, just restore visibility
    local previewWidth = self:GetPreviewWidth()
    self.previewRegion:SetWidth(previewWidth)
    self.previewRegion:Show()
    self.previewCollapsed = false
    self:ApplyResizeBounds(previewWidth)

    -- Restore content area to stop at preview region
    self.contentArea:ClearAllPoints()
    self.contentArea:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 0, 0)
    self.contentArea:SetPoint("BOTTOMRIGHT", self.previewRegion, "BOTTOMLEFT", 0, 0)
    self:ClampToScreen()

    if addon.Preview then
        addon.Preview:OnMainFrameShow()
    end
end

function MainFrame:SetPreviewWidth(newWidth)
    local region = self.previewRegion
    if not region or not region:IsShown() then return end

    local frame = self.frame
    local oldWidth = region:GetWidth()

    if addon.db then
        addon.db.preview.width = newWidth
    end

    local previewWidth = self:GetPreviewWidth()
    local widthDelta = previewWidth - (IsUsableNumber(oldWidth) and oldWidth or previewWidth)
    local frameWidth = frame:GetWidth()

    region:SetWidth(previewWidth)
    if IsUsableNumber(frameWidth) then
        frame:SetWidth(frameWidth + widthDelta)
    end
    self:ApplyResizeBounds(previewWidth)
    self:ClampToScreen()
end

function MainFrame:SetupResizing()
    local frame = self.frame
    local grip = self.resizeGrip

    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)

    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        frame:SetUserPlaced(false)
        MainFrame:SaveSize()
    end)

    -- Update tab layout on any frame resize
    frame:SetScript("OnSizeChanged", function()
        MainFrame:UpdateTabLayout()
    end)
end

function MainFrame:SavePosition()
    local frame = self.frame
    if not frame or not addon.db then return end

    -- Always save TOPLEFT position for consistent resize behavior
    local left = frame:GetLeft()
    local top = frame:GetTop()
    local screenHeight = GetScreenHeight()

    if left and top then
        addon.db.framePosition = {
            point = "TOPLEFT",
            relativePoint = "TOPLEFT",
            xOfs = left,
            yOfs = top - screenHeight,
        }
    end
end

function MainFrame:SaveSize()
    local frame = self.frame
    if not frame or not addon.db then return end

    local width, height = frame:GetSize()
    if width and height then
        -- Save base width (subtract preview if open or temporarily collapsed)
        if self.previewRegion and (self.previewRegion:IsShown() or self.previewCollapsed) then
            width = width - self:GetPreviewWidth()
        end
        addon.db.frameSize = { width = width, height = height }
    end
end

function MainFrame:SetupESCHandling()
    local frame = self.frame

    frame:SetScript("OnKeyDown", function(f, key)
        if key == "ESCAPE" then
            f:SetPropagateKeyboardInput(false)
            MainFrame:Hide()  -- Always close MainFrame directly
        else
            f:SetPropagateKeyboardInput(true)
        end
    end)
    frame:EnableKeyboard(true)
end

function MainFrame:RestoreLayout()
    local frame = self.frame
    if not frame or not addon.db then return end

    -- Restore position (supports legacy nested format: {position={...}} and current: {...})
    local posData = addon.db.framePosition
    if posData then
        local pos = posData.position or posData
        if pos.point then
            frame:ClearAllPoints()
            frame:SetPoint(pos.point, UIParent, pos.relativePoint or "TOPLEFT", pos.xOfs or 0, pos.yOfs or 0)
        end
    end

    -- Restore size (supports legacy nested format: {size={...}} and current: {...})
    local sizeData = addon.db.frameSize
    if sizeData then
        local size = sizeData.size or sizeData
        if size.width and size.height then
            local w = math.max(size.width, MIN_WIDTH)
            local h = math.max(size.height, MIN_HEIGHT)
            frame:SetSize(w, h)
        end
    end

    self:ApplyResizeBounds(0)

    -- Validate position for users with off-screen saved positions
    self:ValidatePosition()
end

function MainFrame:ValidatePosition()
    local frame = self.frame
    if not frame then return end

    local left, bottom, width, height = frame:GetRect()
    if not IsUsableNumber(left) or not IsUsableNumber(bottom) or
       not IsUsableNumber(width) or not IsUsableNumber(height) then
        return
    end

    local screenWidth, screenHeight = GetUsableScreenSize()
    local top = bottom + height
    local right = left + width

    -- If any edge is significantly off-screen, reset to center
    if left < -50 or right > screenWidth + 50 or
       top > screenHeight + 50 or bottom < -50 then
        self:ResetPosition()
    end
end

function MainFrame:ClampToScreen()
    local frame = self.frame
    if not frame then return end

    local left, bottom, width, height = frame:GetRect()
    if not IsUsableNumber(left) or not IsUsableNumber(bottom) or
       not IsUsableNumber(width) or not IsUsableNumber(height) then
        return
    end

    local screenWidth, screenHeight = GetUsableScreenSize()
    local marginX = width < screenWidth and SCREEN_MARGIN or 0
    local marginY = height < screenHeight and SCREEN_MARGIN or 0

    local newLeft = left
    if width >= screenWidth then
        newLeft = 0
    else
        local minLeft = marginX
        local maxLeft = math.max(minLeft, screenWidth - width - marginX)
        if left < minLeft then
            newLeft = minLeft
        elseif left > maxLeft then
            newLeft = maxLeft
        end
    end

    local newBottom = bottom
    if height >= screenHeight then
        newBottom = 0
    else
        local minBottom = marginY
        local maxBottom = math.max(minBottom, screenHeight - height - marginY)
        if bottom < minBottom then
            newBottom = minBottom
        elseif bottom > maxBottom then
            newBottom = maxBottom
        end
    end

    if newLeft ~= left or newBottom ~= bottom then
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", newLeft, newBottom)
    end
end

function MainFrame:ResetPosition()
    if addon.db then
        addon.db.framePosition = nil
    end
    addon:Print(addon.L["POSITION_RESET"])

    local frame = self.frame
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER")
end

function MainFrame:ResetSize()
    if addon.db then
        addon.db.frameSize = { width = DEFAULT_WIDTH, height = DEFAULT_HEIGHT }
    end
    addon:Print(addon.L["SIZE_RESET"])

    local frame = self.frame
    if not frame then return end
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    self:ApplyResizeBounds(self:GetAppliedPreviewWidth())
    self:ClampToScreen()
end

function MainFrame:Show()
    if InCombatLockdown() then
        addon:Print(addon.L["COMBAT_LOCKDOWN_MESSAGE"])
        return false
    end

    local isFirstShow = not self.frame
    if isFirstShow then
        self:Create()
    end

    self:ApplyResizeBounds(self:GetAppliedPreviewWidth())

    -- Ensure frame is on screen
    self:ClampToScreen()

    -- Enable searcher auto-update while visible (Blizzard pattern)
    addon:SetSearcherVisible(true)

    -- Dismiss welcome/whatsnew popup if the user is opening the main frame
    if addon.WhatsNew then
        addon.WhatsNew:DismissIfShowing()
    end

    self.frame:Show()
    self.frame:Raise()

    if addon.Preview then
        addon.Preview:OnMainFrameShow()
    end

    -- Handle deferred refreshes from when frame was hidden
    if addon.needsFullRefresh or addon.needsGridRefresh then
        addon:CountDebug("refresh", "deferred")
        addon.needsFullRefresh = false
        addon.needsGridRefresh = false
        if addon.catalogSearcher then
            addon:RunSearchNow("deferred refresh")
        elseif addon.Grid and addon.Tabs and addon.Tabs:GetCurrentTab() == "DECOR" then
            addon.Grid:Refresh()
        end
        if addon.Tabs and addon.Tabs:GetCurrentTab() == "PROGRESS" and addon.ProgressTab then
            addon.ProgressTab:RefreshDisplay(true)
        end
    end

    -- Always show preview on first show (preview is always visible)
    if isFirstShow then
        C_Timer.After(0.05, function()
            if not self.frame or not self.frame:IsShown() then return end
            if addon.Preview then
                addon.Preview:Show()
                -- Progress tab uses full width; collapse preview to reclaim content space
                if addon.Tabs and addon.Tabs:GetCurrentTab() == "PROGRESS" then
                    MainFrame:CollapsePreview()
                end
            end
        end)
    end

    return true
end

function MainFrame:Hide()
    if not self.frame then return end

    self.frame:Hide()
    addon:CancelPendingSearch()

    -- Cleanup preview ModelScene
    if addon.Preview then
        addon.Preview:OnMainFrameHide()
    end

    -- Disable searcher auto-update when hidden
    addon:SetSearcherVisible(false)
end

function MainFrame:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function MainFrame:IsShown()
    return self.frame and self.frame:IsShown()
end

addon:RegisterInternalEvent("DATA_LOADED", function()
    addon:Debug("MainFrame ready for display")
end)
