# Standalone & Multi-Framework Bridge Patterns

> How to write scripts that work **without a framework** (standalone) or **support multiple frameworks** from a single codebase.

---

## 1. Standalone Scripting

Standalone = FiveM natives + Ox ecosystem (ox_lib, oxmysql, optionally ox_inventory). No ESX/QBCore/QBox dependency.

### When to Use

- Simple scripts (spawners, admin tools, minigames)
- Ox-ecosystem servers where ox_lib + ox_inventory is enough
- Avoiding framework lock-in

### fxmanifest

```lua
fx_version 'cerulean'
game 'gta5'
shared_scripts { '@ox_lib/init.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
dependencies { 'ox_lib', 'oxmysql' }
```

### Standalone Player Sessions

The server ID in `playerConnecting` is **temporary**. Load per-player state in `playerJoining`, where `source` is the final server ID.

```lua
-- server/main.lua
local players = {}

AddEventHandler('playerJoining', function()
    local src = source
    local license = GetPlayerIdentifierByType(src, 'license')
    if not license then return DropPlayer(src, 'No Rockstar license.') end

    local user = MySQL.single.await('SELECT identifier, name, job FROM users WHERE identifier = ?', { license })
    if not user then
        local name = GetPlayerName(src)
        MySQL.insert.await('INSERT INTO users (identifier, name, job) VALUES (?, ?, ?)', { license, name, 'unemployed' })
        user = { identifier = license, name = name, job = 'unemployed' }
    end

    players[src] = user
end)

AddEventHandler('playerDropped', function()
    players[source] = nil
end)

exports('GetPlayer', function(src) return players[src] end)
```

### Standalone Money via ox_inventory

Use a zero-weight `money` item as the single source of truth — do not also track a separate `money` field.

```lua
exports('GetMoney', function(src)
    return exports.ox_inventory:GetItemCount(src, 'money')
end)

exports('AddMoney', function(src, amount)
    return exports.ox_inventory:AddItem(src, 'money', amount)
end)

exports('RemoveMoney', function(src, amount)
    if exports.ox_inventory:GetItemCount(src, 'money') < amount then return false end
    return exports.ox_inventory:RemoveItem(src, 'money', amount)
end)
```

---

## 2. Multi-Framework Bridge

One script, multiple frameworks. Detect once at load and expose a small, uniform API.

Detection at file load only works when the framework starts **before** your resource — list it earlier in `server.cfg`.

### Framework Detection (server/bridge.lua)

```lua
local Bridge = { type = 'standalone' }

if GetResourceState('qbx_core') == 'started' then
    Bridge.type = 'qbox'
elseif GetResourceState('qb-core') == 'started' then
    Bridge.type = 'qbcore'
    Bridge.QBCore = exports['qb-core']:GetCoreObject()
elseif GetResourceState('es_extended') == 'started' then
    Bridge.type = 'esx'
    Bridge.ESX = exports.es_extended:getSharedObject()
end

print(('[%s] Framework bridge: %s'):format(GetCurrentResourceName(), Bridge.type))
```

### Unified Player Wrapper

Every money/item function returns `true`/`false` so callers can roll back.

```lua
local function hasOx() return GetResourceState('ox_inventory') == 'started' end

function Bridge.GetPlayer(src)
    if Bridge.type == 'esx' then
        local x = Bridge.ESX.GetPlayerFromId(src)
        if not x then return nil end
        return {
            source = src,
            identifier = x.getIdentifier(),
            job = x.getJob().name,
            getMoney = function() return x.getMoney() end,
            addMoney = function(a) x.addMoney(a, GetCurrentResourceName()); return true end,
            removeMoney = function(a) return x.removeMoney(a, GetCurrentResourceName()) end,
            canCarry = function(i, c) return x.canCarryItem(i, c) end,
            addItem = function(i, c) x.addInventoryItem(i, c); return true end,
            removeItem = function(i, c)
                local item = x.getInventoryItem(i)
                if not item or item.count < c then return false end
                x.removeInventoryItem(i, c)
                return true
            end,
        }
    elseif Bridge.type == 'qbcore' then
        local p = Bridge.QBCore.Functions.GetPlayer(src)
        if not p then return nil end
        local inv = exports['qb-inventory']
        return {
            source = src,
            identifier = p.PlayerData.citizenid,
            job = p.PlayerData.job.name,
            getMoney = function() return p.PlayerData.money.cash end,
            addMoney = function(a) return p.Functions.AddMoney('cash', a, GetCurrentResourceName()) end,
            removeMoney = function(a) return p.Functions.RemoveMoney('cash', a, GetCurrentResourceName()) end,
            canCarry = function(i, c) return (inv:CanAddItem(src, i, c)) end,
            addItem = function(i, c) return inv:AddItem(src, i, c, false, false, GetCurrentResourceName()) end,
            removeItem = function(i, c) return inv:RemoveItem(src, i, c, false, GetCurrentResourceName()) end,
        }
    elseif Bridge.type == 'qbox' then
        local p = exports.qbx_core:GetPlayer(src)
        if not p then return nil end
        return {
            source = src,
            identifier = p.PlayerData.citizenid,
            job = p.PlayerData.job.name,
            getMoney = function() return p.PlayerData.money.cash end,
            addMoney = function(a) return exports.qbx_core:AddMoney(src, 'cash', a, GetCurrentResourceName()) end,
            removeMoney = function(a) return exports.qbx_core:RemoveMoney(src, 'cash', a, GetCurrentResourceName()) end,
            canCarry = function(i, c) return exports.ox_inventory:CanCarryItem(src, i, c) end,
            addItem = function(i, c) return (exports.ox_inventory:AddItem(src, i, c)) end,
            removeItem = function(i, c) return (exports.ox_inventory:RemoveItem(src, i, c)) end,
        }
    end

    -- standalone (requires ox_inventory)
    if not hasOx() then return nil end
    return {
        source = src,
        identifier = GetPlayerIdentifierByType(src, 'license'),
        getMoney = function() return exports.ox_inventory:GetItemCount(src, 'money') end,
        addMoney = function(a) return (exports.ox_inventory:AddItem(src, 'money', a)) end,
        removeMoney = function(a)
            if exports.ox_inventory:GetItemCount(src, 'money') < a then return false end
            return (exports.ox_inventory:RemoveItem(src, 'money', a))
        end,
        canCarry = function(i, c) return exports.ox_inventory:CanCarryItem(src, i, c) end,
        addItem = function(i, c) return (exports.ox_inventory:AddItem(src, i, c)) end,
        removeItem = function(i, c) return (exports.ox_inventory:RemoveItem(src, i, c)) end,
    }
end
```

> When ESX runs with `Config.CustomInventory = 'ox'`, `xPlayer` item methods already route to ox_inventory, so the ESX branch works unchanged.

### Unified Notifications (server → client)

```lua
function Bridge.Notify(src, msg, notifyType)
    notifyType = notifyType or 'inform'
    if GetResourceState('ox_lib') == 'started' and Bridge.type ~= 'qbcore' then
        TriggerClientEvent('ox_lib:notify', src, { type = notifyType, description = msg })
    elseif Bridge.type == 'esx' then
        TriggerClientEvent('esx:showNotification', src, msg, notifyType == 'inform' and 'info' or notifyType)
    elseif Bridge.type == 'qbcore' then
        TriggerClientEvent('QBCore:Notify', src, msg, notifyType == 'inform' and 'primary' or notifyType)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { msg } })
    end
end
```

---

## 3. Complete Multi-FW Example Structure

```
my-script/
├── fxmanifest.lua
├── shared/config.lua
├── server/bridge.lua        ← Framework detection + unified API
├── server/main.lua          ← Uses Bridge.GetPlayer() for all framework ops
└── client/main.lua          ← ox_lib only (framework-agnostic)
```

```lua
fx_version 'cerulean'
game 'gta5'
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/bridge.lua', 'server/main.lua' }
```

> `bridge.lua` defines the global `Bridge` on purpose (shared by `server/main.lua`). Keep everything else local.

### Server Example — Works on All Frameworks

```lua
lib.callback.register('myscript:buyItem', function(source, itemName)
    local item = type(itemName) == 'string' and Config.Items[itemName]
    if not item then return false end

    local player = Bridge.GetPlayer(source)
    if not player then return false end

    if not player.canCarry(itemName, 1) then return false end
    if not player.removeMoney(item.price) then return false end
    if not player.addItem(itemName, 1) then
        player.addMoney(item.price)  -- refund
        return false
    end
    return true
end)
```

---

## 4. Compatibility Table

| API Call | ESX | QBCore | QBox | Standalone |
|----------|-----|--------|------|------------|
| Get player | `ESX.GetPlayerFromId(src)` | `QBCore.Functions.GetPlayer(src)` | `exports.qbx_core:GetPlayer(src)` | own table keyed in `playerJoining` |
| Add money | `xPlayer.addMoney(n, reason)` | `Player.Functions.AddMoney('cash', n, reason)` | `exports.qbx_core:AddMoney(src, 'cash', n, reason)` | `ox_inventory:AddItem(src, 'money', n)` |
| Remove money | `xPlayer.removeMoney(n, reason)` → bool | `Player.Functions.RemoveMoney('cash', n, reason)` → bool | `exports.qbx_core:RemoveMoney(src, 'cash', n, reason)` → bool | check count, then `RemoveItem` |
| Add item | `xPlayer.addInventoryItem(n, c)` | `exports['qb-inventory']:AddItem(src, n, c)` | `ox_inventory:AddItem(src, n, c)` | `ox_inventory:AddItem(src, n, c)` |
| Notify | `esx:showNotification` | `QBCore:Notify` | `ox_lib:notify` | `ox_lib:notify` |
| Callback | `ESX.RegisterServerCallback` | `QBCore.Functions.CreateCallback` | `lib.callback.register` | `lib.callback.register` |

## 5. Best Practices

1. **Detect once** — at load, with the framework started earlier in `server.cfg`.
2. **Return booleans** from every money/item wrapper and roll back on failure.
3. **Capture `source`** as `src` before any yield.
4. **Validate server-side** regardless of framework.
5. **Test on every target** — inventories differ in metadata, weight and stacking.
