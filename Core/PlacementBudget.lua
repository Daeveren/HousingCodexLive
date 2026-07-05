--[[
    Housing Codex - PlacementBudget.lua
    Decor placement budget snapshots for the Progress sidebar.
]]

local _, addon = ...

local CONTEXT_INTERIOR = "interior"
local CONTEXT_PLOT = "plot"
local CONTEXT_OUTDOOR = "outdoor"
local CONTEXT_PLOTS_BY_ID = "plotsByID"
local CONTEXT_KNOWN_PLOTS = "knownPlots"
local levelRequestTimes = {}
local MergeDuplicateNoGUIDRows

local function IsValidSnapshot(snapshot)
    return type(snapshot) == "table"
        and type(snapshot.spent) == "number"
        and type(snapshot.max) == "number"
        and type(snapshot.updatedAt) == "number"
        and snapshot.max > 0
end

local function IsValidHouseLevelSnapshot(snapshot)
    return type(snapshot) == "table"
        and type(snapshot.level) == "number"
        and snapshot.level > 0
        and type(snapshot.updatedAt) == "number"
end

local function NormalizeBudgetMap(budgets)
    if type(budgets) ~= "table" then
        return {}
    end

    for context, snapshot in pairs(budgets) do
        if (context ~= CONTEXT_OUTDOOR and context ~= CONTEXT_INTERIOR) or not IsValidSnapshot(snapshot) then
            budgets[context] = nil
        end
    end

    return budgets
end

local function NormalizePlotsByID(db)
    if type(db[CONTEXT_PLOTS_BY_ID]) ~= "table" then
        db[CONTEXT_PLOTS_BY_ID] = {}
    end

    local plotsByID = db[CONTEXT_PLOTS_BY_ID]
    for plotID, snapshot in pairs(plotsByID) do
        if type(plotID) ~= "string" or not IsValidSnapshot(snapshot) then
            plotsByID[plotID] = nil
        end
    end

    return plotsByID
end

local function IsValidKnownPlot(plotInfo)
    return type(plotInfo) == "table" and type(plotInfo.plotID) == "number"
end

local function NormalizeKnownPlots(db)
    if type(db[CONTEXT_KNOWN_PLOTS]) ~= "table" then
        db[CONTEXT_KNOWN_PLOTS] = {}
    end

    local knownPlots = db[CONTEXT_KNOWN_PLOTS]
    local changed = false
    for plotID, plotInfo in pairs(knownPlots) do
        if type(plotID) ~= "string" or not IsValidKnownPlot(plotInfo) then
            knownPlots[plotID] = nil
            changed = true
        else
            plotInfo.budgets = NormalizeBudgetMap(plotInfo.budgets)
            if plotInfo.houseLevel ~= nil and not IsValidHouseLevelSnapshot(plotInfo.houseLevel) then
                plotInfo.houseLevel = nil
                changed = true
            end
            if plotInfo.levelRequestedAt ~= nil then
                plotInfo.levelRequestedAt = nil
                changed = true
            end
        end
    end
    if MergeDuplicateNoGUIDRows then
        changed = MergeDuplicateNoGUIDRows(knownPlots) or changed
    end

    return knownPlots, changed
end

local function FindKnownPlotByPlotID(knownPlots, plotID)
    local numericPlotID = tonumber(plotID)
    if not numericPlotID then return nil end

    local fallback = knownPlots[plotID]
    for _, plotInfo in pairs(knownPlots) do
        if type(plotInfo) == "table" and plotInfo.plotID == numericPlotID then
            if plotInfo.houseGUID ~= nil and plotInfo.houseGUID ~= "" then
                return plotInfo
            end
            fallback = fallback or plotInfo
        end
    end
    return fallback
end

local function GetBudgetDB()
    if not addon.db then return nil end
    if type(addon.db.placementBudget) ~= "table" then
        addon.db.placementBudget = {}
    end

    local db = addon.db.placementBudget
    for context, snapshot in pairs(db) do
        if context ~= CONTEXT_PLOTS_BY_ID and context ~= CONTEXT_KNOWN_PLOTS then
            if (context ~= CONTEXT_INTERIOR and context ~= CONTEXT_PLOT) or not IsValidSnapshot(snapshot) then
                db[context] = nil
            end
        end
    end

    local plotsByID = NormalizePlotsByID(db)
    local knownPlots, normalizedChanged = NormalizeKnownPlots(db)
    for plotID, snapshot in pairs(plotsByID) do
        local plotInfo = FindKnownPlotByPlotID(knownPlots, plotID)
        if plotInfo and not IsValidSnapshot(plotInfo.budgets[CONTEXT_OUTDOOR]) then
            plotInfo.budgets[CONTEXT_OUTDOOR] = snapshot
            normalizedChanged = true
        end
    end

    return db, normalizedChanged
end

local function GetCurrentContext()
    if not C_Housing then return nil end
    if C_Housing.IsInsideHouse and C_Housing.IsInsideHouse() then
        return CONTEXT_INTERIOR
    end
    if C_Housing.IsInsidePlot and C_Housing.IsInsidePlot() then
        return CONTEXT_OUTDOOR
    end
    return nil
end

local function GetPlotKey(plotID, neighborhoodGUID)
    if type(plotID) ~= "number" then return nil end
    if neighborhoodGUID ~= nil and neighborhoodGUID ~= "" then
        return "neighborhood:" .. tostring(neighborhoodGUID) .. ":plot:" .. tostring(math.floor(plotID))
    end
    return nil
end

local function GetHouseKey(houseInfo)
    if type(houseInfo) ~= "table" then return nil end
    if houseInfo.houseGUID ~= nil and houseInfo.houseGUID ~= "" then
        return "house:" .. tostring(houseInfo.houseGUID)
    end
    return GetPlotKey(houseInfo.plotID, houseInfo.neighborhoodGUID)
end

local function HasHouseGUID(plotInfo)
    return type(plotInfo) == "table" and plotInfo.houseGUID ~= nil and plotInfo.houseGUID ~= ""
end

local function HasMatchingNeighborhood(plotInfo, neighborhoodGUID)
    if neighborhoodGUID == nil or neighborhoodGUID == "" then return true end
    return plotInfo.neighborhoodGUID == nil or plotInfo.neighborhoodGUID == "" or plotInfo.neighborhoodGUID == neighborhoodGUID
end

local function FindNoGUIDPlotByPlotID(knownPlots, plotID, neighborhoodGUID)
    for key, plotInfo in pairs(knownPlots) do
        if type(plotInfo) == "table" and plotInfo.plotID == plotID and not HasHouseGUID(plotInfo) and HasMatchingNeighborhood(plotInfo, neighborhoodGUID) then
            return key, plotInfo
        end
    end
    return nil, nil
end

local function CopyFieldIfMissing(target, source, field)
    if target[field] == nil and source[field] ~= nil then
        target[field] = source[field]
        return true
    end
    return false
end

local function MergeNoGUIDPlotInfo(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then return false end

    local changed = false
    target.budgets = NormalizeBudgetMap(target.budgets)
    local sourceBudgets = NormalizeBudgetMap(source.budgets)
    for context, snapshot in pairs(sourceBudgets) do
        if not IsValidSnapshot(target.budgets[context]) then
            target.budgets[context] = snapshot
            changed = true
        end
    end

    for _, field in ipairs({ "visited", "discoveredAt", "factionTag", "factionName", "houseName", "ownerName", "neighborhoodName", "neighborhoodGUID" }) do
        changed = CopyFieldIfMissing(target, source, field) or changed
    end

    return changed
end

local function GetPlotNeighborhoodIdentityKey(plotInfo)
    if type(plotInfo) ~= "table" or type(plotInfo.plotID) ~= "number" then return nil end
    if plotInfo.neighborhoodGUID == nil or plotInfo.neighborhoodGUID == "" then return nil end
    return tostring(math.floor(plotInfo.plotID)) .. "\001" .. tostring(plotInfo.neighborhoodGUID)
end

local function MergeNoGUIDRows(knownPlots, targetKey, sourceKey)
    if targetKey == sourceKey then return false end
    local target = knownPlots[targetKey]
    local source = knownPlots[sourceKey]
    if type(target) ~= "table" or type(source) ~= "table" then return false end

    MergeNoGUIDPlotInfo(target, source)
    knownPlots[sourceKey] = nil
    return true
end

MergeDuplicateNoGUIDRows = function(knownPlots)
    local scopedByIdentity = {}
    local bareKeys = {}
    local changed = false

    for key, plotInfo in pairs(knownPlots) do
        if type(plotInfo) == "table" and type(plotInfo.plotID) == "number" and not HasHouseGUID(plotInfo) then
            local identityKey = GetPlotNeighborhoodIdentityKey(plotInfo)
            if identityKey then
                local canonicalKey = GetPlotKey(plotInfo.plotID, plotInfo.neighborhoodGUID)
                local existingKey = scopedByIdentity[identityKey]
                if existingKey and knownPlots[existingKey] then
                    local targetKey = existingKey
                    if key == canonicalKey then
                        targetKey = key
                    end
                    local sourceKey = targetKey == key and existingKey or key
                    changed = MergeNoGUIDRows(knownPlots, targetKey, sourceKey) or changed
                    scopedByIdentity[identityKey] = targetKey
                else
                    scopedByIdentity[identityKey] = key
                end
            else
                bareKeys[#bareKeys + 1] = key
            end
        end
    end

    for _, bareKey in ipairs(bareKeys) do
        local bareInfo = knownPlots[bareKey]
        if type(bareInfo) == "table" and type(bareInfo.plotID) == "number" and not HasHouseGUID(bareInfo) then
            local matchKey
            local ambiguous = false
            for _, scopedKey in pairs(scopedByIdentity) do
                local scopedInfo = knownPlots[scopedKey]
                if type(scopedInfo) == "table" and scopedInfo.plotID == bareInfo.plotID then
                    if matchKey and matchKey ~= scopedKey then
                        ambiguous = true
                        break
                    end
                    matchKey = scopedKey
                end
            end
            if matchKey and not ambiguous then
                changed = MergeNoGUIDRows(knownPlots, matchKey, bareKey) or changed
            end
        end
    end

    return changed
end

local function PruneSamePlotNoGUIDRows(knownPlots, plotKey, plotInfo, plotID, houseGUID, neighborhoodGUID)
    if houseGUID == nil or houseGUID == "" then return false end

    local changed = false
    for otherKey, otherInfo in pairs(knownPlots) do
        if otherKey ~= plotKey and type(otherInfo) == "table" and otherInfo.plotID == plotID and not HasHouseGUID(otherInfo) and HasMatchingNeighborhood(otherInfo, neighborhoodGUID) then
            changed = MergeNoGUIDPlotInfo(plotInfo, otherInfo) or changed
            knownPlots[otherKey] = nil
            changed = true
        end
    end
    return changed
end

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function GetCurrentFactionInfo()
    if type(UnitFactionGroup) ~= "function" then return nil, nil end

    local ok, factionTag, localizedFaction = pcall(UnitFactionGroup, "player")
    if not ok or IsSecretValue(factionTag) or IsSecretValue(localizedFaction) then return nil, nil end
    if factionTag ~= "Alliance" and factionTag ~= "Horde" then return nil, nil end
    if type(localizedFaction) ~= "string" or localizedFaction == "" then
        localizedFaction = nil
    end

    return factionTag, localizedFaction
end

local function RememberHouseInfo(db, houseInfo, markVisited)
    if type(houseInfo) ~= "table" then return nil, false end

    local normalizedPlotID = type(houseInfo.plotID) == "number" and math.floor(houseInfo.plotID) or nil
    if not normalizedPlotID then return nil, false end

    local plotKey = GetHouseKey(houseInfo)
    if not plotKey then return nil, false end

    local knownPlots = NormalizeKnownPlots(db)
    local plotInfo = knownPlots[plotKey]
    local changed = false
    if not IsValidKnownPlot(plotInfo) and HasHouseGUID(houseInfo) then
        local previousKey, previousInfo = FindNoGUIDPlotByPlotID(knownPlots, normalizedPlotID, houseInfo.neighborhoodGUID)
        if previousKey then
            knownPlots[previousKey] = nil
            plotInfo = previousInfo
            knownPlots[plotKey] = plotInfo
            changed = true
        end
    end
    if not IsValidKnownPlot(plotInfo) then
        plotInfo = {
            plotID = normalizedPlotID,
            budgets = {},
        }
        knownPlots[plotKey] = plotInfo
        changed = true
    end

    if plotInfo.plotID ~= normalizedPlotID then
        plotInfo.plotID = normalizedPlotID
        changed = true
    end

    if plotInfo.houseName ~= houseInfo.houseName then
        plotInfo.houseName = houseInfo.houseName
        changed = true
    end
    if plotInfo.ownerName ~= houseInfo.ownerName then
        plotInfo.ownerName = houseInfo.ownerName
        changed = true
    end
    if plotInfo.neighborhoodName ~= houseInfo.neighborhoodName then
        plotInfo.neighborhoodName = houseInfo.neighborhoodName
        changed = true
    end
    if plotInfo.neighborhoodGUID ~= houseInfo.neighborhoodGUID then
        plotInfo.neighborhoodGUID = houseInfo.neighborhoodGUID
        changed = true
    end
    if plotInfo.houseGUID ~= houseInfo.houseGUID then
        local previousHouseGUID = plotInfo.houseGUID
        plotInfo.houseGUID = houseInfo.houseGUID
        if previousHouseGUID ~= nil and previousHouseGUID ~= "" and houseInfo.houseGUID ~= nil and houseInfo.houseGUID ~= "" then
            plotInfo.houseLevel = nil
            plotInfo.budgets = {}
        end
        changed = true
    end

    if markVisited and not plotInfo.visited then
        plotInfo.visited = true
        changed = true
    end
    if markVisited and type(plotInfo.discoveredAt) ~= "number" then
        local now = GetServerTime and GetServerTime()
        if type(now) == "number" then
            plotInfo.discoveredAt = now
            changed = true
        end
    end

    if markVisited then
        local factionTag, factionName = GetCurrentFactionInfo()
        if factionTag and plotInfo.factionTag ~= factionTag then
            plotInfo.factionTag = factionTag
            changed = true
        end
        if factionName and plotInfo.factionName ~= factionName then
            plotInfo.factionName = factionName
            changed = true
        end
    end

    plotInfo.budgets = NormalizeBudgetMap(plotInfo.budgets)
    changed = PruneSamePlotNoGUIDRows(knownPlots, plotKey, plotInfo, normalizedPlotID, houseInfo.houseGUID, houseInfo.neighborhoodGUID) or changed
    return plotKey, changed
end

local function RememberCurrentHouseInfo(db, markVisited)
    if not C_Housing or not C_Housing.GetCurrentHouseInfo then return nil, false end
    return RememberHouseInfo(db, C_Housing.GetCurrentHouseInfo(), markVisited)
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, result = pcall(func, ...)
    if ok then return result end
    return nil
end

local function RequestHouseLevelFavor(plotInfo, force)
    if type(plotInfo) ~= "table" or not plotInfo.houseGUID then return end
    if not C_Housing or not C_Housing.GetCurrentHouseLevelFavor then return end

    local now = GetServerTime and GetServerTime()
    if not force and type(now) == "number" and type(levelRequestTimes[plotInfo.houseGUID]) == "number" and now - levelRequestTimes[plotInfo.houseGUID] < 15 then
        return
    end

    if type(now) == "number" then
        levelRequestTimes[plotInfo.houseGUID] = now
    end
    SafeCall(C_Housing.GetCurrentHouseLevelFavor, plotInfo.houseGUID)
end

local function CalculateHouseLevelSnapshot(houseLevelFavor)
    if type(houseLevelFavor) ~= "table" then return nil end
    local level = houseLevelFavor.houseLevel
    local totalFavor = houseLevelFavor.houseFavor
    if type(level) ~= "number" or type(totalFavor) ~= "number" or level <= 0 then return nil end

    local now = GetServerTime and GetServerTime()
    if type(now) ~= "number" then return nil end

    local maxLevel = SafeCall(C_Housing and C_Housing.GetMaxHouseLevel) or 0
    local isMaxLevel = maxLevel > 0 and level >= maxLevel
    local favor = 0
    local favorNeeded = 0
    local totalNeeded = 0

    if isMaxLevel then
        favor = 1
        favorNeeded = 1
    else
        local favorForCurrent = SafeCall(C_Housing and C_Housing.GetHouseLevelFavorForLevel, level) or 0
        local favorForNext = SafeCall(C_Housing and C_Housing.GetHouseLevelFavorForLevel, level + 1)
        if type(favorForNext) == "number" and favorForNext > favorForCurrent then
            favor = math.max(0, totalFavor - favorForCurrent)
            favorNeeded = favorForNext - favorForCurrent
            totalNeeded = favorForNext
        end
    end

    return {
        level = level,
        favor = favor,
        favorNeeded = favorNeeded,
        favorTotal = totalFavor,
        favorTotalNeeded = totalNeeded,
        maxLevel = maxLevel,
        isMaxLevel = isMaxLevel,
        updatedAt = now,
    }
end

local function ShouldSaveHouseLevelSnapshot(snapshot, nextSnapshot)
    return not IsValidHouseLevelSnapshot(snapshot)
        or snapshot.level ~= nextSnapshot.level
        or snapshot.favor ~= nextSnapshot.favor
        or snapshot.favorNeeded ~= nextSnapshot.favorNeeded
        or snapshot.favorTotal ~= nextSnapshot.favorTotal
        or snapshot.favorTotalNeeded ~= nextSnapshot.favorTotalNeeded
        or snapshot.maxLevel ~= nextSnapshot.maxLevel
        or snapshot.isMaxLevel ~= nextSnapshot.isMaxLevel
        or snapshot.updatedAt ~= nextSnapshot.updatedAt
end

local function SaveHouseLevelSnapshotByGUID(houseGUID, snapshot)
    if not houseGUID or not snapshot then return false end
    local db = GetBudgetDB()
    if not db then return false end

    local changed = false
    for _, plotInfo in pairs(NormalizeKnownPlots(db)) do
        if type(plotInfo) == "table" and plotInfo.houseGUID == houseGUID then
            if ShouldSaveHouseLevelSnapshot(plotInfo.houseLevel, snapshot) then
                plotInfo.houseLevel = snapshot
                changed = true
            end
            levelRequestTimes[houseGUID] = nil
        end
    end

    if changed then
        addon:FireEvent(addon.Events.PLACEMENT_BUDGET_UPDATED)
    end
    return changed
end

local function RequestKnownHouseLevels(db, force)
    if not db then return end
    for _, plotInfo in pairs(NormalizeKnownPlots(db)) do
        RequestHouseLevelFavor(plotInfo, force)
    end
end

local function ShouldSaveSnapshot(snapshot, spent, maxBudget, updatedAt)
    return not snapshot
        or snapshot.spent ~= spent
        or snapshot.max ~= maxBudget
        or snapshot.updatedAt ~= updatedAt
end

local function CaptureBudget(silent)
    if not addon.db or not C_Housing then return false end
    if not C_Housing.IsInsideHouseOrPlot or not C_Housing.IsInsideHouseOrPlot() then return false end

    local db = GetBudgetDB()
    if not db then return false end

    local plotKey, metadataChanged = RememberCurrentHouseInfo(db, true)
    local changed = metadataChanged == true
    if plotKey then
        local knownPlots = NormalizeKnownPlots(db)
        RequestHouseLevelFavor(knownPlots[plotKey], false)
    end

    local context = GetCurrentContext()
    if not context or not C_HousingDecor then
        if changed then
            if not silent then addon:FireEvent(addon.Events.PLACEMENT_BUDGET_UPDATED) end
        end
        return changed
    end

    if not C_HousingDecor.HasMaxPlacementBudget or not C_HousingDecor.HasMaxPlacementBudget() then
        if changed then
            if not silent then addon:FireEvent(addon.Events.PLACEMENT_BUDGET_UPDATED) end
        end
        return changed
    end

    local spent = C_HousingDecor.GetSpentPlacementBudget and C_HousingDecor.GetSpentPlacementBudget()
    local maxBudget = C_HousingDecor.GetMaxPlacementBudget and C_HousingDecor.GetMaxPlacementBudget()
    if type(spent) ~= "number" or type(maxBudget) ~= "number" or maxBudget <= 0 then
        if changed then
            if not silent then addon:FireEvent(addon.Events.PLACEMENT_BUDGET_UPDATED) end
        end
        return changed
    end

    local now = GetServerTime and GetServerTime()
    if type(now) ~= "number" then
        if changed then
            if not silent then addon:FireEvent(addon.Events.PLACEMENT_BUDGET_UPDATED) end
        end
        return changed
    end

    local snapshot = {
        spent = spent,
        max = maxBudget,
        updatedAt = now,
    }

    if context == CONTEXT_INTERIOR then
        if ShouldSaveSnapshot(db[CONTEXT_INTERIOR], spent, maxBudget, now) then
            db[CONTEXT_INTERIOR] = snapshot
            changed = true
        end
    elseif context == CONTEXT_OUTDOOR then
        if ShouldSaveSnapshot(db[CONTEXT_PLOT], spent, maxBudget, now) then
            db[CONTEXT_PLOT] = snapshot
            changed = true
        end

        if plotKey then
            local plotsByID = NormalizePlotsByID(db)
            if ShouldSaveSnapshot(plotsByID[plotKey], spent, maxBudget, now) then
                plotsByID[plotKey] = snapshot
                changed = true
            end
        end
    end

    if plotKey then
        local knownPlots = NormalizeKnownPlots(db)
        local plotInfo = knownPlots[plotKey]
        if plotInfo then
            if ShouldSaveSnapshot(plotInfo.budgets[context], spent, maxBudget, now) then
                plotInfo.budgets[context] = snapshot
                changed = true
            end
        end
    end

    if changed then
        if not silent then addon:FireEvent(addon.Events.PLACEMENT_BUDGET_UPDATED) end
    end
    return changed
end

local function CaptureBudgetAndRefresh()
    local changed = CaptureBudget(false)
    if not changed and addon.db then
        addon:FireEvent(addon.Events.PLACEMENT_BUDGET_UPDATED)
    end
end

local function ScheduleCaptureBudget()
    CaptureBudgetAndRefresh()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.25, CaptureBudgetAndRefresh)
        C_Timer.After(1.0, CaptureBudgetAndRefresh)
    end
end

local function SyncKnownPlots(houseInfos)
    if type(houseInfos) ~= "table" then return end

    local db, normalizedChanged = GetBudgetDB()
    if not db then return false end

    local knownPlots = NormalizeKnownPlots(db)
    local seen = {}
    local activeHouseGUIDsByPlot = {}
    local changed = normalizedChanged == true
    for _, houseInfo in ipairs(houseInfos) do
        local activePlotKey = GetPlotNeighborhoodIdentityKey(houseInfo)
        if activePlotKey and houseInfo.houseGUID ~= nil and houseInfo.houseGUID ~= "" then
            activeHouseGUIDsByPlot[activePlotKey] = houseInfo.houseGUID
        end

        local plotKey, houseChanged = RememberHouseInfo(db, houseInfo, false)
        if plotKey then
            seen[plotKey] = true
            changed = changed or houseChanged
            local plotInfo = knownPlots[plotKey]
            RequestHouseLevelFavor(plotInfo, true)
        end
    end

    for plotKey, plotInfo in pairs(knownPlots) do
        local pruned = false
        if HasHouseGUID(plotInfo) then
            local activePlotKey = GetPlotNeighborhoodIdentityKey(plotInfo)
            local activeHouseGUID = activePlotKey and activeHouseGUIDsByPlot[activePlotKey] or nil
            if activeHouseGUID and activeHouseGUID ~= plotInfo.houseGUID then
                levelRequestTimes[plotInfo.houseGUID] = nil
                knownPlots[plotKey] = nil
                changed = true
                pruned = true
            end
        end
        if not pruned and not seen[plotKey] and not plotInfo.visited and not next(plotInfo.budgets) then
            knownPlots[plotKey] = nil
            changed = true
        end
    end

    if changed then
        addon:FireEvent(addon.Events.PLACEMENT_BUDGET_UPDATED)
    end
end

local function OnHouseLevelFavorUpdated(houseLevelFavor)
    local snapshot = CalculateHouseLevelSnapshot(houseLevelFavor)
    if not snapshot then return end
    SaveHouseLevelSnapshotByGUID(houseLevelFavor.houseGUID, snapshot)
end

local function RequestPlayerOwnedHouses()
    if C_Housing and C_Housing.GetPlayerOwnedHouses then
        C_Housing.GetPlayerOwnedHouses()
    end
end

local function NotifyBudgetUpdated()
    if not addon.db then return end
    GetBudgetDB()
    addon:FireEvent(addon.Events.PLACEMENT_BUDGET_UPDATED)
end

local function HasVisibleKnownPlot(knownPlots)
    if type(knownPlots) ~= "table" then return false end

    for _, plotInfo in pairs(knownPlots) do
        if type(plotInfo) == "table" then
            local budgets = type(plotInfo.budgets) == "table" and plotInfo.budgets or nil
            if plotInfo.visited or (budgets and next(budgets) ~= nil) then
                return true
            end
        end
    end

    return false
end

function addon:GetPlacementBudget()
    CaptureBudget(true)

    local db = GetBudgetDB()
    if not db then return nil end

    local plotsByID = db[CONTEXT_PLOTS_BY_ID]
    local knownPlots = db[CONTEXT_KNOWN_PLOTS]
    if IsValidSnapshot(db[CONTEXT_INTERIOR])
        or IsValidSnapshot(db[CONTEXT_PLOT])
        or (plotsByID and next(plotsByID) ~= nil)
        or HasVisibleKnownPlot(knownPlots) then
        return db
    end
    return nil
end

function addon:IsPlacementBudgetLiveContext()
    return C_Housing and C_Housing.IsInsideHouseOrPlot and C_Housing.IsInsideHouseOrPlot() == true
end

function addon:GetCurrentPlacementBudgetContext()
    if not C_Housing or not C_Housing.IsInsideHouseOrPlot or not C_Housing.IsInsideHouseOrPlot() then
        return nil, nil
    end

    local context = GetCurrentContext()
    if not context or not C_Housing.GetCurrentHouseInfo then
        return nil, context
    end

    local houseInfo = C_Housing.GetCurrentHouseInfo()
    return GetHouseKey(houseInfo), context
end

addon:RegisterWoWEvent("HOUSE_PLOT_ENTERED", ScheduleCaptureBudget)
addon:RegisterWoWEvent("HOUSING_NUM_DECOR_PLACED_CHANGED", ScheduleCaptureBudget)
addon:RegisterWoWEvent("CURRENT_HOUSE_INFO_RECIEVED", ScheduleCaptureBudget)
addon:RegisterWoWEvent("CURRENT_HOUSE_INFO_UPDATED", ScheduleCaptureBudget)
addon:RegisterWoWEvent("HOUSE_EDITOR_MODE_CHANGED", ScheduleCaptureBudget)
addon:RegisterWoWEvent("PLAYER_HOUSE_LIST_UPDATED", SyncKnownPlots)
addon:RegisterWoWEvent("HOUSE_LEVEL_FAVOR_UPDATED", OnHouseLevelFavorUpdated)
addon:RegisterWoWEvent("PLAYER_ENTERING_WORLD", function()
    RequestPlayerOwnedHouses()
    ScheduleCaptureBudget()
    RequestKnownHouseLevels(GetBudgetDB(), true)
end)
addon:RegisterWoWEvent("HOUSE_LEVEL_CHANGED", function(newHouseLevelInfo)
    if newHouseLevelInfo == nil then return end
    RequestPlayerOwnedHouses()
    ScheduleCaptureBudget()
    RequestKnownHouseLevels(GetBudgetDB(), true)
end)
addon:RegisterWoWEvent("HOUSE_PLOT_EXITED", NotifyBudgetUpdated)
