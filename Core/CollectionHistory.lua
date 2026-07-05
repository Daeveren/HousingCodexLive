--[[
    Housing Codex - CollectionHistory.lua
    Daily collection snapshots for the Progress sidebar sparkline.
]]

local _, addon = ...

local SECONDS_PER_DAY = 86400
local HISTORY_METRIC = "decorCollected"
local pendingSnapshotRecords = {}
local ROOM_ENTRY_TYPE = Enum.HousingCatalogEntryType and Enum.HousingCatalogEntryType.Room or 2

local function IsRoomRecord(record)
    return record and record.entryID and record.entryID.entryType == ROOM_ENTRY_TYPE
end

local function IsCollectedDecor(recordID)
    if not recordID or not addon.GetRecord then return false end
    local record = addon:GetRecord(recordID)
    return record
        and record.isCollected == true
        and not IsRoomRecord(record)
end

local function GetTodayKey()
    if not GetServerTime then return nil end
    local now = GetServerTime()
    if type(now) ~= "number" then return nil end

    local secondsUntilReset = 0
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local reset = C_DateAndTime.GetSecondsUntilDailyReset()
        if type(reset) == "number" then
            secondsUntilReset = reset
        end
    end

    return math.floor((now + secondsUntilReset) / SECONDS_PER_DAY)
end

local function NormalizeHistoryDB(liveDay, liveCount, rebaseLiveDayLegacy)
    if not addon.db then return nil end
    if type(addon.db.collectionHistory) ~= "table" then
        addon.db.collectionHistory = {}
    end

    local today = GetTodayKey()
    local minDay = today and (today - addon.CONSTANTS.COLLECTION_HISTORY_RETENTION_DAYS) or nil
    local byDay = {}
    local normalizedChanged = false

    for _, entry in pairs(addon.db.collectionHistory) do
        if type(entry) == "table" and type(entry.day) == "number" and type(entry.count) == "number" then
            local day = math.floor(entry.day)
            if not minDay or day >= minDay then
                local count = math.max(0, math.floor(entry.count))
                local startCount = type(entry.startCount) == "number" and math.max(0, math.floor(entry.startCount)) or nil
                local gain = type(entry.gain) == "number" and math.max(0, math.floor(entry.gain)) or nil
                local metric = entry.metric == HISTORY_METRIC and HISTORY_METRIC or nil
                local shouldRebaseLegacy = rebaseLiveDayLegacy == true
                    and day == liveDay
                    and type(liveCount) == "number"
                    and metric ~= HISTORY_METRIC
                local existing = byDay[day]
                if existing then
                    if existing.metric ~= HISTORY_METRIC and metric == HISTORY_METRIC then
                        existing.count = count
                        existing.startCount = startCount
                        existing.gain = gain
                        existing.metric = metric
                    elseif existing.metric == HISTORY_METRIC and metric ~= HISTORY_METRIC then
                        -- Ignore legacy room-inclusive duplicate rows once a decor-only row exists.
                    else
                        if shouldRebaseLegacy and existing.metric ~= HISTORY_METRIC then
                            local clampedCount = math.max(0, math.floor(liveCount))
                            existing.count = clampedCount
                            existing.startCount = clampedCount
                            existing.gain = 0
                            existing.metric = HISTORY_METRIC
                            normalizedChanged = true
                        else
                            existing.count = math.max(existing.count, count)
                            if startCount then
                                existing.startCount = existing.startCount and math.min(existing.startCount, startCount) or startCount
                            end
                            if gain then
                                existing.gain = existing.gain and math.max(existing.gain, gain) or gain
                            end
                            if metric then
                                existing.metric = metric
                            end
                        end
                    end
                else
                    if shouldRebaseLegacy then
                        local clampedCount = math.max(0, math.floor(liveCount))
                        count = clampedCount
                        startCount = clampedCount
                        gain = 0
                        metric = HISTORY_METRIC
                        normalizedChanged = true
                    end
                    byDay[day] = {
                        day = day,
                        count = count,
                        startCount = startCount,
                        gain = gain,
                        metric = metric,
                    }
                end
            end
        end
    end

    local normalized = {}
    for _, entry in pairs(byDay) do
        normalized[#normalized + 1] = entry
    end
    table.sort(normalized, function(a, b) return a.day < b.day end)

    for i, entry in ipairs(normalized) do
        local previous = normalized[i - 1]
        if type(entry.startCount) ~= "number" then
            entry.startCount = previous and previous.count or entry.count
        end
        if entry.day == liveDay and type(liveCount) == "number" then
            local clampedCount = math.max(0, math.floor(liveCount))
            if entry.count ~= clampedCount then normalizedChanged = true end
            entry.count = clampedCount
        end
        local inferredGain = math.max(0, entry.count - entry.startCount)
        if entry.day == liveDay and type(liveCount) == "number" then
            if entry.gain ~= inferredGain then normalizedChanged = true end
            entry.gain = inferredGain
        else
            entry.gain = math.max(type(entry.gain) == "number" and entry.gain or 0, inferredGain)
        end
    end

    addon.db.collectionHistory = normalized
    return normalized, normalizedChanged
end

local function Snapshot(learnedDelta)
    if not addon.db or not addon.indexesBuilt then return end

    local today = GetTodayKey()
    if not today then return end

    local count = addon:GetDecorCollectedCount()
    if type(count) ~= "number" then return end
    count = math.max(0, math.floor(count))
    learnedDelta = math.max(0, math.floor(learnedDelta or 0))

    local history, normalizedChanged = NormalizeHistoryDB(today, count)
    if not history then return end

    local changed = normalizedChanged == true
    local last = history[#history]
    if last and last.day == today then
        if last.metric ~= HISTORY_METRIC then
            last.metric = HISTORY_METRIC
            last.count = count
            last.startCount = math.min(math.max(0, count - learnedDelta), count)
            last.gain = math.max(0, count - last.startCount)
            changed = true
        else
            if type(last.startCount) ~= "number" then
                last.startCount = math.min(last.count, count)
                changed = true
            end
            local previousCount = last.count
            local previousGain = type(last.gain) == "number" and last.gain or 0
            last.count = count
            local countGain = math.max(0, last.count - last.startCount)
            last.gain = countGain
            if last.count ~= previousCount or last.gain ~= previousGain then
                changed = true
            end
        end
    else
        local startCount = count
        if learnedDelta > 0 then
            startCount = math.max(0, count - learnedDelta)
            if last and last.metric == HISTORY_METRIC and type(last.count) == "number" and last.count <= count then
                startCount = math.max(startCount, last.count)
            end
        end
        startCount = math.min(startCount, count)
        history[#history + 1] = {
            day = today,
            count = count,
            startCount = startCount,
            gain = math.max(0, count - startCount),
            metric = HISTORY_METRIC,
        }
        changed = true
    end

    local minDay = today - addon.CONSTANTS.COLLECTION_HISTORY_RETENTION_DAYS
    while history[1] and history[1].day < minDay do
        table.remove(history, 1)
        changed = true
    end

    if changed then
        addon:FireEvent(addon.Events.COLLECTION_HISTORY_UPDATED)
    end
end

local historyTimer
local function SnapshotDebounced(recordID, collectionStateChanged)
    if recordID ~= nil and collectionStateChanged and IsCollectedDecor(recordID) then
        pendingSnapshotRecords[recordID] = true
    end
    if historyTimer then historyTimer:Cancel() end
    historyTimer = C_Timer.NewTimer(addon.CONSTANTS.TIMER.HISTORY_DEBOUNCE, function()
        historyTimer = nil
        local learnedDelta = 0
        for _ in pairs(pendingSnapshotRecords) do
            learnedDelta = learnedDelta + 1
        end
        pendingSnapshotRecords = {}
        Snapshot(learnedDelta)
    end)
end

function addon:GetCollectionHistoryGains(days)
    days = days or self.CONSTANTS.COLLECTION_HISTORY_DISPLAY_DAYS
    local today = GetTodayKey()
    if not today then return nil end

    local liveCount = addon.indexesBuilt and addon:GetDecorCollectedCount() or nil
    local history = NormalizeHistoryDB(today, liveCount, true)
    if not history then return nil end

    local entryByDay = {}
    for _, entry in ipairs(history) do
        entryByDay[entry.day] = entry
    end

    local result = {}
    local totalGain = 0
    local maxGain = 0
    for offset = days - 1, 0, -1 do
        local day = today - offset
        local entry = entryByDay[day]
        local gain = 0
        if entry then
            local inferredGain = 0
            if type(entry.startCount) == "number" then
                inferredGain = math.max(0, entry.count - entry.startCount)
            end
            gain = math.max(type(entry.gain) == "number" and entry.gain or 0, inferredGain)
        end

        result[#result + 1] = {
            dayOffset = -offset,
            gain = gain,
            count = entry and entry.count or nil,
            startCount = entry and entry.startCount or nil,
            hasData = entry ~= nil,
        }
        totalGain = totalGain + gain
        if gain > maxGain then maxGain = gain end
    end

    return {
        days = days,
        gains = result,
        totalGain = totalGain,
        maxGain = maxGain,
    }
end

addon:RegisterInternalEvent(addon.Events.DATA_LOADED, function()
    Snapshot(0)
end)
addon:RegisterInternalEvent(addon.Events.RECORD_OWNERSHIP_UPDATED, SnapshotDebounced)
