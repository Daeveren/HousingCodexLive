--[[
    Housing Codex - EndeavorsData.lua
    Data layer for the Endeavors mini-panel: zone detection, house XP,
    neighborhood initiative progress, and task diff tracking.
]]

local ADDON_NAME, addon = ...

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
    maxHouseLevel = 0,
    isMaxLevel = false,
    initiativeInfo = nil,
    taskSnapshots = {},    -- { [taskID] = { current, max } }
    sessionProgress = {},  -- { [taskID] = { taskName, current, max, lastChangedTime, delta, completed } }
}
EndeavorsData.state = state

-- Debounce timers
local zoneCheckTimer = nil
local initiativeUpdateTimer = nil

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
    return nil
end

--------------------------------------------------------------------------------
-- Zone Detection
--------------------------------------------------------------------------------

local function CheckNeighborhoodZone()
    local wasInNeighborhood = state.isInNeighborhood
    state.isInNeighborhood = C_Housing.IsOnNeighborhoodMap()

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
    C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()

    -- Get max house level (non-async, non-secret)
    state.maxHouseLevel = C_Housing.GetMaxHouseLevel() or 0

    addon:FireEvent("ENDEAVORS_ZONE_CHANGED", true)
end

function EndeavorsData:OnLeaveNeighborhood()
    addon:Debug("Endeavors: left neighborhood")

    -- Clear transient state but preserve session progress
    state.hasHouse = false
    state.houseGUID = nil
    state.houseLevel = 0
    state.houseFavor = 0
    state.houseFavorNeeded = 0
    state.isMaxLevel = false
    state.initiativeInfo = nil
    wipe(state.taskSnapshots)

    addon:FireEvent("ENDEAVORS_ZONE_CHANGED", false)
end

--------------------------------------------------------------------------------
-- House Ownership & XP
--------------------------------------------------------------------------------

local function OnHouseListUpdated(houseInfoList)
    if not state.isInNeighborhood then return end

    if not houseInfoList or #houseInfoList == 0 then
        state.hasHouse = false
        addon:FireEvent("ENDEAVORS_HOUSE_LEVEL_UPDATED")
        return
    end

    state.hasHouse = true

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

    -- Fallback to first house
    if not matchedHouse then
        matchedHouse = houseInfoList[1]
    end

    if matchedHouse and matchedHouse.houseGUID then
        state.houseGUID = matchedHouse.houseGUID
        -- Request favor data (SecretArgs, async, fires HOUSE_LEVEL_FAVOR_UPDATED)
        pcall(C_Housing.GetCurrentHouseLevelFavor, state.houseGUID)
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

    if state.isMaxLevel then
        state.houseFavorNeeded = 0
    else
        -- Calculate bar segment (follows Blizzard HousingDashboardHouseUpgrade pattern)
        local favorForCurrent = SafeCall(C_Housing.GetHouseLevelFavorForLevel, state.houseLevel) or 0
        local favorForNext = SafeCall(C_Housing.GetHouseLevelFavorForLevel, state.houseLevel + 1)

        if favorForNext then
            state.houseFavor = state.houseFavor - favorForCurrent
            state.houseFavorNeeded = favorForNext - favorForCurrent
        else
            state.houseFavorNeeded = 0
        end
    end

    addon:FireEvent("ENDEAVORS_HOUSE_LEVEL_UPDATED")
end

local function OnHouseLevelChanged()
    if not state.isInNeighborhood or not state.houseGUID then return end
    -- Re-request favor for fresh bar after level-up
    pcall(C_Housing.GetCurrentHouseLevelFavor, state.houseGUID)
end

--------------------------------------------------------------------------------
-- Initiative / Endeavor Progress
--------------------------------------------------------------------------------

local function DiffTaskProgress(info)
    if not info or not info.tasks then return end

    for _, task in ipairs(info.tasks) do
        local taskID = task.ID  -- API field is "ID" per InitiativeTaskInfo
        if taskID then
            local reqText
            if task.requirementsList and task.requirementsList[1] then
                reqText = task.requirementsList[1].requirementText
            end

            local current, max = ParseTaskProgress(reqText)
            if current and max then
                local oldSnapshot = state.taskSnapshots[taskID]
                local isCompleted = task.completed  -- API field is "completed" per InitiativeTaskInfo

                if oldSnapshot then
                    local delta = current - oldSnapshot.current
                    if delta > 0 or (isCompleted and not (state.sessionProgress[taskID] and state.sessionProgress[taskID].completed)) then
                        state.sessionProgress[taskID] = {
                            taskName = task.taskName or "",
                            current = current,
                            max = max,
                            lastChangedTime = GetTime(),
                            delta = (state.sessionProgress[taskID] and state.sessionProgress[taskID].delta or 0) + math.max(delta, 0),
                            completed = isCompleted,
                        }

                        if isCompleted then
                            addon:FireEvent("ENDEAVORS_TASK_COMPLETED", task.taskName or "")
                        end
                    elseif state.sessionProgress[taskID] then
                        -- Update current/max without touching lastChangedTime
                        state.sessionProgress[taskID].current = current
                        state.sessionProgress[taskID].max = max
                    end
                end

                state.taskSnapshots[taskID] = { current = current, max = max }
            end
        end
    end
end

local function OnInitiativeUpdated()
    if not state.isInNeighborhood then return end

    local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
    if not info or not info.isLoaded then return end

    state.initiativeInfo = info
    DiffTaskProgress(info)

    addon:FireEvent("ENDEAVORS_INITIATIVE_UPDATED")
end

local function OnTaskCompleted()
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

function EndeavorsData:GetInitiativeInfo()
    return state.initiativeInfo
end

function EndeavorsData:IsInitiativeEnabled()
    return C_NeighborhoodInitiative.IsInitiativeEnabled()
end

-- Returns active session tasks sorted by most recent change
-- Active = delta > 0 AND not completed, AND age < TASK_FADE_TIMEOUT
function EndeavorsData:GetActiveTasks()
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
                completed = entry.completed,
                age = age,
                lastChangedTime = entry.lastChangedTime,
            }
        end
    end

    -- Sort by most recent first
    table.sort(result, function(a, b)
        return a.lastChangedTime > b.lastChangedTime
    end)

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
-- WoW Event Registration
--------------------------------------------------------------------------------

-- Zone detection events
addon:RegisterWoWEvent("ZONE_CHANGED_NEW_AREA", function()
    if zoneCheckTimer then zoneCheckTimer:Cancel() end
    zoneCheckTimer = C_Timer.NewTimer(CONST.ZONE_CHECK_DEBOUNCE, CheckNeighborhoodZone)
end)

addon:RegisterWoWEvent("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(1.0, CheckNeighborhoodZone)
end)

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
