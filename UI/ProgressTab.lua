--[[
    Housing Codex - ProgressTab.lua
    Collection progress dashboard with click navigation to source tabs.
    Sidebar summary panel + two-column layout with StatusBar progress fills.
]]

local _, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS

-- Layout constants
local SIDEBAR_WIDTH = CONSTS.SIDEBAR_WIDTH
local SECTION_PADDING = 16
local ROW_HEIGHT = 28
local ROW_SPACING = ROW_HEIGHT + 2
local CONTENT_PADDING = 20
local COLUMN_GAP = 16
local SIDEBAR_SECTION_GAP = 10
local SIDEBAR_GROUP_GAP = 8
local BUDGET_BAR_HEIGHT = 20
local BUDGET_ROW_SPACING = 32
local HOUSE_HEADER_ROW_SPACING = 24
local HOUSE_PLOT_SECTION_GAP = 10
local SIDEBAR_HISTORY_BOTTOM_GAP = 6

local SOURCE_LABEL_KEYS = {
    QUESTS       = "PROGRESS_SOURCE_QUESTS",
    VENDORS      = "PROGRESS_SOURCE_VENDORS",
    RENOWN       = "PROGRESS_SOURCE_RENOWN",
    ACHIEVEMENTS = "PROGRESS_SOURCE_ACHIEVEMENTS",
    DROPS        = "PROGRESS_SOURCE_DROPS",
    PVP          = "PROGRESS_SOURCE_PVP",
    PROFESSIONS  = "PROGRESS_SOURCE_PROFESSIONS",
}

addon.ProgressTab = {}
local ProgressTab = addon.ProgressTab

Mixin(ProgressTab, addon.TabBaseMixin)
ProgressTab.tabName = "ProgressTab"

ProgressTab.frame = nil
ProgressTab.scrollFrame = nil
ProgressTab.scrollChild = nil
ProgressTab.sidePanel = nil
ProgressTab.sideContent = nil
ProgressTab.sideScrollFrame = nil
ProgressTab.sideScrollChild = nil
ProgressTab.sideScrollTrack = nil
ProgressTab.sideScrollThumb = nil
ProgressTab.sidebarElements = {}
ProgressTab.sourceRows = {}
ProgressTab.professionRows = {}
ProgressTab.vendorExpRows = {}
ProgressTab.almostThereRows = {}
ProgressTab.questExpRows = {}
ProgressTab.renownExpRows = {}
ProgressTab.pvpCategoryRows = {}
ProgressTab.achievementCatRows = {}
ProgressTab.dropCatRows = {}

local function GetSafeCursorY()
    local _, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not addon:IsUsableUINumber(cursorY) or not addon:IsUsableUINumber(scale) or scale <= 0 then
        return nil
    end

    return cursorY / scale
end

-- Override: gray for <100%, green at 100%
function ProgressTab:GetProgressColor(percent)
    if percent == 100 then
        return COLORS.PROGRESS_COMPLETE
    end
    return COLORS.TEXT_TERTIARY
end

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------

function ProgressTab:Create(parent)
    if self.frame then return end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    self.frame = frame

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)

    self:CreateScrollFrame(frame)
    self:CreateSidebarPanel(frame)

    addon:Debug("ProgressTab created")
end

function ProgressTab:CreateSidebarPanel(parent)
    local TRACK_WIDTH = 6
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", -SIDEBAR_WIDTH, 0)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -SIDEBAR_WIDTH, 0)
    panel:SetWidth(SIDEBAR_WIDTH)
    panel:Hide()
    self.sidePanel = panel

    -- Background (matches sidebar)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel)
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 0)
    self.sideScrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(SIDEBAR_WIDTH - 14)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    self.sideScrollChild = scrollChild
    self.sideContent = scrollChild

    local track = CreateFrame("Frame", nil, panel)
    track:SetWidth(TRACK_WIDTH)
    track:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -8)
    track:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 8)
    track:EnableMouse(true)
    track:Hide()
    self.sideScrollTrack = track

    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.1, 0.1, 0.12, 0.3)

    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetWidth(TRACK_WIDTH)
    self.sideScrollThumb = thumb
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(0.4, 0.4, 0.45, 0.6)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(sf, delta)
        local range = sf:GetVerticalScrollRange()
        if range <= 0 then return end
        local step = 34
        sf:SetVerticalScroll(math.max(0, math.min(range, sf:GetVerticalScroll() - delta * step)))
    end)

    local function ThumbOnUpdate(t)
        if not t.dragging then return end
        local cursorY = GetSafeCursorY()
        if not cursorY then return end
        local deltaY = t.dragStartY - cursorY
        local trackHeight = track:GetHeight()
        local thumbHeight = t:GetHeight()
        if not trackHeight or not thumbHeight then return end
        local maxTravel = trackHeight - thumbHeight
        if maxTravel <= 0 then return end
        local range = scrollFrame:GetVerticalScrollRange()
        scrollFrame:SetVerticalScroll(math.max(0, math.min(range, t.dragStartScroll + (deltaY / maxTravel) * range)))
    end

    thumb:EnableMouse(true)
    thumb:SetScript("OnMouseDown", function(t, button)
        if button == "LeftButton" then
            local cursorY = GetSafeCursorY()
            if not cursorY then return end
            t.dragging = true
            t.dragStartY = cursorY
            t.dragStartScroll = scrollFrame:GetVerticalScroll()
            t:SetScript("OnUpdate", ThumbOnUpdate)
        end
    end)
    thumb:SetScript("OnMouseUp", function(t)
        t.dragging = false
        t:SetScript("OnUpdate", nil)
    end)

    track:SetScript("OnMouseDown", function(t, button)
        if button ~= "LeftButton" then return end
        local range = scrollFrame:GetVerticalScrollRange()
        if range <= 0 then return end
        local cursorY = GetSafeCursorY()
        if not cursorY then return end
        local top = t:GetTop()
        local height = t:GetHeight()
        if not top or not height or height <= 0 then return end
        local pct = (top - cursorY) / height
        scrollFrame:SetVerticalScroll(math.max(0, math.min(range, pct * range)))
    end)

    scrollFrame:SetScript("OnVerticalScroll", function()
        ProgressTab:UpdateSidebarScrollbar()
    end)
    scrollFrame:SetScript("OnScrollRangeChanged", function()
        ProgressTab:UpdateSidebarScrollbar()
    end)
    scrollFrame:SetScript("OnSizeChanged", function(_, width)
        scrollChild:SetWidth(math.max(1, width))
        ProgressTab:UpdateSidebarScrollbar()
    end)

    -- Right border separator
    local border = panel:CreateTexture(nil, "ARTWORK")
    border:SetWidth(1)
    border:SetPoint("TOPRIGHT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(0.2, 0.2, 0.25, 1)
end

function ProgressTab:UpdateSidebarScrollbar()
    local scrollFrame = self.sideScrollFrame
    local track = self.sideScrollTrack
    local thumb = self.sideScrollThumb
    if not scrollFrame or not track or not thumb then return end

    local range = scrollFrame:GetVerticalScrollRange()
    if not range or range <= 0 then
        scrollFrame:SetVerticalScroll(0)
        track:Hide()
        return
    end

    track:Show()
    local trackHeight = track:GetHeight()
    if not trackHeight or trackHeight <= 0 then return end
    local visibleRatio = scrollFrame:GetHeight() / (scrollFrame:GetHeight() + range)
    local thumbHeight = math.max(20, math.floor(trackHeight * visibleRatio))
    thumb:SetHeight(thumbHeight)
    local pct = scrollFrame:GetVerticalScroll() / range
    local maxTravel = trackHeight - thumbHeight
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", track, "TOP", 0, -math.floor(pct * maxTravel))
end

function ProgressTab:EnsureIndexes()
    if not addon.dataLoaded then return false end
    if not addon.questIndexBuilt then
        addon:BuildQuestIndex()
        addon:BuildQuestHierarchy()
    end
    if not addon.vendorIndexBuilt then addon:BuildVendorIndex() end
    if not addon.achievementHierarchyBuilt then
        addon:BuildAchievementIndex()
        addon:BuildAchievementHierarchy()
    end
    if not addon.dropIndexBuilt then addon:BuildDropIndex() end
    if not addon.craftingIndexBuilt then addon:BuildCraftingIndex() end
    if not addon.pvpIndexBuilt then addon:BuildPvPIndex() end
    if not addon.renownIndexBuilt then addon:BuildRenownIndex() end
    return true
end

function ProgressTab:Show()
    if not self.frame then return end

    local skipRefresh = self.ownershipRefreshedThisShow
    self.ownershipRefreshedThisShow = nil
    local previewWasExpanded = addon.MainFrame.previewRegion
        and addon.MainFrame.previewRegion:IsShown()

    self:EnsureIndexes()

    self.frame:Show()
    if self.sidePanel then self.sidePanel:Show() end

    -- Collapse preview BEFORE RefreshDisplay so columns are sized for full-width content area
    addon.MainFrame:CollapsePreview()

    -- A hidden ownership refresh can run before the preview collapses. Rebuild
    -- once at the full content width when that ordering changed the layout.
    if not skipRefresh or previewWasExpanded then
        self:RefreshDisplay()
    end
end

function ProgressTab:Hide()
    if self.frame then self.frame:Hide() end
    if self.sidePanel then self.sidePanel:Hide() end

    -- Restore preview when leaving Progress tab (but not when MainFrame is closing)
    if addon.MainFrame:IsShown() then
        addon.MainFrame:RestorePreview()
    end
end

function ProgressTab:IsShown()
    return self.frame and self.frame:IsShown()
end

--------------------------------------------------------------------------------
-- Scroll Frame
--------------------------------------------------------------------------------

function ProgressTab:CreateScrollFrame(parent)
    local TRACK_WIDTH = 6

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:SetPoint("TOPLEFT", CONTENT_PADDING, -CONTENT_PADDING)
    scrollFrame:SetPoint("BOTTOMRIGHT", -CONTENT_PADDING - 14, CONTENT_PADDING)
    self.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(1)
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild

    -- Thin modern scrollbar (track + thumb)
    local track = CreateFrame("Frame", nil, parent)
    track:SetWidth(TRACK_WIDTH)
    track:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, 0)
    track:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 0)
    track:EnableMouse(true)
    track:Hide()

    local trackBg = track:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0.1, 0.1, 0.12, 0.3)

    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetWidth(TRACK_WIDTH)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(0.4, 0.4, 0.45, 0.6)

    local function UpdateScrollbar()
        local range = scrollFrame:GetVerticalScrollRange()
        if not range or range <= 0 then
            track:Hide()
            return
        end
        track:Show()
        local trackHeight = track:GetHeight()
        if not trackHeight or trackHeight <= 0 then return end
        local visibleRatio = scrollFrame:GetHeight() / (scrollFrame:GetHeight() + range)
        local thumbHeight = math.max(20, math.floor(trackHeight * visibleRatio))
        thumb:SetHeight(thumbHeight)
        local pct = scrollFrame:GetVerticalScroll() / range
        local maxTravel = trackHeight - thumbHeight
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -math.floor(pct * maxTravel))
    end

    -- Mouse wheel
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(sf, delta)
        local range = sf:GetVerticalScrollRange()
        if range <= 0 then return end
        local step = 40
        sf:SetVerticalScroll(math.max(0, math.min(range, sf:GetVerticalScroll() - delta * step)))
    end)

    -- Thumb drag
    thumb:EnableMouse(true)
    local function ThumbOnUpdate(t)
        if not t.dragging then return end
        local cursorY = GetSafeCursorY()
        if not cursorY then return end
        local deltaY = t.dragStartY - cursorY
        local trackHeight = track:GetHeight()
        local thumbHeight = t:GetHeight()
        if not trackHeight or not thumbHeight then return end
        local maxTravel = trackHeight - thumbHeight
        if maxTravel <= 0 then return end
        local range = scrollFrame:GetVerticalScrollRange()
        scrollFrame:SetVerticalScroll(math.max(0, math.min(range, t.dragStartScroll + (deltaY / maxTravel) * range)))
    end

    thumb:SetScript("OnMouseDown", function(t, button)
        if button == "LeftButton" then
            local cursorY = GetSafeCursorY()
            if not cursorY then return end
            t.dragging = true
            t.dragStartY = cursorY
            t.dragStartScroll = scrollFrame:GetVerticalScroll()
            t:SetScript("OnUpdate", ThumbOnUpdate)
        end
    end)
    thumb:SetScript("OnMouseUp", function(t)
        t.dragging = false
        t:SetScript("OnUpdate", nil)
    end)

    -- Track click to page-scroll
    track:SetScript("OnMouseDown", function(t, button)
        if button ~= "LeftButton" then return end
        local range = scrollFrame:GetVerticalScrollRange()
        if range <= 0 then return end
        local cursorY = GetSafeCursorY()
        if not cursorY then return end
        local top = t:GetTop()
        local height = t:GetHeight()
        if not top or not height or height <= 0 then return end
        local pct = (top - cursorY) / height
        scrollFrame:SetVerticalScroll(math.max(0, math.min(range, pct * range)))
    end)

    -- Sync scrollbar with scroll position
    scrollFrame:SetScript("OnVerticalScroll", UpdateScrollbar)
    scrollFrame:SetScript("OnScrollRangeChanged", UpdateScrollbar)

    -- Responsive resize with short debounce
    scrollFrame:SetScript("OnSizeChanged", function(sf, width)
        scrollChild:SetWidth(width)
        UpdateScrollbar()
        if ProgressTab.resizeTimer then ProgressTab.resizeTimer:Cancel() end
        if ProgressTab:IsShown() and addon.dataLoaded then
            ProgressTab.resizeTimer = C_Timer.NewTimer(CONSTS.TIMER.INPUT_DEBOUNCE, function()
                ProgressTab.resizeTimer = nil
                if ProgressTab:IsShown() then
                    ProgressTab:BuildDashboard(true)
                end
            end)
        end
    end)
end

--------------------------------------------------------------------------------
-- Display Building
--------------------------------------------------------------------------------

function ProgressTab:RefreshDisplay(preserveScroll)
    addon:CountDebug("rebuild", "ProgressTab")

    if not addon.dataLoaded then
        self:ShowLoadingState()
        return
    end

    self:BuildDashboard(preserveScroll)
end

function ProgressTab:ShowLoadingState()
    local L = addon.L
    self:ClearDashboard()

    if not self.loadingMsg then
        self.loadingMsg = addon:CreateFontString(self.scrollChild, "OVERLAY", "GameFontNormal")
        self.loadingMsg:SetPoint("CENTER")
        addon:SetFontSize(self.loadingMsg, 16, "")
    end

    self.loadingMsg:SetText(L["PROGRESS_LOADING"])
    self.loadingMsg:SetTextColor(unpack(COLORS.TEXT_TERTIARY))
    self.loadingMsg:Show()

    self.scrollChild:SetHeight(200)
end

function ProgressTab:ClearDashboard()
    local pools = {
        self.sourceRows,
        self.professionRows,
        self.vendorExpRows,
        self.questExpRows,
        self.renownExpRows,
        self.pvpCategoryRows,
        self.achievementCatRows,
        self.dropCatRows,
        self.almostThereRows,
    }
    for _, pool in ipairs(pools) do
        for _, frame in ipairs(pool) do
            frame:Hide()
        end
    end

    for _, element in pairs(self.sidebarElements) do
        element:Hide()
    end

    local headers = {
        "loadingMsg",
        "sourceHeader",
        "professionsHeader",
        "vendorExpHeader",
        "questExpHeader",
        "renownExpHeader",
        "pvpCategoryHeader",
        "achievementCatHeader",
        "dropCatHeader",
        "almostThereHeader",
    }
    for _, key in ipairs(headers) do
        if self[key] then self[key]:Hide() end
    end
end

function ProgressTab:BuildDashboard(preserveScroll)
    local L = addon.L
    local savedScroll = preserveScroll and self.scrollFrame:GetVerticalScroll() or 0
    self:ClearDashboard()

    -- Reset scroll to top on context changes (tab switch, first show);
    -- preserve position on ownership refreshes, resizes, and data reloads
    if not preserveScroll then
        self.scrollFrame:SetVerticalScroll(0)
    end
    self:BuildSidebarSummary()

    local contentWidth = self.scrollChild:GetWidth()
    if contentWidth < 10 then
        local frameWidth = addon.MainFrame.frame and addon.MainFrame.frame:GetWidth() or 1200
        contentWidth = frameWidth - (SIDEBAR_WIDTH + CONTENT_PADDING * 2 + 14 + 4)
    end

    local columnWidth = math.floor((contentWidth - COLUMN_GAP) / 2)

    -- Left column: By Source + Most Progressed + Quest/PvP/Achievement categories
    local leftY = self:BuildSourceSection(0, columnWidth, 0)
    leftY = leftY - SECTION_PADDING
    leftY = self:BuildAlmostThereSection(leftY, columnWidth, 0)
    local questExpData = addon:GetProgressByExpansion("QUESTS")
    if #questExpData > 0 then
        if leftY < 0 then leftY = leftY - SECTION_PADDING end
        leftY = self:BuildExpansionSection(leftY, columnWidth, "questExp", L["PROGRESS_QUEST_EXPANSIONS"], questExpData, self.questExpRows, 0)
    end
    local pvpCategoryData = addon:GetProgressByPvPCategory()
    if #pvpCategoryData > 0 then
        if leftY < 0 then leftY = leftY - SECTION_PADDING end
        leftY = self:BuildExpansionSection(leftY, columnWidth, "pvpCategory", L["PROGRESS_PVP_CATEGORIES"], pvpCategoryData, self.pvpCategoryRows, 0)
    end
    local achievementCatData = addon:GetProgressByAchievementCategory()
    if #achievementCatData > 0 then
        if leftY < 0 then leftY = leftY - SECTION_PADDING end
        local displayData = {}
        for _, data in ipairs(achievementCatData) do
            local rowData = {}
            for key, value in pairs(data) do
                rowData[key] = value
            end
            rowData.displayLabel = addon:GetCategoryName(data.categoryId)
            displayData[#displayData + 1] = rowData
        end
        leftY = self:BuildExpansionSection(leftY, columnWidth, "achievementCat", L["PROGRESS_ACHIEVEMENT_CATEGORIES"], displayData, self.achievementCatRows, 0)
    end

    -- Right column: Professions + Vendor Expansions + Renown Expansions
    local rightX = columnWidth + COLUMN_GAP
    local rightY = self:BuildProfessionsSection(0, columnWidth, rightX)
    local vendorExpData = addon:GetProgressByExpansion("VENDORS")
    if #vendorExpData > 0 then
        if rightY < 0 then rightY = rightY - SECTION_PADDING end
        rightY = self:BuildExpansionSection(rightY, columnWidth, "vendorExp", L["PROGRESS_VENDOR_EXPANSIONS"], vendorExpData, self.vendorExpRows, rightX)
    end
    local renownExpData = addon:GetProgressByExpansion("RENOWN")
    if #renownExpData > 0 then
        if rightY < 0 then rightY = rightY - SECTION_PADDING end
        rightY = self:BuildExpansionSection(rightY, columnWidth, "renownExp", L["PROGRESS_RENOWN_EXPANSIONS"], renownExpData, self.renownExpRows, rightX)
    end
    local dropCatData = addon:GetProgressByDropCategory()
    if #dropCatData > 0 then
        if rightY < 0 then rightY = rightY - SECTION_PADDING end
        rightY = self:BuildExpansionSection(rightY, columnWidth, "dropCat", L["PROGRESS_DROP_CATEGORIES"], dropCatData, self.dropCatRows, rightX)
    end

    local totalHeight = math.max(math.abs(leftY), math.abs(rightY))
    self.scrollChild:SetHeight(totalHeight + SECTION_PADDING)

    -- Restore scroll position (deferred to next frame so layout has recalculated range)
    if savedScroll > 0 then
        C_Timer.After(0, function()
            if ProgressTab:IsShown() then
                local range = ProgressTab.scrollFrame:GetVerticalScrollRange()
                ProgressTab.scrollFrame:SetVerticalScroll(math.min(savedScroll, range))
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- Sidebar Summary
--------------------------------------------------------------------------------

local function CreateSidebarText(parent, fontObject, size, justify)
    local fs = addon:CreateFontString(parent, "OVERLAY", fontObject or "GameFontNormal")
    fs:SetJustifyH(justify or "LEFT")
    addon:SetFontSize(fs, size or 12, "")
    return fs
end

local function OpenHousingDashboard(tabID)
    if InCombatLockdown() then return end
    if PlayerIsTimerunning()
        or not C_Housing.IsHousingServiceEnabled()
        or C_PlayerInfo.IsPlayerNPERestricted() then
        return
    end
    if not HousingDashboardFrame then
        pcall(C_AddOns.LoadAddOn, "Blizzard_HousingDashboard")
    end
    if not HousingDashboardFrame then return end

    local function SetDashboardTab(frame, tab)
        local setTab = frame and frame.SetTab
        if type(setTab) ~= "function" or tab == nil then return false end
        return pcall(setTab, frame, tab)
    end

    if addon.MainFrame then
        addon.MainFrame:Hide()
    end
    ShowUIPanel(HousingDashboardFrame)
    if not SetDashboardTab(HousingDashboardFrame, HousingDashboardFrame.houseInfoTab) then return end
    local contentFrame = HousingDashboardFrame.HouseInfoContent
        and HousingDashboardFrame.HouseInfoContent.ContentFrame
    if contentFrame then
        if not contentFrame.tabsInitialized then
            pcall(contentFrame.Initialize, contentFrame)
        end
        if contentFrame[tabID] then
            SetDashboardTab(contentFrame, contentFrame[tabID])
        end
    end
end

local function SetSidebarElementShown(element, shown)
    if not element then return end
    if element.SetShown then
        element:SetShown(shown)
    elseif shown then
        element:Show()
    else
        element:Hide()
    end
end

function ProgressTab:PlaceSidebarDualDivider(elements, panel, key, yOffset)
    for i = 1, 2 do
        local dividerKey = "divider_" .. key .. i
        if not elements[dividerKey] then
            elements[dividerKey] = panel:CreateTexture(nil, "ARTWORK")
            elements[dividerKey]:SetColorTexture(0.25, 0.25, 0.28, 0.75)
        end

        local divider = elements[dividerKey]
        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset - (i - 1) * 3)
        divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, yOffset - (i - 1) * 3)
        divider:SetHeight(1)
        divider:Show()
    end

    return yOffset - 14
end

function ProgressTab:PlaceSidebarSectionHeader(elements, panel, key, text, yOffset)
    local headerKey = "sectionHeader_" .. key
    if not elements[headerKey] then
        elements[headerKey] = CreateSidebarText(panel, "GameFontNormal", 11, "LEFT")
    end

    local header = elements[headerKey]
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    header:SetText(text)
    header:SetTextColor(unpack(COLORS.GOLD))
    header:Show()

    return yOffset - 22
end

function ProgressTab:SetupSidebarStatRow(elements, panel, stat, yOffset)
    local labelKey = "label_" .. stat.key
    local valueKey = "value_" .. stat.key
    local buttonKey = "button_" .. stat.key

    if stat.onClick and not elements[buttonKey] then
        local button = CreateFrame("Button", nil, panel)
        button.bg = button:CreateTexture(nil, "BACKGROUND")
        button.bg:SetAllPoints()
        button.bg:SetColorTexture(1, 1, 1, 0)
        elements[buttonKey] = button
    end

    local button = elements[buttonKey]
    if button then
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, yOffset + 4)
        button:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, yOffset + 4)
        button:SetHeight(20)
        button:SetScript("OnClick", stat.onClick)
        button:Show()
    end

    if not elements[labelKey] then
        elements[labelKey] = CreateSidebarText(panel, "GameFontNormal", 12, "LEFT")
    end
    local label = elements[labelKey]
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    label:SetText(stat.label)
    label:SetTextColor(unpack(COLORS.TEXT_TERTIARY))
    label:Show()

    if not elements[valueKey] then
        elements[valueKey] = CreateSidebarText(panel, "GameFontNormal", 12, "RIGHT")
    end
    local value = elements[valueKey]
    value:ClearAllPoints()
    value:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, yOffset)
    value:SetText(stat.value)
    value:SetTextColor(unpack(stat.color))
    value:Show()

    if button then
        button:SetScript("OnEnter", function(b)
            b.bg:SetColorTexture(1, 1, 1, 0.06)
            label:SetTextColor(unpack(COLORS.TEXT_SECONDARY))
        end)
        button:SetScript("OnLeave", function(b)
            b.bg:SetColorTexture(1, 1, 1, 0)
            label:SetTextColor(unpack(COLORS.TEXT_TERTIARY))
        end)
    end
end

function ProgressTab:BuildBudgetRows(elements, panel, yOffset)
    local L = addon.L
    local budget = addon.GetPlacementBudget and addon:GetPlacementBudget()
    if not budget then return yOffset end

    local activeKeys = {}
    local previousKeys = self.activeBudgetKeys or {}
    self.activeBudgetKeys = activeKeys
    local function MarkActive(key)
        activeKeys[key] = true
    end

    local function FormatUnit(value, oneKey, manyKey)
        local key = value == 1 and oneKey or manyKey
        return string.format(L[key], value)
    end

    local function FormatElapsed(seconds)
        seconds = math.max(0, math.floor(seconds or 0))
        local days = math.floor(seconds / 86400)
        local hours = math.floor((seconds % 86400) / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        if days > 0 then
            local text = FormatUnit(days, "PROGRESS_TIME_DAY", "PROGRESS_TIME_DAYS")
            if hours > 0 then
                text = text .. ", " .. FormatUnit(hours, "PROGRESS_TIME_HOUR", "PROGRESS_TIME_HOURS")
            end
            return text
        end
        if hours > 0 then
            local text = FormatUnit(hours, "PROGRESS_TIME_HOUR", "PROGRESS_TIME_HOURS")
            if minutes > 0 then
                text = text .. " " .. FormatUnit(minutes, "PROGRESS_TIME_MINUTE", "PROGRESS_TIME_MINUTES")
            end
            return text
        end
        return FormatUnit(math.max(1, minutes), "PROGRESS_TIME_MINUTE", "PROGRESS_TIME_MINUTES")
    end

    local function ShowUpdatedTooltip(owner, title, snapshot)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        if type(snapshot) == "table" and type(snapshot.updatedAt) == "number" then
            local updatedText = date("%Y-%m-%d %H:%M", snapshot.updatedAt)
            GameTooltip:AddLine(string.format(L["PROGRESS_BUDGET_LAST_UPDATED"], updatedText), 0.8, 0.8, 0.8)
            local now = GetServerTime and GetServerTime()
            if type(now) == "number" then
                GameTooltip:AddLine(string.format(L["PROGRESS_BUDGET_TIME_AGO"], FormatElapsed(now - snapshot.updatedAt)), 0.65, 0.70, 0.78)
            end
        end
        GameTooltip:Show()
    end


    local function ShowHouseXPTooltip(owner, levelInfo)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        local xpIcon = CreateAtlasMarkup("housing-dashboard-icon-xp", 16, 16)
        GameTooltip:AddLine(xpIcon .. " " .. L["ENDEAVORS_XP_TOOLTIP_TITLE"], 1, 0.82, 0)
        if levelInfo.isMaxLevel then
            GameTooltip:AddLine(string.format(L["ENDEAVORS_XP_TOOLTIP_LEVEL_MAX"], levelInfo.level), 1, 1, 1)
        else
            GameTooltip:AddLine(string.format(L["ENDEAVORS_XP_TOOLTIP_LEVEL"], levelInfo.level), 1, 1, 1)
            local totalFavor = math.floor(levelInfo.favorTotal or 0)
            local totalFavorNeeded = math.floor(levelInfo.favorTotalNeeded or 0)
            if totalFavorNeeded > 0 then
                local pct = math.floor(totalFavor / totalFavorNeeded * 100)
                GameTooltip:AddLine(string.format(L["ENDEAVORS_XP_TOOLTIP_PROGRESS"],
                    addon:FormatLargeNumber(totalFavor), addon:FormatLargeNumber(totalFavorNeeded), pct), 0.7, 0.7, 0.7)
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["ENDEAVORS_XP_TOOLTIP_CLICK"], 0.5, 0.8, 1)
        GameTooltip:Show()
    end

    local live = addon.IsPlacementBudgetLiveContext and addon:IsPlacementBudgetLiveContext()
    local currentPlotID, currentBudgetContext, currentNeighborhoodGUID = nil, nil, nil
    if addon.GetCurrentPlacementBudgetContext then
        currentPlotID, currentBudgetContext, currentNeighborhoodGUID = addon:GetCurrentPlacementBudgetContext()
    end

    local plotsByID = type(budget.plotsByID) == "table" and budget.plotsByID or nil
    local knownPlots = type(budget.knownPlots) == "table" and budget.knownPlots or nil
    local plotIdentityMap = {}
    local stableIdentitiesByPlotID = {}

    local function HasBudgetSnapshot(snapshot)
        return type(snapshot) == "table" and type(snapshot.spent) == "number" and type(snapshot.max) == "number" and snapshot.max > 0
    end

    local function GetStablePlotIdentityKey(plotID, plotInfo)
        if type(plotInfo) == "table" then
            if plotInfo.houseGUID ~= nil and plotInfo.houseGUID ~= "" then
                return "house:" .. tostring(plotInfo.houseGUID)
            end
            if type(plotInfo.plotID) == "number" and plotInfo.neighborhoodGUID ~= nil and plotInfo.neighborhoodGUID ~= "" then
                return "neighborhood:" .. tostring(plotInfo.neighborhoodGUID) .. ":plot:" .. tostring(math.floor(plotInfo.plotID))
            end
        end
        if type(plotID) == "string" and tonumber(plotID) == nil then
            return plotID
        end
        return nil
    end

    if knownPlots then
        for plotID, plotInfo in pairs(knownPlots) do
            if type(plotInfo) == "table" and type(plotInfo.plotID) == "number" then
                local identityKey = GetStablePlotIdentityKey(plotID, plotInfo)
                if identityKey then
                    local identities = stableIdentitiesByPlotID[plotInfo.plotID]
                    if not identities then
                        identities = {}
                        stableIdentitiesByPlotID[plotInfo.plotID] = identities
                    end
                    identities[identityKey] = true
                end
            end
        end
    end

    local function HasAmbiguousPlotIdentity(plotInfo)
        if type(plotInfo) ~= "table" or type(plotInfo.plotID) ~= "number" then return false end
        local identities = stableIdentitiesByPlotID[plotInfo.plotID]
        if not identities then return false end

        local count = 0
        for _ in pairs(identities) do
            count = count + 1
            if count > 1 then return true end
        end
        return false
    end

    local function GetVerifiedSavedSnapshot(plotID, plotInfo, snapshot, containerKey)
        if not HasBudgetSnapshot(snapshot) then return nil end

        local expectedIdentityKey = GetStablePlotIdentityKey(plotID, plotInfo)
        if type(snapshot.identityKey) == "string" then
            if not expectedIdentityKey or snapshot.identityKey ~= expectedIdentityKey then
                return nil
            end
            return snapshot
        end
        if type(containerKey) == "string" and containerKey == expectedIdentityKey then
            return snapshot
        end
        if not HasAmbiguousPlotIdentity(plotInfo) then
            return snapshot
        end
        return nil
    end

    local function GetPlotDisplayKey(plotID, plotInfo)
        return GetStablePlotIdentityKey(plotID, plotInfo) or "plot:" .. tostring(plotID)
    end

    local function GetPlotCompletenessScore(plotID, plotInfo)
        local score = 0
        local budgets = type(plotInfo) == "table" and type(plotInfo.budgets) == "table" and plotInfo.budgets or nil
        if plotInfo and plotInfo.visited then score = score + 8 end
        if budgets and GetVerifiedSavedSnapshot(plotID, plotInfo, budgets.outdoor) then score = score + 4 end
        if budgets and GetVerifiedSavedSnapshot(plotID, plotInfo, budgets.interior) then score = score + 4 end
        if plotsByID and GetVerifiedSavedSnapshot(plotID, plotInfo, plotsByID[plotID], plotID) then score = score + 2 end
        if plotInfo and type(plotInfo.houseLevel) == "table" and type(plotInfo.houseLevel.level) == "number" then score = score + 1 end
        return score
    end

    local function GetPlotLevel(candidate)
        local plotInfo = candidate and candidate.plotInfo
        return plotInfo and plotInfo.houseLevel and plotInfo.houseLevel.level or 0
    end

    local function IsPlotTiebreakBefore(a, b)
        local levelA = GetPlotLevel(a)
        local levelB = GetPlotLevel(b)
        if levelA ~= levelB then return levelA > levelB end

        if a.updatedAt ~= b.updatedAt then return a.updatedAt > b.updatedAt end

        local numA = tonumber(a.plotID)
        local numB = tonumber(b.plotID)
        if numA and numB then return numA < numB end
        return tostring(a.plotID) < tostring(b.plotID)
    end

    local function GetFactionSortOrder(candidate)
        local factionTag = candidate and candidate.plotInfo and candidate.plotInfo.factionTag
        if factionTag == "Alliance" then return 1 end
        if factionTag == "Horde" then return 2 end
        return 3
    end

    local function IsFactionSortedPlotBefore(a, b)
        local orderA = GetFactionSortOrder(a)
        local orderB = GetFactionSortOrder(b)
        if orderA ~= orderB then return orderA < orderB end
        return IsPlotTiebreakBefore(a, b)
    end

    local function IsCompletePlotBefore(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return IsPlotTiebreakBefore(a, b)
    end

    local function ShouldReplacePlotCandidate(current, candidate)
        if not current then return true end
        if candidate.score ~= current.score then return candidate.score > current.score end
        return IsPlotTiebreakBefore(candidate, current)
    end

    local function FindKnownPlotByPlotID(plotID)
        if not knownPlots then return nil, false end

        local numericPlotID = tonumber(plotID)
        if not numericPlotID then
            return type(knownPlots[plotID]) == "table" and knownPlots[plotID] or nil, false
        end

        local match
        for _, plotInfo in pairs(knownPlots) do
            if type(plotInfo) == "table" and plotInfo.plotID == numericPlotID then
                if match and match ~= plotInfo then
                    return nil, true
                end
                match = plotInfo
            end
        end
        return match, false
    end

    local function HasMatchingNeighborhood(plotInfo, otherInfo)
        local neighborhoodGUID = plotInfo and plotInfo.neighborhoodGUID
        local otherNeighborhoodGUID = otherInfo and otherInfo.neighborhoodGUID
        if neighborhoodGUID == nil or neighborhoodGUID == "" or otherNeighborhoodGUID == nil or otherNeighborhoodGUID == "" then
            return true
        end
        return neighborhoodGUID == otherNeighborhoodGUID
    end

    local function HasHouseIdentityDuplicate(plotInfo)
        if type(plotInfo) ~= "table" or plotInfo.houseGUID ~= nil and plotInfo.houseGUID ~= "" then return false end
        if not knownPlots or type(plotInfo.plotID) ~= "number" then return false end
        for _, otherInfo in pairs(knownPlots) do
            if otherInfo ~= plotInfo and type(otherInfo) == "table" and otherInfo.plotID == plotInfo.plotID
                and otherInfo.houseGUID ~= nil and otherInfo.houseGUID ~= "" and HasMatchingNeighborhood(plotInfo, otherInfo) then
                return true
            end
        end
        return false
    end

    local function AddPlotCandidate(plotID, plotInfo)
        if type(plotID) ~= "string" then return end
        local budgets = type(plotInfo) == "table" and type(plotInfo.budgets) == "table" and plotInfo.budgets or nil
        local hasData = type(plotInfo) == "table" and plotInfo.visited
            or (budgets and (HasBudgetSnapshot(budgets.outdoor) or HasBudgetSnapshot(budgets.interior)))
            or (plotsByID and HasBudgetSnapshot(plotsByID[plotID]))
        if not hasData then return end

        local updatedAt = 0
        if budgets then
            if HasBudgetSnapshot(budgets.outdoor) then updatedAt = math.max(updatedAt, budgets.outdoor.updatedAt or 0) end
            if HasBudgetSnapshot(budgets.interior) then updatedAt = math.max(updatedAt, budgets.interior.updatedAt or 0) end
        end
        if plotsByID and HasBudgetSnapshot(plotsByID[plotID]) then
            updatedAt = math.max(updatedAt, plotsByID[plotID].updatedAt or 0)
        end

        local candidate = {
            plotID = plotID,
            plotInfo = plotInfo,
            score = GetPlotCompletenessScore(plotID, plotInfo),
            updatedAt = updatedAt,
        }
        local key = GetPlotDisplayKey(plotID, plotInfo)
        if ShouldReplacePlotCandidate(plotIdentityMap[key], candidate) then
            plotIdentityMap[key] = candidate
        end
    end

    if knownPlots then
        for plotID, plotInfo in pairs(knownPlots) do
            if type(plotInfo) == "table" and type(plotInfo.plotID) == "number" and not HasHouseIdentityDuplicate(plotInfo) then
                AddPlotCandidate(plotID, plotInfo)
            end
        end
    end

    if plotsByID then
        for plotID, snapshot in pairs(plotsByID) do
            if HasBudgetSnapshot(snapshot) then
                local plotInfo, ambiguous = FindKnownPlotByPlotID(plotID)
                if plotInfo or not ambiguous then
                    AddPlotCandidate(plotID, plotInfo)
                end
            end
        end
    end

    local plotRows = {}
    for _, candidate in pairs(plotIdentityMap) do
        plotRows[#plotRows + 1] = candidate
    end

    if #plotRows > 2 then
        table.sort(plotRows, IsCompletePlotBefore)

        while #plotRows > 2 do
            table.remove(plotRows)
        end
    end
    table.sort(plotRows, IsFactionSortedPlotBefore)
    local function GetFactionName(factionTag, fallbackName)
        if factionTag == "Alliance" then
            return FACTION_ALLIANCE or "Alliance"
        elseif factionTag == "Horde" then
            return FACTION_HORDE or "Horde"
        end
        if type(fallbackName) == "string" and fallbackName ~= "" then
            return fallbackName
        end
        return nil
    end

    local function GetPlotTitle(plotRow, index)
        local plotInfo = plotRow and plotRow.plotInfo
        if type(plotInfo) == "table" then
            local factionName = GetFactionName(plotInfo.factionTag, plotInfo.factionName)
            if factionName and factionName ~= "" then
                return factionName
            end
        end
        return L["PROGRESS_BUDGET_PLOT"] .. " " .. index
    end

    local function CreateBudgetBar(key)
        if not elements[key] then
            local bar = CreateFrame("StatusBar", nil, panel)
            bar:SetHeight(BUDGET_BAR_HEIGHT)
            bar:SetMinMaxValues(0, 100)
            bar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")

            local bg = bar:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.10, 0.10, 0.13, 0.8)
            bar.bg = bg

            local label = CreateSidebarText(bar, "GameFontNormal", 12, "LEFT")
            label:SetPoint("LEFT", bar, "LEFT", 6, 0)
            label:SetJustifyV("MIDDLE")
            bar.label = label

            local text = CreateSidebarText(bar, "GameFontNormal", 12, "RIGHT")
            text:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
            text:SetJustifyV("MIDDLE")
            bar.text = text

            elements[key] = bar
        end
        MarkActive(key)
        return elements[key]
    end

    local function FormatLevelText(levelInfo)
        local valid = type(levelInfo) == "table" and type(levelInfo.level) == "number" and levelInfo.level > 0
        if not valid then return L["PROGRESS_BUDGET_LEVEL_UNKNOWN"], false, 0 end

        local percent = 0
        if levelInfo.isMaxLevel then
            percent = 100
        elseif type(levelInfo.favorTotal) == "number" and type(levelInfo.favorTotalNeeded) == "number" and levelInfo.favorTotalNeeded > 0 then
            percent = math.min(100, math.max(0, levelInfo.favorTotal / levelInfo.favorTotalNeeded * 100))
        end
        return string.format("%s (%d%%)", string.format(L["PROGRESS_BUDGET_LEVEL"], levelInfo.level), math.floor(percent)), true, percent
    end

    local function DrawPlotHeader(plotID, plotTitle, plotInfo)
        local levelInfo = type(plotInfo) == "table" and plotInfo.houseLevel or nil
        local levelText, valid = FormatLevelText(levelInfo)
        local oldLabelKey = "budget_levelLabel" .. plotID
        local oldBarKey = "budget_levelBar" .. plotID
        local oldButtonKey = "budget_levelButton" .. plotID
        local headerKey = "budget_plotHeader" .. plotID

        SetSidebarElementShown(elements[oldLabelKey], false)
        SetSidebarElementShown(elements[oldBarKey], false)
        SetSidebarElementShown(elements[oldButtonKey], false)
        if elements[oldBarKey] and elements[oldBarKey].text then
            elements[oldBarKey].text:Hide()
        end

        if elements[headerKey] and not elements[headerKey].text then
            elements[headerKey]:Hide()
            elements[headerKey] = nil
        end
        if not elements[headerKey] then
            local button = CreateFrame("Button", nil, panel)
            button:EnableMouse(true)
            button.text = CreateSidebarText(button, "GameFontNormal", 13, "LEFT")
            button.text:SetPoint("LEFT", button, "LEFT", 0, 0)
            elements[headerKey] = button
        end
        MarkActive(headerKey)

        local header = elements[headerKey]
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
        header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, yOffset)
        header:SetHeight(18)
        header.text:SetText(string.format("%s - %s", plotTitle, levelText))
        header.text:SetTextColor(1, 1, 1, 1)
        header:SetScript("OnEnter", function(b)
            b.text:SetTextColor(unpack(COLORS.TEXT_SECONDARY))
            if valid then
                ShowHouseXPTooltip(b, levelInfo)
            else
                GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["PROGRESS_BUDGET_LEVEL_UNKNOWN"])
                GameTooltip:Show()
            end
        end)
        header:SetScript("OnLeave", function(b)
            b.text:SetTextColor(1, 1, 1, 1)
            GameTooltip:Hide()
        end)
        header:SetScript("OnMouseUp", function(_, mouseButton)
            if mouseButton ~= "LeftButton" or not valid then return end
            OpenHousingDashboard("houseUpgradeTabID")
        end)
        header:Show()
        header.text:Show()

        return yOffset - HOUSE_HEADER_ROW_SPACING
    end

    local function PlotMatchesCurrentID(plotID, plotInfo)
        if type(plotInfo) ~= "table" then return false end
        if currentPlotID == plotID then return true end

        if currentPlotID and plotInfo.houseGUID ~= nil and plotInfo.houseGUID ~= "" and currentPlotID == "house:" .. tostring(plotInfo.houseGUID) then
            return true
        end

        if currentPlotID and type(plotInfo.plotID) == "number" and plotInfo.neighborhoodGUID ~= nil and plotInfo.neighborhoodGUID ~= "" then
            local plotKey = "neighborhood:" .. tostring(plotInfo.neighborhoodGUID) .. ":plot:" .. tostring(math.floor(plotInfo.plotID))
            if currentPlotID == plotKey then return true end
        end
        if not currentPlotID and currentNeighborhoodGUID ~= nil and currentNeighborhoodGUID ~= ""
            and plotInfo.neighborhoodGUID == currentNeighborhoodGUID then
            local matches = 0
            for _, row in ipairs(plotRows) do
                local rowInfo = row.plotInfo
                if type(rowInfo) == "table" and rowInfo.neighborhoodGUID == currentNeighborhoodGUID then
                    matches = matches + 1
                    if matches > 1 then return false end
                end
            end
            return matches == 1
        end
        return false
    end

    local function IsCurrentPlotRow(plotID, plotInfo)
        if not live then return false end
        if PlotMatchesCurrentID(plotID, plotInfo) then return true end
        return not currentPlotID and not currentNeighborhoodGUID and #plotRows == 1
    end

    local function GetBudgetSnapshotForPlot(plotID, plotInfo, contextKey, snapshot)
        local rowLive = currentBudgetContext == contextKey and IsCurrentPlotRow(plotID, plotInfo)
        if rowLive then
            local liveSnapshot = contextKey == "outdoor" and budget.plot or budget.interior
            if HasBudgetSnapshot(liveSnapshot) then
                return liveSnapshot, true
            end
        end
        return snapshot, rowLive
    end

    local function DrawBudgetRow(plotID, key, contextKey, label, snapshot, known, rowLiveOverride)
        local valid = type(snapshot) == "table" and type(snapshot.spent) == "number" and type(snapshot.max) == "number" and snapshot.max > 0
        local rowKey = "budget_" .. key .. (plotID or "")
        local rowLive = rowLiveOverride == true or (live and currentBudgetContext == contextKey and (not plotID or currentPlotID == plotID))
        if not valid and not known then
            SetSidebarElementShown(elements[rowKey], false)
            return yOffset
        end

        local bar = CreateBudgetBar(rowKey)
        local percent = valid and math.min(100, math.max(0, snapshot.spent / snapshot.max * 100)) or 0
        local color = valid and percent >= (CONSTS.PLACEMENT_BUDGET_WARN_THRESHOLD * 100) and CONSTS.PLACEMENT_BUDGET_WARN_COLOR or COLORS.GOLD
        local alpha = valid and (rowLive and 0.65 or 0.45) or 0.25
        bar:ClearAllPoints()
        bar:SetHeight(BUDGET_BAR_HEIGHT)
        bar:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
        bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, yOffset)
        bar:SetValue(percent)
        bar:SetStatusBarColor(color[1], color[2], color[3], alpha)
        bar:SetAlpha((valid and rowLive) and 1 or 0.7)
        bar.label:ClearAllPoints()
        bar.label:SetPoint("LEFT", bar, "LEFT", 6, 0)
        bar.label:SetWidth(86)
        bar.label:SetText(label)
        bar.label:SetTextColor(unpack(COLORS.TEXT_TERTIARY))
        bar.text:ClearAllPoints()
        bar.text:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
        bar.text:SetWidth(86)
        bar.text:SetText(valid and string.format("%d / %d", snapshot.spent, snapshot.max) or "-- / --")
        bar.text:SetTextColor(unpack(valid and COLORS.TEXT_PRIMARY or COLORS.TEXT_TERTIARY))
        bar:SetScript("OnEnter", function(b)
            if valid then
                ShowUpdatedTooltip(b, label, snapshot)
            else
                GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["PROGRESS_BUDGET_EMPTY_HINT"])
                GameTooltip:Show()
            end
        end)
        bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
        bar:Show()
        bar.label:Show()
        bar.text:Show()
        return yOffset - BUDGET_ROW_SPACING
    end

    if #plotRows > 0 then
        for i, plotRow in ipairs(plotRows) do
            local plotID = plotRow.plotID
            local plotInfo = plotRow.plotInfo
            local budgets = type(plotInfo) == "table" and type(plotInfo.budgets) == "table" and plotInfo.budgets or {}
            local plotTitle = GetPlotTitle(plotRow, i)
            local outdoorSaved = GetVerifiedSavedSnapshot(plotID, plotInfo, budgets.outdoor)
            if not outdoorSaved and plotsByID then
                outdoorSaved = GetVerifiedSavedSnapshot(plotID, plotInfo, plotsByID[plotID], plotID)
            end
            local interiorSaved = GetVerifiedSavedSnapshot(plotID, plotInfo, budgets.interior)
            local outdoorSnapshot, outdoorLive = GetBudgetSnapshotForPlot(plotID, plotInfo, "outdoor", outdoorSaved)
            local interiorSnapshot, interiorLive = GetBudgetSnapshotForPlot(plotID, plotInfo, "interior", interiorSaved)
            yOffset = DrawPlotHeader(plotID, plotTitle, plotInfo)
            yOffset = yOffset - 2
            yOffset = DrawBudgetRow(plotID, "plotOutdoor", "outdoor", L["PROGRESS_BUDGET_OUTDOOR"], outdoorSnapshot, true, outdoorLive)
            yOffset = DrawBudgetRow(plotID, "plotInterior", "interior", L["PROGRESS_BUDGET_INDOOR"], interiorSnapshot, true, interiorLive)
            yOffset = yOffset - HOUSE_PLOT_SECTION_GAP
        end
    else
        if budget.plot then
            yOffset = DrawBudgetRow(nil, "plot", "outdoor", L["PROGRESS_BUDGET_OUTDOOR"], budget.plot, false)
        end
        if budget.interior then
            yOffset = DrawBudgetRow(nil, "interior", "interior", L["PROGRESS_BUDGET_INDOOR"], budget.interior, false)
        end
    end

    for key in pairs(previousKeys) do
        if not activeKeys[key] then
            SetSidebarElementShown(elements[key], false)
            if elements[key] and elements[key].label then elements[key].label:Hide() end
            if elements[key] and elements[key].text then elements[key].text:Hide() end
        end
    end

    return yOffset - SIDEBAR_SECTION_GAP
end

function ProgressTab:BuildHistorySparkline(elements, panel, yOffset, history)
    local L = addon.L
    local days = CONSTS.COLLECTION_HISTORY_DISPLAY_DAYS
    if not history then return yOffset end


    local function GetDayLabel(dayOffset)
        local daysAgo = math.abs(dayOffset or 0)
        if daysAgo == 0 then
            return L["PROGRESS_HISTORY_TOOLTIP_TODAY"]
        end
        local key = daysAgo == 1 and "PROGRESS_HISTORY_TOOLTIP_DAY_AGO" or "PROGRESS_HISTORY_TOOLTIP_DAYS_AGO"
        return string.format(L[key], daysAgo)
    end

    local function ShowHistoryTooltip(owner, point)
        point = point or {}
        local gain = math.max(0, math.floor(point.gain or 0))
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(GetDayLabel(point.dayOffset), 1, 0.82, 0)
        if gain > 0 then
            GameTooltip:AddLine(string.format(L["PROGRESS_HISTORY_TOOLTIP_GAIN"], gain), 0.45, 1, 0.45)
        else
            GameTooltip:AddLine(L["PROGRESS_HISTORY_TOOLTIP_EMPTY"], 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine(string.format(L["PROGRESS_HISTORY_SUMMARY"], history.totalGain or 0, days), 0.8, 0.8, 0.8)
        if type(point.startCount) == "number" then
            GameTooltip:AddLine(string.format(L["PROGRESS_HISTORY_TOOLTIP_START"], addon:FormatLargeNumber(point.startCount)), 0.65, 0.70, 0.78)
        end
        if type(point.count) == "number" then
            GameTooltip:AddLine(string.format(L["PROGRESS_HISTORY_TOOLTIP_TOTAL"], addon:FormatLargeNumber(point.count)), 0.8, 0.8, 0.8)
        elseif not point.hasData then
            GameTooltip:AddLine(L["PROGRESS_HISTORY_TOOLTIP_NO_SNAPSHOT"], 0.55, 0.55, 0.6)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["PROGRESS_HISTORY_TOOLTIP_HINT"], 0.5, 0.8, 1, true)
        GameTooltip:Show()
    end

    local usableWidth = SIDEBAR_WIDTH - 38
    local gap = 2
    local barWidth = math.max(3, math.floor((usableWidth - gap * (days - 1)) / days))
    local scaleMax = math.max(3, history.maxGain or 0)
    local baseY = yOffset - CONSTS.COLLECTION_HISTORY_BAR_MAX_H

    for i = 1, days do
        local key = "historyBar" .. i
        if not elements[key] or not elements[key].SetScript then
            SetSidebarElementShown(elements[key], false)
            local frame = CreateFrame("Button", nil, panel)
            frame:EnableMouse(true)
            frame.fill = frame:CreateTexture(nil, "ARTWORK")
            frame.fill:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            frame.fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            elements[key] = frame
        end
        local bar = elements[key]
        local point = history.gains[i] or { dayOffset = i - days, gain = 0, hasData = false }
        local gain = point.gain or 0
        local height = CONSTS.COLLECTION_HISTORY_BAR_MIN_H
        if gain > 0 then
            height = math.max(CONSTS.COLLECTION_HISTORY_BAR_MIN_H, math.floor(gain / scaleMax * CONSTS.COLLECTION_HISTORY_BAR_MAX_H))
        end
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 12 + (i - 1) * (barWidth + gap), baseY)
        bar:SetSize(barWidth, CONSTS.COLLECTION_HISTORY_BAR_MAX_H)
        bar.fill:SetHeight(height)
        bar.fill:SetColorTexture(COLORS.GOLD[1], COLORS.GOLD[2], COLORS.GOLD[3], gain > 0 and 0.75 or 0.50)
        bar:SetScript("OnEnter", function(b)
            ShowHistoryTooltip(b, point)
        end)
        bar:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        bar:Show()
        bar.fill:Show()
    end
    yOffset = yOffset - CONSTS.COLLECTION_HISTORY_BAR_MAX_H - 4

    SetSidebarElementShown(elements.historySummary, false)

    return yOffset - SIDEBAR_HISTORY_BOTTOM_GAP
end

function ProgressTab:BuildSidebarSummary()
    if not self.sidePanel then return end

    local L = addon.L
    local overview = addon:GetProgressOverview()
    local progressColor = self:GetProgressColor(overview.percent)
    local panel = self.sideContent or self.sidePanel
    local elements = self.sidebarElements
    local yOffset = -12
    for _, element in pairs(elements) do
        element:Hide()
    end

    yOffset = self:PlaceSidebarSectionHeader(elements, panel, "overview", L["PROGRESS_OVERVIEW"], yOffset)

    if not elements.subtitle then
        elements.subtitle = CreateSidebarText(panel, "GameFontNormal", 14, "CENTER")
    end
    elements.subtitle:ClearAllPoints()
    elements.subtitle:SetPoint("TOP", panel, "TOP", 0, yOffset)
    elements.subtitle:SetText(L["PROGRESS_ALL_DECOR_COLLECTED"])
    elements.subtitle:SetTextColor(unpack(COLORS.TEXT_SECONDARY))
    elements.subtitle:Show()
    yOffset = yOffset - 24

    if not elements.bigPercent then
        elements.bigPercent = CreateSidebarText(panel, "GameFontNormal", 34, "CENTER")
    end
    elements.bigPercent:ClearAllPoints()
    elements.bigPercent:SetPoint("TOP", panel, "TOP", 0, yOffset)
    local displayedOverviewPercent = overview.remaining > 0 and math.min(overview.percent, 99.9) or overview.percent
    elements.bigPercent:SetText(string.format("%.1f%%", displayedOverviewPercent))
    elements.bigPercent:SetTextColor(unpack(progressColor))
    elements.bigPercent:Show()
    yOffset = yOffset - 40

    if not elements.progressBar then
        local bar = CreateFrame("StatusBar", nil, panel)
        bar:SetHeight(16)
        bar:SetMinMaxValues(0, 100)
        bar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")

        local barBg = bar:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints()
        barBg:SetColorTexture(0.10, 0.10, 0.13, 0.8)

        elements.progressBar = bar
    end
    local bar = elements.progressBar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
    bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, yOffset)
    bar:SetValue(overview.percent)
    bar:SetStatusBarColor(progressColor[1], progressColor[2], progressColor[3], 0.6)
    bar:Show()
    yOffset = yOffset - 28

    local statValueColor = COLORS.TEXT_TERTIARY
    local primaryStats = {
        { key = "collected", label = L["PROGRESS_COLLECTED"], value = tostring(overview.collected), color = statValueColor },
        { key = "total", label = L["PROGRESS_TOTAL"], value = tostring(overview.total), color = statValueColor },
        { key = "remaining", label = L["PROGRESS_REMAINING"], value = tostring(overview.remaining), color = statValueColor },
        { key = "wishlist", label = L["PROGRESS_STAT_WISHLIST"] .. " >", value = tostring(addon:GetWishlistCount()), color = statValueColor, onClick = function()
            if InCombatLockdown() then
                addon:Print(L["COMBAT_LOCKDOWN_MESSAGE"])
                return
            end
            if addon.MainFrame then
                addon.MainFrame:Hide()
            end
            if addon.WishlistFrame then
                addon.WishlistFrame:Show()
            end
        end },
        { key = "hidden", label = L["PROGRESS_STAT_HIDDEN"] .. " >", value = tostring(addon:GetHiddenDecorCount()), color = statValueColor, onClick = function() addon.HiddenItemsFrame:ShowFrame() end },
    }

    for _, stat in ipairs(primaryStats) do
        self:SetupSidebarStatRow(elements, panel, stat, yOffset)
        yOffset = yOffset - 18
    end

    local history = addon.GetCollectionHistoryGains and addon:GetCollectionHistoryGains(CONSTS.COLLECTION_HISTORY_DISPLAY_DAYS)
    if history then
        yOffset = yOffset - SIDEBAR_SECTION_GAP
        yOffset = self:PlaceSidebarDualDivider(elements, panel, "overviewHistory", yOffset)
        yOffset = self:PlaceSidebarSectionHeader(elements, panel, "history", string.format(L["PROGRESS_HISTORY_HEADER"], CONSTS.COLLECTION_HISTORY_DISPLAY_DAYS), yOffset)
        yOffset = self:BuildHistorySparkline(elements, panel, yOffset, history)
    end

    local budget = addon.GetPlacementBudget and addon:GetPlacementBudget()
    if budget then
        yOffset = yOffset - SIDEBAR_SECTION_GAP
        yOffset = self:PlaceSidebarDualDivider(elements, panel, "historyBudget", yOffset)
        yOffset = self:PlaceSidebarSectionHeader(elements, panel, "budget", L["PROGRESS_BUDGET_HEADER"], yOffset)
        yOffset = self:BuildBudgetRows(elements, panel, yOffset)
    end

    local contentHeight = math.max(1, math.abs(yOffset) + 12)
    if self.sideScrollChild then
        self.sideScrollChild:SetHeight(contentHeight)
    end
    if self.sideScrollFrame then
        local range = self.sideScrollFrame:GetVerticalScrollRange()
        self.sideScrollFrame:SetVerticalScroll(math.max(0, math.min(range, self.sideScrollFrame:GetVerticalScroll())))
        self:UpdateSidebarScrollbar()
    end
end
--------------------------------------------------------------------------------
-- Section Header Helper
--------------------------------------------------------------------------------

function ProgressTab:GetOrCreateSectionHeader(key)
    if self[key] then return self[key] end

    local header = addon:CreateFontString(self.scrollChild, "OVERLAY", "GameFontNormal")
    header:SetJustifyH("LEFT")
    addon:SetFontSize(header, 14, "")
    self[key] = header
    return header
end

function ProgressTab:PlaceSectionHeader(key, text, yOffset, xOffset)
    xOffset = xOffset or 0
    local header = self:GetOrCreateSectionHeader(key)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", xOffset, yOffset)
    header:SetText(text)
    header:SetTextColor(unpack(COLORS.GOLD))
    header:Show()
    return yOffset - 24
end

--------------------------------------------------------------------------------
-- Progress Row Helper (with StatusBar)
--------------------------------------------------------------------------------

function ProgressTab:GetOrCreateProgressRow(pool, index)
    if pool[index] then return pool[index] end

    local row = CreateFrame("Button", nil, self.scrollChild)
    row:SetHeight(ROW_HEIGHT)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.10, 0.13, 0.6)
    row.bg = bg

    -- StatusBar (fills behind text)
    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetAllPoints()
    bar:SetMinMaxValues(0, 100)
    bar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
    bar:SetFrameLevel(row:GetFrameLevel() + 1)
    row.bar = bar

    -- Label and progressText are children of BAR (not row) so they render above the fill
    local label = addon:CreateFontString(bar, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 8, 0)
    label:SetJustifyH("LEFT")
    addon:SetFontSize(label, 13, "")
    row.label = label

    local progressText = addon:CreateFontString(bar, "OVERLAY", "GameFontNormal")
    progressText:SetPoint("RIGHT", -8, 0)
    progressText:SetJustifyH("RIGHT")
    addon:SetFontSize(progressText, 12, "")
    row.progressText = progressText

    pool[index] = row
    return row
end

function ProgressTab:SetupProgressRow(row, data, yOffset, rowWidth, onClick, xOffset)
    local L = addon.L
    xOffset = xOffset or 0
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", xOffset, yOffset)
    row:SetWidth(rowWidth)

    local displayLabel = data.displayLabel
        or (data.professionName and addon:GetLocalizedProfessionName(data.professionName))
        or L[data.labelKey] or data.labelKey
    -- For "Most Progressed" rows, suffix with source kind
    if data.sourceLabel then
        displayLabel = displayLabel .. "  |cFF888888(" .. data.sourceLabel .. ")|r"
    end
    row.label:SetText(displayLabel)
    row.label:SetTextColor(unpack(COLORS.TEXT_SECONDARY))

    local pctText
    if data.percent == 100 then
        pctText = string.format("%d/%d  |TInterface\\RaidFrame\\ReadyCheck-Ready:14|t", data.owned, data.total)
    else
        local displayedPercent = data.owned < data.total and math.min(data.percent, 99) or data.percent
        pctText = string.format("%d/%d  %.0f%%", data.owned, data.total, displayedPercent)
    end
    row.progressText:SetText(pctText)
    local progressColor = self:GetProgressColor(data.percent)
    row.progressText:SetTextColor(unpack(progressColor))

    -- StatusBar fill with subtle color
    row.bar:SetValue(data.percent)
    row.bar:SetStatusBarColor(progressColor[1], progressColor[2], progressColor[3], 0.25)

    row:SetScript("OnClick", onClick)
    if onClick then
        row:SetScript("OnEnter", function(r) r.bg:SetColorTexture(0.14, 0.14, 0.16, 0.8) end)
        row:SetScript("OnLeave", function(r) r.bg:SetColorTexture(0.10, 0.10, 0.13, 0.6) end)
    else
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
    end
    row:Show()
end

--------------------------------------------------------------------------------
-- By Source Section
--------------------------------------------------------------------------------

local function GetCompletionFilter(data)
    return (data.owned == data.total and data.total > 0) and "complete" or "incomplete"
end

local function NavigateToSourceTab(tabObj, tabKey, arg, filter)
    tabObj.pendingNavigation = true
    addon.Tabs:SelectTab(tabKey)
    if tabObj.frame then
        tabObj:NavigateFromProgress(arg, filter)
    end
end

function ProgressTab:BuildSourceSection(yOffset, columnWidth, xOffset)
    local L = addon.L

    yOffset = self:PlaceSectionHeader("sourceHeader", L["PROGRESS_BY_SOURCE"], yOffset, xOffset)

    local sourceData = addon:GetProgressBySourceType()
    for i, data in ipairs(sourceData) do
        local row = self:GetOrCreateProgressRow(self.sourceRows, i)
        self:SetupProgressRow(row, data, yOffset, columnWidth, function()
            local filter = GetCompletionFilter(data)
            if data.category then
                NavigateToSourceTab(addon.DropsTab, "DROPS", data.category, filter)
            elseif data.targetTabKey == "DROPS" then
                NavigateToSourceTab(addon.DropsTab, "DROPS", nil, filter)
            elseif data.targetTabKey == "ACHIEVEMENTS" then
                NavigateToSourceTab(addon.AchievementsTab, "ACHIEVEMENTS", nil, filter)
            elseif data.targetTabKey == "PVP" then
                NavigateToSourceTab(addon.PvPTab, "PVP", nil, filter)
            elseif data.targetTabKey == "RENOWN" then
                NavigateToSourceTab(addon.RenownTab, "RENOWN", nil, filter)
            elseif data.targetTabKey == "VENDORS" then
                NavigateToSourceTab(addon.VendorsTab, "VENDORS", nil, filter)
            elseif data.targetTabKey == "QUESTS" then
                NavigateToSourceTab(addon.QuestsTab, "QUESTS", nil, filter)
            elseif data.targetTabKey == "PROFESSIONS" then
                NavigateToSourceTab(addon.ProfessionsTab, "PROFESSIONS", nil, filter)
            elseif data.targetTabKey == "DECOR" then
                addon.Tabs:SelectTab("DECOR")
                addon.Filters:ResetAllFilters({ preserveGlobalVisibility = true })
            elseif data.targetTabKey == "DECOR_PROMO" then
                -- Reset first so the landing view is a clean "just promo items",
                -- not an intersection with any stale search text / other filters
                -- left active on the Decor tab. Then enable promo-only and switch
                -- tabs — SelectTab fires TAB_CHANGED synchronously which triggers
                -- RunSearchNow, and by that point showPromoOnly is already true.
                addon.Filters:ResetAllFilters({ preserveGlobalVisibility = true })
                addon.Filters:SetPromoOnly(true)
                addon.Tabs:SelectTab("DECOR")
                addon.Filters:SaveState()
            end
        end, xOffset)
        yOffset = yOffset - ROW_SPACING
    end

    return yOffset
end

--------------------------------------------------------------------------------
-- Professions Section
--------------------------------------------------------------------------------

function ProgressTab:BuildProfessionsSection(yOffset, columnWidth, xOffset)
    local L = addon.L

    local profData = addon:GetProgressByProfession()
    if #profData == 0 then return yOffset end

    yOffset = self:PlaceSectionHeader("professionsHeader", L["PROGRESS_PROFESSIONS"], yOffset, xOffset)

    for i, data in ipairs(profData) do
        local row = self:GetOrCreateProgressRow(self.professionRows, i)
        local onClick = nil
        if not CONSTS.NPC_CRAFTING_SOURCES[data.professionName] then
            onClick = function()
                self:NavigateToProfession(data.professionName, GetCompletionFilter(data))
            end
        end
        self:SetupProgressRow(row, data, yOffset, columnWidth, onClick, xOffset)
        yOffset = yOffset - ROW_SPACING
    end

    return yOffset
end

--------------------------------------------------------------------------------
-- Expansion Section (vendor only now)
--------------------------------------------------------------------------------

function ProgressTab:BuildExpansionSection(yOffset, columnWidth, headerKey, headerText, expansionData, rowPool, xOffset)
    yOffset = self:PlaceSectionHeader(headerKey .. "Header", headerText, yOffset, xOffset)

    for i, data in ipairs(expansionData) do
        local row = self:GetOrCreateProgressRow(rowPool, i)
        self:SetupProgressRow(row, data, yOffset, columnWidth, function()
            self:NavigateToDetail(data)
        end, xOffset)
        yOffset = yOffset - ROW_SPACING
    end

    return yOffset
end

--------------------------------------------------------------------------------
-- Most Progressed Section
--------------------------------------------------------------------------------

function ProgressTab:BuildAlmostThereSection(yOffset, columnWidth, xOffset)
    local L = addon.L

    local rows = addon:GetAlmostThereRows(5)
    if #rows == 0 then return yOffset end

    yOffset = self:PlaceSectionHeader("almostThereHeader", L["PROGRESS_ALMOST_THERE"], yOffset, xOffset)

    for i, data in ipairs(rows) do
        local isUnknownExpansion = (data.labelKey == "QUESTS_UNKNOWN_EXPANSION"
                                    or data.labelKey == "VENDORS_UNKNOWN_EXPANSION")
        local sourceLabelKey = SOURCE_LABEL_KEYS[data.sourceKind] or "PROGRESS_SOURCE_VENDORS"

        -- Resolve display label for types that need special handling
        local resolvedLabel
        if data.categoryId then
            resolvedLabel = addon:GetCategoryName(data.categoryId)
        elseif isUnknownExpansion then
            resolvedLabel = L[sourceLabelKey]
        end

        local displayData = {
            displayLabel   = resolvedLabel,
            labelKey       = data.labelKey,
            professionName = data.professionName,
            owned          = data.owned,
            total          = data.total,
            percent        = data.percent,
            sourceLabel    = not isUnknownExpansion and L[sourceLabelKey] or nil,
        }

        local row = self:GetOrCreateProgressRow(self.almostThereRows, i)
        self:SetupProgressRow(row, displayData, yOffset, columnWidth, function()
            self:NavigateToDetail(data)
        end, xOffset)
        yOffset = yOffset - ROW_SPACING
    end

    return yOffset
end

--------------------------------------------------------------------------------
-- Click Navigation
--------------------------------------------------------------------------------

function ProgressTab:NavigateToDetail(data)
    local filter = GetCompletionFilter(data)
    if data.sourceKind == "QUESTS" then
        NavigateToSourceTab(addon.QuestsTab, "QUESTS", data.expansionKey, filter)
    elseif data.sourceKind == "VENDORS" then
        NavigateToSourceTab(addon.VendorsTab, "VENDORS", data.expansionKey, filter)
    elseif data.sourceKind == "RENOWN" then
        NavigateToSourceTab(addon.RenownTab, "RENOWN", data.expansionKey, filter)
    elseif data.sourceKind == "ACHIEVEMENTS" then
        NavigateToSourceTab(addon.AchievementsTab, "ACHIEVEMENTS", data.categoryId, filter)
    elseif data.sourceKind == "DROPS" then
        NavigateToSourceTab(addon.DropsTab, "DROPS", data.category, filter)
    elseif data.sourceKind == "PVP" then
        NavigateToSourceTab(addon.PvPTab, "PVP", data.pvpCategory, filter)
    elseif data.sourceKind == "PROFESSIONS" then
        self:NavigateToProfession(data.professionName, filter)
    end
end

function ProgressTab:NavigateToProfession(professionName, filter)
    addon.ProfessionsTab.pendingNavigation = true
    addon.Tabs:SelectTab("PROFESSIONS")
    if addon.ProfessionsTab.frame then
        addon.ProfessionsTab:NavigateFromProgress(professionName, filter)
    end
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

ProgressTab:RegisterTabVisibility("PROGRESS")

addon:RegisterInternalEvent("DATA_LOADED", function()
    if not ProgressTab:IsShown() then return end
    ProgressTab:EnsureIndexes()
    ProgressTab:RefreshDisplay(true)
end)

ProgressTab:RegisterOwnershipRefresh(function()
    ProgressTab:EnsureIndexes()
    ProgressTab:RefreshDisplay(true)
end)

addon:RegisterInternalEvent(addon.Events.DECOR_VISIBILITY_CHANGED, function()
    if ProgressTab:IsShown() then
        ProgressTab:EnsureIndexes()
        ProgressTab:RefreshDisplay(true)
    end
end)

addon:RegisterInternalEvent(addon.Events.WISHLIST_CHANGED, function()
    if ProgressTab:IsShown() then
        ProgressTab:BuildSidebarSummary()
    end
end)

addon:RegisterInternalEvent(addon.Events.PLACEMENT_BUDGET_UPDATED, function()
    if ProgressTab:IsShown() then
        ProgressTab:BuildSidebarSummary()
    end
end)

addon:RegisterInternalEvent(addon.Events.COLLECTION_HISTORY_UPDATED, function()
    if ProgressTab:IsShown() then
        ProgressTab:BuildSidebarSummary()
    end
end)

addon.MainFrame:RegisterContentAreaInitializer("ProgressTab", function(contentArea)
    ProgressTab:Create(contentArea)
end)
