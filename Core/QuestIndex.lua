--[[
    Housing Codex - QuestIndex.lua
    Quest-to-decor index building and hierarchy management
    Parses sourceText for quest IDs and organizes by Expansion > Zone
]]

local _, addon = ...

local ZONE_TO_EXPANSION = addon.ZONE_TO_EXPANSION
local EMPTY = {}  -- Shared empty table for cache misses (never mutate)

-- Shared expansion order; module-specific unknowns fall back to 0 at usage sites
local EXPANSION_ORDER = addon.CONSTANTS.EXPANSION_ORDER

-- Runtime data structures
addon.questIndex = {}           -- questKey -> { [recordID] = true, ... } (questKey = questID or questName for nil IDs)
addon.questSortedRecords = {}   -- questKey -> sorted { recordID, ... } (cached at build time)
addon.questHierarchy = {}       -- expansionKey -> { order, zones = { zoneName -> { questKeys } } }
addon.questTitleCache = {}      -- questKey -> title string
addon.questZoneCache = {}       -- questKey -> { zoneName, expansionKey }
addon.questIndexBuilt = false
addon.pendingQuestLoads = {}    -- questID -> true (for async title loading)
addon.questZoneFromScrape = {}  -- questKey -> { zoneName, expansionKey } (primary zone, from scraped QuestSourceData)
addon.questAllZones = {}        -- questKey -> { {zoneName, expansionKey}, ... } (all zones, for multi-zone hierarchy)
addon.questStringsInterned = false

-- Intern quest name strings to reduce memory (Lua 5.1 doesn't auto-intern table strings)
local function InternQuestStrings()
    local intern = {}
    local count = 0

    -- Build intern table from QuestSourceData
    if addon.QuestSourceData then
        for _, quests in pairs(addon.QuestSourceData) do
            for _, quest in ipairs(quests) do
                local name = quest.questName
                if name then
                    if not intern[name] then
                        intern[name] = name
                        count = count + 1
                    end
                    quest.questName = intern[name]
                end
            end
        end
    end

    -- Reuse interned strings in DecorToQuestLookup
    if addon.DecorToQuestLookup then
        for _, data in pairs(addon.DecorToQuestLookup) do
            local name = data.questName
            if name then
                data.questName = intern[name] or name
            end
        end
    end

    addon:Debug(string.format("Interned %d unique quest names", count))
end

-- Parse quest ID from sourceText using multiple strategies
local function ParseQuestID(sourceText)
    if not sourceText or sourceText == "" then return nil end

    -- Strategy 1: Try LinkUtil.ExtractLink for any hyperlink type
    if LinkUtil and LinkUtil.ExtractLink then
        local linkType, linkID = LinkUtil.ExtractLink(sourceText)
        if linkType == "quest" and linkID then
            return tonumber(linkID)
        end
    end

    -- Strategy 2: Regex pattern for |Hquest:ID|h format
    local questID = sourceText:match("|Hquest:(%d+)|h")
    if questID then
        return tonumber(questID)
    end

    -- Strategy 3: Look for "Quest:" followed by a number (fallback for plain text)
    questID = sourceText:match("Quest:%s*(%d+)")
    if questID then
        return tonumber(questID)
    end

    return nil
end

-- Cache helper for unknown locations
local function CacheUnknownLocation(questKey)
    local zoneName = addon.L["QUESTS_UNKNOWN_ZONE"]
    local expansionKey = "QUESTS_UNKNOWN_EXPANSION"
    addon.questZoneCache[questKey] = { zoneName = zoneName, expansionKey = expansionKey }
    return zoneName, expansionKey
end

-- Get quest location (zone name and expansion) from quest key
-- questKey can be a numeric questID or a string questName (for quests without IDs)
-- Simplified: Uses scraped data only (covers 99%+ of housing quests)
local function GetQuestLocation(questKey)
    if not questKey then
        return addon.L["QUESTS_UNKNOWN_ZONE"], "QUESTS_UNKNOWN_EXPANSION"
    end

    -- Check cache first
    local cached = addon.questZoneCache[questKey]
    if cached then
        return cached.zoneName, cached.expansionKey
    end

    -- Check scraped zone data (primary and only source for housing quests)
    local scraped = addon.questZoneFromScrape[questKey]
    if scraped then
        addon.questZoneCache[questKey] = scraped
        return scraped.zoneName, scraped.expansionKey
    end

    -- No scraped data available - cache and return unknown
    return CacheUnknownLocation(questKey)
end

-- Request async loading of quest title
local function RequestQuestTitle(questID)
    if not questID or addon.questTitleCache[questID] or addon.pendingQuestLoads[questID] then
        return
    end
    addon.pendingQuestLoads[questID] = true
    if C_QuestLog and C_QuestLog.RequestLoadQuestByID then
        C_QuestLog.RequestLoadQuestByID(questID)
    end
end

-- Build quest index from scraped WowDB data and decor records
function addon:BuildQuestIndex()
    if not self.dataLoaded then
        self:Debug("Cannot build quest index: data not loaded")
        return
    end

    -- Guard: prevent QUEST_DATA_LOAD_RESULT from calling BuildQuestHierarchy
    -- while we're still building the index (step 2 hasn't populated zones yet)
    self.buildingQuestIndex = true

    -- Intern strings before building index (first run only)
    if not self.questStringsInterned then
        InternQuestStrings()
        self.questStringsInterned = true
    end

    local startTime = debugprofilestop()

    -- Clear existing data
    wipe(self.questIndex)
    wipe(self.questSortedRecords)
    wipe(self.questZoneFromScrape)
    wipe(self.questAllZones)
    wipe(self.questZoneCache)
    wipe(self.questTitleCache)
    self.questTitleFallback = {}
    wipe(self.pendingQuestLoads)

    local questCount = 0
    local scrapedCount = 0

    -- Primary source: Use scraped DecorToQuestLookup
    -- WowDB decorId = WoW API's HousingCatalogEntryID.recordID (decorID)
    if self.DecorToQuestLookup then
        for recordID, questData in pairs(self.DecorToQuestLookup) do
            -- Only index if the record exists in our data (ResolveRecord covers HiddenInCatalog items)
            if self:ResolveRecord(recordID) then
                -- Use questId if available, check override table, then fall back to questName
                local questKey = questData.questId
                    or (questData.questName and self.QuestIdOverrides and self.QuestIdOverrides[questData.questName])
                    or questData.questName
                if questKey then
                    if not self.questIndex[questKey] then
                        self.questIndex[questKey] = {}
                        questCount = questCount + 1
                    end
                    self.questIndex[questKey][recordID] = true

                    -- Cache the quest name from scraped data
                    -- Numeric keys: store in fallback so RequestQuestTitle can fire async localization
                    -- String keys: store in questTitleCache (can't be localized via API)
                    if questData.questName then
                        if type(questKey) == "number" then
                            self.questTitleFallback[questKey] = questData.questName
                        else
                            self.questTitleCache[questKey] = questData.questName
                        end
                    end

                    -- Request title loading for numeric IDs (to get localized names)
                    if type(questKey) == "number" then
                        RequestQuestTitle(questKey)
                    end

                    scrapedCount = scrapedCount + 1
                end
            end
        end
    end

    -- Build zone caches from QuestSourceData (provides zone → quest mapping)
    -- questZoneFromScrape: single primary zone per quest (deterministic tiebreaker for GetQuestLocation/ZoneIndex)
    -- questAllZones: all zones per quest (for multi-zone hierarchy placement)
    if self.QuestSourceData then
        for zoneName, quests in pairs(self.QuestSourceData) do
            local expansionKey = ZONE_TO_EXPANSION[zoneName] or "QUESTS_UNKNOWN_EXPANSION"
            for _, questInfo in ipairs(quests) do
                local questKey = questInfo.questId
                    or (questInfo.questName and self.QuestIdOverrides and self.QuestIdOverrides[questInfo.questName])
                    or questInfo.questName
                if questKey and self.questIndex[questKey] then
                    local zoneEntry = { zoneName = zoneName, expansionKey = expansionKey }

                    -- All-zones list for multi-zone hierarchy
                    local allZones = self.questAllZones[questKey]
                    if not allZones then
                        allZones = {}
                        self.questAllZones[questKey] = allZones
                    end
                    table.insert(allZones, zoneEntry)

                    -- Primary zone with deterministic tiebreaker (Dornogal wins, then alphabetical)
                    local existing = self.questZoneFromScrape[questKey]
                    if not existing then
                        self.questZoneFromScrape[questKey] = zoneEntry
                    elseif existing.zoneName ~= zoneName then
                        local keepExisting = existing.zoneName == "Dornogal"
                            or (zoneName ~= "Dornogal" and existing.zoneName < zoneName)
                        if not keepExisting then
                            self.questZoneFromScrape[questKey] = zoneEntry
                        end
                    end
                end
            end
        end
    end

    -- Build set of already-indexed records to prevent sourceText fallback duplicates
    local indexedRecords = {}
    for _, records in pairs(self.questIndex) do
        for recordID in pairs(records) do
            indexedRecords[recordID] = true
        end
    end

    -- Secondary source: Parse sourceText from records (fallback for any missed)
    local parsedCount = 0
    for recordID, record in pairs(self.decorRecords) do
        if not indexedRecords[recordID] and record.sourceText and record.sourceText ~= "" then
            local questID = ParseQuestID(record.sourceText)
            if questID then
                if not self.questIndex[questID] then
                    -- Found a quest not in scraped data
                    self.questIndex[questID] = {}
                    questCount = questCount + 1
                    RequestQuestTitle(questID)
                    parsedCount = parsedCount + 1
                end
                -- Add record to quest (new or existing)
                self.questIndex[questID][recordID] = true
            end
        end
    end

    -- Pre-build sorted record lists (all call sites are read-only ipairs)
    for questKey, records in pairs(self.questIndex) do
        local sorted = {}
        for recordID in pairs(records) do
            sorted[#sorted + 1] = recordID
        end
        table.sort(sorted)
        self.questSortedRecords[questKey] = sorted
    end

    self.buildingQuestIndex = false

    -- Reset zone index so it rebuilds with the now-populated quest data
    self:ResetZoneIndex()

    local elapsedMs = math.floor(debugprofilestop() - startTime)
    self:Debug(string.format("Built quest index: %d quests (%d scraped, %d parsed) in %d ms",
        questCount, scrapedCount, parsedCount, elapsedMs))
end

-- Build quest hierarchy (expansion > zone > quests)
function addon:BuildQuestHierarchy()
    local startTime = debugprofilestop()

    -- Clear existing hierarchy
    wipe(self.questHierarchy)

    -- Helper: insert questKey into a zone within the hierarchy
    local function InsertIntoHierarchy(questKey, zoneName, expansionKey)
        if not self.questHierarchy[expansionKey] then
            self.questHierarchy[expansionKey] = {
                order = EXPANSION_ORDER[expansionKey] or 0,
                zones = {},
            }
        end
        if not self.questHierarchy[expansionKey].zones[zoneName] then
            self.questHierarchy[expansionKey].zones[zoneName] = {}
        end
        table.insert(self.questHierarchy[expansionKey].zones[zoneName], questKey)
    end

    -- Group quests by expansion and zone (multi-zone quests appear in all applicable zones)
    for questKey in pairs(self.questIndex) do
        local zones = self.questAllZones[questKey]
        if zones then
            for _, zoneEntry in ipairs(zones) do
                InsertIntoHierarchy(questKey, zoneEntry.zoneName, zoneEntry.expansionKey)
            end
        else
            -- Fallback for quests from secondary source (sourceText parsing, not in QuestSourceData)
            local zoneName, expansionKey = GetQuestLocation(questKey)
            InsertIntoHierarchy(questKey, zoneName, expansionKey)
        end
    end

    -- Helper to get quest difficulty level (only works for numeric IDs)
    local function GetQuestLevel(questKey)
        if type(questKey) ~= "number" then return 0 end
        if not C_QuestLog or not C_QuestLog.GetQuestDifficultyLevel then return 0 end
        return C_QuestLog.GetQuestDifficultyLevel(questKey) or 0
    end

    -- Precompute sort keys once (O(n) API calls instead of O(n log n) in comparator)
    local levelCache = {}
    for _, expData in pairs(self.questHierarchy) do
        for _, quests in pairs(expData.zones) do
            for _, questKey in ipairs(quests) do
                levelCache[questKey] = GetQuestLevel(questKey)
            end
        end
    end

    -- Sort quests within each zone by level then title
    for _, expData in pairs(self.questHierarchy) do
        for _, quests in pairs(expData.zones) do
            table.sort(quests, function(a, b)
                local levelA = levelCache[a] or 0
                local levelB = levelCache[b] or 0
                if levelA ~= levelB then return levelA < levelB end

                local titleA = addon:GetQuestTitle(a)
                local titleB = addon:GetQuestTitle(b)
                return titleA < titleB
            end)
        end
    end

    self.questIndexBuilt = true

    local elapsedMs = math.floor(debugprofilestop() - startTime)
    self:Debug(string.format("Built quest hierarchy in %d ms", elapsedMs))
end

-- Get sorted list of expansion keys (newest first, Unknown last)
function addon:GetSortedExpansions()
    local expansions = {}
    for expansionKey in pairs(self.questHierarchy) do
        table.insert(expansions, expansionKey)
    end

    table.sort(expansions, function(a, b)
        local orderA = EXPANSION_ORDER[a] or 0
        local orderB = EXPANSION_ORDER[b] or 0
        return orderA > orderB  -- Higher order = newer = first
    end)

    return expansions
end

-- Get sorted list of zone names within an expansion
function addon:GetSortedZones(expansionKey)
    local expData = self.questHierarchy[expansionKey]
    if not expData then return {} end

    local zones = {}
    for zoneName in pairs(expData.zones) do
        table.insert(zones, zoneName)
    end

    table.sort(zones, function(a, b)
        return self:GetLocalizedZoneName(a) < self:GetLocalizedZoneName(b)
    end)
    return zones
end

-- Get quests for a specific zone
function addon:GetQuestsForZone(expansionKey, zoneName)
    local expData = self.questHierarchy[expansionKey]
    if not expData or not expData.zones[zoneName] then return {} end
    return expData.zones[zoneName]
end

-- Get record IDs for a specific quest (returns cached sorted array)
-- questKey can be a numeric questID or a string questName
function addon:GetRecordsForQuest(questKey)
    return self.questSortedRecords[questKey] or EMPTY
end

-- Get collection progress for a quest (owned/total decor items)
-- questKey can be a numeric questID or a string questName
function addon:GetQuestCollectionProgress(questKey)
    local records = self.questIndex[questKey]
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

-- Get collection progress for a zone
function addon:GetZoneCollectionProgress(expansionKey, zoneName)
    local quests = self:GetQuestsForZone(expansionKey, zoneName)
    local owned, total = 0, 0

    for _, questID in ipairs(quests) do
        local qOwned, qTotal = self:GetQuestCollectionProgress(questID)
        owned = owned + qOwned
        total = total + qTotal
    end

    return owned, total
end

-- Get collection progress for an expansion (deduped: multi-zone quests counted once)
function addon:GetExpansionCollectionProgress(expansionKey)
    local expData = self.questHierarchy[expansionKey]
    if not expData then return 0, 0 end

    local owned, total = 0, 0
    local seenQuests = {}
    for zoneName in pairs(expData.zones) do
        for _, questKey in ipairs(expData.zones[zoneName]) do
            if not seenQuests[questKey] then
                seenQuests[questKey] = true
                local qOwned, qTotal = self:GetQuestCollectionProgress(questKey)
                owned = owned + qOwned
                total = total + qTotal
            end
        end
    end

    return owned, total
end

-- Get quest title (with placeholder fallback)
-- questKey can be a numeric questID or a string questName (for quests without IDs)
function addon:GetQuestTitle(questKey)
    if not questKey then return nil end

    -- Check cache first (includes scraped quest names)
    local cached = self.questTitleCache[questKey]
    if cached then return cached end

    -- For string keys (quests without IDs), check locale table first, then use English name
    if type(questKey) == "string" then
        local title = self.questTitleLocale[questKey] or questKey
        self.questTitleCache[questKey] = title
        return title
    end

    -- Try to get title from WoW API for numeric IDs
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(questKey)
        if title and title ~= "" then
            self.questTitleCache[questKey] = title
            return title
        end
    end

    -- Fall back to scraped English name (displays while async load is pending)
    local fallback = self.questTitleFallback and self.questTitleFallback[questKey]
    if fallback then return fallback end

    -- Return placeholder
    return string.format(self.L["QUESTS_UNKNOWN_QUEST"], questKey)
end

-- Get total quest count (matches SavedVars pattern)
function addon:GetQuestCount()
    local count = 0
    for _ in pairs(self.questIndex) do count = count + 1 end
    return count
end

-- Handle quest data load completion
addon:RegisterWoWEvent("QUEST_DATA_LOAD_RESULT", function(questID, success)
    if not addon.pendingQuestLoads[questID] then return end
    addon.pendingQuestLoads[questID] = nil

    -- Cache title on success
    if success and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title and title ~= "" then
            addon.questTitleCache[questID] = title
        end
    end

    -- Signal when all pending title loads are resolved
    -- Guard: don't rebuild hierarchy if BuildQuestIndex is still running
    -- (RequestQuestTitle can fire synchronous QUEST_DATA_LOAD_RESULT during step 1,
    -- before step 2 has populated questZoneFromScrape)
    if not next(addon.pendingQuestLoads) and not addon.buildingQuestIndex then
        addon:BuildQuestHierarchy()
        addon:FireEvent("QUEST_ALL_TITLES_LOADED")
    end
end)

