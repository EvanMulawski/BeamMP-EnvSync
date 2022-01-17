options = {}
options.admins = {}
options.timeOfDay = {}

--[[
    TIME OF DAY OPTIONS
--]]

-- The length of an in-game day in real-world seconds. Note: The in-game time scales affect the actual real-world length of the day.
options.timeOfDay.dayLengthRealTimeSeconds = 600

-- The game clock time the server should start with (equivalent to the in-game time slider time, "12:00" is noon and "00:00" is midnight).
options.timeOfDay.serverWorldStartTime = "10:00"

-- The factor at which the day progresses during the daytime.
options.timeOfDay.daytimeScale = 1

-- The factor at which the day progresses during the nighttime.
options.timeOfDay.nighttimeScale = 2

-- The horizontal location of the sun in the sky (in degrees). This currently has no effect.
options.timeOfDay.azimuth = 0

-- If false, this will "play" the time settings ("run the clock"). If true, the server will always sync the time it started with (the time will not change).
options.timeOfDay.fixed = false

--[[
    GENERAL OPTIONS
--]]

-- Approximate number of times per minute the server should send the current environment data to all clients. For example, a syncRate of 2 would sync the time of day with clients approximately every 30 seconds (2 syncs per minute).
options.syncRate = 30

-- Determines if debug logging is enabled.
options.debug = true

--[[
    PERMISSIONS
--]]

-- A table of user ID's that will be able to use chat commands to control this plugin. Only the key is used; the value can be anything (e.g. the player name).
--options.admins.beammp_123456 = "server owner"

return options
