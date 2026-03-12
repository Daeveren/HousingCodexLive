--[[
    Housing Codex - TreasureHuntWaypoints.lua
    Automatic map waypoints for Decor Treasure Hunt daily quests

    Sets native Blizzard waypoints when accepting Treasure Hunt quests.
    Listens globally - quest ID check filters to treasure hunt quests only.
]]

local _, addon = ...

addon.TreasureHuntWaypoints = {}

-- State
local activeQuestId = nil
local eventsRegistered = false
local pendingCombatQuestId = nil
local combatRegenCallback = nil

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

    -- UX courtesy: don't silently move waypoint during combat
    if UnitAffectingCombat("player") then
        pendingCombatQuestId = questId
        if not combatRegenCallback then
            combatRegenCallback = function()
                addon:UnregisterWoWEvent("PLAYER_REGEN_ENABLED", combatRegenCallback)
                combatRegenCallback = nil
                local qid = pendingCombatQuestId
                pendingCombatQuestId = nil
                if qid and C_QuestLog.IsOnQuest(qid) then
                    SetWaypoint(qid)
                end
            end
            addon:RegisterWoWEvent("PLAYER_REGEN_ENABLED", combatRegenCallback)
        end
        addon:Debug("Treasure Hunt: Deferring waypoint until combat ends (quest " .. tostring(questId) .. ")")
        return
    end

    pendingCombatQuestId = nil

    if not addon.Waypoints:Set(loc.mapID, loc.x, loc.y, "Decor Treasure") then
        addon:Debug(string.format("Treasure Hunt: Cannot set waypoint on map %d", loc.mapID))
        return
    end

    activeQuestId = questId

    -- Get clickable map pin link and notify user
    local hyperlink = addon.Waypoints:GetHyperlink()
    if hyperlink then
        addon:Print(addon.L["TREASURE_HUNT_WAYPOINT_SET"] .. " " .. hyperlink)
    end

    addon:Debug(string.format("Treasure Hunt waypoint set: quest %d at map %d (%.4f, %.4f)",
        questId, loc.mapID, loc.x, loc.y))
end

local function ClearWaypoint()
    if activeQuestId then
        addon.Waypoints:Clear()
        addon:Debug("Treasure Hunt waypoint cleared")
        activeQuestId = nil
    end
end

-- Reconcile waypoint state after login/reload or setting toggle
local function Reconcile()
    if not addon.db or not addon.db.settings.treasureHuntWaypoints then return end
    if not IsInHousingZone() then return end

    -- Scan known treasure hunt quests to see if any are active
    for questId in pairs(addon.TreasureHuntLocations) do
        if C_QuestLog.IsOnQuest(questId) then
            if questId ~= activeQuestId then SetWaypoint(questId) end
            return
        end
    end

    -- No matching quest active — clear stale waypoint if present
    ClearWaypoint()
end

function addon.TreasureHuntWaypoints.UpdateListenerState()
    if not addon.db or not addon.db.settings then
        return
    end

    -- Listeners stay registered; setting gates behavior in handlers.
    -- If disabled mid-session, clear only the waypoint managed by this module.
    if not addon.db.settings.treasureHuntWaypoints then
        ClearWaypoint()
        return
    end

    -- Setting just enabled — reconcile in case a quest is already active
    Reconcile()
end

--------------------------------------------------------------------------------
-- Quest Event Handlers
--------------------------------------------------------------------------------
local function OnQuestAccepted(questId)
    if not IsInHousingZone() then return end
    if not addon.db or not addon.db.settings.treasureHuntWaypoints then return end
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
local function Initialize()
    if eventsRegistered then return end
    eventsRegistered = true

    addon:RegisterWoWEvent("QUEST_ACCEPTED", OnQuestAccepted)
    addon:RegisterWoWEvent("QUEST_TURNED_IN", OnQuestEnded)
    addon:RegisterWoWEvent("QUEST_REMOVED", OnQuestEnded)

    -- Reconcile on subsequent loading screens (instance transitions, teleports)
    addon:RegisterWoWEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0, Reconcile)
    end)

    -- Reconcile now for login/reload (PEW already fired before DATA_LOADED)
    C_Timer.After(0, Reconcile)

    addon:Debug("TreasureHunt: Ready")
end

addon:RegisterInternalEvent("DATA_LOADED", Initialize)
