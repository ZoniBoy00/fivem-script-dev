# Standalone & Multi-Framework Bridge Patterns

> How to write scripts that work **without a framework** (standalone) or **support multiple frameworks** from a single codebase.

---

## 1. Standalone Scripting

Standalone = FiveM natives + Ox ecosystem (ox_lib, oxmysql, ox_inventory). No ESX/QBCore/QBox dependency.

### When to Use Standalone

- Simple scripts (vehicle spawners, door locks, admin tools)
- Performance-critical resources (no framework overhead)
- Ox-ecosystem servers (ox_lib + ox_inventory is enough)
- You want to avoid framework lock-in

### fxmanifest

```lua
fx_version 'cerulean'; game 'gta5'; lua54 'yes'
shared_scripts { '@ox_lib/init.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
dependencies { 'ox_lib', 'oxmysql' }
```

### Standalone Player Management

```lua
-- server/main.lua — Simple player session tracker
local players = {}

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    deferrals.defer(); Wait(0)
    local license = nil
    for _, v in ipairs(GetPlayerIdentifiers(source)) do
        if string.find(v, 'license:') then license = v; break end
    end
    if not license then deferrals.done('No license'); return end
    local user = MySQL.single.await('SELECT * FROM users WHERE identifier = ?', {license})
    if not user then
        MySQL.insert.await('INSERT INTO users (identifier, name) VALUES (?, ?)', {license, name})
        user = { identifier = license, name = name, money = 500, job = 'unemployed' }
    end
    players[source] = user
    deferrals.done()
end)

AddEventHandler('playerDropped', function()
    local p = players[source]
    if p then MySQL.update.await('UPDATE users SET money = ? WHERE identifier = ?', {p.money, p.identifier}) end
    players[source] = nil
end)

exports('GetPlayer', function(source) return players[source] end)
```

### Standalone Money via ox_inventory

```lua
-- Add 'money' as an ox_inventory item with 0 weight
exports('AddMoney', function(src, amt) exports.ox_inventory:AddItem(src, 'money', amt) end)
exports('RemoveMoney', function(src, amt) exports.ox_inventory:RemoveItem(src, 'money', amt) end)
exports('GetMoney', function(src) return exports.ox_inventory:Search('count', 'money', src) end)
```

---

## 2. Multi-Framework Bridge

One script, multiple frameworks. Detect at runtime, use correct API.

### Framework Detection

```lua
-- shared/bridge.lua
local Framework = { type = nil }

CreateThread(function()
    if GetResourceState('qbx_core') == 'started' then Framework = { type = 'qbox', res = exports.qbx_core }
    elseif GetResourceState('qb-core') == 'started' then Framework = { type = 'qbcore', res = exports['qb-core']:GetCoreObject() }
    elseif GetResourceState('es_extended') == 'started' then Framework = { type = 'esx', res = ESX }
    else Framework = { type = 'standalone' } end
    print('[Bridge] Detected:', Framework.type)
end)
```

### Unified Player Wrapper

```lua
function GetPlayerSafe(source)
    if Framework.type == 'esx' then
        local x = ESX.GetPlayerFromId(source); if not x then return nil end
        return { source = source, identifier = x.identifier, job = x.getJob(), money = x.getMoney(),
                 addMoney = function(a) x.addMoney(a) end, removeMoney = function(a) x.removeMoney(a) end,
                 addItem = function(i,c) x.addInventoryItem(i,c) end, removeItem = function(i,c) x.removeInventoryItem(i,c) end }
    elseif Framework.type == 'qbcore' then
        local p = QBCore.Functions.GetPlayer(source); if not p then return nil end
        return { source = source, identifier = p.PlayerData.citizenid, job = p.PlayerData.job, money = p.PlayerData.money.cash,
                 addMoney = function(a) p.Functions.AddMoney('cash', a) end, removeMoney = function(a) p.Functions.RemoveMoney('cash', a) end,
                 addItem = function(i,c) p.Functions.AddItem(i,c) end, removeItem = function(i,c) p.Functions.RemoveItem(i,c) end }
    elseif Framework.type == 'qbox' then
        local p = exports.qbx_core:GetPlayer(source); if not p then return nil end
        return { source = source, identifier = p.PlayerData.citizenid, job = p.PlayerData.job,
                 addMoney = function(a) p.Functions.AddMoney('cash', a) end, removeMoney = function(a) p.Functions.RemoveMoney('cash', a) end,
                 addItem = function(i,c) exports.ox_inventory:AddItem(source,i,c) end, removeItem = function(i,c) exports.ox_inventory:RemoveItem(source,i,c) end }
    else -- standalone
        local p = players[source]; if not p then return nil end
        return { source = source, identifier = p.identifier, money = p.money,
                 addMoney = function(a) p.money = p.money + a; exports.ox_inventory:AddItem(source,'money',a) end,
                 removeMoney = function(a) p.money = p.money - a; exports.ox_inventory:RemoveItem(source,'money',a) end,
                 addItem = function(i,c) exports.ox_inventory:AddItem(source,i,c) end, removeItem = function(i,c) exports.ox_inventory:RemoveItem(source,i,c) end }
    end
end
```

### Unified Notifications

```lua
function NotifyPlayer(source, type, msg)
    local t = { success = 'success', error = 'error', info = 'info', warning = 'warning' }
    if Framework.type == 'esx' and GetResourceState('ox_lib') ~= 'started' then
        TriggerClientEvent('esx:showNotification', source, msg)
    elseif Framework.type == 'qbcore' then
        TriggerClientEvent('QBCore:Notify', source, msg, t[type] or 'info')
    else
        TriggerClientEvent('ox_lib:notify', source, { type = t[type] or 'info', description = msg })
    end
end
```

---

## 3. Complete Multi-FW Example Structure

```
my-script/
├── fxmanifest.lua
├── shared/config.lua
├── shared/bridge.lua        ← Framework detection + unified API
├── client/main.lua          ← Uses ox_lib only (framework-agnostic)
└── server/main.lua          ← Uses GetPlayerSafe() for all framework ops
```

### fxmanifest

```lua
fx_version 'cerulean'; game 'gta5'; lua54 'yes'
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', 'shared/bridge.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
```

### Server Example — Works on All Frameworks

```lua
lib.callback.register('myscript:buyItem', function(source, itemName)
    local player = GetPlayerSafe(source)  -- ← Bridge handles ESX/QB/QBox/Standalone
    if not player then return false end
    -- ... item validation, money check via player.removeMoney(), add via player.addItem()
    return true
end)
```

---

## 4. Compatibility Table

| API Call | ESX | QBCore | QBox | Standalone |
|----------|-----|--------|------|------------|
| Get player | `ESX.GetPlayerFromId(src)` | `QBCore.Functions.GetPlayer(src)` | `exports.qbx_core:GetPlayer(src)` | `players[src]` |
| Add money | `xPlayer.addMoney(n)` | `Player.Functions.AddMoney('cash', n)` | `player.Functions.AddMoney('cash', n)` | `ox_inventory:AddItem(src,'money',n)` |
| Remove money | `xPlayer.removeMoney(n)` | `Player.Functions.RemoveMoney('cash', n)` | `player.Functions.RemoveMoney('cash', n)` | `ox_inventory:RemoveItem(src,'money',n)` |
| Add item | `xPlayer.addInventoryItem(n,c)` | `Player.Functions.AddItem(n,c)` | `ox_inventory:AddItem(src,n,c)` | `ox_inventory:AddItem(src,n,c)` |
| Notify | `esx:showNotification` | `QBCore:Notify` | `ox_lib` | `ox_lib` |
| Callback | `ESX.RegisterServerCallback` | `QBCore.Functions.CreateCallback` | `lib.callback.register` | `lib.callback.register` |
| Inventory | ESX built-in or ox_inventory | qb-inventory or ox_inventory | ox_inventory | ox_inventory |

## 5. Best Practices

1. **Ox ecosystem first** — ox_lib + ox_inventory work on ALL frameworks
2. **Bridge at the top** — Detect once on start, use bridge functions everywhere
3. **Never trust `source` from client events** — Validate server-side regardless of framework
4. **Fall back to Ox** — ox_lib notifications and callbacks work universally
5. **Test on all targets** — behavior differs (e.g. QBCore money vs ox_inventory money)
