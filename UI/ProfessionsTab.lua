--[[
    Housing Codex - ProfessionsTab.lua
    Crafting sources tab with Profession > Item layout.
]]

local _, addon = ...

local CONSTS = addon.CONSTANTS
local COLORS = CONSTS.COLORS
local ICON_CROP_COORDS = CONSTS.ICON_CROP_COORDS

local PROFESSION_PANEL_WIDTH = CONSTS.HIERARCHY_PANEL_WIDTH
local HIERARCHY_PADDING = CONSTS.HIERARCHY_PADDING
local HEADER_HEIGHT = CONSTS.HIERARCHY_HEADER_HEIGHT

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
        local localized = addon:GetLocalizedSkillLine(line)
        if type(craft.skillNeeded) == "number" then
            return string.format("%s (%d)", localized, craft.skillNeeded)
        end
        return localized
    end
    return addon:GetLocalizedProfessionName(craft.professionName) or addon.L["UNKNOWN"]
end

local function ResolveCraftRecord(decorId)
    return addon:GetRecord(decorId) or addon:ResolveRecord(decorId)
end

local function GetSearchText(searchBox)
    return strlower(strtrim(searchBox and searchBox:GetText() or ""))
end

local function CraftMatchesSearch(craft, searchText, record)
    if searchText == "" then return true end

    record = record or ResolveCraftRecord(craft.decorId)
    local decorName = addon:ResolveDecorName(craft.decorId, record)
    if decorName and strlower(decorName):find(searchText, 1, true) then
        return true
    end

    if craft.professionName then
        if strlower(craft.professionName):find(searchText, 1, true) then
            return true
        end
        local localizedName = addon:GetLocalizedProfessionName(craft.professionName)
        if localizedName ~= craft.professionName and strlower(localizedName):find(searchText, 1, true) then
            return true
        end
    end

    local skillText = BuildSkillText(craft)
    if skillText and strlower(skillText):find(searchText, 1, true) then
        return true
    end

    return false
end

local function CraftPassesCompletionFilter(craft, filter, record)
    if filter == "all" then return true end

    record = record or ResolveCraftRecord(craft.decorId)
    local isCollected = record and record.isCollected or false
    if filter == "complete" then return isCollected end
    if filter == "incomplete" then return not isCollected end
    return true
end

local function CraftMatchesActiveFilters(craft, filter, searchText)
    local record = ResolveCraftRecord(craft.decorId)
    return CraftPassesCompletionFilter(craft, filter, record) and CraftMatchesSearch(craft, searchText, record)
end

-- Evaluate craft visibility once per refresh; two-level table avoids string allocation per entry
local function BuildCraftVisibilityCache(filter, searchText)
    local cache = {}
    for _, professionInfo in ipairs(addon:GetSortedProfessions()) do
        local professionName = professionInfo.name
        local profCache = {}
        for _, craft in ipairs(addon:GetCraftsForProfession(professionName)) do
            if CraftMatchesActiveFilters(craft, filter, searchText) then
                profCache[craft.decorId] = true
            end
        end
        cache[professionName] = profCache
    end
    return cache
end

local function IsCraftVisible(craft, professionName, filter, searchText, visCache)
    if visCache then
        local profCache = visCache[professionName]
        return profCache and profCache[craft.decorId] or false
    end
    return CraftMatchesActiveFilters(craft, filter, searchText)
end

addon.ProfessionsTab = {}
local ProfessionsTab = addon.ProfessionsTab
local VALID_FILTERS = { all = true, incomplete = true, complete = true }

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

    if addon.dataLoaded and not addon.craftingIndexBuilt then
        addon:BuildCraftingIndex()
    end

    self.frame:Show()

    -- Skip default rebuild when navigating from Progress
    if self.pendingNavigation then
        self.pendingNavigation = nil
        return
    end

    local db = EnsureProfessionsDB()

    -- Restore persisted profession
    self.selectedProfession = db and db.selectedProfession

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
    self:CreateStandardToolbar(parent, {
        searchPlaceholderKey = "PROFESSIONS_SEARCH_PLACEHOLDER",
        filterPrefix = "PROFESSIONS",
    })
end

function ProfessionsTab:SetCompletionFilter(filterKey, skipRefresh)
    if not VALID_FILTERS[filterKey] then filterKey = "incomplete" end
    for key, btn in pairs(self.filterButtons) do
        btn:SetActive(key == filterKey)
    end
    local db = GetProfessionsDB()
    if db then db.completionFilter = filterKey end
    if not skipRefresh then
        self:RefreshDisplay()
    end
end

function ProfessionsTab:GetCompletionFilter()
    local db = GetProfessionsDB()
    return db and db.completionFilter or "incomplete"
end

function ProfessionsTab:OnSearchTextChanged(_)
    self:RefreshDisplay()
end

--------------------------------------------------------------------------------
-- Profession Panel (Left Column)
--------------------------------------------------------------------------------

function ProfessionsTab:CreateProfessionPanel(parent)
    self:CreateHierarchyPanel(parent, {
        panelKey        = "professionPanel",
        scrollBoxKey    = "professionScrollBox",
        dataProviderKey = "professionDataProvider",
        elementExtent   = HEADER_HEIGHT,
        setupFn         = function(frame, elementData)
            self:SetupProfessionButton(frame, elementData)
        end,
    })
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

    frame.professionName = elementData.professionName

    local isSelected = self.selectedProfession == elementData.professionName
    self:ApplySelectionButtonState(frame, isSelected)

    frame.label:SetText(addon:GetLocalizedProfessionName(elementData.professionName))
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
        self:ApplySelectionButtonState(f, self.selectedProfession == f.professionName)
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
                self:ApplySelectionButtonState(frame, frame.professionName == professionName)
            end
        end)
    end

    self:BuildCraftDisplay()
end

function ProfessionsTab:NavigateFromProgress(professionName)
    if self.searchBox then
        self.searchBox:SetText("")
    end
    self:SetCompletionFilter("incomplete", true)
    self:BuildProfessionDisplay()
    if not professionName then
        professionName = addon.craftingHierarchy and addon.craftingHierarchy[1]
    end
    if professionName then self:SelectProfession(professionName) end
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
        frame.name:SetTextColor(unpack(COLORS.GOLD))
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
        selectionBorder:SetColorTexture(unpack(COLORS.GOLD))
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

        addon:FireEvent("RECORD_SELECTED", craft.decorId)

        addon:AnchorTooltipToCursor(f)
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

function ProfessionsTab:BuildProfessionDisplay(visCache)
    if not self.professionScrollBox or not self.professionDataProvider then return false end

    local professionElements = {}
    local filter = self:GetCompletionFilter()
    local searchText = GetSearchText(self.searchBox)

    for _, professionInfo in ipairs(addon:GetSortedProfessions()) do
        local professionName = professionInfo.name
        local hasVisibleContent = false
        for _, craft in ipairs(addon:GetCraftsForProfession(professionName)) do
            if IsCraftVisible(craft, professionName, filter, searchText, visCache) then
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

function ProfessionsTab:BuildCraftDisplay(visCache)
    if not self.craftScrollBox or not self.craftDataProvider then return end

    local craftElements = {}
    local professionName = self.selectedProfession

    if professionName then
        local filter = self:GetCompletionFilter()
        local searchText = GetSearchText(self.searchBox)

        for _, craft in ipairs(addon:GetCraftsForProfession(professionName)) do
            if IsCraftVisible(craft, professionName, filter, searchText, visCache) then
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
    local filter = self:GetCompletionFilter()
    local searchText = GetSearchText(self.searchBox)
    local visCache = BuildCraftVisibilityCache(filter, searchText)
    if not self:BuildProfessionDisplay(visCache) then
        self:BuildCraftDisplay(visCache)
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

ProfessionsTab:RegisterTabVisibility("PROFESSIONS")

addon:RegisterInternalEvent("DATA_LOADED", function()
    if ProfessionsTab:IsShown() then
        addon:BuildCraftingIndex()
        ProfessionsTab:RefreshDisplay()
    end
end)

ProfessionsTab:RegisterOwnershipRefresh(function()
    if addon.dataLoaded and not addon.craftingIndexBuilt then
        addon:BuildCraftingIndex()
    end
    ProfessionsTab:RefreshDisplay()
end)

addon.MainFrame:RegisterContentAreaInitializer("ProfessionsTab", function(contentArea)
    ProfessionsTab:Create(contentArea)
end)
