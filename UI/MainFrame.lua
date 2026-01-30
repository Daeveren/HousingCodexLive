--[[
    Housing Codex - MainFrame.lua
    Main window with DaevTools styling
]]

local ADDON_NAME, addon = ...

local COLORS = addon.CONSTANTS.COLORS
local MIN_WIDTH = addon.CONSTANTS.MIN_FRAME_WIDTH
local MIN_HEIGHT = addon.CONSTANTS.MIN_FRAME_HEIGHT
local DEFAULT_WIDTH = addon.CONSTANTS.DEFAULT_FRAME_WIDTH
local DEFAULT_HEIGHT = addon.CONSTANTS.DEFAULT_FRAME_HEIGHT
local SIDEBAR_WIDTH = addon.CONSTANTS.SIDEBAR_WIDTH
local HEADER_HEIGHT = addon.CONSTANTS.HEADER_HEIGHT

local MAIN_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

addon.MainFrame = {}
local MainFrame = addon.MainFrame

function MainFrame:Create()
    if self.frame then return self.frame end

    -- Main frame
    local frame = CreateFrame("Frame", "HousingCodexMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
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
    titleBg:SetColorTexture(0.08, 0.08, 0.1, 0.95)

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
        MainFrame:SavePosition()
    end)
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
        text:SetTextColor(1, 0.4, 0.4, 1)  -- Red-ish for error
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

    -- Preview region (starts hidden, expanded via ExpandForPreview)
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

function MainFrame:GetPreviewWidth()
    local db = addon.db
    return db and db.preview.width or addon.CONSTANTS.PREVIEW_DEFAULT_WIDTH
end

function MainFrame:ExpandForPreview()
    local frame = self.frame
    local previewWidth = self:GetPreviewWidth()

    self.previewRegion:SetWidth(previewWidth)
    frame:SetWidth(frame:GetWidth() + previewWidth)
    frame:SetResizeBounds(MIN_WIDTH + previewWidth, MIN_HEIGHT, GetScreenWidth(), GetScreenHeight())

    -- Anchor content to stop at preview region
    self.contentArea:ClearAllPoints()
    self.contentArea:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 0, 0)
    self.contentArea:SetPoint("BOTTOMRIGHT", self.previewRegion, "BOTTOMLEFT", 0, 0)

    self.previewRegion:Show()
end

function MainFrame:CollapsePreview()
    local frame = self.frame
    local previewWidth = self:GetPreviewWidth()

    -- Anchor content back to frame edge
    self.contentArea:ClearAllPoints()
    self.contentArea:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 0, 0)
    self.contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)

    self.previewRegion:Hide()
    frame:SetWidth(frame:GetWidth() - previewWidth)
    frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, GetScreenWidth(), GetScreenHeight())
end

function MainFrame:SetPreviewWidth(newWidth)
    local region = self.previewRegion
    if not region or not region:IsShown() then return end

    local frame = self.frame
    local widthDelta = newWidth - self:GetPreviewWidth()

    if addon.db then
        addon.db.preview.width = newWidth
    end

    region:SetWidth(newWidth)
    frame:SetWidth(frame:GetWidth() + widthDelta)
    frame:SetResizeBounds(MIN_WIDTH + newWidth, MIN_HEIGHT, GetScreenWidth(), GetScreenHeight())
end

function MainFrame:SetupResizing()
    local frame = self.frame
    local grip = self.resizeGrip

    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame:StartSizing("BOTTOMRIGHT", true)
        end
    end)

    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        MainFrame:SaveSize()
    end)
end

function MainFrame:SavePosition()
    local frame = self.frame
    if not frame or not addon.db then return end

    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
    if point then
        addon.db.framePosition = {
            point = point,
            relativePoint = relativePoint or "CENTER",
            xOfs = xOfs or 0,
            yOfs = yOfs or 0,
        }
    end
end

function MainFrame:SaveSize()
    local frame = self.frame
    if not frame or not addon.db then return end

    local width, height = frame:GetSize()
    if width and height then
        -- Save base width (subtract preview if open)
        if self.previewRegion and self.previewRegion:IsShown() then
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
            frame:SetPoint(pos.point, UIParent, pos.relativePoint or "CENTER", pos.xOfs or 0, pos.yOfs or 0)
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
end

function MainFrame:Show()
    if InCombatLockdown() then
        addon:Print(addon.L["COMBAT_LOCKDOWN_MESSAGE"])
        return false
    end

    local isFirstShow = not self.frame
    if not self.frame then
        self:Create()
    end

    -- Enable searcher auto-update while visible (Blizzard pattern)
    if addon.catalogSearcher then
        addon.catalogSearcher:SetAutoUpdateOnParamChanges(true)
    end

    self.frame:Show()
    self.frame:Raise()

    -- Restore preview state from last session (only on first show after login/reload)
    if isFirstShow and addon.db and addon.db.preview.isOpen then
        C_Timer.After(0.05, function()
            if addon.Preview then
                addon.Preview:Show()
            end
        end)
    end

    return true
end

function MainFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end

    -- Disable searcher auto-update when hidden (Blizzard pattern)
    if addon.catalogSearcher then
        addon.catalogSearcher:SetAutoUpdateOnParamChanges(false)
    end
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
