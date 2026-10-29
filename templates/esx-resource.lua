--[[
    ESX resource scaffold (client + server sections)
    Replace 'myres' with your actual resource name.

    fxmanifest.lua:
        shared_scripts { '@es_extended/imports.lua', 'shared/config.lua' }
        client_scripts { 'client/main.lua' }
        server_scripts { 'server/main.lua' }
        dependency 'es_extended'

    @es_extended/imports.lua defines the global `ESX` (and keeps ESX.PlayerData updated on the client).
]]

-- ============================================================================
-- CLIENT (client/main.lua)
-- ============================================================================

local isLoggedIn = false

local function onPlayerLoaded()
    isLoggedIn = true
    -- ESX.PlayerData.job, .accounts, .inventory are available here
end

RegisterNetEvent('esx:playerLoaded', function()
    onPlayerLoaded()
end)

-- Resource restarted while the player is already loaded
CreateThread(function()
    if ESX.IsPlayerLoaded() then onPlayerLoaded() end
end)

-- Logout / character switch (server → client only)
ESX.SecureNetEvent('esx:onPlayerLogout', function()
    isLoggedIn = false
end)

RegisterNetEvent('esx:setJob', function(job)
    -- ESX.PlayerData.job is already updated by imports.lua; react to the change here
    print('New job:', job.name)
end)

-- Callback example (client → server)
local function requestData()
    ESX.TriggerServerCallback('myres:server:getData', function(data)
        if data then print('Cash:', data.cash) end
    end)
end

-- Interaction with ESX's own text UI (esx_textui)
local SHOP_COORDS = vector3(100.0, 200.0, 30.0)

CreateThread(function()
    local shown = false
    while true do
        local sleep = 1000
        if isLoggedIn then
            local dist = #(GetEntityCoords(PlayerPedId()) - SHOP_COORDS)
            if dist < 2.0 then
                sleep = 0
                if not shown then ESX.TextUI('[E] Open shop', 'info'); shown = true end
                if IsControlJustPressed(0, 38) then
                    TriggerServerEvent('myres:server:openShop')
                    requestData()
                end
            elseif shown then
                ESX.HideUI(); shown = false
            elseif dist < 30.0 then
                sleep = 250
            end
        end
        Wait(sleep)
    end
end)

-- ============================================================================
-- SERVER (server/main.lua)
-- ============================================================================

--[[
local SHOP_COORDS = vector3(100.0, 200.0, 30.0)

ESX.RegisterServerCallback('myres:server:getData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end
    cb({ cash = xPlayer.getMoney(), job = xPlayer.getJob().name })
end)

RegisterNetEvent('myres:server:openShop', function()
    local src = source                         -- capture before any yield
    if GetInvokingResource() then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - SHOP_COORDS) > 5.0 then return end

    xPlayer.showNotification('Shop opened!', 'success')
end)
]]
