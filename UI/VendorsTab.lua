--[[
    Housing Codex - VendorsTab.lua
    Vendor sources tab with Expansion > Zone > Vendor hierarchy
]]

local ADDON_NAME, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS

local TOOLBAR_HEIGHT = CONSTS.HEADER_HEIGHT
local SIDEBAR_WIDTH = CONSTS.SIDEBAR_WIDTH
local EXPANSION_PANEL_WIDTH = CONSTS.HIERARCHY_PANEL_WIDTH
local HIERARCHY_PADDING = CONSTS.HIERARCHY_PADDING
local HEADER_HEIGHT = CONSTS.HIERARCHY_HEADER_HEIGHT
local GRID_OUTER_PAD = CONSTS.GRID_OUTER_PAD

local VENDOR_ROW_BASE_HEIGHT = 32
local DECOR_ROW_HEIGHT = 24
local ZONE_HEADER_HEIGHT = 28
local DECOR_ICON_SIZE = 22
local WAYPOINT_BUTTON_SIZE = 20

-- Helper to apply expansion button visual state
local function ApplyExpansionButtonState(frame, isSelected)
    if isSelected then
        frame.bg:SetColorTexture(unpack(COLORS.PANEL_HOVER))
        frame.selectionBorder:Show()
        frame.label:SetTextColor(unpack(COLORS.GOLD))
    else
        frame.bg:SetColorTexture(unpack(COLORS.PANEL_NORMAL))
        frame.selectionBorder:Hide()
        frame.label:SetTextColor(unpack(COLORS.TEXT_SECONDARY))
    end
end

addon.VendorsTab = {}
local VendorsTab = addon.VendorsTab

Mixin(VendorsTab, addon.TabBaseMixin)
VendorsTab.tabName = "VendorsTab"

local function GetVendorsDB()
    return addon.db and addon.db.browser and addon.db.browser.vendors
end

local function EnsureVendorsDB()
    if not addon.db then return nil end
    addon.db.browser = addon.db.browser or {}
    addon.db.browser.vendors = addon.db.browser.vendors or {
        selectedExpansionKey = nil,
        completionFilter = "incomplete",
        expandedZones = {},
    }
    return addon.db.browser.vendors
end

VendorsTab.frame = nil
VendorsTab.toolbar = nil
VendorsTab.expansionPanel = nil
VendorsTab.expansionScrollBox = nil
VendorsTab.vendorPanel = nil
VendorsTab.vendorScrollBox = nil
VendorsTab.vendorScrollBar = nil
VendorsTab.searchBox = nil
VendorsTab.filterButtons = {}
VendorsTab.emptyState = nil
VendorsTab.noExpansionState = nil

VendorsTab.selectedExpansionKey = nil
VendorsTab.selectedVendorNpcId = nil
VendorsTab.selectedDecorId = nil
VendorsTab.selectedVendorFrame = nil
VendorsTab.selectedDecorRow = nil
VendorsTab.hoveringRecordID = nil

VendorsTab.toolbarLayout = nil
VendorsTab.filterContainer = nil

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------

function VendorsTab:Create(parent)
    if self.frame then return end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    self.frame = frame

    self:CreateToolbar(frame)
    self:CreateExpansionPanel(frame)
    self:CreateVendorPanel(frame)
    self:CreateEmptyStates()

    addon:Debug("VendorsTab created")
end

function VendorsTab:Show()
    if not self.frame then return end

    if not addon.vendorIndexBuilt then
        addon:BuildVendorIndex()
    end

    self.frame:Show()
    EnsureVendorsDB()

    local saved = GetVendorsDB()
    if saved then
        self.selectedExpansionKey = saved.selectedExpansionKey
        self:SetCompletionFilter(saved.completionFilter or "incomplete")
        -- Reset expanded zones each session
        saved.expandedZones = {}
    end

    self:BuildExpansionDisplay()
    self:BuildVendorDisplay()
    self:UpdateEmptyStates()
end

function VendorsTab:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function VendorsTab:IsShown()
    return self.frame and self.frame:IsShown()
end

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------

function VendorsTab:CreateToolbar(parent)
    local L = addon.L

    local toolbar = CreateFrame("Frame", nil, parent)
    toolbar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    toolbar:SetHeight(TOOLBAR_HEIGHT)
    self.toolbar = toolbar

    local bg = toolbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.07, 0.9)

    local searchBox = CreateFrame("EditBox", nil, toolbar, "SearchBoxTemplate")
    searchBox:SetPoint("LEFT", toolbar, "LEFT", GRID_OUTER_PAD + 40, 0)
    searchBox:SetSize(200, 20)
    searchBox:SetAutoFocus(false)
    searchBox.Instructions:SetText(L["VENDORS_SEARCH_PLACEHOLDER"])
    self.searchBox = searchBox

    searchBox:HookScript("OnTextChanged", function(box, userInput)
        if userInput then self:OnSearchTextChanged(box:GetText()) end
    end)

    if searchBox.clearButton then
        searchBox.clearButton:HookScript("OnClick", function()
            self:OnSearchTextChanged("")
        end)
    end

    searchBox:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)

    local filterContainer = CreateFrame("Frame", nil, toolbar)
    filterContainer:SetPoint("LEFT", searchBox, "RIGHT", 16, 0)
    filterContainer:SetHeight(22)
    self.filterContainer = filterContainer

    local filters = {
        { key = "all", label = L["VENDORS_FILTER_ALL"] },
        { key = "incomplete", label = L["VENDORS_FILTER_INCOMPLETE"] },
        { key = "complete", label = L["VENDORS_FILTER_COMPLETE"] },
    }

    local xOffset = 0
    for _, filterInfo in ipairs(filters) do
        local btn = addon:CreateActionButton(filterContainer, filterInfo.label, function()
            self:SetCompletionFilter(filterInfo.key)
        end)
        btn:SetPoint("LEFT", filterContainer, "LEFT", xOffset, 0)
        btn.filterKey = filterInfo.key
        self.filterButtons[filterInfo.key] = btn
        xOffset = xOffset + btn:GetWidth() + 4
    end

    filterContainer:SetWidth(xOffset - 4)
    self:SetCompletionFilter("incomplete")

    toolbar:SetScript("OnSizeChanged", function(_, width)
        self:UpdateToolbarLayout(width)
    end)
end

function VendorsTab:SetCompletionFilter(filterKey)
    for key, btn in pairs(self.filterButtons) do
        btn:SetActive(key == filterKey)
    end
    local db = GetVendorsDB()
    if db then db.completionFilter = filterKey end
    self:BuildExpansionDisplay()
    self:BuildVendorDisplay()
end

function VendorsTab:GetCompletionFilter()
    local db = GetVendorsDB()
    return db and db.completionFilter or "incomplete"
end

function VendorsTab:OnSearchTextChanged(text)
    text = strtrim(text or "")
    self:BuildExpansionDisplay()
    self:BuildVendorDisplay()
end

--------------------------------------------------------------------------------
-- Expansion Panel (Left Column)
--------------------------------------------------------------------------------

function VendorsTab:CreateExpansionPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", self.toolbar, "BOTTOMLEFT", -SIDEBAR_WIDTH, 0)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -SIDEBAR_WIDTH, 0)
    panel:SetWidth(EXPANSION_PANEL_WIDTH)
    self.expansionPanel = panel

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)

    local border = panel:CreateTexture(nil, "ARTWORK")
    border:SetWidth(1)
    border:SetPoint("TOPRIGHT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(0.2, 0.2, 0.25, 1)

    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", HIERARCHY_PADDING, -HIERARCHY_PADDING)
    scrollContainer:SetPoint("BOTTOMRIGHT", -HIERARCHY_PADDING, HIERARCHY_PADDING)

    local scrollBox = CreateFrame("Frame", nil, scrollContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    self.expansionScrollBox = scrollBox

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(HEADER_HEIGHT)
    view:SetPadding(0, 0, 0, 0, 4)
    view:SetElementInitializer("Button", function(frame, elementData)
        self:SetupExpansionButton(frame, elementData)
    end)

    scrollBox:Init(view)
    self.expansionDataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(self.expansionDataProvider)
end

function VendorsTab:SetupExpansionButton(frame, elementData)
    local L = addon.L

    if not frame.bg then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        frame.bg = bg

        local border = frame:CreateTexture(nil, "ARTWORK")
        border:SetWidth(3)
        border:SetPoint("TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMLEFT", 0, 0)
        border:SetColorTexture(unpack(COLORS.GOLD))
        border:Hide()
        frame.selectionBorder = border

        local pct = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        pct:SetPoint("RIGHT", -8, 0)
        pct:SetJustifyH("RIGHT")
        frame.percentLabel = pct

        local label = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", 10, 0)
        label:SetPoint("RIGHT", pct, "LEFT", -4, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        frame.label = label

        frame:EnableMouse(true)
    end

    frame.selectionBorder:Hide()
    frame.expansionKey = elementData.expansionKey

    local isSelected = self.selectedExpansionKey == elementData.expansionKey
    ApplyExpansionButtonState(frame, isSelected)

    frame.label:SetText(L[elementData.expansionKey] or elementData.expansionKey)
    addon:SetFontSize(frame.label, 13, "")

    local owned, total = addon:GetVendorExpansionCollectionProgress(elementData.expansionKey)
    local pctValue = total > 0 and (owned / total * 100) or 0
    frame.percentLabel:SetText(string.format("%.0f%%", pctValue))
    frame.percentLabel:SetTextColor(addon:GetCompletionProgressColor(pctValue))
    addon:SetFontSize(frame.percentLabel, 11, "")

    frame:SetScript("OnClick", function()
        self:SelectExpansion(elementData.expansionKey)
    end)

    frame:SetScript("OnEnter", function(f)
        if self.selectedExpansionKey ~= f.expansionKey then
            f.bg:SetColorTexture(unpack(COLORS.PANEL_HOVER))
        end
    end)

    frame:SetScript("OnLeave", function(f)
        ApplyExpansionButtonState(f, self.selectedExpansionKey == f.expansionKey)
    end)
end

function VendorsTab:SelectExpansion(expansionKey)
    local prevSelected = self.selectedExpansionKey
    self.selectedExpansionKey = expansionKey

    local db = GetVendorsDB()
    if db then
        db.selectedExpansionKey = expansionKey
        if db.expandedZones then
            for _, zoneName in ipairs(addon:GetSortedVendorZones(expansionKey)) do
                db.expandedZones[expansionKey .. ":" .. zoneName] = nil
            end
        end
    end

    if self.expansionScrollBox then
        self.expansionScrollBox:ForEachFrame(function(frame)
            if frame.expansionKey then
                ApplyExpansionButtonState(frame, frame.expansionKey == expansionKey)
            end
        end)
    end

    self:BuildVendorDisplay()

    if prevSelected ~= expansionKey then
        self.selectedVendorNpcId = nil
        self.selectedDecorId = nil
        self.selectedVendorFrame = nil
        self.selectedDecorRow = nil
        addon:FireEvent("RECORD_SELECTED", nil)
    end

    self:UpdateEmptyStates()
end

--------------------------------------------------------------------------------
-- Vendor Panel (Right Side)
--------------------------------------------------------------------------------

function VendorsTab:CreateVendorPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", self.expansionPanel, "TOPRIGHT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.vendorPanel = panel

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)

    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", HIERARCHY_PADDING, -HIERARCHY_PADDING)
    scrollContainer:SetPoint("BOTTOMRIGHT", -HIERARCHY_PADDING - 16, HIERARCHY_PADDING)

    local scrollBox = CreateFrame("Frame", nil, scrollContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    self.vendorScrollBox = scrollBox

    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollContainer, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollContainer, "BOTTOMRIGHT", 4, 0)
    self.vendorScrollBar = scrollBar

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, elementData)
        if elementData.isZoneHeader then return ZONE_HEADER_HEIGHT end
        local decorCount = elementData.decorIds and #elementData.decorIds or 0
        return VENDOR_ROW_BASE_HEIGHT + (decorCount * DECOR_ROW_HEIGHT)
    end)
    view:SetElementInitializer("Button", function(frame, elementData)
        self:SetupVendorButton(frame, elementData)
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    self.vendorView = view

    self.vendorDataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(self.vendorDataProvider)
end

function VendorsTab:SetupVendorButton(frame, elementData)
    local L = addon.L

    -- One-time frame setup
    if not frame.initialized then
        self:InitializeVendorFrame(frame)
        frame.initialized = true
    end

    -- Reset frame state
    self:ResetVendorFrame(frame)

    if elementData.isZoneHeader then
        self:SetupZoneHeader(frame, elementData)
    else
        self:SetupVendorRow(frame, elementData)
    end
end

function VendorsTab:InitializeVendorFrame(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.bg = bg

    local border = frame:CreateTexture(nil, "ARTWORK")
    border:SetWidth(3)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMLEFT", 0, 0)
    border:SetColorTexture(unpack(COLORS.GOLD))
    border:Hide()
    frame.selectionBorder = border

    local indicator = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
    addon:SetFontSize(indicator, 14, "OUTLINE")
    indicator:SetPoint("LEFT", 8, 0)
    indicator:SetWidth(20)
    indicator:SetJustifyH("LEFT")
    frame.indicator = indicator

    local zoneLabel = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
    zoneLabel:SetPoint("LEFT", 28, 0)
    zoneLabel:SetPoint("RIGHT", -80, 0)
    zoneLabel:SetJustifyH("LEFT")
    zoneLabel:SetWordWrap(false)
    frame.zoneLabel = zoneLabel

    local zoneProgress = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
    zoneProgress:SetPoint("RIGHT", -8, 0)
    zoneProgress:SetJustifyH("RIGHT")
    frame.zoneProgress = zoneProgress

    local vendorContainer = CreateFrame("Frame", nil, frame)
    vendorContainer:SetPoint("TOPLEFT", 8, 0)
    vendorContainer:SetPoint("TOPRIGHT", -8, 0)
    vendorContainer:SetHeight(VENDOR_ROW_BASE_HEIGHT)
    frame.vendorContainer = vendorContainer

    local vendorName = addon:CreateFontString(vendorContainer, "OVERLAY", "GameFontNormal")
    vendorName:SetPoint("TOPLEFT", 4, -8)
    vendorName:SetJustifyH("LEFT")
    frame.vendorName = vendorName

    local factionIcon = vendorContainer:CreateTexture(nil, "OVERLAY")
    factionIcon:SetSize(18, 18)
    factionIcon:SetPoint("LEFT", vendorName, "RIGHT", 4, 0)
    factionIcon:Hide()
    frame.factionIcon = factionIcon

    local vendorProgress = addon:CreateFontString(vendorContainer, "OVERLAY", "GameFontNormal")
    vendorProgress:SetPoint("TOPRIGHT", -4, -8)
    vendorProgress:SetJustifyH("RIGHT")
    frame.vendorProgress = vendorProgress

    local waypointBtn = CreateFrame("Button", nil, vendorContainer)
    waypointBtn:SetSize(WAYPOINT_BUTTON_SIZE, WAYPOINT_BUTTON_SIZE)
    waypointBtn:SetPoint("RIGHT", vendorProgress, "LEFT", -8, 0)

    local waypointIcon = waypointBtn:CreateTexture(nil, "ARTWORK")
    waypointIcon:SetAllPoints()
    waypointIcon:SetAtlas("Waypoint-MapPin-ChatIcon")
    waypointIcon:SetAlpha(0.7)
    waypointBtn.icon = waypointIcon

    waypointBtn:SetScript("OnEnter", function(btn)
        btn.icon:SetAlpha(1)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(addon.L["VENDOR_SET_WAYPOINT"], 1, 1, 1)
        GameTooltip:Show()
    end)
    waypointBtn:SetScript("OnLeave", function(btn)
        btn.icon:SetAlpha(0.7)
        GameTooltip:Hide()
    end)
    frame.waypointBtn = waypointBtn

    local decorContainer = CreateFrame("Frame", nil, frame)
    decorContainer:SetPoint("TOPLEFT", vendorContainer, "BOTTOMLEFT", 0, 0)
    decorContainer:SetPoint("TOPRIGHT", vendorContainer, "BOTTOMRIGHT", 0, 0)
    frame.decorContainer = decorContainer

    frame.decorRows = {}
    frame:EnableMouse(true)
end

function VendorsTab:ResetVendorFrame(frame)
    frame.selectionBorder:Hide()
    frame.indicator:Hide()
    frame.zoneLabel:Hide()
    frame.zoneProgress:Hide()
    frame.vendorContainer:Hide()
    frame.decorContainer:Hide()
    frame.waypointBtn:Hide()
    frame.factionIcon:Hide()
    frame.npcId = nil
    frame.zoneName = nil
    frame.expansionKey = nil
    frame.isZoneHeader = nil

    -- Hide all decor rows
    for _, row in ipairs(frame.decorRows) do
        row:Hide()
        if row.selectionHighlight then
            row.selectionHighlight:Hide()
        end
    end
end

-- Helper to update vendor row selection visual
function VendorsTab:UpdateVendorSelectionVisual(frame, isSelected)
    if not frame or frame.isZoneHeader then return end
    if isSelected then
        frame.selectionBorder:Show()
        frame.bg:SetColorTexture(0.12, 0.12, 0.14, 1)
    else
        frame.selectionBorder:Hide()
        frame.bg:SetColorTexture(0.08, 0.08, 0.10, 0.9)
    end
end

-- Helper to update decor row selection visual
function VendorsTab:UpdateDecorSelectionVisual(row, isSelected, textBrightness)
    if not row then return end
    if row.selectionHighlight then
        row.selectionHighlight:SetShown(isSelected)
    end
    if isSelected then
        row.name:SetTextColor(1, 0.82, 0, 1)  -- Gold for selected
    else
        row.name:SetTextColor(textBrightness, textBrightness, textBrightness, 1)
    end
end

function VendorsTab:SetupZoneHeader(frame, elementData)
    frame:SetHeight(ZONE_HEADER_HEIGHT)
    frame.isZoneHeader = true
    frame.zoneName = elementData.zoneName
    frame.expansionKey = elementData.expansionKey

    local isExpanded = self:IsZoneExpanded(elementData.expansionKey, elementData.zoneName)

    -- Reset background
    addon:ResetBackgroundTexture(frame.bg)
    frame.bg:SetColorTexture(unpack(COLORS.PANEL_NORMAL_ALT))

    -- Collapse indicator
    frame.indicator:SetText(isExpanded and "-" or "+")
    frame.indicator:SetTextColor(1, 1, 1, 1)
    frame.indicator:SetPoint("LEFT", 8, 0)
    frame.indicator:Show()

    -- Zone name (with class hall or housing zone annotation if applicable)
    local classHall = addon:GetClassHallAnnotation(elementData.zoneName)
    local housingZone = addon:GetHousingZoneAnnotation(elementData.zoneName)
    if classHall then
        -- Dimmer gray for the class hall annotation
        frame.zoneLabel:SetText(elementData.zoneName .. " |cff888888(" .. classHall .. " class hall)|r")
    elseif housingZone then
        -- Dimmer gray for the housing zone annotation
        frame.zoneLabel:SetText(elementData.zoneName .. " |cff888888(" .. housingZone .. " housing zone)|r")
    else
        frame.zoneLabel:SetText(elementData.zoneName)
    end
    frame.zoneLabel:SetTextColor(1, 1, 1, 1)
    addon:SetFontSize(frame.zoneLabel, 14, "")
    frame.zoneLabel:Show()

    -- Progress
    local owned, total = addon:GetVendorZoneCollectionProgress(elementData.expansionKey, elementData.zoneName)
    local percent = total > 0 and math.floor((owned / total) * 100) or 0
    frame.zoneProgress:SetText(string.format("%d/%d (%d%%)", owned, total, percent))
    frame.zoneProgress:SetTextColor(unpack(addon.TabBaseMixin:GetProgressColor(percent, true)))
    frame.zoneProgress:Show()

    frame:SetScript("OnClick", function()
        self:ToggleZone(elementData.expansionKey, elementData.zoneName)
    end)

    frame:SetScript("OnEnter", function(f)
        f.bg:SetColorTexture(unpack(COLORS.PANEL_HOVER_ALT))
    end)

    frame:SetScript("OnLeave", function(f)
        f.bg:SetColorTexture(unpack(COLORS.PANEL_NORMAL_ALT))
    end)
end

function VendorsTab:SetupVendorRow(frame, elementData)
    local L = addon.L
    local decorIds = elementData.decorIds or {}
    local decorCount = #decorIds
    frame:SetHeight(VENDOR_ROW_BASE_HEIGHT + (decorCount * DECOR_ROW_HEIGHT))
    frame.npcId = elementData.npcId

    addon:ResetBackgroundTexture(frame.bg)
    frame.bg:SetColorTexture(0.08, 0.08, 0.10, 0.9)

    frame.vendorContainer:Show()
    frame.decorContainer:Show()
    frame.decorContainer:SetHeight(decorCount * DECOR_ROW_HEIGHT)

    frame.vendorName:SetText(elementData.npcName or L["VENDOR_UNKNOWN"])
    addon:SetFontSize(frame.vendorName, 14, "")
    frame.vendorName:SetTextColor(0.92, 0.76, 0, 1)

    local faction = addon:GetVendorFaction(elementData.npcId)
    if faction then
        frame.factionIcon:Show()
        local atlas = faction == "Alliance" and "questlog-questtypeicon-alliance" or "questlog-questtypeicon-horde"
        frame.factionIcon:SetAtlas(atlas)
    end

    local owned = 0
    for _, decorId in ipairs(decorIds) do
        if addon:IsDecorCollected(decorId) then owned = owned + 1 end
    end
    frame.vendorProgress:SetText(string.format("%d/%d", owned, decorCount))
    local progressComplete = owned == decorCount and decorCount > 0
    frame.vendorProgress:SetTextColor(unpack(progressComplete and COLORS.PROGRESS_COMPLETE or COLORS.TEXT_TERTIARY))
    addon:SetFontSize(frame.vendorProgress, 11, "")

    if addon:GetNPCLocation(elementData.npcId) then
        frame.waypointBtn:Show()
        frame.waypointBtn:SetScript("OnClick", function()
            self:SetWaypoint(elementData.npcId, elementData.npcName)
        end)
    end

    self:SetupDecorRows(frame, decorIds)

    -- Check if this vendor is currently selected
    local isVendorSelected = self.selectedVendorNpcId == elementData.npcId
    self:UpdateVendorSelectionVisual(frame, isVendorSelected)

    frame:SetScript("OnClick", function(_, button)
        if button == "RightButton" then return end
        if decorCount == 0 then return end

        local isCurrentlySelected = self.selectedVendorNpcId == elementData.npcId and self.selectedDecorId == decorIds[1]

        if isCurrentlySelected then
            -- Deselect current vendor
            self.selectedVendorNpcId = nil
            self.selectedDecorId = nil
            self:UpdateVendorSelectionVisual(frame, false)
            addon:FireEvent("RECORD_SELECTED", nil)
        else
            -- Clear previous selections
            if self.selectedVendorFrame and self.selectedVendorFrame ~= frame then
                self:UpdateVendorSelectionVisual(self.selectedVendorFrame, false)
            end
            if self.selectedDecorRow then
                self:UpdateDecorSelectionVisual(self.selectedDecorRow, false, self.selectedDecorRow.textBrightness or 0.7)
                self.selectedDecorRow = nil
            end

            -- Select this vendor
            self.selectedVendorNpcId = elementData.npcId
            self.selectedDecorId = decorIds[1]
            self.selectedVendorFrame = frame
            self:UpdateVendorSelectionVisual(frame, true)
            addon:FireEvent("RECORD_SELECTED", decorIds[1])
        end
    end)

    frame:SetScript("OnEnter", function(f)
        if self.selectedVendorNpcId ~= elementData.npcId then
            f.bg:SetColorTexture(0.12, 0.12, 0.14, 1)
        end
        if decorCount > 0 then
            self.hoveringRecordID = decorIds[1]
            addon:FireEvent("RECORD_SELECTED", decorIds[1])
        end
    end)

    frame:SetScript("OnLeave", function(f)
        if self.selectedVendorNpcId ~= elementData.npcId then
            f.bg:SetColorTexture(0.08, 0.08, 0.10, 0.9)
        end
        self.hoveringRecordID = nil
        if self.selectedDecorId then
            addon:FireEvent("RECORD_SELECTED", self.selectedDecorId)
        else
            addon:FireEvent("RECORD_SELECTED", nil)
        end
    end)
end

function VendorsTab:SetupDecorRows(frame, decorIds)
    local L = addon.L

    for i, decorId in ipairs(decorIds) do
        local row = frame.decorRows[i]
        if not row then
            row = CreateFrame("Button", nil, frame.decorContainer)
            row:SetHeight(DECOR_ROW_HEIGHT)

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(DECOR_ICON_SIZE, DECOR_ICON_SIZE)
            icon:SetPoint("LEFT", 20, 0)
            row.icon = icon

            local checkIcon = row:CreateTexture(nil, "OVERLAY")
            checkIcon:SetSize(14, 14)
            checkIcon:SetPoint("LEFT", 4, 0)
            checkIcon:SetAtlas("common-icon-checkmark")
            checkIcon:SetVertexColor(0.4, 0.9, 0.4, 1)
            checkIcon:Hide()
            row.checkIcon = checkIcon

            local name = addon:CreateFontString(row, "OVERLAY", "GameFontNormal")
            name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            name:SetPoint("RIGHT", -60, 0)
            name:SetJustifyH("LEFT")
            name:SetWordWrap(false)
            row.name = name

            -- Selection highlight (subtle left border)
            local selHighlight = row:CreateTexture(nil, "BACKGROUND")
            selHighlight:SetWidth(2)
            selHighlight:SetPoint("TOPLEFT", 0, 0)
            selHighlight:SetPoint("BOTTOMLEFT", 0, 0)
            selHighlight:SetColorTexture(1, 0.82, 0, 1)
            selHighlight:Hide()
            row.selectionHighlight = selHighlight

            row:EnableMouse(true)
            frame.decorRows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.decorContainer, "TOPLEFT", 0, -((i - 1) * DECOR_ROW_HEIGHT))
        row:SetPoint("RIGHT", frame.decorContainer, "RIGHT", 0, 0)
        row:Show()

        local record = addon:GetRecord(decorId)
        local fallback = not record and addon.VendorItemFallback and addon.VendorItemFallback[decorId]
        row.decorId = decorId

        if record then
            if record.iconType == "atlas" then
                row.icon:SetAtlas(record.icon)
            else
                row.icon:SetTexture(record.icon)
            end
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        local isCollected = record and record.isCollected
        row.checkIcon:SetShown(isCollected)

        local textBrightness = isCollected and 0.4 or 0.7
        row.textBrightness = textBrightness  -- Store for use in handlers
        local displayName = (record and record.name) or (fallback and fallback.name) or string.format(L["VENDORS_DECOR_ID"], decorId)
        row.name:SetText(displayName)
        addon:SetFontSize(row.name, 13, "")

        -- Check if this item is currently selected
        local isItemSelected = self.selectedDecorId == decorId
        self:UpdateDecorSelectionVisual(row, isItemSelected, textBrightness)

        row:SetScript("OnClick", function()
            if IsShiftKeyDown() then
                local trackingType = Enum.ContentTrackingType.Decor
                if C_ContentTracking.IsTracking(trackingType, decorId) then
                    C_ContentTracking.StopTracking(trackingType, decorId, Enum.ContentTrackingStopType.Manual)
                    addon:Print(L["VENDORS_TRACKING_STOPPED"])
                else
                    local err = C_ContentTracking.StartTracking(trackingType, decorId)
                    addon:PrintTrackingResult(err, "VENDORS_TRACKING_STARTED", "VENDORS_TRACKING_FAILED", "VENDORS_TRACKING_MAX_REACHED", "VENDORS_TRACKING_ALREADY")
                end
                return
            end

            local isCurrentlySelected = self.selectedDecorId == decorId

            if isCurrentlySelected then
                -- Deselect current item
                self.selectedVendorNpcId = nil
                self.selectedDecorId = nil
                self.selectedDecorRow = nil
                self:UpdateDecorSelectionVisual(row, false, row.textBrightness)
                addon:FireEvent("RECORD_SELECTED", nil)
            else
                -- Clear previous selections
                if self.selectedDecorRow and self.selectedDecorRow ~= row then
                    self:UpdateDecorSelectionVisual(self.selectedDecorRow, false, self.selectedDecorRow.textBrightness or 0.7)
                end
                if self.selectedVendorFrame then
                    self:UpdateVendorSelectionVisual(self.selectedVendorFrame, false)
                    self.selectedVendorFrame = nil
                end

                -- Select this item
                self.selectedVendorNpcId = frame.npcId
                self.selectedDecorId = decorId
                self.selectedDecorRow = row
                self:UpdateDecorSelectionVisual(row, true, row.textBrightness)
                addon:FireEvent("RECORD_SELECTED", decorId)
            end
        end)

        row:SetScript("OnEnter", function(r)
            if self.selectedDecorId ~= decorId then
                r.name:SetTextColor(1, 1, 1, 1)
            end
            self.hoveringRecordID = decorId
            addon:FireEvent("RECORD_SELECTED", decorId)

            GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 15, (y / scale) + 15)
            if record then
                GameTooltip:SetText(record.name, 1, 1, 1)
                if isCollected then
                    GameTooltip:AddLine(L["FILTER_COLLECTED"], 0.4, 0.9, 0.4)
                end
            elseif fallback and fallback.name then
                GameTooltip:SetText(fallback.name, 1, 1, 1)
                if fallback.category then
                    GameTooltip:AddLine(fallback.category, 0.7, 0.7, 0.7)
                end
            else
                GameTooltip:SetText(string.format(L["VENDORS_DECOR_ID"], decorId), 1, 1, 1)
            end
            GameTooltip:Show()
        end)

        row:SetScript("OnLeave", function(r)
            if self.selectedDecorId ~= decorId then
                r.name:SetTextColor(r.textBrightness, r.textBrightness, r.textBrightness, 1)
            end
            self.hoveringRecordID = nil
            GameTooltip:Hide()
            if self.selectedDecorId then
                addon:FireEvent("RECORD_SELECTED", self.selectedDecorId)
            else
                addon:FireEvent("RECORD_SELECTED", nil)
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- Waypoint Functionality
--------------------------------------------------------------------------------

function VendorsTab:SetWaypoint(npcId, npcName)
    local L = addon.L
    local locData = addon:GetNPCLocation(npcId)

    if not locData then
        addon:Print(L["VENDOR_NO_LOCATION"])
        return
    end

    if not C_Map.CanSetUserWaypointOnMap(locData.uiMapId) then
        addon:Print(L["VENDOR_MAP_RESTRICTED"])
        return
    end

    local point = UiMapPoint.CreateFromCoordinates(locData.uiMapId, locData.x / 100, locData.y / 100)
    C_Map.SetUserWaypoint(point)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)

    addon:Print(string.format(L["VENDOR_WAYPOINT_SET"], npcName or L["VENDOR_FALLBACK_NAME"]))

    if not InCombatLockdown() then
        C_Map.OpenWorldMap(locData.uiMapId)
    end
end

--------------------------------------------------------------------------------
-- Zone Expand/Collapse
--------------------------------------------------------------------------------

function VendorsTab:IsZoneExpanded(expansionKey, zoneName)
    local db = GetVendorsDB()
    if not db then return false end
    local key = expansionKey .. ":" .. zoneName
    return db.expandedZones[key] == true
end

function VendorsTab:ToggleZone(expansionKey, zoneName)
    local db = GetVendorsDB()
    if db then
        local key = expansionKey .. ":" .. zoneName
        db.expandedZones[key] = not db.expandedZones[key]
    end
    self:BuildVendorDisplay()
end

--------------------------------------------------------------------------------
-- Search/Filter Logic
--------------------------------------------------------------------------------

local function VendorMatchesSearch(vendorData, searchText, zoneName, expansionKey)
    if searchText == "" then return true end

    if vendorData.npcName and strlower(vendorData.npcName):find(searchText, 1, true) then
        return true
    end

    if strlower(zoneName):find(searchText, 1, true) then return true end

    local expName = strlower(addon.L[expansionKey] or expansionKey)
    if expName:find(searchText, 1, true) then return true end

    for _, decorId in ipairs(vendorData.decorIds or {}) do
        local record = addon:GetRecord(decorId)
        if record and record.name and strlower(record.name):find(searchText, 1, true) then
            return true
        end
    end

    return false
end

local function VendorPassesCompletionFilter(vendorData, filter)
    if filter == "all" then return true end

    local owned, total = 0, 0
    for _, decorId in ipairs(vendorData.decorIds or {}) do
        total = total + 1
        if addon:IsDecorCollected(decorId) then owned = owned + 1 end
    end

    local isComplete = total > 0 and owned == total
    if filter == "complete" then return isComplete end
    if filter == "incomplete" then return not isComplete end
    return true
end

--------------------------------------------------------------------------------
-- Display Building
--------------------------------------------------------------------------------

local function FindExpansionInList(elements, key)
    for _, elem in ipairs(elements) do
        if elem.expansionKey == key then return true end
    end
    return false
end

function VendorsTab:BuildExpansionDisplay()
    if not self.expansionScrollBox or not self.expansionDataProvider then return end

    local elements = {}
    local filter = self:GetCompletionFilter()
    local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

    for _, expansionKey in ipairs(addon:GetSortedVendorExpansions()) do
        local hasVisibleContent = false
        for _, zoneName in ipairs(addon:GetSortedVendorZones(expansionKey)) do
            for _, vendorData in ipairs(addon:GetVendorsForZone(expansionKey, zoneName)) do
                if VendorPassesCompletionFilter(vendorData, filter)
                    and VendorMatchesSearch(vendorData, searchText, zoneName, expansionKey) then
                    hasVisibleContent = true
                    break
                end
            end
            if hasVisibleContent then break end
        end
        if hasVisibleContent then
            table.insert(elements, { expansionKey = expansionKey })
        end
    end

    self.expansionDataProvider:Flush()
    if #elements > 0 then
        self.expansionDataProvider:InsertTable(elements)
    end

    if not self.selectedExpansionKey and #elements > 0 then
        local defaultKey = "EXPANSION_TWW"
        self:SelectExpansion(FindExpansionInList(elements, defaultKey) and defaultKey or elements[1].expansionKey)
    elseif self.selectedExpansionKey and not FindExpansionInList(elements, self.selectedExpansionKey) then
        if #elements > 0 then
            self:SelectExpansion(elements[1].expansionKey)
        else
            self.selectedExpansionKey = nil
            self:BuildVendorDisplay()
        end
    end
end

function VendorsTab:BuildVendorDisplay()
    if not self.vendorScrollBox or not self.vendorDataProvider then return end

    local elements = {}
    local expansionKey = self.selectedExpansionKey

    if expansionKey then
        local filter = self:GetCompletionFilter()
        local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

        for _, zoneName in ipairs(addon:GetSortedVendorZones(expansionKey)) do
            local zoneVendors = {}
            for _, vendorData in ipairs(addon:GetVendorsForZone(expansionKey, zoneName)) do
                if VendorPassesCompletionFilter(vendorData, filter)
                    and VendorMatchesSearch(vendorData, searchText, zoneName, expansionKey) then
                    table.insert(zoneVendors, vendorData)
                end
            end

            if #zoneVendors > 0 then
                table.insert(elements, { isZoneHeader = true, expansionKey = expansionKey, zoneName = zoneName })
                if self:IsZoneExpanded(expansionKey, zoneName) then
                    for _, vendor in ipairs(zoneVendors) do
                        table.insert(elements, vendor)
                    end
                end
            end
        end
    end

    self.vendorDataProvider:Flush()
    if #elements > 0 then
        self.vendorDataProvider:InsertTable(elements)
    end
    self:UpdateEmptyStates()
end

--------------------------------------------------------------------------------
-- Empty States
--------------------------------------------------------------------------------

function VendorsTab:CreateEmptyStates()
    self.emptyState = addon:CreateEmptyStateFrame(
        self.expansionPanel,
        "VENDORS_EMPTY_NO_SOURCES",
        "VENDORS_EMPTY_NO_SOURCES_DESC",
        EXPANSION_PANEL_WIDTH - 16
    )
    self.noExpansionState = addon:CreateEmptyStateFrame(self.vendorPanel, "VENDORS_SELECT_EXPANSION")
end

function VendorsTab:UpdateEmptyStates()
    local hasVendors = addon:GetVendorCount() > 0
    local hasSelection = self.selectedExpansionKey ~= nil

    if self.emptyState then self.emptyState:SetShown(not hasVendors) end
    if self.noExpansionState then self.noExpansionState:SetShown(hasVendors and not hasSelection) end
    if self.expansionScrollBox then self.expansionScrollBox:SetShown(hasVendors) end
    if self.vendorScrollBox then self.vendorScrollBox:SetShown(hasVendors and hasSelection) end
    if self.vendorScrollBar then self.vendorScrollBar:SetShown(hasVendors and hasSelection) end
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

addon:RegisterInternalEvent("TAB_CHANGED", function(tabKey)
    if tabKey == "VENDORS" then
        VendorsTab:Show()
    else
        VendorsTab:Hide()
    end
end)

addon:RegisterInternalEvent("DATA_LOADED", function()
    if VendorsTab:IsShown() and not addon.vendorIndexBuilt then
        addon:BuildVendorIndex()
        VendorsTab:BuildExpansionDisplay()
        VendorsTab:BuildVendorDisplay()
        VendorsTab:UpdateEmptyStates()
    end
end)

addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
    if VendorsTab:IsShown() then
        VendorsTab:BuildExpansionDisplay()
        VendorsTab:BuildVendorDisplay()
    end
end)

local originalCreateContent = addon.MainFrame.CreateContentArea
addon.MainFrame.CreateContentArea = function(mainFrame)
    originalCreateContent(mainFrame)
    if mainFrame.contentArea then
        VendorsTab:Create(mainFrame.contentArea)
    end
end
