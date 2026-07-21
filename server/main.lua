local appIdentifier = "lbphone-calender"
local schemaStatus = "pending"
local schemaError = nil

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function isAdmin(src)
    return IsPlayerAceAllowed(src, Config.AdminAce)
end

local function canAddEvent(player)
    if Config.CanAddEvent(player.PlayerData) then return true end
    -- satou_gang のボス = rank 0 (Leader)
    local gangInfo = exports['satou_gang']:GetPlayerGangInfo(player.PlayerData.citizenid)
    return gangInfo ~= nil and gangInfo.rank == 0
end

local function sendResult(src, ok, message)
    TriggerClientEvent("calendar:client:result", src, { ok = ok, message = message })
end

local function schemaRows(query, params)
    return MySQL.query.await(query, params or {}) or {}
end

local function schemaItemExists(query, params)
    return schemaRows(query, params)[1] ~= nil
end

local function applySchemaChange(label, statement)
    MySQL.query.await(statement)
    print(("[lbphone-calender] Applied non-destructive schema change: %s"):format(label))
end

local function ensureColumn(tableName, columnName, definition)
    local exists = schemaItemExists([[
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND COLUMN_NAME = ?
        LIMIT 1
    ]], { tableName, columnName })

    if not exists then
        applySchemaChange(("%s.%s"):format(tableName, columnName),
            ("ALTER TABLE `%s` ADD COLUMN `%s` %s"):format(tableName, columnName, definition))
    end
end

local function ensureIndex(tableName, indexName, definition)
    local exists = schemaItemExists([[
        SELECT 1
        FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND INDEX_NAME = ?
        LIMIT 1
    ]], { tableName, indexName })

    if not exists then
        applySchemaChange(("%s.%s"):format(tableName, indexName),
            ("ALTER TABLE `%s` ADD INDEX `%s` %s"):format(tableName, indexName, definition))
    end
end

local function ensureSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_calendar_events` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `citizenid` VARCHAR(50) NOT NULL,
            `author` VARCHAR(100) NOT NULL,
            `hide_author` TINYINT(1) NOT NULL DEFAULT 0,
            `title` VARCHAR(100) NOT NULL,
            `event_date` CHAR(10) NOT NULL,
            `start_time` CHAR(5) DEFAULT NULL,
            `end_time` CHAR(5) DEFAULT NULL,
            `location` VARCHAR(100) NOT NULL DEFAULT '',
            `description` TEXT,
            `image_url` TEXT DEFAULT NULL,
            `reminder_enabled` TINYINT(1) NOT NULL DEFAULT 0,
            `reminder_at` DATETIME DEFAULT NULL,
            `reminder_sent_at` DATETIME DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_event_date` (`event_date`),
            INDEX `idx_reminder_due` (`reminder_enabled`, `reminder_sent_at`, `reminder_at`)
        )
    ]])

    -- 既存データを変更せず、不足している構造だけを追加する。
    ensureColumn("phone_calendar_events", "hide_author",
        "TINYINT(1) NOT NULL DEFAULT 0 AFTER `author`")
    ensureColumn("phone_calendar_events", "image_url",
        "TEXT DEFAULT NULL AFTER `description`")
    ensureColumn("phone_calendar_events", "reminder_enabled",
        "TINYINT(1) NOT NULL DEFAULT 0 AFTER `image_url`")
    ensureColumn("phone_calendar_events", "reminder_at",
        "DATETIME DEFAULT NULL AFTER `reminder_enabled`")
    ensureColumn("phone_calendar_events", "reminder_sent_at",
        "DATETIME DEFAULT NULL AFTER `reminder_at`")
    ensureIndex("phone_calendar_events", "idx_event_date", "(`event_date`)")
    ensureIndex("phone_calendar_events", "idx_reminder_due",
        "(`reminder_enabled`, `reminder_sent_at`, `reminder_at`)")

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `phone_calendar_event_participants` (
            `event_id` INT NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `participant_name` VARCHAR(100) NOT NULL,
            `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`event_id`, `citizenid`),
            INDEX `idx_participant_citizenid` (`citizenid`),
            CONSTRAINT `fk_calendar_participant_event`
                FOREIGN KEY (`event_id`) REFERENCES `phone_calendar_events` (`id`)
                ON DELETE CASCADE
        )
    ]])

    ensureColumn("phone_calendar_event_participants", "participant_name",
        "VARCHAR(100) NOT NULL DEFAULT '' AFTER `citizenid`")
    ensureColumn("phone_calendar_event_participants", "joined_at",
        "TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER `participant_name`")
    ensureIndex("phone_calendar_event_participants", "idx_participant_citizenid", "(`citizenid`)")

    local hasEventForeignKey = schemaItemExists([[
        SELECT 1
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'phone_calendar_event_participants'
          AND COLUMN_NAME = 'event_id'
          AND REFERENCED_TABLE_NAME = 'phone_calendar_events'
          AND REFERENCED_COLUMN_NAME = 'id'
        LIMIT 1
    ]])
    if not hasEventForeignKey then
        applySchemaChange("phone_calendar_event_participants event foreign key", [[
            ALTER TABLE `phone_calendar_event_participants`
            ADD CONSTRAINT `fk_calendar_participant_event`
            FOREIGN KEY (`event_id`) REFERENCES `phone_calendar_events` (`id`)
            ON DELETE CASCADE
        ]])
    end
end

local function waitForSchema(src)
    local waited = 0
    while schemaStatus == "pending" and waited < 200 do
        Wait(50)
        waited = waited + 1
    end

    if schemaStatus == "ready" then return true end
    if src then
        sendResult(src, false, "データベースの準備が完了していません。管理者に確認してください")
    end
    return false
end

CreateThread(function()
    local ok, errorMessage = pcall(ensureSchema)
    if ok then
        schemaStatus = "ready"
        print("[lbphone-calender] Database schema is ready (existing data preserved)")
    else
        schemaStatus = "failed"
        schemaError = tostring(errorMessage)
        print("[lbphone-calender] Database schema migration failed: " .. schemaError)
    end
end)

local function sendEvents(src)
    local player = getPlayer(src)
    if not player then return end
    if not waitForSchema(src) then return end
    local admin = isAdmin(src)
    MySQL.query(
        [[
            SELECT
                e.id,
                e.citizenid,
                CASE
                    WHEN e.hide_author = 1 AND ? = 0 THEN NULL
                    ELSE e.author
                END AS author,
                e.hide_author,
                e.title,
                e.event_date,
                e.start_time,
                e.end_time,
                e.location,
                e.description,
                e.image_url,
                e.reminder_enabled,
                DATE_FORMAT(e.reminder_at, '%Y-%m-%d %H:%i') AS reminder_at,
                TIMESTAMPDIFF(
                    MINUTE,
                    e.reminder_at,
                    STR_TO_DATE(
                        CONCAT(e.event_date, ' ', COALESCE(NULLIF(e.start_time, ''), '00:00')),
                        '%Y-%m-%d %H:%i'
                    )
                ) AS reminder_minutes,
                (
                    SELECT COUNT(*)
                    FROM phone_calendar_event_participants p
                    WHERE p.event_id = e.id
                ) AS participant_count,
                EXISTS(
                    SELECT 1
                    FROM phone_calendar_event_participants p
                    WHERE p.event_id = e.id AND p.citizenid = ?
                ) AS has_joined
            FROM phone_calendar_events e
            ORDER BY e.event_date, e.start_time
        ]],
        { admin and 1 or 0, player.PlayerData.citizenid },
        function(rows)
            TriggerClientEvent("calendar:client:events", src, {
                events = rows or {},
                citizenid = player.PlayerData.citizenid,
                canAdd = admin or canAddEvent(player),
                isAdmin = admin,
            })
        end
    )
end

local function isTruthy(value)
    return value == true or value == 1 or value == "1"
end

local allowedReminderMinutes = {
    [10] = true,
    [30] = true,
    [60] = true,
    [1440] = true,
    [4320] = true,
}

local function datePartsOrNil(value)
    local year, month, day = tostring(value or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or not month or not day or year < 1970 or month < 1 or month > 12 then return nil end
    local monthDays = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0) then
        monthDays[2] = 29
    end
    if day < 1 or day > monthDays[month] then return nil end

    return year, month, day
end

local function timeOrNil(value)
    local hour, minute = tostring(value or ""):match("^(%d%d):(%d%d)$")
    hour, minute = tonumber(hour), tonumber(minute)
    if not hour or not minute or hour > 23 or minute > 59 then return nil end
    return ("%02d:%02d"):format(hour, minute), hour, minute
end

local function reminderDateTimeFromOffset(date, startTime, reminderMinutes)
    if not allowedReminderMinutes[reminderMinutes] then return nil end
    local year, month, day = datePartsOrNil(date)
    if not year then return nil end

    local hour, minute = 0, 0
    if startTime then
        local normalizedTime, parsedHour, parsedMinute = timeOrNil(startTime)
        if not normalizedTime then return nil end
        hour, minute = parsedHour, parsedMinute
    end

    local eventTimestamp = os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = minute,
        sec = 0,
    })
    if not eventTimestamp then return nil end

    return os.date("%Y-%m-%d %H:%M:%S", eventTimestamp - (reminderMinutes * 60))
end

local function imageUrlOrNil(value)
    local imageUrl = tostring(value or "")
    if imageUrl == "" then return nil end
    if #imageUrl > 2048 or imageUrl:find("[%s%c]") then return nil end
    if not imageUrl:lower():match("^https?://") then return nil end
    return imageUrl
end

local function sanitize(data)
    if type(data) ~= "table" then return nil end
    local title = tostring(data.title or ""):sub(1, 100)
    local date = tostring(data.date or "")
    if title == "" or not datePartsOrNil(date) then return nil end

    local startTime = timeOrNil(data.startTime)
    local endTime = timeOrNil(data.endTime)
    if data.startTime and tostring(data.startTime) ~= "" and not startTime then return nil end
    if data.endTime and tostring(data.endTime) ~= "" and not endTime then return nil end

    local reminderEnabled = isTruthy(data.reminderEnabled)
    local reminderMinutes = tonumber(data.reminderMinutes)
    local reminderAt = reminderEnabled
        and reminderDateTimeFromOffset(date, startTime, reminderMinutes)
        or nil
    if reminderEnabled and not reminderAt then return nil end

    local rawImageUrl = tostring(data.imageUrl or "")
    local imageUrl = imageUrlOrNil(rawImageUrl)
    if rawImageUrl ~= "" and not imageUrl then return nil end

    return {
        title = title,
        date = date,
        startTime = startTime,
        endTime = endTime,
        location = tostring(data.location or ""):sub(1, 100),
        description = tostring(data.description or ""):sub(1, 1000),
        imageUrl = imageUrl,
        reminderEnabled = reminderEnabled,
        reminderAt = reminderAt,
    }
end

RegisterNetEvent("calendar:server:requestEvents", function()
    sendEvents(source)
end)

local function getParticipantName(player)
    local charinfo = player.PlayerData.charinfo or {}
    local name = ("%s %s"):format(charinfo.firstname or "", charinfo.lastname or "")
    name = name:match("^%s*(.-)%s*$")
    return name ~= "" and name:sub(1, 100) or player.PlayerData.citizenid
end

RegisterNetEvent("calendar:server:toggleParticipation", function(data)
    local src = source
    local player = getPlayer(src)
    if not player then return end
    if not waitForSchema(src) then return end

    local eventId = tonumber(type(data) == "table" and data.id)
    if not eventId or eventId < 1 or eventId % 1 ~= 0 then
        sendResult(src, false, "イベント情報が正しくありません")
        return
    end

    MySQL.single(
        "SELECT id FROM phone_calendar_events WHERE id = ?",
        { eventId },
        function(event)
            if not event then
                sendResult(src, false, "イベントが見つかりません")
                return
            end

            local citizenid = player.PlayerData.citizenid
            MySQL.single(
                "SELECT event_id FROM phone_calendar_event_participants WHERE event_id = ? AND citizenid = ?",
                { eventId, citizenid },
                function(participation)
                    if participation then
                        MySQL.update(
                            "DELETE FROM phone_calendar_event_participants WHERE event_id = ? AND citizenid = ?",
                            { eventId, citizenid },
                            function()
                                sendResult(src, true, "参加予約を取り消しました")
                                TriggerClientEvent("calendar:client:refresh", -1)
                            end
                        )
                        return
                    end

                    MySQL.insert(
                        "INSERT IGNORE INTO phone_calendar_event_participants (event_id, citizenid, participant_name) VALUES (?, ?, ?)",
                        { eventId, citizenid, getParticipantName(player) },
                        function(insertId)
                            if insertId then
                                sendResult(src, true, "参加予約が完了しました")
                                TriggerClientEvent("calendar:client:refresh", -1)
                            else
                                sendResult(src, false, "参加予約に失敗しました")
                            end
                        end
                    )
                end
            )
        end
    )
end)

RegisterNetEvent("calendar:server:addEvent", function(data)
    local src = source
    local player = getPlayer(src)
    if not player then return end
    if not waitForSchema(src) then return end
    local admin = isAdmin(src)
    if not (admin or canAddEvent(player)) then
        sendResult(src, false, "予定を追加する権限がありません")
        return
    end
    local ev = sanitize(data)
    if not ev then
        sendResult(src, false, "入力内容が正しくありません")
        return
    end
    local charinfo = player.PlayerData.charinfo
    local author = ("%s %s"):format(charinfo.firstname, charinfo.lastname)
    local hideAuthor = admin and isTruthy(data.hideAuthor) or false
    MySQL.insert(
        "INSERT INTO phone_calendar_events (citizenid, author, hide_author, title, event_date, start_time, end_time, location, description, image_url, reminder_enabled, reminder_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        { player.PlayerData.citizenid, author, hideAuthor and 1 or 0, ev.title, ev.date, ev.startTime, ev.endTime, ev.location, ev.description, ev.imageUrl, ev.reminderEnabled and 1 or 0, ev.reminderAt },
        function(id)
            if id and id > 0 then
                sendResult(src, true, "予定を追加しました")
                TriggerClientEvent("calendar:client:refresh", -1)
            else
                sendResult(src, false, "追加に失敗しました")
            end
        end
    )
end)

local function withOwnedEvent(src, data, cb)
    local player = getPlayer(src)
    if not player then return end
    if not waitForSchema(src) then return end
    local id = tonumber(type(data) == "table" and data.id)
    if not id then
        sendResult(src, false, "入力内容が正しくありません")
        return
    end
    MySQL.single("SELECT id, citizenid, hide_author, reminder_enabled, DATE_FORMAT(reminder_at, '%Y-%m-%d %H:%i:%s') AS reminder_at FROM phone_calendar_events WHERE id = ?", { id }, function(row)
        if not row then
            sendResult(src, false, "予定が見つかりません")
            return
        end
        if row.citizenid ~= player.PlayerData.citizenid and not isAdmin(src) then
            sendResult(src, false, "この予定を操作する権限がありません")
            return
        end
        cb(id, row)
    end)
end

RegisterNetEvent("calendar:server:updateEvent", function(data)
    local src = source
    withOwnedEvent(src, data, function(id, row)
        local ev = sanitize(data)
        if not ev then
            sendResult(src, false, "入力内容が正しくありません")
            return
        end

        local previousEnabled = row.reminder_enabled == true or row.reminder_enabled == 1 or row.reminder_enabled == "1"
        local reminderChanged = previousEnabled ~= ev.reminderEnabled
            or tostring(row.reminder_at or "") ~= tostring(ev.reminderAt or "")
        local resetSent = reminderChanged and ", reminder_sent_at = NULL" or ""
        local hideAuthor = row.hide_author == true or row.hide_author == 1 or row.hide_author == "1"
        if isAdmin(src) then
            hideAuthor = isTruthy(data.hideAuthor)
        end
        MySQL.update(
            "UPDATE phone_calendar_events SET title = ?, event_date = ?, start_time = ?, end_time = ?, location = ?, description = ?, image_url = ?, hide_author = ?, reminder_enabled = ?, reminder_at = ?" .. resetSent .. " WHERE id = ?",
            { ev.title, ev.date, ev.startTime, ev.endTime, ev.location, ev.description, ev.imageUrl, hideAuthor and 1 or 0, ev.reminderEnabled and 1 or 0, ev.reminderAt, id },
            function()
                sendResult(src, true, "予定を更新しました")
                TriggerClientEvent("calendar:client:refresh", -1)
            end
        )
    end)
end)

RegisterNetEvent("calendar:server:deleteEvent", function(data)
    local src = source
    withOwnedEvent(src, data, function(id)
        MySQL.update("DELETE FROM phone_calendar_events WHERE id = ?", { id }, function()
            sendResult(src, true, "予定を削除しました")
            TriggerClientEvent("calendar:client:refresh", -1)
        end)
    end)
end)

local function reminderContent(event)
    local time = event.start_time and event.start_time:sub(1, 5) or "終日"
    local content = ("%s\n%s %s"):format(event.title, event.event_date, time)
    if event.location and event.location ~= "" then
        content = content .. (" / %s"):format(event.location)
    end
    return content
end

local function checkDueReminders()
    if schemaStatus ~= "ready" then return end
    local rows = MySQL.query.await([[
        SELECT id, title, event_date, start_time, location
        FROM phone_calendar_events
        WHERE reminder_enabled = 1
          AND reminder_sent_at IS NULL
          AND reminder_at <= NOW()
        ORDER BY reminder_at
    ]]) or {}

    local audience = Config.ReminderAudience == "all" and "all" or "online"
    for _, event in ipairs(rows) do
        local notified, errorMessage = pcall(function()
            exports["lb-phone"]:NotifyEveryone(audience, {
                app = appIdentifier,
                title = Config.ReminderNotificationTitle or "イベントリマインダー",
                content = reminderContent(event),
            })
        end)

        if notified then
            MySQL.update.await(
                "UPDATE phone_calendar_events SET reminder_sent_at = NOW() WHERE id = ? AND reminder_sent_at IS NULL",
                { event.id }
            )
        else
            print(("[lbphone-calender] Reminder notification failed for event %s: %s")
                :format(tostring(event.id), tostring(errorMessage)))
        end
    end
end

CreateThread(function()
    Wait(5000)
    local interval = math.max(tonumber(Config.ReminderCheckInterval) or 60000, 1000)
    while true do
        local ok, errorMessage = pcall(checkDueReminders)
        if not ok then
            print("[lbphone-calender] Reminder check failed: " .. tostring(errorMessage))
        end
        Wait(interval)
    end
end)
