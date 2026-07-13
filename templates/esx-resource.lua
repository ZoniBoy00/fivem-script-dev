--[[
    ESX resource scaffold
    Replace 'myres' with your actual resource name
]]

-- Core variables
local PlayerData = {}
local isLoggedIn = false
local Config = Config or {}  -- Loaded from shared/config.lua

-- ============================================================================
-- CLIENT MAIN
-- ============================================================================

-- Wait for player to load
CreateThread(function()
    while not ESX.IsPlayerLoaded() do
        Wait(100)
    end
    
    isLoggedIn = true
    PlayerData = ESX.GetPlayerData()
    OnPlayerLoaded()
end)

-- Player loaded callback
function OnPlayerLoaded()
    print('Player loaded:', PlayerData.identifier)
end

-- Player dropped
RegisterNetEvent('esx:playerDropped')
AddEventHandler('esx:playerDropped', function()
    isLoggedIn = false
    PlayerData = {}
end)

-- Job updated
RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
end)

-- ============================================================================
-- ESX CALLBACK EXAMPLE (Client to Server)
-- ============================================================================

function GetPlayerData(callback)
    ESX.TriggerServerCallback('myres:getPlayerData', function(data)
        if data then
            callback(data)
        end
    end)
end

-- ============================================================================
-- INTERACTION ZONE (ox_lib)
-- ============================================================================

-- -- Uncomment if using ox_lib:
-- local shopZone = lib.zones.box({
--     coords = vector3(100.0, 200.0, 30.0),
--     size = vector3(3.0, 3.0, 2.0),
--     rotation = 0,
--     debug = false,
--     onEnter = function()
--         lib.showTextUI('[E] - Open shop', { icon = 'fa-solid fa-store' })
--     end,
--     onExit = function()
--         lib.hideTextUI()
--     end,
--     inside = function()
--         if IsControlJustPressed(0, 38) then
--             TriggerServerEvent('myres:server:openShop')
--         end
--     end,
-- })

-- ============================================================================
-- CLIENT THREAD (Variable wait pattern)
-- ============================================================================

CreateThread(function()
    while true do
        local sleep = 1000
        
        if isLoggedIn then
            -- Player logic here
        end
        
        Wait(sleep)
    end
end)
