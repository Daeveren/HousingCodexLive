--[[
    Housing Codex - QuestIndex.lua
    Quest-to-decor index building and hierarchy management
    Parses sourceText for quest IDs and organizes by Expansion > Zone
]]

local ADDON_NAME, addon = ...

-- Continent ID to Expansion mapping (manually maintained)
-- Higher order = newer expansion = appears first in UI
local CONTINENT_TO_EXPANSION = {
    -- Classic (order 1)
    [12] = { order = 1, key = "EXPANSION_CLASSIC" },   -- Kalimdor
    [13] = { order = 1, key = "EXPANSION_CLASSIC" },   -- Eastern Kingdoms
    -- The Burning Crusade (order 2)
    [101] = { order = 2, key = "EXPANSION_TBC" },      -- Outland
    -- Wrath of the Lich King (order 3)
    [113] = { order = 3, key = "EXPANSION_WRATH" },    -- Northrend
    -- Cataclysm (order 4)
    [948] = { order = 4, key = "EXPANSION_CATA" },     -- The Maelstrom
    -- Mists of Pandaria (order 5)
    [424] = { order = 5, key = "EXPANSION_MOP" },      -- Pandaria
    -- Warlords of Draenor (order 6)
    [572] = { order = 6, key = "EXPANSION_WOD" },      -- Draenor
    -- Legion (order 7)
    [619] = { order = 7, key = "EXPANSION_LEGION" },   -- Broken Isles
    -- Battle for Azeroth (order 8)
    [875] = { order = 8, key = "EXPANSION_BFA" },      -- Zandalar
    [876] = { order = 8, key = "EXPANSION_BFA" },      -- Kul Tiras
    -- Shadowlands (order 9)
    [1550] = { order = 9, key = "EXPANSION_SL" },      -- The Shadowlands
    -- Dragonflight (order 10)
    [1978] = { order = 10, key = "EXPANSION_DF" },     -- Dragon Isles
    -- The War Within (order 11)
    [2248] = { order = 11, key = "EXPANSION_TWW" },    -- Khaz Algar
}

-- Zone name to Expansion mapping (from scraped WowDB data)
-- Used as primary source for zone categorization
local ZONE_TO_EXPANSION = {
    -- Classic
    ["Blackrock Depths"] = "EXPANSION_CLASSIC",
    ["Blasted Lands"] = "EXPANSION_CLASSIC",
    ["Burning Steppes"] = "EXPANSION_CLASSIC",
    ["Duskwood"] = "EXPANSION_CLASSIC",
    ["Elwynn Forest"] = "EXPANSION_CLASSIC",
    ["Gilneas"] = "EXPANSION_CLASSIC",
    ["Loch Modan"] = "EXPANSION_CLASSIC",
    ["Mulgore"] = "EXPANSION_CLASSIC",
    ["Northshire"] = "EXPANSION_CLASSIC",
    ["Orgrimmar"] = "EXPANSION_CLASSIC",
    ["Ruins of Gilneas"] = "EXPANSION_CLASSIC",
    ["Searing Gorge"] = "EXPANSION_CLASSIC",
    ["Silverpine Forest"] = "EXPANSION_CLASSIC",
    ["Stormwind City"] = "EXPANSION_CLASSIC",
    ["Westfall"] = "EXPANSION_CLASSIC",
    ["Dustwallow Marsh"] = "EXPANSION_CLASSIC",
    ["Felwood"] = "EXPANSION_CLASSIC",

    -- TBC
    ["Exile's Reach"] = "EXPANSION_TBC",  -- Starting zone, fits better here

    -- Wrath
    ["Dalaran"] = "EXPANSION_WRATH",
    ["Grizzly Hills"] = "EXPANSION_WRATH",

    -- Cataclysm
    ["Twilight Highlands"] = "EXPANSION_CATA",

    -- MoP
    ["Kun-Lai Summit"] = "EXPANSION_MOP",
    ["The Jade Forest"] = "EXPANSION_MOP",
    ["Valley of the Four Winds"] = "EXPANSION_MOP",

    -- WoD
    ["Frostfire Ridge"] = "EXPANSION_WOD",
    ["Frostwall"] = "EXPANSION_WOD",
    ["Lunarfall"] = "EXPANSION_WOD",
    ["Nagrand"] = "EXPANSION_WOD",
    ["Shadowmoon Valley"] = "EXPANSION_WOD",
    ["Spires of Arak"] = "EXPANSION_WOD",
    ["Talador"] = "EXPANSION_WOD",

    -- Legion (no zones currently)

    -- BFA
    ["Boralus Harbor"] = "EXPANSION_BFA",
    ["Drustvar"] = "EXPANSION_BFA",
    ["Mechagon"] = "EXPANSION_BFA",
    ["Nazmir"] = "EXPANSION_BFA",
    ["Stormsong Valley"] = "EXPANSION_BFA",
    ["The Great Sea"] = "EXPANSION_BFA",
    ["Tiragarde Sound"] = "EXPANSION_BFA",
    ["Vol'dun"] = "EXPANSION_BFA",
    ["Zuldazar"] = "EXPANSION_BFA",

    -- Shadowlands (no zones currently)

    -- Dragonflight
    ["Thaldraszus"] = "EXPANSION_DF",
    ["The Azure Span"] = "EXPANSION_DF",
    ["The Forbidden Reach"] = "EXPANSION_DF",
    ["The Waking Shores"] = "EXPANSION_DF",
    ["Valdrakken"] = "EXPANSION_DF",

    -- TWW
    ["Dornogal"] = "EXPANSION_TWW",
    ["Founder's Point"] = "EXPANSION_TWW",
    ["Razorwind Shores"] = "EXPANSION_TWW",
    ["The Ringing Deeps"] = "EXPANSION_TWW",
    ["Voidstorm"] = "EXPANSION_TWW",
    ["Undermine"] = "EXPANSION_TWW",

    -- Midnight
    ["Arcantina"] = "EXPANSION_MIDNIGHT",
    ["Eversong Woods"] = "EXPANSION_MIDNIGHT",  -- Midnight quests (92025, 90493)
    ["Harandar"] = "EXPANSION_MIDNIGHT",

    -- Unknown/catchall
    ["Unknown"] = "QUESTS_UNKNOWN_EXPANSION",
}

-- Build expansion order lookup from CONTINENT_TO_EXPANSION (avoids duplication)
local EXPANSION_ORDER = { ["QUESTS_UNKNOWN_EXPANSION"] = 0 }
for _, data in pairs(CONTINENT_TO_EXPANSION) do
    EXPANSION_ORDER[data.key] = data.order
end
-- Midnight (order 12) - no continent ID available yet
EXPANSION_ORDER["EXPANSION_MIDNIGHT"] = 12

-- Runtime data structures
addon.questIndex = {}           -- questKey -> { [recordID] = true, ... } (questKey = questID or questName for nil IDs)
addon.questHierarchy = {}       -- expansionKey -> { order, zones = { zoneName -> { questKeys } } }
addon.questTitleCache = {}      -- questKey -> title string
addon.questCompletionCache = {} -- questKey -> boolean
addon.questZoneCache = {}       -- questKey -> { zoneName, expansionKey }
addon.questIndexBuilt = false
addon.pendingQuestLoads = {}    -- questID -> true (for async title loading)
addon.questZoneFromScrape = {}  -- questKey -> { zoneName, expansionKey } (from scraped QuestSourceData)
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
local function CacheUnknownLocation(questID)
    local result = { zoneName = addon.L["QUESTS_UNKNOWN_ZONE"], expansionKey = "QUESTS_UNKNOWN_EXPANSION" }
    addon.questZoneCache[questID] = result
    return result.zoneName, result.expansionKey
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

    -- Intern strings before building index (first run only)
    if not self.questStringsInterned then
        InternQuestStrings()
        self.questStringsInterned = true
    end

    local startTime = debugprofilestop()

    -- Clear existing data
    wipe(self.questIndex)
    wipe(self.questZoneFromScrape)
    wipe(self.questTitleCache)

    local questCount = 0
    local scrapedCount = 0

    -- Primary source: Use scraped DecorToQuestLookup
    -- decorId from WowDB scraper = recordID from WoW Housing API
    if self.DecorToQuestLookup then
        for decorId, questData in pairs(self.DecorToQuestLookup) do
            local recordID = decorId
            -- Only index if the record exists in our data
            if self.decorRecords[recordID] then
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
                    if questData.questName then
                        self.questTitleCache[questKey] = questData.questName
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

    -- Build zone cache from QuestSourceData (provides zone → quest mapping)
    -- Priority: Prefer Dornogal when a quest appears in multiple zones (avoids duplicate entries)
    if self.QuestSourceData then
        for zoneName, quests in pairs(self.QuestSourceData) do
            local expansionKey = ZONE_TO_EXPANSION[zoneName] or "QUESTS_UNKNOWN_EXPANSION"
            for _, questInfo in ipairs(quests) do
                local questKey = questInfo.questId
                    or (questInfo.questName and self.QuestIdOverrides and self.QuestIdOverrides[questInfo.questName])
                    or questInfo.questName
                if questKey and self.questIndex[questKey] then
                    local existing = self.questZoneFromScrape[questKey]
                    local isDornogalPriority = existing and existing.zoneName == "Dornogal" and zoneName ~= "Dornogal"
                    if not isDornogalPriority then
                        self.questZoneFromScrape[questKey] = {
                            zoneName = zoneName,
                            expansionKey = expansionKey,
                        }
                    end
                end
            end
        end
    end

    -- Secondary source: Parse sourceText from records (fallback for any missed)
    local parsedCount = 0
    for recordID, record in pairs(self.decorRecords) do
        if record.sourceText and record.sourceText ~= "" then
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

    local elapsedMs = math.floor(debugprofilestop() - startTime)
    self:Debug(string.format("Built quest index: %d quests (%d scraped, %d parsed) in %d ms",
        questCount, scrapedCount, parsedCount, elapsedMs))
end

-- Build quest hierarchy (expansion > zone > quests)
function addon:BuildQuestHierarchy()
    local startTime = debugprofilestop()

    -- Clear existing hierarchy
    wipe(self.questHierarchy)

    -- Group quests by expansion and zone
    for questKey in pairs(self.questIndex) do
        local zoneName, expansionKey = GetQuestLocation(questKey)

        -- Initialize expansion entry if needed
        if not self.questHierarchy[expansionKey] then
            self.questHierarchy[expansionKey] = {
                order = EXPANSION_ORDER[expansionKey] or 0,
                zones = {},
            }
        end

        -- Initialize zone entry if needed
        if not self.questHierarchy[expansionKey].zones[zoneName] then
            self.questHierarchy[expansionKey].zones[zoneName] = {}
        end

        -- Add quest to zone
        table.insert(self.questHierarchy[expansionKey].zones[zoneName], questKey)
    end

    -- Helper to get quest difficulty level (only works for numeric IDs)
    local function GetQuestLevel(questKey)
        if type(questKey) ~= "number" then return 0 end
        if not C_QuestLog or not C_QuestLog.GetQuestDifficultyLevel then return 0 end
        return C_QuestLog.GetQuestDifficultyLevel(questKey) or 0
    end

    -- Sort quests within each zone by level then title
    for _, expData in pairs(self.questHierarchy) do
        for _, quests in pairs(expData.zones) do
            table.sort(quests, function(a, b)
                local levelA = GetQuestLevel(a)
                local levelB = GetQuestLevel(b)
                if levelA ~= levelB then return levelA < levelB end

                local titleA = addon.questTitleCache[a] or tostring(a)
                local titleB = addon.questTitleCache[b] or tostring(b)
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

    table.sort(zones)  -- Alphabetical
    return zones
end

-- Get quests for a specific zone
function addon:GetQuestsForZone(expansionKey, zoneName)
    local expData = self.questHierarchy[expansionKey]
    if not expData or not expData.zones[zoneName] then return {} end
    return expData.zones[zoneName]
end

-- Get record IDs for a specific quest
-- questKey can be a numeric questID or a string questName
function addon:GetRecordsForQuest(questKey)
    local records = self.questIndex[questKey]
    if not records then return {} end

    local result = {}
    for recordID in pairs(records) do
        table.insert(result, recordID)
    end
    table.sort(result)  -- Deterministic "(1)", "(2)" order
    return result
end

-- Get collection progress for a quest (owned/total decor items)
-- questKey can be a numeric questID or a string questName
function addon:GetQuestCollectionProgress(questKey)
    local records = self.questIndex[questKey]
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

-- Get collection progress for an expansion
function addon:GetExpansionCollectionProgress(expansionKey)
    local expData = self.questHierarchy[expansionKey]
    if not expData then return 0, 0 end

    local owned, total = 0, 0
    for zoneName in pairs(expData.zones) do
        local zOwned, zTotal = self:GetZoneCollectionProgress(expansionKey, zoneName)
        owned = owned + zOwned
        total = total + zTotal
    end

    return owned, total
end

-- Get quest completion progress for an expansion (completed/total quests)
function addon:GetExpansionQuestCompletionProgress(expansionKey)
    local zones = self.questHierarchy[expansionKey] and self.questHierarchy[expansionKey].zones
    if not zones then return 0, 0 end

    local completed, total = 0, 0
    for zoneName, quests in pairs(zones) do
        for _, questKey in ipairs(quests) do
            total = total + 1
            if self:IsQuestCompleted(questKey) then
                completed = completed + 1
            end
        end
    end
    return completed, total
end

-- Get quest title (with placeholder fallback)
-- questKey can be a numeric questID or a string questName (for quests without IDs)
function addon:GetQuestTitle(questKey)
    if not questKey then return nil end

    -- Check cache first (includes scraped quest names)
    local cached = self.questTitleCache[questKey]
    if cached then return cached end

    -- For string keys, the key itself is the quest name
    if type(questKey) == "string" then
        self.questTitleCache[questKey] = questKey
        return questKey
    end

    -- Try to get title from WoW API for numeric IDs
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(questKey)
        if title and title ~= "" then
            self.questTitleCache[questKey] = title
            return title
        end
    end

    -- Return placeholder
    return string.format(self.L["QUESTS_UNKNOWN_QUEST"], questKey)
end

-- Check if quest is completed (account-wide first, then character)
-- questKey can be a numeric questID or a string questName (for quests without IDs)
function addon:IsQuestCompleted(questKey)
    if not questKey then return false end

    -- Check cache
    local cached = self.questCompletionCache[questKey]
    if cached ~= nil then return cached end

    -- String keys (quests without IDs) cannot be checked via API
    if type(questKey) ~= "number" then
        self.questCompletionCache[questKey] = false
        return false
    end

    -- Numeric quest IDs can be checked via WoW API
    if not C_QuestLog then return false end

    -- Try account-wide first (11.0+), fallback to character
    local isComplete = false
    if C_QuestLog.IsQuestFlaggedCompletedOnAccount then
        isComplete = C_QuestLog.IsQuestFlaggedCompletedOnAccount(questKey)
    end
    if not isComplete and C_QuestLog.IsQuestFlaggedCompleted then
        isComplete = C_QuestLog.IsQuestFlaggedCompleted(questKey)
    end

    self.questCompletionCache[questKey] = isComplete
    return isComplete
end

-- Get total quest count (matches SavedVars pattern)
function addon:GetQuestCount()
    local count = 0
    for _ in pairs(self.questIndex) do count = count + 1 end
    return count
end

-- Handle quest data load completion
addon:RegisterWoWEvent("QUEST_DATA_LOAD_RESULT", function(questID, success)
    if not success then return end
    if not addon.pendingQuestLoads[questID] then return end

    addon.pendingQuestLoads[questID] = nil

    -- Get and cache the title
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title and title ~= "" then
            addon.questTitleCache[questID] = title
            addon:FireEvent("QUEST_TITLE_LOADED", questID, title)
        end
    end
end)

-- Update quest completion cache on quest turn-in
addon:RegisterWoWEvent("QUEST_TURNED_IN", function(questID)
    if addon.questIndex[questID] then
        addon.questCompletionCache[questID] = true
        addon:FireEvent("QUEST_COMPLETION_CHANGED", questID, true)
    end
end)

-- Periodic refresh of completion status (some quests may be completed elsewhere)
addon:RegisterWoWEvent("QUEST_LOG_UPDATE", function()
    if not addon.questIndexBuilt then return end

    -- Only refresh if we have quests indexed
    local hasQuests = next(addon.questIndex) ~= nil
    if not hasQuests then return end

    -- Invalidate completion cache (will be refreshed on next access)
    wipe(addon.questCompletionCache)
    addon:FireEvent("QUEST_COMPLETION_CACHE_INVALIDATED")
end)
