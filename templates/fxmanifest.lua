--[[
    fxmanifest.lua — Template for FiveM resources
    Copy this file to the root of your resource and adjust as needed
]]

-- Resource metadata
fx_version 'cerulean'                   -- Always use latest version
game 'gta5'                             -- 'gta5', 'rdr3', or 'common'
-- lua54 'yes'                          -- REMOVED: Lua 5.4 is default since June 2025

author 'Your Name'
description 'Description of your resource'
version '1.0.0'

-- Shared scripts (run on both client and server)
-- Load here: config, shared functions, libraries (ox_lib, etc.)
shared_scripts {
    'shared/config.lua',
    -- '@ox_lib/init.lua',             -- Enable if using ox_lib
}

-- Client scripts (run on each player's game)
client_scripts {
    'client/main.lua',
    'client/**/*.lua',                  -- Globbing: all .lua in client/ subdirectories
}

-- Server scripts (run once on the server)
server_scripts {
    'server/main.lua',
    'server/database.lua',
    -- '@oxmysql/lib/MySQL.lua',        -- Enable if using oxmysql (NOTE: before own scripts!)
}

-- NUI (only if your resource has an HTML UI)
-- ui_page 'html/index.html'
-- files {
--     'html/**/*',
-- }

-- Dependencies (resources that must load before this one)
-- dependencies {
--     'ox_lib',
--     'oxmysql',
-- }

-- Exports (functions other resources can call)
-- exports {
--     'getData',
--     'setData',
-- }
-- server_export 'getServerData'

-- Data files (only if adding custom game data)
-- data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
-- data_file 'HANDLING_FILE' 'data/handling.meta'

-- Map resource
-- this_is_a_map 'yes'

-- Server-only (prevents resource from being downloaded to clients)
-- server_only 'yes'
