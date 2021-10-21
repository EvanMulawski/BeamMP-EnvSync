json = require("json")

-- https://stackoverflow.com/a/1283608/483349
local function tableMerge(t1, t2)
    for k,v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                tableMerge(t1[k] or {}, t2[k] or {})
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
    return t1
end

BeamMPEnvSync = {
    _state = {
        tickCounter = 0,
        previousClockTime = nil,
        init = false,
        timeOfDay = nil
    },
    _defaultOptions = {
        timeOfDay = {
            dayLengthRealTimeSeconds = 1800,
            serverWorldStartTime = "10:00",
            daytimeScale = 1,
            nighttimeScale = 2,
            azimuth = 0, -- todo: sanitize
            fixed = false
        },
        syncRate = 2
    },
    options = {},
    MINUTES_PER_DAY = 1440,
    MINUTES_PER_HOUR = 60,
    SECONDS_PER_MINUTE = 60,
    SECONDS_PER_HOUR = 3600,
    SECONDS_PER_DAY = 3600 * 24,
    GAME_NIGHTTIME_START_VALUE = 0.275, -- approx. 18:36
    GAME_DAYTIME_START_VALUE = 0.7425, -- approx. 05:23
    GAME_TIME_MAX_REF = 1.0,
    GAME_TIME_SCALE_MIN = 0.5,
    GAME_TIME_SCALE_MAX = 10,
    SYNC_RATE_MIN = 1,
    SYNC_RATE_MAX = 30,
}
    function BeamMPEnvSync:init(postInit)
        if (self._state.init) then
            self:print("BeamMPEnvSync already initialized")
            return
        end
        self:loadOptions()
        self._state.init = true
        self:recalcServerTimeOfDay()
        self:print("Set initial time of day (" .. self._state.timeOfDay .. ")")
        postInit()
    end

    function BeamMPEnvSync:loadOptions()
        -- read options file
        local open = io.open
        local function read_file(path)
            local file = open(path, "rb")
            if not file then return nil end
            local content = file:read "*a"
            file:close()
            return content
        end
        local optionsFile = read_file("envsync.json")
        if not optionsFile then
            error(self:createPrintMessage("envsync.json does not exist"))
            -- todo: don't error, create file using _defaultOptions
        end
        local options = json.decode(optionsFile)
        tableMerge(self.options, options)
        -- convert start time to game time
        local h_s, m_s = string.match(self.options.timeOfDay.serverWorldStartTime, "(%d%d):(%d%d)")
        self._state.timeOfDay = self:convertSecondsToGameTime((tonumber(h_s) * self.SECONDS_PER_HOUR) + (tonumber(m_s) * self.SECONDS_PER_MINUTE))
        -- normalize/sanitize other options
        self.options.syncRate = math.min(self.SYNC_RATE_MAX, math.max(self.SYNC_RATE_MIN, self.options.syncRate))
        self.options.timeOfDay.daytimeScale = math.min(self.GAME_TIME_SCALE_MAX, math.max(self.GAME_TIME_SCALE_MIN, self.options.timeOfDay.daytimeScale))
        self.options.timeOfDay.nighttimeScale = math.min(self.GAME_TIME_SCALE_MAX, math.max(self.GAME_TIME_SCALE_MIN, self.options.timeOfDay.nighttimeScale))
        -- other calculations
        self.options.timeOfDay.__dayLengthRealTimeSecondsPart = 1.0 / self.options.timeOfDay.dayLengthRealTimeSeconds
        if self.options.timeOfDay.fixed then self.options.timeOfDay.__play = 0 else self.options.timeOfDay.__play = 1 end
        -- print options
        self:print("Running with options: " .. json.encode(self.options))
    end

    function BeamMPEnvSync:recalcServerTimeOfDay()
        if not self._state.previousClockTime then
            self._state.previousClockTime = os.time()
            return
        end
        local elapsedSeconds = os.time() - self._state.previousClockTime
        self._state.previousClockTime = os.time()
        if self.options.timeOfDay.fixed then
            return
        end
        local newTimeOfDay = self._state.timeOfDay
        local inc = self.options.timeOfDay.__dayLengthRealTimeSecondsPart
        for i = 1, elapsedSeconds do
            if newTimeOfDay >= self.GAME_NIGHTTIME_START_VALUE and newTimeOfDay < self.GAME_DAYTIME_START_VALUE then
                --self:print("night")
                newTimeOfDay = newTimeOfDay + (inc * self.options.timeOfDay.nighttimeScale)
            else
                --self:print("day")
                newTimeOfDay = newTimeOfDay + (inc * self.options.timeOfDay.daytimeScale)
            end
            if newTimeOfDay >= 1 then newTimeOfDay = newTimeOfDay - 1 end
        end
        self._state.timeOfDay = newTimeOfDay
        --self:print("Updated time of day to " .. newTimeOfDay)
    end

    function BeamMPEnvSync:convertSecondsToGameTime(seconds)
        -- need to convert range [0,86400) (12am-11:59pm) to [0,1) (12pm-11:59am)
        local a = seconds + (self.SECONDS_PER_DAY / 2)
        if a >= self.SECONDS_PER_DAY then
            a = a - self.SECONDS_PER_DAY
        end
        return a / self.SECONDS_PER_DAY
    end

    function BeamMPEnvSync:syncTimeOfDay()
        local t = self._state.timeOfDay
        -- [1] = time
        -- [2] = dayLength
        -- [3] = dayScale
        -- [4] = nightScale
        -- [5] = play
        -- [6] = azimuthOverride
        local data = t .. "|" .. self.options.timeOfDay.dayLengthRealTimeSeconds .. "|" .. self.options.timeOfDay.daytimeScale .. "|" .. self.options.timeOfDay.nighttimeScale .. "|" .. self.options.timeOfDay.__play .. "|" .. self.options.timeOfDay.azimuth
        self:print("Syncing time of day (" .. t .. ")")
        TriggerClientEvent(-1, "BeamMPEnvSyncSetTimeOfDay", data)
    end

    function BeamMPEnvSync:tick()
        local c = self._state.tickCounter
        if c > 60 / self.options.syncRate then
            c = 0
            self:recalcServerTimeOfDay()
            self:syncTimeOfDay()
        end
        c = c + 1
        self._state.tickCounter = c
    end

    function BeamMPEnvSync:print(s)
        print(self:createPrintMessage(s))
    end

    function BeamMPEnvSync:createPrintMessage(s)
        return "[ENVSYNC] " .. s
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
