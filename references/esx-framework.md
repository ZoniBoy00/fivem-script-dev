# ESX Legacy Framework Development

> Verified against `esx-framework/esx_core` **1.16.x**. Older ESX (1.1–1.9, `esx:getSharedObject` event) differs — check the server's `es_extended/fxmanifest.lua` version before using newer APIs.

## Core Concepts

ESX Legacy uses `xPlayer` objects for server-side player management. The official stack in `esx_core` now includes its own UI and utility resources:

| Resource | Purpose | API |
|----------|---------|-----|
| `es_extended` | Core, xPlayer, items, accounts | `ESX.*`, `xPlayer.*` |
| `esx_lib` | Utility library (ox_lib-derived) | global `xLib` via `@esx_lib/imports.lua` |
| `esx_notify` | Notifications | `ESX.ShowNotification`, `xPlayer.showNotification` |
| `esx_textui` | Text UI | `ESX.TextUI(msg, type)`, `ESX.HideUI()` |
| `esx_progressbar` | Progress bar | `ESX.Progressbar(msg, ms, options)` |
| `esx_context` | Context menus | `ESX.OpenContext(...)` |
| `esx_inventory` | NUI inventory (es_extended stays the authority) | xPlayer item methods |

ox_lib / ox_inventory / ox_target are optional on ESX. es_extended has built-in ox_inventory support (`Config.CustomInventory = 'ox'`); xPlayer item methods keep working.

### Getting the ESX object

```lua
-- fxmanifest.lua (recommended)
shared_script '@es_extended/imports.lua'   -- defines global ESX (and ESX.PlayerData on client)

-- or manually
-- local ESX = exports['es_extended']:getSharedObject()
```

### Framework Initialization

**Client:**
```lua
-- PlayerData is kept up to date by @es_extended/imports.lua
RegisterNetEvent('esx:playerLoaded', function(xPlayerData)
    -- player is ready; xPlayerData.job, .accounts, .inventory...
end)

RegisterNetEvent('esx:setJob', function(job, lastJob)
    -- job changed
end)

-- Logout / character switch (sent only by the server)
ESX.SecureNetEvent('esx:onPlayerLogout', function()
    -- cleanup
end)

-- If your resource may start after the player has loaded:
CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(200) end
    local data = ESX.GetPlayerData()
end)
```

**Server:**
```lua
RegisterNetEvent('myres:server:doThing', function()
    local src = source                       -- capture before any yield
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
end)

-- Server-side lifecycle
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer, isNew) end)
AddEventHandler('esx:playerDropped', function(playerId, reason) end)
```

## Key Principles

1. **Always check for nil** — `ESX.GetPlayerFromId` returns nil for unloaded/disconnected players.
2. **Capture `source` first** — `local src = source` before any `Wait`/await.
3. **Check return values** — `removeMoney`/`removeAccountMoney` return `false` when the balance is insufficient.
4. **Never trust the client** — prices, amounts, item names and distances are validated server-side.
5. **Use the ESX UI the server runs** — `esx_notify`/`esx_textui`/`esx_context` by default; ox_lib only if installed.
6. **Don't modify core ESX files** — use exports/events from your own resource.

## Get Player

```lua
-- Server
local xPlayer = ESX.GetPlayerFromId(src)
local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
local xPlayers = ESX.GetExtendedPlayers()            -- all xPlayers
local police = ESX.GetExtendedPlayers('job', 'police') -- filtered

-- Client
local PlayerData = ESX.GetPlayerData()
```

## xPlayer Methods

### Money & Accounts

```lua
xPlayer.addMoney(amount, 'reason')
local ok = xPlayer.removeMoney(amount, 'reason')        -- false if not enough
local cash = xPlayer.getMoney()

xPlayer.addAccountMoney('bank', amount, 'reason')
local ok = xPlayer.removeAccountMoney('bank', amount, 'reason')
local bank = xPlayer.getAccount('bank').money

local black = xPlayer.getAccount('black_money').money
```

### Inventory

```lua
local item = xPlayer.getInventoryItem('water')   -- { name, label, count, weight, ... } or nil
local count = item and item.count or 0
local has = xPlayer.hasItem('water')

if xPlayer.canCarryItem('water', 2) then
    xPlayer.addInventoryItem('water', 2)
end
xPlayer.removeInventoryItem('water', 1)

local weight, maxWeight = xPlayer.getWeight(), xPlayer.getMaxWeight()
```

### Weapons

```lua
xPlayer.addWeapon('WEAPON_PISTOL', 50)
xPlayer.removeWeapon('WEAPON_PISTOL')
xPlayer.addWeaponAmmo('WEAPON_PISTOL', 20)
xPlayer.addWeaponComponent('WEAPON_PISTOL', 'clip_extended')
local has = xPlayer.hasWeapon('WEAPON_PISTOL')
```

### Jobs

```lua
local job = xPlayer.getJob()
-- job.name, job.label, job.grade (number), job.grade_name, job.grade_label, job.grade_salary

xPlayer.setJob('police', 1)
```

### Coordinates

```lua
local coords = xPlayer.getCoords(true)          -- vector3 (pass true for a vector)
xPlayer.setCoords(vector3(x, y, z))             -- teleport; returns false on invalid coords
```

### Metadata

```lua
xPlayer.setMeta('stress', 0)
local stress = xPlayer.getMeta('stress')
xPlayer.clearMeta('stress')
```

### Notifications & UI from the server

```lua
xPlayer.showNotification('Item purchased!', 'success', 3000)
xPlayer.showHelpNotification('Press ~INPUT_CONTEXT~ to interact')
-- or: TriggerClientEvent('esx:showNotification', src, 'Text', 'success')
```

## Callbacks

```lua
-- Server
ESX.RegisterServerCallback('myres:getItems', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    cb(xPlayer.getInventory(true))
end)

-- Client
ESX.TriggerServerCallback('myres:getItems', function(items)
    -- use items
end)
```

`lib.callback` (ox_lib) is a valid alternative when ox_lib is installed.

## Usable Items

```lua
-- Server
ESX.RegisterUsableItem('bandage', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    xPlayer.removeInventoryItem('bandage', 1)
    TriggerClientEvent('myres:client:useBandage', source)
end)
```

## `ESX.SecureNetEvent` (client-side)

`ESX.SecureNetEvent(name, handler)` is a **client** helper for **server → client** events. It is not a server-side guard and does not validate client requests. Server net events still need full server-side validation.

```lua
-- Client
ESX.SecureNetEvent('myres:client:setState', function(state)
    -- runs only for events sent by the server
end)
```

## Client UI Helpers

```lua
ESX.ShowNotification('Saved', 'success', 3000)
ESX.ShowHelpNotification('Press ~INPUT_CONTEXT~ to open')
ESX.TextUI('[E] Open shop', 'info')
ESX.HideUI()

ESX.Progressbar('Repairing...', 5000, {
    FreezePlayer = true,
    animation = { type = 'anim', dict = 'mini@repair', lib = 'fixing_a_ped' },
    onFinish = function() end,
    onCancel = function() end,
})
```

## Jobs & Society

```lua
local xPlayer = ESX.GetPlayerFromId(src)
if xPlayer and xPlayer.getJob().name == 'police' and xPlayer.getJob().grade >= 3 then
    -- authorized
end

-- Society accounts (esx_society + esx_addonaccount must be installed)
TriggerEvent('esx_society:getSociety', 'police', function(society)
    if not society then return end
    TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
        if account then account.addMoney(100) end
    end)
end)
```

## ESX Best Practices

1. Validate `xPlayer` after every lookup.
2. Check `canCarryItem` before adding and the return value of `removeMoney` before granting anything.
3. Keep all money/item changes server-side.
4. Use `ESX.GetExtendedPlayers(key, value)` instead of looping all players manually.
5. Use the framework's own UI (`esx_notify`, `esx_textui`, `esx_context`) unless the server standardizes on ox_lib.
6. Prefix events/exports with your resource name.

## ESX Documentation

- Docs: https://docs.esx-framework.org/
- GitHub: https://github.com/esx-framework/esx_core
