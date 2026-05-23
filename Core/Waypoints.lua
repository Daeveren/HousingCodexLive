--[[
    Housing Codex - Waypoints.lua
    Central waypoint dispatch: routes through TomTom or native Blizzard waypoints
]]

local _, addon = ...
local L = addon.L

local Waypoints = {}
addon.Waypoints = Waypoints

local WAYPOINT_OWNER_GENERIC = addon.CONSTANTS.WAYPOINT_OWNER_GENERIC

-- State
local tomtomAvailable = false
local activeTomTomUid = nil
local activeWaypoint = nil  -- { mapID, x, y, title, owner }
local ownsNativeWaypoint = false  -- true when this addon placed the native waypoint
local isSettingWaypoint = false  -- guards against self-triggered USER_WAYPOINT_UPDATED
local isClearingWaypoint = false  -- guards against self-triggered USER_WAYPOINT_UPDATED
local waypointEventRegistered = false  -- never reset: survives DATA_LOADED re-fires on /hc retry

local function GetWaypointOwner(options)
    return type(options) == "table" and options.owner or WAYPOINT_OWNER_GENERIC
end

local function FireWaypointChanged(action, owner)
    addon:FireEvent(addon.Events.WAYPOINT_CHANGED, action, owner or WAYPOINT_OWNER_GENERIC, activeWaypoint)
end

local function ShowInvalidMapFeedback()
    local message = _G.MAP_PIN_INVALID_MAP or L["VENDOR_MAP_RESTRICTED"]
    local errorsFrame = _G.UIErrorsFrame
    if errorsFrame and type(errorsFrame.AddMessage) == "function" then
        local ok = pcall(errorsFrame.AddMessage, errorsFrame, message)
        if ok then return end
    end
    addon:Print(message)
end

local function ClearExistingWaypointState()
    if activeTomTomUid then
        if TomTom and type(TomTom.RemoveWaypoint) == "function" then
            pcall(TomTom.RemoveWaypoint, TomTom, activeTomTomUid)
        end
        activeTomTomUid = nil
    end

    local shouldClearNative = ownsNativeWaypoint and C_Map.HasUserWaypoint()
    ownsNativeWaypoint = false
    if shouldClearNative then
        isClearingWaypoint = true
        C_Map.ClearUserWaypoint()
        isClearingWaypoint = false
        C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    end

    activeWaypoint = nil
end

function Waypoints:IsTomTomAvailable()
    return tomtomAvailable
end

function Waypoints:IsTomTomActive()
    return tomtomAvailable
        and addon.db
        and addon.db.settings
        and addon.db.settings.useTomTom
end

function Waypoints:Set(mapID, normX, normY, title, options)
    local owner = GetWaypointOwner(options)

    if self:IsTomTomActive() then
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapID, normX, normY, {
            title = title,
            persistent = false,
            minimap = true,
            world = true,
            crazy = true,
            from = "HousingCodex",
        })
        if ok and uid then
            ClearExistingWaypointState()
            activeTomTomUid = uid
            activeWaypoint = { mapID = mapID, x = normX, y = normY, title = title, owner = owner }
            FireWaypointChanged("set", owner)
            return true
        end
        -- TomTom failed, fall through to native
        addon:Debug("Waypoints: TomTom AddWaypoint failed, falling back to native")
    end

    -- Native path: validate BEFORE clearing old waypoint
    if not C_Map.CanSetUserWaypointOnMap(mapID) then
        ShowInvalidMapFeedback()
        return false
    end

    -- Validation passed — safe to clear previous addon waypoint and place new one
    self:Clear(options)
    local point = UiMapPoint.CreateFromCoordinates(mapID, normX, normY)
    isSettingWaypoint = true
    C_Map.SetUserWaypoint(point)
    isSettingWaypoint = false
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    ownsNativeWaypoint = true
    activeWaypoint = { mapID = mapID, x = normX, y = normY, title = title, owner = owner }
    FireWaypointChanged("set", owner)
    return true
end

function Waypoints:Clear(options)
    local owner = GetWaypointOwner(options)
    local hadWaypoint = activeTomTomUid ~= nil or ownsNativeWaypoint or activeWaypoint ~= nil

    ClearExistingWaypointState()

    if hadWaypoint then
        FireWaypointChanged("clear", owner)
    end
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
    if isSettingWaypoint or isClearingWaypoint or not ownsNativeWaypoint then return end

    local function DropOwnership()
        ownsNativeWaypoint = false
        activeWaypoint = nil
        FireWaypointChanged("clear", WAYPOINT_OWNER_GENERIC)
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
