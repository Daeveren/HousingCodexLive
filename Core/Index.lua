--[[
    Housing Codex - Index.lua
    Search and filter indexes for fast queries
]]

local ADDON_NAME, addon = ...

addon.indexes = {
    collected = {},
    uncollected = {},
    trackable = {},
    indoors = {},
    outdoors = {},
    dyeable = {},
    bySize = {},
    byCategory = {},
    bySubcategory = {},
    byWord = {},
}

addon.indexesBuilt = false

local function AddToIndex(index, key, recordID)
    index[key] = index[key] or {}
    index[key][recordID] = true
end

function addon:BuildIndexes()
    if not self.dataLoaded then
        self:Debug("Cannot build indexes: data not loaded")
        return
    end

    local startTime = debugprofilestop()

    -- Clear existing indexes
    for key in pairs(self.indexes) do
        if type(self.indexes[key]) == "table" then
            wipe(self.indexes[key])
        end
    end

    -- Build indexes from records
    for recordID, record in pairs(self.decorRecords) do
        -- Collection state
        if record.isCollected then
            self.indexes.collected[recordID] = true
        else
            self.indexes.uncollected[recordID] = true
        end

        -- Attributes
        if record.isTrackable then
            self.indexes.trackable[recordID] = true
        end
        if record.isIndoors then
            self.indexes.indoors[recordID] = true
        end
        if record.isOutdoors then
            self.indexes.outdoors[recordID] = true
        end
        if record.canCustomize then
            self.indexes.dyeable[recordID] = true
        end

        -- Size
        if record.size then
            AddToIndex(self.indexes.bySize, record.size, recordID)
        end

        -- Categories
        if record.categoryIDs then
            for _, catID in ipairs(record.categoryIDs) do
                AddToIndex(self.indexes.byCategory, catID, recordID)
            end
        end

        -- Subcategories
        if record.subcategoryIDs then
            for _, subID in ipairs(record.subcategoryIDs) do
                AddToIndex(self.indexes.bySubcategory, subID, recordID)
            end
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
    end

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
    local firstWord = words[1]
    local candidates = self.indexes.byWord[firstWord]

    if not candidates then
        -- Try partial match on first word
        for indexWord, recordIDs in pairs(self.indexes.byWord) do
            if string.find(indexWord, firstWord, 1, true) then
                candidates = candidates or {}
                for recordID in pairs(recordIDs) do
                    candidates[recordID] = true
                end
            end
        end
    end

    if not candidates then return results end

    -- Filter by remaining words
    for recordID in pairs(candidates) do
        local matchesAll = true

        for i = 2, #words do
            local word = words[i]
            local found = false

            -- Check exact match
            if self.indexes.byWord[word] and self.indexes.byWord[word][recordID] then
                found = true
            else
                -- Check partial match
                local record = self.decorRecords[recordID]
                if record and record.name then
                    found = string.find(string.lower(record.name), word, 1, true) ~= nil
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

function addon:QueryRecords(filters)
    filters = filters or {}

    local results = {}
    local firstFilter = true

    -- Helper to intersect results
    local function IntersectWith(index)
        if firstFilter then
            for recordID in pairs(index) do
                results[recordID] = true
            end
            firstFilter = false
        else
            for recordID in pairs(results) do
                if not index[recordID] then
                    results[recordID] = nil
                end
            end
        end
    end

    -- Apply filters (AND logic between different filter types)

    -- Collection filters
    if filters.collected then
        IntersectWith(self.indexes.collected)
    elseif filters.uncollected then
        IntersectWith(self.indexes.uncollected)
    end

    -- Attribute filters
    if filters.trackable then
        IntersectWith(self.indexes.trackable)
    end
    if filters.indoors then
        IntersectWith(self.indexes.indoors)
    end
    if filters.outdoors then
        IntersectWith(self.indexes.outdoors)
    end
    if filters.dyeable then
        IntersectWith(self.indexes.dyeable)
    end

    -- Size filter
    if filters.size then
        local sizeIndex = self.indexes.bySize[filters.size]
        if sizeIndex then
            IntersectWith(sizeIndex)
        else
            return {}  -- No results for this size
        end
    end

    -- Category filter
    if filters.categoryID then
        local catIndex = self.indexes.byCategory[filters.categoryID]
        if catIndex then
            IntersectWith(catIndex)
        else
            return {}
        end
    end

    -- Subcategory filter
    if filters.subcategoryID then
        local subIndex = self.indexes.bySubcategory[filters.subcategoryID]
        if subIndex then
            IntersectWith(subIndex)
        else
            return {}
        end
    end

    -- Wishlist filter
    if filters.wishlistOnly and self.db then
        if firstFilter then
            for recordID in pairs(self.db.wishlist) do
                if self.decorRecords[recordID] then
                    results[recordID] = true
                end
            end
            firstFilter = false
        else
            for recordID in pairs(results) do
                if not self.db.wishlist[recordID] then
                    results[recordID] = nil
                end
            end
        end
    end

    -- If no filters were applied, return all records
    if firstFilter then
        for recordID in pairs(self.decorRecords) do
            results[recordID] = true
        end
    end

    -- Convert to array
    local resultArray = {}
    for recordID in pairs(results) do
        table.insert(resultArray, recordID)
    end

    return resultArray
end

function addon:SortResults(recordIDs, sortType)
    sortType = sortType or "alphabetical"

    table.sort(recordIDs, function(a, b)
        local recordA = self.decorRecords[a]
        local recordB = self.decorRecords[b]

        if not recordA or not recordB then return false end

        if sortType == "alphabetical" then
            return (recordA.name or "") < (recordB.name or "")
        elseif sortType == "newest" then
            -- Assuming higher recordID = newer (may not be accurate)
            return a > b
        end

        return false
    end)

    return recordIDs
end

-- Event Handlers
addon:RegisterInternalEvent("DATA_LOADED", function()
    addon:BuildIndexes()
end)

addon:RegisterInternalEvent("TRACKING_CHANGED", function(recordID)
    local record = addon.decorRecords[recordID]
    if record then
        addon.indexes.trackable[recordID] = record.isTrackable or nil
    end
end)
