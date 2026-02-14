--[[
    Housing Codex - Index.lua
    Search and filter indexes for fast queries
]]

local ADDON_NAME, addon = ...

addon.indexes = {
    collected = {},
    byWord = {},
}

addon.indexesBuilt = false

local function AddToIndex(index, key, recordID)
    index[key] = index[key] or {}
    index[key][recordID] = true
end

-- Strip WoW escape sequences (colors, hyperlinks, textures, newlines) from sourceText
-- NOTE: tostring() required because C_StringUtil.StripHyperlinks returns stringView type
local function StripSourceMarkup(text)
    if C_StringUtil and C_StringUtil.StripHyperlinks then
        return tostring(C_StringUtil.StripHyperlinks(text, false, false, true, false, false))
    end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|n", " ")
end

function addon:BuildIndexes()
    if not self.dataLoaded then
        self:Debug("Cannot build indexes: data not loaded")
        return
    end

    local startTime = debugprofilestop()

    -- Clear existing indexes
    wipe(self.indexes.collected)
    wipe(self.indexes.byWord)

    -- Build indexes from records
    for recordID, record in pairs(self.decorRecords) do
        -- Collection state
        if record.isCollected then
            self.indexes.collected[recordID] = true
        end

        -- Word index for name search
        if record.name then
            local nameLower = string.lower(record.name)
            for word in string.gmatch(nameLower, "%w+") do
                if #word >= 2 then  -- Skip single-letter words
                    AddToIndex(self.indexes.byWord, word, recordID)
                end
            end
        end

        -- Word index for sourceText search (zone, quest, vendor names)
        if record.sourceText and record.sourceText ~= "" then
            local lower = string.lower(StripSourceMarkup(record.sourceText))
            for word in string.gmatch(lower, "%w+") do
                if #word >= 2 then
                    AddToIndex(self.indexes.byWord, word, recordID)
                end
            end
        end
    end

    -- itemID -> recordID reverse index (merchant overlay instant lookup)
    local itemIDToRecordID = {}
    for recordID, record in pairs(self.decorRecords) do
        if record.itemID then
            itemIDToRecordID[record.itemID] = recordID
        end
    end
    for recordID, record in pairs(self.fallbackRecords) do
        -- Skip false sentinel values (failed lookups cached as false)
        if record and record.itemID then
            itemIDToRecordID[record.itemID] = recordID
        end
    end
    self.itemIDToRecordID = itemIDToRecordID

    self.indexesBuilt = true

    local elapsedMs = math.floor(debugprofilestop() - startTime)
    self:Debug(string.format("Built indexes in %d ms", elapsedMs))
end

function addon:SearchByText(searchText)
    if not searchText or searchText == "" then
        return self:GetAllRecordIDs()
    end

    local results = {}
    local words = {}

    -- Extract search words
    local searchLower = string.lower(searchText)
    for word in string.gmatch(searchLower, "%w+") do
        if #word >= 2 then
            table.insert(words, word)
        end
    end

    if #words == 0 then
        return self:GetAllRecordIDs()
    end

    -- Find records matching ALL words (AND logic)
    -- Always use partial matching for first word to ensure consistent results
    -- (exact match would skip partial scan, causing "dalaran" to find fewer than "dalara")
    local firstWord = words[1]
    local candidates = {}
    for indexWord, recordIDs in pairs(self.indexes.byWord) do
        if string.find(indexWord, firstWord, 1, true) then
            for recordID in pairs(recordIDs) do
                candidates[recordID] = true
            end
        end
    end

    if not next(candidates) then return results end

    -- Filter by remaining words
    -- Cache cleaned sourceText per record to avoid repeated StripHyperlinks calls
    local cleanedSourceCache = {}
    local function getCleanedSource(record)
        if not record.sourceText or record.sourceText == "" then return nil end
        local cached = cleanedSourceCache[record]
        if cached then return cached end
        local lower = string.lower(StripSourceMarkup(record.sourceText))
        cleanedSourceCache[record] = lower
        return lower
    end

    for recordID in pairs(candidates) do
        local matchesAll = true

        for i = 2, #words do
            local word = words[i]
            local found = false

            -- Check exact match in word index
            if self.indexes.byWord[word] and self.indexes.byWord[word][recordID] then
                found = true
            else
                -- Check partial match in name and sourceText
                local record = self.decorRecords[recordID]
                if record then
                    if record.name and string.find(string.lower(record.name), word, 1, true) then
                        found = true
                    elseif record.sourceText then
                        local cleanSource = getCleanedSource(record)
                        if cleanSource and string.find(cleanSource, word, 1, true) then
                            found = true
                        end
                    end
                end
            end

            if not found then
                matchesAll = false
                break
            end
        end

        if matchesAll then
            table.insert(results, recordID)
        end
    end

    return results
end

-- Event Handlers
addon:RegisterInternalEvent("DATA_LOADED", function()
    addon:BuildIndexes()
end)
