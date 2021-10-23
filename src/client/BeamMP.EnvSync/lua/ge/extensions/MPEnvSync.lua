print("[ENVSYNC] Loading")

local M = {}

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

local function setTimeOfDay(timeOfDayData)
    local p = splitString(timeOfDayData, "|")
    -- [1] = time
    -- [2] = dayLength
    -- [3] = dayScale
    -- [4] = nightScale
    -- [5] = play
    local play = false
    if p[5] == 1 then play = true end
    -- [6] = azimuthOverride
    print("[ENVSYNC] Sync: " .. timeOfDayData)
    core_environment.setTimeOfDay({time=p[1], dayLength=p[2], dayScale=p[3], nightScale=p[4], play=play, azimuthOverride=p[6]})
end

AddEventHandler("BeamMPEnvSyncSetTimeOfDay", setTimeOfDay)

print("[ENVSYNC] Ready")
return M
