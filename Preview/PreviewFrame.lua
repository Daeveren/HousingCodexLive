--[[
    Housing Codex - PreviewFrame.lua
    Docked 3D preview panel (right side of MainFrame)
]]

local ADDON_NAME, addon = ...

-- Add preview constants to central CONSTANTS table
addon.CONSTANTS.PREVIEW_DEFAULT_WIDTH = 400  -- Fixed docked width

local COLORS = addon.CONSTANTS.COLORS

-- Details panel constants (1C.6)
local DETAILS_MIN_HEIGHT = 60   -- Minimum height when empty/placeholder
local PADDING = 8
local SPACING_SMALL = 2
local METADATA_GAP = 4          -- Extra spacing before metadata row
local DIVIDER_OFFSET = 1        -- Inset from left edge to clear MainFrame divider

-- Size API values to localization keys
local SIZE_KEYS = {
    [0] = nil,           -- No size
    [65] = "SIZE_TINY",
    [66] = "SIZE_SMALL",
    [67] = "SIZE_MEDIUM",
    [68] = "SIZE_LARGE",
    [69] = "SIZE_HUGE",
}

-- Camera constants (WoW globals with fallbacks)
local CAMERA_IMMEDIATE = CAMERA_TRANSITION_TYPE_IMMEDIATE or 1
local CAMERA_DISCARD = CAMERA_MODIFICATION_TYPE_DISCARD or 0

-- Width preset buttons (widths only, labels generated from index)
local WIDTH_PRESETS = { 500, 600, 700 }

-- Preset button colors
local COLOR_PRESET_INACTIVE = { 0.5, 0.5, 0.5, 0.8 }
local COLOR_PRESET_HOVER = { 0.8, 0.8, 0.8, 1 }
local COLOR_PRESET_ACTIVE = { 0.9, 0.75, 0.3, 1 }  -- Gold

-- Scene presets by Enum.HousingCatalogEntrySize values (0, 65-69)
-- record.size uses these actual enum values, not 0-5 indices
local SCENE_PRESETS = {
    [0] = 1317,   -- None -> DecorDefault
    [65] = 1333,  -- Tiny
    [66] = 1334,  -- Small
    [67] = 1335,  -- Medium
    [68] = 1336,  -- Large
    [69] = 1337,  -- Huge
}
local DEFAULT_SCENE_ID = 1317

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

-- Helper: Generate Wowhead URL for a decor item
local function CreateWowheadURL(record)
    local slug = record.name:lower()
    slug = slug:gsub("%s+", "-")        -- spaces to hyphens
    slug = slug:gsub("[^%w%-]", "")     -- remove non-alphanumeric except hyphens
    slug = slug:gsub("%-+", "-")        -- collapse multiple hyphens
    return string.format("https://www.wowhead.com/decor/%s-%d", slug, record.recordID)
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
    self:CreateCollapseButton()
    self:CreateContentArea()

    addon:Debug("PreviewFrame created (integrated)")
    return region
end

function Preview:CreateCollapseButton()
    local region = self.frame

    -- Collapse button floats at top-right of preview region (no title bar)
    local collapseBtn = addon:CreateToggleButton(region, "<", "PREVIEW_COLLAPSE", function()
        Preview:Hide()
    end)
    collapseBtn:SetPoint("TOPRIGHT", region, "TOPRIGHT", -2, -4)
    self.collapseButton = collapseBtn
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

    -- Enable mouse wheel zoom
    modelScene:EnableMouseWheel(true)
    modelScene:SetScript("OnMouseWheel", function(frame, delta)
        self:OnModelSceneMouseWheel(delta)
    end)
end

function Preview:OnModelSceneMouseWheel(delta)
    local camera = self.modelScene and self.modelScene:GetActiveCamera()
    if not camera or not camera.ZoomByPercent then return end

    camera:ZoomByPercent(delta * ZOOM_STEP)
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
    placeholder:SetText(addon.L["PREVIEW_NO_SELECTION"] or "Select an item to preview")
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

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
    local owned = addon:CreateFontString(details, "OVERLAY", "GameFontHighlightSmall")
    owned:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    owned:SetTextColor(0.7, 0.7, 0.7)
    self.detailsOwned = owned

    -- Source text (below owned, spans full width)
    -- No MaxLines limit - sourceText can contain multiple vendor sources with full formatting
    local source = addon:CreateFontString(details, "OVERLAY", "GameFontHighlightSmall")
    source:SetPoint("TOPLEFT", owned, "BOTTOMLEFT", 0, -PADDING)
    source:SetPoint("RIGHT", details, "RIGHT", -PADDING, 0)
    source:SetJustifyH("LEFT")
    source:SetWordWrap(true)
    source:SetTextColor(0.8, 0.8, 0.8)
    self.detailsSource = source

    -- ========== Metadata Section (1C.7) ==========
    -- Size row (anchored below source text with extra spacing)
    local sizeLabel = addon:CreateFontString(details, "OVERLAY", "GameFontHighlightSmall")
    sizeLabel:SetPoint("TOPLEFT", source, "BOTTOMLEFT", 0, -PADDING - METADATA_GAP)
    sizeLabel:SetText(addon.L["DETAILS_SIZE"] or "Size:")
    sizeLabel:SetTextColor(0.5, 0.5, 0.5)

    local sizeValue = addon:CreateFontString(details, "OVERLAY", "GameFontHighlightSmall")
    sizeValue:SetPoint("LEFT", sizeLabel, "RIGHT", 4, 0)
    sizeValue:SetTextColor(1, 1, 1)
    self.detailsSize = sizeValue

    -- Place (same line, after size)
    local placeLabel = addon:CreateFontString(details, "OVERLAY", "GameFontHighlightSmall")
    placeLabel:SetPoint("LEFT", sizeValue, "RIGHT", 12, 0)
    placeLabel:SetText(addon.L["DETAILS_PLACE"] or "Place:")
    placeLabel:SetTextColor(0.5, 0.5, 0.5)

    local placeValue = addon:CreateFontString(details, "OVERLAY", "GameFontHighlightSmall")
    placeValue:SetPoint("LEFT", placeLabel, "RIGHT", 4, 0)
    placeValue:SetTextColor(1, 1, 1)
    self.detailsPlacement = placeValue

    -- Dyeable (same line, after place)
    local dyeableValue = addon:CreateFontString(details, "OVERLAY", "GameFontHighlightSmall")
    dyeableValue:SetPoint("LEFT", placeValue, "RIGHT", 12, 0)
    self.detailsDyeable = dyeableValue

    -- Category (same line, after dyeable)
    local categoryValue = addon:CreateFontString(details, "OVERLAY", "GameFontHighlightSmall")
    categoryValue:SetPoint("LEFT", dyeableValue, "RIGHT", 12, 0)
    categoryValue:SetTextColor(unpack(COLOR_CATEGORY))
    self.detailsCategory = categoryValue

    -- ========== Actions Row (1C.9) ==========
    self:CreateActionsRow(details, sizeLabel)

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
        addon.L["ACTION_TRACK"] or "Track",
        function() self:OnTrackButtonClick() end,
        function(btn) self:ShowTrackButtonTooltip(btn) end
    )
    trackBtn:SetPoint("LEFT", wishlistBtn, "RIGHT", AB.SPACING + 4, 0)
    self.trackButton = trackBtn

    -- Link to Chat button (left-click: chat link, right-click: Wowhead URL)
    local linkBtn = addon:CreateActionButton(
        actionsRow,
        addon.L["ACTION_LINK"] or "Link",
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

-- URL popup for Wowhead link copy
local urlPopup = nil  -- Lazy init

local function CreateURLPopup()
    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetSize(400, 70)
    popup:SetFrameStrata("DIALOG")
    popup:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    popup:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    popup:SetBackdropBorderColor(0.6, 0.6, 0.6)
    popup:Hide()
    popup:EnableMouse(true)

    -- Close button (top-right)
    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 2, 2)
    closeBtn:SetSize(20, 20)
    closeBtn:SetScript("OnClick", function() popup:Hide() end)

    -- URL edit box
    local editBox = CreateFrame("EditBox", nil, popup)
    editBox:SetPoint("TOPLEFT", 10, -10)
    editBox:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    editBox:SetHeight(20)
    editBox:SetFontObject("GameFontHighlight")
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function() popup:Hide() end)
    popup.editBox = editBox

    -- Copy button
    local copyBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    copyBtn:SetSize(60, 22)
    copyBtn:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -10, 8)
    copyBtn:SetText("Copy")
    copyBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
        -- Note: WoW doesn't allow direct clipboard access, but highlighting makes Ctrl+C easy
    end)

    popup:SetScript("OnShow", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    return popup
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
        local name = record and record.name or "item"

        if isNowWishlisted then
            addon:Print(string.format(addon.L["WISHLIST_ADDED"] or "Added to wishlist: %s", name))
        else
            addon:Print(string.format(addon.L["WISHLIST_REMOVED"] or "Removed from wishlist: %s", name))
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
            and (addon.L["WISHLIST_REMOVE"] or "Remove from Wishlist")
            or (addon.L["WISHLIST_ADD"] or "Add to Wishlist")
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
    self.detailsName:SetText(record.name or "Unknown")
    self.detailsName:SetTextColor(1, 1, 1)

    -- Owned count (use totalOwned = placed + storage + redeemable)
    if record.totalOwned and record.totalOwned > 0 then
        self.detailsOwned:SetText(string.format(addon.L["DETAILS_OWNED"] or "Owned: %d", record.totalOwned))
        self.detailsOwned:SetTextColor(0.2, 0.8, 0.2)
    else
        self.detailsOwned:SetText(addon.L["DETAILS_NOT_OWNED"] or "Not Owned")
        self.detailsOwned:SetTextColor(0.6, 0.6, 0.6)
    end

    -- Source (use raw sourceText - FontStrings render texture escape sequences natively)
    local sourceText = record.sourceText
    if sourceText and sourceText ~= "" then
        self.detailsSource:SetText(sourceText)
    else
        self.detailsSource:SetText(addon.L["DETAILS_SOURCE_UNKNOWN"] or "Unknown source")
    end

    -- ========== Metadata (1C.7) ==========

    -- Size (use localized name or dash if no size)
    local sizeKey = SIZE_KEYS[record.size]
    self.detailsSize:SetText(sizeKey and addon.L[sizeKey] or "-")

    -- Place
    local placement = {}
    if record.isIndoors then table.insert(placement, addon.L["PLACEMENT_IN"] or "In") end
    if record.isOutdoors then table.insert(placement, addon.L["PLACEMENT_OUT"] or "Out") end
    self.detailsPlacement:SetText(#placement > 0 and table.concat(placement, "/") or "-")

    -- Dyeable
    if record.canCustomize then
        self.detailsDyeable:SetText(addon.L["DETAILS_DYEABLE"] or "Dyeable")
        self.detailsDyeable:SetTextColor(0.6, 0.8, 1)  -- Light blue
    else
        self.detailsDyeable:SetText(addon.L["DETAILS_NOT_DYEABLE"] or "Not Dyeable")
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

    self.detailsName:SetText(addon.L["PREVIEW_NO_SELECTION"] or "Select an item to preview")
    self.detailsName:SetTextColor(0.5, 0.5, 0.5)
    self.detailsOwned:SetText("")
    self.detailsSource:SetText("")
    self.detailsSize:SetText("-")
    self.detailsPlacement:SetText("-")
    self.detailsDyeable:SetText("")
    self.detailsCategory:SetText("")

    -- Reset action buttons to disabled state (wishlist uses UpdateWishlistButton which handles nil recordID)
    self:UpdateWishlistButton()
    if self.trackButton then
        self.trackButton:SetText(addon.L["ACTION_TRACK"] or "Track")
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

    -- Source (up to 5 lines, word wrapped)
    local sourceText = self.detailsSource:GetText()
    if sourceText and sourceText ~= "" then
        height = height + self.detailsSource:GetStringHeight()
        height = height + PADDING + METADATA_GAP
    end

    -- Metadata row (Size + Placement, single line)
    height = height + self.detailsSize:GetStringHeight()
    height = height + PADDING

    -- Actions row (1C.9) - uses shared button height constant
    local AB = addon.CONSTANTS.ACTION_BUTTON
    height = height + AB.HEIGHT + 4  -- Button height + padding
    height = height + PADDING  -- Bottom padding before divider

    -- Apply calculated height (with minimum)
    self.detailsArea:SetHeight(math.max(DETAILS_MIN_HEIGHT, height))
end

-- Note: ESC handling is done by MainFrame (cascading: preview closes first, then MainFrame)

-- ============================================================================
-- Actions (1C.9)
-- ============================================================================

-- Helper: Check if a record is currently being tracked
local function IsRecordTracked(recordID)
    return C_ContentTracking and
        C_ContentTracking.IsTracking(Enum.ContentTrackingType.Decor, recordID)
end

function Preview:UpdateActionButtons(record)
    if not self.trackButton or not self.linkButton then return end

    -- Wishlist button state
    self:UpdateWishlistButton()

    -- Track button state
    if record and record.isTrackable then
        self.trackButton:SetEnabled(true)
        local isTracking = IsRecordTracked(record.recordID)
        self.trackButton:SetActive(isTracking)  -- Gold highlight when tracking
        if isTracking then
            self.trackButton:SetText(addon.L["ACTION_UNTRACK"] or "Untrack")
        else
            self.trackButton:SetText(addon.L["ACTION_TRACK"] or "Track")
        end
    else
        self.trackButton:SetEnabled(false)
        self.trackButton:SetActive(false)
        self.trackButton:SetText(addon.L["ACTION_TRACK"] or "Track")
    end

    -- Link button is always enabled when an item is selected
    self.linkButton:SetEnabled(record ~= nil)
end

-- Helper: Set super tracking for map pin auto-select
local function SetSuperTracking(recordID)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedContent then
        C_SuperTrack.SetSuperTrackedContent(Enum.ContentTrackingType.Decor, recordID)
    end
end

function Preview:OnTrackButtonClick()
    local recordID = self.currentRecordID
    local record = recordID and addon:GetRecord(recordID)
    if not record or not record.isTrackable then return end

    if not C_ContentTracking then
        addon:Print(addon.L["ERROR_API_UNAVAILABLE"] or "API unavailable")
        return
    end

    -- Stop tracking if already tracked
    if IsRecordTracked(recordID) then
        C_ContentTracking.StopTracking(Enum.ContentTrackingType.Decor, recordID, Enum.ContentTrackingStopType.Manual)
        addon:Print(string.format(addon.L["TRACKING_STOPPED"] or "Stopped tracking: %s", record.name))
        self:UpdateActionButtons(record)
        addon:FireEvent("TRACKING_CHANGED", recordID)
        return
    end

    -- Start tracking
    local err = C_ContentTracking.StartTracking(Enum.ContentTrackingType.Decor, recordID)

    -- Handle result using error code lookup
    local ERROR_MESSAGES = {
        [Enum.ContentTrackingError.MaxTracked] = addon.L["TRACKING_ERROR_MAX"] or "Maximum tracked items reached",
        [Enum.ContentTrackingError.Untrackable] = addon.L["TRACKING_ERROR_UNTRACKABLE"] or "Cannot track this item",
    }

    if not err or err == Enum.ContentTrackingError.AlreadyTracked then
        SetSuperTracking(recordID)
        if not err then
            addon:Print(string.format(addon.L["TRACKING_STARTED"] or "Now tracking: %s", record.name))
        end
    elseif ERROR_MESSAGES[err] then
        addon:Print(ERROR_MESSAGES[err])
    else
        addon:Print("Tracking failed")
    end

    self:UpdateActionButtons(record)
    addon:FireEvent("TRACKING_CHANGED", recordID)
end

function Preview:OnLinkButtonClick()
    local recordID = self.currentRecordID
    local record = recordID and addon:GetRecord(recordID)
    if not record then return end

    -- Try to open chat if not already open
    local editBox = ChatFrame1EditBox
    if not editBox or not editBox:IsShown() then
        ChatFrame_OpenChat("")
        editBox = ChatFrame1EditBox
    end

    if editBox and editBox:IsShown() then
        local linkText = string.format("|cFFFFD100[%s]|r", record.name)
        editBox:Insert(linkText)
        addon:Print(addon.L["LINK_INSERTED"] or "Link inserted into chat")
    else
        addon:Print(addon.L["LINK_ERROR"] or "Unable to insert link")
    end
end

function Preview:OnLinkButtonRightClick()
    local recordID = self.currentRecordID
    local record = recordID and addon:GetRecord(recordID)
    if not record then return end

    -- Create popup lazily
    if not urlPopup then
        urlPopup = CreateURLPopup()
    end

    local url = CreateWowheadURL(record)
    urlPopup.editBox:SetText(url)

    -- Position near the Link button
    urlPopup:ClearAllPoints()
    urlPopup:SetPoint("TOPLEFT", self.linkButton, "BOTTOMLEFT", 0, -5)
    urlPopup:Show()
end

function Preview:ShowTrackButtonTooltip(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")

    local recordID = self.currentRecordID
    local record = recordID and addon:GetRecord(recordID)
    local L = addon.L

    -- Determine tooltip content based on tracking state
    local title, description, r, g, b
    if not record or not record.isTrackable then
        title = L["ACTION_TRACK"] or "Track"
        description = L["ACTION_TRACK_DISABLED_TOOLTIP"] or "This item cannot be tracked"
        r, g, b = 1, 0.5, 0.5
    elseif IsRecordTracked(recordID) then
        title = L["ACTION_UNTRACK"] or "Untrack"
        description = L["ACTION_UNTRACK_TOOLTIP"] or "Stop tracking this item"
        r, g, b = 1, 1, 1
    else
        title = L["ACTION_TRACK"] or "Track"
        description = L["ACTION_TRACK_TOOLTIP"] or "Track this item in the objectives tracker"
        r, g, b = 1, 1, 1
    end

    GameTooltip:SetText(title)
    GameTooltip:AddLine(description, r, g, b)
    GameTooltip:Show()
end

function Preview:ShowLinkButtonTooltip(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText(addon.L["ACTION_LINK"] or "Link")
    GameTooltip:AddLine(addon.L["ACTION_LINK_TOOLTIP"] or "Insert item link into chat", 1, 1, 1)
    GameTooltip:AddLine(addon.L["ACTION_LINK_TOOLTIP_RIGHTCLICK"] or "Right-click: Copy Wowhead URL", 0.7, 0.7, 0.7)
    GameTooltip:Show()
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
        self:ShowFallback(addon.L["PREVIEW_ERROR"])
        self:ClearDetails()
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

    -- Transition to appropriate scene preset
    local sceneID = record.modelSceneID or SCENE_PRESETS[record.size] or DEFAULT_SCENE_ID
    self.modelScene:TransitionToModelSceneID(sceneID, CAMERA_IMMEDIATE, CAMERA_DISCARD, true)

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
        addon:Print(addon.L["COMBAT_LOCKDOWN_MESSAGE"] or "Cannot open during combat")
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

    if addon.db then
        addon.db.preview.isOpen = true
    end

    addon:FireEvent("PREVIEW_VISIBILITY_CHANGED")
    return true
end

function Preview:Hide()
    if not self:IsShown() then return end

    addon.MainFrame:CollapsePreview()

    if addon.db then
        addon.db.preview.isOpen = false
    end

    addon:FireEvent("PREVIEW_VISIBILITY_CHANGED")
end

function Preview:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function Preview:IsShown()
    local region = addon.MainFrame and addon.MainFrame.previewRegion
    return region and region:IsShown()
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

    -- Only update preview content if preview is already visible
    -- Preview does NOT auto-open on selection (user must click tile or use preview button)
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
    if record then
        Preview:UpdateActionButtons(record)
    end
end

-- Update track button when tracking state changes externally
addon:RegisterInternalEvent("TRACKING_CHANGED", function(recordID)
    if Preview.currentRecordID == recordID then
        RefreshCurrentActionButtons()
    end
end)

-- Listen for WoW's tracking update event (catches changes from other UI)
local trackingFrame = CreateFrame("Frame")
trackingFrame:RegisterEvent("CONTENT_TRACKING_UPDATE")
trackingFrame:SetScript("OnEvent", function(_, event, trackingType)
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
