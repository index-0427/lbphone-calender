local appIdentifier = "lbphone-calender"

local function addApp()
    local added, errorMessage = exports["lb-phone"]:AddCustomApp({
        identifier  = appIdentifier,
        name        = "イベントカレンダー",
        description = "サーバー共有カレンダー",
        developer   = "SuiMag",
        defaultApp  = true,
        size        = 1024,
        price       = 0,
        ui          = GetCurrentResourceName() .. "/ui/index.html",
        icon        = "https://cfx-nui-" .. GetCurrentResourceName() .. "/ui/icon.svg?v=2",
        fixBlur     = true,
    })
    if not added then
        print("[lbphone-calender] Could not add app: " .. tostring(errorMessage))
    end
end

CreateThread(function()
    while GetResourceState("lb-phone") ~= "started" do
        Wait(500)
    end
    addApp()
end)

AddEventHandler("onResourceStart", function(resource)
    if resource == "lb-phone" then
        addApp()
    end
end)

local function sendToApp(msgType, data)
    exports["lb-phone"]:SendCustomAppMessage(appIdentifier, {
        type = msgType,
        data = data,
    })
end

RegisterNUICallback("getEvents", function(_, cb)
    TriggerServerEvent("calendar:server:requestEvents")
    cb("ok")
end)

RegisterNUICallback("addEvent", function(data, cb)
    TriggerServerEvent("calendar:server:addEvent", data)
    cb("ok")
end)

RegisterNUICallback("updateEvent", function(data, cb)
    TriggerServerEvent("calendar:server:updateEvent", data)
    cb("ok")
end)

RegisterNUICallback("deleteEvent", function(data, cb)
    TriggerServerEvent("calendar:server:deleteEvent", data)
    cb("ok")
end)

RegisterNUICallback("toggleParticipation", function(data, cb)
    TriggerServerEvent("calendar:server:toggleParticipation", data)
    cb("ok")
end)

RegisterNetEvent("calendar:client:events", function(data)
    sendToApp("events", data)
end)

RegisterNetEvent("calendar:client:result", function(data)
    sendToApp("result", data)
end)

RegisterNetEvent("calendar:client:refresh", function()
    TriggerServerEvent("calendar:server:requestEvents")
end)
