--[[
    QBox resource scaffold
    Replace 'myres' with your actual resource name
    
    QBox uses qbx_core with ox_lib, ox_inventory, and ox_target by default.
    This template follows QBox conventions — no QB bridge unless needed.
]]

-- Core variables
local isLoggedIn = false
local Config = Config or {}  -- Loaded from shared/config.lua

-- ============================================================================
-- CLIENT MAIN
-- ============================================================================

-- Add these to the resource's fxmanifest.lua:
-- shared_scripts {
--     '@ox_lib/init.lua',
--     '@qbx_core/modules/lib.lua',
-- }
-- client_scripts {
--     '@qbx_core/modules/playerdata.lua',
--     'client.lua',
-- }
-- dependency 'qbx_core'
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    isLoggedIn = true
    print('Player loaded!')
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    isLoggedIn = false
end)

-- QBox also emits 'QBCore:Client:OnPlayerUnload' earlier in the unload lifecycle.
-- Use that event instead when cleanup must run before Qbox removes the player.

-- ============================================================================
-- CALLBACK EXAMPLE (Client → Server via ox_lib)
-- ============================================================================

-- Async callback
local function fetchPlayerData()
    local data = lib.callback.await('myres:server:getData', false)
    if data then
        print('Got data:', data)
    end
end

-- ============================================================================
-- INTERACTION ZONE (ox_lib zones)
-- ============================================================================

-- Example: shop zone with TextUI
local shopZone = lib.zones.box({
    coords = vector3(100.0, 200.0, 30.0),
    size = vector3(3.0, 3.0, 2.0),
    rotation = 0,
    debug = false,
    onEnter = function()
        lib.showTextUI('[E] - Open Shop', { icon = 'fa-solid fa-store' })
    end,
    onExit = function()
        lib.hideTextUI()
    end,
    inside = function()
        if IsControlJustPressed(0, 38) then  -- E key
            TriggerServerEvent('myres:server:openShop')
        end
    end,
})

-- ============================================================================
-- KEYBIND EXAMPLE (ox_lib)
-- ============================================================================

lib.addKeybind({
    name = 'openMenu',
    description = 'Open Menu',
    defaultKey = 'F5',
    onPressed = function()
        print('Menu opened')
    end,
})

-- ============================================================================
-- NOTIFICATION EXAMPLE (ox_lib)
-- ============================================================================

-- Client-side notification (can also be triggered from server)
-- TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = 'Done!' })

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

-- ============================================================================
-- SERVER-SIDE (place in server/main.lua or similar)
-- ============================================================================

--[[
-- Example server callback:
lib.callback.register('myres:server:getData', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    return {
        job = player.PlayerData.job.name,
        money = player.PlayerData.money,
    }
end)

-- Example event handler:
RegisterNetEvent('myres:server:openShop', function()
    if GetInvokingResource() then return end
    
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    
    -- Open shop logic here
    TriggerClientEvent('ox_lib:notify', source, {
        type = 'success',
        description = 'Shop opened!',
    })
end)
--]]
