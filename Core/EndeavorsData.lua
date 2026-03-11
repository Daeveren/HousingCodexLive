--[[
    Housing Codex - EndeavorsData.lua
    Data layer for the Endeavors mini-panel: zone detection, house XP,
    neighborhood initiative progress, and task diff tracking.
]]

local _, addon = ...

local EndeavorsData = {}
addon.EndeavorsData = EndeavorsData

local CONST = addon.CONSTANTS.ENDEAVORS

-- Persistent state (survives show/hide, cleared on zone leave)
local state = {
    isInNeighborhood = false,
    hasHouse = false,
    houseGUID = nil,
    houseLevel = 0,
    houseFavor = 0,
    houseFavorNeeded = 0,
    houseFavorTotal = 0,        -- cumulative favor (text display)
    houseFavorTotalNeeded = 0,  -- cumulative favor threshold for next level (text display)
    maxHouseLevel = 0,
    isMaxLevel = false,
    initiativeInfo = nil,
    taskSnapshots = {},    -- { [taskID] = { current, max } }
    sessionProgress = {},  -- { [taskID] = { taskName, current, max, lastChangedTime, delta, completed } }
    lastNeighborhoodGUID = nil,
    lastCycleID = nil,
    initiativeDataFresh = false,
}
EndeavorsData.state = state

-- Debounce timers
local zoneCheckTimer = nil
local initiativeUpdateTimer = nil
local initiativePollTicker = nil

-- House list retry (guards against nil neighborhoodGUID on early event)
local houseListRetryCount = 0
local HOUSE_LIST_MAX_RETRIES = 3

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Parse "N/M" from initiative task requirement text
local function ParseTaskProgress(text)
    if not text then return nil, nil end
    local current, max = text:match("(%d+)%s*/%s*(%d+)")
    if current and max then
        return tonumber(current), tonumber(max)
    end
    return nil, nil
end

-- Safe pcall wrapper for SecretArguments APIs
local function SafeCall(func, ...)
    local ok, result = pcall(func, ...)
    if ok then return result end
    addon:Debug("Endeavors: SafeCall failed:", result)
    return nil
end

--------------------------------------------------------------------------------
-- Zone Detection
--------------------------------------------------------------------------------

local function CheckNeighborhoodZone()
    if not (addon.db and addon.db.endeavors and addon.db.endeavors.enabled) then
        state.isInNeighborhood = false
        return
    end
    local wasInNeighborhood = state.isInNeighborhood
    local isOnMap = C_Housing.IsOnNeighborhoodMap()
    local isInHouse = C_Housing.IsInsideHouseOrPlot()
    state.isInNeighborhood = isOnMap or isInHouse

    addon:Debug("Endeavors: CheckNeighborhoodZone - onMap:", isOnMap, "inHouse:", isInHouse, "was:", wasInNeighborhood, "now:", state.isInNeighborhood)

    if state.isInNeighborhood and not wasInNeighborhood then
        EndeavorsData:OnEnterNeighborhood()
    elseif not state.isInNeighborhood and wasInNeighborhood then
        EndeavorsData:OnLeaveNeighborhood()
    end
end

function EndeavorsData:OnEnterNeighborhood()
    addon:Debug("Endeavors: entered neighborhood")

    -- Request house data (async, fires PLAYER_HOUSE_LIST_UPDATED)
    C_Housing.GetPlayerOwnedHouses()

    -- Request initiative data (async, fires NEIGHBORHOOD_INITIATIVE_UPDATED)
    -- Skip if endeavor bar is disabled (no visible consumer for poll data)
    if addon.db and addon.db.endeavors and addon.db.endeavors.showEndeavorProgress then
        C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
    end

    -- Get max house level (non-async, non-secret)
    state.maxHouseLevel = C_Housing.GetMaxHouseLevel() or 0

    addon:FireEvent("ENDEAVORS_ZONE_CHANGED", true)
end

function EndeavorsData:OnLeaveNeighborhood()
    addon:Debug("Endeavors: left neighborhood")

    self:StopInitiativePoll()
    houseListRetryCount = 0

    -- Clear transient state but preserve session progress
    state.hasHouse = false
    state.houseGUID = nil
    state.houseLevel = 0
    state.houseFavor = 0
    state.houseFavorNeeded = 0
    state.houseFavorTotal = 0
    state.houseFavorTotalNeeded = 0
    state.isMaxLevel = false
    state.initiativeInfo = nil
    state.initiativeDataFresh = false
    wipe(state.taskSnapshots)
    state.lastNeighborhoodGUID = nil
    state.lastCycleID = nil

    addon:FireEvent("ENDEAVORS_ZONE_CHANGED", false)
end

--------------------------------------------------------------------------------
-- House Ownership & XP
--------------------------------------------------------------------------------

local function OnHouseListUpdated(houseInfoList)
    if not state.isInNeighborhood then return end

    if not houseInfoList or #houseInfoList == 0 then
        state.hasHouse = false
        state.houseGUID = nil
        addon:FireEvent("ENDEAVORS_HOUSE_LEVEL_UPDATED")
        return
    end

    -- Match house to current neighborhood
    local neighborhoodGUID = C_Housing.GetCurrentNeighborhoodGUID()
    local matchedHouse = nil

    if neighborhoodGUID then
        for _, houseInfo in ipairs(houseInfoList) do
            if houseInfo.neighborhoodGUID == neighborhoodGUID then
                matchedHouse = houseInfo
                break
            end
        end
    end

    -- neighborhoodGUID not ready yet — retry instead of treating as unowned
    if not matchedHouse and not neighborhoodGUID and houseListRetryCount < HOUSE_LIST_MAX_RETRIES then
        houseListRetryCount = houseListRetryCount + 1
        addon:Debug("Endeavors: neighborhoodGUID nil, retry", houseListRetryCount)
        C_Timer.After(1.0, function()
            if state.isInNeighborhood then
                C_Housing.GetPlayerOwnedHouses()
            end
        end)
        return
    end

    -- No house in this neighborhood — treat as unowned
    if not matchedHouse then
        state.hasHouse = false
        state.houseGUID = nil
        addon:FireEvent("ENDEAVORS_HOUSE_LEVEL_UPDATED")
        return
    end

    houseListRetryCount = 0
    state.hasHouse = true

    if matchedHouse.houseGUID then
        state.houseGUID = matchedHouse.houseGUID
        -- Request favor data (SecretArgs, async, fires HOUSE_LEVEL_FAVOR_UPDATED)
        SafeCall(C_Housing.GetCurrentHouseLevelFavor, state.houseGUID)
    end

    addon:FireEvent("ENDEAVORS_HOUSE_LEVEL_UPDATED")
end

local function OnHouseLevelFavorUpdated(houseLevelFavor)
    if not state.isInNeighborhood then return end
    if not houseLevelFavor then return end
    -- Filter to our house (Blizzard HousingDashboardHouseUpgrade pattern)
    if houseLevelFavor.houseGUID ~= state.houseGUID then return end

    state.houseLevel = houseLevelFavor.houseLevel or 0
    state.houseFavor = houseLevelFavor.houseFavor or 0
    state.maxHouseLevel = C_Housing.GetMaxHouseLevel() or state.maxHouseLevel
    state.isMaxLevel = state.houseLevel >= state.maxHouseLevel

    -- Cumulative values for text display (matches Blizzard tooltip); set before bar math mutates houseFavor
    state.houseFavorTotal = state.houseFavor

    if state.isMaxLevel then
        state.houseFavorNeeded = 0
        state.houseFavorTotalNeeded = 0
    else
        -- Calculate bar segment (follows Blizzard HousingDashboardHouseUpgrade pattern)
        local favorForCurrent = SafeCall(C_Housing.GetHouseLevelFavorForLevel, state.houseLevel) or 0
        local favorForNext = SafeCall(C_Housing.GetHouseLevelFavorForLevel, state.houseLevel + 1)

        if favorForNext then
            state.houseFavorTotalNeeded = favorForNext
            -- Level-relative values for bar fill
            state.houseFavor = state.houseFavor - favorForCurrent
            state.houseFavorNeeded = favorForNext - favorForCurrent
        else
            state.houseFavorTotalNeeded = 0
            state.houseFavorNeeded = 0
        end
    end

    addon:FireEvent("ENDEAVORS_HOUSE_LEVEL_UPDATED")
end

local function OnHouseLevelChanged()
    if not state.isInNeighborhood or not state.houseGUID then return end
    -- Re-request favor for fresh bar after level-up
    SafeCall(C_Housing.GetCurrentHouseLevelFavor, state.houseGUID)
end

--------------------------------------------------------------------------------
-- Initiative / Endeavor Progress
--------------------------------------------------------------------------------

local function DiffTaskProgress(info)
    if not info or not info.tasks then return false end

    local hasChanges = false
    for _, task in ipairs(info.tasks) do
        local taskID = task.ID  -- API field is "ID" per InitiativeTaskInfo
        if taskID then
            -- Use the first requirement entry that yields a parseable "N/M" pair
            local current, max
            if task.requirementsList then
                for _, reqEntry in ipairs(task.requirementsList) do
                    current, max = ParseTaskProgress(reqEntry.requirementText)
                    if current and max then break end
                end
            end
            if current and max then
                local oldSnapshot = state.taskSnapshots[taskID]
                local isCompleted = task.completed  -- API field is "completed" per InitiativeTaskInfo
                local prevProgress = state.sessionProgress[taskID]

                if oldSnapshot then
                    local delta = current - oldSnapshot.current
                    if delta > 0 or (isCompleted and not (prevProgress and prevProgress.completed)) then
                        hasChanges = true
                        state.sessionProgress[taskID] = {
                            taskName = task.taskName or "",
                            current = current,
                            max = max,
                            lastChangedTime = GetTime(),
                            delta = (prevProgress and prevProgress.delta or 0) + math.max(delta, 0),
                            completed = isCompleted,
                            timesCompleted = task.timesCompleted or 0,
                            rewardQuestID = task.rewardQuestID or 0,
                            taskType = task.taskType,
                        }

                        if isCompleted then
                            addon:FireEvent("ENDEAVORS_TASK_COMPLETED", task.taskName or "")
                        end
                    elseif prevProgress then
                        -- Update current/max without touching lastChangedTime
                        prevProgress.current = current
                        prevProgress.max = max
                        prevProgress.timesCompleted = task.timesCompleted or 0
                        prevProgress.rewardQuestID = task.rewardQuestID or 0
                        prevProgress.taskType = task.taskType
                    end
                end

                state.taskSnapshots[taskID] = { current = current, max = max }
            end
        end
    end

    return hasChanges
end

local function OnInitiativeUpdated()
    addon:Debug("Endeavors: OnInitiativeUpdated - isInNeighborhood:", state.isInNeighborhood)
    if not state.isInNeighborhood then return end

    local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
    addon:Debug("Endeavors: info:", info ~= nil, "isLoaded:", info and info.isLoaded, "tasks:", info and info.tasks and #info.tasks or 0)
    if not info or not info.isLoaded then return end

    state.initiativeInfo = info

    -- Wipe task state when neighborhood or cycle changes to prevent stale data bleed
    local scopeChanged = info.neighborhoodGUID and info.currentCycleID
        and (state.lastNeighborhoodGUID ~= info.neighborhoodGUID or state.lastCycleID ~= info.currentCycleID)
    if scopeChanged then
        wipe(state.taskSnapshots)
        wipe(state.sessionProgress)
        state.lastNeighborhoodGUID = info.neighborhoodGUID
        state.lastCycleID = info.currentCycleID
    end

    state.initiativeDataFresh = true

    -- Debug: log snapshot state before diff
    if addon.db and addon.db.settings and addon.db.settings.debugMode then
        local snapshotCount = 0
        for _ in pairs(state.taskSnapshots) do snapshotCount = snapshotCount + 1 end
        addon:Debug("Endeavors: pre-diff snapshots:", snapshotCount)
    end

    local hasChanges = DiffTaskProgress(info)

    -- Debug: log snapshot state after diff
    if addon.db and addon.db.settings and addon.db.settings.debugMode then
        local afterCount = 0
        for _ in pairs(state.taskSnapshots) do afterCount = afterCount + 1 end
        local progressCount = 0
        for _ in pairs(state.sessionProgress) do progressCount = progressCount + 1 end
        addon:Debug("Endeavors: post-diff snapshots:", afterCount, "sessionProgress:", progressCount, "hasChanges:", hasChanges)
    end

    addon:FireEvent("ENDEAVORS_INITIATIVE_UPDATED", hasChanges)
end

local function OnTaskCompleted()
    addon:Debug("Endeavors: INITIATIVE_TASK_COMPLETED fired, isInNeighborhood:", state.isInNeighborhood)
    if not state.isInNeighborhood then return end
    -- Request fresh data to update the diff
    C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
end

--------------------------------------------------------------------------------
-- Public Accessors
--------------------------------------------------------------------------------

function EndeavorsData:IsInNeighborhood()
    return state.isInNeighborhood
end

function EndeavorsData:RecheckNeighborhoodZone()
    CheckNeighborhoodZone()
end

function EndeavorsData:HasHouse()
    return state.hasHouse
end

function EndeavorsData:GetHouseLevel()
    return state.houseLevel
end

function EndeavorsData:IsMaxLevel()
    return state.isMaxLevel
end

function EndeavorsData:GetHouseXPProgress()
    if state.isMaxLevel then
        return 1, 1, true
    end
    return state.houseFavor, state.houseFavorNeeded, false
end

-- Returns cumulative favor values (matches Blizzard's Housing Dashboard display)
function EndeavorsData:GetHouseXPTotal()
    return state.houseFavorTotal, state.houseFavorTotalNeeded
end

function EndeavorsData:GetInitiativeInfo()
    return state.initiativeInfo
end

function EndeavorsData:IsInitiativeEnabled()
    return C_NeighborhoodInitiative.IsInitiativeEnabled()
end

-- Returns active session tasks sorted by most recent change
-- Active = delta > 0, not completed, age < TASK_FADE_TIMEOUT
function EndeavorsData:GetActiveTasks()
    -- Don't return stale tasks from a previous neighborhood
    if not state.initiativeDataFresh then return {} end

    local now = GetTime()
    local result = {}

    for taskID, entry in pairs(state.sessionProgress) do
        local age = now - entry.lastChangedTime
        if age < CONST.TASK_FADE_TIMEOUT and entry.delta > 0 and not entry.completed then
            result[#result + 1] = {
                taskID = taskID,
                taskName = entry.taskName,
                current = entry.current,
                max = entry.max,
                age = age,
                lastChangedTime = entry.lastChangedTime,
                timesCompleted = entry.timesCompleted,
                rewardQuestID = entry.rewardQuestID,
                taskType = entry.taskType,
            }
        end
    end

    -- Sort by most recent first
    table.sort(result, function(a, b)
        return a.lastChangedTime > b.lastChangedTime
    end)

    -- Debug: log why tasks were filtered
    if next(state.sessionProgress) and #result == 0 then
        for taskID, entry in pairs(state.sessionProgress) do
            local age = now - entry.lastChangedTime
            addon:Debug("Endeavors: filtered task", taskID, "delta:", entry.delta, "age:", string.format("%.1f", age), "limit:", CONST.TASK_FADE_TIMEOUT, "completed:", entry.completed)
        end
    end

    return result
end

-- Remove expired tasks (called from UI ticker)
function EndeavorsData:PruneExpiredTasks()
    local now = GetTime()
    local pruned = false

    for taskID, entry in pairs(state.sessionProgress) do
        if (now - entry.lastChangedTime) >= CONST.TASK_FADE_TIMEOUT then
            state.sessionProgress[taskID] = nil
            pruned = true
        end
    end

    return pruned
end

--------------------------------------------------------------------------------
-- Initiative Poll (progress detection requires periodic re-request)
-- NEIGHBORHOOD_INITIATIVE_UPDATED only fires in response to
-- RequestNeighborhoodInitiativeInfo(), not on every task progress increment.
--------------------------------------------------------------------------------

function EndeavorsData:StartInitiativePoll()
    if initiativePollTicker then return end
    if not state.isInNeighborhood then return end
    initiativePollTicker = C_Timer.NewTicker(CONST.INITIATIVE_POLL_INTERVAL, function()
        if not state.isInNeighborhood then
            EndeavorsData:StopInitiativePoll()
            return
        end
        C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
    end)
end

function EndeavorsData:StopInitiativePoll()
    if initiativePollTicker then
        initiativePollTicker:Cancel()
        initiativePollTicker = nil
    end
end

--------------------------------------------------------------------------------
-- WoW Event Registration
--------------------------------------------------------------------------------

-- Debounced zone check: cancels any pending timer, then schedules a new one
local function ScheduleZoneCheck()
    if zoneCheckTimer then zoneCheckTimer:Cancel() end
    zoneCheckTimer = C_Timer.NewTimer(CONST.ZONE_CHECK_DEBOUNCE, CheckNeighborhoodZone)
end

-- Zone detection events
addon:RegisterWoWEvent("ZONE_CHANGED_NEW_AREA", ScheduleZoneCheck)
addon:RegisterWoWEvent("ZONE_CHANGED",          ScheduleZoneCheck)
addon:RegisterWoWEvent("ZONE_CHANGED_INDOORS",  ScheduleZoneCheck)
addon:RegisterWoWEvent("PLAYER_MAP_CHANGED",    ScheduleZoneCheck)

addon:RegisterWoWEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(1.0, CheckNeighborhoodZone)
end)

-- Housing plot events: ENTERED is immediate (definitive signal), EXITED is debounced
addon:RegisterWoWEvent("HOUSE_PLOT_ENTERED", function()
    if zoneCheckTimer then zoneCheckTimer:Cancel() end
    zoneCheckTimer = nil
    CheckNeighborhoodZone()
end)

addon:RegisterWoWEvent("HOUSE_PLOT_EXITED", ScheduleZoneCheck)

-- House events
addon:RegisterWoWEvent("PLAYER_HOUSE_LIST_UPDATED", OnHouseListUpdated)
addon:RegisterWoWEvent("HOUSE_LEVEL_FAVOR_UPDATED", OnHouseLevelFavorUpdated)
addon:RegisterWoWEvent("HOUSE_LEVEL_CHANGED", OnHouseLevelChanged)

-- Initiative events
addon:RegisterWoWEvent("NEIGHBORHOOD_INITIATIVE_UPDATED", function()
    if initiativeUpdateTimer then initiativeUpdateTimer:Cancel() end
    initiativeUpdateTimer = C_Timer.NewTimer(CONST.UPDATE_DEBOUNCE, OnInitiativeUpdated)
end)

addon:RegisterWoWEvent("INITIATIVE_TASK_COMPLETED", OnTaskCompleted)
