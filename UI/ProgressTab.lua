--[[
    Housing Codex - ProgressTab.lua
    Collection progress dashboard with click navigation to source tabs.
    Sidebar summary panel + two-column layout with StatusBar progress fills.
]]

local ADDON_NAME, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS

-- Layout constants
local SIDEBAR_WIDTH = CONSTS.SIDEBAR_WIDTH
local SECTION_PADDING = 16
local ROW_HEIGHT = 28
local CONTENT_PADDING = 20
local COLUMN_GAP = 16

addon.ProgressTab = {}
local ProgressTab = addon.ProgressTab

Mixin(ProgressTab, addon.TabBaseMixin)
ProgressTab.tabName = "ProgressTab"

ProgressTab.frame = nil
ProgressTab.scrollFrame = nil
ProgressTab.scrollChild = nil
ProgressTab.sidePanel = nil
ProgressTab.sidebarElements = {}
ProgressTab.sourceRows = {}
ProgressTab.professionRows = {}
ProgressTab.vendorExpRows = {}
ProgressTab.almostThereRows = {}

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

    -- Right border separator
    local border = panel:CreateTexture(nil, "ARTWORK")
    border:SetWidth(1)
    border:SetPoint("TOPRIGHT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(0.2, 0.2, 0.25, 1)
end

function ProgressTab:Show()
    if not self.frame then return end

    -- Ensure all indexes are built (lazy-load on first visit, guarded until data is ready)
    if addon.dataLoaded then
        if not addon.questIndexBuilt then
            addon:BuildQuestIndex()
            addon:BuildQuestHierarchy()
        end
        if not addon.vendorIndexBuilt then addon:BuildVendorIndex() end
        if not addon.achievementIndexBuilt then addon:BuildAchievementIndex() end
        if not addon.dropIndexBuilt then addon:BuildDropIndex() end
        if not addon.craftingIndexBuilt then addon:BuildCraftingIndex() end
    end

    self.frame:Show()
    if self.sidePanel then self.sidePanel:Show() end

    -- Collapse preview BEFORE RefreshDisplay so columns are sized for full-width content area
    addon.MainFrame:CollapsePreview()

    self:RefreshDisplay()
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
        if trackHeight <= 0 then return end
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
    thumb:SetScript("OnMouseDown", function(t, button)
        if button == "LeftButton" then
            t.dragging = true
            t.dragStartY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
            t.dragStartScroll = scrollFrame:GetVerticalScroll()
        end
    end)
    thumb:SetScript("OnMouseUp", function(t) t.dragging = false end)
    thumb:SetScript("OnUpdate", function(t)
        if not t.dragging then return end
        local cursorY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
        local deltaY = t.dragStartY - cursorY
        local trackHeight = track:GetHeight()
        local maxTravel = trackHeight - t:GetHeight()
        if maxTravel <= 0 then return end
        local range = scrollFrame:GetVerticalScrollRange()
        scrollFrame:SetVerticalScroll(math.max(0, math.min(range, t.dragStartScroll + (deltaY / maxTravel) * range)))
    end)

    -- Track click to page-scroll
    track:SetScript("OnMouseDown", function(t, button)
        if button ~= "LeftButton" then return end
        local range = scrollFrame:GetVerticalScrollRange()
        if range <= 0 then return end
        local cursorY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
        local pct = (t:GetTop() - cursorY) / t:GetHeight()
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
    end

    self.loadingMsg:SetText(L["PROGRESS_LOADING"])
    self.loadingMsg:SetTextColor(unpack(COLORS.TEXT_TERTIARY))
    addon:SetFontSize(self.loadingMsg, 16, "")
    self.loadingMsg:Show()

    self.scrollChild:SetHeight(200)
end

function ProgressTab:ClearDashboard()
    local pools = { self.sourceRows, self.professionRows, self.vendorExpRows, self.almostThereRows }
    for _, pool in ipairs(pools) do
        for _, frame in ipairs(pool) do
            frame:Hide()
        end
    end

    for _, element in pairs(self.sidebarElements) do
        element:Hide()
    end

    local headers = { "loadingMsg", "sourceHeader", "professionsHeader", "vendorExpHeader", "almostThereHeader" }
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

    -- Left column: By Source + Professions
    local leftY = self:BuildSourceSection(0, columnWidth, 0)
    leftY = leftY - SECTION_PADDING
    leftY = self:BuildProfessionsSection(leftY, columnWidth, 0)

    -- Right column: Most Progressed + Vendor Expansions
    local rightX = columnWidth + COLUMN_GAP
    local rightY = self:BuildAlmostThereSection(0, columnWidth, rightX)
    if rightY < 0 then
        rightY = rightY - SECTION_PADDING
    end
    local vendorExpData = addon:GetProgressByExpansion("VENDORS")
    if #vendorExpData > 0 then
        rightY = self:BuildExpansionSection(rightY, columnWidth, "vendorExp", L["PROGRESS_VENDOR_EXPANSIONS"], vendorExpData, self.vendorExpRows, rightX)
    end

    local totalHeight = math.max(math.abs(leftY), math.abs(rightY))
    self.scrollChild:SetHeight(totalHeight + SECTION_PADDING)

    -- Restore scroll position (clamped to new range)
    if savedScroll > 0 then
        local range = self.scrollFrame:GetVerticalScrollRange()
        self.scrollFrame:SetVerticalScroll(math.min(savedScroll, range))
    end
end

--------------------------------------------------------------------------------
-- Sidebar Summary
--------------------------------------------------------------------------------

function ProgressTab:BuildSidebarSummary()
    if not self.sidePanel then return end

    local L = addon.L
    local overview = addon:GetProgressOverview()
    local progressColor = self:GetProgressColor(overview.percent)
    local panel = self.sidePanel
    local elements = self.sidebarElements
    local yOffset = -16

    -- "OVERVIEW" header
    if not elements.header then
        elements.header = addon:CreateFontString(panel, "OVERLAY", "GameFontNormal")
        elements.header:SetJustifyH("CENTER")
    end
    elements.header:ClearAllPoints()
    elements.header:SetPoint("TOP", panel, "TOP", 0, yOffset)
    elements.header:SetText(L["PROGRESS_OVERVIEW"])
    elements.header:SetTextColor(unpack(COLORS.GOLD))
    addon:SetFontSize(elements.header, 11, "")
    elements.header:Show()
    yOffset = yOffset - 28

    -- "All Decor Collected" subtitle
    if not elements.subtitle then
        elements.subtitle = addon:CreateFontString(panel, "OVERLAY", "GameFontNormal")
        elements.subtitle:SetJustifyH("CENTER")
    end
    elements.subtitle:ClearAllPoints()
    elements.subtitle:SetPoint("TOP", panel, "TOP", 0, yOffset)
    elements.subtitle:SetText(L["PROGRESS_ALL_DECOR_COLLECTED"])
    elements.subtitle:SetTextColor(unpack(COLORS.TEXT_SECONDARY))
    addon:SetFontSize(elements.subtitle, 14, "")
    elements.subtitle:Show()
    yOffset = yOffset - 24

    -- Big percentage
    if not elements.bigPercent then
        elements.bigPercent = addon:CreateFontString(panel, "OVERLAY", "GameFontNormal")
        elements.bigPercent:SetJustifyH("CENTER")
    end
    elements.bigPercent:ClearAllPoints()
    elements.bigPercent:SetPoint("TOP", panel, "TOP", 0, yOffset)
    elements.bigPercent:SetText(string.format("%.1f%%", overview.percent))
    elements.bigPercent:SetTextColor(unpack(progressColor))
    addon:SetFontSize(elements.bigPercent, 34, "")
    elements.bigPercent:Show()
    yOffset = yOffset - 44

    -- Overall progress bar
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

    -- Stat rows (label left, value right)
    local stats = {
        { key = "collected", label = L["PROGRESS_COLLECTED"], value = tostring(overview.collected), color = COLORS.GOLD },
        { key = "total", label = L["PROGRESS_TOTAL"], value = tostring(overview.total), color = COLORS.TEXT_PRIMARY },
        { key = "remaining", label = L["PROGRESS_REMAINING"], value = tostring(overview.remaining), color = COLORS.TEXT_TERTIARY },
    }

    for _, stat in ipairs(stats) do
        local labelKey = "label_" .. stat.key
        local valueKey = "value_" .. stat.key

        if not elements[labelKey] then
            elements[labelKey] = addon:CreateFontString(panel, "OVERLAY", "GameFontNormal")
            elements[labelKey]:SetJustifyH("LEFT")
        end
        elements[labelKey]:ClearAllPoints()
        elements[labelKey]:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, yOffset)
        elements[labelKey]:SetText(stat.label)
        elements[labelKey]:SetTextColor(unpack(COLORS.TEXT_TERTIARY))
        addon:SetFontSize(elements[labelKey], 12, "")
        elements[labelKey]:Show()

        if not elements[valueKey] then
            elements[valueKey] = addon:CreateFontString(panel, "OVERLAY", "GameFontNormal")
            elements[valueKey]:SetJustifyH("RIGHT")
        end
        elements[valueKey]:ClearAllPoints()
        elements[valueKey]:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, yOffset)
        elements[valueKey]:SetText(stat.value)
        elements[valueKey]:SetTextColor(unpack(stat.color))
        addon:SetFontSize(elements[valueKey], 12, "")
        elements[valueKey]:Show()

        yOffset = yOffset - 22
    end
end

--------------------------------------------------------------------------------
-- Section Header Helper
--------------------------------------------------------------------------------

function ProgressTab:GetOrCreateSectionHeader(key)
    if self[key] then return self[key] end

    local header = addon:CreateFontString(self.scrollChild, "OVERLAY", "GameFontNormal")
    header:SetJustifyH("LEFT")
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
    addon:SetFontSize(header, 14, "")
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
    row.label = label

    local progressText = addon:CreateFontString(bar, "OVERLAY", "GameFontNormal")
    progressText:SetPoint("RIGHT", -8, 0)
    progressText:SetJustifyH("RIGHT")
    row.progressText = progressText

    row:SetScript("OnEnter", function(r)
        r.bg:SetColorTexture(0.14, 0.14, 0.16, 0.8)
    end)
    row:SetScript("OnLeave", function(r)
        r.bg:SetColorTexture(0.10, 0.10, 0.13, 0.6)
    end)

    pool[index] = row
    return row
end

function ProgressTab:SetupProgressRow(row, data, yOffset, rowWidth, onClick, xOffset)
    local L = addon.L
    xOffset = xOffset or 0
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", xOffset, yOffset)
    row:SetWidth(rowWidth)

    local displayLabel = L[data.labelKey] or data.labelKey
    -- For "Most Progressed" rows, suffix with source kind
    if data.sourceLabel then
        displayLabel = displayLabel .. "  |cFF888888(" .. data.sourceLabel .. ")|r"
    end
    row.label:SetText(displayLabel)
    row.label:SetTextColor(unpack(COLORS.TEXT_SECONDARY))
    addon:SetFontSize(row.label, 13, "")

    local pctText
    if data.percent == 100 then
        pctText = string.format("%d/%d  |TInterface\\RaidFrame\\ReadyCheck-Ready:14|t", data.owned, data.total)
    else
        pctText = string.format("%d/%d  %.0f%%", data.owned, data.total, data.percent)
    end
    row.progressText:SetText(pctText)
    local progressColor = self:GetProgressColor(data.percent)
    row.progressText:SetTextColor(unpack(progressColor))
    addon:SetFontSize(row.progressText, 12, "")

    -- StatusBar fill with subtle color
    row.bar:SetValue(data.percent)
    row.bar:SetStatusBarColor(progressColor[1], progressColor[2], progressColor[3], 0.25)

    row:SetScript("OnClick", onClick)
    row:Show()
end

--------------------------------------------------------------------------------
-- By Source Section
--------------------------------------------------------------------------------

function ProgressTab:BuildSourceSection(yOffset, columnWidth, xOffset)
    local L = addon.L

    yOffset = self:PlaceSectionHeader("sourceHeader", L["PROGRESS_BY_SOURCE"], yOffset, xOffset)

    local sourceData = addon:GetProgressBySourceType()
    for i, data in ipairs(sourceData) do
        local row = self:GetOrCreateProgressRow(self.sourceRows, i)
        self:SetupProgressRow(row, data, yOffset, columnWidth, function()
            addon.Tabs:SelectTab(data.targetTabKey)
        end, xOffset)
        yOffset = yOffset - ROW_HEIGHT - 2
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
        self:SetupProgressRow(row, data, yOffset, columnWidth, function()
            self:NavigateToProfession(data.professionName)
        end, xOffset)
        yOffset = yOffset - ROW_HEIGHT - 2
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
            self:NavigateToExpansion(data)
        end, xOffset)
        yOffset = yOffset - ROW_HEIGHT - 2
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
        -- If expansion name is "Other" (unmapped zones), just show the source type name
        local isUnknownExpansion = (data.labelKey == "QUESTS_UNKNOWN_EXPANSION" or data.labelKey == "VENDORS_UNKNOWN_EXPANSION")
        local sourceLabelKey = data.sourceKind == "QUESTS" and "PROGRESS_SOURCE_QUESTS" or "PROGRESS_SOURCE_VENDORS"
        local displayData = {
            labelKey    = isUnknownExpansion and sourceLabelKey or data.labelKey,
            owned       = data.owned,
            total       = data.total,
            percent     = data.percent,
            sourceLabel = not isUnknownExpansion and L[sourceLabelKey] or nil,
        }

        local row = self:GetOrCreateProgressRow(self.almostThereRows, i)
        self:SetupProgressRow(row, displayData, yOffset, columnWidth, function()
            self:NavigateToExpansion(data)
        end, xOffset)
        yOffset = yOffset - ROW_HEIGHT - 2
    end

    return yOffset
end

--------------------------------------------------------------------------------
-- Click Navigation
--------------------------------------------------------------------------------

function ProgressTab:NavigateToExpansion(data)
    if data.sourceKind == "QUESTS" then
        addon.Tabs:SelectTab("QUESTS")
        if addon.QuestsTab.frame then
            addon.QuestsTab:SetCompletionFilter("incomplete")
            addon.QuestsTab:SelectExpansion(data.expansionKey)
        end
    elseif data.sourceKind == "VENDORS" then
        addon.Tabs:SelectTab("VENDORS")
        if addon.VendorsTab.frame then
            addon.VendorsTab:SetCompletionFilter("incomplete")
            addon.VendorsTab:SelectExpansion(data.expansionKey)
        end
    end
end

function ProgressTab:NavigateToProfession(professionName)
    addon.Tabs:SelectTab("PROFESSIONS")
    if addon.ProfessionsTab.frame then
        addon.ProfessionsTab:SelectProfession(professionName)
    end
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

addon:RegisterInternalEvent("TAB_CHANGED", function(tabKey)
    if tabKey == "PROGRESS" then
        ProgressTab:Show()
    else
        ProgressTab:Hide()
    end
end)

addon:RegisterInternalEvent("DATA_LOADED", function()
    if not ProgressTab:IsShown() then return end

    if not addon.questIndexBuilt then
        addon:BuildQuestIndex()
        addon:BuildQuestHierarchy()
    end
    if not addon.vendorIndexBuilt then addon:BuildVendorIndex() end
    if not addon.achievementIndexBuilt then addon:BuildAchievementIndex() end
    if not addon.dropIndexBuilt then addon:BuildDropIndex() end
    if not addon.craftingIndexBuilt then addon:BuildCraftingIndex() end

    ProgressTab:RefreshDisplay(true)
end)

ProgressTab:RegisterOwnershipRefresh(function()
    ProgressTab:RefreshDisplay(true)
end)

addon.MainFrame:RegisterContentAreaInitializer("ProgressTab", function(contentArea)
    ProgressTab:Create(contentArea)
end)
