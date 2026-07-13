--[[
    QBCore resource scaffold
    Replace 'myres' with your actual resource name
]]

-- Core variables
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local isLoggedIn = false
local Config = Config or {}

-- ============================================================================
-- CLIENT MAIN
-- ============================================================================

-- Wait for player data to load
CreateThread(function()
    while not QBCore.Functions.GetPlayerData() do
        Wait(100)
    end
    
    isLoggedIn = true
    PlayerData = QBCore.Functions.GetPlayerData()
    OnPlayerLoaded()
end)

function OnPlayerLoaded()
    print('Player loaded:', PlayerData.charinfo.firstname, PlayerData.charinfo.lastname)
end

-- Event-driven updates
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    isLoggedIn = true
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(GangInfo)
    PlayerData.gang = GangInfo
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(newDuty)
    PlayerData.job.onduty = newDuty
end)

-- ============================================================================
-- QBCORE CALLBACK EXAMPLE
-- ============================================================================

function GetPlayerData(callback)
    QBCore.Functions.TriggerCallback('myres:server:getPlayerData', function(data)
        if data then
            callback(data)
        end
    end)
end

-- ============================================================================
-- ITEM USAGE
-- ============================================================================

-- Example: item usage handler
-- RegisterNetEvent('myres:useLockpick', function()
--     QBCore.Functions.Notify('You used a lockpick!', 'success')
-- end)

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
