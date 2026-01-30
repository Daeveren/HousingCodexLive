--[[
    Housing Codex - AchievementIndex.lua
    Achievement-to-decor index building and hierarchy management
    Parses AchievementSourceData for achievement-decor relationships
]]

local ADDON_NAME, addon = ...

-- Category display order (by decor count, descending)
local CATEGORY_ORDER = {
    ["Class Hall"] = 1,   -- 47 items
    ["Delves"] = 2,       -- 31 items
    ["Quests"] = 3,       -- 27 items
    ["PvP"] = 4,          -- 24 items
    ["Special"] = 5,      -- 20 items
    ["Professions"] = 6,  -- 16 items
    ["Exploration"] = 7,  -- 13 items
    ["Reputation"] = 8,   -- 8 items
    ["Dungeons"] = 9,     -- 5 items
    ["Timewalking"] = 10, -- 2 items
}

-- Runtime data structures
addon.achievementIndex = {}           -- achievementId -> { [recordID] = true, ... }
addon.achievementHierarchy = {}       -- category -> { achievements[] }
addon.achievementCompletionCache = {} -- achievementId -> boolean
addon.achievementIndexBuilt = false

-- Build achievement index from scraped AchievementSourceData
function addon:BuildAchievementIndex()
    if self.achievementIndexBuilt then return end  -- Prevent double initialization
    if not self.dataLoaded then
        self:Debug("Cannot build achievement index: data not loaded")
        return
    end

    local startTime = debugprofilestop()

    -- Clear existing data
    wipe(self.achievementIndex)

    local achievementCount = 0
    local decorCount = 0

    -- Parse AchievementSourceData
    if self.AchievementSourceData then
        for achievementId, achievementData in pairs(self.AchievementSourceData) do
            local validDecors = {}

            -- Only index decors that exist in our decorRecords
            if achievementData.decorIds then
                for _, decorId in ipairs(achievementData.decorIds) do
                    if self.decorRecords[decorId] then
                        validDecors[decorId] = true
                        decorCount = decorCount + 1
                    end
                end
            end

            -- Only add achievement if it has valid decors
            if next(validDecors) then
                self.achievementIndex[achievementId] = validDecors
                achievementCount = achievementCount + 1
            end
        end
    end

    local elapsedMs = math.floor(debugprofilestop() - startTime)
    self:Debug(string.format("Built achievement index: %d achievements, %d decors in %d ms",
        achievementCount, decorCount, elapsedMs))
end

-- Build achievement hierarchy (category -> achievements)
function addon:BuildAchievementHierarchy()
    local startTime = debugprofilestop()

    -- Clear existing hierarchy
    wipe(self.achievementHierarchy)

    -- Group achievements by category
    for achievementId in pairs(self.achievementIndex) do
        local achievementData = self.AchievementSourceData[achievementId]
        if achievementData and achievementData.category then
            local category = achievementData.category

            if not self.achievementHierarchy[category] then
                self.achievementHierarchy[category] = {}
            end

            table.insert(self.achievementHierarchy[category], achievementId)
        end
    end

    -- Sort achievements within each category alphabetically by name
    for category, achievements in pairs(self.achievementHierarchy) do
        table.sort(achievements, function(a, b)
            local nameA = self:GetAchievementName(a) or ""
            local nameB = self:GetAchievementName(b) or ""
            return nameA < nameB
        end)
    end

    self.achievementIndexBuilt = true

    local elapsedMs = math.floor(debugprofilestop() - startTime)
    self:Debug(string.format("Built achievement hierarchy in %d ms", elapsedMs))
end

-- Get sorted list of achievement categories (by predefined order)
function addon:GetSortedAchievementCategories()
    local categories = {}
    for category in pairs(self.achievementHierarchy) do
        table.insert(categories, category)
    end

    table.sort(categories, function(a, b)
        local orderA = CATEGORY_ORDER[a] or 999
        local orderB = CATEGORY_ORDER[b] or 999
        return orderA < orderB
    end)

    return categories
end

-- Get achievements for a specific category
function addon:GetAchievementsForCategory(category)
    return self.achievementHierarchy[category] or {}
end

-- Get record IDs for a specific achievement
function addon:GetRecordsForAchievement(achievementId)
    local records = self.achievementIndex[achievementId]
    if not records then return {} end

    local result = {}
    for recordID in pairs(records) do
        table.insert(result, recordID)
    end
    table.sort(result)  -- Deterministic "(1)", "(2)" order
    return result
end

-- Get achievement name from AchievementSourceData
function addon:GetAchievementName(achievementId)
    -- Check scraped data first
    local achievementData = self.AchievementSourceData and self.AchievementSourceData[achievementId]
    if achievementData and achievementData.achievementName then
        return achievementData.achievementName
    end

    -- Fallback to WoW API
    local _, name = GetAchievementInfo(achievementId)
    return name or string.format(self.L["ACHIEVEMENTS_UNKNOWN"], achievementId)
end

-- Get achievement category from AchievementSourceData
function addon:GetAchievementCategory(achievementId)
    local achievementData = self.AchievementSourceData and self.AchievementSourceData[achievementId]
    return achievementData and achievementData.category or nil
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
        local record = self.decorRecords[recordID]
        if record and record.isCollected then
            owned = owned + 1
        end
    end
    return owned, total
end

-- Get collection progress for a category
function addon:GetCategoryCollectionProgress(category)
    local achievements = self:GetAchievementsForCategory(category)
    local owned, total = 0, 0

    for _, achievementId in ipairs(achievements) do
        local aOwned, aTotal = self:GetAchievementCollectionProgress(achievementId)
        owned = owned + aOwned
        total = total + aTotal
    end

    return owned, total
end

-- Get achievement completion progress for a category (earned/total)
function addon:GetCategoryAchievementCompletionProgress(category)
    local achievements = self:GetAchievementsForCategory(category)
    local completed, total = 0, 0

    for _, achievementId in ipairs(achievements) do
        total = total + 1
        if self:IsAchievementCompleted(achievementId) then
            completed = completed + 1
        end
    end
    return completed, total
end

-- Get total achievement count
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

        -- Only fire UI notification for newly earned (prevents login spam)
        if not alreadyEarned then
            addon:FireEvent("ACHIEVEMENT_COMPLETION_CHANGED", achievementID, true)
        end
    end
end)
