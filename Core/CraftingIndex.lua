--[[
    Housing Codex - CraftingIndex.lua
    Profession-to-decor index building and progress helpers.
]]

local ADDON_NAME, addon = ...

addon.craftingIndex = {}
addon.craftingHierarchy = {}
addon.craftingProgressCache = {}
addon.craftingIndexBuilt = false
addon.craftingTotalCount = 0

local function BuildSortName(record, recipeName, decorId)
    if record and record.name and record.name ~= "" then
        return strlower(record.name)
    end
    if recipeName and recipeName ~= "" then
        return strlower(recipeName)
    end
    return tostring(decorId or 0)
end

local function ResolveCraftRecord(owner, decorId)
    return owner:GetRecord(decorId) or owner:ResolveRecord(decorId)
end

function addon:BuildCraftingIndex()
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
                local record = ResolveCraftRecord(self, decorId)
                if record then
                    local recipeName = craft.recipeName
                    table.insert(entries, {
                        decorId = decorId,
                        recipeId = craft.recipeId,
                        recipeName = recipeName,
                        professionName = professionName,
                        skillLine = craft.skillLine,
                        skillNeeded = craft.skillNeeded,
                        sortName = BuildSortName(record, recipeName, decorId),
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
                    return (a.decorId or 0) < (b.decorId or 0)
                end
                return a.sortName < b.sortName
            end)

            self.craftingIndex[professionName] = entries
            table.insert(self.craftingHierarchy, professionName)
            professionCount = professionCount + 1
        end
    end

    table.sort(self.craftingHierarchy, function(a, b)
        return (a or "") < (b or "")
    end)

    self.craftingIndexBuilt = true

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
        total = total + 1
        local record = ResolveCraftRecord(self, craft.decorId)
        if record and record.isCollected then
            owned = owned + 1
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
