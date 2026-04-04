--[[
    Housing Codex - VendorsTab.lua
    Vendor sources tab with Expansion > Zone > Vendor hierarchy
]]

local _, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS

local EXPANSION_PANEL_WIDTH = CONSTS.HIERARCHY_PANEL_WIDTH
local HIERARCHY_PADDING = CONSTS.HIERARCHY_PADDING
local HEADER_HEIGHT = CONSTS.HIERARCHY_HEADER_HEIGHT

local VENDOR_ROW_BASE_HEIGHT = 32
local DECOR_ROW_HEIGHT = 24
local ZONE_HEADER_HEIGHT = 28
local DECOR_ICON_SIZE = 22
local WAYPOINT_BUTTON_SIZE = 20
local WAYPOINT_MATCH_EPSILON = CONSTS.WAYPOINT_MATCH_EPSILON or 0.0001

addon.VendorsTab = {}
local VendorsTab = addon.VendorsTab
local VALID_FILTERS = { all = true, incomplete = true, complete = true }

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
VendorsTab.activeTrackedNpcId = nil
VendorsTab.activeTrackedDecorId = nil
VendorsTab.waypointListenerRegistered = false
VendorsTab.onUserWaypointUpdated = nil

VendorsTab.toolbarLayout = nil
VendorsTab.filterContainer = nil
VendorsTab.currentZoneOnly = false
VendorsTab.currentZoneCheckbox = nil
VendorsTab.playerZoneRootMapID = nil

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------

function VendorsTab:Create(parent)
    if self.frame then return end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    self.frame = frame

    self.onUserWaypointUpdated = function()
        self:OnUserWaypointUpdated()
    end

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

    -- Skip default rebuild when navigating from Progress
    if self.pendingNavigation then
        self.pendingNavigation = nil
        return
    end

    local saved = GetVendorsDB()
    if saved then
        -- Expanded zones persist across sessions (EnsureVendorsDB initializes on first load)
        self.selectedExpansionKey = saved.selectedExpansionKey
        self:SetCompletionFilter(saved.completionFilter or "incomplete")
    end

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
    self:CreateStandardToolbar(parent, {
        searchPlaceholderKey = "VENDORS_SEARCH_PLACEHOLDER",
        filterPrefix = "VENDORS",
    })

    local check = CreateFrame("CheckButton", nil, self.toolbar, "UICheckButtonTemplate")
    check:SetPoint("LEFT", self.filterContainer, "RIGHT", 12, 0)
    check:SetSize(22, 22)
    check.Text:SetFontObject(addon:GetFontObject("GameFontNormalSmall"))
    addon:RegisterFontString(check.Text, "GameFontNormalSmall")
    check.Text:SetText(addon.L["VENDORS_CURRENT_ZONE"])
    check.Text:SetTextColor(1, 0.82, 0)
    check:SetChecked(false)
    check:SetScript("OnClick", function(cb)
        self.currentZoneOnly = cb:GetChecked()
        self:RefreshDisplay()
    end)
    self.currentZoneCheckbox = check
end

-- Rebuild the expansion list and, if needed, the vendor list.
local searchCache, filterCache

-- BuildExpansionDisplay returns true when it already triggered BuildVendorDisplay
-- internally (via SelectExpansion or direct call), so we only call it ourselves
-- when that didn't happen.
function VendorsTab:RefreshDisplay()
    addon:CountDebug("rebuild", "VendorsTab")
    if self.currentZoneOnly then
        self:UpdatePlayerZone()
    end
    searchCache = {}
    filterCache = {}
    if not self:BuildExpansionDisplay() then
        self:BuildVendorDisplay()
    end
    searchCache = nil
    filterCache = nil
end

function VendorsTab:SetCompletionFilter(filterKey, skipRefresh)
    if not VALID_FILTERS[filterKey] then filterKey = "incomplete" end
    for key, btn in pairs(self.filterButtons) do
        btn:SetActive(key == filterKey)
    end
    local db = GetVendorsDB()
    if db then db.completionFilter = filterKey end
    if not skipRefresh then
        self:RefreshDisplay()
    end
end

function VendorsTab:GetCompletionFilter()
    local db = GetVendorsDB()
    return db and db.completionFilter or "incomplete"
end

function VendorsTab:OnSearchTextChanged(text)
    self:RefreshDisplay()
end

--------------------------------------------------------------------------------
-- Expansion Panel (Left Column)
--------------------------------------------------------------------------------

function VendorsTab:CreateExpansionPanel(parent)
    self:CreateHierarchyPanel(parent, {
        panelKey        = "expansionPanel",
        scrollBoxKey    = "expansionScrollBox",
        dataProviderKey = "expansionDataProvider",
        elementExtent   = HEADER_HEIGHT,
        setupFn         = function(frame, elementData)
            self:SetupExpansionButton(frame, elementData)
        end,
    })
end

-- Named handlers for expansion buttons (bound once, read data from frame fields)
local function VendorExpansionButtonOnClick(frame)
    VendorsTab:SelectExpansion(frame.expansionKey)
end

local function VendorExpansionButtonOnEnter(frame)
    if VendorsTab.selectedExpansionKey ~= frame.expansionKey then
        frame.bg:SetColorTexture(unpack(COLORS.PANEL_HOVER))
    end
end

local function VendorExpansionButtonOnLeave(frame)
    VendorsTab:ApplySelectionButtonState(frame, VendorsTab.selectedExpansionKey == frame.expansionKey)
end

-- Named handlers for zone header rows (bound once, read data from frame fields)
local function VendorZoneHeaderOnClick(frame)
    if frame.isForceExpanded then return end
    VendorsTab:ToggleZone(frame.expansionKey, frame.zoneName)
end

local function VendorZoneHeaderOnEnter(frame)
    frame.bg:SetColorTexture(unpack(COLORS.PANEL_HOVER_ALT))
end

local function VendorZoneHeaderOnLeave(frame)
    frame.bg:SetColorTexture(unpack(COLORS.PANEL_NORMAL_ALT))
end

-- Named handlers for vendor rows (bound once, read data from frame fields)
local function VendorRowOnClick(frame, button)
    if button == "RightButton" then return end
    local decorIds = frame.decorIds
    if not decorIds or #decorIds == 0 then return end
    VendorsTab:HandleItemSelection({
        decorId = decorIds[1],
        npcId = frame.npcId,
        isVendorRow = true,
        vendorFrame = frame,
    })
end

local function VendorRowOnEnter(frame)
    if VendorsTab.selectedVendorNpcId ~= frame.npcId then
        frame.bg:SetColorTexture(0.12, 0.12, 0.14, 1)
    end
    local decorIds = frame.decorIds
    if decorIds and #decorIds > 0 then
        addon:FireEvent("RECORD_SELECTED", decorIds[1])
    end
end

local function VendorRowOnLeave(frame)
    if VendorsTab.selectedVendorNpcId ~= frame.npcId then
        frame.bg:SetColorTexture(unpack(COLORS.ROW_BG))
    end
    VendorsTab:RestoreSelectionOnLeave()
end

local function VendorWaypointBtnOnClick(btn)
    VendorsTab:SetWaypoint(btn.npcId, nil, btn.zoneName)
end

-- Named handlers for decor rows (bound once, read data from row fields)
local function VendorDecorRowOnClick(row)
    local decorId = row.decorId
    if IsShiftKeyDown() then
        VendorsTab:ToggleVendorDecorTracking(row.npcId, decorId, row.zoneName)
        return
    end
    VendorsTab:HandleItemSelection({
        decorId = decorId,
        npcId = row.npcId,
        isVendorRow = false,
        decorRow = row,
    })
end

local function VendorDecorRowOnEnter(row)
    local decorId = row.decorId
    if not (VendorsTab.selectedVendorNpcId == row.npcId and VendorsTab.selectedDecorId == decorId) then
        row.name:SetTextColor(1, 1, 1, 1)
    end
    addon:FireEvent("RECORD_SELECTED", decorId)

    local L = addon.L
    addon:AnchorTooltipToCursor(row)
    local record = row.record
    local fallback = row.fallback
    if record then
        GameTooltip:SetText(record.name, 1, 1, 1)
        if row.isCollected then
            GameTooltip:AddLine(L["FILTER_COLLECTED"], 0.4, 0.9, 0.4)
        end
    elseif fallback and fallback.name then
        GameTooltip:SetText(fallback.name, 1, 1, 1)
        if fallback.category then
            GameTooltip:AddLine(addon:GetLocalizedCategory(fallback.category), 0.7, 0.7, 0.7)
        end
    else
        GameTooltip:SetText(string.format(L["VENDORS_DECOR_ID"], decorId), 1, 1, 1)
    end
    GameTooltip:Show()
end

local function VendorDecorRowOnLeave(row)
    local decorId = row.decorId
    if not (VendorsTab.selectedVendorNpcId == row.npcId and VendorsTab.selectedDecorId == decorId) then
        row.name:SetTextColor(row.textBrightness, row.textBrightness, row.textBrightness, 1)
    end
    GameTooltip:Hide()
    VendorsTab:RestoreSelectionOnLeave()
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
        frame:SetScript("OnClick", VendorExpansionButtonOnClick)
        frame:SetScript("OnEnter", VendorExpansionButtonOnEnter)
        frame:SetScript("OnLeave", VendorExpansionButtonOnLeave)
    end

    frame.expansionKey = elementData.expansionKey

    local isSelected = self.selectedExpansionKey == elementData.expansionKey
    self:ApplySelectionButtonState(frame, isSelected)

    frame.label:SetText(L[elementData.expansionKey] or elementData.expansionKey)
    addon:SetFontSize(frame.label, 13, "")

    local owned, total = addon:GetVendorExpansionCollectionProgress(elementData.expansionKey)
    local pctValue = total > 0 and (owned / total * 100) or 0
    frame.percentLabel:SetText(string.format("%.0f%%", pctValue))
    frame.percentLabel:SetTextColor(addon:GetCompletionProgressColor(pctValue))
    addon:SetFontSize(frame.percentLabel, 11, "")
end

function VendorsTab:SelectExpansion(expansionKey)
    local prevSelected = self.selectedExpansionKey
    self.selectedExpansionKey = expansionKey

    local db = GetVendorsDB()
    if db then
        db.selectedExpansionKey = expansionKey
        if prevSelected ~= expansionKey and db.expandedZones then
            for _, zoneName in ipairs(addon:GetSortedVendorZones(expansionKey)) do
                db.expandedZones[expansionKey .. ":" .. zoneName] = nil
            end
        end
    end

    if self.expansionScrollBox then
        self.expansionScrollBox:ForEachFrame(function(frame)
            if frame.expansionKey then
                self:ApplySelectionButtonState(frame, frame.expansionKey == expansionKey)
            end
        end)
    end

    self:BuildVendorDisplay()

    if prevSelected ~= expansionKey then
        self.selectedVendorNpcId = nil
        self.selectedDecorId = nil
        addon:FireEvent("RECORD_SELECTED", nil)
    end
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
    waypointBtn:SetScript("OnClick", VendorWaypointBtnOnClick)
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
    frame.decorIds = nil
    frame.zoneName = nil
    frame.expansionKey = nil
    frame.isZoneHeader = nil
    frame.waypointBtn.npcId = nil
    frame.waypointBtn.zoneName = nil
    frame.isForceExpanded = nil

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
        frame.bg:SetColorTexture(unpack(COLORS.ROW_BG))
    end
end

-- Helper to update decor row selection visual
function VendorsTab:UpdateDecorSelectionVisual(row, isSelected, textBrightness)
    if not row then return end
    if row.selectionHighlight then
        row.selectionHighlight:SetShown(isSelected)
    end
    if isSelected then
        row.name:SetTextColor(unpack(COLORS.GOLD))
    else
        row.name:SetTextColor(textBrightness, textBrightness, textBrightness, 1)
    end
end

-- Shared selection toggle for vendor rows and decor rows
function VendorsTab:HandleItemSelection(params)
    local isCurrentlySelected = self.selectedVendorNpcId == params.npcId
        and self.selectedDecorId == params.decorId

    if isCurrentlySelected then
        -- Deselect
        if params.isVendorRow then
            self:UpdateVendorSelectionVisual(params.vendorFrame, false)
        else
            self:UpdateDecorSelectionVisual(params.decorRow, false, params.decorRow.textBrightness)
        end
        self.selectedVendorNpcId = nil
        self.selectedDecorId = nil
        addon:FireEvent("RECORD_SELECTED", nil)
    else
        -- Clear previous vendor highlight
        if self.selectedVendorNpcId then
            self.vendorScrollBox:ForEachFrame(function(f)
                if f.npcId == self.selectedVendorNpcId then
                    self:UpdateVendorSelectionVisual(f, false)
                end
            end)
        end
        -- Clear previous decor highlight
        if self.selectedDecorId then
            self.vendorScrollBox:ForEachFrame(function(f)
                if f.decorRows and f.npcId == self.selectedVendorNpcId then
                    for _, row in pairs(f.decorRows) do
                        if row.decorId == self.selectedDecorId then
                            self:UpdateDecorSelectionVisual(row, false, row.textBrightness or 0.7)
                        end
                    end
                end
            end)
        end

        -- Select new
        self.selectedVendorNpcId = params.npcId
        self.selectedDecorId = params.decorId
        if params.isVendorRow then
            self:UpdateVendorSelectionVisual(params.vendorFrame, true)
        else
            self:UpdateDecorSelectionVisual(params.decorRow, true, params.decorRow.textBrightness)
        end
        addon:FireEvent("RECORD_SELECTED", params.decorId)
    end
end

-- Shared OnLeave handler to restore selection state
function VendorsTab:RestoreSelectionOnLeave()
    addon:FireEvent("RECORD_SELECTED", self.selectedDecorId)
end

function VendorsTab:SetupZoneHeader(frame, elementData)
    local L = addon.L
    frame:SetHeight(ZONE_HEADER_HEIGHT)
    frame.isZoneHeader = true
    frame.zoneName = elementData.zoneName
    frame.expansionKey = elementData.expansionKey

    local isExpanded = self:IsZoneExpanded(elementData.expansionKey, elementData.zoneName)
    local isEffectivelyExpanded = isExpanded or elementData.isForceExpanded
    frame.isForceExpanded = elementData.isForceExpanded

    -- Reset background
    addon:ResetBackgroundTexture(frame.bg)
    frame.bg:SetColorTexture(unpack(COLORS.PANEL_NORMAL_ALT))

    -- Collapse indicator
    frame.indicator:SetText(isEffectivelyExpanded and "-" or "+")
    frame.indicator:SetTextColor(1, 1, 1, 1)
    frame.indicator:SetPoint("LEFT", 8, 0)
    frame.indicator:Show()

    -- Zone name (with class hall or housing zone annotation if applicable)
    local localizedZoneName = addon:GetLocalizedVendorZoneName(elementData.zoneName)
    local classHall = addon:GetClassHallAnnotation(elementData.zoneName)
    local housingZone = addon:GetHousingZoneAnnotation(elementData.zoneName)
    if classHall then
        local colorCode = addon:GetClassColorCode(classHall)
        local localizedClass = addon:GetLocalizedClassName(classHall)
        frame.zoneLabel:SetText(localizedZoneName .. " " .. colorCode .. "(" .. localizedClass .. " " .. L["VENDOR_CLASS_HALL_SUFFIX"] .. ")|r")
    elseif housingZone then
        local localizedFaction = addon:GetLocalizedFactionName(housingZone)
        frame.zoneLabel:SetText(localizedZoneName .. " |cff888888(" .. localizedFaction .. " " .. L["VENDOR_HOUSING_ZONE_SUFFIX"] .. ")|r")
    else
        frame.zoneLabel:SetText(localizedZoneName)
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

    frame:SetScript("OnClick", VendorZoneHeaderOnClick)
    frame:SetScript("OnEnter", VendorZoneHeaderOnEnter)
    frame:SetScript("OnLeave", VendorZoneHeaderOnLeave)
end

-- Check if a decorId can be resolved by any game API or fallback data
local function IsDecorResolvable(decorId)
    if addon:ResolveRecord(decorId) then return true end
    if C_HousingDecor and C_HousingDecor.GetDecorIcon then
        local icon = C_HousingDecor.GetDecorIcon(decorId)
        if icon then return true end
    end
    local fallback = addon.VendorItemFallback and addon.VendorItemFallback[decorId]
    if fallback and fallback.name then return true end
    return false
end

function VendorsTab:SetupVendorRow(frame, elementData)
    local L = addon.L
    local decorIds = {}
    for _, decorId in ipairs(elementData.decorIds or {}) do
        if IsDecorResolvable(decorId) then
            decorIds[#decorIds + 1] = decorId
        end
    end
    local decorCount = #decorIds
    frame:SetHeight(VENDOR_ROW_BASE_HEIGHT + (decorCount * DECOR_ROW_HEIGHT))
    frame.npcId = elementData.npcId
    frame.decorIds = decorIds
    frame.zoneName = elementData.zoneName
    frame.expansionKey = elementData.expansionKey

    addon:ResetBackgroundTexture(frame.bg)
    frame.bg:SetColorTexture(unpack(COLORS.ROW_BG))

    frame.vendorContainer:Show()
    frame.decorContainer:Show()
    frame.decorContainer:SetHeight(decorCount * DECOR_ROW_HEIGHT)

    local vendorDisplayName = addon:GetLocalizedNPCName(elementData.npcId, elementData.npcName) or L["VENDOR_UNKNOWN"]
    local classHall = addon:GetClassHallAnnotation(elementData.zoneName)
    if classHall then
        local colorCode = addon:GetClassColorCode(classHall)
        local localizedClass = addon:GetLocalizedClassName(classHall)
        vendorDisplayName = vendorDisplayName .. " " .. colorCode .. "(" .. string.format(L["VENDOR_CLASS_ONLY_SUFFIX"], localizedClass) .. ")|r"
    end
    frame.vendorName:SetText(vendorDisplayName)
    addon:SetFontSize(frame.vendorName, 14, "")
    frame.vendorName:SetTextColor(unpack(COLORS.SOURCE_NAME_GOLD))

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
        frame.waypointBtn.npcId = elementData.npcId
        frame.waypointBtn.zoneName = elementData.zoneName
        frame.waypointBtn:Show()
    end

    self:SetupDecorRows(frame, decorIds)

    frame:SetScript("OnClick", VendorRowOnClick)
    frame:SetScript("OnEnter", VendorRowOnEnter)
    frame:SetScript("OnLeave", VendorRowOnLeave)

    -- Check if this vendor is currently selected
    local isVendorSelected = self.selectedVendorNpcId == elementData.npcId
    self:UpdateVendorSelectionVisual(frame, isVendorSelected)
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
            selHighlight:SetColorTexture(unpack(COLORS.GOLD))
            selHighlight:Hide()
            row.selectionHighlight = selHighlight

            row:EnableMouse(true)
            row:SetScript("OnClick", VendorDecorRowOnClick)
            row:SetScript("OnEnter", VendorDecorRowOnEnter)
            row:SetScript("OnLeave", VendorDecorRowOnLeave)
            frame.decorRows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.decorContainer, "TOPLEFT", 0, -((i - 1) * DECOR_ROW_HEIGHT))
        row:SetPoint("RIGHT", frame.decorContainer, "RIGHT", 0, 0)
        row:Show()

        local record = addon:ResolveRecord(decorId)
        local fallback = not record and addon.VendorItemFallback and addon.VendorItemFallback[decorId]

        -- Store per-row data for named handlers
        row.decorId = decorId
        row.record = record
        row.fallback = fallback
        row.isCollected = record and record.isCollected
        row.npcId = frame.npcId
        row.zoneName = frame.zoneName

        if record then
            if record.iconType == "atlas" then
                row.icon:SetAtlas(record.icon)
            else
                row.icon:SetTexture(record.icon)
            end
        else
            local decorIcon = C_HousingDecor and C_HousingDecor.GetDecorIcon and C_HousingDecor.GetDecorIcon(decorId)
            row.icon:SetTexture(decorIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
        end

        row.checkIcon:SetShown(row.isCollected)

        local textBrightness = row.isCollected and 0.4 or 0.7
        row.textBrightness = textBrightness
        local displayName = (record and record.name) or (fallback and fallback.name) or string.format(L["VENDORS_DECOR_ID"], decorId)
        row.name:SetText(displayName)
        addon:SetFontSize(row.name, 13, "")

        -- Check if this item is currently selected (composite key: vendor + decor)
        local isItemSelected = self.selectedVendorNpcId == frame.npcId and self.selectedDecorId == decorId
        self:UpdateDecorSelectionVisual(row, isItemSelected, textBrightness)
    end
end

--------------------------------------------------------------------------------
-- Waypoint Functionality
--------------------------------------------------------------------------------

local function GetWaypointXY(point)
    if not point or not point.position then return nil, nil end
    local pos = point.position
    if pos.x and pos.y then
        return pos.x, pos.y
    end
    if pos.GetXY then
        return pos:GetXY()
    end
    return nil, nil
end

local function GetVendorTrackingChatDetails(npcId)
    local L = addon.L

    local vendorEntry = addon.vendorIndex and addon.vendorIndex[npcId]
    local vendorName = vendorEntry and addon:GetLocalizedNPCName(npcId, vendorEntry.npcName)
    if not vendorName or vendorName == "" then
        vendorName = L["VENDOR_FALLBACK_NAME"]
    end

    local zoneCache = addon.vendorZoneCache and addon.vendorZoneCache[npcId]
    local zoneName = zoneCache and addon:GetLocalizedVendorZoneName(zoneCache.zoneName)
    if not zoneName or zoneName == "" then
        zoneName = L["VENDORS_UNKNOWN_ZONE"]
    end

    return vendorName, zoneName
end

local function PrintVendorTrackingMessage(messageKey, npcId)
    local L = addon.L
    local vendorName, zoneName = GetVendorTrackingChatDetails(npcId)
    local vendorText = string.format("|cff80ff80%s|r", vendorName)
    local zoneText = string.format("|cff80c0ff%s|r", zoneName)
    local message = string.format(L[messageKey], vendorText, zoneText)
    if messageKey == "VENDORS_TRACKING_STARTED" then
        local hyperlink = addon.Waypoints:GetHyperlink()
        if hyperlink then
            message = message .. " " .. hyperlink
        end
    end
    addon:Print(message)
end

function VendorsTab:GetVendorTrackPoint(npcId, preferredZoneName)
    -- For multi-location vendors, prefer the location matching the row's zone context
    local locData
    local locations = preferredZoneName and addon:GetNPCLocations(npcId)
    local zoneMapId = locations and #locations > 1 and addon.vendorZoneToMapId and addon.vendorZoneToMapId[preferredZoneName]
    if zoneMapId then
        local zoneRootId = addon:GetZoneRootMapID(zoneMapId)
        if zoneRootId then
            for _, loc in ipairs(locations) do
                if loc.uiMapId and addon:GetZoneRootMapID(loc.uiMapId) == zoneRootId then
                    locData = loc
                    break
                end
            end
        end
    end
    locData = locData or addon:GetNPCLocation(npcId)

    if not locData or not addon.IsValidMapId(locData.uiMapId) or not addon.HasValidCoordinates(locData) then
        return nil, nil, "VENDOR_NO_LOCATION"
    end

    local tomtomActive = addon.Waypoints and addon.Waypoints:IsTomTomActive()
    if not tomtomActive and not C_Map.CanSetUserWaypointOnMap(locData.uiMapId) then
        return nil, nil, "VENDOR_MAP_RESTRICTED"
    end

    local normX, normY = locData.x / 100, locData.y / 100
    if normX < 0 or normX > 1 or normY < 0 or normY > 1 then
        return nil, nil, "VENDOR_NO_LOCATION"
    end

    local point = UiMapPoint.CreateFromCoordinates(locData.uiMapId, normX, normY)
    return point, locData, nil
end

function VendorsTab:CanVendorTrackDecor(npcId)
    local point = self:GetVendorTrackPoint(npcId)
    return point ~= nil
end

function VendorsTab:IsCurrentWaypointForVendor(npcId)
    if not npcId then return false end

    local locations = addon:GetNPCLocations(npcId)
    if not locations then return false end

    -- TomTom mode: compare against module state
    if addon.Waypoints and addon.Waypoints:IsTomTomActive() then
        local active = addon.Waypoints:GetActive()
        if not active then return false end
        for _, locData in ipairs(locations) do
            if active.mapID == locData.uiMapId and addon.HasValidCoordinates(locData) then
                local vendorX = locData.x / 100
                local vendorY = locData.y / 100
                if math.abs(active.x - vendorX) <= WAYPOINT_MATCH_EPSILON
                    and math.abs(active.y - vendorY) <= WAYPOINT_MATCH_EPSILON then
                    return true
                end
            end
        end
        return false
    end

    -- Native mode
    if not C_Map.HasUserWaypoint() then return false end
    local point = C_Map.GetUserWaypoint()
    if not point then return false end

    for _, locData in ipairs(locations) do
        if point.uiMapID == locData.uiMapId and addon.HasValidCoordinates(locData) then
            local x, y = GetWaypointXY(point)
            if x and y then
                local vendorX = locData.x / 100
                local vendorY = locData.y / 100
                if math.abs(x - vendorX) <= WAYPOINT_MATCH_EPSILON
                    and math.abs(y - vendorY) <= WAYPOINT_MATCH_EPSILON then
                    return true
                end
            end
        end
    end
    return false
end

function VendorsTab:IsVendorDecorTracked(npcId, decorId)
    if not npcId or not decorId then return false end

    return self.activeTrackedNpcId == npcId
        and self.activeTrackedDecorId == decorId
        and self:IsCurrentWaypointForVendor(npcId)
end

function VendorsTab:HasActiveVendorTracking()
    return self.activeTrackedNpcId ~= nil and self.activeTrackedDecorId ~= nil
end

function VendorsTab:OnUserWaypointUpdated()
    self:ReconcileVendorTrackingWithWaypoint()
end

function VendorsTab:EnsureWaypointListenerState()
    local shouldListen = self:HasActiveVendorTracking()

    if shouldListen and not self.waypointListenerRegistered then
        addon:RegisterWoWEvent("USER_WAYPOINT_UPDATED", self.onUserWaypointUpdated)
        self.waypointListenerRegistered = true
    elseif not shouldListen and self.waypointListenerRegistered then
        addon:UnregisterWoWEvent("USER_WAYPOINT_UPDATED", self.onUserWaypointUpdated)
        self.waypointListenerRegistered = false
    end
end

function VendorsTab:ClearVendorTrackedState()
    if not self:HasActiveVendorTracking() then
        self:EnsureWaypointListenerState()
        return
    end

    local oldNpcId = self.activeTrackedNpcId
    local oldDecorId = self.activeTrackedDecorId
    self.activeTrackedNpcId = nil
    self.activeTrackedDecorId = nil
    addon:FireEvent("VENDOR_TRACKING_CHANGED", oldNpcId, oldDecorId, false)
    self:EnsureWaypointListenerState()
end

function VendorsTab:ReconcileVendorTrackingWithWaypoint()
    if not self:HasActiveVendorTracking() then
        self:EnsureWaypointListenerState()
        return
    end

    if not self:IsCurrentWaypointForVendor(self.activeTrackedNpcId) then
        self:ClearVendorTrackedState()
    end
end

function VendorsTab:ToggleVendorDecorTracking(npcId, decorId, zoneName)
    local L = addon.L
    if not npcId or not decorId then return end

    self:ReconcileVendorTrackingWithWaypoint()

    if self:IsVendorDecorTracked(npcId, decorId) then
        addon.Waypoints:Clear()
        self:ClearVendorTrackedState()
        PrintVendorTrackingMessage("VENDORS_TRACKING_STOPPED", npcId)
        return
    end

    local point, locData, errorKey = self:GetVendorTrackPoint(npcId, zoneName)
    if not point then
        addon:Print(L[errorKey] or L["VENDOR_MAP_RESTRICTED"])
        return
    end

    local vendorEntry = addon.vendorIndex and addon.vendorIndex[npcId]
    local vendorName = vendorEntry and addon:GetLocalizedNPCName(npcId, vendorEntry.npcName) or L["VENDOR_FALLBACK_NAME"]
    if not addon.Waypoints:Set(locData.uiMapId, locData.x / 100, locData.y / 100, vendorName) then
        return
    end

    self.activeTrackedNpcId = npcId
    self.activeTrackedDecorId = decorId
    addon:FireEvent("VENDOR_TRACKING_CHANGED", npcId, decorId, true)
    self:EnsureWaypointListenerState()
    PrintVendorTrackingMessage("VENDORS_TRACKING_STARTED", npcId)
end

function VendorsTab:SetWaypoint(npcId, npcName, zoneName)
    local L = addon.L
    npcName = addon:GetLocalizedNPCName(npcId, npcName)
    local point, locData, errorKey = self:GetVendorTrackPoint(npcId, zoneName)
    if not point then
        addon:Print(L[errorKey] or L["VENDOR_MAP_RESTRICTED"])
        return
    end

    if not addon.Waypoints:Set(locData.uiMapId, locData.x / 100, locData.y / 100, npcName or L["VENDOR_FALLBACK_NAME"]) then
        return
    end

    addon:Print(string.format(L["VENDOR_WAYPOINT_SET"], npcName or L["VENDOR_FALLBACK_NAME"]))

    if not InCombatLockdown() then
        if OpenWorldMap then OpenWorldMap(locData.uiMapId) end
    end
end

--------------------------------------------------------------------------------
-- Zone Expand/Collapse
--------------------------------------------------------------------------------

function VendorsTab:IsZoneExpanded(expansionKey, zoneName)
    local db = GetVendorsDB()
    if not db or not db.expandedZones then return false end
    local key = expansionKey .. ":" .. zoneName
    return db.expandedZones[key] == true
end

function VendorsTab:ToggleZone(expansionKey, zoneName)
    local db = GetVendorsDB()
    if db and db.expandedZones then
        local key = expansionKey .. ":" .. zoneName
        db.expandedZones[key] = not db.expandedZones[key]
    end
    local scrollBox = self.vendorScrollBox
    local scrollOffset = scrollBox and scrollBox:GetDerivedScrollOffset() or 0
    self:BuildVendorDisplay()
    if scrollOffset > 0 then
        scrollBox:ScrollToOffset(scrollOffset, ScrollBoxConstants.NoScrollInterpolation)
    end
end

function VendorsTab:NavigateToVendor(npcId)
    if not npcId then return end

    local zoneCache = addon.vendorZoneCache and addon.vendorZoneCache[npcId]
    if not zoneCache then return end

    local zoneName = zoneCache.zoneName
    local expansionKey = zoneCache.expansionKey
    if not zoneName or not expansionKey then return end

    -- Clear search and set filter to "all" to guarantee vendor visibility
    if self.searchBox then
        self.searchBox:SetText("")
    end
    self:SetCompletionFilter("all")

    -- Select the expansion (rebuilds display internally)
    self:SelectExpansion(expansionKey)

    -- Expand the target zone
    local db = GetVendorsDB()
    if db then
        local key = expansionKey .. ":" .. zoneName
        db.expandedZones[key] = true
    end
    self:BuildVendorDisplay()

    -- Select the vendor's first decor item to show 3D preview
    local vendorData = addon.vendorIndex and addon.vendorIndex[npcId]
    local firstDecorId = vendorData and vendorData.decorIds and vendorData.decorIds[1]
    if firstDecorId then
        self.selectedVendorNpcId = npcId
        self.selectedDecorId = firstDecorId
        addon:FireEvent("RECORD_SELECTED", firstDecorId)
    end

    -- Next frame: scroll to the vendor row
    C_Timer.After(0, function()
        if not self.vendorScrollBox then return end
        self.vendorScrollBox:ScrollToElementDataByPredicate(function(elementData)
            return elementData.npcId == npcId
        end, ScrollBoxConstants.AlignNearest, ScrollBoxConstants.NoScrollInterpolation)
    end)
end

function VendorsTab:NavigateFromProgress(expansionKey)
    if self.searchBox then
        self.searchBox:SetText("")
    end
    -- Clear "Current Zone" filter so all vendors in the expansion are visible
    if self.currentZoneCheckbox then
        self.currentZoneCheckbox:SetChecked(false)
    end
    self.currentZoneOnly = false
    self:SetCompletionFilter("incomplete", true)
    if not expansionKey then
        local expansions = addon:GetSortedVendorExpansions()
        expansionKey = expansions[1]
    end
    if expansionKey then self:SelectExpansion(expansionKey) end
end

--------------------------------------------------------------------------------
-- Current Zone Filter
--------------------------------------------------------------------------------

function VendorsTab:UpdatePlayerZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then
        self.playerZoneRootMapID = nil
        return
    end
    self.playerZoneRootMapID = addon:GetZoneRootMapID(mapID)
end

local function VendorZoneMatchesPlayerZone(zoneName)
    local playerRoot = VendorsTab.playerZoneRootMapID
    if not playerRoot then return false end

    local vendorMapID = addon.vendorZoneToMapId and addon.vendorZoneToMapId[zoneName]
    if not vendorMapID then return false end

    local vendorRoot = addon:GetZoneRootMapID(vendorMapID)
    if not vendorRoot then return false end

    -- Direct match
    if vendorRoot == playerRoot then return true end

    -- Player is in a city that belongs to the vendor's zone
    local cityChildren = addon:GetCityChildMapIDs(vendorRoot)
    if cityChildren then
        for _, cityMapID in ipairs(cityChildren) do
            if cityMapID == playerRoot then return true end
        end
    end

    -- Player is in a zone that has the vendor's city as a child
    local playerCityChildren = addon:GetCityChildMapIDs(playerRoot)
    if playerCityChildren then
        for _, cityMapID in ipairs(playerCityChildren) do
            if cityMapID == vendorRoot then return true end
        end
    end

    return false
end

--------------------------------------------------------------------------------
-- Search/Filter Logic (with per-refresh memoization)
--------------------------------------------------------------------------------

local function VendorMatchesSearch(vendorData, searchText, zoneName, expansionKey)
    if searchText == "" then return true end

    local cacheKey = vendorData.npcId .. ":" .. zoneName .. ":" .. expansionKey
    if searchCache and searchCache[cacheKey] ~= nil then return searchCache[cacheKey] end

    local localizedZoneName = addon:GetLocalizedVendorZoneName(zoneName)
    local localizedNpcName = addon:GetLocalizedNPCName(vendorData.npcId, vendorData.npcName)
    local result = false

    if vendorData.npcName and strlower(vendorData.npcName):find(searchText, 1, true) then
        result = true
    elseif localizedNpcName and localizedNpcName ~= vendorData.npcName and strlower(localizedNpcName):find(searchText, 1, true) then
        result = true
    elseif strlower(zoneName):find(searchText, 1, true) then
        result = true
    elseif localizedZoneName ~= zoneName and strlower(localizedZoneName):find(searchText, 1, true) then
        result = true
    elseif strlower(addon.L[expansionKey] or expansionKey):find(searchText, 1, true) then
        result = true
    elseif strlower(vendorData.currencyName or addon.L["CURRENCY_GOLD"]):find(searchText, 1, true) then
        result = true
    elseif vendorData.currencyName then
        local localizedCurrency = addon:GetLocalizedCurrencyName(vendorData.currencyName)
        if localizedCurrency ~= vendorData.currencyName and strlower(localizedCurrency):find(searchText, 1, true) then
            result = true
        end
    end

    if not result then
        for _, decorId in ipairs(vendorData.decorIds or {}) do
            local record = addon:GetRecord(decorId)
            if record and record.name and strlower(record.name):find(searchText, 1, true) then
                result = true
                break
            end
            local fallback = not record and addon.VendorItemFallback and addon.VendorItemFallback[decorId]
            if fallback and fallback.name and strlower(fallback.name):find(searchText, 1, true) then
                result = true
                break
            end
        end
    end

    if searchCache then searchCache[cacheKey] = result end
    return result
end

local function VendorPassesCompletionFilter(vendorData, filter, zoneName, expansionKey)
    if filter == "all" then return true end

    local cacheKey = vendorData.npcId .. ":" .. zoneName .. ":" .. expansionKey
    if filterCache and filterCache[cacheKey] ~= nil then return filterCache[cacheKey] end

    local owned, total = 0, 0
    for _, decorId in ipairs(vendorData.decorIds or {}) do
        total = total + 1
        if addon:IsDecorCollected(decorId) then owned = owned + 1 end
    end

    local isComplete = total > 0 and owned == total
    local result
    if filter == "complete" then result = isComplete
    else result = not isComplete end

    if filterCache then filterCache[cacheKey] = result end
    return result
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

-- Map WoW expansion level (from GetMaximumExpansionLevel) to addon expansion key
local EXPANSION_LEVEL_TO_KEY = {
    [0]  = "EXPANSION_CLASSIC",
    [1]  = "EXPANSION_TBC",
    [2]  = "EXPANSION_WRATH",
    [3]  = "EXPANSION_CATA",
    [4]  = "EXPANSION_MOP",
    [5]  = "EXPANSION_WOD",
    [6]  = "EXPANSION_LEGION",
    [7]  = "EXPANSION_BFA",
    [8]  = "EXPANSION_SL",
    [9]  = "EXPANSION_DF",
    [10] = "EXPANSION_TWW",
    [11] = "EXPANSION_MIDNIGHT",
}

function VendorsTab:BuildExpansionDisplay()
    if not self.expansionScrollBox or not self.expansionDataProvider then return end

    local elements = {}
    local filter = self:GetCompletionFilter()
    local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

    local zoneFilterActive = self.currentZoneOnly

    for _, expansionKey in ipairs(addon:GetSortedVendorExpansions()) do
        local hasVisibleContent = false
        for _, zoneName in ipairs(addon:GetSortedVendorZones(expansionKey)) do
            if not zoneFilterActive or VendorZoneMatchesPlayerZone(zoneName) then
                for _, vendorData in ipairs(addon:GetVendorsForZone(expansionKey, zoneName)) do
                    if VendorPassesCompletionFilter(vendorData, filter, zoneName, expansionKey)
                        and VendorMatchesSearch(vendorData, searchText, zoneName, expansionKey) then
                        hasVisibleContent = true
                        break
                    end
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
        local defaultKey = EXPANSION_LEVEL_TO_KEY[GetMaximumExpansionLevel()] or "EXPANSION_TWW"
        self:SelectExpansion(FindExpansionInList(elements, defaultKey) and defaultKey or elements[1].expansionKey)
        return true
    elseif self.selectedExpansionKey and not FindExpansionInList(elements, self.selectedExpansionKey) then
        if #elements > 0 then
            self:SelectExpansion(elements[1].expansionKey)
            return true
        else
            self.selectedExpansionKey = nil
            self:BuildVendorDisplay()
            return true
        end
    end
    return false
end

function VendorsTab:BuildVendorDisplay()
    if not self.vendorScrollBox or not self.vendorDataProvider then return end

    local elements = {}
    local expansionKey = self.selectedExpansionKey

    if expansionKey then
        local filter = self:GetCompletionFilter()
        local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))
        local zoneFilterActive = self.currentZoneOnly
        local isForceExpanded = zoneFilterActive or searchText ~= ""

        for _, zoneName in ipairs(addon:GetSortedVendorZones(expansionKey)) do
            if not zoneFilterActive or VendorZoneMatchesPlayerZone(zoneName) then
                local zoneVendors = {}
                for _, vendorData in ipairs(addon:GetVendorsForZone(expansionKey, zoneName)) do
                    if VendorPassesCompletionFilter(vendorData, filter, zoneName, expansionKey)
                        and VendorMatchesSearch(vendorData, searchText, zoneName, expansionKey) then
                        table.insert(zoneVendors, vendorData)
                    end
                end

                if #zoneVendors > 0 then
                    table.insert(elements, { isZoneHeader = true, expansionKey = expansionKey, zoneName = zoneName, isForceExpanded = isForceExpanded })
                    if isForceExpanded or self:IsZoneExpanded(expansionKey, zoneName) then
                        for _, vendor in ipairs(zoneVendors) do
                            table.insert(elements, {
                                npcId = vendor.npcId,
                                npcName = vendor.npcName,
                                decorIds = vendor.decorIds,
                                zoneName = zoneName,
                                expansionKey = expansionKey,
                            })
                        end
                    end
                end
            end
        end
    end

    -- Clear stale selection if the selected vendor is no longer in the visible list
    if self.selectedVendorNpcId then
        local found = false
        for _, el in ipairs(elements) do
            if el.npcId == self.selectedVendorNpcId then
                found = true
                break
            end
        end
        if not found then
            self.selectedVendorNpcId = nil
            self.selectedDecorId = nil
            addon:FireEvent("RECORD_SELECTED", nil)
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

VendorsTab:RegisterTabVisibility("VENDORS")

addon:RegisterInternalEvent("DATA_LOADED", function()
    if VendorsTab:IsShown() then
        VendorsTab:RefreshDisplay()
        VendorsTab:UpdateEmptyStates()
    end
end)

VendorsTab:RegisterOwnershipRefresh(function() VendorsTab:RefreshDisplay() end)

-- Reconcile vendor tracking after loading screens/teleports/reloads
addon:RegisterWoWEvent("PLAYER_ENTERING_WORLD", function()
    if VendorsTab.activeTrackedNpcId then
        VendorsTab:ReconcileVendorTrackingWithWaypoint()
    end
    if VendorsTab.currentZoneOnly and VendorsTab:IsShown() then
        VendorsTab:RefreshDisplay()
    end
end)

-- Refresh vendor list when player changes zones while current-zone filter is active
addon:RegisterWoWEvent("ZONE_CHANGED_NEW_AREA", function()
    if VendorsTab.currentZoneOnly and VendorsTab:IsShown() then
        VendorsTab:RefreshDisplay()
    end
end)

addon.MainFrame:RegisterContentAreaInitializer("VendorsTab", function(contentArea)
    VendorsTab:Create(contentArea)
end)
