--[[
    Housing Codex - Categories.lua
    Sidebar category navigation with Blizzard-style drill-down
]]

local ADDON_NAME, addon = ...

local CONSTS = addon.CONSTANTS
local BUTTON_HEIGHT = CONSTS.CATEGORY_BUTTON_HEIGHT
local PADDING = CONSTS.CATEGORY_PADDING
local ICON_SIZE = 30  -- Override for sidebar (larger than CONSTS.CATEGORY_ICON_SIZE)

-- Button colors (darker to match sidebar)
local COLOR_BG_NORMAL = { 0.08, 0.08, 0.10, 1 }
local COLOR_BG_HOVER = { 0.12, 0.12, 0.15, 1 }
local COLOR_BG_SELECTED = { 0.10, 0.10, 0.13, 1 }
local COLOR_GOLD_BORDER = { 1, 0.82, 0, 1 }

-- Button vertical spacing
local BUTTON_SPACING = BUTTON_HEIGHT + 2

addon.Categories = {}
local Categories = addon.Categories

Categories.sidebar = nil
Categories.container = nil
Categories.resultCountText = nil
Categories.resultOverlay = nil
Categories.buttonPool = nil
Categories.categories = {}       -- Cached category info
Categories.subcategories = {}    -- Cached subcategory info
Categories.focusedCategoryID = nil
Categories.focusedSubcategoryID = nil

function Categories:Initialize(sidebar)
    if self.container then return end

    self.sidebar = sidebar

    -- Create scroll container for buttons
    local container = CreateFrame("Frame", nil, sidebar)
    container:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 24)
    self.container = container

    -- Create button pool
    self.buttonPool = CreateFramePool("Button", container, nil, function(pool, button)
        button:Hide()
        button:ClearAllPoints()
        button.categoryID = nil
        button.subcategoryID = nil
        button.isBack = nil
        button.isAll = nil
    end)

    -- Create result count text at bottom of sidebar
    local resultText = addon:CreateFontString(sidebar, "OVERLAY", "GameFontHighlight")
    resultText:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", PADDING, 6)
    resultText:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -PADDING, 6)
    resultText:SetTextColor(0.7, 0.7, 0.7, 1)
    resultText:SetJustifyH("LEFT")
    self.resultCountText = resultText

    -- Invisible overlay for collection stats tooltip
    local resultOverlay = CreateFrame("Frame", nil, sidebar)
    resultOverlay:SetAllPoints(resultText)
    resultOverlay:EnableMouse(true)
    resultOverlay:SetScript("OnEnter", function(frame)
        if not addon.indexesBuilt then return end
        local L = addon.L

        GameTooltip:SetOwner(frame, "ANCHOR_TOPLEFT", 0, 4)
        GameTooltip:AddLine(string.format(L["RESULT_COUNT_TOOLTIP_UNIQUE"], addon:GetUniqueCollectedCount()), 1, 1, 1)
        GameTooltip:AddLine(string.format(L["RESULT_COUNT_TOOLTIP_OWNED"], addon:GetTotalOwnedCount()), 1, 1, 1)
        GameTooltip:AddLine(string.format(L["RESULT_COUNT_TOOLTIP_TOTAL"], addon:GetRecordCount()), 1, 1, 1)
        GameTooltip:Show()
    end)
    resultOverlay:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.resultOverlay = resultOverlay

    -- Load categories from API (defer if data not ready)
    if addon.dataLoaded then
        self:LoadCategories()
    end
    -- Otherwise, DATA_LOADED handler will call LoadCategories

    -- Always start at "All" (no category focus) on initialization
    self.focusedCategoryID = nil
    self.focusedSubcategoryID = nil

    -- Build initial display (will show "All" selected)
    self:BuildDisplay()

    -- Check current tab visibility (TAB_CHANGED may have fired before we registered)
    local currentTab = addon.Tabs and addon.Tabs:GetCurrentTab()
    if currentTab and currentTab ~= "DECOR" then
        self:Hide()
    end

    addon:Debug("Categories initialized")
end

function Categories:LoadCategories()
    self.categories = {}
    self.subcategories = {}

    -- Guard: API may not be available yet
    if not C_HousingCatalog or not C_HousingCatalog.SearchCatalogCategories then
        return
    end

    -- Get all categories (match searcher's editorModeContext)
    local categoryIDs = C_HousingCatalog.SearchCatalogCategories({
        withOwnedEntriesOnly = false,
        editorModeContext = Enum.HouseEditorMode.BasicDecor,
    })
    if not categoryIDs then return end

    for _, categoryID in ipairs(categoryIDs) do
        local info = C_HousingCatalog.GetCatalogCategoryInfo(categoryID)
        if info then
            self.categories[categoryID] = info

            -- Cache subcategories for this category
            if info.subcategoryIDs then
                for _, subcatID in ipairs(info.subcategoryIDs) do
                    local subInfo = C_HousingCatalog.GetCatalogSubcategoryInfo(subcatID)
                    if subInfo then
                        self.subcategories[subcatID] = subInfo
                    end
                end
            end
        end
    end

    addon:Debug("Loaded " .. #categoryIDs .. " categories")
end

-- Clear search text (Blizzard pattern: search and category are mutually exclusive)
local function ClearSearchText()
    if addon.SearchBox and addon.SearchBox.Clear then
        addon.SearchBox:Clear()
    end
    if addon.catalogSearcher then
        addon.catalogSearcher:SetSearchText(nil)
    end
end

function Categories:SetFocus(categoryID, subcategoryID)
    self.focusedCategoryID = categoryID
    self.focusedSubcategoryID = subcategoryID
    self.selectedCategoryID = nil  -- Clear direct selection when using drill-down navigation

    -- Clear search when focusing a category
    if categoryID ~= nil then
        ClearSearchText()
    end

    -- Save to db
    if addon.db and addon.db.browser and addon.db.browser.category then
        addon.db.browser.category.focusedCategoryID = categoryID
        addon.db.browser.category.focusedSubcategoryID = subcategoryID
    end

    self:ApplyFilter()
    self:BuildDisplay()
end

-- Clear category state and UI without triggering a search (used by SearchBox)
function Categories:ClearFocusOnly()
    self.focusedCategoryID = nil
    self.focusedSubcategoryID = nil
    self.selectedCategoryID = nil

    if addon.db and addon.db.browser and addon.db.browser.category then
        addon.db.browser.category.focusedCategoryID = nil
        addon.db.browser.category.focusedSubcategoryID = nil
    end

    self:BuildDisplay()
end

function Categories:ApplyFilter()
    if not addon.catalogSearcher then return end

    addon.catalogSearcher:SetFilteredCategoryID(self.focusedCategoryID)
    addon.catalogSearcher:SetFilteredSubcategoryID(self.focusedSubcategoryID)
    addon:RequestSearch()
end

function Categories:BuildDisplay()
    if not self.container or not self.buttonPool then return end

    self.buttonPool:ReleaseAll()

    if self.focusedCategoryID then
        self:BuildSubcategoryView()
    else
        self:BuildCategoryView()
    end
end

-- Position a button in the container at the given yOffset
function Categories:PositionButton(btn, yOffset)
    btn:SetPoint("TOPLEFT", self.container, "TOPLEFT", PADDING, yOffset)
    btn:SetPoint("TOPRIGHT", self.container, "TOPRIGHT", -PADDING, yOffset)
end

function Categories:BuildCategoryView()
    local L = addon.L
    local yOffset = -PADDING

    -- "All" button at top
    local allBtn = self:CreateCategoryButton(L["CATEGORY_ALL"], nil)
    self:PositionButton(allBtn, yOffset)
    allBtn.isAll = true
    allBtn:SetScript("OnClick", function()
        self:SetFocus(nil, nil)
    end)

    if not self.focusedCategoryID and not self.selectedCategoryID then
        self:SetButtonSelected(allBtn, true)
    end

    yOffset = yOffset - BUTTON_SPACING

    -- Get sorted category list (excluding built-in "All" category)
    local sortedCategories = {}
    local builtinAllID = CONSTS.BUILTIN_ALL_CATEGORY_ID
    for _, info in pairs(self.categories) do
        if info.ID ~= builtinAllID then
            table.insert(sortedCategories, info)
        end
    end
    table.sort(sortedCategories, function(a, b) return a.orderIndex < b.orderIndex end)

    -- Category buttons
    for _, info in ipairs(sortedCategories) do
        local btn = self:CreateCategoryButton(info.name, info.icon)
        self:PositionButton(btn, yOffset)
        btn.categoryID = info.ID

        btn:SetScript("OnClick", function()
            self:OnCategoryClick(info)
        end)

        -- Highlight if this category is directly selected (no drill-down)
        if self.selectedCategoryID == info.ID then
            self:SetButtonSelected(btn, true)
        end

        yOffset = yOffset - BUTTON_SPACING
    end
end

function Categories:BuildSubcategoryView()
    local L = addon.L
    local yOffset = -PADDING

    local categoryInfo = self.categories[self.focusedCategoryID]
    if not categoryInfo then
        self:SetFocus(nil, nil)
        return
    end

    -- Back button
    local backBtn = self:CreateCategoryButton("< " .. L["CATEGORY_BACK"], nil)
    self:PositionButton(backBtn, yOffset)
    backBtn.isBack = true
    backBtn:SetScript("OnClick", function()
        self:SetFocus(nil, nil)
    end)

    yOffset = yOffset - BUTTON_SPACING

    -- "All [Category]" button
    local allLabel = string.format(L["CATEGORY_ALL_IN"], categoryInfo.name or "")
    local allBtn = self:CreateCategoryButton(allLabel, categoryInfo.icon)
    self:PositionButton(allBtn, yOffset)
    allBtn.isAll = true
    allBtn.categoryID = self.focusedCategoryID
    allBtn:SetScript("OnClick", function()
        self:SetFocus(self.focusedCategoryID, nil)
    end)

    if not self.focusedSubcategoryID then
        self:SetButtonSelected(allBtn, true)
    end

    yOffset = yOffset - BUTTON_SPACING

    -- Get sorted subcategories
    local sortedSubcats = {}
    if categoryInfo.subcategoryIDs then
        for _, subcatID in ipairs(categoryInfo.subcategoryIDs) do
            local subInfo = self.subcategories[subcatID]
            if subInfo then
                table.insert(sortedSubcats, subInfo)
            end
        end
    end
    table.sort(sortedSubcats, function(a, b) return a.orderIndex < b.orderIndex end)

    -- Subcategory buttons
    for _, subInfo in ipairs(sortedSubcats) do
        local btn = self:CreateCategoryButton(subInfo.name, subInfo.icon)
        self:PositionButton(btn, yOffset)
        btn.subcategoryID = subInfo.ID

        btn:SetScript("OnClick", function()
            self:SetFocus(self.focusedCategoryID, subInfo.ID)
        end)

        if self.focusedSubcategoryID == subInfo.ID then
            self:SetButtonSelected(btn, true)
        end

        yOffset = yOffset - BUTTON_SPACING
    end
end

function Categories:OnCategoryClick(categoryInfo)
    local subcatCount = categoryInfo.subcategoryIDs and #categoryInfo.subcategoryIDs or 0
    if subcatCount > 1 then
        -- Drill down to show subcategories
        self:SetFocus(categoryInfo.ID, nil)
        return
    end

    -- Apply filter directly, stay in category view
    self.selectedCategoryID = categoryInfo.ID  -- Track for highlight
    ClearSearchText()

    if addon.catalogSearcher then
        addon.catalogSearcher:SetFilteredCategoryID(categoryInfo.ID)
        addon.catalogSearcher:SetFilteredSubcategoryID(nil)
        addon:RequestSearch()
    end
    self:BuildDisplay()  -- Refresh selection highlight
end

function Categories:CreateCategoryButton(label, iconAtlas)
    local btn = self.buttonPool:Acquire()
    btn:SetHeight(BUTTON_HEIGHT)

    -- Background
    if not btn.bg then
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(unpack(COLOR_BG_NORMAL))
        btn.bg = bg
    else
        btn.bg:SetColorTexture(unpack(COLOR_BG_NORMAL))
    end

    -- Gold left border (for selection, hidden by default)
    if not btn.selectionBorder then
        local border = btn:CreateTexture(nil, "ARTWORK")
        border:SetWidth(3)
        border:SetPoint("TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMLEFT", 0, 0)
        border:SetColorTexture(unpack(COLOR_GOLD_BORDER))
        border:Hide()
        btn.selectionBorder = border
    else
        btn.selectionBorder:Hide()
    end

    -- Icon (use larger size for better visibility)
    local iconOffset = PADDING
    if iconAtlas then
        if not btn.icon then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(ICON_SIZE, ICON_SIZE)
            icon:SetPoint("LEFT", PADDING, 0)
            btn.icon = icon
        else
            btn.icon:SetSize(ICON_SIZE, ICON_SIZE)
        end
        btn.icon:SetAtlas(iconAtlas)
        btn.icon:Show()
        iconOffset = PADDING + ICON_SIZE + 6
    elseif btn.icon then
        btn.icon:Hide()
    end

    -- Label (default to grayed out, selected buttons get white text)
    if not btn.label then
        local text = addon:CreateFontString(btn, "OVERLAY", "GameFontNormal")
        text:SetJustifyH("LEFT")
        btn.label = text
    end
    -- Clear and reset anchors on each reuse (Blizzard pattern for pooled frames)
    btn.label:ClearAllPoints()
    btn.label:SetPoint("LEFT", iconOffset, 0)
    btn.label:SetPoint("RIGHT", -PADDING, 0)
    btn.label:SetText(label or "")
    btn.label:SetTextColor(0.6, 0.6, 0.6, 1)  -- Grayed out by default

    -- Hover handlers
    btn:SetScript("OnEnter", function(b)
        if not b.isSelected then
            b.bg:SetColorTexture(unpack(COLOR_BG_HOVER))
        end
    end)

    btn:SetScript("OnLeave", function(b)
        if not b.isSelected then
            b.bg:SetColorTexture(unpack(COLOR_BG_NORMAL))
        end
    end)

    btn:Show()
    return btn
end

function Categories:SetButtonSelected(btn, selected)
    btn.isSelected = selected
    if selected then
        btn.bg:SetColorTexture(unpack(COLOR_BG_SELECTED))
        btn.selectionBorder:Show()
        btn.label:SetTextColor(1, 1, 1, 1)  -- White for selected
    else
        btn.bg:SetColorTexture(unpack(COLOR_BG_NORMAL))
        btn.selectionBorder:Hide()
        btn.label:SetTextColor(0.6, 0.6, 0.6, 1)  -- Grayed out for non-selected
    end
end

function Categories:UpdateResultCount(shown, total)
    if not self.resultCountText then return end

    local L = addon.L

    if not addon.dataLoaded then
        self.resultCountText:SetText("")
    elseif shown == total then
        self.resultCountText:SetText(string.format(L["RESULT_COUNT_ALL"], total))
    else
        self.resultCountText:SetText(string.format(L["RESULT_COUNT_FILTERED"], shown, total))
    end
end

function Categories:Show()
    if self.container then self.container:Show() end
    if self.resultCountText then self.resultCountText:Show() end
    if self.resultOverlay then self.resultOverlay:Show() end
end

function Categories:Hide()
    if self.container then self.container:Hide() end
    if self.resultCountText then self.resultCountText:Hide() end
    if self.resultOverlay then self.resultOverlay:Hide() end
end

function Categories:Reset()
    self:SetFocus(nil, nil)
end

-- Hook into tab changes - only show categories for DECOR tab
addon:RegisterInternalEvent("TAB_CHANGED", function(tabKey)
    if tabKey == "DECOR" then
        Categories:Show()
    else
        Categories:Hide()
    end
end)

-- Load categories when data becomes available (deferred initialization)
addon:RegisterInternalEvent("DATA_LOADED", function()
    if Categories.container and not next(Categories.categories) then
        Categories:LoadCategories()
        Categories:BuildDisplay()
        -- Run initial search to populate the grid
        Categories:ApplyFilter()
    end
end)

-- Cache invalidation for categories (fired by Init.lua from WoW events)
addon:RegisterInternalEvent("CATEGORY_CACHE_INVALIDATED", function(categoryID)
    if not Categories.categories or not categoryID then return end

    -- Clear cached entry and fetch fresh data
    Categories.categories[categoryID] = nil
    local info = C_HousingCatalog.GetCatalogCategoryInfo(categoryID)
    if info then
        Categories.categories[categoryID] = info
    end
    Categories:BuildDisplay()
end)

addon:RegisterInternalEvent("SUBCATEGORY_CACHE_INVALIDATED", function(subcategoryID)
    if not Categories.subcategories or not subcategoryID then return end

    -- Clear cached entry and fetch fresh data
    Categories.subcategories[subcategoryID] = nil
    local info = C_HousingCatalog.GetCatalogSubcategoryInfo(subcategoryID)
    if info then
        Categories.subcategories[subcategoryID] = info
    end
    Categories:BuildDisplay()
end)
