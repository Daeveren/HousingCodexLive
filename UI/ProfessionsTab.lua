--[[
    Housing Codex - ProfessionsTab.lua
    Crafting sources tab with Profession > Item layout.
]]

local ADDON_NAME, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS
local ICON_CROP_COORDS = CONSTS.ICON_CROP_COORDS

local TOOLBAR_HEIGHT = CONSTS.HEADER_HEIGHT
local SIDEBAR_WIDTH = CONSTS.SIDEBAR_WIDTH
local PROFESSION_PANEL_WIDTH = CONSTS.HIERARCHY_PANEL_WIDTH
local HIERARCHY_PADDING = CONSTS.HIERARCHY_PADDING
local HEADER_HEIGHT = CONSTS.HIERARCHY_HEADER_HEIGHT
local GRID_OUTER_PAD = CONSTS.GRID_OUTER_PAD

local DECOR_ROW_HEIGHT = 24
local DECOR_ICON_SIZE = 22
local ROW_TEXT_BRIGHTNESS_COLLECTED = 0.4
local ROW_TEXT_BRIGHTNESS_UNCOLLECTED = 0.7

local KNOWN_PROFESSIONS = {
    alchemy = true,
    blacksmithing = true,
    enchanting = true,
    engineering = true,
    inscription = true,
    jewelcrafting = true,
    leatherworking = true,
    tailoring = true,
    cooking = true,
}

local function ApplyProfessionButtonState(frame, isSelected)
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

local function NormalizeSkillLine(skillLine)
    if type(skillLine) ~= "string" then return nil end
    local trimmed = strtrim(skillLine)
    if trimmed == "" then return nil end

    local normalized = trimmed:gsub("%s+", " ")
    local lastToken = normalized:match("(%S+)$")
    if lastToken and KNOWN_PROFESSIONS[strlower(lastToken)] then
        return normalized
    end

    return trimmed
end

local function BuildSkillText(craft)
    local line = NormalizeSkillLine(craft.skillLine)
    if line then
        if type(craft.skillNeeded) == "number" then
            return string.format("%s (%d)", line, craft.skillNeeded)
        end
        return line
    end
    return craft.professionName or addon.L["UNKNOWN"]
end

local function ResolveCraftRecord(decorId)
    return addon:GetRecord(decorId) or addon:ResolveRecord(decorId)
end

local function GetSearchText(searchBox)
    return strlower(strtrim(searchBox and searchBox:GetText() or ""))
end

local function CraftMatchesSearch(craft, searchText)
    if searchText == "" then return true end

    local record = ResolveCraftRecord(craft.decorId)
    local decorName = addon:ResolveDecorName(craft.decorId, record)
    if decorName and strlower(decorName):find(searchText, 1, true) then
        return true
    end

    if craft.recipeName and strlower(craft.recipeName):find(searchText, 1, true) then
        return true
    end

    if craft.professionName and strlower(craft.professionName):find(searchText, 1, true) then
        return true
    end

    local skillText = BuildSkillText(craft)
    if skillText and strlower(skillText):find(searchText, 1, true) then
        return true
    end

    return false
end

local function CraftPassesCompletionFilter(craft, filter)
    if filter == "all" then return true end

    local record = ResolveCraftRecord(craft.decorId)
    local isCollected = record and record.isCollected or false
    if filter == "complete" then return isCollected end
    if filter == "incomplete" then return not isCollected end
    return true
end

local function CraftMatchesActiveFilters(craft, filter, searchText)
    return CraftPassesCompletionFilter(craft, filter) and CraftMatchesSearch(craft, searchText)
end

addon.ProfessionsTab = {}
local ProfessionsTab = addon.ProfessionsTab

Mixin(ProfessionsTab, addon.TabBaseMixin)
ProfessionsTab.tabName = "ProfessionsTab"

local function GetProfessionsDB()
    return addon.db and addon.db.browser and addon.db.browser.professions
end

local function EnsureProfessionsDB()
    if not addon.db then return nil end
    addon.db.browser = addon.db.browser or {}
    addon.db.browser.professions = addon.db.browser.professions or {
        completionFilter = "incomplete",
    }
    return addon.db.browser.professions
end

ProfessionsTab.frame = nil
ProfessionsTab.toolbar = nil
ProfessionsTab.professionPanel = nil
ProfessionsTab.professionScrollBox = nil
ProfessionsTab.craftPanel = nil
ProfessionsTab.craftScrollBox = nil
ProfessionsTab.craftScrollBar = nil
ProfessionsTab.searchBox = nil
ProfessionsTab.filterButtons = {}
ProfessionsTab.emptyState = nil
ProfessionsTab.noProfessionState = nil
ProfessionsTab.noResultsState = nil

ProfessionsTab.selectedProfession = nil
ProfessionsTab.selectedDecorId = nil
ProfessionsTab.hoveringRecordID = nil

ProfessionsTab.toolbarLayout = nil
ProfessionsTab.filterContainer = nil

--------------------------------------------------------------------------------
-- Main Frame
--------------------------------------------------------------------------------

function ProfessionsTab:Create(parent)
    if self.frame then return end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()
    self.frame = frame

    self:CreateToolbar(frame)
    self:CreateProfessionPanel(frame)
    self:CreateCraftPanel(frame)
    self:CreateEmptyStates()

    addon:Debug("ProfessionsTab created")
end

function ProfessionsTab:Show()
    if not self.frame then return end

    if not addon.craftingIndexBuilt then
        addon:BuildCraftingIndex()
    end

    self.frame:Show()
    local db = EnsureProfessionsDB()

    -- Restore persisted profession; reset craft selection each session
    self.selectedProfession = db and db.selectedProfession
    self.selectedDecorId = nil

    self:SetCompletionFilter((db and db.completionFilter) or "incomplete")
    self:UpdateEmptyStates()
end

function ProfessionsTab:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function ProfessionsTab:IsShown()
    return self.frame and self.frame:IsShown()
end

--------------------------------------------------------------------------------
-- Toolbar
--------------------------------------------------------------------------------

function ProfessionsTab:CreateToolbar(parent)
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
    searchBox.Instructions:SetText(L["PROFESSIONS_SEARCH_PLACEHOLDER"])
    self.searchBox = searchBox

    local searchDebounceTimer
    searchBox:HookScript("OnTextChanged", function(box, userInput)
        if userInput then
            if searchDebounceTimer then searchDebounceTimer:Cancel() end
            local text = box:GetText()
            searchDebounceTimer = C_Timer.NewTimer(CONSTS.TIMER.INPUT_DEBOUNCE, function()
                searchDebounceTimer = nil
                self:OnSearchTextChanged(text)
            end)
        end
    end)

    if searchBox.clearButton then
        searchBox.clearButton:HookScript("OnClick", function()
            if searchDebounceTimer then searchDebounceTimer:Cancel(); searchDebounceTimer = nil end
            self:OnSearchTextChanged("")
        end)
    end

    searchBox:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    searchBox:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)

    local filterContainer = CreateFrame("Frame", nil, toolbar)
    filterContainer:SetPoint("LEFT", searchBox, "RIGHT", 16, 0)
    filterContainer:SetHeight(22)
    self.filterContainer = filterContainer

    local filters = {
        { key = "all", label = L["PROFESSIONS_FILTER_ALL"] },
        { key = "incomplete", label = L["PROFESSIONS_FILTER_INCOMPLETE"] },
        { key = "complete", label = L["PROFESSIONS_FILTER_COMPLETE"] },
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

function ProfessionsTab:SetCompletionFilter(filterKey)
    for key, btn in pairs(self.filterButtons) do
        btn:SetActive(key == filterKey)
    end
    local db = GetProfessionsDB()
    if db then db.completionFilter = filterKey end
    self:RefreshDisplay()
end

function ProfessionsTab:GetCompletionFilter()
    local db = GetProfessionsDB()
    return db and db.completionFilter or "incomplete"
end

function ProfessionsTab:OnSearchTextChanged(text)
    self:RefreshDisplay()
end

--------------------------------------------------------------------------------
-- Profession Panel (Left Column)
--------------------------------------------------------------------------------

function ProfessionsTab:CreateProfessionPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", self.toolbar, "BOTTOMLEFT", -SIDEBAR_WIDTH, 0)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -SIDEBAR_WIDTH, 0)
    panel:SetWidth(PROFESSION_PANEL_WIDTH)
    self.professionPanel = panel

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
    self.professionScrollBox = scrollBox

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(HEADER_HEIGHT)
    view:SetPadding(0, 0, 0, 0, 4)
    view:SetElementInitializer("Button", function(frame, elementData)
        self:SetupProfessionButton(frame, elementData)
    end)

    scrollBox:Init(view)
    self.professionDataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(self.professionDataProvider)
end

function ProfessionsTab:SetupProfessionButton(frame, elementData)
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

        local progress = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        progress:SetPoint("RIGHT", -8, 0)
        progress:SetJustifyH("RIGHT")
        frame.progressLabel = progress

        local label = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", 10, 0)
        label:SetPoint("RIGHT", progress, "LEFT", -4, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        frame.label = label

        frame:EnableMouse(true)
    end

    frame.selectionBorder:Hide()
    frame.professionName = elementData.professionName

    local isSelected = self.selectedProfession == elementData.professionName
    ApplyProfessionButtonState(frame, isSelected)

    frame.label:SetText(elementData.professionName)
    addon:SetFontSize(frame.label, 13, "")

    local owned, total = addon:GetCraftingProgress(elementData.professionName)
    local pctValue = total > 0 and (owned / total * 100) or 0
    frame.progressLabel:SetText(string.format("%d/%d", owned, total))
    frame.progressLabel:SetTextColor(unpack(self:GetProgressColor(pctValue)))
    addon:SetFontSize(frame.progressLabel, 11, "")

    frame:SetScript("OnClick", function()
        self:SelectProfession(elementData.professionName)
    end)

    frame:SetScript("OnEnter", function(f)
        if self.selectedProfession ~= f.professionName then
            f.bg:SetColorTexture(unpack(COLORS.PANEL_HOVER))
        end
    end)

    frame:SetScript("OnLeave", function(f)
        ApplyProfessionButtonState(f, self.selectedProfession == f.professionName)
    end)
end

function ProfessionsTab:SelectProfession(professionName)
    local prevSelected = self.selectedProfession
    if prevSelected ~= professionName then
        self.selectedDecorId = nil
        addon:FireEvent("RECORD_SELECTED", nil)
    end

    self.selectedProfession = professionName

    local db = GetProfessionsDB()
    if db then db.selectedProfession = professionName end

    if self.professionScrollBox then
        self.professionScrollBox:ForEachFrame(function(frame)
            if frame.professionName then
                ApplyProfessionButtonState(frame, frame.professionName == professionName)
            end
        end)
    end

    self:BuildCraftDisplay()
    self:UpdateEmptyStates()
end

--------------------------------------------------------------------------------
-- Craft Panel (Right Side)
--------------------------------------------------------------------------------

function ProfessionsTab:CreateCraftPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", self.professionPanel, "TOPRIGHT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.craftPanel = panel

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.06, 0.98)

    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", HIERARCHY_PADDING, -HIERARCHY_PADDING)
    scrollContainer:SetPoint("BOTTOMRIGHT", -HIERARCHY_PADDING - 16, HIERARCHY_PADDING)

    local scrollBox = CreateFrame("Frame", nil, scrollContainer, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    self.craftScrollBox = scrollBox

    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollContainer, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollContainer, "BOTTOMRIGHT", 4, 0)
    self.craftScrollBar = scrollBar

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(DECOR_ROW_HEIGHT)
    view:SetElementInitializer("Button", function(frame, elementData)
        self:SetupCraftRow(frame, elementData)
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    self.craftView = view

    self.craftDataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(self.craftDataProvider)
end

function ProfessionsTab:UpdateCraftRowSelectionVisual(frame, isSelected, textBrightness)
    if not frame then return end
    frame.selectionBorder:SetShown(isSelected)
    local shade = isSelected and 0.14 or 0.08
    local blue = isSelected and 0.16 or 0.10
    local alpha = isSelected and 1 or 0.9
    frame.bg:SetColorTexture(shade, shade, blue, alpha)
    if isSelected then
        frame.name:SetTextColor(1, 0.82, 0, 1)
    else
        frame.name:SetTextColor(textBrightness, textBrightness, textBrightness, 1)
    end
end

function ProfessionsTab:HandleCraftSelection(frame, decorId)
    if self.selectedDecorId == decorId then
        self.selectedDecorId = nil
        self:UpdateCraftRowSelectionVisual(frame, false, frame.textBrightness or ROW_TEXT_BRIGHTNESS_UNCOLLECTED)
        addon:FireEvent("RECORD_SELECTED", nil)
        return
    end

    if self.selectedDecorId and self.craftScrollBox then
        self.craftScrollBox:ForEachFrame(function(f)
            if f.decorId == self.selectedDecorId then
                self:UpdateCraftRowSelectionVisual(f, false, f.textBrightness or ROW_TEXT_BRIGHTNESS_UNCOLLECTED)
            end
        end)
    end

    self.selectedDecorId = decorId
    self:UpdateCraftRowSelectionVisual(frame, true, frame.textBrightness or ROW_TEXT_BRIGHTNESS_UNCOLLECTED)
    addon:FireEvent("RECORD_SELECTED", decorId)
end

function ProfessionsTab:SetupCraftRow(frame, craft)
    local L = addon.L

    if not frame.bg then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        frame.bg = bg

        local selectionBorder = frame:CreateTexture(nil, "ARTWORK")
        selectionBorder:SetWidth(2)
        selectionBorder:SetPoint("TOPLEFT", 0, 0)
        selectionBorder:SetPoint("BOTTOMLEFT", 0, 0)
        selectionBorder:SetColorTexture(1, 0.82, 0, 1)
        selectionBorder:Hide()
        frame.selectionBorder = selectionBorder

        local checkIcon = frame:CreateTexture(nil, "OVERLAY")
        checkIcon:SetSize(14, 14)
        checkIcon:SetPoint("LEFT", 4, 0)
        checkIcon:SetAtlas("common-icon-checkmark")
        checkIcon:SetVertexColor(0.4, 0.9, 0.4, 1)
        checkIcon:Hide()
        frame.checkIcon = checkIcon

        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(DECOR_ICON_SIZE, DECOR_ICON_SIZE)
        icon:SetPoint("LEFT", 20, 0)
        frame.icon = icon

        local skillText = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        skillText:SetPoint("RIGHT", -8, 0)
        skillText:SetJustifyH("RIGHT")
        skillText:SetWordWrap(false)
        frame.skillText = skillText

        local name = addon:CreateFontString(frame, "OVERLAY", "GameFontNormal")
        name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        name:SetPoint("RIGHT", skillText, "LEFT", -10, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        frame.name = name

        frame:EnableMouse(true)
    end

    frame.decorId = craft.decorId
    frame.craftData = craft

    local record = ResolveCraftRecord(craft.decorId)
    local isCollected = record and record.isCollected

    if record then
        if record.iconType == "atlas" then
            frame.icon:SetAtlas(record.icon)
            frame.icon:SetTexCoord(0, 1, 0, 1)
        else
            frame.icon:SetTexture(record.icon)
            frame.icon:SetTexCoord(unpack(ICON_CROP_COORDS))
        end
    else
        frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        frame.icon:SetTexCoord(unpack(ICON_CROP_COORDS))
    end

    frame.checkIcon:SetShown(isCollected)

    local textBrightness = isCollected and ROW_TEXT_BRIGHTNESS_COLLECTED or ROW_TEXT_BRIGHTNESS_UNCOLLECTED
    frame.textBrightness = textBrightness
    frame.name:SetText(addon:ResolveDecorName(craft.decorId, record))
    addon:SetFontSize(frame.name, 13, "")

    frame.skillText:SetText(BuildSkillText(craft))
    frame.skillText:SetTextColor(0.58, 0.58, 0.58, 1)
    addon:SetFontSize(frame.skillText, 11, "")

    self:UpdateCraftRowSelectionVisual(frame, self.selectedDecorId == craft.decorId, textBrightness)

    frame:SetScript("OnMouseDown", function(f, button)
        if button == "RightButton" then
            addon.ContextMenu:ShowForDecor(f, craft.decorId)
            return
        end

        if IsShiftKeyDown() then
            addon:ToggleTracking(craft.decorId)
            return
        end

        self:HandleCraftSelection(f, craft.decorId)
    end)

    frame:SetScript("OnEnter", function(f)
        if self.selectedDecorId ~= craft.decorId then
            f.name:SetTextColor(1, 1, 1, 1)
        end

        self.hoveringRecordID = craft.decorId
        addon:FireEvent("RECORD_SELECTED", craft.decorId)

        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (x / scale) + 15, (y / scale) + 15)
        GameTooltip:SetText(addon:ResolveDecorName(craft.decorId, record), 1, 1, 1)
        if isCollected then
            GameTooltip:AddLine(L["FILTER_COLLECTED"], 0.4, 0.9, 0.4)
        end
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function(f)
        if self.selectedDecorId ~= craft.decorId then
            f.name:SetTextColor(f.textBrightness, f.textBrightness, f.textBrightness, 1)
        end
        GameTooltip:Hide()
        self.hoveringRecordID = nil
        addon:FireEvent("RECORD_SELECTED", self.selectedDecorId)
    end)
end

--------------------------------------------------------------------------------
-- Display Building
--------------------------------------------------------------------------------

local function FindProfessionInList(elements, professionName)
    for _, elem in ipairs(elements) do
        if elem.professionName == professionName then return true end
    end
    return false
end

local function FindCraftInList(elements, decorId)
    for _, elem in ipairs(elements) do
        if elem.decorId == decorId then return true end
    end
    return false
end

function ProfessionsTab:BuildProfessionDisplay()
    if not self.professionScrollBox or not self.professionDataProvider then return false end

    local professionElements = {}
    local filter = self:GetCompletionFilter()
    local searchText = GetSearchText(self.searchBox)

    for _, professionInfo in ipairs(addon:GetSortedProfessions()) do
        local professionName = professionInfo.name
        local hasVisibleContent = false
        for _, craft in ipairs(addon:GetCraftsForProfession(professionName)) do
            if CraftMatchesActiveFilters(craft, filter, searchText) then
                hasVisibleContent = true
                break
            end
        end
        if hasVisibleContent then
            table.insert(professionElements, { professionName = professionName })
        end
    end

    self.professionDataProvider:Flush()
    if #professionElements > 0 then
        self.professionDataProvider:InsertTable(professionElements)
    end

    -- Keep selection when still visible; otherwise auto-select first visible profession.
    local firstProfession = professionElements[1] and professionElements[1].professionName
    if not self.selectedProfession and firstProfession then
        self:SelectProfession(firstProfession)
        return true
    end

    if self.selectedProfession and not FindProfessionInList(professionElements, self.selectedProfession) then
        if firstProfession then
            self:SelectProfession(firstProfession)
            return true
        end

        self.selectedProfession = nil
        self.selectedDecorId = nil
        addon:FireEvent("RECORD_SELECTED", nil)
        self:BuildCraftDisplay()
        return true
    end

    return false
end

function ProfessionsTab:BuildCraftDisplay()
    if not self.craftScrollBox or not self.craftDataProvider then return end

    local craftElements = {}
    local professionName = self.selectedProfession

    if professionName then
        local filter = self:GetCompletionFilter()
        local searchText = GetSearchText(self.searchBox)

        for _, craft in ipairs(addon:GetCraftsForProfession(professionName)) do
            if CraftMatchesActiveFilters(craft, filter, searchText) then
                table.insert(craftElements, craft)
            end
        end
    end

    self.craftDataProvider:Flush()
    if #craftElements > 0 then
        self.craftDataProvider:InsertTable(craftElements)
    end

    if self.selectedDecorId and not FindCraftInList(craftElements, self.selectedDecorId) then
        self.selectedDecorId = nil
        addon:FireEvent("RECORD_SELECTED", nil)
    end

    self:UpdateEmptyStates()
end

function ProfessionsTab:RefreshDisplay()
    addon:CountDebug("rebuild", "ProfessionsTab")
    if not self:BuildProfessionDisplay() then
        self:BuildCraftDisplay()
    end
end

--------------------------------------------------------------------------------
-- Empty States
--------------------------------------------------------------------------------

function ProfessionsTab:CreateEmptyStates()
    self.emptyState = addon:CreateEmptyStateFrame(
        self.professionPanel,
        "PROFESSIONS_EMPTY_NO_SOURCES",
        "PROFESSIONS_EMPTY_NO_SOURCES_DESC",
        PROFESSION_PANEL_WIDTH - 16
    )
    self.noProfessionState = addon:CreateEmptyStateFrame(self.craftPanel, "PROFESSIONS_SELECT_PROFESSION")
    self.noResultsState = addon:CreateEmptyStateFrame(self.craftPanel, "PROFESSIONS_EMPTY_NO_RESULTS")
end

function ProfessionsTab:UpdateEmptyStates()
    local hasSources = addon:GetCraftingCount() > 0
    local professionResults = self.professionDataProvider and self.professionDataProvider:GetSize() or 0
    local craftResults = self.craftDataProvider and self.craftDataProvider:GetSize() or 0
    local hasVisibleProfessions = professionResults > 0
    local hasSelection = self.selectedProfession ~= nil
    local showCraftList = hasSources and hasVisibleProfessions and hasSelection and craftResults > 0
    local showNoResults = hasSources and ((not hasVisibleProfessions) or (hasSelection and craftResults == 0))
    local showNoProfession = hasSources and hasVisibleProfessions and not hasSelection and not showNoResults

    if self.emptyState then self.emptyState:SetShown(not hasSources) end
    if self.noProfessionState then self.noProfessionState:SetShown(showNoProfession) end
    if self.noResultsState then self.noResultsState:SetShown(showNoResults) end
    if self.professionScrollBox then self.professionScrollBox:SetShown(hasSources and hasVisibleProfessions) end
    if self.craftScrollBox then self.craftScrollBox:SetShown(showCraftList) end
    if self.craftScrollBar then self.craftScrollBar:SetShown(showCraftList) end
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

addon:RegisterInternalEvent("TAB_CHANGED", function(tabKey)
    if tabKey == "PROFESSIONS" then
        ProfessionsTab:Show()
    else
        ProfessionsTab:Hide()
    end
end)

addon:RegisterInternalEvent("DATA_LOADED", function()
    if ProfessionsTab:IsShown() then
        addon:BuildCraftingIndex()
        ProfessionsTab:RefreshDisplay()
    end
end)

ProfessionsTab:RegisterOwnershipRefresh(function() ProfessionsTab:RefreshDisplay() end)

addon.MainFrame:RegisterContentAreaInitializer("ProfessionsTab", function(contentArea)
    ProfessionsTab:Create(contentArea)
end)
