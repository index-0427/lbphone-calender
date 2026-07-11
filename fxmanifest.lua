fx_version "cerulean"
game "gta5"
lua54 "yes"

name "lbphone-calender"
description "Calendar app for lb-phone (qbox)"
version "0.1.0"

shared_script "shared/config.lua"
client_script "client/main.lua"

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server/main.lua",
}

files {
    "ui/**/*",
}

ui_page "ui/index.html"

dependency "lb-phone"
dependency "oxmysql"
