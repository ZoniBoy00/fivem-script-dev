# QBCore Framework Development

## Core Concepts

QBCore uses a `Player` object (capital P) for server-side player management.

### Framework Initialization

**Client:**
```lua
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}

CreateThread(function()
    while not QBCore.Functions.GetPlayerData() do
        Wait(100)
    end
    PlayerData = QBCore.Functions.GetPlayerData()
end)

-- Event-driven updates
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
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
```

**Server:**
```lua
local QBCore = exports['qb-core']:GetCoreObject()

-- In event handler, source = triggering player
local Player = QBCore.Functions.GetPlayer(source)
if not Player then return end  -- Always validate!
```

## Key Principles

1. **Always check for nil** — `if Player then ... end`
2. **Use `QBCore.Functions.GetPlayer(source)`** — standard retrieval
3. **Never trust client** — validate everything server-side
4. **Use ox_lib for UI** — over qb-menu/qb-input
5. **Use event-driven updates** — avoid polling PlayerData
6. **Don't modify qb-core files** — use exports/events

## Get Player

```lua
-- By source
local Player = QBCore.Functions.GetPlayer(source)

-- By citizenid
local Player = QBCore.Functions.GetPlayerByCitizenId(citizenId)

-- By phone number
local Player = QBCore.Functions.GetPlayerByPhone(phoneNumber)

-- By license identifier
local Player = QBCore.Functions.GetPlayerByLicense(license)

-- Offline player by citizenid
local offlineData = QBCore.Functions.GetOfflinePlayer(citizenId)

-- All online players
local players = QBCore.Functions.GetPlayers()

-- Get player from identifier string
local identifier = QBCore.Functions.GetIdentifier(source, 'license')
```

## Player Object Methods

### Money

```lua
Player.Functions.AddMoney('cash', amount, 'reason')
Player.Functions.RemoveMoney('cash', amount, 'reason')
Player.Functions.AddMoney('bank', amount)
Player.Functions.RemoveMoney('bank', amount)
Player.Functions.AddMoney('crypto', amount)

-- Access player money table
local cash = Player.PlayerData.money['cash']
local bank = Player.PlayerData.money['bank']
```

### Items (qb-inventory)

```lua
Player.Functions.AddItem(itemName, amount, slot, info)
-- slot = nil (auto), info = { metadata }
Player.Functions.RemoveItem(itemName, amount, slot)
-- Returns the item table or false

local item = Player.Functions.GetItemByName(itemName)
-- Returns { name, amount, info, label, slot, type, image, ... } or nil

local items = Player.Functions.GetItems()
-- Returns table of all items indexed by slot

-- Check if player can carry item
local canCarry = Player.Functions.CanAddItem(itemName, amount)
```

### Jobs

```lua
local job = Player.PlayerData.job
print(job.name)        -- 'police'
print(job.label)       -- 'Police'
print(job.grade)       -- { name = 'officer', level = 2 }
print(job.grade.name)  -- 'Officer'
print(job.onduty)      -- boolean

-- Set job
Player.Functions.SetJob(jobName, grade)
-- Player.Functions.SetJob('police', 2)

-- Toggle duty
Player.Functions.SetDuty(not Player.PlayerData.job.onduty)
```

### Gangs

```lua
local gang = Player.PlayerData.gang
print(gang.name)    -- 'ballas' or nil
print(gang.label)   -- 'Ballas' or nil
print(gang.grade)   -- { name = 'member', level = 1 }

Player.Functions.SetGang(gangName, grade)
-- Player.Functions.SetGang('ballas', 1)
```

### Metadata

```lua
Player.PlayerData.metadata['hunger'] = 100
Player.PlayerData.metadata['thirst'] = 100
Player.PlayerData.metadata['stress'] = 0
Player.PlayerData.metadata['isdead'] = false
Player.PlayerData.metadata['inlaststand'] = false
Player.PlayerData.metadata['armor'] = 100
Player.PlayerData.metadata['ishandcuffed'] = false
Player.PlayerData.metadata['tracker'] = false
Player.PlayerData.metadata['injail'] = 0
Player.PlayerData.metadata['jailitems'] = {}
Player.PlayerData.metadata['status'] = {}
Player.PlayerData.metadata['phone'] = {}
Player.PlayerData.metadata['fitbit'] = {}
Player.PlayerData.metadata['commandbinds'] = {}
Player.PlayerData.metadata['bloodtype'] = 'A+'
Player.PlayerData.metadata['dealerrep'] = 0
Player.PlayerData.metadata['craftingrep'] = 0
Player.PlayerData.metadata['attachmentcraftingrep'] = 0
Player.PlayerData.metadata['currentapartment'] = nil
Player.PlayerData.metadata['jobrep'] = {}
Player.PlayerData.metadata['criminalrate'] = 0
```

### Char Info

```lua
local charinfo = Player.PlayerData.charinfo
print(charinfo.firstname)
print(charinfo.lastname)
print(charinfo.birthdate)        -- '1990-01-01'
print(charinfo.nationality)      -- 'USA'
print(charinfo.phone)            -- '555-1234'
print(charinfo.gender)           -- 0 = male, 1 = female
print(charinfo.backstory)        -- Optional
```

## QBCore Events

### Client-Side Events

```lua
-- Trigger server event
TriggerServerEvent('QBCore:Server:AddItem', itemName, amount)
TriggerServerEvent('QBCore:Server:RemoveItem', itemName, amount)

-- QBCore callback (client → server with return)
QBCore.Functions.TriggerCallback('myres:server:getData', function(result)
    if result then
        print('Got data:', result)
    end
end, arg1, arg2)

-- Notify player
QBCore.Functions.Notify('Message', 'success')  -- 'success', 'error', 'primary', 'warning', 'info'
```

### Server-Side Events

```lua
-- Register callback
QBCore.Functions.CreateCallback('myres:server:getData', function(source, cb, arg1)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(false) return end
    
    cb({ success = true, data = Player.PlayerData })
end)

-- Progress item usage
QBCore.Functions.CreateUseableItem('lockpick', function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    TriggerClientEvent('myres:useLockpick', source)
end)

-- Get permission / check if admin
local isAdmin = QBCore.Functions.HasPermission(source, 'god')
```

### Server Core Events

```lua
-- Player loaded (server sees it)
RegisterNetEvent('QBCore:Server:PlayerLoaded')
AddEventHandler('QBCore:Server:PlayerLoaded', function(playerData)
    -- Player fully loaded and ready
end)

-- Player unloaded
RegisterNetEvent('QBCore:Server:PlayerUnload')
AddEventHandler('QBCore:Server:PlayerUnload', function(playerId)
    -- Clean up
end)

-- Item use
RegisterNetEvent('QBCore:Server:UseItem')
AddEventHandler('QBCore:Server:UseItem', function(item)
    local Player = QBCore.Functions.GetPlayer(source)
    -- Handle item usage
end)
```

## QBCore Client Functions

```lua
-- Notify
QBCore.Functions.Notify('Message', 'success', 5000)  -- (text, type, duration_ms)

-- Draw text (3D world space)
QBCore.Functions.DrawText3D(x, y, z, 'Text')

-- Get player data
local data = QBCore.Functions.GetPlayerData()

-- Progressbar (qb-progress or custom)
exports['qb-progress']:Progress({
    name = 'task_name',
    duration = 5000,
    label = 'Working...',
    useWhileDead = false,
    canCancel = true,
    controlDisables = { disableMovement = true, disableCarMovement = true },
    animation = { dict = 'mini@repair', clip = 'fixing_a_ped' },
}, function(cancelled)
    if not cancelled then
        print('Task complete!')
    end
end)
```

## QBCore Commands

```lua
-- Create a command
QBCore.Commands.Add('car', 'Spawn a vehicle', {{ name='model', help='Vehicle model' }}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    TriggerClientEvent('myres:spawnVehicle', source, args[1])
end, 'admin')  -- 'admin', 'user', or a permission string

-- Admin check
QBCore.Commands.Add('goto', 'Teleport to player', {{ name='id', help='Player ID' }}, true, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    if not QBCore.Functions.HasPermission(source, 'admin') then return end
    
    TriggerClientEvent('myres:gotoPlayer', source, tonumber(args[1]))
end)
```

## QBCore Shared Data

```lua
-- Access shared data (items, jobs, vehicles, etc.)
print(QBCore.Shared.Items['water'].label)       -- 'Water'
print(QBCore.Shared.Jobs['police'].label)        -- 'Police'
print(QBCore.Shared.Vehicles['adder'].name)      -- 'Adder'
print(QBCore.Shared.Gangs['ballas'].label)       -- 'Ballas'

-- Update shared data from server
QBCore.Functions.AddItem(name, data)             -- Add new item
QBCore.Functions.AddJob(name, data)              -- Add new job
QBCore.Functions.AddVehicle(name, data)          -- Add new vehicle
```

## QBCore Best Practices

1. **Use QBCore.Functions.GetPlayer()** over other retrieval methods
2. **Event-driven updates over polling** — listen for QBCore events
3. **CreateUseableItem pattern** for item usage instead of manual event handling
4. **Minimize global variables** — keep everything in local scope
5. **Cache PlayerData** in local variables when accessed frequently
6. **Use ox_lib for UI** — modern replacement for qb-menu/qb-input
7. **Validate permissions server-side** before executing admin commands

## QBCore Documentation

- Full docs: https://docs.qbcore.org/qbcore-documentation
- AI-friendly (llms.txt): https://docs.qbcore.org/qbcore-documentation/llms.txt
- Core object: https://docs.qbcore.org/qbcore-documentation/qb-core/core-object.md
- Player data: https://docs.qbcore.org/qbcore-documentation/qb-core/player-data.md
- Client events: https://docs.qbcore.org/qbcore-documentation/qb-core/client-event-reference.md
- Server events: https://docs.qbcore.org/qbcore-documentation/qb-core/server-event-reference.md
