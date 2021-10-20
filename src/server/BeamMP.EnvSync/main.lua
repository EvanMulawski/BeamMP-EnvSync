BeamMPEnvSync = {
    _state = {
        calcThreadCounter = 0,
        syncThreadPreviousTime = nil,
    },
    INITIAL_TOD_MINS = 600,
    SYNCS_PER_MINUTE = 2,
    MINUTES_PER_DAY = 1440,
    SECONDS_PER_MINUTE = 60,
    CLIENT_TIMER_ADJUST = 1/6,
}
    BeamMPEnvSync.SECONDS_PER_DAY = BeamMPEnvSync.MINUTES_PER_DAY * BeamMPEnvSync.SECONDS_PER_MINUTE
    BeamMPEnvSync.CLIENT_SECONDS_PER_MINUTE = math.floor(BeamMPEnvSync.SECONDS_PER_MINUTE - (BeamMPEnvSync.SECONDS_PER_MINUTE * BeamMPEnvSync.CLIENT_TIMER_ADJUST))
    BeamMPEnvSync.ENV_TOD_NIGHT_START = 1113 * BeamMPEnvSync.SECONDS_PER_MINUTE
    BeamMPEnvSync.ENV_TOD_DAY_START = 327 * BeamMPEnvSync.SECONDS_PER_MINUTE

    function BeamMPEnvSync:init(postInit)
        if (self._state.init) then
            print("[ENVSYNC] BeamMPEnvSync already initialized")
            return
        end
        self._state.init = true
        self._state.timeOfDay = self.INITIAL_TOD_MINS * self.SECONDS_PER_MINUTE
        self._state.clientTimeOfDay = self:normalizeTimeOfDay(self._state.timeOfDay)
        self:recalcServerTimeOfDay()
        print("[ENVSYNC] Set initial time of day (" .. self._state.timeOfDay .. " seconds = " .. self._state.clientTimeOfDay .. " client time)")
        postInit()
    end

    function BeamMPEnvSync:recalcServerTimeOfDay()
        if not self._state.syncThreadPreviousTime then
            self._state.syncThreadPreviousTime = os.time()
            return
        end
        local elapsedSeconds = os.time() - self._state.syncThreadPreviousTime
        local currentSeconds = self._state.timeOfDay
        local newTimeOfDaySeconds = currentSeconds
        local _max = currentSeconds + elapsedSeconds - 1
        --print("currentSeconds=" .. currentSeconds .. ";_max=" .. _max)
        for i = currentSeconds, _max do
            --print(i)
            if i >= self.ENV_TOD_NIGHT_START or i < self.ENV_TOD_DAY_START then
                -- night
                --print("night")
                newTimeOfDaySeconds = newTimeOfDaySeconds + (self.CLIENT_SECONDS_PER_MINUTE * 2)
            else
                -- day
                --print("day")
                newTimeOfDaySeconds = newTimeOfDaySeconds + self.CLIENT_SECONDS_PER_MINUTE
            end
        end
        local newTimeOfDay = newTimeOfDaySeconds % self.SECONDS_PER_DAY
        self._state.timeOfDay = newTimeOfDay
        self._state.clientTimeOfDay = self:normalizeTimeOfDay(newTimeOfDay)
        self._state.syncThreadPreviousTime = os.time()
        --print("[ENVSYNC] Updated time of day to " .. self._state.timeOfDay)
    end

    function BeamMPEnvSync:normalizeTimeOfDay(timeOfDay)
        -- need to convert range [0,86400) (12am-11:59pm) to [0,1) (12pm-11:59am)
        local a = timeOfDay + (self.SECONDS_PER_DAY / 2)
        if a >= self.SECONDS_PER_DAY then
            a = a - self.SECONDS_PER_DAY
        end
        return a / self.SECONDS_PER_DAY
    end

    function BeamMPEnvSync:syncTimeOfDay()
        local ct = self._state.clientTimeOfDay
        local t = self._state.timeOfDay
        print("[ENVSYNC] Syncing time of day (" .. t .. " seconds = " .. ct .. " client time)")
        TriggerClientEvent(-1, "BeamMPEnvSyncSetTimeOfDay", ct)
    end

    function BeamMPEnvSync:tick()
        local c = self._state.calcThreadCounter
        if c > 60 / self.SYNCS_PER_MINUTE then
            c = 0
            self:recalcServerTimeOfDay()
            self:syncTimeOfDay()
        end
        c = c + 1
        self._state.calcThreadCounter = c
    end
-- end class BeamMPEnvSync

function onInit()
    BeamMPEnvSync:init(onEnvSyncInit)
end

function onEnvSyncInit()
    RegisterEvent("envSyncTick", "envSyncTick")
    RegisterEvent("onPlayerJoin", "onPlayerJoin")
    CreateThread("envSyncTick", 1)
end

function onPlayerJoin()
    BeamMPEnvSync:recalcServerTimeOfDay()
    BeamMPEnvSync:syncTimeOfDay()
end

function envSyncTick()
    BeamMPEnvSync:tick()
end
