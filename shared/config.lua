Config = {}

Config.AdminAce = "admin"

function Config.CanAddEvent(playerData)
    local job = playerData.job
    local gang = playerData.gang
    return (job and job.isboss) or (gang and gang.isboss and gang.name ~= "none") or false
end
