--[[
    NUI manifest directives — add these to your fxmanifest.lua
    Three separate files: index.html (structure), style.css (styles), app.js (logic)
]]

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

client_script 'client.lua'
