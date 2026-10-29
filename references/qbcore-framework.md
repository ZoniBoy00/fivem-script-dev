# QBCore Framework Development

## Core Concepts

QBCore uses a `Player` object (capital P) for server-side player management.

> Verified against current `qbcore-framework/qb-core` and `qb-inventory`. **Item functions moved out of the Player object**: use `exports['qb-inventory']:*` (older guides showing `Player.Functions.AddItem` target older qb-core versions).

### Framework Initialization

**Client:**
```lua
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(100)
    end
    PlayerData = QBCore.Functions.GetPlayerData()
end)

-- Event-driven updates
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
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

RegisterNetEvent('myres:server:doThing', function()
    local src = source                         -- capture before any yield
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end              -- Always validate!
end)
```

## Key Principles

1. **Always check for nil** — `if Player then ... end`
2. **Use `QBCore.Functions.GetPlayer(source)`** — standard retrieval
3. **Never trust client** — validate everything server-side
4. **Use the server's UI stack** — QBCore defaults (`QBCore.Functions.Notify`, qb-menu/qb-input); ox_lib only if installed
5. **Use event-driven updates** — avoid polling PlayerData
6. **Don't modify qb-core files** — use exports/events
7. **Check return values** — `RemoveMoney` and `exports['qb-inventory']:RemoveItem` return `false` on failure

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
local offline = QBCore.Functions.GetOfflinePlayerByCitizenId(citizenId)

-- All online players
local players = QBCore.Functions.GetPlayers()

-- Get player from identifier string
local identifier = QBCore.Functions.GetIdentifier(source, 'license')
```

## Player Object Methods

### Money

```lua
Player.Functions.AddMoney('cash', amount, 'reason')
local ok = Player.Functions.RemoveMoney('cash', amount, 'reason')  -- false if insufficient
Player.Functions.AddMoney('bank', amount, 'reason')
local ok = Player.Functions.RemoveMoney('bank', amount, 'reason')

-- Access player money table
local cash = Player.PlayerData.money['cash']
local bank = Player.PlayerData.money['bank']
```

### Items (qb-inventory exports, server)

```lua
local inv = exports['qb-inventory']

local canAdd, reason = inv:CanAddItem(src, 'water', 2)      -- false, 'weight' | 'slots' on failure
local added = inv:AddItem(src, 'water', 2, false, { quality = 100 }, 'myres:reward')
local removed = inv:RemoveItem(src, 'water', 1, false, 'myres:used')

local item = inv:GetItemByName(src, 'water')    -- first matching slot or nil
local count = inv:GetItemCount(src, 'water')    -- total amount
local has = inv:HasItem(src, 'water', 1)

-- Show the item box animation on the client
TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['water'], 'add', 2)
```

> Never expose a client event that adds or removes items. Grant items only from validated server logic.

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

### Client-Side

```lua
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

-- Usable item
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

```

Item usage goes through `QBCore.Functions.CreateUseableItem` (registered once at resource start). Do not register client-triggerable "use item" events.

## QBCore Client Functions

```lua
-- Notify
QBCore.Functions.Notify('Message', 'success', 5000)  -- (text, type, duration_ms)

-- Draw text (3D world space, per frame)
QBCore.Functions.DrawText3D(x, y, z, 'Text')

-- Screen text UI (qb-core)
exports['qb-core']:DrawText('[E] Open', 'left')
exports['qb-core']:HideText()

-- Get player data
local data = QBCore.Functions.GetPlayerData()

-- Progressbar (requires the `progressbar` resource)
QBCore.Functions.Progressbar('repair', 'Repairing...', 5000, false, true, {
    disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true,
}, { animDict = 'mini@repair', anim = 'fixing_a_ped', flags = 16 }, {}, {}, function()
    -- finished
end, function()
    -- cancelled
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

-- Register shared definitions at runtime (server) — these add item/job/gang DEFINITIONS,
-- they do NOT give anything to a player
QBCore.Functions.AddItem(name, data)
QBCore.Functions.AddJob(name, data)
QBCore.Functions.AddGang(name, data)
```

## QBCore Best Practices

1. **Use QBCore.Functions.GetPlayer()** over other retrieval methods
2. **Event-driven updates over polling** — listen for QBCore events
3. **CreateUseableItem pattern** for item usage instead of manual event handling
4. **Minimize global variables** — keep everything in local scope
5. **Cache PlayerData** in local variables when accessed frequently
6. **Items via `exports['qb-inventory']`** — check `CanAddItem` before `AddItem`, check `RemoveItem`'s return value
7. **Validate permissions server-side** before executing admin commands

## QBCore Documentation

- Full docs: https://docs.qbcore.org/qbcore-documentation
- AI-friendly (llms.txt): https://docs.qbcore.org/qbcore-documentation/llms.txt
- Core object: https://docs.qbcore.org/qbcore-documentation/qb-core/core-object.md
- Player data: https://docs.qbcore.org/qbcore-documentation/qb-core/player-data.md
- Client events: https://docs.qbcore.org/qbcore-documentation/qb-core/client-event-reference.md
- Server events: https://docs.qbcore.org/qbcore-documentation/qb-core/server-event-reference.md
