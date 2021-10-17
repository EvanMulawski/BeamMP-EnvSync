BeamMPEnvSyncState = {
    calcThreadCounter = 0,
    syncThreadPreviousTime = nil
}

MINUTES_PER_DAY = 1440
SECONDS_PER_MINUTE = 60
CLIENT_TIMER_ADJUST = 1/6
CLIENT_SECONDS_PER_MINUTE = math.floor(SECONDS_PER_MINUTE - (SECONDS_PER_MINUTE * CLIENT_TIMER_ADJUST))

function onInit()
    StopThread("updateServerTimeOfDay")
    math.randomseed(os.time())
    -- BeamMPEnvSyncState.timeOfDay = math.floor(math.random() * MINUTES_PER_DAY)
    BeamMPEnvSyncState.timeOfDay = 600; -- 10am
    BeamMPEnvSyncState.clientTimeOfDay = normalizeTimeOfDay(BeamMPEnvSyncState.timeOfDay)
    print("[ENVSYNC] Set initial time of day (" .. BeamMPEnvSyncState.timeOfDay .. " minutes = " .. BeamMPEnvSyncState.clientTimeOfDay .. " client time)")
    RegisterEvent("updateServerTimeOfDay", "updateServerTimeOfDay")
    CreateThread("updateServerTimeOfDay", 1)
    RegisterEvent("onPlayerJoin", "onPlayerJoin")
    recalcServerTimeOfDay()
    syncTimeOfDay()
end

local NIGHT_START_MIN = 1113;
local DAY_START_MIN = 327;
function recalcServerTimeOfDay()
    if not BeamMPEnvSyncState.syncThreadPreviousTime then
        BeamMPEnvSyncState.syncThreadPreviousTime = os.time()
        return
    end
    local current = BeamMPEnvSyncState.timeOfDay
    local elapsedSeconds = os.time() - BeamMPEnvSyncState.syncThreadPreviousTime
    local currentSeconds = current * SECONDS_PER_MINUTE
    local newTimeOfDaySeconds = currentSeconds
    local _max = currentSeconds + elapsedSeconds - 1
    --print("currentSeconds=" .. currentSeconds .. ";_max=" .. _max)
    for i = currentSeconds, _max do
        if current >= NIGHT_START_MIN or current < DAY_START_MIN then
            -- night
            newTimeOfDaySeconds = newTimeOfDaySeconds + (CLIENT_SECONDS_PER_MINUTE * 2)
        else
            -- day
            newTimeOfDaySeconds = newTimeOfDaySeconds + CLIENT_SECONDS_PER_MINUTE
        end
    end
    local newTimeOfDay = math.floor(newTimeOfDaySeconds / SECONDS_PER_MINUTE) % MINUTES_PER_DAY
    BeamMPEnvSyncState.timeOfDay = newTimeOfDay
    BeamMPEnvSyncState.clientTimeOfDay = normalizeTimeOfDay(newTimeOfDay)
    BeamMPEnvSyncState.syncThreadPreviousTime = os.time()
    --print("[ENVSYNC] Updated time of day to " .. BeamMPEnvSyncState.timeOfDay)
end

function normalizeTimeOfDay(timeOfDay)
    -- need to convert range [0,1440) (12am-11:59pm) to [0,1) (12pm-11:59am)
    local a = timeOfDay + (MINUTES_PER_DAY / 2)
    if a >= MINUTES_PER_DAY then
        a = a - MINUTES_PER_DAY
    end
    return a / 1440
end

function syncTimeOfDay()
    local ct = BeamMPEnvSyncState.clientTimeOfDay
    local t = BeamMPEnvSyncState.timeOfDay
    print("[ENVSYNC] Syncing time of day (" .. t .. " minutes = " .. ct .. " client time)")
    TriggerClientEvent(-1, "BeamMPEnvSyncSetTimeOfDay", ct)
end

function onPlayerJoin()
    syncTimeOfDay()
end

function updateServerTimeOfDay()
    local c = BeamMPEnvSyncState.calcThreadCounter
    if c > 60 then
        c = 0
        recalcServerTimeOfDay()
        syncTimeOfDay()
    end
    c = c + 1
    BeamMPEnvSyncState.calcThreadCounter = c
end
