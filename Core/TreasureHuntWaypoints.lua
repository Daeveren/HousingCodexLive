--[[
    Housing Codex - TreasureHuntWaypoints.lua
    Automatic map waypoints for Decor Treasure Hunt daily quests

    Sets native Blizzard waypoints when accepting Treasure Hunt quests.
    Listens globally - quest ID check filters to treasure hunt quests only.
]]

local ADDON_NAME, addon = ...

-- State
local activeQuestId = nil

-- Housing zone map IDs
local HOUSING_ZONES = {
    [2352] = true,  -- Founder's Point (Alliance)
    [2351] = true,  -- Razorwind Shores (Horde)
}

local function IsInHousingZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    return mapID and HOUSING_ZONES[mapID]
end

--------------------------------------------------------------------------------
-- Waypoint Management
--------------------------------------------------------------------------------
local function SetWaypoint(questId)
    local loc = addon.TreasureHuntLocations[questId]
    if not loc then
        addon:Debug("Treasure Hunt: No location data for quest " .. tostring(questId))
        return
    end

    if not C_Map.CanSetUserWaypointOnMap(loc.mapID) then
        addon:Debug(string.format("Treasure Hunt: Cannot set waypoint on map %d", loc.mapID))
        return
    end

    C_Map.ClearUserWaypoint()
    local point = UiMapPoint.CreateFromCoordinates(loc.mapID, loc.x, loc.y)
    C_Map.SetUserWaypoint(point)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    activeQuestId = questId

    -- Get clickable map pin link and notify user
    local hyperlink = C_Map.GetUserWaypointHyperlink()
    if hyperlink then
        addon:Print(addon.L["TREASURE_HUNT_WAYPOINT_SET"] .. " " .. hyperlink)
    end

    addon:Debug(string.format("Treasure Hunt waypoint set: quest %d at map %d (%.4f, %.4f)",
        questId, loc.mapID, loc.x, loc.y))
end

local function ClearWaypoint()
    if activeQuestId then
        C_Map.ClearUserWaypoint()
        addon:Debug("Treasure Hunt waypoint cleared")
        activeQuestId = nil
    end
end

--------------------------------------------------------------------------------
-- Quest Event Handlers
--------------------------------------------------------------------------------
local function OnQuestAccepted(arg1, arg2)
    if not IsInHousingZone() then return end
    if not addon.db or not addon.db.settings.treasureHuntWaypoints then return end

    -- Handle both (questLogIndex, questId) and (questId) event signatures
    local questId = arg2 or arg1
    if not questId or not addon.TreasureHuntLocations[questId] then return end

    addon:Debug("Treasure hunt quest accepted: " .. questId)

    -- Defer to next frame for safe API access
    C_Timer.After(0, function()
        SetWaypoint(questId)
    end)
end

local function OnQuestEnded(questId)
    if questId == activeQuestId then
        ClearWaypoint()
    end
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------
addon:RegisterInternalEvent("DATA_LOADED", function()
    addon:Debug("TreasureHunt: Registering quest event listeners")

    addon:RegisterWoWEvent("QUEST_ACCEPTED", OnQuestAccepted)
    addon:RegisterWoWEvent("QUEST_TURNED_IN", OnQuestEnded)
    addon:RegisterWoWEvent("QUEST_REMOVED", OnQuestEnded)

    addon:Debug("TreasureHunt: Ready")
end)
