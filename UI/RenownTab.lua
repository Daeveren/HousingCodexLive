--[[
    Housing Codex - RenownTab.lua
    Reputation sources tab for housing decor.
    Left panel: expansion list with completion %
    Right panel: faction cards with standing, progress bar, and decor item rows
]]

local _, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS
local ICON_CROP_COORDS = CONSTS.ICON_CROP_COORDS

local CATEGORY_PANEL_WIDTH = CONSTS.HIERARCHY_PANEL_WIDTH
local HIERARCHY_PADDING = CONSTS.HIERARCHY_PADDING
local HEADER_HEIGHT = CONSTS.HIERARCHY_HEADER_HEIGHT

local FACTION_ROW_BASE_HEIGHT = 38
local FACTION_GAP = 10
local DECOR_ROW_HEIGHT = 24
local DECOR_ICON_SIZE = 22

local VALID_FILTERS = { all = true, incomplete = true, complete = true }

addon.RenownTab = {}
local RenownTab = addon.RenownTab

Mixin(RenownTab, addon.TabBaseMixin)
RenownTab.tabName = "RenownTab"

local function GetRenownDB()
    return addon.db and addon.db.browser and addon.db.browser.renown
end

local function EnsureRenownDB()
    if not addon.db then return nil end
    addon.db.browser = addon.db.browser or {}
    addon.db.browser.renown = addon.db.browser.renown or {
        selectedExpansion = nil,
        completionFilter = "incomplete",
    }
    return addon.db.browser.renown
end

RenownTab.frame = nil
RenownTab.toolbar = nil
RenownTab.expansionPanel = nil
RenownTab.expansionScrollBox = nil
RenownTab.factionPanel = nil
RenownTab.factionScrollBox = nil
RenownTab.factionScrollBar = nil
RenownTab.searchBox = nil
RenownTab.filterButtons = {}
RenownTab.emptyState = nil
RenownTab.noExpansionState = nil
RenownTab.noResultsState = nil

RenownTab.selectedExpansion = nil
RenownTab.selectedFactionID = nil
RenownTab.selectedDecorId = nil

RenownTab.toolbarLayout = nil
RenownTab.filterContainer = nil

-- WoW event frame for standing updates (registered on Show, unregistered on Hide)
local standingEventFrame = nil

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------

function RenownTab:Create(parent)
    if self.frame then return end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    self.frame = frame

    self:CreateToolbar(frame)
    self:CreateExpansionPanel(frame)
    self:CreateFactionPanel(frame)
    self:CreateEmptyStates()
    self:CreateStandingEventFrame()

    addon:Debug("RenownTab created")
end

function RenownTab:Show()
    if not self.frame then return end

    if not addon.renownIndexBuilt then
        addon:BuildRenownIndex()
    end

    self.frame:Show()

    -- Skip saved-state restore when navigating from Progress (NavigateFromProgress sets its own state)
    if not self.pendingNavigation then
        -- Wipe standing cache so reopening after hidden-period rep changes shows fresh data
        wipe(addon.renownStandingCache)

        local saved = EnsureRenownDB()
        if saved then
            self.selectedExpansion = saved.selectedExpansion
            self:SetCompletionFilter(saved.completionFilter or "incomplete")
        end
    end
    self.pendingNavigation = nil

    self:RegisterStandingEvents()
    self:UpdateEmptyStates()
end

function RenownTab:Hide()
    if self.frame then
        self.frame:Hide()
    end
    self:UnregisterStandingEvents()
end

function RenownTab:IsShown()
    return self.frame and self.frame:IsShown()
end

function RenownTab:NavigateFromProgress(expansionKey)
    if self.searchBox then
        self.searchBox:SetText("")
    end
    self:SetCompletionFilter("incomplete")
    if not expansionKey then
        local expansions = addon:GetSortedRenownExpansions()
        expansionKey = expansions[1]
    end
    if expansionKey then
        self:SelectExpansion(expansionKey)
    end
end

--------------------------------------------------------------------------------
-- Standing Event Registration (Show/Hide pattern per Blizzard)
--------------------------------------------------------------------------------

function RenownTab:CreateStandingEventFrame()
    if standingEventFrame then return end
    standingEventFrame = CreateFrame("Frame")
    standingEventFrame:SetScript("OnEvent", function(_, event)
        wipe(addon.renownStandingCache)
        if event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" then
            addon:FireEvent("RENOWN_LEVEL_CHANGED")
        end
        if RenownTab:IsShown() then
            RenownTab:RefreshDisplay()
        end
    end)
end

function RenownTab:RegisterStandingEvents()
    if not standingEventFrame then return end
    standingEventFrame:RegisterEvent("UPDATE_FACTION")
    standingEventFrame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    standingEventFrame:RegisterEvent("MAJOR_FACTION_UNLOCKED")
end

function RenownTab:UnregisterStandingEvents()
    if not standingEventFrame then return end
    standingEventFrame:UnregisterAllEvents()
end

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------

function RenownTab:CreateToolbar(parent)
    self:CreateStandardToolbar(parent, {
        searchPlaceholderKey = "RENOWN_SEARCH_PLACEHOLDER",
        filterPrefix = "RENOWN",
    })
end

function RenownTab:SetCompletionFilter(filterKey)
    if not VALID_FILTERS[filterKey] then filterKey = "incomplete" end
    for key, btn in pairs(self.filterButtons) do
        btn:SetActive(key == filterKey)
    end
    local db = GetRenownDB()
    if db then db.completionFilter = filterKey end
    self:RefreshDisplay()
end

function RenownTab:GetCompletionFilter()
    local db = GetRenownDB()
    return db and db.completionFilter or "incomplete"
end

function RenownTab:OnSearchTextChanged(_)
    self:RefreshDisplay()
end

--------------------------------------------------------------------------------
-- Expansion Panel (Left Column)
--------------------------------------------------------------------------------

function RenownTab:CreateExpansionPanel(parent)
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

-- Named handlers for expansion buttons
local function ExpansionButtonOnClick(frame)
    RenownTab:SelectExpansion(frame.expansionKey)
end

local function ExpansionButtonOnEnter(frame)
    if RenownTab.selectedExpansion ~= frame.expansionKey then
        frame.bg:SetColorTexture(unpack(COLORS.PANEL_HOVER))
    end
end

local function ExpansionButtonOnLeave(frame)
    RenownTab:ApplySelectionButtonState(frame, RenownTab.selectedExpansion == frame.expansionKey)
end

function RenownTab:SetupExpansionButton(frame, elementData)
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
        label:SetPoint("LEFT", 8, 0)
        label:SetPoint("RIGHT", pct, "LEFT", -4, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        frame.label = label

        frame:EnableMouse(true)
        frame:SetScript("OnClick", ExpansionButtonOnClick)
        frame:SetScript("OnEnter", ExpansionButtonOnEnter)
        frame:SetScript("OnLeave", ExpansionButtonOnLeave)
    end

    frame.expansionKey = elementData.expansionKey

    local isSelected = self.selectedExpansion == elementData.expansionKey
    self:ApplySelectionButtonState(frame, isSelected)

    frame.label:SetText(L[elementData.expansionKey] or elementData.expansionKey)
    addon:SetFontSize(frame.label, 13, "")

    local owned, total = addon:GetRenownExpansionProgress(elementData.expansionKey)
    local pctValue = total > 0 and (owned / total * 100) or 0
    frame.percentLabel:SetText(string.format("%.0f%%", pctValue))
    frame.percentLabel:SetTextColor(addon:GetCompletionProgressColor(pctValue))
    addon:SetFontSize(frame.percentLabel, 11, "")
end

function RenownTab:SelectExpansion(expKey)
    local prevSelected = self.selectedExpansion
    self.selectedExpansion = expKey

    local db = GetRenownDB()
    if db then db.selectedExpansion = expKey end

    if self.expansionScrollBox then
        self.expansionScrollBox:ForEachFrame(function(frame)
            if frame.expansionKey then
                self:ApplySelectionButtonState(frame, frame.expansionKey == expKey)
            end
        end)
    end

    self:BuildFactionDisplay()

    if prevSelected ~= expKey then
        self.selectedFactionID = nil
        self.selectedDecorId = nil
        addon:FireEvent("RECORD_SELECTED", nil)
    end

    self:UpdateEmptyStates()
end

--------------------------------------------------------------------------------
-- Faction Panel (Right Side)
--------------------------------------------------------------------------------

function RenownTab:CreateFactionPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", self.expansionPanel, "TOPRIGHT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.factionPanel = panel

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)

    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", HIERARCHY_PADDING, -HIERARCHY_PADDING)
    scrollContainer:SetPoint("BOTTOMRIGHT", -HIERARCHY_PADDING - 16, HIERARCHY_PADDING)

    local scrollBox = CreateFrame("Frame", nil, scrollContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    self.factionScrollBox = scrollBox

    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollContainer, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollContainer, "BOTTOMRIGHT", 4, 0)
    self.factionScrollBar = scrollBar

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, elementData)
        local decorCount = elementData.visibleDecorCount or 0
        return FACTION_ROW_BASE_HEIGHT + (decorCount * DECOR_ROW_HEIGHT)
    end)
    view:SetPadding(0, 0, 0, 0, FACTION_GAP)
    view:SetElementInitializer("Button", function(frame, elementData)
        self:SetupFactionCard(frame, elementData)
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    scrollBox:SetPanExtent(DECOR_ROW_HEIGHT * 3)
    self.factionView = view

    self.factionDataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(self.factionDataProvider)
end

--------------------------------------------------------------------------------
-- Faction Card Setup
--------------------------------------------------------------------------------

local function FactionCardOnEnter(frame)
    if not frame.factionID then return end
    frame.bg:SetColorTexture(0.12, 0.12, 0.14, 1)
end

local function FactionCardOnLeave(frame)
    frame.bg:SetColorTexture(unpack(COLORS.ROW_BG))
end

local function FactionCardOnClick(frame, button)
    if button == "RightButton" and frame.vendors then
        addon.ContextMenu:ShowForRenownFaction(frame, frame.vendors)
    end
end

-- Named handlers for decor rows
local function DecorRowOnClick(row)
    local decorId = row.decorId
    if not decorId then return end
    if IsShiftKeyDown() then
        addon:ToggleTracking(decorId)
        return
    end
    RenownTab:HandleDecorSelection(row)
end

local function DecorRowOnEnter(row)
    if not row.decorId then return end

    local isSelected = RenownTab.selectedDecorId == row.decorId
    if not isSelected then
        row.name:SetTextColor(1, 1, 1, 1)
    end
    addon:FireEvent("RECORD_SELECTED", row.decorId)

    addon:AnchorTooltipToCursor(row)
    GameTooltip:SetText(addon:ResolveDecorName(row.decorId, row.record), 1, 1, 1)
    if row.isCollected then
        GameTooltip:AddLine(addon.L["FILTER_COLLECTED"], 0.4, 0.9, 0.4)
    end
    if row.vendors then
        for _, vendor in ipairs(row.vendors) do
            local name = addon:GetLocalizedNPCName(vendor.npcId, vendor.name)
            local zone = addon:GetLocalizedVendorZoneName(vendor.zone) or vendor.zone or ""
            GameTooltip:AddDoubleLine(name, zone, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:Show()
end

local function DecorRowOnLeave(row)
    if not row.decorId then return end
    local isSelected = RenownTab.selectedDecorId == row.decorId
    if not isSelected then
        row.name:SetTextColor(row.textBrightness, row.textBrightness, row.textBrightness, 1)
    end
    GameTooltip:Hide()
    RenownTab:RestoreSelectionOnLeave()
end

function RenownTab:HandleDecorSelection(row)
    local decorId = row.decorId
    if self.selectedDecorId == decorId then
        -- Deselect
        row.name:SetTextColor(row.textBrightness, row.textBrightness, row.textBrightness, 1)
        if row.selectionHighlight then row.selectionHighlight:Hide() end
        self.selectedDecorId = nil
        addon:FireEvent("RECORD_SELECTED", nil)
    else
        -- Clear previous
        if self.selectedDecorId then
            self.factionScrollBox:ForEachFrame(function(f)
                if f.decorRows then
                    for _, r in ipairs(f.decorRows) do
                        if r.decorId == self.selectedDecorId then
                            r.name:SetTextColor(r.textBrightness, r.textBrightness, r.textBrightness, 1)
                            if r.selectionHighlight then r.selectionHighlight:Hide() end
                        end
                    end
                end
            end)
        end
        -- Select new
        self.selectedDecorId = decorId
        row.name:SetTextColor(unpack(COLORS.GOLD))
        if row.selectionHighlight then row.selectionHighlight:Show() end
        addon:FireEvent("RECORD_SELECTED", decorId)
    end
end

function RenownTab:RestoreSelectionOnLeave()
    addon:FireEvent("RECORD_SELECTED", self.selectedDecorId)
end

function RenownTab:SetupFactionCard(frame, elementData)
    local L = addon.L

    -- One-time frame setup
    if not frame.initialized then
        self:InitializeFactionFrame(frame)
        frame.initialized = true
    end

    -- Reset state
    self:ResetFactionFrame(frame)

    local factionID = elementData.factionID
    local factionData = elementData.factionData
    local sourceData = addon.RenownSourceData[factionID]
    frame.factionID = factionID
    frame.factionLabel = factionData.label
    frame.vendors = factionData.vendors

    -- Standing info
    local standing = addon:GetFactionStandingInfo(factionID)
    local isUnlocked = standing and standing.isUnlocked
    local hasMet = addon:HasMetStandingRequirement(factionID)
    local requiredStanding = sourceData and sourceData.requiredStanding

    -- Faction name: prefer localized API name, fall back to scraped English label
    local nameText = (standing and standing.factionName) or factionData.label or ("Faction #" .. factionID)
    if factionData.factionSide == "Alliance" then
        nameText = nameText .. "  |TInterface\\PVPFrame\\PVP-Currency-Alliance:14:14:0:0|t"
    elseif factionData.factionSide == "Horde" then
        nameText = nameText .. "  |TInterface\\PVPFrame\\PVP-Currency-Horde:14:14:0:0|t"
    end
    frame.nameLabel:SetText(nameText)
    frame.nameLabel:SetTextColor(unpack(COLORS.SOURCE_NAME_GOLD))
    addon:SetFontSize(frame.nameLabel, 14, "")

    -- Progress count (right side)
    local owned, total = addon:GetFactionRewardProgress(factionID)
    frame.progressCount:SetText(string.format(L["RENOWN_PROGRESS_FORMAT"], owned, total))
    local isAllComplete = total > 0 and owned == total
    frame.progressCount:SetTextColor(unpack(isAllComplete and COLORS.PROGRESS_COMPLETE or COLORS.TEXT_TERTIARY))
    addon:SetFontSize(frame.progressCount, 11, "")

    -- Check if this is an opposing-faction faction the player can never progress
    local playerFaction = UnitFactionGroup("player")
    local isOpposingFaction = factionData.factionSide
        and factionData.factionSide ~= playerFaction

    -- Standing line
    if isOpposingFaction then
        local key = factionData.factionSide == "Horde" and "RENOWN_NEEDS_HORDE" or "RENOWN_NEEDS_ALLIANCE"
        frame.standingLabel:SetText(L[key])
        frame.standingLabel:SetTextColor(0.8, 0.4, 0.19, 1)
    elseif hasMet then
        frame.standingLabel:SetText(L["RENOWN_REP_MET"])
        frame.standingLabel:SetTextColor(0.4, 0.9, 0.4, 1)
    else
        local localizedStanding = requiredStanding
            and addon:LocalizeRequiredStanding(requiredStanding, sourceData and sourceData.kind, factionID)
        local reqPart = localizedStanding
            and ("|cFFCC6630* " .. strlower(string.format(L["RENOWN_REQUIRED"], localizedStanding)) .. "|r")
            or ""
        local statusPart
        if isUnlocked then
            local standingText = standing.standingText or ""
            if not standing.isMaxed and standing.maxValue > 0 then
                standingText = standingText .. string.format(" %d/%d", standing.currentValue, standing.maxValue)
            end
            statusPart = L["RENOWN_CURRENTLY_AT"] .. standingText
        else
            statusPart = L["RENOWN_LOCKED"]
        end
        local text = reqPart ~= "" and (reqPart .. ", " .. statusPart) or statusPart
        frame.standingLabel:SetText(text)
        frame.standingLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    end
    addon:SetFontSize(frame.standingLabel, 12, "")

    -- Decor rows (from resolved entries)
    local entries = elementData.visibleEntries or {}
    local decorCount = #entries
    frame:SetHeight(FACTION_ROW_BASE_HEIGHT + (decorCount * DECOR_ROW_HEIGHT))
    frame.decorContainer:SetHeight(decorCount * DECOR_ROW_HEIGHT)
    frame.decorContainer:Show()

    self:SetupDecorRows(frame, entries, factionID, factionData.vendors)
end

function RenownTab:InitializeFactionFrame(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetColorTexture(unpack(COLORS.ROW_BG))
    frame.bg = bg

    -- Header area
    local headerContainer = CreateFrame("Frame", nil, frame)
    headerContainer:SetPoint("TOPLEFT", 8, 0)
    headerContainer:SetPoint("TOPRIGHT", -8, 0)
    headerContainer:SetHeight(FACTION_ROW_BASE_HEIGHT)
    frame.headerContainer = headerContainer

    -- Row 1: faction name + progress count
    local nameLabel = addon:CreateFontString(headerContainer, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 4, -6)
    nameLabel:SetPoint("RIGHT", -60, 0)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetWordWrap(false)
    frame.nameLabel = nameLabel

    local progressCount = addon:CreateFontString(headerContainer, "OVERLAY", "GameFontNormal")
    progressCount:SetPoint("TOPRIGHT", -4, -6)
    progressCount:SetJustifyH("RIGHT")
    frame.progressCount = progressCount

    -- Row 2: standing requirement + current standing (+2px gap below name)
    local standingLabel = addon:CreateFontString(headerContainer, "OVERLAY", "GameFontNormal")
    standingLabel:SetPoint("TOPLEFT", 4, -24)
    standingLabel:SetPoint("RIGHT", -60, 0)
    standingLabel:SetJustifyH("LEFT")
    standingLabel:SetWordWrap(false)
    frame.standingLabel = standingLabel

    -- Decor sub-rows container
    local decorContainer = CreateFrame("Frame", nil, frame)
    decorContainer:SetPoint("TOPLEFT", headerContainer, "BOTTOMLEFT", 0, 0)
    decorContainer:SetPoint("TOPRIGHT", headerContainer, "BOTTOMRIGHT", 0, 0)
    frame.decorContainer = decorContainer

    frame.decorRows = {}
    frame:EnableMouse(true)
    frame:RegisterForClicks("AnyUp")
    frame:SetScript("OnEnter", FactionCardOnEnter)
    frame:SetScript("OnLeave", FactionCardOnLeave)
    frame:SetScript("OnClick", FactionCardOnClick)
end

function RenownTab:ResetFactionFrame(frame)
    frame.factionID = nil
    frame.factionLabel = nil
    frame.vendors = nil
    frame.headerContainer:Show()
    frame.decorContainer:Hide()

    for _, row in ipairs(frame.decorRows) do
        row:Hide()
        if row.selectionHighlight then
            row.selectionHighlight:Hide()
        end
    end
end

function RenownTab:SetupDecorRows(frame, entries, factionID, vendors)
    for i, entry in ipairs(entries) do
        local isTable = type(entry) == "table"
        local decorId = isTable and entry.decorId or entry
        local itemReqStanding = isTable and entry.requiredStanding
        local itemReqRankLevel = isTable and entry.requiredRankLevel
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

            -- Selection highlight
            local selHighlight = row:CreateTexture(nil, "BACKGROUND")
            selHighlight:SetWidth(2)
            selHighlight:SetPoint("TOPLEFT", 0, 0)
            selHighlight:SetPoint("BOTTOMLEFT", 0, 0)
            selHighlight:SetColorTexture(unpack(COLORS.GOLD))
            selHighlight:Hide()
            row.selectionHighlight = selHighlight

            row:EnableMouse(true)
            row:SetScript("OnClick", DecorRowOnClick)
            row:SetScript("OnEnter", DecorRowOnEnter)
            row:SetScript("OnLeave", DecorRowOnLeave)
            frame.decorRows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.decorContainer, "TOPLEFT", 0, -((i - 1) * DECOR_ROW_HEIGHT))
        row:SetPoint("RIGHT", frame.decorContainer, "RIGHT", 0, 0)
        row:Show()

        local record = addon:ResolveRecord(decorId)

        -- Store per-row data for named handlers
        row.decorId = decorId
        row.record = record
        row.isCollected = record and record.isCollected
        row.vendors = vendors

        if record and record.icon then
            if record.iconType == "atlas" then
                row.icon:SetAtlas(record.icon)
            else
                row.icon:SetTexture(record.icon)
            end
        else
            row.icon:SetTexture(addon:ResolveDecorIcon(decorId))
        end

        row.checkIcon:SetShown(row.isCollected)

        -- Check if this item's specific standing requirement is unmet
        local itemRepUnmet = false
        if itemReqStanding and not row.isCollected then
            itemRepUnmet = not addon:HasMetItemStandingRequirement(factionID, itemReqStanding, itemReqRankLevel)
        end

        local textBrightness = row.isCollected and 0.4 or 0.7
        row.textBrightness = textBrightness
        row.itemRepUnmet = itemRepUnmet
        local displayName = addon:ResolveDecorName(decorId, record)
        -- Append " *" for items with unmet per-item reputation
        if itemRepUnmet then
            displayName = displayName .. "  |cFFCC6630*|r"
        end
        row.name:SetText(displayName)
        addon:SetFontSize(row.name, 13, "")

        -- Check if this item is currently selected
        local isItemSelected = self.selectedDecorId == decorId
        if isItemSelected then
            row.name:SetTextColor(unpack(COLORS.GOLD))
            if row.selectionHighlight then row.selectionHighlight:Show() end
        else
            row.name:SetTextColor(textBrightness, textBrightness, textBrightness, 1)
        end
    end
end

--------------------------------------------------------------------------------
-- Search/Filter Logic
--------------------------------------------------------------------------------

local function FactionMatchesSearch(factionData, searchText)
    if searchText == "" then return true end

    -- English label (scraped)
    if factionData.label and strlower(factionData.label):find(searchText, 1, true) then
        return true
    end

    -- Localized faction name from standing cache
    local standing = addon.renownStandingCache[factionData.factionID]
    if standing and standing.factionName and standing.factionName ~= factionData.label
        and strlower(standing.factionName):find(searchText, 1, true) then
        return true
    end

    if factionData.group and strlower(factionData.group):find(searchText, 1, true) then
        return true
    end

    if factionData.vendors then
        for _, vendor in ipairs(factionData.vendors) do
            -- English vendor name
            if vendor.name and strlower(vendor.name):find(searchText, 1, true) then
                return true
            end
            -- Localized vendor name
            local localizedName = addon:GetLocalizedNPCName(vendor.npcId, vendor.name)
            if localizedName ~= vendor.name and strlower(localizedName):find(searchText, 1, true) then
                return true
            end
            -- English zone
            if vendor.zone and strlower(vendor.zone):find(searchText, 1, true) then
                return true
            end
            -- Localized zone
            local localizedZone = addon:GetLocalizedVendorZoneName(vendor.zone)
            if localizedZone and localizedZone ~= vendor.zone and strlower(localizedZone):find(searchText, 1, true) then
                return true
            end
        end
    end

    -- Match decor item names
    if factionData.resolvedDecorIds then
        for _, decorId in ipairs(factionData.resolvedDecorIds) do
            local name = addon:ResolveDecorName(decorId, addon:GetRecord(decorId))
            if name and strlower(name):find(searchText, 1, true) then
                return true
            end
        end
    end

    return false
end

local function FactionPassesCompletionFilter(factionID, filter)
    if filter == "all" then return true end

    local owned, total = addon:GetFactionRewardProgress(factionID)
    if total == 0 then return false end

    if filter == "complete" then return owned == total end
    if filter == "incomplete" then return owned ~= total end
    return true
end

local function GetVisibleDecorEntries(resolvedDecorIds, filter)
    if not resolvedDecorIds or #resolvedDecorIds == 0 then return {} end

    local visible = {}
    for _, entry in ipairs(resolvedDecorIds) do
        local isTable = type(entry) == "table"
        local decorId = isTable and entry.decorId or entry

        -- Skip items that can't be resolved by the housing catalog (? icon, no preview)
        if addon:ResolveRecord(decorId) then
            local isCollected = addon:IsDecorCollected(decorId)
            if not (filter == "incomplete" and isCollected) then
                table.insert(visible, {
                    decorId = decorId,
                    requiredStanding = isTable and entry.requiredStanding,
                    requiredRankLevel = isTable and entry.requiredRankLevel,
                })
            end
        end
    end
    return visible
end

--------------------------------------------------------------------------------
-- Visibility Cache
--------------------------------------------------------------------------------

local function BuildFactionVisibilityCache(filter, searchText)
    local cache = {}
    for _, expKey in ipairs(addon:GetSortedRenownExpansions()) do
        for _, faction in ipairs(addon:GetFactionsForExpansion(expKey)) do
            if FactionPassesCompletionFilter(faction.factionID, filter)
                and FactionMatchesSearch(faction, searchText) then
                cache[expKey .. "\0" .. faction.factionID] = true
            end
        end
    end
    return cache
end

local function IsFactionVisible(factionID, expKey, visCache)
    return visCache[expKey .. "\0" .. factionID] or false
end

--------------------------------------------------------------------------------
-- Display Building
--------------------------------------------------------------------------------

local function FindExpansionInList(elements, expKey)
    for _, elem in ipairs(elements) do
        if elem.expansionKey == expKey then return true end
    end
    return false
end

function RenownTab:BuildExpansionDisplay(visCache)
    if not self.expansionScrollBox or not self.expansionDataProvider then return false end

    local elements = {}

    for _, expKey in ipairs(addon:GetSortedRenownExpansions()) do
        local hasVisibleContent = false
        for _, faction in ipairs(addon:GetFactionsForExpansion(expKey)) do
            if IsFactionVisible(faction.factionID, expKey, visCache) then
                hasVisibleContent = true
                break
            end
        end
        if hasVisibleContent then
            table.insert(elements, { expansionKey = expKey })
        end
    end

    self.expansionDataProvider:Flush()
    if #elements > 0 then
        self.expansionDataProvider:InsertTable(elements)
    end

    local selectionLost = self.selectedExpansion and not FindExpansionInList(elements, self.selectedExpansion)
    if #elements > 0 and (not self.selectedExpansion or selectionLost) then
        self:SelectExpansion(elements[1].expansionKey)
        return true
    end
    if selectionLost then
        self.selectedExpansion = nil
        self.selectedFactionID = nil
        self.selectedDecorId = nil
        local db = GetRenownDB()
        if db then db.selectedExpansion = nil end
        self:BuildFactionDisplay()
        return true
    end
    return false
end

function RenownTab:BuildFactionDisplay(visCache)
    if not self.factionScrollBox or not self.factionDataProvider then return end

    if not visCache then
        local filter = self:GetCompletionFilter()
        local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))
        visCache = BuildFactionVisibilityCache(filter, searchText)
    end

    local elements = {}
    local expKey = self.selectedExpansion

    if expKey then
        local filter = self:GetCompletionFilter()

        for _, faction in ipairs(addon:GetFactionsForExpansion(expKey)) do
            if IsFactionVisible(faction.factionID, expKey, visCache) then
                local visibleEntries = GetVisibleDecorEntries(faction.resolvedDecorEntries or faction.resolvedDecorIds, filter)
                if #visibleEntries > 0 then
                    table.insert(elements, {
                        factionID = faction.factionID,
                        factionData = faction,
                        visibleEntries = visibleEntries,
                        visibleDecorCount = #visibleEntries,
                    })
                end
            end
        end
    end

    self.factionDataProvider:Flush()
    if #elements > 0 then
        self.factionDataProvider:InsertTable(elements)
    end

    self:UpdateEmptyStates()
end

function RenownTab:RefreshDisplay()
    addon:CountDebug("rebuild", "RenownTab")

    local filter = self:GetCompletionFilter()
    local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))
    local visCache = BuildFactionVisibilityCache(filter, searchText)

    local rebuilt = self:BuildExpansionDisplay(visCache)
    if not rebuilt then self:BuildFactionDisplay(visCache) end
end

--------------------------------------------------------------------------------
-- Empty States
--------------------------------------------------------------------------------

function RenownTab:CreateEmptyStates()
    self.emptyState = addon:CreateEmptyStateFrame(
        self.expansionPanel,
        "RENOWN_EMPTY_NO_DATA",
        nil,
        CATEGORY_PANEL_WIDTH - 16
    )
    self.noExpansionState = addon:CreateEmptyStateFrame(self.factionPanel, "RENOWN_SELECT_EXPANSION")
    self.noResultsState = addon:CreateEmptyStateFrame(self.factionPanel, "RENOWN_EMPTY_NO_RESULTS")
end

function RenownTab:UpdateEmptyStates()
    local hasFactions = addon:GetRenownFactionCount() > 0
    local hasSelection = self.selectedExpansion ~= nil
    local hasExpansions = self.expansionDataProvider and self.expansionDataProvider:GetSize() > 0
    local dataProvider = self.factionScrollBox and self.factionScrollBox:GetDataProvider()
    local hasResults = dataProvider and dataProvider:GetSize() > 0
    local showFactionList = hasFactions and hasSelection and hasResults

    if self.emptyState then self.emptyState:SetShown(not hasFactions) end
    if self.noExpansionState then self.noExpansionState:SetShown(hasFactions and not hasSelection and hasExpansions) end
    if self.noResultsState then self.noResultsState:SetShown(hasFactions and ((hasSelection and not hasResults) or not hasExpansions)) end
    if self.expansionScrollBox then self.expansionScrollBox:SetShown(hasFactions) end
    if self.factionScrollBox then self.factionScrollBox:SetShown(showFactionList) end
    if self.factionScrollBar then self.factionScrollBar:SetShown(showFactionList) end
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

RenownTab:RegisterTabVisibility("RENOWN")

addon:RegisterInternalEvent("DATA_LOADED", function()
    addon.renownIndexBuilt = false
    if RenownTab:IsShown() then
        addon:BuildRenownIndex()
        RenownTab:RefreshDisplay()
    end
end)

RenownTab:RegisterOwnershipRefresh(function() RenownTab:RefreshDisplay() end)

addon.MainFrame:RegisterContentAreaInitializer("RenownTab", function(contentArea)
    RenownTab:Create(contentArea)
end)
