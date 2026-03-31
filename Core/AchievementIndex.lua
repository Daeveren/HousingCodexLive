--[[
    Housing Codex - AchievementIndex.lua
    Achievement-to-decor index building and hierarchy management
    Parses AchievementSourceData for achievement-decor relationships
]]

local _, addon = ...

-- WoW achievement root category IDs (stable across locales)
-- Intentional ordering (diverges from Blizzard's ACHIEVEMENTUI_SUMMARYCATEGORIES; 81 not in Blizzard list)
local CATEGORY_ORDER = {
    [92] = 1,      -- General
    [96] = 2,      -- Quests
    [97] = 3,      -- Exploration
    [95] = 4,      -- Player vs. Player
    [168] = 5,     -- Dungeons & Raids
    [169] = 6,     -- Professions
    [201] = 7,     -- Reputation
    [155] = 8,     -- World Events
    [15117] = 9,   -- Pet Battles
    [15246] = 10,  -- Collections
    [15522] = 11,  -- Expansion Features
    [81] = 12,     -- Feats of Strength
}

local EMPTY = {}  -- Shared empty table for cache misses (never mutate)

-- Runtime data structures
addon.achievementIndex = {}           -- achievementId -> { [recordID] = true, ... }
addon.achievementSortedRecords = {}   -- achievementId -> sorted { recordID, ... } (cached at build time)
addon.achievementHierarchy = {}       -- categoryId -> { achievements[] }
addon.achievementCompletionCache = {} -- achievementId -> boolean
addon.achievementIndexBuilt = false   -- true only after BuildAchievementHierarchy completes

-- Build achievement index from scraped AchievementSourceData
function addon:BuildAchievementIndex()
    if self.achievementIndexBuilt then return end
    if not self.dataLoaded then
        self:Debug("Cannot build achievement index: data not loaded")
        return
    end

    local startTime = debugprofilestop()

    -- Clear existing data
    wipe(self.achievementIndex)
    wipe(self.achievementSortedRecords)
    self.DecorToAchievementLookup = {}

    local achievementCount = 0
    local decorCount = 0

    -- Parse AchievementSourceData and build reverse lookup
    if self.AchievementSourceData then
        for achievementId, achievementData in pairs(self.AchievementSourceData) do
            local validDecors = {}

            -- Only index decors that resolve (matches CraftingIndex/QuestIndex pattern)
            if achievementData.decorIds then
                for _, decorId in ipairs(achievementData.decorIds) do
                    if self:GetRecord(decorId) or self:ResolveRecord(decorId) then
                        validDecors[decorId] = true
                        decorCount = decorCount + 1
                    end
                    -- Build reverse lookup (decorId -> achievementId) for all entries
                    self.DecorToAchievementLookup[decorId] = achievementId
                end
            end

            -- Only add achievement if it has valid decors
            if next(validDecors) then
                self.achievementIndex[achievementId] = validDecors
                achievementCount = achievementCount + 1
            end
        end
    end

    -- Pre-build sorted record lists (all call sites are read-only ipairs)
    for achievementId, records in pairs(self.achievementIndex) do
        local sorted = {}
        for recordID in pairs(records) do
            sorted[#sorted + 1] = recordID
        end
        table.sort(sorted)
        self.achievementSortedRecords[achievementId] = sorted
    end

    local elapsedMs = math.floor(debugprofilestop() - startTime)
    self:Debug(string.format("Built achievement index: %d achievements, %d decors in %d ms",
        achievementCount, decorCount, elapsedMs))
end

-- Get top-level category ID from WoW API
-- Walks up the category hierarchy to find the root category ID
function addon:GetWoWAchievementCategory(achievementId)
    local categoryId = GetAchievementCategory(achievementId)
    if not categoryId then return nil end

    -- Walk up hierarchy to find top-level category (where parentCategoryId == -1)
    local _, parentCategoryId = GetCategoryInfo(categoryId)

    while parentCategoryId and parentCategoryId ~= -1 do
        categoryId = parentCategoryId
        _, parentCategoryId = GetCategoryInfo(categoryId)
    end

    return categoryId
end

-- Get localized category name from category ID
function addon:GetCategoryName(categoryId)
    if not categoryId then return nil end
    return (GetCategoryInfo(categoryId))
end

-- Build achievement hierarchy (categoryId -> achievements)
function addon:BuildAchievementHierarchy()
    local startTime = debugprofilestop()

    -- Clear existing hierarchy
    wipe(self.achievementHierarchy)

    -- Group achievements by category ID using WoW API
    for achievementId in pairs(self.achievementIndex) do
        local categoryId = self:GetWoWAchievementCategory(achievementId)

        if categoryId then
            if not self.achievementHierarchy[categoryId] then
                self.achievementHierarchy[categoryId] = {}
            end

            table.insert(self.achievementHierarchy[categoryId], achievementId)
        end
    end

    -- Precompute sort keys once (O(n) API calls instead of O(n log n) in comparator)
    local nameCache = {}
    for _, achievements in pairs(self.achievementHierarchy) do
        for _, achievementId in ipairs(achievements) do
            nameCache[achievementId] = self:GetAchievementName(achievementId) or ""
        end
    end

    -- Sort achievements within each category alphabetically by name
    for categoryId, achievements in pairs(self.achievementHierarchy) do
        table.sort(achievements, function(a, b)
            return nameCache[a] < nameCache[b]
        end)
    end

    self.achievementIndexBuilt = true

    local elapsedMs = math.floor(debugprofilestop() - startTime)
    self:Debug(string.format("Built achievement hierarchy in %d ms", elapsedMs))
end

-- Get sorted list of achievement category IDs (by predefined order)
function addon:GetSortedAchievementCategories()
    local categoryIds = {}
    for categoryId in pairs(self.achievementHierarchy) do
        table.insert(categoryIds, categoryId)
    end

    table.sort(categoryIds, function(a, b)
        local orderA = CATEGORY_ORDER[a] or 999
        local orderB = CATEGORY_ORDER[b] or 999
        return orderA < orderB
    end)

    return categoryIds
end

-- Get achievements for a specific category (by ID)
function addon:GetAchievementsForCategory(categoryId)
    return self.achievementHierarchy[categoryId] or {}
end

-- Get record IDs for a specific achievement (returns cached sorted array)
function addon:GetRecordsForAchievement(achievementId)
    return self.achievementSortedRecords[achievementId] or EMPTY
end

-- Get achievement name (prefers localized API name)
function addon:GetAchievementName(achievementId)
    -- Prefer localized API name
    local _, name = GetAchievementInfo(achievementId)
    if name then return name end

    -- Fallback to scraped data if API unavailable
    local achievementData = self.AchievementSourceData and self.AchievementSourceData[achievementId]
    if achievementData and achievementData.achievementName then
        return achievementData.achievementName
    end

    return string.format(self.L["ACHIEVEMENTS_UNKNOWN"], achievementId)
end

-- Check if achievement is completed (uses WoW API, cached)
-- Returns: true (complete), false (incomplete), or nil (invalid achievement)
function addon:IsAchievementCompleted(achievementId)
    if not achievementId then return nil end

    -- Check cache first
    local cached = self.achievementCompletionCache[achievementId]
    if cached ~= nil then return cached end

    -- Validate achievement exists before querying
    if not C_AchievementInfo.IsValidAchievement(achievementId) then
        return nil  -- Don't cache invalid - may become valid in future patch
    end

    -- Query WoW API: GetAchievementInfo returns: id, name, points, completed, ...
    local _, _, _, completed = GetAchievementInfo(achievementId)
    local isComplete = completed or false

    self.achievementCompletionCache[achievementId] = isComplete
    return isComplete
end

-- Get collection progress for an achievement (owned/total decor items)
function addon:GetAchievementCollectionProgress(achievementId)
    local records = self.achievementIndex[achievementId]
    if not records then return 0, 0 end

    local owned, total = 0, 0
    for recordID in pairs(records) do
        total = total + 1
        local record = self:GetRecord(recordID)
        if record and record.isCollected then
            owned = owned + 1
        end
    end
    return owned, total
end

-- Get collection progress for a category (by ID)
function addon:GetCategoryCollectionProgress(categoryId)
    local achievements = self:GetAchievementsForCategory(categoryId)
    local owned, total = 0, 0

    for _, achievementId in ipairs(achievements) do
        local aOwned, aTotal = self:GetAchievementCollectionProgress(achievementId)
        owned = owned + aOwned
        total = total + aTotal
    end

    return owned, total
end

function addon:GetAchievementCount()
    local count = 0
    for _ in pairs(self.achievementIndex) do count = count + 1 end
    return count
end

-- Handle achievement completion event
addon:RegisterWoWEvent("ACHIEVEMENT_EARNED", function(achievementID, alreadyEarned)
    if addon.achievementIndex[achievementID] then
        -- Always update cache (even for alts completing account-wide achievements)
        addon.achievementCompletionCache[achievementID] = true

        -- Always fire UI notification (alreadyEarned=true fires for account-wide sync on alts)
        addon:FireEvent("ACHIEVEMENT_COMPLETION_CHANGED", achievementID, true)
    end
end)
