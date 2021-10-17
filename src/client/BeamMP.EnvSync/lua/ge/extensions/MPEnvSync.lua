M = {}

local function setTimeOfDay(timeOfDay)
    core_environment.setTimeOfDay({time=timeOfDay, dayScale=1, nightScale=2, play=true})
    print("[ENVSYNC] Set time of day to " .. timeOfDay)
end

AddEventHandler("BeamMPEnvSyncSetTimeOfDay", setTimeOfDay)

return M
