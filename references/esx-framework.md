# ESX Legacy Framework Development

## Core Concepts

ESX Legacy is the #1 FiveM roleplay framework (since 2017). Uses `xPlayer` objects for server-side player management.

### Framework Initialization

**Client:**
```lua
-- Wait for player to load before accessing data
CreateThread(function()
    while not ESX.IsPlayerLoaded() do
        Wait(100)
    end
    -- Player is ready
    local PlayerData = ESX.GetPlayerData()
end)

-- On player loaded event
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayerData)
    PlayerData = xPlayerData
end)

-- On player data update
RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
end)
```

**Server:**
```lua
-- In any server event, source is the triggering player
local xPlayer = ESX.GetPlayerFromId(source)
if not xPlayer then return end  -- Always validate!
```

## Key Principles

1. **Always check for nil** — `if xPlayer then ... end` before ANY xPlayer access
2. **Use `ESX.GetPlayerFromId(source)`** for standard retrieval (not `ESX.GetPlayerFromIdentifier`)
3. **Wait for player load** — check `ESX.IsPlayerLoaded()` on client before using PlayerData
4. **Never trust client** — validate ALL data server-side
5. **Use ox_lib for UI** — over ESX built-in UI systems
6. **Don't modify core ESX files** — use exports/events instead
7. **Use SecureNetEvent** for events that shouldn't be triggered from arbitrary resources

## Get Player

```lua
-- Server
local xPlayer = ESX.GetPlayerFromId(source)         -- By server ID
local xPlayer = ESX.GetPlayerFromIdentifier(identifier)  -- By identifier (steam, license, etc.)
local players = ESX.GetPlayers()                     -- All online players

-- Client
local PlayerData = ESX.GetPlayerData()               -- Current player's data
```

## xPlayer Methods

### Money & Accounts

```lua
-- Cash
xPlayer.addMoney(amount)
xPlayer.removeMoney(amount)
local cash = xPlayer.getMoney()

-- Bank
xPlayer.addAccountMoney('bank', amount)
xPlayer.removeAccountMoney('bank', amount)
local bank = xPlayer.getAccount('bank').money

-- Other accounts (black money, etc.)
xPlayer.addAccountMoney('black_money', amount)
local black = xPlayer.getAccount('black_money').money
```

### Inventory (ESX built-in)

```lua
-- Check & modify items
local item = xPlayer.getInventoryItem(itemName)
local count = item.count
local weight = item.weight
local limit = item.limit  -- max stack size, nil = unlimited

-- Add item
if xPlayer.canCarryItem(itemName, amount) then
    xPlayer.addInventoryItem(itemName, amount)
end

-- Remove item
xPlayer.removeInventoryItem(itemName, amount)

-- Check weight
local currentWeight = xPlayer.getWeight()
local maxWeight = xPlayer.getMaxWeight()
```

### Weapons

```lua
xPlayer.addWeapon(weaponName, ammo)           -- Give weapon
xPlayer.removeWeapon(weaponName)               -- Remove weapon
xPlayer.addWeaponAmmo(weaponName, ammo)        -- Add ammo
xPlayer.removeWeaponAmmo(weaponName, ammo)     -- Remove ammo
xPlayer.addWeaponComponent(weaponName, component)  -- Add component (suppressor, grip, etc.)
xPlayer.removeWeaponComponent(weaponName, component) -- Remove component
```

### Jobs

```lua
local job = xPlayer.getJob()
print(job.name)    -- 'police', 'mechanic', 'unemployed'
print(job.label)   -- 'Police', 'Mechanic'
print(job.grade)   -- 0-12 (number)
print(job.grade_label)  -- 'Cadet', 'Officer', 'Chief'

-- Set job
xPlayer.setJob(jobName, grade)
-- Example: xPlayer.setJob('police', 1)

-- Salary (automatic on payday, or manual)
xPlayer.addAccountMoney('bank', job.salary)
```

### Coordinates & Teleport

```lua
-- Get coords
local coords = xPlayer.getCoords()  -- returns vector3

-- Set coords (teleport client)
xPlayer.setCoords(x, y, z)
```

### Metadata

```lua
xPlayer.setMeta('hunger', 100)
xPlayer.setMeta('thirst', 100)
xPlayer.setMeta('stress', 0)

local hunger = xPlayer.getMeta('hunger')
```

## ESX Events

### TriggerServerCallback (client → server with return)

```lua
-- Client: request data from server
ESX.TriggerServerCallback('myres:getPlayerItems', function(items)
    if items then
        -- Use items data
    end
end)

-- Server: register callback
ESX.RegisterServerCallback('myres:getPlayerItems', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb({}) return end
    
    local items = xPlayer.getInventory()
    cb(items)
end)
```

### SecureNetEvent

```lua
-- Prevents other resources from triggering this event
RegisterNetEvent('esx:secure:myEvent')
AddEventHandler('esx:secure:myEvent', function(data)
    if GetInvokingResource() then return end  -- Only from same resource
    
    local xPlayer = ESX.GetPlayerFromId(source)
    -- handle event
end)
```

### Show Notification
```lua
TriggerClientEvent('esx:showNotification', source, '~g~Item purchased!')
```

## ESX Client Functions

```lua
-- Show Help Text
ESX.ShowHelpNotification('Press ~INPUT_CONTEXT~ to interact')

-- Show Advanced Notification (with icon, color, etc.)
ESX.ShowAdvancedNotification('Shop', 'Purchase', 'You bought an item', 'CHAR_BLOCKED', 0)

-- Displays
ESX.Game.Utils.DrawText3D(coords, 'Text', 0.4)

-- Progressbar (ESX built-in)
ESX.Progressbar('Working...', 3000, function()
    print('Done!')
end)
```

## ESX Jobs & Economy

```lua
-- Server: check if player has specific job
local xPlayer = ESX.GetPlayerFromId(source)
if xPlayer and xPlayer.getJob().name == 'police' then
    -- Do police stuff
end

-- Server: check grade level
local grade = xPlayer.getJob().grade
if grade >= 5 then
    -- Higher rank actions
end

-- Society funds (shared job money)
TriggerEvent('esx_society:getSociety', 'police', function(society)
    if society then
        society.addMoney(amount)
        society.removeMoney(amount)
        local money = society.getMoney()
    end
end)
```

## ESX Configuration

```lua
-- es_extended/config.lua typically has:
Config = {
    EnablePaycheck = true,
    PaycheckTimer = 10 * 60 * 1000,  -- 10 minutes
    Multicharacter = false,
    Identity = false,
    
    -- Optional modules
    EnableHud = false,
    EnablePvP = true,
    
    -- Accounts
    Accounts = {
        'money',        -- Cash
        'bank',         -- Bank
        'black_money',  -- Black money
    },
}
```

## ESX Best Practices

1. **ALWAYS validate xPlayer exists** — players disconnect mid-event
2. **Use `xPlayer.canCarryItem()`** before adding items
3. **Never handle money/items client-side** — server is single source of truth
4. **Use ESX's callback system** instead of chained events for data requests
5. **Group related items in jobs** (e.g. all police items under one category)
6. **Use ox_lib for UI** — ESX built-in menus are deprecated
7. **Prefix exports** with resource name to avoid conflicts

## ESX Documentation

- Full docs: https://docs.esx-framework.org/en/
- Core reference: https://docs.esx-framework.org/en/esx_core/
- Client functions: https://docs.esx-framework.org/en/esx_core/es_extended/client/functions
- Server functions: https://docs.esx-framework.org/en/esx_core/es_extended/server/functions
- Configuration: https://docs.esx-framework.org/en/esx_core/es_extended/config
- GitHub: https://github.com/esx-framework/esx_core
