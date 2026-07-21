Config = {}

Config.AdminAce = "admin"

-- リマインダーは期限到来分だけを一定間隔で確認する。
Config.ReminderCheckInterval = 60 * 1000

-- "online" は現在オンライン中の全員、"all" はオフライン中の住民分も保存する。
Config.ReminderAudience = "all"
Config.ReminderNotificationTitle = "イベントリマインダー"

-- gang は satou_gang 管理のため QBCore の gang.isboss では判定できない
-- (server/main.lua の canAddEvent で satou_gang export を使って判定する)
function Config.CanAddEvent(playerData)
    local job = playerData.job
    return (job and job.isboss) or false
end
