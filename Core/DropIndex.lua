--[[
    Housing Codex - DropIndex.lua
    Drop-to-decor index building and hierarchy management.
    Data is flat: category → list of sources (no zone/expansion hierarchy).
    WowDB provides source names (boss names, event names) but not NPC IDs or zones.
]]

local _, addon = ...
local L = addon.L

-- Source category display info
local SOURCE_CATEGORY_INFO = {
    ["drop"] = {
        icon = "Interface\\Icons\\INV_Misc_Bag_10_Blue",
        labelKey = "DROPS_CATEGORY_DROP",
        order = 1,
    },
    ["encounter"] = {
        icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        labelKey = "DROPS_CATEGORY_ENCOUNTER",
        order = 2,
    },
    ["treasure"] = {
        icon = "Interface\\Icons\\INV_Misc_TreasureChest04a",
        labelKey = "DROPS_CATEGORY_TREASURE",
        order = 3,
    },
}

-- Runtime data structures
-- dropHierarchy[category] = { sources = { { sourceName, sourceCategory, decorIds } } }
addon.dropHierarchy = {}
addon.dropIndexBuilt = false
addon.dropCategoryProgressCache = {}

function addon:GetSourceCategoryInfo(category)
    return SOURCE_CATEGORY_INFO[category]
end

function addon:BuildDropIndex()
    if not self.DropSourceData then
        self:Debug("Cannot build drop index: DropSourceData not loaded")
        return
    end

    local startTime = debugprofilestop()

    wipe(self.dropHierarchy)
    wipe(self.dropCategoryProgressCache)

    local sourceCount, decorCount = 0, 0

    for category, sources in pairs(self.DropSourceData) do
        self.dropHierarchy[category] = { sources = {} }

        for _, sourceData in ipairs(sources) do
            local entry = {
                sourceName = sourceData.sourceName or L["UNKNOWN"],
                sourceCategory = category,
                decorIds = sourceData.decorIds or {},
            }

            table.insert(self.dropHierarchy[category].sources, entry)
            sourceCount = sourceCount + 1
            decorCount = decorCount + #entry.decorIds
        end

        -- Sort sources alphabetically within each category
        table.sort(self.dropHierarchy[category].sources, function(a, b)
            return (addon:GetLocalizedSourceName(a.sourceName) or "") < (addon:GetLocalizedSourceName(b.sourceName) or "")
        end)

        -- Remove empty categories after filtering
        if #self.dropHierarchy[category].sources == 0 then
            self.dropHierarchy[category] = nil
        end
    end

    -- Enrich empty sourceText on records with drop source names
    local enriched = 0
    if self.decorRecords then
        for category, sources in pairs(self.DropSourceData) do
            for _, sourceData in ipairs(sources) do
                local displayName = self:GetLocalizedSourceName(sourceData.sourceName) or sourceData.sourceName
                if displayName then
                    for _, decorId in ipairs(sourceData.decorIds or {}) do
                        local record = self.decorRecords[decorId]
                        if record and (not record.sourceText or record.sourceText == "") then
                            record.sourceText = displayName
                            enriched = enriched + 1
                        end
                    end
                end
            end
        end
    end

    self.dropIndexBuilt = true

    self:Debug(string.format("Built drop index: %d sources, %d decor items (%d sourceText enriched) in %d ms",
        sourceCount, decorCount, enriched, math.floor(debugprofilestop() - startTime)))
end

function addon:GetSortedDropCategories()
    local categories = {}
    for category in pairs(self.dropHierarchy) do
        table.insert(categories, category)
    end
    table.sort(categories, function(a, b)
        local aInfo = SOURCE_CATEGORY_INFO[a]
        local bInfo = SOURCE_CATEGORY_INFO[b]
        return (aInfo and aInfo.order or 99) < (bInfo and bInfo.order or 99)
    end)
    return categories
end

function addon:GetDropsForCategory(category)
    local catData = self.dropHierarchy[category]
    return catData and catData.sources or {}
end

function addon:GetDropSourceCollectionProgress(source)
    local owned, total = 0, 0
    for _, decorId in ipairs(source.decorIds or {}) do
        total = total + 1
        if self:IsDecorCollected(decorId) then
            owned = owned + 1
        end
    end
    return owned, total
end

function addon:GetDropCategoryCollectionProgress(category)
    local cached = self.dropCategoryProgressCache[category]
    if cached then return cached.owned, cached.total end

    local owned, total = 0, 0
    for _, source in ipairs(self:GetDropsForCategory(category)) do
        local sOwned, sTotal = self:GetDropSourceCollectionProgress(source)
        owned, total = owned + sOwned, total + sTotal
    end

    self.dropCategoryProgressCache[category] = { owned = owned, total = total }
    return owned, total
end

function addon:GetDropCount()
    local count = 0
    for _, catData in pairs(self.dropHierarchy) do
        count = count + #catData.sources
    end
    return count
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
    wipe(addon.dropCategoryProgressCache)
end)
