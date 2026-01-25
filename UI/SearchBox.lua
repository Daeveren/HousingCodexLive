--[[
    Housing Codex - SearchBox.lua
    Search input with debounce for filtering decor items
    Uses HousingCatalogSearcher:SetSearchText() for native search
]]

local ADDON_NAME, addon = ...

local DEBOUNCE_DELAY = 0.2  -- 200ms

addon.SearchBox = {}
local SearchBox = addon.SearchBox

SearchBox.frame = nil
SearchBox.debounceTimer = nil
SearchBox.lastSearchText = nil

function SearchBox:Create(parent)
    if self.frame then return self.frame end

    -- Create search box using WoW's SearchBoxTemplate
    local frame = CreateFrame("EditBox", "HousingCodexSearchBox", parent, "SearchBoxTemplate")
    frame:SetHeight(22)  -- Width is determined by two-point anchoring in Grid.lua
    frame:SetAutoFocus(false)
    self.frame = frame

    -- Set placeholder text
    if frame.Instructions then
        frame.Instructions:SetText(addon.L["SEARCH_PLACEHOLDER"] or "Search...")
    end

    -- Text changed handler with debounce (HookScript preserves default placeholder behavior)
    frame:HookScript("OnTextChanged", function(editBox, userInput)
        if userInput then
            self:OnTextChanged(editBox:GetText())
        end
    end)

    -- Clear button handler
    if frame.clearButton then
        frame.clearButton:HookScript("OnClick", function()
            self:ApplySearch(nil)
        end)
    end

    -- Enter key triggers immediate search
    frame:SetScript("OnEnterPressed", function(editBox)
        self:CancelDebounce()
        self:ApplySearch(editBox:GetText())
        editBox:ClearFocus()
    end)

    -- Escape clears and removes focus
    frame:SetScript("OnEscapePressed", function(editBox)
        self:CancelDebounce()
        editBox:SetText("")
        self:ApplySearch(nil)
        editBox:ClearFocus()
    end)

    return frame
end

function SearchBox:OnTextChanged(text)
    self:CancelDebounce()

    -- Start debounce timer
    self.debounceTimer = C_Timer.NewTimer(DEBOUNCE_DELAY, function()
        self:ApplySearch(text)
    end)
end

function SearchBox:CancelDebounce()
    if self.debounceTimer then
        self.debounceTimer:Cancel()
        self.debounceTimer = nil
    end
end

function SearchBox:ApplySearch(text)
    -- Normalize empty/whitespace to nil
    local searchText = text and strtrim(text)
    if searchText == "" then searchText = nil end

    -- Skip if same as last search
    if searchText == self.lastSearchText then return end
    self.lastSearchText = searchText

    -- Check if searcher is available
    if not addon.catalogSearcher then
        addon:Debug("SearchBox: Searcher not available")
        return
    end

    addon:Debug("SearchBox: Applying search: " .. tostring(searchText))

    -- Set search text first (order matters for searcher state)
    addon.catalogSearcher:SetSearchText(searchText)

    -- Clear category focus when searching (Blizzard pattern: search and category are mutually exclusive)
    if searchText then
        if addon.Categories then
            addon.Categories:ClearFocusOnly()
        end
        addon.catalogSearcher:SetFilteredCategoryID(nil)
        addon.catalogSearcher:SetFilteredSubcategoryID(nil)
    end

    addon.catalogSearcher:RunSearch()

    addon:FireEvent("SEARCH_TEXT_CHANGED", searchText)

    -- Save filter state (search text is part of filter state)
    if addon.Filters then
        addon.Filters:SaveState()
    end
end

function SearchBox:Clear()
    if self.frame then
        self.frame:SetText("")
    end
    self:CancelDebounce()
    self.lastSearchText = nil
end

function SearchBox:GetText()
    return self.frame and self.frame:GetText() or ""
end

function SearchBox:SetEnabled(enabled)
    if not self.frame then return end
    self.frame:SetEnabled(enabled)
end

function SearchBox:Show()
    if not self.frame then return end
    self.frame:Show()
end

function SearchBox:Hide()
    if not self.frame then return end
    self.frame:Hide()
end
