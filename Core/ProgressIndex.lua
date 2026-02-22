--[[
    Housing Codex - ProgressIndex.lua
    Aggregation layer for collection progress across all source types.
    Pure data — no WoW API calls, no UI code.
]]

local ADDON_NAME, addon = ...

local EXPANSION_ORDER = addon.CONSTANTS.EXPANSION_ORDER

addon.progressCache = {}

--------------------------------------------------------------------------------
-- Cache Invalidation
--------------------------------------------------------------------------------

addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
    wipe(addon.progressCache)
end)

addon:RegisterInternalEvent("DATA_LOADED", function()
    wipe(addon.progressCache)
end)

--------------------------------------------------------------------------------
-- Public: Overall Progress
--------------------------------------------------------------------------------

-- Returns { collected, total, percent, remaining }
function addon:GetProgressOverview()
    if self.progressCache.overview then
        return self.progressCache.overview
    end

    local collected = self:GetUniqueCollectedCount()
    local total = self:GetRecordCount()
    local percent = total > 0 and (collected / total * 100) or 0
    local remaining = total - collected

    local result = {
        collected = collected,
        total = total,
        percent = percent,
        remaining = remaining,
    }
    self.progressCache.overview = result
    return result
end

--------------------------------------------------------------------------------
-- Public: Progress By Source Type
--------------------------------------------------------------------------------

-- Returns ordered array of { key, labelKey, owned, total, percent, targetTabKey }
function addon:GetProgressBySourceType()
    if self.progressCache.bySource then
        return self.progressCache.bySource
    end

    local result = {}

    -- All Decor (global counts)
    local overview = self:GetProgressOverview()
    table.insert(result, {
        key = "ALL_DECOR",
        labelKey = "PROGRESS_SOURCE_ALL",
        owned = overview.collected,
        total = overview.total,
        percent = overview.percent,
        targetTabKey = "DECOR",
    })

    -- Vendors
    local vOwned, vTotal = 0, 0
    for expansionKey in pairs(self.vendorHierarchy) do
        local eOwned, eTotal = self:GetVendorExpansionCollectionProgress(expansionKey)
        vOwned = vOwned + eOwned
        vTotal = vTotal + eTotal
    end
    table.insert(result, {
        key = "VENDORS",
        labelKey = "PROGRESS_SOURCE_VENDORS",
        owned = vOwned,
        total = vTotal,
        percent = vTotal > 0 and (vOwned / vTotal * 100) or 0,
        targetTabKey = "VENDORS",
    })

    -- Quests
    local qOwned, qTotal = 0, 0
    for expansionKey in pairs(self.questHierarchy) do
        local eOwned, eTotal = self:GetExpansionCollectionProgress(expansionKey)
        qOwned = qOwned + eOwned
        qTotal = qTotal + eTotal
    end
    table.insert(result, {
        key = "QUESTS",
        labelKey = "PROGRESS_SOURCE_QUESTS",
        owned = qOwned,
        total = qTotal,
        percent = qTotal > 0 and (qOwned / qTotal * 100) or 0,
        targetTabKey = "QUESTS",
    })

    -- Achievements
    local aOwned, aTotal = 0, 0
    for achievementId in pairs(self.achievementIndex) do
        local eOwned, eTotal = self:GetAchievementCollectionProgress(achievementId)
        aOwned = aOwned + eOwned
        aTotal = aTotal + eTotal
    end
    table.insert(result, {
        key = "ACHIEVEMENTS",
        labelKey = "PROGRESS_SOURCE_ACHIEVEMENTS",
        owned = aOwned,
        total = aTotal,
        percent = aTotal > 0 and (aOwned / aTotal * 100) or 0,
        targetTabKey = "ACHIEVEMENTS",
    })

    -- Drops (split by sub-category: drops, bosses, treasure)
    local dropCategories = {
        { category = "drop",      labelKey = "DROPS_CATEGORY_DROP" },
        { category = "encounter", labelKey = "DROPS_CATEGORY_ENCOUNTER" },
        { category = "treasure",  labelKey = "DROPS_CATEGORY_TREASURE" },
    }
    for _, dc in ipairs(dropCategories) do
        if self.dropHierarchy[dc.category] then
            local dOwned, dTotal = self:GetDropCategoryCollectionProgress(dc.category)
            if dTotal > 0 then
                table.insert(result, {
                    key = dc.category,
                    labelKey = dc.labelKey,
                    owned = dOwned,
                    total = dTotal,
                    percent = dOwned / dTotal * 100,
                    targetTabKey = "DROPS",
                })
            end
        end
    end

    -- Professions (sum per-profession rows already computed by GetProgressByProfession)
    local pOwned, pTotal = 0, 0
    for _, row in ipairs(self:GetProgressByProfession()) do
        pOwned = pOwned + row.owned
        pTotal = pTotal + row.total
    end
    table.insert(result, {
        key = "PROFESSIONS",
        labelKey = "PROGRESS_SOURCE_PROFESSIONS",
        owned = pOwned,
        total = pTotal,
        percent = pTotal > 0 and (pOwned / pTotal * 100) or 0,
        targetTabKey = "PROFESSIONS",
    })

    self.progressCache.bySource = result
    return result
end

--------------------------------------------------------------------------------
-- Public: Progress By Expansion
--------------------------------------------------------------------------------

-- sourceKind: "QUESTS" or "VENDORS"
-- Returns ordered array of { expansionKey, labelKey, owned, total, percent, targetTabKey, sourceKind }
function addon:GetProgressByExpansion(sourceKind)
    local cacheKey = "byExpansion_" .. (sourceKind or "")
    if self.progressCache[cacheKey] then
        return self.progressCache[cacheKey]
    end

    local hierarchy, progressFn
    if sourceKind == "QUESTS" then
        hierarchy = self.questHierarchy
        progressFn = self.GetExpansionCollectionProgress
    elseif sourceKind == "VENDORS" then
        hierarchy = self.vendorHierarchy
        progressFn = self.GetVendorExpansionCollectionProgress
    else
        return {}
    end

    local result = {}
    for expansionKey in pairs(hierarchy) do
        local owned, total = progressFn(self, expansionKey)
        table.insert(result, {
            expansionKey = expansionKey,
            labelKey     = expansionKey,
            owned        = owned,
            total        = total,
            percent      = total > 0 and (owned / total * 100) or 0,
            targetTabKey = sourceKind,
            sourceKind   = sourceKind,
        })
    end

    -- Sort newest first (highest EXPANSION_ORDER), unknown last
    table.sort(result, function(a, b)
        local orderA = EXPANSION_ORDER[a.expansionKey] or 0
        local orderB = EXPANSION_ORDER[b.expansionKey] or 0
        return orderA > orderB
    end)

    self.progressCache[cacheKey] = result
    return result
end

--------------------------------------------------------------------------------
-- Public: Progress By Profession
--------------------------------------------------------------------------------

-- Returns ordered array of { professionName, labelKey, owned, total, percent, targetTabKey }
function addon:GetProgressByProfession()
    if self.progressCache.byProfession then
        return self.progressCache.byProfession
    end

    local result = {}
    for _, professionName in ipairs(self.craftingHierarchy) do
        local owned, total = self:GetCraftingProgress(professionName)
        if total > 0 then
            table.insert(result, {
                professionName = professionName,
                labelKey       = professionName,
                owned          = owned,
                total          = total,
                percent        = owned / total * 100,
                targetTabKey   = "PROFESSIONS",
            })
        end
    end

    self.progressCache.byProfession = result
    return result
end

--------------------------------------------------------------------------------
-- Public: Almost There (closest to completion)
--------------------------------------------------------------------------------

-- Returns array of { expansionKey, labelKey, owned, total, percent, remaining, targetTabKey, sourceKind }
-- Combines quest + vendor expansion rows, sorted by highest % then smallest remaining
function addon:GetAlmostThereRows(limit)
    limit = limit or 5

    local cacheKey = "almostThere_" .. limit
    if self.progressCache[cacheKey] then
        return self.progressCache[cacheKey]
    end

    local candidates = {}

    local function addIncomplete(sourceRows, targetTabKey, sourceKind)
        for _, row in ipairs(sourceRows) do
            if row.total > 0 and row.owned > 0 and row.owned < row.total then
                local entry = {}
                for k, v in pairs(row) do entry[k] = v end
                entry.remaining = row.total - row.owned
                entry.targetTabKey = targetTabKey
                entry.sourceKind = sourceKind
                table.insert(candidates, entry)
            end
        end
    end

    addIncomplete(self:GetProgressByExpansion("QUESTS"), "QUESTS", "QUESTS")
    addIncomplete(self:GetProgressByExpansion("VENDORS"), "VENDORS", "VENDORS")

    -- Sort: highest % first, then smallest remaining as tiebreaker
    table.sort(candidates, function(a, b)
        if a.percent ~= b.percent then
            return a.percent > b.percent
        end
        return a.remaining < b.remaining
    end)

    local result = {}
    for i = 1, math.min(limit, #candidates) do
        result[i] = candidates[i]
    end

    self.progressCache[cacheKey] = result
    return result
end
