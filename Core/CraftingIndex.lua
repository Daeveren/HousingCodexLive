--[[
    Housing Codex - CraftingIndex.lua
    Profession-to-decor index building and progress helpers.

    Index entries carry scraped values verbatim: skillLine, professionName, and
    recipeSource stay in English here (search matches the English spelling). The display layer localizes them --
    see BuildSkillText / BuildRecipeSourceText in UI/ProfessionsTab.lua.
]]

local _, addon = ...

addon.craftingIndex = {}
addon.craftingHierarchy = {}
addon.craftingProgressCache = {}
addon.craftingIndexBuilt = false
addon.craftingTotalCount = 0

local function BuildSortName(record, professionName, decorId)
    if record and record.name and record.name ~= "" then
        return strlower(record.name)
    end
    if professionName and professionName ~= "" then
        return strlower(professionName)
    end
    return tostring(decorId)
end

function addon:BuildCraftingIndex()
    if self.craftingIndexBuilt then return end
    if not self.CraftingSourceData then
        self:Debug("Cannot build crafting index: CraftingSourceData not loaded")
        return
    end

    local startTime = debugprofilestop()

    wipe(self.craftingIndex)
    wipe(self.craftingHierarchy)
    wipe(self.craftingProgressCache)
    self.craftingTotalCount = 0

    local professionCount = 0
    local skippedMissingRecord = 0

    for professionName, crafts in pairs(self.CraftingSourceData) do
        local entries = {}

        for _, craft in ipairs(crafts or {}) do
            local decorId = craft.decorId
            if decorId then
                local record = self:ResolveRecord(decorId)
                if record then
                    table.insert(entries, {
                        decorId = decorId,
                        professionName = professionName,
                        skillLine = craft.skillLine,
                        skillNeeded = craft.skillNeeded,
                        recipeSource = craft.recipeSource,
                        sortName = BuildSortName(record, professionName, decorId),
                    })
                    self.craftingTotalCount = self.craftingTotalCount + 1
                else
                    skippedMissingRecord = skippedMissingRecord + 1
                end
            end
        end

        if #entries > 0 then
            table.sort(entries, function(a, b)
                if a.sortName == b.sortName then
                    return a.decorId < b.decorId
                end
                return a.sortName < b.sortName
            end)

            self.craftingIndex[professionName] = entries
            table.insert(self.craftingHierarchy, professionName)
            professionCount = professionCount + 1
        end
    end

    table.sort(self.craftingHierarchy, function(a, b)
        return a < b
    end)

    self.craftingIndexBuilt = true
    self:InvalidateProgressCache()

    -- ResolveRecord calls above may have grown fallbackRecords. Invalidate the
    -- word index and GetAllRecordIDs cache so next search covers the new entries.
    self.byWordIndexBuilt = false
    self.cachedAllRecordIDs = nil

    self:Debug(string.format(
        "Built crafting index: %d professions, %d crafts, %d skipped in %d ms",
        professionCount,
        self.craftingTotalCount,
        skippedMissingRecord,
        math.floor(debugprofilestop() - startTime)
    ))
end

function addon:GetSortedProfessions()
    local professions = {}
    for _, professionName in ipairs(self.craftingHierarchy) do
        local owned, total = self:GetCraftingProgress(professionName)
        table.insert(professions, {
            name = professionName,
            owned = owned,
            total = total,
        })
    end
    return professions
end

function addon:GetCraftsForProfession(professionName)
    return self.craftingIndex[professionName] or {}
end

function addon:GetCraftingCount()
    return self.craftingTotalCount or 0
end

function addon:GetCraftingProgress(professionName)
    local cached = self.craftingProgressCache[professionName]
    if cached then
        return cached.owned, cached.total
    end

    local owned, total = 0, 0
    for _, craft in ipairs(self:GetCraftsForProfession(professionName)) do
        if self:ShouldDisplayDecor(craft.decorId) then
            total = total + 1
            local record = self:ResolveRecord(craft.decorId)
            if record and record.isCollected then
                owned = owned + 1
            end
        end
    end

    self.craftingProgressCache[professionName] = {
        owned = owned,
        total = total,
    }
    return owned, total
end

addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
    wipe(addon.craftingProgressCache)
end)

-- Eagerly resolve crafting-only decorIds at data load so hidden-catalog items
-- (e.g. HiddenInCatalog-flagged recipes) land in fallbackRecords before the
-- main search word index is first built.
addon:RegisterInternalEvent("DATA_LOADED", function()
    addon:BuildCraftingIndex()
end)
