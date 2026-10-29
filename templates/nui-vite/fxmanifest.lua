--[[
    NUI with Vite + TypeScript
    Build the UI before starting the resource:  cd web && npm install && npm run build
    Ship web/build/ with the resource (players never run npm); node_modules stays out.
]]

fx_version 'cerulean'
game 'gta5'

name 'myres'
version '1.0.0'

shared_script '@ox_lib/init.lua'
client_script 'client.lua'
server_script 'server.lua'

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/**/*',
}

dependency 'ox_lib'
