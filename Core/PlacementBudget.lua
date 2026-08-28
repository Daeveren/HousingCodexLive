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
local ownedCompositeKeys = {}
local houseGUIDToComposite = {}
local previousHouseGUIDComposites = {}
local poisonedHouseGUIDs = {}
local ownedHouseListReady = false
local ownedHouseListRetryTimer = nil
local ownedHouseListRetryCount = 0
local ownedHouseListRequestGeneration = 0
local currentHouseInfoRequestInFlight = false
local currentHouseInfoRequestTimeoutTimer = nil
local currentHouseInfoRequestGeneration = 0
local captureTimers = {}
local captureScheduleGeneration = 0
local lastBudgetCaptureBlockReason = nil
local budgetCaptureDiagnosticReasons = {
    ["owned house list unavailable"] = true,
    ["current house info API unavailable"] = true,
    ["missing current house info"] = true,
    ["non-numeric current house plotID"] = true,
    ["unfetched current house plotID"] = true,
    ["current neighborhood GUID API unavailable"] = true,
    ["secret current house neighborhoodGUID"] = true,
    ["empty current house neighborhoodGUID"] = true,
    ["current neighborhood conflicts with current house info"] = true,
    ["unresolved current house identity"] = true,
    ["owned house identity not confirmed"] = true,
    ["current house GUID conflicts with owned house list"] = true,
    ["resolved house identity mismatch"] = true,
}
local MigratePlacementBudgetIdentity
local GetPlotKey

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
    return knownPlots, changed
end

local function GetBudgetDB()
    if not addon.db then return nil end
    if type(addon.db.placementBudget) ~= "table" then
        addon.db.placementBudget = {}
    end
    if type(addon.db.placementBudgetQuarantine) ~= "table" then
        addon.db.placementBudgetQuarantine = {}
    end

    local db = addon.db.placementBudget
    local migratedChanged = MigratePlacementBudgetIdentity
        and MigratePlacementBudgetIdentity(db, addon.db.placementBudgetQuarantine)
    for context, snapshot in pairs(db) do
        if context ~= CONTEXT_PLOTS_BY_ID and context ~= CONTEXT_KNOWN_PLOTS then
            if (context ~= CONTEXT_INTERIOR and context ~= CONTEXT_PLOT) or not IsValidSnapshot(snapshot) then
                db[context] = nil
            end
        end
    end

    local plotsByID = NormalizePlotsByID(db)
    local knownPlots, normalizedChanged = NormalizeKnownPlots(db)
    normalizedChanged = migratedChanged or normalizedChanged
    for plotKey, snapshot in pairs(plotsByID) do
        local plotInfo = knownPlots[plotKey]
        local exactKey = type(plotInfo) == "table"
            and GetPlotKey(plotInfo.plotID, plotInfo.neighborhoodGUID) or nil
        if exactKey == plotKey and not IsValidSnapshot(plotInfo.budgets[CONTEXT_OUTDOOR]) then
            plotInfo.budgets[CONTEXT_OUTDOOR] = snapshot
            normalizedChanged = true
        end
    end

    return db, normalizedChanged
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, result = pcall(func, ...)
    if ok then return result end
    return nil
end

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
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

-- Blizzard uses a negative plotID to mean "we failed to fetch this house's info
-- from the server" (Blizzard_HousingHouseSettings.lua checks == -1;
-- Blizzard_HousingCornerstone.lua gates its whole HasData predicate on < 0).
-- Never build a persisted identity from that sentinel: two unfetched houses in
-- one neighborhood would share an identity key and prune each other in
-- SyncKnownPlots. Read-back stays permissive so legacy rows still load.
local function IsValidPlotID(plotID)
    return type(plotID) == "number" and plotID >= 0
end

GetPlotKey = function(plotID, neighborhoodGUID)
    if not IsValidPlotID(plotID) then return nil end
    if neighborhoodGUID ~= nil and neighborhoodGUID ~= "" then
        return "neighborhood:" .. tostring(neighborhoodGUID) .. ":plot:" .. tostring(math.floor(plotID))
    end
    return nil
end

local function GetHouseKey(houseInfo)
    if type(houseInfo) ~= "table" then return nil end
    return GetPlotKey(houseInfo.plotID, houseInfo.neighborhoodGUID)
end

local function GetCurrentHouseIdentity()
    if not C_Housing or type(C_Housing.GetCurrentHouseInfo) ~= "function" then
        return nil, nil, "current house info API unavailable"
    end

    local houseInfo = SafeCall(C_Housing.GetCurrentHouseInfo)
    if type(houseInfo) ~= "table" then
        return nil, nil, "missing current house info"
    end

    if type(houseInfo.plotID) ~= "number" then
        return houseInfo, nil, "non-numeric current house plotID"
    end
    if not IsValidPlotID(houseInfo.plotID) then
        return houseInfo, nil, "unfetched current house plotID"
    end

    local storedNeighborhoodGUID = houseInfo.neighborhoodGUID
    local liveNeighborhoodGUID
    local liveNeighborhoodAvailable = type(C_Housing.GetCurrentNeighborhoodGUID) == "function"
    if liveNeighborhoodAvailable then
        liveNeighborhoodGUID = SafeCall(C_Housing.GetCurrentNeighborhoodGUID)
    end

    local storedNeighborhoodUsable = not IsSecretValue(storedNeighborhoodGUID)
        and storedNeighborhoodGUID ~= nil and storedNeighborhoodGUID ~= ""
    local liveNeighborhoodUsable = not IsSecretValue(liveNeighborhoodGUID)
        and liveNeighborhoodGUID ~= nil and liveNeighborhoodGUID ~= ""
    if storedNeighborhoodUsable and liveNeighborhoodUsable
        and storedNeighborhoodGUID ~= liveNeighborhoodGUID then
        return houseInfo, nil, "current neighborhood conflicts with current house info"
    end

    if storedNeighborhoodUsable then
        return houseInfo, GetHouseKey(houseInfo)
    end
    if not liveNeighborhoodAvailable then
        return houseInfo, nil, "current neighborhood GUID API unavailable"
    end
    if IsSecretValue(liveNeighborhoodGUID) then
        return houseInfo, nil, "secret current house neighborhoodGUID"
    end
    if not liveNeighborhoodUsable then
        return houseInfo, nil, "empty current house neighborhoodGUID"
    end

    local resolvedHouseInfo = {}
    for field, value in pairs(houseInfo) do
        resolvedHouseInfo[field] = value
    end
    resolvedHouseInfo.neighborhoodGUID = liveNeighborhoodGUID
    return resolvedHouseInfo, GetHouseKey(resolvedHouseInfo)
end

local function HasOwnedHouseIdentity(houseInfo)
    local plotKey = GetHouseKey(houseInfo)
    return plotKey ~= nil and ownedCompositeKeys[plotKey] == true
end

local function IsVisitingAnotherPlayersHousing()
    local neighborhoodCheck = C_HousingNeighborhood and C_HousingNeighborhood.IsPlayerInOtherPlayersPlot
    if type(neighborhoodCheck) == "function" and neighborhoodCheck() == true then
        return true
    end

    local insideHouseCheck = C_Housing and C_Housing.IsInsideHouse
    -- 12.1 added IsInsideOwnedHouse; IsInsideOwnHouse is absent from the
    -- generated docs but still resolves in game -- only because
    -- Blizzard_Deprecated/Mainline/Deprecated_12_1_0.lua aliases it, and that
    -- whole file early-returns unless the CVar loadDeprecationFallbacks is set.
    -- So the fallback is a courtesy, not a second real API: prefer the
    -- documented name, which is always present.
    local insideOwnHouseCheck = C_Housing
        and (C_Housing.IsInsideOwnedHouse or C_Housing.IsInsideOwnHouse)
    return type(insideHouseCheck) == "function"
        and type(insideOwnHouseCheck) == "function"
        and insideHouseCheck() == true
        and insideOwnHouseCheck() ~= true
end

local function GetOwnedBudgetContext()
    if not C_Housing then return false, nil, nil, "housing API unavailable" end

    -- Prefer the ownership-specific combined check when a future client exposes it.
    local ownedContextCheck = C_Housing.IsInsideOwnedHouseOrPlot
    if type(ownedContextCheck) == "function" then
        local isOwned = SafeCall(ownedContextCheck)
        if IsSecretValue(isOwned) or isOwned ~= true then
            return false, nil, nil, "not inside owned housing"
        end
    else
        local legacyContextCheck = C_Housing.IsInsideHouseOrPlot
        if type(legacyContextCheck) ~= "function" or legacyContextCheck() ~= true then
            return false, nil, nil, "outside housing"
        end
    end

    if IsVisitingAnotherPlayersHousing() then
        return false, nil, nil, "visiting another player's housing"
    end
    if not ownedHouseListReady then
        return false, nil, nil, "owned house list unavailable"
    end

    local houseInfo, houseKey, identityBlockReason = GetCurrentHouseIdentity()
    if not houseKey then
        return false, houseInfo, nil, identityBlockReason or "unresolved current house identity"
    end
    if not HasOwnedHouseIdentity(houseInfo) then
        return false, houseInfo, houseKey, "owned house identity not confirmed"
    end
    local houseGUID = type(houseInfo) == "table" and houseInfo.houseGUID or nil
    local mappedIdentity
    if not IsSecretValue(houseGUID) and houseGUID ~= nil and houseGUID ~= "" then
        mappedIdentity = houseGUIDToComposite[houseGUID]
    end
    if mappedIdentity and mappedIdentity ~= houseKey then
        return false, houseInfo, houseKey, "current house GUID conflicts with owned house list"
    end
    return true, houseInfo, houseKey
end

local function DebugBudgetCaptureBlock(reason)
    if not budgetCaptureDiagnosticReasons[reason] then
        return
    end
    if lastBudgetCaptureBlockReason == reason then return end

    lastBudgetCaptureBlockReason = reason
    addon:Debug("Placement budget capture paused: " .. reason)
end

local function HasHouseGUID(plotInfo)
    return type(plotInfo) == "table" and plotInfo.houseGUID ~= nil and plotInfo.houseGUID ~= ""
end

local function SetBudgetIdentity(budgets, identityKey)
    if type(budgets) ~= "table" or type(identityKey) ~= "string" then return false end

    local changed = false
    for _, snapshot in pairs(budgets) do
        if IsValidSnapshot(snapshot) and snapshot.identityKey ~= identityKey then
            snapshot.identityKey = identityKey
            changed = true
        end
    end
    return changed
end

local function CopySavedValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[CopySavedValue(key, seen)] = CopySavedValue(child, seen)
    end
    return copy
end

local function AppendQuarantineEntry(quarantine, entry)
    local maxIndex = 0
    for key in pairs(quarantine) do
        if type(key) == "number" and key > maxIndex and key == math.floor(key) then
            maxIndex = key
        end
    end
    quarantine[maxIndex + 1] = entry
end

local function NewOccupancyQuarantineEntry(reason, sourceKey, targetKey, plotInfo)
    return {
        kind = "occupancy",
        reason = reason,
        sourceKey = sourceKey,
        targetKey = targetKey,
        plotInfo = CopySavedValue(plotInfo),
    }
end

local function MovePlotSnapshotIdentity(sourcePlots, targetPlots, sourceKey, targetKey)
    local snapshot = sourcePlots[sourceKey]
    if not IsValidSnapshot(snapshot) then return false end

    local copy = CopySavedValue(snapshot)
    copy.identityKey = targetKey
    targetPlots[targetKey] = copy
    return true
end

local function IsBarePlotSnapshotKey(key)
    return type(key) == "string" and tonumber(key) ~= nil
end

local function IsCompositePlotKey(key)
    return type(key) == "string" and string.sub(key, 1, 13) == "neighborhood:"
end

local function HasConflictingLegacyHouseIdentity(sourceKey, plotInfo)
    if type(sourceKey) ~= "string" or string.sub(sourceKey, 1, 6) ~= "house:" then
        return false
    end
    if not HasHouseGUID(plotInfo) then return false end
    return sourceKey ~= "house:" .. tostring(plotInfo.houseGUID)
end

local function HasConflictingSnapshotIdentity(snapshot, sourceKey, targetKey, legacyHouseKey)
    if not IsValidSnapshot(snapshot) then return false end

    local identityKey = snapshot.identityKey
    return type(identityKey) == "string" and identityKey ~= ""
        and identityKey ~= sourceKey and identityKey ~= targetKey
        and identityKey ~= legacyHouseKey
end

local function HasConflictingBudgetIdentity(budgets, sourceKey, targetKey, legacyHouseKey)
    if type(budgets) ~= "table" then return false end

    for _, snapshot in pairs(budgets) do
        if HasConflictingSnapshotIdentity(snapshot, sourceKey, targetKey, legacyHouseKey) then
            return true
        end
    end
    return false
end

MigratePlacementBudgetIdentity = function(db, quarantine)
    local rawKnownPlots = type(db[CONTEXT_KNOWN_PLOTS]) == "table" and db[CONTEXT_KNOWN_PLOTS] or {}
    local rawPlotsByID = type(db[CONTEXT_PLOTS_BY_ID]) == "table" and db[CONTEXT_PLOTS_BY_ID] or {}
    local claimsByTarget = {}
    local unresolvedClaims = {}
    local legacyHouseKeyCounts = {}
    local ambiguousLegacySnapshotKeys = {}
    local changed = false

    for sourceKey, plotInfo in pairs(rawKnownPlots) do
        if type(plotInfo) == "table" then
            if HasHouseGUID(plotInfo) then
                local legacyHouseKey = "house:" .. tostring(plotInfo.houseGUID)
                legacyHouseKeyCounts[legacyHouseKey] = (legacyHouseKeyCounts[legacyHouseKey] or 0) + 1
            end
            local targetKey = GetPlotKey(plotInfo.plotID, plotInfo.neighborhoodGUID)
            local claim = {
                sourceKey = sourceKey,
                targetKey = targetKey,
                plotInfo = plotInfo,
            }
            if targetKey then
                local claims = claimsByTarget[targetKey]
                if not claims then
                    claims = {}
                    claimsByTarget[targetKey] = claims
                end
                claims[#claims + 1] = claim
            else
                unresolvedClaims[#unresolvedClaims + 1] = claim
            end
        end
    end
    for legacyHouseKey, count in pairs(legacyHouseKeyCounts) do
        if count > 1 then
            ambiguousLegacySnapshotKeys[legacyHouseKey] = true
        end
    end

    local nextKnownPlots = {}
    local nextPlotsByID = {}
    local pendingQuarantine = {}
    local quarantineEntryBySource = {}
    local quarantinedIdentities = {}
    local uniqueClaimsByTarget = {}
    local identityTargets = {}
    local consumedPlotSnapshots = {}

    local function QueueQuarantine(entry)
        pendingQuarantine[#pendingQuarantine + 1] = entry
    end

    local function QuarantineClaim(claim, reason)
        local entry = NewOccupancyQuarantineEntry(reason, claim.sourceKey, claim.targetKey, claim.plotInfo)
        QueueQuarantine(entry)
        quarantineEntryBySource[claim.sourceKey] = entry
        if type(claim.sourceKey) == "string" then
            quarantinedIdentities[claim.sourceKey] = true
        end
        if type(claim.targetKey) == "string" then
            quarantinedIdentities[claim.targetKey] = true
        end
        changed = true
        return entry
    end

    for _, claim in ipairs(unresolvedClaims) do
        QuarantineClaim(claim, "unresolved_composite_identity")
    end

    for targetKey, claims in pairs(claimsByTarget) do
        if #claims == 1 then
            local claim = claims[1]
            local sourceKey = claim.sourceKey
            local sourceSnapshot = rawPlotsByID[sourceKey]
            local targetSnapshot = sourceKey ~= targetKey and rawPlotsByID[targetKey] or nil
            local sourceValid = IsValidSnapshot(sourceSnapshot)
            local targetValid = IsValidSnapshot(targetSnapshot)
            local sourceMirrorAmbiguous = sourceValid
                and ambiguousLegacySnapshotKeys[sourceKey] == true
                and sourceSnapshot.identityKey ~= targetKey
            local legacyHouseKey = HasHouseGUID(claim.plotInfo)
                and "house:" .. tostring(claim.plotInfo.houseGUID) or nil
            local snapshotIdentityConflict = HasConflictingBudgetIdentity(
                claim.plotInfo.budgets, sourceKey, targetKey, legacyHouseKey
            ) or HasConflictingSnapshotIdentity(sourceSnapshot, sourceKey, targetKey, legacyHouseKey)
                or HasConflictingSnapshotIdentity(targetSnapshot, sourceKey, targetKey, legacyHouseKey)
            -- A composite source key is already durable provenance. If its
            -- identity conflicts with the row fields, neither side can safely
            -- win; moving it would turn corruption into an apparently valid row.
            if IsCompositePlotKey(sourceKey) and sourceKey ~= targetKey then
                QuarantineClaim(claim, "conflicting_stable_source_identity")
            -- The legacy house key and its corroborating metadata are two
            -- independent stored observations. A disagreement is not proof
            -- that either one names this occupancy.
            elseif HasConflictingLegacyHouseIdentity(sourceKey, claim.plotInfo) then
                QuarantineClaim(claim, "conflicting_legacy_house_identity")
            -- Snapshot identity is provenance too. Only an unstamped snapshot,
            -- the source, the derived target, or this row's corroborating
            -- legacy house key may be normalized; any other stable identity
            -- makes the whole occupancy ambiguous.
            elseif snapshotIdentityConflict then
                QuarantineClaim(claim, "conflicting_snapshot_identity")
            -- Two mirrors mean both the old and target identities already hold
            -- data. Quarantine the whole occupancy so embedded row budgets do
            -- not remain displayable after the ambiguous mirrors are removed.
            elseif sourceValid and targetValid and not sourceMirrorAmbiguous then
                local entry = QuarantineClaim(claim, "conflicting_plot_mirrors")
                entry.plotSnapshots = {
                    sourceSnapshot = CopySavedValue(sourceSnapshot),
                    targetSnapshot = CopySavedValue(targetSnapshot),
                }
                consumedPlotSnapshots[sourceKey] = true
                consumedPlotSnapshots[targetKey] = true
            else
                local plotInfo = CopySavedValue(claim.plotInfo)
                local normalizedPlotID = math.floor(plotInfo.plotID)
                if plotInfo.plotID ~= normalizedPlotID then
                    plotInfo.plotID = normalizedPlotID
                    changed = true
                end
                changed = SetBudgetIdentity(plotInfo.budgets, targetKey) or changed
                nextKnownPlots[targetKey] = plotInfo
                uniqueClaimsByTarget[targetKey] = claim
                claim.sourceMirrorAmbiguous = sourceMirrorAmbiguous
                if sourceKey ~= targetKey then
                    changed = true
                end
            end
        else
            for _, claim in ipairs(claims) do
                QuarantineClaim(claim, "conflicting_composite_claim")
            end
        end
    end

    for targetKey, claim in pairs(uniqueClaimsByTarget) do
        local sourceKey = claim.sourceKey
        local sourceSnapshot = rawPlotsByID[sourceKey]
        local targetSnapshot = sourceKey ~= targetKey and rawPlotsByID[targetKey] or nil
        local sourceValid = IsValidSnapshot(sourceSnapshot)
        local targetValid = IsValidSnapshot(targetSnapshot)
        local sourceMirrorBlocked = claim.sourceMirrorAmbiguous
            or quarantinedIdentities[sourceKey] == true
        local targetMirrorBlocked = quarantinedIdentities[targetKey] == true

        if not targetMirrorBlocked then
            identityTargets[targetKey] = targetKey
        end
        if type(sourceKey) == "string" and not sourceMirrorBlocked
            and not ambiguousLegacySnapshotKeys[sourceKey] then
            identityTargets[sourceKey] = targetKey
        end

        if sourceValid and not sourceMirrorBlocked then
            MovePlotSnapshotIdentity(rawPlotsByID, nextPlotsByID, sourceKey, targetKey)
            consumedPlotSnapshots[sourceKey] = true
            if sourceKey ~= targetKey or sourceSnapshot.identityKey ~= targetKey then
                changed = true
            end
        elseif targetValid and not targetMirrorBlocked then
            MovePlotSnapshotIdentity(rawPlotsByID, nextPlotsByID, targetKey, targetKey)
            consumedPlotSnapshots[targetKey] = true
            if targetSnapshot.identityKey ~= targetKey then
                changed = true
            end
        end
    end

    for plotKey, snapshot in pairs(rawPlotsByID) do
        if not consumedPlotSnapshots[plotKey] then
            local occupancyEntry = quarantineEntryBySource[plotKey]
            if occupancyEntry and IsValidSnapshot(snapshot) then
                occupancyEntry.plotSnapshotKey = plotKey
                occupancyEntry.plotSnapshot = CopySavedValue(snapshot)
            elseif quarantinedIdentities[plotKey] and IsValidSnapshot(snapshot) then
                QueueQuarantine({
                    kind = "plotSnapshot",
                    reason = "quarantined_identity_mirror",
                    sourceKey = plotKey,
                    snapshot = CopySavedValue(snapshot),
                })
            elseif ambiguousLegacySnapshotKeys[plotKey] and IsValidSnapshot(snapshot) then
                QueueQuarantine({
                    kind = "plotSnapshot",
                    reason = "ambiguous_legacy_house_identity_mirror",
                    sourceKey = plotKey,
                    snapshot = CopySavedValue(snapshot),
                })
                changed = true
            elseif IsBarePlotSnapshotKey(plotKey) then
                nextPlotsByID[plotKey] = snapshot
            elseif IsValidSnapshot(snapshot) then
                QueueQuarantine({
                    kind = "plotSnapshot",
                    reason = "orphaned_stable_identity_mirror",
                    sourceKey = plotKey,
                    snapshot = CopySavedValue(snapshot),
                })
                changed = true
            end
        end
    end

    local nextSingleSlots = {}
    for _, context in ipairs({ CONTEXT_INTERIOR, CONTEXT_PLOT }) do
        local snapshot = db[context]
        if IsValidSnapshot(snapshot) and type(snapshot.identityKey) == "string" then
            local targetKey = identityTargets[snapshot.identityKey]
            if targetKey then
                local copy = CopySavedValue(snapshot)
                copy.identityKey = targetKey
                nextSingleSlots[context] = copy
                if snapshot.identityKey ~= targetKey then
                    changed = true
                end
            else
                local entry = quarantineEntryBySource[snapshot.identityKey]
                if entry then
                    entry.singleSlots = entry.singleSlots or {}
                    entry.singleSlots[context] = CopySavedValue(snapshot)
                else
                    local reason = "orphaned_stable_identity_slot"
                    if quarantinedIdentities[snapshot.identityKey] then
                        reason = "quarantined_identity_slot"
                    elseif ambiguousLegacySnapshotKeys[snapshot.identityKey] then
                        reason = "ambiguous_legacy_house_identity_slot"
                    end
                    QueueQuarantine({
                        kind = "singleSlot",
                        reason = reason,
                        context = context,
                        identityKey = snapshot.identityKey,
                        snapshot = CopySavedValue(snapshot),
                    })
                end
                changed = true
            end
        else
            nextSingleSlots[context] = snapshot
        end
    end

    if not changed then
        return false
    end

    local nextQuarantine = CopySavedValue(quarantine)
    for _, entry in ipairs(pendingQuarantine) do
        AppendQuarantineEntry(nextQuarantine, entry)
    end
    db[CONTEXT_KNOWN_PLOTS] = nextKnownPlots
    db[CONTEXT_PLOTS_BY_ID] = nextPlotsByID
    db[CONTEXT_INTERIOR] = nextSingleSlots[CONTEXT_INTERIOR]
    db[CONTEXT_PLOT] = nextSingleSlots[CONTEXT_PLOT]
    addon.db.placementBudgetQuarantine = nextQuarantine
    return true
end

local function QuarantineActiveOccupancy(db, plotKey, plotInfo, incomingHouseGUID)
    local quarantine = addon.db and addon.db.placementBudgetQuarantine
    if type(quarantine) ~= "table" then
        quarantine = {}
        addon.db.placementBudgetQuarantine = quarantine
    end

    local entry = NewOccupancyQuarantineEntry("house_guid_conflict", plotKey, plotKey, plotInfo)
    entry.incomingHouseGUID = incomingHouseGUID
    local plotsByID = type(db[CONTEXT_PLOTS_BY_ID]) == "table" and db[CONTEXT_PLOTS_BY_ID] or nil
    if plotsByID and type(plotsByID[plotKey]) == "table" then
        entry.plotSnapshotKey = plotKey
        entry.plotSnapshot = plotsByID[plotKey]
        plotsByID[plotKey] = nil
    end
    for _, context in ipairs({ CONTEXT_INTERIOR, CONTEXT_PLOT }) do
        local snapshot = db[context]
        if type(snapshot) == "table" and snapshot.identityKey == plotKey then
            entry.singleSlots = entry.singleSlots or {}
            entry.singleSlots[context] = snapshot
            db[context] = nil
        end
    end
    AppendQuarantineEntry(quarantine, entry)
end

local function GetPlayerFactionInfo()
    if type(UnitFactionGroup) ~= "function" then return nil, nil end

    local ok, factionTag, localizedFaction = pcall(UnitFactionGroup, "player")
    if not ok or IsSecretValue(factionTag) or IsSecretValue(localizedFaction) then return nil, nil end
    if factionTag ~= "Alliance" and factionTag ~= "Horde" then return nil, nil end
    if type(localizedFaction) ~= "string" or localizedFaction == "" then
        localizedFaction = nil
    end

    return factionTag, localizedFaction
end

local function GetNeighborhoodFactionInfo(neighborhoodGUID)
    if IsSecretValue(neighborhoodGUID) then return nil, nil end
    if neighborhoodGUID == nil or neighborhoodGUID == "" then return nil, nil end
    if not C_Housing or type(C_Housing.DoesFactionMatchNeighborhood) ~= "function" then return nil, nil end

    local playerFactionTag, localizedPlayerFaction = GetPlayerFactionInfo()
    if not playerFactionTag then return nil, nil end

    local ok, factionMatches = pcall(C_Housing.DoesFactionMatchNeighborhood, neighborhoodGUID)
    if not ok or IsSecretValue(factionMatches) or type(factionMatches) ~= "boolean" then return nil, nil end

    local factionTag = playerFactionTag
    if not factionMatches then
        factionTag = playerFactionTag == "Alliance" and "Horde" or "Alliance"
    end

    local localizedFaction
    if factionTag == playerFactionTag then
        localizedFaction = localizedPlayerFaction
    elseif factionTag == "Alliance" then
        localizedFaction = FACTION_ALLIANCE
    else
        localizedFaction = FACTION_HORDE
    end
    return factionTag, localizedFaction
end

local function RememberHouseInfo(db, houseInfo, markVisited)
    if type(houseInfo) ~= "table" then return nil, false end

    local normalizedPlotID = IsValidPlotID(houseInfo.plotID) and math.floor(houseInfo.plotID) or nil
    if not normalizedPlotID then return nil, false end

    local plotKey = GetHouseKey(houseInfo)
    if not plotKey then return nil, false end

    local knownPlots = NormalizeKnownPlots(db)
    local plotInfo = knownPlots[plotKey]
    local changed = false
    local incomingHouseGUID = houseInfo.houseGUID
    if IsValidKnownPlot(plotInfo) and HasHouseGUID(plotInfo)
        and incomingHouseGUID ~= nil and incomingHouseGUID ~= ""
        and plotInfo.houseGUID ~= incomingHouseGUID then
        QuarantineActiveOccupancy(db, plotKey, plotInfo, incomingHouseGUID)
        knownPlots[plotKey] = nil
        plotInfo = nil
        levelRequestTimes[plotKey] = nil
        changed = true
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
    if incomingHouseGUID ~= nil and incomingHouseGUID ~= "" and plotInfo.houseGUID ~= incomingHouseGUID then
        plotInfo.houseGUID = incomingHouseGUID
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

    local factionTag, factionName = GetNeighborhoodFactionInfo(houseInfo.neighborhoodGUID)
    if factionTag and plotInfo.factionTag ~= factionTag then
        plotInfo.factionTag = factionTag
        changed = true
    end
    if factionName and plotInfo.factionName ~= factionName then
        plotInfo.factionName = factionName
        changed = true
    end

    plotInfo.budgets = NormalizeBudgetMap(plotInfo.budgets)
    return plotKey, changed
end

local function RequestHouseLevelFavor(plotInfo, force)
    if type(plotInfo) ~= "table" or not HasHouseGUID(plotInfo) then return end
    if not C_Housing or not C_Housing.GetCurrentHouseLevelFavor then return end
    local identityKey = GetHouseKey(plotInfo)
    if not identityKey or houseGUIDToComposite[plotInfo.houseGUID] ~= identityKey then return end

    local now = GetServerTime and GetServerTime()
    if not force and type(now) == "number" and type(levelRequestTimes[identityKey]) == "number"
        and now - levelRequestTimes[identityKey] < 15 then
        return
    end

    if type(now) == "number" then
        levelRequestTimes[identityKey] = now
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
    local identityKey = houseGUIDToComposite[houseGUID]
    if not identityKey or poisonedHouseGUIDs[houseGUID] then
        addon:Debug("House level update skipped: houseGUID " .. tostring(houseGUID)
            .. " has no unambiguous current owned-house mapping")
        return false
    end

    local db = GetBudgetDB()
    if not db then return false end
    local knownPlots = NormalizeKnownPlots(db)
    local target = knownPlots[identityKey]
    if type(target) ~= "table" or target.houseGUID ~= houseGUID
        or ownedCompositeKeys[identityKey] ~= true then
        return false
    end

    levelRequestTimes[identityKey] = nil

    local changed = false
    if ShouldSaveHouseLevelSnapshot(target.houseLevel, snapshot) then
        target.houseLevel = snapshot
        changed = true
    end

    if changed then
        addon:FireEvent(addon.Events.PLACEMENT_BUDGET_UPDATED)
    end
    return changed
end

-- Currently stored spent value for this identity/context, or nil when nothing
-- is stored yet. Checks the same targets CaptureBudget writes to.
local function GetStoredBudgetSpent(db, context, plotKey, knownPlots)
    local function SpentFor(snapshot)
        if type(snapshot) ~= "table" then return nil end
        if snapshot.identityKey ~= plotKey then return nil end
        if type(snapshot.spent) ~= "number" then return nil end
        return snapshot.spent
    end

    local plotInfo = knownPlots and knownPlots[plotKey]
    if type(plotInfo) == "table" and type(plotInfo.budgets) == "table" then
        local stored = SpentFor(plotInfo.budgets[context])
        if stored then return stored end
    end

    if context == CONTEXT_INTERIOR then
        return SpentFor(db[CONTEXT_INTERIOR])
    end
    if context == CONTEXT_OUTDOOR then
        local stored = SpentFor(db[CONTEXT_PLOT])
        if stored then return stored end
        local plotsByID = db[CONTEXT_PLOTS_BY_ID]
        if type(plotsByID) == "table" then
            return SpentFor(plotsByID[plotKey])
        end
    end
    return nil
end

-- Observed in game 2026-08-24: on login inside an owned house, the first
-- captures read spent = 0 while max already read 3500, then corrected to 94.
-- Blizzard_Deprecated/Mainline/Deprecated_12_1_0.lua rewrites
-- GetSpentPlacementBudget as `original() or 0`, masking a nil return as a plain
-- zero. That file early-returns unless the loadDeprecationFallbacks CVar is set,
-- and it IS set: verified in game 2026-08-24, where
-- GetCVarBool("loadDeprecationFallbacks") returned true and
-- C_Housing.IsInsideOwnHouse == C_Housing.IsInsideOwnedHouse confirmed the same
-- file's alias is live. So the masking wrapper is installed for real users, and
-- an unpopulated nil is indistinguishable from a genuine zero here. Note the
-- documented nil condition ("not in an owned house or plot") is already excluded
-- upstream, so the exact trigger is still unproven -- but max read 3500 while
-- spent read 0, so the two getters demonstrably diverge. C_HousingDecor exposes
-- no readiness predicate, so a zero has to earn the right to replace a stored
-- non-zero value.
local pendingZeroConfirmation = nil
-- Last signals behind a zero refusal, for the debug line only. The docs do not
-- say whether GetAllSpentPlacementBudgets returns nil or a zero-filled table
-- while a house interior is still streaming, so log both readings and settle it
-- from a real capture rather than guessing.
local lastZeroSignals = { unmasked = nil, placed = nil }

-- Elapsed wall-clock time is NOT evidence that a reading settled, and keying the
-- confirmation off it was a rubber stamp. A house interior streams its decor in
-- over roughly a second while the shimmed spend getter reads a masked zero
-- throughout, and the old 0.2s window was crossed by the very next scheduled
-- capture at 0.25s (Core/Init.lua BUDGET_CAPTURE_RETRY_SHORT), so any zero
-- surviving one capture was confirmed and persisted. Observed in game
-- 2026-08-24: a stored interior spend of 94 was overwritten with 0, then with a
-- still-streaming 22. No API bounds the load time, so a longer window would only
-- lower the odds rather than close the hole.
--
-- The unmasked reading closes it instead. C_HousingDecor.GetSpentPlacementBudget
-- became nilable in 12.1 ("not in an owned House or Plot"), but
-- Blizzard_Deprecated/Mainline/Deprecated_12_1_0.lua wraps it as `original() or 0`
-- and loadDeprecationFallbacks is on by default, so its zero cannot be told apart
-- from an unavailable read. GetAllSpentPlacementBudgets is new in 12.1 and is one
-- of the getters that file does NOT wrap, so its documented nil survives to us.
--   true  = the budget is readable and the decor bucket genuinely reads zero
--   false = the budget is not readable, so a zero is a masked nil
--   nil   = cannot tell (API or enum unavailable)
local function ReadUnmaskedZeroSpend(context)
    local getAllSpent = C_HousingDecor and C_HousingDecor.GetAllSpentPlacementBudgets
    if type(getAllSpent) ~= "function" then return nil end

    local budgetType = Enum and Enum.HousingBudgetType and Enum.HousingBudgetType.DecorPlacement
    if type(budgetType) ~= "number" then return nil end

    local ok, interiorSpent, exteriorSpent = pcall(getAllSpent)
    if not ok then return nil end

    -- Explicit branch, not `context == CONTEXT_INTERIOR and interiorSpent or
    -- exteriorSpent`: both returns are documented Nilable, and that idiom falls
    -- through to the exterior table whenever the interior one is nil -- reading
    -- the plot's spend as if it were the interior's.
    local spentByType
    if context == CONTEXT_INTERIOR then
        spentByType = interiorSpent
    else
        spentByType = exteriorSpent
    end
    if type(spentByType) ~= "table" then return false end

    local decorSpent = spentByType[budgetType]
    if IsSecretValue(decorSpent) or type(decorSpent) ~= "number" then return false end
    return decorSpent == 0
end

-- true  = nothing is placed, so a zero spend is consistent with the world
-- false = decor is placed, so the read is not settled
-- nil   = cannot tell
-- GetNumDecorPlaced is documented as "NOT the value used in placement budget
-- calculations", and it is Nilable = false so it cannot say "not loaded yet" --
-- which is why it corroborates the unmasked read rather than deciding alone.
-- Nothing in the 12.1 catalog or decor structs describes budget-exempt decor, so
-- inside an owned house a placed count above zero alongside a zero spend means
-- the read has not settled.
local function IsZeroSpendPlausible()
    local getNumPlaced = C_HousingDecor and C_HousingDecor.GetNumDecorPlaced
    if type(getNumPlaced) ~= "function" then return nil end
    local ok, numPlaced = pcall(getNumPlaced)
    if not ok or IsSecretValue(numPlaced) or type(numPlaced) ~= "number" then return nil end
    return numPlaced == 0
end

-- A zero may replace a stored non-zero only on agreement from three independent
-- checks: the unmasked getter says the budget is readable and really is zero,
-- nothing is placed, and a previous capture already saw the same zero. Refusing
-- is cheap -- the stored value stands and any real reading overwrites it, and
-- HOUSING_NUM_DECOR_PLACED_CHANGED reschedules a capture as the world settles --
-- while confirming wrongly destroys a value only a physical visit can restore.
local function IsZeroReadConfirmed(plotKey, context, maxBudget)
    local unmaskedZero = ReadUnmaskedZeroSpend(context)
    local nothingPlaced = IsZeroSpendPlausible()
    lastZeroSignals.unmasked = unmaskedZero
    lastZeroSignals.placed = nothingPlaced
    if unmaskedZero ~= true or nothingPlaced ~= true then
        pendingZeroConfirmation = {
            plotKey = plotKey,
            context = context,
            max = maxBudget,
        }
        return false
    end

    local pending = pendingZeroConfirmation
    if pending
        and pending.plotKey == plotKey
        and pending.context == context
        and pending.max == maxBudget
    then
        pendingZeroConfirmation = nil
        return true
    end

    pendingZeroConfirmation = {
        plotKey = plotKey,
        context = context,
        max = maxBudget,
    }
    return false
end

local function ShouldSaveSnapshot(snapshot, spent, maxBudget, updatedAt, identityKey)
    return not snapshot
        or snapshot.spent ~= spent
        or snapshot.max ~= maxBudget
        or snapshot.updatedAt ~= updatedAt
        or snapshot.identityKey ~= identityKey
end

local function CaptureBudget(silent)
    if not addon.db or not C_Housing then return false end
    local isOwnedContext, houseInfo, ownedHouseKey, blockReason = GetOwnedBudgetContext()
    if not isOwnedContext then
        -- Drop any half-confirmed zero: leaving and re-entering the same house
        -- must not let a stale first sighting instantly confirm a new one.
        pendingZeroConfirmation = nil
        DebugBudgetCaptureBlock(blockReason)
        return false
    end
    lastBudgetCaptureBlockReason = nil

    local db = GetBudgetDB()
    if not db then return false end

    local plotKey, metadataChanged = RememberHouseInfo(db, houseInfo, true)
    if not plotKey or plotKey ~= ownedHouseKey then
        pendingZeroConfirmation = nil
        DebugBudgetCaptureBlock("resolved house identity mismatch")
        return false
    end
    local changed = metadataChanged == true
    local knownPlots = NormalizeKnownPlots(db)
    RequestHouseLevelFavor(knownPlots[plotKey], false)

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

    local storedSpent = GetStoredBudgetSpent(db, context, plotKey, knownPlots)
    if spent == 0 and type(storedSpent) == "number" and storedSpent > 0 then
        if not IsZeroReadConfirmed(plotKey, context, maxBudget) then
            addon:Debug("Placement budget zero read unconfirmed; keeping "
                .. tostring(storedSpent) .. " for " .. tostring(plotKey)
                .. " (unmaskedZero=" .. tostring(lastZeroSignals.unmasked)
                .. " nothingPlaced=" .. tostring(lastZeroSignals.placed) .. ")")
            if changed then
                if not silent then addon:FireEvent(addon.Events.PLACEMENT_BUDGET_UPDATED) end
            end
            return changed
        end
    else
        pendingZeroConfirmation = nil
    end

    local snapshot = {
        spent = spent,
        max = maxBudget,
        updatedAt = now,
        identityKey = plotKey,
    }

    if context == CONTEXT_INTERIOR then
        if ShouldSaveSnapshot(db[CONTEXT_INTERIOR], spent, maxBudget, now, plotKey) then
            db[CONTEXT_INTERIOR] = snapshot
            changed = true
        end
    elseif context == CONTEXT_OUTDOOR then
        if ShouldSaveSnapshot(db[CONTEXT_PLOT], spent, maxBudget, now, plotKey) then
            db[CONTEXT_PLOT] = snapshot
            changed = true
        end

        local plotsByID = NormalizePlotsByID(db)
        if ShouldSaveSnapshot(plotsByID[plotKey], spent, maxBudget, now, plotKey) then
            plotsByID[plotKey] = snapshot
            changed = true
        end
    end

    local plotInfo = knownPlots[plotKey]
    if plotInfo then
        if ShouldSaveSnapshot(plotInfo.budgets[context], spent, maxBudget, now, plotKey) then
            plotInfo.budgets[context] = snapshot
            changed = true
        end
    end

    -- ShouldSaveSnapshot also compares updatedAt (GetServerTime, one-second
    -- resolution), so `changed` reports elapsed time as much as a real change.
    -- Key the log off the value instead.
    if storedSpent ~= spent then
        addon:Debug("Placement budget captured: " .. context .. " "
            .. tostring(spent) .. "/" .. tostring(maxBudget) .. " for " .. tostring(plotKey))
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

local function CancelScheduledCaptures()
    for slot, timer in pairs(captureTimers) do
        timer:Cancel()
        captureTimers[slot] = nil
    end
end

local function ScheduleCaptureBudget()
    CaptureBudgetAndRefresh()
    if not C_Timer or not C_Timer.NewTimer then
        return
    end

    captureScheduleGeneration = captureScheduleGeneration + 1
    local generation = captureScheduleGeneration
    CancelScheduledCaptures()

    local function Schedule(slot, delay)
        captureTimers[slot] = C_Timer.NewTimer(delay, function()
            captureTimers[slot] = nil
            if generation == captureScheduleGeneration then
                CaptureBudgetAndRefresh()
            end
        end)
    end

    local timers = addon.CONSTANTS.TIMER
    Schedule("debounce", timers.BUDGET_CAPTURE_DEBOUNCE)
    Schedule("shortRetry", timers.BUDGET_CAPTURE_RETRY_SHORT)
    Schedule("longRetry", timers.BUDGET_CAPTURE_RETRY_LONG)
end

local function CancelCurrentHouseInfoRequestTimeout()
    if currentHouseInfoRequestTimeoutTimer then
        currentHouseInfoRequestTimeoutTimer:Cancel()
        currentHouseInfoRequestTimeoutTimer = nil
    end
end

local function ClearCurrentHouseInfoRequest()
    currentHouseInfoRequestGeneration = currentHouseInfoRequestGeneration + 1
    currentHouseInfoRequestInFlight = false
    CancelCurrentHouseInfoRequestTimeout()
end

local function RequestCurrentHouseInfo()
    if currentHouseInfoRequestInFlight then return end

    local request = C_Housing and C_Housing.RequestCurrentHouseInfo
    if type(request) ~= "function" then return end

    currentHouseInfoRequestGeneration = currentHouseInfoRequestGeneration + 1
    local generation = currentHouseInfoRequestGeneration
    currentHouseInfoRequestInFlight = true

    local timers = addon.CONSTANTS and addon.CONSTANTS.TIMER
    local timeout = timers and timers.BUDGET_CURRENT_HOUSE_INFO_TIMEOUT
    if C_Timer and type(C_Timer.NewTimer) == "function" and type(timeout) == "number" then
        currentHouseInfoRequestTimeoutTimer = C_Timer.NewTimer(timeout, function()
            if generation ~= currentHouseInfoRequestGeneration then return end
            currentHouseInfoRequestTimeoutTimer = nil
            currentHouseInfoRequestInFlight = false
            addon:Debug("Current house info request timed out; allowing a new entry request")
        end)
    end

    request()
    if generation == currentHouseInfoRequestGeneration and not currentHouseInfoRequestTimeoutTimer then
        currentHouseInfoRequestInFlight = false
    end
end

local function OnHousePlotEntered()
    -- Entering a plot always invalidates a half-confirmed zero. Clearing only
    -- inside CaptureBudget is not enough: an on-foot exit fires no capture and
    -- no loading screen, so a pending sighting from the end of the last visit
    -- would still be older than the confirmation window on re-entry.
    pendingZeroConfirmation = nil
    RequestCurrentHouseInfo()
    ScheduleCaptureBudget()
end

local function OnCurrentHouseInfoChanged()
    ClearCurrentHouseInfoRequest()
    ScheduleCaptureBudget()
end

local function CancelOwnedHouseListRetry()
    if ownedHouseListRetryTimer then
        ownedHouseListRetryTimer:Cancel()
        ownedHouseListRetryTimer = nil
    end
end

local function ScheduleOwnedHouseListRetry(generation)
    if generation ~= ownedHouseListRequestGeneration or ownedHouseListReady then return end

    local timers = addon.CONSTANTS and addon.CONSTANTS.TIMER
    if not C_Timer or type(C_Timer.NewTimer) ~= "function" or not timers then return end

    local exhaustedFastRetries = ownedHouseListRetryCount >= timers.BUDGET_OWNED_LIST_MAX_RETRIES
    local delay = exhaustedFastRetries
        and timers.BUDGET_OWNED_LIST_FALLBACK_DELAY
        or timers.BUDGET_OWNED_LIST_RETRY_DELAY
    ownedHouseListRetryTimer = C_Timer.NewTimer(delay, function()
        ownedHouseListRetryTimer = nil
        if generation ~= ownedHouseListRequestGeneration or ownedHouseListReady then return end
        if not C_Housing or type(C_Housing.GetPlayerOwnedHouses) ~= "function" then return end

        if exhaustedFastRetries then
            addon:Debug("Owned house list unavailable; issuing fallback recovery request")
        else
            ownedHouseListRetryCount = ownedHouseListRetryCount + 1
            addon:Debug("Retrying owned house list request (" .. tostring(ownedHouseListRetryCount) .. ")")
        end

        C_Housing.GetPlayerOwnedHouses()
        ScheduleOwnedHouseListRetry(generation)
    end)
end

local function SyncKnownPlots(houseInfos)
    if type(houseInfos) ~= "table" then
        addon:Debug("Ignoring invalid owned house list payload")
        return
    end

    ownedHouseListRequestGeneration = ownedHouseListRequestGeneration + 1
    CancelOwnedHouseListRetry()
    ownedHouseListRetryCount = 0
    local nextOwnedCompositeKeys = {}
    local nextHouseGUIDToComposite = {}
    local houseGUIDCounts = {}
    local houseGUIDCompositeCandidates = {}
    local compositeCounts = {}
    local ambiguousCompositeKeys = {}
    local hasUnsafeOwnedIdentity = false
    for _, houseInfo in ipairs(houseInfos) do
        local identityKey = GetHouseKey(houseInfo)
        if identityKey then
            compositeCounts[identityKey] = (compositeCounts[identityKey] or 0) + 1
        else
            hasUnsafeOwnedIdentity = true
        end

        local houseGUID = type(houseInfo) == "table" and houseInfo.houseGUID or nil
        if houseGUID ~= nil and houseGUID ~= "" then
            houseGUIDCounts[houseGUID] = (houseGUIDCounts[houseGUID] or 0) + 1
            if identityKey then
                houseGUIDCompositeCandidates[houseGUID] = identityKey
            end
        end
    end
    for identityKey, count in pairs(compositeCounts) do
        if count == 1 then
            nextOwnedCompositeKeys[identityKey] = true
        else
            ambiguousCompositeKeys[identityKey] = true
            hasUnsafeOwnedIdentity = true
        end
    end
    for houseGUID, count in pairs(houseGUIDCounts) do
        local identityKey = houseGUIDCompositeCandidates[houseGUID]
        if count ~= 1 then
            poisonedHouseGUIDs[houseGUID] = true
        elseif identityKey and not ambiguousCompositeKeys[identityKey] then
            local previousIdentityKey = previousHouseGUIDComposites[houseGUID]
            if previousIdentityKey and previousIdentityKey ~= identityKey then
                poisonedHouseGUIDs[houseGUID] = true
                levelRequestTimes[previousIdentityKey] = nil
                levelRequestTimes[identityKey] = nil
            elseif not previousIdentityKey then
                previousHouseGUIDComposites[houseGUID] = identityKey
            end
            if not poisonedHouseGUIDs[houseGUID] then
                nextHouseGUIDToComposite[houseGUID] = identityKey
            end
        end
    end
    ownedCompositeKeys = nextOwnedCompositeKeys
    houseGUIDToComposite = nextHouseGUIDToComposite
    ownedHouseListReady = true

    local db, normalizedChanged = GetBudgetDB()
    if not db then
        ScheduleCaptureBudget()
        return false
    end

    local knownPlots = NormalizeKnownPlots(db)
    local seen = {}
    local changed = normalizedChanged == true
    for _, houseInfo in ipairs(houseInfos) do
        -- Mark seen from the house identity itself, independently of whether
        -- RememberHouseInfo accepted the row. It declines an unfetched
        -- (negative) plotID, and without this the server still lists the house
        -- while its stored row looks unseen -- which would let the prune below
        -- delete a real owned house's cached metadata.
        local identityKey = GetHouseKey(houseInfo)
        if identityKey then
            seen[identityKey] = true
        end

        if not identityKey or not ambiguousCompositeKeys[identityKey] then
            local plotKey, houseChanged = RememberHouseInfo(db, houseInfo, false)
            if plotKey then
                seen[plotKey] = true
                changed = changed or houseChanged
                local plotInfo = knownPlots[plotKey]
                RequestHouseLevelFavor(plotInfo, true)
            end
        end
    end

    if not hasUnsafeOwnedIdentity then
        for plotKey, plotInfo in pairs(knownPlots) do
            if not seen[plotKey] and not plotInfo.visited and not next(plotInfo.budgets) then
                levelRequestTimes[plotKey] = nil
                knownPlots[plotKey] = nil
                changed = true
            end
        end
    else
        addon:Debug("Owned house sync skipped stale-row pruning: at least one house identity is unresolved or ambiguous")
    end

    if changed then
        addon:FireEvent(addon.Events.PLACEMENT_BUDGET_UPDATED)
    end
    ScheduleCaptureBudget()
end

local function OnHouseLevelFavorUpdated(houseLevelFavor)
    local snapshot = CalculateHouseLevelSnapshot(houseLevelFavor)
    if not snapshot then return end
    SaveHouseLevelSnapshotByGUID(houseLevelFavor.houseGUID, snapshot)
end

local function RequestPlayerOwnedHouses()
    if not C_Housing or type(C_Housing.GetPlayerOwnedHouses) ~= "function" then return end

    -- The generated docs expose no direct return or completion cross-link, so
    -- use fast retries followed by a low-frequency recovery request without
    -- ever opening the ownership gate speculatively.
    ownedHouseListRequestGeneration = ownedHouseListRequestGeneration + 1
    local generation = ownedHouseListRequestGeneration
    CancelOwnedHouseListRetry()
    ownedHouseListRetryCount = 0
    ownedCompositeKeys = {}
    houseGUIDToComposite = {}
    ownedHouseListReady = false
    C_Housing.GetPlayerOwnedHouses()
    ScheduleOwnedHouseListRetry(generation)
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
    local isOwnedContext = GetOwnedBudgetContext()
    return isOwnedContext
end

function addon:IsOwnedPlacementBudgetIdentity(identityKey)
    return ownedHouseListReady and type(identityKey) == "string"
        and ownedCompositeKeys[identityKey] == true
end

function addon:GetCurrentPlacementBudgetContext()
    local isOwnedContext, houseInfo, houseKey = GetOwnedBudgetContext()
    if not isOwnedContext then
        return nil, nil
    end

    local context = GetCurrentContext()
    if not context then return nil, nil, nil end

    local neighborhoodGUID = type(houseInfo) == "table" and houseInfo.neighborhoodGUID or nil
    if IsSecretValue(neighborhoodGUID) then
        neighborhoodGUID = nil
    end
    return houseKey, context, neighborhoodGUID
end

addon:RegisterWoWEvent("HOUSE_PLOT_ENTERED", OnHousePlotEntered)
addon:RegisterWoWEvent("HOUSING_NUM_DECOR_PLACED_CHANGED", ScheduleCaptureBudget)
addon:RegisterWoWEvent("CURRENT_HOUSE_INFO_RECIEVED", OnCurrentHouseInfoChanged)
addon:RegisterWoWEvent("CURRENT_HOUSE_INFO_UPDATED", OnCurrentHouseInfoChanged)
addon:RegisterWoWEvent("HOUSE_EDITOR_MODE_CHANGED", ScheduleCaptureBudget)
addon:RegisterWoWEvent("PLAYER_HOUSE_LIST_UPDATED", SyncKnownPlots)
addon:RegisterWoWEvent("HOUSE_LEVEL_FAVOR_UPDATED", OnHouseLevelFavorUpdated)
addon:RegisterWoWEvent("PLAYER_ENTERING_WORLD", function()
    RequestPlayerOwnedHouses()
    RequestCurrentHouseInfo()
    ScheduleCaptureBudget()
end)
addon:RegisterWoWEvent("HOUSE_LEVEL_CHANGED", function(newHouseLevelInfo)
    if newHouseLevelInfo == nil then return end
    RequestPlayerOwnedHouses()
    ScheduleCaptureBudget()
end)
addon:RegisterWoWEvent("HOUSE_PLOT_EXITED", NotifyBudgetUpdated)
