--[[
    Housing Codex - RenownIndex.lua
    Reputation-to-decor index building. Groups factions by expansion,
    resolves live standing via WoW API.
    Cross-references vendor NPCs against VendorSourceData for real decorIds.
]]

local _, addon = ...
local L = addon.L

-- Standing labels indexed by reaction (luaIndex 1-8: Hated→Exalted)
local STANDING_LABELS = {
    "STANDING_HATED", "STANDING_HOSTILE", "STANDING_UNFRIENDLY", "STANDING_NEUTRAL",
    "STANDING_FRIENDLY", "STANDING_HONORED", "STANDING_REVERED", "STANDING_EXALTED",
}

-- Standing name → reaction luaIndex for requirement comparison (English names from RenownSourceData)
local STANDING_REACTION = {
    ["Hated"] = 1, ["Hostile"] = 2, ["Unfriendly"] = 3, ["Neutral"] = 4,
    ["Friendly"] = 5, ["Honored"] = 6, ["Revered"] = 7, ["Exalted"] = 8,
}

-- Runtime data structures
addon.renownHierarchy = {}         -- { [expansionKey] = { factions = {...} } }
addon.renownIndexBuilt = false
addon.renownProgressCache = {}     -- { [factionID] = { owned, total } }
addon.renownStandingCache = {}     -- { [factionID] = standing info }

-- NPC ID → decorIds lookup built from VendorSourceData
local vendorNPCDecorLookup = nil   -- { [npcId] = { decorId1, decorId2, ... } }

--------------------------------------------------------------------------------
-- Vendor Cross-Reference
--------------------------------------------------------------------------------

local function BuildVendorNPCLookup()
    if vendorNPCDecorLookup then return end
    vendorNPCDecorLookup = {}

    if not addon.VendorSourceData then return end

    for _, zones in pairs(addon.VendorSourceData) do
        for _, vendors in pairs(zones) do
            for _, vendorData in ipairs(vendors) do
                local npcId = vendorData.npcId
                if npcId and vendorData.decorIds then
                    local existing = vendorNPCDecorLookup[npcId]
                    if not existing then
                        existing = {}
                        vendorNPCDecorLookup[npcId] = existing
                    end
                    local seen = {}
                    for _, id in ipairs(existing) do seen[id] = true end
                    for _, decorId in ipairs(vendorData.decorIds) do
                        if not seen[decorId] then
                            existing[#existing + 1] = decorId
                            seen[decorId] = true
                        end
                    end
                end
            end
        end
    end
end

local function ResolveDecorEntriesForFaction(factionData)
    BuildVendorNPCLookup()

    local entries = {}   -- { { decorId = N, requiredStanding = "Standing" }, ... }
    local plainIds = {}  -- parallel plain list for progress tracking
    local seen = {}

    -- First: check static rewards for pre-populated decorIds with per-item standing
    if factionData.rewards then
        for _, reward in ipairs(factionData.rewards) do
            if reward.decorId and not seen[reward.decorId] then
                table.insert(entries, { decorId = reward.decorId, requiredStanding = reward.requiredStanding, requiredRankLevel = reward.requiredRankLevel })
                table.insert(plainIds, reward.decorId)
                seen[reward.decorId] = true
            end
        end
    end

    -- Second: cross-reference vendor NPC IDs against VendorSourceData
    -- These items get the faction-level requiredStanding (per-item unknown until scraper runs)
    local factionReq = factionData.requiredStanding
    if factionData.vendors and vendorNPCDecorLookup then
        for _, vendor in ipairs(factionData.vendors) do
            local npcDecors = vendorNPCDecorLookup[vendor.npcId]
            if npcDecors then
                for _, decorId in ipairs(npcDecors) do
                    if not seen[decorId] then
                        table.insert(entries, { decorId = decorId, requiredStanding = factionReq })
                        table.insert(plainIds, decorId)
                        seen[decorId] = true
                    end
                end
            end
        end
    end

    return entries, plainIds
end

--------------------------------------------------------------------------------
-- Standing Resolution
-- Note: All rep APIs have SecretArguments=AllowedWhenUntainted.
-- Call sites (timers, event handlers) are untainted; do not call from
-- tainted click/hook contexts.
--------------------------------------------------------------------------------

local function GetStandardStanding(factionID)
    local data = C_Reputation.GetFactionDataByID(factionID)
    if not data then return nil end

    local reaction = data.reaction  -- luaIndex 1-8
    local labelKey = STANDING_LABELS[reaction]
    local standingText = labelKey and L[labelKey] or L["STANDING_NEUTRAL"]
    local currentValue = data.currentStanding or 0
    local minValue = data.currentReactionThreshold or 0
    local maxValue = data.nextReactionThreshold or 1
    local range = maxValue - minValue
    local progressMax = range > 0 and range or 1
    local progress = range > 0 and (currentValue - minValue) or 0
    local isMaxed = reaction == 8  -- Exalted
    local progressPct = math.floor(progress / progressMax * 100)

    return {
        standingText = standingText,
        reaction = reaction,
        currentValue = progress,
        maxValue = progressMax,
        progressPct = progressPct,
        isMaxed = isMaxed,
        isUnlocked = true,
        isAccountWide = data.isAccountWide or false,
    }
end

local function GetRenownStanding(factionID)
    local data = C_MajorFactions.GetMajorFactionData(factionID)
    if not data then return nil end

    if not data.isUnlocked then
        return {
            standingText = L["RENOWN_LOCKED"],
            currentValue = 0,
            maxValue = 1,
            progressPct = 0,
            isMaxed = false,
            isUnlocked = false,
            isAccountWide = false,
        }
    end

    local hasMax = C_MajorFactions.HasMaximumRenown(factionID)
    local earned = data.renownReputationEarned or 0
    local threshold = data.renownLevelThreshold or 1
    local progressPct = hasMax and 100 or math.floor(earned / threshold * 100)

    return {
        standingText = "Renown " .. (data.renownLevel or 0),
        currentValue = earned,
        maxValue = threshold,
        progressPct = progressPct,
        isMaxed = hasMax,
        isUnlocked = true,
        isAccountWide = false,
    }
end

local function GetFriendshipStanding(factionID)
    local repInfo = C_GossipInfo.GetFriendshipReputation(factionID)
    if not repInfo or repInfo.friendshipFactionID == 0 then return nil end

    local rankInfo = C_GossipInfo.GetFriendshipReputationRanks(repInfo.friendshipFactionID)
    local standingText = repInfo.reaction or L["STANDING_NEUTRAL"]
    local currentValue = repInfo.standing or 0

    -- Use nextThreshold (current rank ceiling), not maxRep (lifetime faction cap)
    -- Matches Blizzard FriendshipStatusBar.lua:72
    local maxValue = repInfo.nextThreshold or 0
    local minValue = repInfo.reactionThreshold or 0

    local range = maxValue > 0 and (maxValue - minValue) or 1
    local progress = maxValue > 0 and (currentValue - minValue) or 0
    -- Nil nextThreshold is definitive max-rank signal (Blizzard FriendshipStatusBar.lua:50)
    local isMaxed = repInfo.nextThreshold == nil
        or (rankInfo and rankInfo.currentLevel ~= nil and rankInfo.currentLevel == rankInfo.maxLevel)
    local progressPct = isMaxed and 100 or math.floor(progress / range * 100)

    return {
        standingText = standingText,
        currentValue = progress,
        maxValue = range,
        progressPct = progressPct,
        isMaxed = isMaxed,
        isUnlocked = true,
        isAccountWide = false,
        currentRankLevel = rankInfo and rankInfo.currentLevel or nil,
    }
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function addon:HasMetStandingRequirement(factionID)
    local sourceData = self.RenownSourceData and self.RenownSourceData[factionID]
    if not sourceData or not sourceData.requiredStanding then return false end

    local standing = self:GetFactionStandingInfo(factionID)
    if not standing or not standing.isUnlocked then return false end

    local required = sourceData.requiredStanding
    local kind = sourceData.kind

    if kind == "standard" then
        -- Compare reaction values: Friendly=5, Honored=6, Revered=7, Exalted=8
        local reqReaction = STANDING_REACTION[required]
        local curReaction = standing.reaction
        if reqReaction and curReaction then
            return curReaction >= reqReaction
        end
        return standing.isMaxed
    elseif kind == "renown" then
        -- Parse "Renown X" from both required and current
        local reqLevel = tonumber(required:match("%d+"))
        local curLevel = tonumber(standing.standingText:match("%d+"))
        if reqLevel and curLevel then
            return curLevel >= reqLevel
        end
        return standing.isMaxed
    elseif kind == "friendship" then
        local reqLevel = sourceData.requiredRankLevel or tonumber(required:match("%d+"))
        if reqLevel and standing.currentRankLevel then
            return standing.currentRankLevel >= reqLevel
        end
        return standing.isMaxed
    end

    return false
end

function addon:HasMetItemStandingRequirement(factionID, itemReqStanding, requiredRankLevel)
    if not itemReqStanding then return true end

    local standing = self:GetFactionStandingInfo(factionID)
    if not standing or not standing.isUnlocked then return false end

    local sourceData = self.RenownSourceData and self.RenownSourceData[factionID]
    if not sourceData then return false end

    local kind = sourceData.kind
    if kind == "standard" then
        local reqReaction = STANDING_REACTION[itemReqStanding]
        local curReaction = standing.reaction
        if reqReaction and curReaction then
            return curReaction >= reqReaction
        end
        return standing.isMaxed
    elseif kind == "renown" then
        local reqLevel = tonumber(itemReqStanding:match("%d+"))
        local curLevel = tonumber(standing.standingText:match("%d+"))
        if reqLevel and curLevel then
            return curLevel >= reqLevel
        end
        return standing.isMaxed
    elseif kind == "friendship" then
        local reqLevel = requiredRankLevel or tonumber(itemReqStanding:match("%d+"))
        if reqLevel and standing.currentRankLevel then
            return standing.currentRankLevel >= reqLevel
        end
        return standing.isMaxed
    end
    return standing.isMaxed
end

function addon:GetFactionStandingInfo(factionID)
    local cached = self.renownStandingCache[factionID]
    if cached then return cached end

    local sourceData = self.RenownSourceData and self.RenownSourceData[factionID]
    if not sourceData then return nil end

    local info
    if sourceData.kind == "renown" then
        info = GetRenownStanding(factionID)
    elseif sourceData.kind == "friendship" then
        info = GetFriendshipStanding(factionID)
    else
        info = GetStandardStanding(factionID)
    end

    if info then
        self.renownStandingCache[factionID] = info
    end
    return info
end

function addon:BuildRenownIndex()
    if not self.RenownSourceData then
        self:Debug("Cannot build Renown index: RenownSourceData not loaded")
        return
    end

    local startTime = debugprofilestop()

    wipe(self.renownHierarchy)
    wipe(self.renownProgressCache)
    wipe(self.renownStandingCache)
    vendorNPCDecorLookup = nil  -- Force rebuild on next access

    local factionCount, resolvedCount = 0, 0

    for factionID, factionData in pairs(self.RenownSourceData) do
        local expKey = factionData.expansionKey
        if expKey then
            if not self.renownHierarchy[expKey] then
                self.renownHierarchy[expKey] = { factions = {} }
            end

            local resolvedDecorEntries, resolvedDecorIds = ResolveDecorEntriesForFaction(factionData)

            table.insert(self.renownHierarchy[expKey].factions, {
                factionID = factionID,
                label = factionData.label,
                kind = factionData.kind,
                factionSide = factionData.factionSide,
                group = factionData.group,
                rewards = factionData.rewards,
                vendors = factionData.vendors,
                resolvedDecorEntries = resolvedDecorEntries,
                resolvedDecorIds = resolvedDecorIds,
            })
            factionCount = factionCount + 1
            if #resolvedDecorIds > 0 then
                resolvedCount = resolvedCount + 1
            end
        end
    end

    -- Sort factions within each expansion alphabetically
    for _, expData in pairs(self.renownHierarchy) do
        table.sort(expData.factions, function(a, b)
            return (a.label or "") < (b.label or "")
        end)
    end

    self.renownIndexBuilt = true

    self:Debug(string.format("Built Renown index: %d factions (%d with resolved decor) in %d ms",
        factionCount, resolvedCount, math.floor(debugprofilestop() - startTime)))
end

function addon:GetSortedRenownExpansions()
    local expansions = {}
    local order = self.CONSTANTS.EXPANSION_ORDER

    for expKey in pairs(self.renownHierarchy) do
        table.insert(expansions, expKey)
    end

    -- Sort newest first (highest order first)
    table.sort(expansions, function(a, b)
        return (order[a] or 0) > (order[b] or 0)
    end)

    return expansions
end

function addon:GetFactionsForExpansion(expKey)
    local expData = self.renownHierarchy[expKey]
    return expData and expData.factions or {}
end

function addon:GetFactionRewardProgress(factionID)
    local cached = self.renownProgressCache[factionID]
    if cached then return cached.owned, cached.total end

    local decorIds
    for _, expData in pairs(self.renownHierarchy) do
        for _, faction in ipairs(expData.factions) do
            if faction.factionID == factionID then
                decorIds = faction.resolvedDecorIds
            end
        end
        if decorIds then break end
    end

    if not decorIds or #decorIds == 0 then
        self.renownProgressCache[factionID] = { owned = 0, total = 0 }
        return 0, 0
    end

    local owned, total = 0, 0
    for _, decorId in ipairs(decorIds) do
        -- Only count items that the housing catalog can resolve
        if self:ResolveRecord(decorId) then
            total = total + 1
            if self:IsDecorCollected(decorId) then
                owned = owned + 1
            end
        end
    end

    self.renownProgressCache[factionID] = { owned = owned, total = total }
    return owned, total
end

function addon:GetRenownExpansionProgress(expKey)
    local owned, total = 0, 0
    for _, faction in ipairs(self:GetFactionsForExpansion(expKey)) do
        local fOwned, fTotal = self:GetFactionRewardProgress(faction.factionID)
        owned = owned + fOwned
        total = total + fTotal
    end
    return owned, total
end

function addon:GetRenownFactionCount()
    local count = 0
    for _, expData in pairs(self.renownHierarchy) do
        count = count + #expData.factions
    end
    return count
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

addon:RegisterInternalEvent("RECORD_OWNERSHIP_UPDATED", function()
    wipe(addon.renownProgressCache)
end)
