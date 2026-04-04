--[[
    Housing Codex - PvPIndex.lua
    PvP-to-decor index building. Aggregates PvP items from existing
    AchievementData, VendorData, and DropData into a unified hierarchy.
    No data duplication — scans existing sources at runtime.
]]

local _, addon = ...
local L = addon.L

-- PvP source category display info
local PVP_SOURCE_CATEGORY_INFO = {
    ["achievements"] = {
        icon = "Interface\\Icons\\Achievement_General",
        labelKey = "PVP_CATEGORY_ACHIEVEMENTS",
        order = 1,
    },
    ["vendors"] = {
        icon = "Interface\\Icons\\INV_Misc_Coin_02",
        labelKey = "PVP_CATEGORY_VENDORS",
        order = 2,
    },
    ["drops"] = {
        icon = "Interface\\Icons\\INV_Misc_Bag_10_Blue",
        labelKey = "PVP_CATEGORY_DROPS",
        order = 3,
    },
}

-- PvP vendor NPC IDs (manually curated from plan cross-check)
local PVP_VENDOR_NPC_IDS = {
    [254603] = true,  -- Riica (Stormwind, Honor)
    [254606] = true,  -- Joruh (Orgrimmar, Honor)
    [145695] = true,  -- "Bad Luck" Symmes (Brawl'gar Arena)
    [151941] = true,  -- Dershway the Triggered (Deeprun Tram)
    [13217]  = true,  -- Thanthaldis Snowgleam (Hillsbrad)
}

-- Drop source keywords that identify PvP drops
local PVP_DROP_KEYWORDS = { "Voidscar Arena", "Stormarion" }

-- Runtime data structures
addon.pvpHierarchy = {}
addon.pvpIndexBuilt = false
addon.pvpCategoryProgressCache = {}

local function SortBySourceName(a, b)
    return (addon:GetLocalizedSourceName(a.sourceName) or "") < (addon:GetLocalizedSourceName(b.sourceName) or "")
end

function addon:GetPvPSourceCategoryInfo(category)
    return PVP_SOURCE_CATEGORY_INFO[category]
end

function addon:BuildPvPIndex()
    if not self.AchievementSourceData then
        self:Debug("Cannot build PvP index: AchievementSourceData not loaded")
        return
    end

    local startTime = debugprofilestop()

    wipe(self.pvpHierarchy)
    wipe(self.pvpCategoryProgressCache)

    local sourceCount, decorCount = 0, 0

    -- 1. Scan AchievementSourceData for PvP category achievements
    local achievementSources = {}
    for achievementId, achievementData in pairs(self.AchievementSourceData) do
        if achievementData.category == "PvP" and achievementData.decorIds then
            local entry = {
                sourceName    = addon:GetAchievementName(achievementId),
                sourceCategory = "achievements",
                decorIds      = achievementData.decorIds,
                achievementID = achievementId,
            }
            table.insert(achievementSources, entry)
            sourceCount = sourceCount + 1
            decorCount  = decorCount + #entry.decorIds
        end
    end

    if #achievementSources > 0 then
        table.sort(achievementSources, SortBySourceName)
        self.pvpHierarchy["achievements"] = { sources = achievementSources }
    end

    -- 2. Scan VendorSourceData for PvP vendor NPC IDs
    local vendorSources = {}
    local vendorSeen = {}  -- Deduplicate by npcId (vendors appear in multiple zones)

    if self.VendorSourceData then
        for _, zones in pairs(self.VendorSourceData) do
            for zoneName, vendors in pairs(zones) do
                for _, vendorData in ipairs(vendors) do
                    local npcId = vendorData.npcId
                    if npcId and PVP_VENDOR_NPC_IDS[npcId] and not vendorSeen[npcId] then
                        vendorSeen[npcId] = true
                        local entry = {
                            sourceName     = vendorData.npcName or L["UNKNOWN"],
                            sourceCategory = "vendors",
                            decorIds       = vendorData.decorIds or {},
                            npcId          = npcId,
                            zoneName       = zoneName,
                        }
                        table.insert(vendorSources, entry)
                        sourceCount = sourceCount + 1
                        decorCount  = decorCount + #entry.decorIds
                    end
                end
            end
        end
    end

    if #vendorSources > 0 then
        table.sort(vendorSources, SortBySourceName)
        self.pvpHierarchy["vendors"] = { sources = vendorSources }
    end

    -- 3. Scan DropSourceData["encounter"] and ["drop"] for PvP drop keywords
    local dropSources = {}

    for _, dropCategory in ipairs({"encounter", "drop"}) do
        if self.DropSourceData and self.DropSourceData[dropCategory] then
            for _, sourceData in ipairs(self.DropSourceData[dropCategory]) do
                local name = sourceData.sourceName or ""
                for _, keyword in ipairs(PVP_DROP_KEYWORDS) do
                    if name:find(keyword, 1, true) then
                        local entry = {
                            sourceName     = name ~= "" and name or L["UNKNOWN"],
                            sourceCategory = "drops",
                            decorIds       = sourceData.decorIds or {},
                        }
                        table.insert(dropSources, entry)
                        sourceCount = sourceCount + 1
                        decorCount  = decorCount + #entry.decorIds
                        break
                    end
                end
            end
        end
    end

    if #dropSources > 0 then
        table.sort(dropSources, SortBySourceName)
        self.pvpHierarchy["drops"] = { sources = dropSources }
    end

    self.pvpIndexBuilt = true
    wipe(self.pvpCategoryProgressCache)

    self:Debug(string.format("Built PvP index: %d sources, %d decor items in %d ms",
        sourceCount, decorCount, math.floor(debugprofilestop() - startTime)))
end

function addon:GetSortedPvPCategories()
    local categories = {}
    for category in pairs(self.pvpHierarchy) do
        table.insert(categories, category)
    end
    table.sort(categories, function(a, b)
        local aInfo = PVP_SOURCE_CATEGORY_INFO[a]
        local bInfo = PVP_SOURCE_CATEGORY_INFO[b]
        return (aInfo and aInfo.order or 99) < (bInfo and bInfo.order or 99)
    end)
    return categories
end

function addon:GetPvPSourcesForCategory(category)
    local catData = self.pvpHierarchy[category]
    return catData and catData.sources or {}
end

function addon:GetPvPCategoryCollectionProgress(category)
    local cached = self.pvpCategoryProgressCache[category]
    if cached then return cached.owned, cached.total end

    local owned, total = 0, 0
    local seen = {}
    for _, source in ipairs(self:GetPvPSourcesForCategory(category)) do
        for _, decorId in ipairs(source.decorIds or {}) do
            if not seen[decorId] then
                seen[decorId] = true
                total = total + 1
                if self:IsDecorCollected(decorId) then owned = owned + 1 end
            end
        end
    end

    self.pvpCategoryProgressCache[category] = { owned = owned, total = total }
    return owned, total
end

function addon:GetPvPSourceCount()
    local count = 0
    for _, catData in pairs(self.pvpHierarchy) do
        count = count + #catData.sources
    end
    return count
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
    wipe(addon.pvpCategoryProgressCache)
end)
