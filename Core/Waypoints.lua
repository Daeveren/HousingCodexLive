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
    self:Clear()

    if self:IsTomTomActive() then
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

    -- Native path
    if not C_Map.CanSetUserWaypointOnMap(mapID) then
        return false
    end

    local point = UiMapPoint.CreateFromCoordinates(mapID, normX, normY)
    C_Map.SetUserWaypoint(point)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    activeWaypoint = { mapID = mapID, x = normX, y = normY, title = title }
    return true
end

function Waypoints:Clear()
    if activeTomTomUid then
        pcall(TomTom.RemoveWaypoint, TomTom, activeTomTomUid)
        activeTomTomUid = nil
    end

    -- Always clear native too for safety (e.g. toggling setting mid-session)
    if C_Map.HasUserWaypoint() then
        C_Map.ClearUserWaypoint()
        C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    end

    activeWaypoint = nil
end

function Waypoints:HasActive()
    if self:IsTomTomActive() then
        return activeWaypoint ~= nil
    end
    return C_Map.HasUserWaypoint()
end

function Waypoints:GetActive()
    return activeWaypoint
end

function Waypoints:GetHyperlink()
    if self:IsTomTomActive() then
        return nil
    end
    if C_Map.HasUserWaypoint() then
        return C_Map.GetUserWaypointHyperlink()
    end
    return nil
end

-- Detection at DATA_LOADED
addon:RegisterInternalEvent("DATA_LOADED", function()
    tomtomAvailable = (TomTom ~= nil
        and type(TomTom.AddWaypoint) == "function"
        and type(TomTom.RemoveWaypoint) == "function")

    addon:Debug("Waypoints: TomTom " .. (tomtomAvailable and "available" or "not found"))
end)
