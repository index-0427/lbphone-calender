Config = {}

Config.AdminAce = "admin"

-- gang は satou_gang 管理のため QBCore の gang.isboss では判定できない
-- (server/main.lua の canAddEvent で satou_gang export を使って判定する)
function Config.CanAddEvent(playerData)
    local job = playerData.job
    return (job and job.isboss) or false
end
