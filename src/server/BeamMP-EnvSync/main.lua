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

-- https://stackoverflow.com/a/7615129/483349
local function splitString(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
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
        syncRate = 2,
        debug = false,
        admins = {}
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
            self:print("BeamMP-EnvSync already initialized")
            return
        end
        self:loadOptions()
        self._state.init = true
        self:recalcServerTimeOfDay()
        self:printDebug("Set initial time of day (" .. self._state.timeOfDay .. ")")
        postInit()
    end

    function BeamMPEnvSync:loadOptions()
        local options = dofile("envsync.config.lua") or {}
        -- load default options
        tableMerge(self.options, self._defaultOptions)
        -- merge user options
        tableMerge(self.options, options)
        -- convert start time to game time
        self._state.timeOfDay = self:convertClockTimeToGameTime(self.options.timeOfDay.serverWorldStartTime) or self._defaultOptions.timeOfDay.serverWorldStartTime
        -- normalize/sanitize other options
        self.options.syncRate = math.min(self.SYNC_RATE_MAX, math.max(self.SYNC_RATE_MIN, self.options.syncRate or self._defaultOptions.syncRate))
        self.options.timeOfDay.daytimeScale = math.min(self.GAME_TIME_SCALE_MAX, math.max(self.GAME_TIME_SCALE_MIN, self.options.timeOfDay.daytimeScale or self._defaultOptions.timeOfDay.daytimeScale))
        self.options.timeOfDay.nighttimeScale = math.min(self.GAME_TIME_SCALE_MAX, math.max(self.GAME_TIME_SCALE_MIN, self.options.timeOfDay.nighttimeScale or self._defaultOptions.timeOfDay.nighttimeScale))
        self.options.timeOfDay.dayLengthRealTimeSeconds = math.max(0, self.options.timeOfDay.dayLengthRealTimeSeconds or self._defaultOptions.timeOfDay.dayLengthRealTimeSeconds)
        -- other calculations
        self.options.timeOfDay.__dayLengthRealTimeSecondsPart = 1.0 / self.options.timeOfDay.dayLengthRealTimeSeconds
        self:updateDerivedOptions()
        -- load admins
        self:printDebug("Loading admins...")
        self.options._adminBeammpIds = {}
        for k, adminComment in pairs(self.options.admins) do
            local kParts = splitString(k, "_")
            if (kParts[1] == "beammp") then
                local admin = kParts[2]
                table.insert(self.options._adminBeammpIds, admin)
                self:printDebug(" Admin: " .. admin .. " (" .. adminComment .. ")")
            end
        end
        self:printDebug("Loaded " .. #self.options._adminBeammpIds .. " admins")
    end

    function BeamMPEnvSync:updateDerivedOptions()
        if self.options.timeOfDay.fixed then
            self.options.timeOfDay.__play = 0
        else
            self.options.timeOfDay.__play = 1
        end
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
            local isNighttime = newTimeOfDay >= self.GAME_NIGHTTIME_START_VALUE and newTimeOfDay < self.GAME_DAYTIME_START_VALUE
            if isNighttime then
                newTimeOfDay = newTimeOfDay + (inc * self.options.timeOfDay.nighttimeScale)
            else
                newTimeOfDay = newTimeOfDay + (inc * self.options.timeOfDay.daytimeScale)
            end
            if newTimeOfDay >= 1 then newTimeOfDay = newTimeOfDay - 1 end
        end
        self._state.timeOfDay = newTimeOfDay
    end

    function BeamMPEnvSync:setTimeOfDay(value, fixed)
        self.options.timeOfDay.fixed = fixed or self.options.timeOfDay.fixed
        self:updateDerivedOptions()
        self._state.timeOfDay = value
        self._state.previousClockTime = os.time()
        self:syncTimeOfDay()
    end

    function BeamMPEnvSync:convertClockTimeToGameTime(value)
        local h_s, m_s = string.match(value, "^(%d%d):(%d%d)$")
        if not h_s or not m_s then return nil end
        return self:convertSecondsToGameTime(((tonumber(h_s) * self.SECONDS_PER_HOUR) + (tonumber(m_s) * self.SECONDS_PER_MINUTE)) % self.SECONDS_PER_DAY)
    end

    function BeamMPEnvSync:convertSecondsToGameTime(seconds)
        -- sanitize
        local s = math.min(self.SECONDS_PER_DAY, math.max(0, seconds or 0))
        -- need to convert range [0,86400) (12am-11:59pm) to [0,1) (12pm-11:59am)
        local a = s + (self.SECONDS_PER_DAY / 2)
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
        self:printDebug("Syncing time of day (" .. t .. ")")
        MP.TriggerClientEvent(-1, "BeamMPEnvSyncSetTimeOfDay", data)
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

    function BeamMPEnvSync:printDebug(s)
        if self.options.debug then
            self:print(s)
        end
    end

    function BeamMPEnvSync:createPrintMessage(s)
        return "[ENVSYNC] " .. s
    end

    function BeamMPEnvSync:tryHandleRawCommand(senderId, rawCommand)
        if not self:isAdmin(senderId) then
            return {
                status = "access_denied"
            }
        end
        local commandParseResult = self:tryParseRawCommand(rawCommand)
        if not commandParseResult.valid then
            return {
                status = "no_command"
            }
        end
        return self:handleCommand(commandParseResult.command)
    end

    function BeamMPEnvSync:handleCommand(command)
        if command.name == "env" then
            -- (set) (time) (<value>)
            local sub = command.args[1]
            if sub == "set" and command.args[2] == "time" then
                local value = self:convertClockTimeToGameTime(command.args[3])
                local modifier = command.args[4]
                local fixed = nil
                if value then
                    if modifier then
                        if modifier == "--fixed" then
                            fixed = true
                        elseif modifier == "--play" then
                            fixed = false
                        end
                    end
                    self:setTimeOfDay(value, fixed)
                    return { status = "ok" }
                end
                return { status = "invalid_command" }
            end
        end
        return { status = "invalid_command" }
    end

    function BeamMPEnvSync:tryParseRawCommand(rawCommand)
        local commandParts = splitString(rawCommand, " ")
        local commandName = string.match(commandParts[1], "^%s*/(%w+)$")
        if not commandName then
            return {
                valid = false
            }
        end
        table.remove(commandParts, 1)
        return {
            valid = true,
            command = {
                name = commandName,
                args = commandParts
            }
        }
    end

    function BeamMPEnvSync:isAdmin(playerId)
        local playerBeammpId = MP.GetPlayerIdentifiers(playerId).beammp
        for _, admin in ipairs(self.options._adminBeammpIds) do
            if admin == playerBeammpId then
                return true
            end
        end
        return false
    end
-- end class BeamMPEnvSync

function onInit()
    BeamMPEnvSync:init(onEnvSyncInit)
end

function onEnvSyncInit()
    MP.RegisterEvent("envSyncTick", "envSyncTick")
    MP.RegisterEvent("onPlayerJoin", "onPlayerJoin")
    MP.RegisterEvent("onChatMessage", "onChatMessage")
    MP.CreateEventTimer("envSyncTick", 1000)
end

function onPlayerJoin()
    BeamMPEnvSync:recalcServerTimeOfDay()
    BeamMPEnvSync:syncTimeOfDay()
end

function envSyncTick()
    BeamMPEnvSync:tick()
end

function onChatMessage(senderId, senderName, message)
    local result = BeamMPEnvSync:tryHandleRawCommand(senderId, message)
    if result.status == "no_command" then return end
    if result.status == "access_denied" then
        MP.SendChatMessage(senderId, "You do not have permission to do this.")
    elseif result.status == "invalid_command" then
        MP.SendChatMessage(senderId, "The command is invalid.")
    elseif result.status == "ok" then
        MP.SendChatMessage(senderId, "Command completed successfully.")
    else
        MP.SendChatMessage(senderId, "Command completed with an unknown status.")
    end
end
