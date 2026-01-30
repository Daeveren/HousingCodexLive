--[[
    Housing Codex - QuestsTab.lua
    Quest sources tab with Expansion > Zone > Quest hierarchy
]]

local ADDON_NAME, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS

-- Layout constants
local TOOLBAR_HEIGHT = 32
local SIDEBAR_WIDTH = CONSTS.SIDEBAR_WIDTH  -- 182 - same as main sidebar
local EXPANSION_PANEL_WIDTH = 198           -- Left column for expansions (10% wider)
local HIERARCHY_PADDING = 8
local HEADER_HEIGHT = 32  -- Expansion/zone header height
local ROW_HEIGHT = 26     -- Quest row height
local GRID_OUTER_PAD = CONSTS.GRID_OUTER_PAD
local WISHLIST_STAR_SIZE = 14  -- Small star for quest rows

-- Button colors
local COLOR_GOLD_BORDER = { 1, 0.82, 0, 1 }

-- Progress colors
local COLOR_PROGRESS_COMPLETE = { 0.2, 1, 0.2, 1 }   -- Green for 100%
local COLOR_PROGRESS_PARTIAL = { 1, 0.82, 0, 1 }     -- Gold for 50%+
local COLOR_PROGRESS_LOW = { 0.7, 0.7, 0.7, 1 }      -- Gray for <50%
local COLOR_PROGRESS_LOW_DIM = { 0.6, 0.6, 0.6, 1 }  -- Slightly dimmer for zones

-- Solid colors for expansion headers (flat, no gradient)
local COLOR_EXPANSION_NORMAL = { 0.14, 0.14, 0.16, 0.9 }
local COLOR_EXPANSION_HOVER = { 0.19, 0.19, 0.21, 1 }

-- Solid colors for zone headers (darker, distinct from expansion)
local COLOR_ZONE_NORMAL = { 0.12, 0.12, 0.14, 0.95 }
local COLOR_ZONE_HOVER = { 0.16, 0.16, 0.18, 1 }

-- Selected quest row background (neutral gray, not gold-tinted)
local COLOR_QUEST_SELECTED = { 0.20, 0.20, 0.22, 1 }

-- Helper to get progress text color based on percentage
local function GetProgressColor(percent, useZoneDim)
    if percent == 100 then
        return COLOR_PROGRESS_COMPLETE
    elseif percent >= 50 then
        return COLOR_PROGRESS_PARTIAL
    else
        return useZoneDim and COLOR_PROGRESS_LOW_DIM or COLOR_PROGRESS_LOW
    end
end

-- Helper to apply expansion button visual state
local function ApplyExpansionButtonState(frame, isSelected)
    if isSelected then
        frame.bg:SetColorTexture(unpack(COLOR_EXPANSION_HOVER))
        frame.selectionBorder:Show()
        frame.label:SetTextColor(1, 0.82, 0, 1)
    else
        frame.bg:SetColorTexture(unpack(COLOR_EXPANSION_NORMAL))
        frame.selectionBorder:Hide()
        frame.label:SetTextColor(0.9, 0.9, 0.9, 1)
    end
end

-- Helper to reset background texture to solid color mode (clears gradient from recycled frames)
local function ResetBackgroundTexture(bg)
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetGradient("HORIZONTAL", CreateColor(1,1,1,1), CreateColor(1,1,1,1))  -- Clear gradient
end

-- Helper to apply quest row visual state
local function ApplyQuestRowState(frame, isSelected)
    ResetBackgroundTexture(frame.bg)
    if isSelected then
        frame.bg:SetColorTexture(unpack(COLOR_QUEST_SELECTED))
        frame.selectionBorder:Show()
        frame.label:SetTextColor(unpack(COLOR_GOLD_BORDER))  -- Gold/yellow text for selected
    else
        frame.bg:SetColorTexture(0.08, 0.08, 0.10, 0.9)
        frame.selectionBorder:Hide()
        -- Restore text color based on completion state (stored on frame during setup)
        local textBrightness = frame.isComplete and 0.5 or 0.7
        frame.label:SetTextColor(textBrightness, textBrightness, textBrightness, 1)
    end
end

-- Helper to print tracking result messages
local function PrintTrackingResult(errorCode, startedKey, failedKey)
    local L = addon.L
    if errorCode == nil then
        addon:Print(L[startedKey])
    elseif errorCode == Enum.ContentTrackingError.MaxTracked then
        addon:Print(L["QUESTS_TRACKING_MAX_REACHED"])
    elseif errorCode == Enum.ContentTrackingError.AlreadyTracked then
        addon:Print(L["QUESTS_TRACKING_ALREADY"])
    else
        addon:Print(L[failedKey])
    end
end

-- Helper to create an empty state frame with centered message
local function CreateEmptyStateFrame(parent, messageKey, descKey, descWidth)
    local L = addon.L
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.95)

    local hasDesc = descKey ~= nil
    local msg = addon:CreateFontString(frame, "OVERLAY", hasDesc and "GameFontNormal" or "GameFontNormalLarge")
    msg:SetPoint("CENTER", 0, hasDesc and 10 or 0)
    msg:SetText(L[messageKey])
    msg:SetTextColor(hasDesc and 0.6 or 0.5, hasDesc and 0.6 or 0.5, hasDesc and 0.6 or 0.5, 1)

    if hasDesc then
        local desc = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        desc:SetPoint("TOP", msg, "BOTTOM", 0, -8)
        desc:SetText(L[descKey])
        desc:SetTextColor(0.5, 0.5, 0.5, 1)
        if descWidth then desc:SetWidth(descWidth) end
    end

    return frame
end

addon.QuestsTab = {}
local QuestsTab = addon.QuestsTab

-- Helper to get quests db state (avoids repeated nil checks)
local function GetQuestsDB()
    return addon.db and addon.db.browser and addon.db.browser.quests
end

-- UI elements
QuestsTab.frame = nil
QuestsTab.toolbar = nil
QuestsTab.expansionPanel = nil
QuestsTab.expansionScrollBox = nil
QuestsTab.zoneQuestPanel = nil
QuestsTab.zoneQuestScrollBox = nil
QuestsTab.zoneQuestScrollBar = nil
QuestsTab.searchBox = nil
QuestsTab.filterButtons = {}
QuestsTab.emptyState = nil
QuestsTab.noExpansionState = nil

-- State
QuestsTab.selectedExpansionKey = nil
QuestsTab.selectedQuestID = nil
QuestsTab.selectedRecordID = nil  -- For multi-reward quests
QuestsTab.hoveringRecordID = nil  -- For hover-to-preview


--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------

function QuestsTab:Create(parent)
    if self.frame then return end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()  -- Hidden by default, shown when tab selected
    self.frame = frame

    -- Create toolbar
    self:CreateToolbar(frame)

    -- Create expansion panel (left column)
    self:CreateExpansionPanel(frame)

    -- Create zone/quest panel (right side - fills remaining space)
    self:CreateZoneQuestPanel(frame)

    -- Create empty states
    self:CreateEmptyStates()

    addon:Debug("QuestsTab created")
end

function QuestsTab:Show()
    if not self.frame then return end

    -- Build index if not done
    if not addon.questIndexBuilt then
        addon:BuildQuestIndex()
        addon:BuildQuestHierarchy()
    end

    self.frame:Show()

    -- Restore saved state
    local saved = GetQuestsDB()
    if saved then
        self.selectedExpansionKey = saved.selectedExpansionKey
        self.selectedQuestID = saved.selectedQuestID
        self.selectedRecordID = saved.selectedRecordID
        self:SetCompletionFilter(saved.completionFilter or "incomplete")
    end

    -- Update displays
    self:BuildExpansionDisplay()
    self:BuildZoneQuestDisplay()
    self:UpdateEmptyStates()
end

function QuestsTab:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function QuestsTab:IsShown()
    return self.frame and self.frame:IsShown()
end

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------

function QuestsTab:CreateToolbar(parent)
    local toolbar = CreateFrame("Frame", nil, parent)
    toolbar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    toolbar:SetHeight(TOOLBAR_HEIGHT)
    self.toolbar = toolbar

    -- Background
    local bg = toolbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.07, 0.9)

    local L = addon.L

    -- Search box (left side)
    local searchBox = CreateFrame("EditBox", nil, toolbar, "SearchBoxTemplate")
    searchBox:SetPoint("LEFT", toolbar, "LEFT", GRID_OUTER_PAD, 0)
    searchBox:SetSize(200, 20)
    searchBox:SetAutoFocus(false)
    searchBox.Instructions:SetText(L["QUESTS_SEARCH_PLACEHOLDER"])
    self.searchBox = searchBox

    searchBox:HookScript("OnTextChanged", function(box, userInput)
        if userInput then
            self:OnSearchTextChanged(box:GetText())
        end
    end)

    -- Handle clear button click (X button)
    if searchBox.clearButton then
        searchBox.clearButton:HookScript("OnClick", function()
            self:OnSearchTextChanged("")
        end)
    end

    searchBox:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
    end)

    -- Completion filter buttons (center-left)
    local filterContainer = CreateFrame("Frame", nil, toolbar)
    filterContainer:SetPoint("LEFT", searchBox, "RIGHT", 16, 0)
    filterContainer:SetHeight(22)

    local filters = {
        { key = "all", label = L["QUESTS_FILTER_ALL"] },
        { key = "incomplete", label = L["QUESTS_FILTER_INCOMPLETE"] },
        { key = "complete", label = L["QUESTS_FILTER_COMPLETE"] },
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

    -- Preview toggle button (right side)
    local toggleBtn = addon:CreateToggleButton(toolbar, ">", nil, function()
        if InCombatLockdown() then
            addon:Print(L["COMBAT_LOCKDOWN_MESSAGE"])
            return
        end
        if addon.Preview then
            addon.Preview:Toggle()
        end
    end)
    toggleBtn:SetPoint("RIGHT", toolbar, "RIGHT", -GRID_OUTER_PAD, 0)

    toggleBtn:SetScript("OnEnter", function(b)
        b:SetBackdropColor(0.2, 0.2, 0.24, 1)
        b:SetBackdropBorderColor(0.6, 0.5, 0.1, 1)
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        local isOpen = addon.Preview and addon.Preview:IsShown()
        local key = isOpen and "PREVIEW_COLLAPSE" or "PREVIEW_EXPAND"
        GameTooltip:SetText(L[key])
        GameTooltip:Show()
    end)

    self.previewToggleButton = toggleBtn

    -- Set default filter
    self:SetCompletionFilter("incomplete")
end

function QuestsTab:SetCompletionFilter(filterKey)
    for key, btn in pairs(self.filterButtons) do
        btn:SetActive(key == filterKey)
    end
    local db = GetQuestsDB()
    if db then db.completionFilter = filterKey end
    self:BuildExpansionDisplay()
    self:BuildZoneQuestDisplay()
end

function QuestsTab:GetCompletionFilter()
    local db = GetQuestsDB()
    return db and db.completionFilter or "incomplete"
end

function QuestsTab:OnSearchTextChanged(text)
    text = strtrim(text or "")
    self:BuildExpansionDisplay()
    self:BuildZoneQuestDisplay()
end

--------------------------------------------------------------------------------
-- Expansion Panel (Left Column - narrow list of expansion names)
--------------------------------------------------------------------------------

function QuestsTab:CreateExpansionPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    -- Offset left by SIDEBAR_WIDTH to cover the sidebar area
    panel:SetPoint("TOPLEFT", self.toolbar, "BOTTOMLEFT", -SIDEBAR_WIDTH, 0)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -SIDEBAR_WIDTH, 0)
    panel:SetWidth(EXPANSION_PANEL_WIDTH)
    self.expansionPanel = panel

    -- Background (darker, matches sidebar)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)

    -- Right border separator
    local border = panel:CreateTexture(nil, "ARTWORK")
    border:SetWidth(1)
    border:SetPoint("TOPRIGHT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(0.2, 0.2, 0.25, 1)

    -- Create scroll container (no scrollbar - expansions fit in one view)
    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", HIERARCHY_PADDING, -HIERARCHY_PADDING)
    scrollContainer:SetPoint("BOTTOMRIGHT", -HIERARCHY_PADDING, HIERARCHY_PADDING)

    -- Create ScrollBox
    local scrollBox = CreateFrame("Frame", nil, scrollContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    self.expansionScrollBox = scrollBox

    -- Create list view with FIXED height (all expansions same height)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(HEADER_HEIGHT)
    view:SetPadding(0, 0, 0, 0, 4)  -- Add 4px spacing between expansion items
    view:SetElementInitializer("Button", function(frame, elementData)
        self:SetupExpansionButton(frame, elementData)
    end)

    -- Initialize ScrollBox without scrollbar (call Init directly)
    scrollBox:Init(view)
end

function QuestsTab:SetupExpansionButton(frame, elementData)
    local L = addon.L

    -- One-time frame setup
    if not frame.bg then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        frame.bg = bg

        local border = frame:CreateTexture(nil, "ARTWORK")
        border:SetWidth(3)
        border:SetPoint("TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMLEFT", 0, 0)
        border:SetColorTexture(unpack(COLOR_GOLD_BORDER))
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

    -- Reset state
    frame.selectionBorder:Hide()
    frame.expansionKey = elementData.expansionKey

    local isSelected = self.selectedExpansionKey == elementData.expansionKey
    ApplyExpansionButtonState(frame, isSelected)

    frame.label:SetText(L[elementData.expansionKey] or elementData.expansionKey)
    addon:SetFontSize(frame.label, 13, "")

    -- Quest completion percentage
    local completed, total = addon:GetExpansionQuestCompletionProgress(elementData.expansionKey)
    local pctValue = total > 0 and (completed / total * 100) or 0
    frame.percentLabel:SetText(string.format("%.0f%%", pctValue))
    frame.percentLabel:SetTextColor(addon:GetCompletionProgressColor(pctValue))
    addon:SetFontSize(frame.percentLabel, 11, "")

    frame:SetScript("OnClick", function()
        self:SelectExpansion(elementData.expansionKey)
    end)

    frame:SetScript("OnEnter", function(f)
        if self.selectedExpansionKey ~= f.expansionKey then
            f.bg:SetColorTexture(unpack(COLOR_EXPANSION_HOVER))
        end
    end)

    frame:SetScript("OnLeave", function(f)
        ApplyExpansionButtonState(f, self.selectedExpansionKey == f.expansionKey)
    end)
end

function QuestsTab:SelectExpansion(expansionKey)
    local prevSelected = self.selectedExpansionKey
    self.selectedExpansionKey = expansionKey

    -- Save to DB
    local db = GetQuestsDB()
    if db then db.selectedExpansionKey = expansionKey end

    -- Reset all zones in this expansion to expanded (removes collapsed state)
    if db and db.expandedZones then
        for _, zoneName in ipairs(addon:GetSortedZones(expansionKey)) do
            local key = expansionKey .. ":" .. zoneName
            db.expandedZones[key] = nil  -- nil = default expanded
        end
    end

    -- Update expansion panel visuals (visible frames only)
    if self.expansionScrollBox then
        self.expansionScrollBox:ForEachFrame(function(frame)
            if frame.expansionKey then
                ApplyExpansionButtonState(frame, frame.expansionKey == expansionKey)
            end
        end)
    end

    -- Rebuild zone/quest panel
    self:BuildZoneQuestDisplay()

    -- Clear quest selection and preview when switching expansions
    if prevSelected ~= expansionKey then
        self.selectedQuestID = nil
        self.selectedRecordID = nil
        if db then
            db.selectedQuestID = nil
            db.selectedRecordID = nil
        end
        addon:FireEvent("RECORD_SELECTED", nil)
    end

    self:UpdateEmptyStates()
end

--------------------------------------------------------------------------------
-- Zone/Quest Panel (Middle Column - zones with expandable quests)
--------------------------------------------------------------------------------

function QuestsTab:CreateZoneQuestPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    -- Position to right of expansion panel, fill remaining space
    panel:SetPoint("TOPLEFT", self.expansionPanel, "TOPRIGHT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.zoneQuestPanel = panel

    -- Background (darker, matches sidebar)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)

    -- Create scroll container
    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", HIERARCHY_PADDING, -HIERARCHY_PADDING)
    scrollContainer:SetPoint("BOTTOMRIGHT", -HIERARCHY_PADDING - 16, HIERARCHY_PADDING)

    -- Create ScrollBox
    local scrollBox = CreateFrame("Frame", nil, scrollContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    self.zoneQuestScrollBox = scrollBox

    -- Create ScrollBar
    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollContainer, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollContainer, "BOTTOMRIGHT", 4, 0)
    self.zoneQuestScrollBar = scrollBar

    -- Create list view with dynamic element heights
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(dataIndex, elementData)
        -- Zone headers are taller than quest rows
        if elementData.isZone then
            return HEADER_HEIGHT
        end
        return ROW_HEIGHT
    end)
    view:SetElementInitializer("Button", function(frame, elementData)
        self:SetupZoneQuestButton(frame, elementData)
    end)

    -- Initialize ScrollBox
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    self.zoneQuestView = view
end

function QuestsTab:SetupZoneQuestButton(frame, elementData)
    local L = addon.L

    -- Setup frame if needed (one-time initialization)
    if not frame.bg then
        -- Background texture for gradient effects
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        frame.bg = bg

        -- Selection border (left edge gold bar)
        local border = frame:CreateTexture(nil, "ARTWORK")
        border:SetWidth(3)
        border:SetPoint("TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMLEFT", 0, 0)
        border:SetColorTexture(unpack(COLOR_GOLD_BORDER))
        border:Hide()
        frame.selectionBorder = border

        -- Collapse indicator (+/-) for zones, (o) for incomplete quests
        local indicator = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        addon:SetFontSize(indicator, 14, "OUTLINE")
        indicator:SetPoint("LEFT", 8, 0)
        indicator:SetWidth(20)
        indicator:SetJustifyH("LEFT")
        frame.indicator = indicator

        -- Checkmark icon for completed quests
        local checkIcon = frame:CreateTexture(nil, "OVERLAY")
        checkIcon:SetSize(14, 14)
        checkIcon:SetPoint("LEFT", 20, 0)
        checkIcon:SetAtlas("common-icon-checkmark")
        checkIcon:SetVertexColor(0.4, 0.9, 0.4, 1)  -- Green tint
        checkIcon:Hide()
        frame.checkIcon = checkIcon

        -- Incomplete icon (small pip for incomplete quests)
        local incompleteIcon = frame:CreateTexture(nil, "OVERLAY")
        incompleteIcon:SetSize(8, 8)
        incompleteIcon:SetPoint("LEFT", 23, 0)
        incompleteIcon:SetTexture("Interface\\Buttons\\WHITE8x8")
        incompleteIcon:SetVertexColor(0.7, 0.5, 0.2, 0.8)  -- Muted orange
        incompleteIcon:Hide()
        frame.incompleteIcon = incompleteIcon

        -- Label
        local label = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", 28, 0)
        label:SetPoint("RIGHT", -80, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        frame.label = label

        -- Progress (right side)
        local progress = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        progress:SetPoint("RIGHT", -8, 0)
        progress:SetJustifyH("RIGHT")
        frame.progress = progress

        -- Wishlist star badge (next to quest name)
        local wishlistStar = frame:CreateTexture(nil, "OVERLAY")
        wishlistStar:SetSize(WISHLIST_STAR_SIZE, WISHLIST_STAR_SIZE)
        wishlistStar:SetPoint("LEFT", 40, 0)  -- Will be repositioned after label
        wishlistStar:SetAtlas("PetJournal-FavoritesIcon")
        wishlistStar:SetVertexColor(unpack(COLORS.GOLD))
        wishlistStar:Hide()
        frame.wishlistStar = wishlistStar

        frame:EnableMouse(true)
    end

    -- Reset state
    frame.selectionBorder:Hide()
    frame.checkIcon:Hide()
    if frame.incompleteIcon then frame.incompleteIcon:Hide() end
    if frame.wishlistStar then frame.wishlistStar:Hide() end
    frame.questID = nil
    frame.recordID = nil
    frame.expansionKey = nil
    frame.zoneName = nil
    frame.isZone = nil

    if elementData.isZone then
        -- ZONE HEADER (first-level item)
        frame:SetHeight(HEADER_HEIGHT)
        frame.expansionKey = elementData.expansionKey
        frame.zoneName = elementData.zoneName
        frame.isZone = true

        local isExpanded = self:IsZoneExpanded(elementData.expansionKey, elementData.zoneName)

        -- Reset background texture state (clears gradient from recycled quest rows)
        ResetBackgroundTexture(frame.bg)

        -- Solid dark background
        frame.bg:SetColorTexture(unpack(COLOR_ZONE_NORMAL))

        -- Collapse indicator
        frame.indicator:SetText(isExpanded and "-" or "+")
        frame.indicator:SetTextColor(1, 1, 1, 1)
        frame.indicator:SetPoint("LEFT", 8, 0)
        frame.indicator:Show()

        -- Zone name (pure white)
        frame.label:SetText(elementData.zoneName)
        frame.label:SetTextColor(1, 1, 1, 1)
        addon:SetFontSize(frame.label, 12, "")
        frame.label:SetPoint("LEFT", 28, 0)

        -- Progress
        local owned, total = addon:GetZoneCollectionProgress(elementData.expansionKey, elementData.zoneName)
        local percent = total > 0 and math.floor((owned / total) * 100) or 0
        frame.progress:SetText(string.format("%d/%d (%d%%)", owned, total, percent))
        frame.progress:SetTextColor(unpack(GetProgressColor(percent, true)))

        frame:SetScript("OnClick", function()
            self:ToggleZone(elementData.expansionKey, elementData.zoneName)
        end)

        frame:SetScript("OnEnter", function(f)
            f.bg:SetColorTexture(unpack(COLOR_ZONE_HOVER))
        end)

        frame:SetScript("OnLeave", function(f)
            f.bg:SetColorTexture(unpack(COLOR_ZONE_NORMAL))
        end)

    else
        -- QUEST ROW (indented under zone)
        frame:SetHeight(ROW_HEIGHT)
        frame.questID = elementData.questID
        frame.recordID = elementData.recordID

        -- For multi-reward quests, check if this specific reward is collected
        -- For single-reward quests, use quest completion status
        local isComplete
        if elementData.recordID then
            local record = addon:GetRecord(elementData.recordID)
            isComplete = record and record.isCollected or false
        else
            isComplete = addon:IsQuestCompleted(elementData.questID)
        end
        frame.isComplete = isComplete  -- Store for ApplyQuestRowState to use
        local isSelected = self.selectedQuestID == elementData.questID and
            (not elementData.recordID or self.selectedRecordID == elementData.recordID)
        ApplyQuestRowState(frame, isSelected)

        -- Completion indicator: checkmark for complete, orange pip for incomplete
        frame.indicator:Hide()  -- indicator only used for zone +/-
        if isComplete then
            frame.checkIcon:Show()
            frame.incompleteIcon:Hide()
        else
            frame.checkIcon:Hide()
            frame.incompleteIcon:Show()
        end

        -- Quest name (text color handled by ApplyQuestRowState)
        -- Multi-reward quests show "Quest Name (1)", "Quest Name (2)", etc.
        local questTitle = addon:GetQuestTitle(elementData.questID)
        if elementData.totalRewards and elementData.totalRewards > 1 then
            questTitle = questTitle .. " (" .. elementData.rewardIndex .. ")"
        end
        frame.label:SetText(questTitle)
        addon:SetFontSize(frame.label, 11, "")
        frame.label:SetPoint("LEFT", 40, 0)

        -- Wishlist star (show if item is wishlisted)
        if frame.wishlistStar and elementData.recordID then
            local isWishlisted = addon:IsWishlisted(elementData.recordID)
            frame.wishlistStar:SetShown(isWishlisted)
            if isWishlisted then
                -- Position star after label text
                frame.wishlistStar:ClearAllPoints()
                frame.wishlistStar:SetPoint("LEFT", frame.label, "LEFT", frame.label:GetStringWidth() + 4, 0)
            end
        end

        -- Progress
        local owned, total = addon:GetQuestCollectionProgress(elementData.questID)
        frame.progress:SetText(string.format("%d/%d", owned, total))
        local progressComplete = owned == total and total > 0
        frame.progress:SetTextColor(unpack(progressComplete and COLOR_PROGRESS_COMPLETE or COLOR_PROGRESS_LOW))

        frame:SetScript("OnMouseDown", function(f, button)
            if button == "RightButton" then
                -- Right-Click: Copy Wowhead URL to clipboard
                if type(elementData.questID) == "number" then
                    local url = "https://www.wowhead.com/quest=" .. elementData.questID
                    CopyToClipboard(url)
                    addon:Print(string.format(addon.L["WOWHEAD_LINK_COPIED"], url))
                else
                    addon:Print(addon.L["WOWHEAD_LINK_NO_ID"])
                end
                return
            end

            if IsShiftKeyDown() then
                -- Shift+Click: Toggle tracking the decor reward
                local recordID = elementData.recordID or (addon:GetRecordsForQuest(elementData.questID) or {})[1]
                if not recordID then
                    addon:Print(addon.L["QUESTS_TRACKING_FAILED"])
                    return
                end

                local trackingType = Enum.ContentTrackingType.Decor
                if C_ContentTracking.IsTracking(trackingType, recordID) then
                    C_ContentTracking.StopTracking(trackingType, recordID, Enum.ContentTrackingStopType.Manual)
                    addon:Print(addon.L["QUESTS_TRACKING_STOPPED"])
                else
                    local err = C_ContentTracking.StartTracking(trackingType, recordID)
                    PrintTrackingResult(err, "QUESTS_TRACKING_STARTED", "QUESTS_TRACKING_FAILED")
                end
            elseif IsControlKeyDown() and elementData.recordID then
                -- Ctrl+Click: Start tracking decor (kept for compatibility)
                local err = C_ContentTracking.StartTracking(Enum.ContentTrackingType.Decor, elementData.recordID)
                PrintTrackingResult(err, "QUESTS_TRACKING_STARTED", "QUESTS_TRACKING_FAILED")
            else
                self:SelectQuest(elementData)
            end
        end)

        frame:SetScript("OnEnter", function(f)
            -- Visual feedback
            if self.selectedQuestID ~= f.questID or self.selectedRecordID ~= f.recordID then
                f.bg:SetColorTexture(0.08, 0.08, 0.10, 1)
            end

            -- Fire preview event for hover
            local recordID = f.recordID
            if not recordID then
                local recordIDs = addon:GetRecordsForQuest(f.questID)
                recordID = recordIDs and recordIDs[1]
            end
            if recordID then
                self.hoveringRecordID = recordID
                addon:FireEvent("RECORD_SELECTED", recordID)
            end

            -- Show quest tooltip at cursor
            GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 15, (y / scale) + 15)
            if type(f.questID) == "number" then
                GameTooltip:SetHyperlink("quest:" .. f.questID)
            else
                local questTitle = addon:GetQuestTitle(f.questID) or f.questID
                GameTooltip:SetText(questTitle, 1, 1, 1)
            end
            GameTooltip:Show()
        end)

        frame:SetScript("OnLeave", function(f)
            GameTooltip:Hide()

            ApplyQuestRowState(f, self.selectedQuestID == f.questID and
                (not f.recordID or self.selectedRecordID == f.recordID))

            self.hoveringRecordID = nil

            -- Restore preview to selected quest
            if self.selectedRecordID then
                addon:FireEvent("RECORD_SELECTED", self.selectedRecordID)
            elseif self.selectedQuestID then
                local recordIDs = addon:GetRecordsForQuest(self.selectedQuestID)
                if recordIDs and recordIDs[1] then
                    addon:FireEvent("RECORD_SELECTED", recordIDs[1])
                end
            end
        end)
    end
end

-- Check if quest matches search text (title, zone, expansion, or reward names)
-- questKey can be a numeric questID or a string questName
local function QuestMatchesSearch(questKey, searchText, zoneName, expansionKey)
    if searchText == "" then return true end

    -- Check quest title
    local title = strlower(addon:GetQuestTitle(questKey) or "")
    if title:find(searchText, 1, true) then return true end

    -- Check zone name
    if strlower(zoneName):find(searchText, 1, true) then return true end

    -- Check expansion name
    local expName = strlower(addon.L[expansionKey] or expansionKey)
    if expName:find(searchText, 1, true) then return true end

    -- Check reward names
    local records = addon:GetRecordsForQuest(questKey)
    for _, recordID in ipairs(records) do
        local record = addon:GetRecord(recordID)
        if record and record.name and strlower(record.name):find(searchText, 1, true) then
            return true
        end
    end

    return false
end

-- Check if quest passes completion filter (based on collection progress, not quest turn-in)
-- questKey can be a numeric questID or a string questName
local function QuestPassesCompletionFilter(questKey, filter)
    if filter == "all" then return true end
    -- Use collection progress: complete = all rewards owned
    local owned, total = addon:GetQuestCollectionProgress(questKey)
    local isComplete = total > 0 and owned == total
    if filter == "complete" then return isComplete end
    if filter == "incomplete" then return not isComplete end
    return true
end

function QuestsTab:BuildExpansionDisplay()
    if not self.expansionScrollBox then return end

    local elements = {}
    local filter = self:GetCompletionFilter()
    local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

    for _, expansionKey in ipairs(addon:GetSortedExpansions()) do
        local hasVisibleContent = false
        for _, zoneName in ipairs(addon:GetSortedZones(expansionKey)) do
            for _, questKey in ipairs(addon:GetQuestsForZone(expansionKey, zoneName)) do
                if QuestPassesCompletionFilter(questKey, filter)
                    and QuestMatchesSearch(questKey, searchText, zoneName, expansionKey) then
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

    local dataProvider = CreateDataProvider(elements)
    self.expansionScrollBox:SetDataProvider(dataProvider)

    -- Helper to check if expansion key exists in elements
    local function HasExpansion(key)
        for _, elem in ipairs(elements) do
            if elem.expansionKey == key then
                return true
            end
        end
        return false
    end

    -- Auto-select expansion if none selected (prefer The War Within)
    if not self.selectedExpansionKey and #elements > 0 then
        local defaultKey = "EXPANSION_TWW"
        self:SelectExpansion(HasExpansion(defaultKey) and defaultKey or elements[1].expansionKey)
    elseif self.selectedExpansionKey and not HasExpansion(self.selectedExpansionKey) then
        -- Current selection no longer visible
        if #elements > 0 then
            self:SelectExpansion(elements[1].expansionKey)
        else
            self.selectedExpansionKey = nil
            self:BuildZoneQuestDisplay()
        end
    end
end

function QuestsTab:BuildZoneQuestDisplay()
    if not self.zoneQuestScrollBox then return end

    local elements = {}
    local expansionKey = self.selectedExpansionKey

    if expansionKey then
        local filter = self:GetCompletionFilter()
        local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

        for _, zoneName in ipairs(addon:GetSortedZones(expansionKey)) do
            local zoneQuests = {}
            for _, questKey in ipairs(addon:GetQuestsForZone(expansionKey, zoneName)) do
                if QuestPassesCompletionFilter(questKey, filter)
                    and QuestMatchesSearch(questKey, searchText, zoneName, expansionKey) then
                    -- Multi-reward quests: show one entry per reward
                    local recordIDs = addon:GetRecordsForQuest(questKey)
                    local numRewards = recordIDs and #recordIDs or 0
                    if numRewards > 1 then
                        for i, recordID in ipairs(recordIDs) do
                            table.insert(zoneQuests, {
                                questID = questKey,
                                recordID = recordID,
                                rewardIndex = i,
                                totalRewards = numRewards
                            })
                        end
                    else
                        table.insert(zoneQuests, {
                            questID = questKey,
                            recordID = recordIDs and recordIDs[1]
                        })
                    end
                end
            end
            if #zoneQuests > 0 then
                table.insert(elements, { isZone = true, expansionKey = expansionKey, zoneName = zoneName })
                if self:IsZoneExpanded(expansionKey, zoneName) then
                    for _, quest in ipairs(zoneQuests) do
                        table.insert(elements, quest)
                    end
                end
            end
        end
    end

    local dataProvider = CreateDataProvider(elements)
    self.zoneQuestScrollBox:SetDataProvider(dataProvider)
    self:UpdateEmptyStates()
end

function QuestsTab:IsZoneExpanded(expansionKey, zoneName)
    local db = GetQuestsDB()
    if not db then return true end  -- Default to expanded
    local key = expansionKey .. ":" .. zoneName
    -- Default to expanded (true) if not explicitly set
    if db.expandedZones[key] == nil then
        return true
    end
    return db.expandedZones[key]
end

function QuestsTab:ToggleZone(expansionKey, zoneName)
    local db = GetQuestsDB()
    if db then
        local key = expansionKey .. ":" .. zoneName
        db.expandedZones[key] = not db.expandedZones[key]
    end
    self:BuildZoneQuestDisplay()
end

function QuestsTab:SelectQuest(elementData)
    local questID = elementData.questID
    local recordID = elementData.recordID

    local prevSelectedQuest = self.selectedQuestID
    local prevSelectedRecord = self.selectedRecordID
    self.selectedQuestID = questID
    self.selectedRecordID = recordID

    local db = GetQuestsDB()
    if db then
        db.selectedQuestID = questID
        db.selectedRecordID = recordID
    end

    -- Update zone/quest panel visuals
    if self.zoneQuestScrollBox then
        self.zoneQuestScrollBox:ForEachFrame(function(frame)
            if frame.questID then
                local wasSelected = frame.questID == prevSelectedQuest and
                    (not prevSelectedRecord or frame.recordID == prevSelectedRecord)
                local isSelected = frame.questID == questID and
                    (not recordID or frame.recordID == recordID)
                if wasSelected or isSelected then
                    ApplyQuestRowState(frame, isSelected)
                end
            end
        end)
    end

    -- Preview the specific reward (use stored recordID for multi-reward quests)
    if recordID then
        addon:FireEvent("RECORD_SELECTED", recordID)
    else
        -- Fallback for single-reward quests
        local recordIDs = addon:GetRecordsForQuest(questID)
        if recordIDs and recordIDs[1] then
            addon:FireEvent("RECORD_SELECTED", recordIDs[1])
        end
    end

    addon:Debug("Selected quest: " .. tostring(questID) .. (recordID and (" recordID: " .. recordID) or ""))
end

--------------------------------------------------------------------------------
-- Empty States
--------------------------------------------------------------------------------

function QuestsTab:CreateEmptyStates()
    -- No quest sources found state (shown in expansion panel)
    self.emptyState = CreateEmptyStateFrame(
        self.expansionPanel,
        "QUESTS_EMPTY_NO_SOURCES",
        "QUESTS_EMPTY_NO_SOURCES_DESC",
        EXPANSION_PANEL_WIDTH - 16
    )

    -- "Select an expansion" state (shown in zone/quest panel when no expansion selected)
    self.noExpansionState = CreateEmptyStateFrame(self.zoneQuestPanel, "QUESTS_SELECT_EXPANSION")
end

function QuestsTab:UpdateEmptyStates()
    local questCount = addon:GetQuestCount()
    local hasQuests = questCount > 0

    -- Show "no sources" if no quests found at all
    if self.emptyState then
        self.emptyState:SetShown(not hasQuests)
    end

    -- Show "select an expansion" in zone panel when no expansion is selected
    if self.noExpansionState then
        self.noExpansionState:SetShown(hasQuests and not self.selectedExpansionKey)
    end

    -- Show/hide expansion scroll box based on state
    if self.expansionScrollBox then
        self.expansionScrollBox:SetShown(hasQuests)
    end

    -- Show/hide zone/quest scroll boxes based on state
    if self.zoneQuestScrollBox then
        self.zoneQuestScrollBox:SetShown(hasQuests and self.selectedExpansionKey ~= nil)
    end
    if self.zoneQuestScrollBar then
        self.zoneQuestScrollBar:SetShown(hasQuests and self.selectedExpansionKey ~= nil)
    end
end

function QuestsTab:UpdatePreviewToggleButton()
    if not self.previewToggleButton then return end

    local isOpen = addon.Preview and addon.Preview:IsShown()
    self.previewToggleButton:SetShown(not isOpen)
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

addon:RegisterInternalEvent("TAB_CHANGED", function(tabKey)
    if tabKey == "QUESTS" then
        QuestsTab:Show()
    else
        QuestsTab:Hide()
    end
end)

addon:RegisterInternalEvent("DATA_LOADED", function()
    -- Build quest index when data is available
    if QuestsTab:IsShown() and not addon.questIndexBuilt then
        addon:BuildQuestIndex()
        addon:BuildQuestHierarchy()
        QuestsTab:BuildExpansionDisplay()
        QuestsTab:BuildZoneQuestDisplay()
        QuestsTab:UpdateEmptyStates()
    end
end)

-- Shared handler for events that require rebuilding quest displays
local function RefreshQuestDisplays()
    if QuestsTab:IsShown() then
        QuestsTab:BuildExpansionDisplay()
        QuestsTab:BuildZoneQuestDisplay()
    end
end

addon:RegisterInternalEvent("QUEST_TITLE_LOADED", RefreshQuestDisplays)
addon:RegisterInternalEvent("QUEST_COMPLETION_CHANGED", RefreshQuestDisplays)
addon:RegisterInternalEvent("QUEST_COMPLETION_CACHE_INVALIDATED", RefreshQuestDisplays)

addon:RegisterInternalEvent("PREVIEW_VISIBILITY_CHANGED", function()
    QuestsTab:UpdatePreviewToggleButton()
end)

addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", RefreshQuestDisplays)

-- Update wishlist stars when wishlist changes
addon:RegisterInternalEvent("WISHLIST_CHANGED", function(recordID, isWishlisted)
    if QuestsTab:IsShown() and QuestsTab.zoneQuestScrollBox then
        QuestsTab.zoneQuestScrollBox:ForEachFrame(function(frame)
            if frame.recordID == recordID and frame.wishlistStar then
                frame.wishlistStar:SetShown(isWishlisted)
                if isWishlisted then
                    -- Reposition star after label text
                    frame.wishlistStar:ClearAllPoints()
                    frame.wishlistStar:SetPoint("LEFT", frame.label, "LEFT", frame.label:GetStringWidth() + 4, 0)
                end
            end
        end)
    end
end)

-- Hook into MainFrame creation (same pattern as Grid.lua)
local originalCreateContent = addon.MainFrame.CreateContentArea
addon.MainFrame.CreateContentArea = function(self)
    originalCreateContent(self)
    if self.contentArea then
        QuestsTab:Create(self.contentArea)
    end
end
