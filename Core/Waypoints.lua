--[[
    Housing Codex - Waypoints.lua
    Central waypoint dispatch: routes through TomTom or native Blizzard waypoints
]]

local _, addon = ...

local Waypoints = {}
addon.Waypoints = Waypoints

-- State
local tomtomAvailable = false
local activeTomTomUid = nil
local activeWaypoint = nil  -- { mapID, x, y, title }
local ownsNativeWaypoint = false  -- true when this addon placed the native waypoint
local isSettingWaypoint = false  -- guards against self-triggered USER_WAYPOINT_UPDATED
local waypointEventRegistered = false  -- never reset: survives DATA_LOADED re-fires on /hc retry

function Waypoints:IsTomTomAvailable()
    return tomtomAvailable
end

function Waypoints:IsTomTomActive()
    return tomtomAvailable
        and addon.db
        and addon.db.settings
        and addon.db.settings.useTomTom
end

function Waypoints:Set(mapID, normX, normY, title)
    if self:IsTomTomActive() then
        -- Clear previous addon waypoint first, then attempt TomTom
        self:Clear()
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapID, normX, normY, {
            title = title,
            persistent = false,
            minimap = true,
            world = true,
            from = "HousingCodex",
        })
        if ok and uid then
            activeTomTomUid = uid
            activeWaypoint = { mapID = mapID, x = normX, y = normY, title = title }
            return true
        end
        -- TomTom failed, fall through to native
        addon:Debug("Waypoints: TomTom AddWaypoint failed, falling back to native")
    end

    -- Native path: validate BEFORE clearing old waypoint
    if not C_Map.CanSetUserWaypointOnMap(mapID) then
        return false
    end

    -- Validation passed — safe to clear previous addon waypoint and place new one
    self:Clear()
    local point = UiMapPoint.CreateFromCoordinates(mapID, normX, normY)
    isSettingWaypoint = true
    C_Map.SetUserWaypoint(point)
    isSettingWaypoint = false
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    ownsNativeWaypoint = true
    activeWaypoint = { mapID = mapID, x = normX, y = normY, title = title }
    return true
end

function Waypoints:Clear()
    if activeTomTomUid then
        pcall(TomTom.RemoveWaypoint, TomTom, activeTomTomUid)
        activeTomTomUid = nil
    end

    -- Only clear native waypoint if this addon placed it
    if ownsNativeWaypoint and C_Map.HasUserWaypoint() then
        C_Map.ClearUserWaypoint()
        C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    end
    ownsNativeWaypoint = false

    activeWaypoint = nil
end

function Waypoints:GetActive()
    return activeWaypoint
end

function Waypoints:GetHyperlink()
    if self:IsTomTomActive() then return nil end
    return C_Map.HasUserWaypoint() and C_Map.GetUserWaypointHyperlink() or nil
end

-- Drop native ownership when external changes occur
local function ReconcileOwnership()
    if isSettingWaypoint or not ownsNativeWaypoint then return end

    local function DropOwnership()
        ownsNativeWaypoint = false
        activeWaypoint = nil
    end

    if not C_Map.HasUserWaypoint() then return DropOwnership() end

    local point = C_Map.GetUserWaypoint()
    if not point or not point.position or not activeWaypoint then return DropOwnership() end

    local x, y = point.position:GetXY()
    local EPSILON = addon.CONSTANTS.WAYPOINT_MATCH_EPSILON
    if x == nil or y == nil
        or point.uiMapID ~= activeWaypoint.mapID
        or math.abs(x - activeWaypoint.x) > EPSILON
        or math.abs(y - activeWaypoint.y) > EPSILON then
        DropOwnership()
    end
end

-- Detection at DATA_LOADED
addon:RegisterInternalEvent("DATA_LOADED", function()
    tomtomAvailable = (TomTom ~= nil
        and type(TomTom.AddWaypoint) == "function"
        and type(TomTom.RemoveWaypoint) == "function")

    addon:Debug("Waypoints: TomTom " .. (tomtomAvailable and "available" or "not found"))

    if not waypointEventRegistered then
        addon:RegisterWoWEvent("USER_WAYPOINT_UPDATED", ReconcileOwnership)
        waypointEventRegistered = true
    end
end)
