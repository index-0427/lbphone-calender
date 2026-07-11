local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function isAdmin(src)
    return IsPlayerAceAllowed(src, Config.AdminAce)
end

local function sendResult(src, ok, message)
    TriggerClientEvent("calendar:client:result", src, { ok = ok, message = message })
end

local function sendEvents(src)
    local player = getPlayer(src)
    if not player then return end
    local admin = isAdmin(src)
    MySQL.query(
        "SELECT id, citizenid, author, title, event_date, start_time, end_time, location, description FROM phone_calendar_events ORDER BY event_date, start_time",
        {},
        function(rows)
            TriggerClientEvent("calendar:client:events", src, {
                events = rows or {},
                citizenid = player.PlayerData.citizenid,
                canAdd = admin or Config.CanAddEvent(player.PlayerData),
                isAdmin = admin,
            })
        end
    )
end

local function sanitize(data)
    if type(data) ~= "table" then return nil end
    local title = tostring(data.title or ""):sub(1, 100)
    local date = tostring(data.date or "")
    if title == "" or not date:match("^%d%d%d%d%-%d%d%-%d%d$") then return nil end
    local function timeOrNil(v)
        v = tostring(v or "")
        return v:match("^%d%d:%d%d$") and v or nil
    end
    return {
        title = title,
        date = date,
        startTime = timeOrNil(data.startTime),
        endTime = timeOrNil(data.endTime),
        location = tostring(data.location or ""):sub(1, 100),
        description = tostring(data.description or ""):sub(1, 1000),
    }
end

RegisterNetEvent("calendar:server:requestEvents", function()
    sendEvents(source)
end)

RegisterNetEvent("calendar:server:addEvent", function(data)
    local src = source
    local player = getPlayer(src)
    if not player then return end
    if not (isAdmin(src) or Config.CanAddEvent(player.PlayerData)) then
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
    MySQL.insert(
        "INSERT INTO phone_calendar_events (citizenid, author, title, event_date, start_time, end_time, location, description) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        { player.PlayerData.citizenid, author, ev.title, ev.date, ev.startTime, ev.endTime, ev.location, ev.description },
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
    local id = tonumber(type(data) == "table" and data.id)
    if not id then return end
    MySQL.single("SELECT id, citizenid FROM phone_calendar_events WHERE id = ?", { id }, function(row)
        if not row then
            sendResult(src, false, "予定が見つかりません")
            return
        end
        if row.citizenid ~= player.PlayerData.citizenid and not isAdmin(src) then
            sendResult(src, false, "この予定を操作する権限がありません")
            return
        end
        cb(id)
    end)
end

RegisterNetEvent("calendar:server:updateEvent", function(data)
    local src = source
    withOwnedEvent(src, data, function(id)
        local ev = sanitize(data)
        if not ev then
            sendResult(src, false, "入力内容が正しくありません")
            return
        end
        MySQL.update(
            "UPDATE phone_calendar_events SET title = ?, event_date = ?, start_time = ?, end_time = ?, location = ?, description = ? WHERE id = ?",
            { ev.title, ev.date, ev.startTime, ev.endTime, ev.location, ev.description, id },
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
