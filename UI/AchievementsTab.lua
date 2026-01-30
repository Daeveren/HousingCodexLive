--[[
    Housing Codex - AchievementsTab.lua
    Achievement sources tab with Category > Achievement flat list
]]

local ADDON_NAME, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS

-- Layout constants
local TOOLBAR_HEIGHT = 32
local SIDEBAR_WIDTH = CONSTS.SIDEBAR_WIDTH  -- 182 - same as main sidebar
local CATEGORY_PANEL_WIDTH = 198            -- Left column for categories (10% wider)
local HIERARCHY_PADDING = 8
local ROW_HEIGHT = 26     -- Achievement row height
local GRID_OUTER_PAD = CONSTS.GRID_OUTER_PAD
local WISHLIST_STAR_SIZE = 14  -- Small star for achievement rows
local CATEGORY_BUTTON_HEIGHT = 32  -- Category button height

-- Category names from WoW API are already localized by the game
-- No lookup table needed - we display GetCategoryInfo() results directly

-- Button colors
local COLOR_GOLD_BORDER = { 1, 0.82, 0, 1 }

-- Progress colors (used for collection progress display)
local COLOR_PROGRESS_COMPLETE = { 0.2, 1, 0.2, 1 }   -- Green for 100%
local COLOR_PROGRESS_LOW = { 0.7, 0.7, 0.7, 1 }      -- Gray for incomplete

-- Solid colors for category buttons
local COLOR_CATEGORY_NORMAL = { 0.14, 0.14, 0.16, 0.9 }
local COLOR_CATEGORY_HOVER = { 0.19, 0.19, 0.21, 1 }

-- Selected achievement row background
local COLOR_ACHIEVEMENT_SELECTED = { 0.20, 0.20, 0.22, 1 }

-- Helper to apply category button visual state
local function ApplyCategoryButtonState(frame, isSelected)
    if isSelected then
        frame.bg:SetColorTexture(unpack(COLOR_CATEGORY_HOVER))
        frame.selectionBorder:Show()
        frame.label:SetTextColor(1, 0.82, 0, 1)
    else
        frame.bg:SetColorTexture(unpack(COLOR_CATEGORY_NORMAL))
        frame.selectionBorder:Hide()
        frame.label:SetTextColor(0.9, 0.9, 0.9, 1)
    end
end

-- Helper to reset background texture to solid color mode
local function ResetBackgroundTexture(bg)
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetGradient("HORIZONTAL", CreateColor(1,1,1,1), CreateColor(1,1,1,1))
end

-- Helper to apply achievement row visual state
local function ApplyAchievementRowState(frame, isSelected)
    ResetBackgroundTexture(frame.bg)
    if isSelected then
        frame.bg:SetColorTexture(unpack(COLOR_ACHIEVEMENT_SELECTED))
        frame.selectionBorder:Show()
        frame.label:SetTextColor(unpack(COLOR_GOLD_BORDER))
    else
        frame.bg:SetColorTexture(0.08, 0.08, 0.10, 0.9)
        frame.selectionBorder:Hide()
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
        addon:Print(L["ACHIEVEMENTS_TRACKING_MAX_REACHED"])
    elseif errorCode == Enum.ContentTrackingError.AlreadyTracked then
        addon:Print(L["ACHIEVEMENTS_TRACKING_ALREADY"])
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

addon.AchievementsTab = {}
local AchievementsTab = addon.AchievementsTab

-- Helper to get achievements db state
local function GetAchievementsDB()
    return addon.db and addon.db.browser and addon.db.browser.achievements
end

-- UI elements
AchievementsTab.frame = nil
AchievementsTab.toolbar = nil
AchievementsTab.categoryPanel = nil
AchievementsTab.categoryScrollBox = nil
AchievementsTab.achievementPanel = nil
AchievementsTab.achievementScrollBox = nil
AchievementsTab.achievementScrollBar = nil
AchievementsTab.searchBox = nil
AchievementsTab.filterButtons = {}
AchievementsTab.emptyState = nil
AchievementsTab.noCategoryState = nil
AchievementsTab.noResultsState = nil

-- State
AchievementsTab.selectedCategory = nil
AchievementsTab.selectedAchievementID = nil
AchievementsTab.selectedRecordID = nil
AchievementsTab.hoveringRecordID = nil

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------

function AchievementsTab:Create(parent)
    if self.frame then return end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    self.frame = frame

    -- Create toolbar
    self:CreateToolbar(frame)

    -- Create category panel (left column)
    self:CreateCategoryPanel(frame)

    -- Create achievement panel (right side - fills remaining space)
    self:CreateAchievementPanel(frame)

    -- Create empty states
    self:CreateEmptyStates()

    addon:Debug("AchievementsTab created")
end

function AchievementsTab:Show()
    if not self.frame then return end

    -- Build index if not done
    if not addon.achievementIndexBuilt then
        addon:BuildAchievementIndex()
        addon:BuildAchievementHierarchy()
    end

    self.frame:Show()

    -- Restore saved state
    local saved = GetAchievementsDB()
    if saved then
        self.selectedCategory = saved.selectedCategory
        self.selectedAchievementID = saved.selectedAchievementID
        self.selectedRecordID = saved.selectedRecordID
        self:SetCompletionFilter(saved.completionFilter or "incomplete")
    end

    -- Update displays
    self:BuildCategoryDisplay()
    self:BuildAchievementDisplay()
    self:UpdateEmptyStates()
end

function AchievementsTab:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function AchievementsTab:IsShown()
    return self.frame and self.frame:IsShown()
end

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------

function AchievementsTab:CreateToolbar(parent)
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
    searchBox.Instructions:SetText(L["ACHIEVEMENTS_SEARCH_PLACEHOLDER"])
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
        { key = "all", label = L["ACHIEVEMENTS_FILTER_ALL"] },
        { key = "incomplete", label = L["ACHIEVEMENTS_FILTER_INCOMPLETE"] },
        { key = "complete", label = L["ACHIEVEMENTS_FILTER_COMPLETE"] },
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

function AchievementsTab:SetCompletionFilter(filterKey)
    for key, btn in pairs(self.filterButtons) do
        btn:SetActive(key == filterKey)
    end
    local db = GetAchievementsDB()
    if db then db.completionFilter = filterKey end
    self:BuildCategoryDisplay()
    self:BuildAchievementDisplay()
end

function AchievementsTab:GetCompletionFilter()
    local db = GetAchievementsDB()
    return db and db.completionFilter or "incomplete"
end

function AchievementsTab:OnSearchTextChanged(text)
    text = strtrim(text or "")
    self:BuildCategoryDisplay()
    self:BuildAchievementDisplay()
end

--------------------------------------------------------------------------------
-- Category Panel (Left Column)
--------------------------------------------------------------------------------

function AchievementsTab:CreateCategoryPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", self.toolbar, "BOTTOMLEFT", -SIDEBAR_WIDTH, 0)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -SIDEBAR_WIDTH, 0)
    panel:SetWidth(CATEGORY_PANEL_WIDTH)
    self.categoryPanel = panel

    -- Background
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)

    -- Right border separator
    local border = panel:CreateTexture(nil, "ARTWORK")
    border:SetWidth(1)
    border:SetPoint("TOPRIGHT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(0.2, 0.2, 0.25, 1)

    -- Create scroll container
    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", HIERARCHY_PADDING, -HIERARCHY_PADDING)
    scrollContainer:SetPoint("BOTTOMRIGHT", -HIERARCHY_PADDING, HIERARCHY_PADDING)

    -- Create ScrollBox
    local scrollBox = CreateFrame("Frame", nil, scrollContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    self.categoryScrollBox = scrollBox

    -- Create list view with FIXED height
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(CATEGORY_BUTTON_HEIGHT)
    view:SetPadding(0, 0, 0, 0, 4)
    view:SetElementInitializer("Button", function(frame, elementData)
        self:SetupCategoryButton(frame, elementData)
    end)

    scrollBox:Init(view)
end

function AchievementsTab:SetupCategoryButton(frame, elementData)
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
    frame.category = elementData.category

    local isSelected = self.selectedCategory == elementData.category
    ApplyCategoryButtonState(frame, isSelected)

    -- Category names from WoW API are already localized
    frame.label:SetText(elementData.category)
    addon:SetFontSize(frame.label, 13, "")

    -- Achievement completion percentage
    local completed, total = addon:GetCategoryAchievementCompletionProgress(elementData.category)
    local pctValue = total > 0 and (completed / total * 100) or 0
    frame.percentLabel:SetText(string.format("%.0f%%", pctValue))
    frame.percentLabel:SetTextColor(addon:GetCompletionProgressColor(pctValue))
    addon:SetFontSize(frame.percentLabel, 11, "")

    frame:SetScript("OnClick", function()
        self:SelectCategory(elementData.category)
    end)

    frame:SetScript("OnEnter", function(f)
        if self.selectedCategory ~= f.category then
            f.bg:SetColorTexture(unpack(COLOR_CATEGORY_HOVER))
        end
    end)

    frame:SetScript("OnLeave", function(f)
        ApplyCategoryButtonState(f, self.selectedCategory == f.category)
    end)
end

function AchievementsTab:SelectCategory(category)
    local prevSelected = self.selectedCategory
    self.selectedCategory = category

    -- Save to DB
    local db = GetAchievementsDB()
    if db then db.selectedCategory = category end

    -- Update category panel visuals
    if self.categoryScrollBox then
        self.categoryScrollBox:ForEachFrame(function(frame)
            if frame.category then
                ApplyCategoryButtonState(frame, frame.category == category)
            end
        end)
    end

    -- Rebuild achievement panel
    self:BuildAchievementDisplay()

    -- Clear selection and preview when switching categories
    if prevSelected ~= category then
        self.selectedAchievementID = nil
        self.selectedRecordID = nil
        if db then
            db.selectedAchievementID = nil
            db.selectedRecordID = nil
        end
        addon:FireEvent("RECORD_SELECTED", nil)
    end

    self:UpdateEmptyStates()
end

--------------------------------------------------------------------------------
-- Achievement Panel (Right Side - flat list)
--------------------------------------------------------------------------------

function AchievementsTab:CreateAchievementPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", self.categoryPanel, "TOPRIGHT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.achievementPanel = panel

    -- Background
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
    self.achievementScrollBox = scrollBox

    -- Create ScrollBar
    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollContainer, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollContainer, "BOTTOMRIGHT", 4, 0)
    self.achievementScrollBar = scrollBar

    -- Create list view with fixed element heights
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", function(frame, elementData)
        self:SetupAchievementButton(frame, elementData)
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    self.achievementView = view
end

function AchievementsTab:SetupAchievementButton(frame, elementData)
    local L = addon.L

    -- Setup frame if needed (one-time initialization)
    if not frame.bg then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        frame.bg = bg

        -- Selection border
        local border = frame:CreateTexture(nil, "ARTWORK")
        border:SetWidth(3)
        border:SetPoint("TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMLEFT", 0, 0)
        border:SetColorTexture(unpack(COLOR_GOLD_BORDER))
        border:Hide()
        frame.selectionBorder = border

        -- Checkmark icon for completed achievements
        local checkIcon = frame:CreateTexture(nil, "OVERLAY")
        checkIcon:SetSize(14, 14)
        checkIcon:SetPoint("LEFT", 8, 0)
        checkIcon:SetAtlas("common-icon-checkmark")
        checkIcon:SetVertexColor(0.4, 0.9, 0.4, 1)
        checkIcon:Hide()
        frame.checkIcon = checkIcon

        -- Incomplete icon (small pip)
        local incompleteIcon = frame:CreateTexture(nil, "OVERLAY")
        incompleteIcon:SetSize(8, 8)
        incompleteIcon:SetPoint("LEFT", 11, 0)
        incompleteIcon:SetTexture("Interface\\Buttons\\WHITE8x8")
        incompleteIcon:SetVertexColor(0.7, 0.5, 0.2, 0.8)
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

        -- Wishlist star badge
        local wishlistStar = frame:CreateTexture(nil, "OVERLAY")
        wishlistStar:SetSize(WISHLIST_STAR_SIZE, WISHLIST_STAR_SIZE)
        wishlistStar:SetPoint("LEFT", 40, 0)
        wishlistStar:SetAtlas("PetJournal-FavoritesIcon")
        wishlistStar:SetVertexColor(unpack(COLORS.GOLD))
        wishlistStar:Hide()
        frame.wishlistStar = wishlistStar

        frame:EnableMouse(true)
    end

    -- Reset state
    frame.selectionBorder:Hide()
    frame.checkIcon:Hide()
    frame.incompleteIcon:Hide()
    frame.wishlistStar:Hide()
    frame.achievementID = elementData.achievementID
    frame.recordID = elementData.recordID

    -- Achievement completion is based on achievement earned status
    local isComplete = addon:IsAchievementCompleted(elementData.achievementID)
    frame.isComplete = isComplete

    local isSelected = self.selectedAchievementID == elementData.achievementID and
        (not elementData.recordID or self.selectedRecordID == elementData.recordID)
    ApplyAchievementRowState(frame, isSelected)

    -- Completion indicator
    if isComplete then
        frame.checkIcon:Show()
    else
        frame.incompleteIcon:Show()
    end

    -- Achievement name (multi-decor shows "Name (1)", "Name (2)")
    local achievementName = addon:GetAchievementName(elementData.achievementID)
    if elementData.totalRewards and elementData.totalRewards > 1 then
        achievementName = achievementName .. " (" .. elementData.rewardIndex .. ")"
    end
    frame.label:SetText(achievementName)
    addon:SetFontSize(frame.label, 11, "")

    -- Wishlist star
    if frame.wishlistStar and elementData.recordID then
        local isWishlisted = addon:IsWishlisted(elementData.recordID)
        frame.wishlistStar:SetShown(isWishlisted)
        if isWishlisted then
            frame.wishlistStar:ClearAllPoints()
            frame.wishlistStar:SetPoint("LEFT", frame.label, "LEFT", frame.label:GetStringWidth() + 4, 0)
        end
    end

    -- Progress (collection progress for the achievement's decors)
    local owned, total = addon:GetAchievementCollectionProgress(elementData.achievementID)
    frame.progress:SetText(string.format("%d/%d", owned, total))
    local progressComplete = owned == total and total > 0
    frame.progress:SetTextColor(unpack(progressComplete and COLOR_PROGRESS_COMPLETE or COLOR_PROGRESS_LOW))

    frame:SetScript("OnMouseDown", function(f, button)
        if button == "RightButton" then
            -- Right-Click: Copy Wowhead URL to clipboard
            if elementData.achievementID then
                local url = "https://www.wowhead.com/achievement=" .. elementData.achievementID
                CopyToClipboard(url)
                addon:Print(string.format(L["WOWHEAD_LINK_COPIED"], url))
            end
            return
        end

        if IsShiftKeyDown() and elementData.achievementID then
            -- Shift+Click: Toggle tracking the achievement
            local trackingType = Enum.ContentTrackingType.Achievement
            local achievementID = elementData.achievementID
            if C_ContentTracking.IsTracking(trackingType, achievementID) then
                C_ContentTracking.StopTracking(trackingType, achievementID, Enum.ContentTrackingStopType.Manual)
                addon:Print(L["ACHIEVEMENTS_TRACKING_STOPPED"])
            else
                local err = C_ContentTracking.StartTracking(trackingType, achievementID)
                PrintTrackingResult(err, "ACHIEVEMENTS_TRACKING_STARTED_ACHIEVEMENT", "ACHIEVEMENTS_TRACKING_FAILED")
            end
        elseif IsControlKeyDown() and elementData.recordID then
            -- Ctrl+Click: Start tracking the decor reward
            local err = C_ContentTracking.StartTracking(Enum.ContentTrackingType.Decor, elementData.recordID)
            PrintTrackingResult(err, "ACHIEVEMENTS_TRACKING_STARTED", "ACHIEVEMENTS_TRACKING_FAILED")
        else
            self:SelectAchievement(elementData)
        end
    end)

    frame:SetScript("OnEnter", function(f)
        -- Visual feedback
        if self.selectedAchievementID ~= f.achievementID or self.selectedRecordID ~= f.recordID then
            f.bg:SetColorTexture(0.08, 0.08, 0.10, 1)
        end

        -- Fire preview event for hover
        local recordID = f.recordID
        if not recordID then
            local recordIDs = addon:GetRecordsForAchievement(f.achievementID)
            recordID = recordIDs and recordIDs[1]
        end
        if recordID then
            self.hoveringRecordID = recordID
            addon:FireEvent("RECORD_SELECTED", recordID)
        end

        -- Show achievement tooltip at cursor with live criteria progress
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 15, (y / scale) + 15)

        local achievementID = f.achievementID
        local _, name, _, completed, month, day, year, description = GetAchievementInfo(achievementID)

        -- Achievement name (gold if completed, white otherwise)
        local r, g, b = 1, 1, 1
        if completed then r, g, b = 1, 0.82, 0 end
        GameTooltip:AddLine(name, r, g, b)

        -- Description
        if description then
            GameTooltip:AddLine(description, 1, 1, 1, true)
        end

        -- Criteria progress
        local numCriteria = GetAchievementNumCriteria(achievementID)
        if numCriteria and numCriteria > 0 then
            GameTooltip:AddLine(" ")
            for i = 1, numCriteria do
                local criteriaString, _, criteriaCompleted, quantity, reqQuantity, _, _, _, quantityString
                    = GetAchievementCriteriaInfo(achievementID, i)
                if criteriaString then
                    if criteriaCompleted then
                        GameTooltip:AddLine("  |cff00ff00" .. criteriaString .. "|r")
                    elseif reqQuantity and reqQuantity > 1 then
                        local progressText = quantityString or (quantity .. "/" .. reqQuantity)
                        GameTooltip:AddLine("  |cff808080- " .. criteriaString .. " (" .. progressText .. ")|r")
                    else
                        GameTooltip:AddLine("  |cff808080- " .. criteriaString .. "|r")
                    end
                end
            end
        end

        -- Completion date
        if completed and month and day and year then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format(ACHIEVEMENT_TOOLTIP_COMPLETE, day, month, year), 0.6, 0.6, 0.6)
        end

        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function(f)
        GameTooltip:Hide()

        ApplyAchievementRowState(f, self.selectedAchievementID == f.achievementID and
            (not f.recordID or self.selectedRecordID == f.recordID))

        self.hoveringRecordID = nil

        -- Restore preview to selected achievement
        if self.selectedRecordID then
            addon:FireEvent("RECORD_SELECTED", self.selectedRecordID)
        elseif self.selectedAchievementID then
            local recordIDs = addon:GetRecordsForAchievement(self.selectedAchievementID)
            if recordIDs and recordIDs[1] then
                addon:FireEvent("RECORD_SELECTED", recordIDs[1])
            end
        end
    end)
end

-- Check if achievement matches search text
local function AchievementMatchesSearch(achievementID, searchText, category)
    if searchText == "" then return true end

    -- Check achievement name
    local name = addon:GetAchievementName(achievementID) or ""
    if strlower(name):find(searchText, 1, true) then return true end

    -- Check category name (already localized from WoW API)
    if strlower(category):find(searchText, 1, true) then return true end

    -- Check decor reward names
    local records = addon:GetRecordsForAchievement(achievementID)
    for _, recordID in ipairs(records) do
        local record = addon:GetRecord(recordID)
        if record and record.name and strlower(record.name):find(searchText, 1, true) then
            return true
        end
    end

    return false
end

-- Check if achievement passes completion filter (based on achievement earned status)
local function AchievementPassesCompletionFilter(achievementID, filter)
    local isComplete = addon:IsAchievementCompleted(achievementID)

    -- Invalid achievement (nil) - hide from all views
    if isComplete == nil then return false end

    if filter == "all" then return true end
    if filter == "complete" then return isComplete end
    if filter == "incomplete" then return not isComplete end
    return true
end

function AchievementsTab:BuildCategoryDisplay()
    if not self.categoryScrollBox then return end

    local elements = {}
    local filter = self:GetCompletionFilter()
    local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

    for _, category in ipairs(addon:GetSortedAchievementCategories()) do
        local hasVisibleContent = false
        for _, achievementID in ipairs(addon:GetAchievementsForCategory(category)) do
            if AchievementPassesCompletionFilter(achievementID, filter)
                and AchievementMatchesSearch(achievementID, searchText, category) then
                hasVisibleContent = true
                break
            end
        end
        if hasVisibleContent then
            table.insert(elements, { category = category })
        end
    end

    local dataProvider = CreateDataProvider(elements)
    self.categoryScrollBox:SetDataProvider(dataProvider)

    -- Check if a category exists in the filtered elements
    local function CategoryExists(cat)
        for _, elem in ipairs(elements) do
            if elem.category == cat then return true end
        end
        return false
    end

    -- Auto-select first category if none selected
    if not self.selectedCategory and #elements > 0 then
        self:SelectCategory(elements[1].category)
    elseif self.selectedCategory and not CategoryExists(self.selectedCategory) then
        -- Current selection no longer visible after filtering
        if #elements > 0 then
            self:SelectCategory(elements[1].category)
        else
            self.selectedCategory = nil
            self:BuildAchievementDisplay()
        end
    end
end

function AchievementsTab:BuildAchievementDisplay()
    if not self.achievementScrollBox then return end

    local elements = {}
    local category = self.selectedCategory

    if category then
        local filter = self:GetCompletionFilter()
        local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

        for _, achievementID in ipairs(addon:GetAchievementsForCategory(category)) do
            if AchievementPassesCompletionFilter(achievementID, filter)
                and AchievementMatchesSearch(achievementID, searchText, category) then
                -- Multi-reward achievements: show one entry per reward
                local recordIDs = addon:GetRecordsForAchievement(achievementID)
                local numRewards = recordIDs and #recordIDs or 0
                if numRewards > 1 then
                    for i, recordID in ipairs(recordIDs) do
                        table.insert(elements, {
                            achievementID = achievementID,
                            recordID = recordID,
                            rewardIndex = i,
                            totalRewards = numRewards
                        })
                    end
                else
                    table.insert(elements, {
                        achievementID = achievementID,
                        recordID = recordIDs and recordIDs[1]
                    })
                end
            end
        end
    end

    local dataProvider = CreateDataProvider(elements)
    self.achievementScrollBox:SetDataProvider(dataProvider)
    self:UpdateEmptyStates()
end

function AchievementsTab:SelectAchievement(elementData)
    local achievementID = elementData.achievementID
    local recordID = elementData.recordID

    local prevSelectedAchievement = self.selectedAchievementID
    local prevSelectedRecord = self.selectedRecordID
    self.selectedAchievementID = achievementID
    self.selectedRecordID = recordID

    local db = GetAchievementsDB()
    if db then
        db.selectedAchievementID = achievementID
        db.selectedRecordID = recordID
    end

    -- Update achievement panel visuals
    if self.achievementScrollBox then
        self.achievementScrollBox:ForEachFrame(function(frame)
            if frame.achievementID then
                local wasSelected = frame.achievementID == prevSelectedAchievement and
                    (not prevSelectedRecord or frame.recordID == prevSelectedRecord)
                local isSelected = frame.achievementID == achievementID and
                    (not recordID or frame.recordID == recordID)
                if wasSelected or isSelected then
                    ApplyAchievementRowState(frame, isSelected)
                end
            end
        end)
    end

    -- Preview the specific reward
    if recordID then
        addon:FireEvent("RECORD_SELECTED", recordID)
    else
        local recordIDs = addon:GetRecordsForAchievement(achievementID)
        if recordIDs and recordIDs[1] then
            addon:FireEvent("RECORD_SELECTED", recordIDs[1])
        end
    end

    addon:Debug("Selected achievement: " .. tostring(achievementID) .. (recordID and (" recordID: " .. recordID) or ""))
end

--------------------------------------------------------------------------------
-- Empty States
--------------------------------------------------------------------------------

function AchievementsTab:CreateEmptyStates()
    -- No achievement sources found state
    self.emptyState = CreateEmptyStateFrame(
        self.categoryPanel,
        "ACHIEVEMENTS_EMPTY_NO_SOURCES",
        "ACHIEVEMENTS_EMPTY_NO_SOURCES_DESC",
        CATEGORY_PANEL_WIDTH - 16
    )

    -- "Select a category" state
    self.noCategoryState = CreateEmptyStateFrame(self.achievementPanel, "ACHIEVEMENTS_SELECT_CATEGORY")

    -- No search results state
    self.noResultsState = CreateEmptyStateFrame(self.achievementPanel, "ACHIEVEMENTS_EMPTY_NO_RESULTS")
end

function AchievementsTab:UpdateEmptyStates()
    local hasAchievements = addon:GetAchievementCount() > 0

    -- Check if current display has results
    local dataProvider = self.achievementScrollBox and self.achievementScrollBox:GetDataProvider()
    local hasResults = dataProvider and dataProvider:GetSize() > 0

    -- Determine visibility states
    local showNoSources = not hasAchievements
    local showSelectCategory = hasAchievements and not self.selectedCategory
    local showNoResults = hasAchievements and self.selectedCategory and not hasResults
    local showAchievementList = hasAchievements and self.selectedCategory and hasResults

    -- Apply visibility to empty states
    if self.emptyState then
        self.emptyState:SetShown(showNoSources)
    end
    if self.noCategoryState then
        self.noCategoryState:SetShown(showSelectCategory)
    end
    if self.noResultsState then
        self.noResultsState:SetShown(showNoResults)
    end

    -- Apply visibility to scroll elements
    if self.categoryScrollBox then
        self.categoryScrollBox:SetShown(hasAchievements)
    end
    if self.achievementScrollBox then
        self.achievementScrollBox:SetShown(showAchievementList)
    end
    if self.achievementScrollBar then
        self.achievementScrollBar:SetShown(showAchievementList)
    end
end

function AchievementsTab:UpdatePreviewToggleButton()
    if not self.previewToggleButton then return end

    local isOpen = addon.Preview and addon.Preview:IsShown()
    self.previewToggleButton:SetShown(not isOpen)
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

addon:RegisterInternalEvent("TAB_CHANGED", function(tabKey)
    if tabKey == "ACHIEVEMENTS" then
        AchievementsTab:Show()
    else
        AchievementsTab:Hide()
    end
end)

addon:RegisterInternalEvent("DATA_LOADED", function()
    if AchievementsTab:IsShown() and not addon.achievementIndexBuilt then
        addon:BuildAchievementIndex()
        addon:BuildAchievementHierarchy()
        AchievementsTab:BuildCategoryDisplay()
        AchievementsTab:BuildAchievementDisplay()
        AchievementsTab:UpdateEmptyStates()
    end
end)

-- Shared handler for events that require rebuilding achievement displays
local function RefreshAchievementDisplays()
    if AchievementsTab:IsShown() then
        AchievementsTab:BuildCategoryDisplay()
        AchievementsTab:BuildAchievementDisplay()
    end
end

addon:RegisterInternalEvent("ACHIEVEMENT_COMPLETION_CHANGED", RefreshAchievementDisplays)

addon:RegisterInternalEvent("PREVIEW_VISIBILITY_CHANGED", function()
    AchievementsTab:UpdatePreviewToggleButton()
end)

addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", RefreshAchievementDisplays)

-- Update wishlist stars when wishlist changes
addon:RegisterInternalEvent("WISHLIST_CHANGED", function(recordID, isWishlisted)
    if AchievementsTab:IsShown() and AchievementsTab.achievementScrollBox then
        AchievementsTab.achievementScrollBox:ForEachFrame(function(frame)
            if frame.recordID == recordID and frame.wishlistStar then
                frame.wishlistStar:SetShown(isWishlisted)
                if isWishlisted then
                    frame.wishlistStar:ClearAllPoints()
                    frame.wishlistStar:SetPoint("LEFT", frame.label, "LEFT", frame.label:GetStringWidth() + 4, 0)
                end
            end
        end)
    end
end)

-- Hook into MainFrame creation
local originalCreateContent = addon.MainFrame.CreateContentArea
addon.MainFrame.CreateContentArea = function(self)
    originalCreateContent(self)
    if self.contentArea then
        AchievementsTab:Create(self.contentArea)
    end
end
