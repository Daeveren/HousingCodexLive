--[[
    Housing Codex - AchievementsTab.lua
    Achievement sources tab with Category > Achievement flat list
]]

local _, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS

-- Layout constants (using centralized values where available)
local CATEGORY_PANEL_WIDTH = CONSTS.HIERARCHY_PANEL_WIDTH
local HIERARCHY_PADDING = CONSTS.HIERARCHY_PADDING
local ROW_HEIGHT = CONSTS.HIERARCHY_ROW_HEIGHT
local WISHLIST_STAR_SIZE = CONSTS.WISHLIST_STAR_SIZE_HIERARCHY
local CATEGORY_BUTTON_HEIGHT = CONSTS.HIERARCHY_HEADER_HEIGHT

-- Category IDs are used for logic, GetCategoryInfo(id) gets localized names for display

-- Forward declarations for named handlers (defined after AchievementsTab singleton)
local AchievementRowOnMouseDown, AchievementRowOnEnter, AchievementRowOnLeave

-- Helper to apply achievement row visual state
local function ApplyAchievementRowState(frame, isSelected)
    addon:ResetBackgroundTexture(frame.bg)
    if isSelected then
        frame.bg:SetColorTexture(unpack(COLORS.ROW_SELECTED))
        frame.selectionBorder:Show()
        frame.label:SetTextColor(unpack(COLORS.GOLD))
    else
        frame.bg:SetColorTexture(unpack(COLORS.ROW_BG))
        frame.selectionBorder:Hide()
        local textBrightness = frame.isComplete and 0.5 or 0.7
        frame.label:SetTextColor(textBrightness, textBrightness, textBrightness, 1)
    end
end

-- Helper to initialize shared achievement row visuals
local function InitializeAchievementRowFrame(frame)
    if frame.bg then return end

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.bg = bg

    -- Selection border
    local border = frame:CreateTexture(nil, "ARTWORK")
    border:SetWidth(3)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMLEFT", 0, 0)
    border:SetColorTexture(unpack(COLORS.GOLD))
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

local function ResetAchievementRowState(frame)
    frame.selectionBorder:Hide()
    frame.checkIcon:Hide()
    frame.incompleteIcon:Hide()
    frame.wishlistStar:Hide()
    frame.achievementID = nil
    frame.recordID = nil
    frame.elementData = nil
end

local function SetupAchievementRow(self, frame, elementData)
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
    addon:SetFontSize(frame.label, 14, "")

    -- Wishlist star
    if frame.wishlistStar and elementData.recordID then
        local isWishlisted = addon:IsWishlisted(elementData.recordID)
        addon.TabBaseMixin:UpdateWishlistStar(frame, isWishlisted)
    end

    -- Progress (collection progress for the achievement's decors)
    local owned, total = addon:GetAchievementCollectionProgress(elementData.achievementID)
    frame.progress:SetText(string.format("%d/%d", owned, total))
    local progressComplete = owned == total and total > 0
    frame.progress:SetTextColor(unpack(progressComplete and COLORS.PROGRESS_COMPLETE or COLORS.TEXT_TERTIARY))

    frame.elementData = elementData
    frame:SetScript("OnMouseDown", AchievementRowOnMouseDown)
    frame:SetScript("OnEnter", AchievementRowOnEnter)
    frame:SetScript("OnLeave", AchievementRowOnLeave)
end
addon.AchievementsTab = {}
local AchievementsTab = addon.AchievementsTab
local VALID_FILTERS = { all = true, incomplete = true, complete = true }

-- Apply shared mixin for common tab functionality
Mixin(AchievementsTab, addon.TabBaseMixin)
AchievementsTab.tabName = "AchievementsTab"

-- Named handlers for achievement rows (bound once, read data from frame fields)
AchievementRowOnMouseDown = function(frame, button)
    local elementData = frame.elementData
    if button == "RightButton" then
        addon.ContextMenu:ShowForAchievement(frame, elementData.achievementID, elementData.recordID)
        return
    end

    if C_ContentTracking and IsShiftKeyDown() and elementData.achievementID then
        local achievementID = elementData.achievementID
        if C_ContentTracking.IsTracking(Enum.ContentTrackingType.Achievement, achievementID) then
            C_ContentTracking.StopTracking(Enum.ContentTrackingType.Achievement, achievementID, Enum.ContentTrackingStopType.Manual)
            addon:Print(addon.L["ACHIEVEMENTS_TRACKING_STOPPED"])
        else
            local err = C_ContentTracking.StartTracking(Enum.ContentTrackingType.Achievement, achievementID)
            addon:PrintTrackingResult(err, "ACHIEVEMENTS_TRACKING_STARTED_ACHIEVEMENT", "ACHIEVEMENTS_TRACKING_FAILED", "ACHIEVEMENTS_TRACKING_MAX_REACHED", "ACHIEVEMENTS_TRACKING_ALREADY")
        end
    elseif C_ContentTracking and IsControlKeyDown() and elementData.recordID then
        local err = C_ContentTracking.StartTracking(Enum.ContentTrackingType.Decor, elementData.recordID)
        addon:PrintTrackingResult(err, "ACHIEVEMENTS_TRACKING_STARTED", "ACHIEVEMENTS_TRACKING_FAILED", "ACHIEVEMENTS_TRACKING_MAX_REACHED", "ACHIEVEMENTS_TRACKING_ALREADY")
    else
        AchievementsTab:SelectAchievement(elementData)
    end
end

AchievementRowOnEnter = function(frame)
    if AchievementsTab.selectedAchievementID ~= frame.achievementID or AchievementsTab.selectedRecordID ~= frame.recordID then
        frame.bg:SetColorTexture(unpack(COLORS.ROW_BG_SOLID))
    end

    local recordID = frame.recordID
    if not recordID then
        local recordIDs = addon:GetRecordsForAchievement(frame.achievementID)
        recordID = recordIDs and recordIDs[1]
    end
    if recordID then
        addon:FireEvent("RECORD_SELECTED", recordID)
    end

    addon:AnchorTooltipToCursor(frame)

    local _, name, _, completed, month, day, year, description = GetAchievementInfo(frame.achievementID)

    local r, g, b = 1, 1, 1
    if completed then r, g, b = 1, 0.82, 0 end
    GameTooltip:AddLine(name, r, g, b)

    if description then
        GameTooltip:AddLine(description, 1, 1, 1, true)
    end

    local numCriteria = GetAchievementNumCriteria(frame.achievementID)
    if numCriteria and numCriteria > 0 then
        GameTooltip:AddLine(" ")
        for i = 1, numCriteria do
            local criteriaString, _, criteriaCompleted, quantity, reqQuantity, _, _, _, quantityString
                = GetAchievementCriteriaInfo(frame.achievementID, i)
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

    if completed and month and day and year then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(ACHIEVEMENT_TOOLTIP_COMPLETE, day, month, year), 0.6, 0.6, 0.6)
    end

    GameTooltip:Show()
end

AchievementRowOnLeave = function(frame)
    GameTooltip:Hide()

    ApplyAchievementRowState(frame, AchievementsTab.selectedAchievementID == frame.achievementID and
        (not frame.recordID or AchievementsTab.selectedRecordID == frame.recordID))

    if AchievementsTab.selectedRecordID then
        addon:FireEvent("RECORD_SELECTED", AchievementsTab.selectedRecordID)
    elseif AchievementsTab.selectedAchievementID then
        local recordIDs = addon:GetRecordsForAchievement(AchievementsTab.selectedAchievementID)
        if recordIDs and recordIDs[1] then
            addon:FireEvent("RECORD_SELECTED", recordIDs[1])
        end
    end
end

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
-- Responsive toolbar state
AchievementsTab.toolbarLayout = nil  -- "full", "noFilter", "minimal"
AchievementsTab.filterContainer = nil  -- Reference for responsive hiding

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
    if addon.dataLoaded and not addon.achievementIndexBuilt then
        addon:BuildAchievementIndex()
        addon:BuildAchievementHierarchy()
    end

    self.frame:Show()

    -- Skip default rebuild when navigating from Progress
    if self.pendingNavigation then
        self.pendingNavigation = nil
        return
    end

    -- Restore saved state
    local saved = GetAchievementsDB()
    if saved then
        self.selectedCategory = saved.selectedCategory
        self.selectedAchievementID = saved.selectedAchievementID
        self.selectedRecordID = saved.selectedRecordID
    end

    -- Always apply completion filter (triggers RefreshDisplay → BuildAchievementDisplay → UpdateEmptyStates)
    self:SetCompletionFilter(saved and saved.completionFilter or "incomplete")
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
    self:CreateStandardToolbar(parent, {
        searchPlaceholderKey = "ACHIEVEMENTS_SEARCH_PLACEHOLDER",
        filterPrefix = "ACHIEVEMENTS",
    })
end

-- Rebuild the category list and, if needed, the achievement list.
-- BuildCategoryDisplay returns true when it already triggered BuildAchievementDisplay
-- internally (via SelectCategory or direct call), so we only call it ourselves
-- when that didn't happen.
function AchievementsTab:RefreshDisplay()
    addon:CountDebug("rebuild", "AchievementsTab")
    if not self:BuildCategoryDisplay() then
        self:BuildAchievementDisplay()
    end
end

function AchievementsTab:SetCompletionFilter(filterKey, skipRefresh)
    if not VALID_FILTERS[filterKey] then filterKey = "incomplete" end
    for key, btn in pairs(self.filterButtons) do
        btn:SetActive(key == filterKey)
    end
    local db = GetAchievementsDB()
    if db then db.completionFilter = filterKey end
    if not skipRefresh then
        self:RefreshDisplay()
    end
end

function AchievementsTab:NavigateFromProgress(categoryId)
    if self.searchBox then
        self.searchBox:SetText("")
    end
    self:SetCompletionFilter("incomplete")
    if categoryId then
        self:SelectCategory(categoryId)
    end
end

function AchievementsTab:GetCompletionFilter()
    local db = GetAchievementsDB()
    return db and db.completionFilter or "incomplete"
end

function AchievementsTab:OnSearchTextChanged(text)
    self:RefreshDisplay()
end

--------------------------------------------------------------------------------
-- Category Panel (Left Column)
--------------------------------------------------------------------------------

function AchievementsTab:CreateCategoryPanel(parent)
    self:CreateHierarchyPanel(parent, {
        panelKey        = "categoryPanel",
        scrollBoxKey    = "categoryScrollBox",
        dataProviderKey = "categoryDataProvider",
        elementExtent   = CATEGORY_BUTTON_HEIGHT,
        setupFn         = function(frame, elementData)
            self:SetupCategoryButton(frame, elementData)
        end,
    })
end

function AchievementsTab:SetupCategoryButton(frame, elementData)
    -- One-time frame setup
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

    frame.categoryId = elementData.categoryId

    local isSelected = self.selectedCategory == elementData.categoryId
    self:ApplySelectionButtonState(frame, isSelected)

    -- Get localized category name from ID
    local categoryName = addon:GetCategoryName(elementData.categoryId) or tostring(elementData.categoryId)
    frame.label:SetText(categoryName)
    addon:SetFontSize(frame.label, 13, "")

    -- Collection progress percentage (items owned / total items)
    local owned, total = addon:GetCategoryCollectionProgress(elementData.categoryId)
    local pctValue = total > 0 and (owned / total * 100) or 0
    frame.percentLabel:SetText(string.format("%.0f%%", pctValue))
    frame.percentLabel:SetTextColor(addon:GetCompletionProgressColor(pctValue))
    addon:SetFontSize(frame.percentLabel, 11, "")

    frame:SetScript("OnClick", function()
        self:SelectCategory(elementData.categoryId)
    end)

    frame:SetScript("OnEnter", function(f)
        if self.selectedCategory ~= f.categoryId then
            f.bg:SetColorTexture(unpack(COLORS.PANEL_HOVER))
        end
    end)

    frame:SetScript("OnLeave", function(f)
        self:ApplySelectionButtonState(f, self.selectedCategory == f.categoryId)
    end)
end

function AchievementsTab:SelectCategory(categoryId)
    local prevSelected = self.selectedCategory
    self.selectedCategory = categoryId

    -- Save to DB
    local db = GetAchievementsDB()
    if db then db.selectedCategory = categoryId end

    -- Update category panel visuals
    if self.categoryScrollBox then
        self.categoryScrollBox:ForEachFrame(function(frame)
            if frame.categoryId then
                self:ApplySelectionButtonState(frame, frame.categoryId == categoryId)
            end
        end)
    end

    -- Clear selection and preview when switching categories (before build so auto-select targets new category)
    if prevSelected ~= categoryId then
        self.selectedAchievementID = nil
        self.selectedRecordID = nil
        if db then
            db.selectedAchievementID = nil
            db.selectedRecordID = nil
        end
        addon:FireEvent("RECORD_SELECTED", nil)
    end

    -- Rebuild achievement panel
    self:BuildAchievementDisplay()
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

    -- Initialize DataProvider once (reused via Flush/InsertTable)
    self.achievementDataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(self.achievementDataProvider)
end

function AchievementsTab:SetupAchievementButton(frame, elementData)
    InitializeAchievementRowFrame(frame)
    ResetAchievementRowState(frame)
    SetupAchievementRow(self, frame, elementData)
end

-- Check if achievement matches search text
local function AchievementMatchesSearch(achievementID, searchText, categoryId)
    if searchText == "" then return true end

    -- Check achievement name
    local name = addon:GetAchievementName(achievementID) or ""
    if strlower(name):find(searchText, 1, true) then return true end

    -- Check category name (get localized name from ID)
    local categoryName = addon:GetCategoryName(categoryId) or ""
    if strlower(categoryName):find(searchText, 1, true) then return true end

    -- Check decor reward names
    local records = addon:GetRecordsForAchievement(achievementID)
    for _, recordID in ipairs(records or {}) do
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

    -- "incomplete" or any other value defaults to showing incomplete
    return not isComplete
end

function AchievementsTab:BuildCategoryDisplay()
    if not self.categoryScrollBox or not self.categoryDataProvider then return false end

    local elements = {}
    local filter = self:GetCompletionFilter()
    local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

    for _, categoryId in ipairs(addon:GetSortedAchievementCategories()) do
        local hasVisibleContent = false
        for _, achievementID in ipairs(addon:GetAchievementsForCategory(categoryId)) do
            if AchievementPassesCompletionFilter(achievementID, filter)
                and AchievementMatchesSearch(achievementID, searchText, categoryId) then
                hasVisibleContent = true
                break
            end
        end
        if hasVisibleContent then
            table.insert(elements, { categoryId = categoryId })
        end
    end

    -- Reuse DataProvider: Flush and insert new elements
    self.categoryDataProvider:Flush()
    if #elements > 0 then
        self.categoryDataProvider:InsertTable(elements)
    end

    -- Build lookup for visible categories
    local visibleCategories = {}
    for _, elem in ipairs(elements) do
        visibleCategories[elem.categoryId] = true
    end

    -- Auto-select first category if none selected or current selection is no longer visible
    -- Returns true when this function already triggered BuildAchievementDisplay internally
    if not self.selectedCategory and #elements > 0 then
        self:SelectCategory(elements[1].categoryId)
        return true
    elseif self.selectedCategory and not visibleCategories[self.selectedCategory] then
        if #elements > 0 then
            self:SelectCategory(elements[1].categoryId)
            return true
        else
            self.selectedCategory = nil
            self.selectedAchievementID = nil
            self.selectedRecordID = nil
            local db = GetAchievementsDB()
            if db then
                db.selectedCategory = nil
                db.selectedAchievementID = nil
                db.selectedRecordID = nil
            end
            addon:FireEvent("RECORD_SELECTED", nil)
            self:BuildAchievementDisplay()
            return true
        end
    end
    return false
end

function AchievementsTab:BuildAchievementDisplay()
    if not self.achievementScrollBox or not self.achievementDataProvider then return end

    local elements = {}
    local categoryId = self.selectedCategory

    if categoryId then
        local filter = self:GetCompletionFilter()
        local searchText = strlower(strtrim(self.searchBox and self.searchBox:GetText() or ""))

        for _, achievementID in ipairs(addon:GetAchievementsForCategory(categoryId)) do
            if AchievementPassesCompletionFilter(achievementID, filter)
                and AchievementMatchesSearch(achievementID, searchText, categoryId) then
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

    -- Reuse DataProvider: Flush and insert new elements
    self.achievementDataProvider:Flush()
    if #elements > 0 then
        self.achievementDataProvider:InsertTable(elements)
    end

    -- Reconcile selection: if selected achievement is no longer visible, auto-select first or clear
    if self.selectedAchievementID then
        local found = false
        for _, elem in ipairs(elements) do
            if elem.achievementID == self.selectedAchievementID
                and (not self.selectedRecordID or elem.recordID == self.selectedRecordID) then
                found = true
                break
            end
        end
        if not found then
            if #elements > 0 then
                self:SelectAchievement(elements[1])
            else
                self.selectedAchievementID = nil
                self.selectedRecordID = nil
                local db = GetAchievementsDB()
                if db then
                    db.selectedAchievementID = nil
                    db.selectedRecordID = nil
                end
                addon:FireEvent("RECORD_SELECTED", nil)
            end
        end
    end

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
    self.emptyState = addon:CreateEmptyStateFrame(
        self.categoryPanel,
        "ACHIEVEMENTS_EMPTY_NO_SOURCES",
        "ACHIEVEMENTS_EMPTY_NO_SOURCES_DESC",
        CATEGORY_PANEL_WIDTH - 16
    )

    -- "Select a category" state
    self.noCategoryState = addon:CreateEmptyStateFrame(self.achievementPanel, "ACHIEVEMENTS_SELECT_CATEGORY")

    -- No search results state
    self.noResultsState = addon:CreateEmptyStateFrame(self.achievementPanel, "ACHIEVEMENTS_EMPTY_NO_RESULTS")
end

function AchievementsTab:UpdateEmptyStates()
    local hasAchievements = addon:GetAchievementCount() > 0
    local categoryResults = self.categoryDataProvider and self.categoryDataProvider:GetSize() or 0
    local hasVisibleCategories = categoryResults > 0
    local hasCategory = self.selectedCategory ~= nil
    local achievementDataProvider = self.achievementScrollBox and self.achievementScrollBox:GetDataProvider()
    local achievementResults = achievementDataProvider and achievementDataProvider:GetSize() or 0
    local showAchievementList = hasAchievements and hasVisibleCategories and hasCategory and achievementResults > 0
    local showNoResults = hasAchievements and ((not hasVisibleCategories) or (hasCategory and achievementResults == 0))
    local showNoCategory = hasAchievements and hasVisibleCategories and not hasCategory and not showNoResults

    if self.emptyState then self.emptyState:SetShown(not hasAchievements) end
    if self.noCategoryState then self.noCategoryState:SetShown(showNoCategory) end
    if self.noResultsState then self.noResultsState:SetShown(showNoResults) end
    if self.categoryScrollBox then self.categoryScrollBox:SetShown(hasAchievements and hasVisibleCategories) end
    if self.achievementScrollBox then self.achievementScrollBox:SetShown(showAchievementList) end
    if self.achievementScrollBar then self.achievementScrollBar:SetShown(showAchievementList) end

    if showNoResults then
        addon:FireEvent("RECORD_SELECTED", nil)
    end
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

AchievementsTab:RegisterTabVisibility("ACHIEVEMENTS")

addon:RegisterInternalEvent("DATA_LOADED", function()
    -- Always build index on DATA_LOADED (DecorToAchievementLookup needed by VendorMapIndex)
    addon:BuildAchievementIndex()
    if AchievementsTab:IsShown() then
        addon:BuildAchievementHierarchy()
        AchievementsTab:RefreshDisplay()
    end
end)

-- Shared handler for events that require rebuilding achievement displays
local function RefreshAchievementDisplays()
    if AchievementsTab:IsShown() then
        AchievementsTab:RefreshDisplay()
    end
end

addon:RegisterInternalEvent("ACHIEVEMENT_COMPLETION_CHANGED", RefreshAchievementDisplays)

AchievementsTab:RegisterOwnershipRefresh(RefreshAchievementDisplays)

-- Update wishlist stars when wishlist changes
addon:RegisterInternalEvent("WISHLIST_CHANGED", function(recordID, isWishlisted)
    if AchievementsTab:IsShown() and AchievementsTab.achievementScrollBox then
        AchievementsTab.achievementScrollBox:ForEachFrame(function(frame)
            if frame.recordID == recordID and frame.wishlistStar then
                addon.TabBaseMixin:UpdateWishlistStar(frame, isWishlisted)
            end
        end)
    end
end)

addon.MainFrame:RegisterContentAreaInitializer("AchievementsTab", function(contentArea)
    AchievementsTab:Create(contentArea)
end)
