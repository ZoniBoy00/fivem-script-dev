# Common FiveM Script Patterns

> Patterns using the **Ox ecosystem** (ox_lib, oxmysql, ox_inventory, ox_target). Framework-specific lines are marked `-- ADAPT:`; ESX is used as the example framework.

> **🔒 Security note:** These examples keep non-sensitive coordinates (shops, doors, duty points) in shared `Config`. For drug spots, hidden stashes, heist locations and similar, keep coordinates **server-side only** and send them to a client only when needed.

---

## 1. Item Shop (ox_lib + ox_inventory)

### Config (shared)
```lua
Config.ShopCoords = vector3(100.0, 200.0, 30.0)
Config.ShopItems = {            -- keyed by item name → O(1) server lookup
    water = { label = 'Water', price = 5 },
    bread = { label = 'Bread', price = 3 },
    phone = { label = 'Phone', price = 250 },
}
```

### Client
```lua
lib.zones.box({
    coords = Config.ShopCoords,
    size = vector3(3.0, 3.0, 2.0),
    onEnter = function() lib.showTextUI('[E] - Buy water') end,
    onExit = function() lib.hideTextUI() end,
    inside = function()
        if IsControlJustPressed(0, 38) then
            local result = lib.callback.await('myres:buyItem', false, 'water', 1)
            lib.notify({ type = result.success and 'success' or 'error', description = result.message })
        end
    end,
})
```

### Server
```lua
local MAX_QTY = 10

lib.callback.register('myres:buyItem', function(source, itemName, quantity)
    -- 1. Validate input types and ranges
    if type(itemName) ~= 'string' then return { success = false, message = 'Invalid item' } end
    quantity = math.tointeger(quantity)
    if not quantity or quantity < 1 or quantity > MAX_QTY then
        return { success = false, message = 'Invalid amount' }
    end

    -- 2. Price comes from SERVER config only
    local itemData = Config.ShopItems[itemName]
    if not itemData then return { success = false, message = 'Invalid item' } end
    local total = itemData.price * quantity

    -- 3. Player + location
    local xPlayer = ESX.GetPlayerFromId(source)  -- ADAPT: your framework
    if not xPlayer then return { success = false, message = 'Player not found' } end
    if #(GetEntityCoords(GetPlayerPed(source)) - Config.ShopCoords) > 5.0 then
        return { success = false, message = 'Too far away' }
    end

    -- 4. Capacity BEFORE taking money
    if not exports.ox_inventory:CanCarryItem(source, itemName, quantity) then
        return { success = false, message = 'Inventory full' }
    end

    -- 5. Take money; removeMoney returns false if the balance is too low
    if not xPlayer.removeMoney(total, 'shop purchase') then  -- ADAPT
        return { success = false, message = 'Not enough money' }
    end

    -- 6. Give item; refund if it fails
    local added = exports.ox_inventory:AddItem(source, itemName, quantity)
    if not added then
        xPlayer.addMoney(total, 'shop refund')  -- ADAPT
        return { success = false, message = 'Could not add item' }
    end

    return { success = true, message = ('%dx %s purchased'):format(quantity, itemData.label) }
end)
```

> `lib.callback` handlers run per request. Add a per-player cooldown (see `fivem-security.md`) for anything players can spam.

---

## 2. Door Lock System

```lua
-- Config (shared)
Config.Doors = {
    { id = 'police_front', coords = vector3(434.7, -982.1, 30.7), model = joaat('v_ilev_ph_door002'), locked = true, job = 'police' },
}
```

```lua
-- Server: authoritative state replicated through GlobalState
local doorsById = {}
for _, door in ipairs(Config.Doors) do
    doorsById[door.id] = door
    GlobalState['door:' .. door.id] = door.locked
end

RegisterNetEvent('myres:server:toggleDoor', function(doorId)
    local src = source
    local door = type(doorId) == 'string' and doorsById[doorId]
    if not door then return end

    local xPlayer = ESX.GetPlayerFromId(src)  -- ADAPT: your framework
    if not xPlayer then return end
    if door.job and xPlayer.getJob().name ~= door.job then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - door.coords) > 3.0 then return end

    GlobalState['door:' .. door.id] = not GlobalState['door:' .. door.id]
end)
```

```lua
-- Client: one target option per model; label reflects current state
for _, door in ipairs(Config.Doors) do
    exports.ox_target:addModel(door.model, {
        {
            name = 'myres:door:' .. door.id,
            label = 'Lock / Unlock',
            icon = 'fa-solid fa-door-closed',
            distance = 2.0,
            canInteract = function(entity)
                return #(GetEntityCoords(entity) - door.coords) < 1.5
            end,
            onSelect = function() TriggerServerEvent('myres:server:toggleDoor', door.id) end,
        },
    })
end

-- Apply state changes to the door entity
local doorsById = {}
for _, door in ipairs(Config.Doors) do doorsById[door.id] = door end

AddStateBagChangeHandler('', 'global', function(_, key, locked)
    local doorId = key:match('^door:(.+)$')
    local door = doorId and doorsById[doorId]
    if not door then return end

    local entity = GetClosestObjectOfType(door.coords.x, door.coords.y, door.coords.z, 1.5, door.model, false, false, false)
    if entity ~= 0 then FreezeEntityPosition(entity, locked) end
end)
```

> For production doors, prefer an existing door resource (e.g. ox_doorlock) that uses the game's door system (`AddDoorToSystem`) instead of freezing entities.

---

## 3. Vehicle Spawner (server-side, OneSync)

Spawn gameplay vehicles on the server so clients cannot create arbitrary networked entities (pair with `sv_entityLockdown`, see `onesync.md`).

```lua
-- Server
Config.AllowedVehicles = { adder = true, police = true }

lib.addCommand('car', {
    help = 'Spawn vehicle',
    params = { { name = 'model', type = 'string' } },
    restricted = 'group.admin',
}, function(source, args)
    local model = args.model:lower()
    if not Config.AllowedVehicles[model] then return end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local veh = CreateVehicleServerSetter(joaat(model), 'automobile', coords.x + 2.0, coords.y, coords.z, GetEntityHeading(ped))

    local timeoutAt = GetGameTimer() + 5000
    while not DoesEntityExist(veh) and GetGameTimer() < timeoutAt do Wait(0) end
    if not DoesEntityExist(veh) then return end

    SetPedIntoVehicle(ped, veh, -1)
    Entity(veh).state:set('spawnedBy', source, true)
end)
```

> `CreateVehicleServerSetter` needs the correct vehicle type (`automobile`, `bike`, `boat`, `heli`, `plane`, `submarine`, `trailer`, `train`). Map it from the model in config for non-car vehicles.

---

## 4. Whitelist / Ban Check (playerConnecting)

```lua
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source                                   -- capture BEFORE any yield
    deferrals.defer()
    Wait(0)

    local license = GetPlayerIdentifierByType(src, 'license')
    if not license then return deferrals.done('No Rockstar license found.') end

    deferrals.update('Checking whitelist...')

    local ban = MySQL.single.await('SELECT reason FROM bans WHERE identifier = ? AND (expires IS NULL OR expires > NOW())', { license })
    if ban then return deferrals.done('Banned: ' .. (ban.reason or 'N/A')) end

    if Config.WhitelistEnabled then
        local wl = MySQL.scalar.await('SELECT 1 FROM whitelist WHERE identifier = ?', { license })
        if not wl then return deferrals.done('Not whitelisted.') end
    end

    deferrals.done()
end)
```

> `src` here is a temporary connection ID. Create per-player runtime state in `playerJoining` or the framework's "player loaded" event, not in `playerConnecting`.

---

## 5. Basic Server-Side Anti-Abuse

```lua
-- Explosion spam / blacklisted explosion types (server event)
local lastExplosion = {}
local BLOCKED_TYPES = { [29] = true }  -- ADAPT: explosion type IDs you never expect from players

AddEventHandler('explosionEvent', function(sender, ev)
    local src = tonumber(sender)
    if not src then return end

    if BLOCKED_TYPES[ev.explosionType] then
        CancelEvent()
        -- ADAPT: log / ban through your anti-cheat
        return
    end

    local now = GetGameTimer()
    if lastExplosion[src] and now - lastExplosion[src] < 500 then
        CancelEvent()
        return
    end
    lastExplosion[src] = now
end)

AddEventHandler('playerDropped', function()
    lastExplosion[source] = nil
end)
```

> Server-side heuristics only catch obvious abuse. Use a dedicated anti-cheat for mod menus; the most effective general measures are server authority, server-side spawns and `sv_entityLockdown strict`.

---

## 6. Item Usage (ox_inventory export)

```lua
-- ox_inventory/data/items.lua
-- ['water'] = { label = 'Water', weight = 500, client = { anim = {...}, usetime = 2500 }, server = { export = 'myres.water' } },
```

```lua
-- Server: ox_inventory calls this; it has already checked that the player owns the item
Config.UsableItems = { water = { thirst = 30 } }

exports('water', function(event, item, inventory, slot, data)
    if event == 'usedItem' then
        local src = inventory.id
        local effect = Config.UsableItems.water
        -- ADAPT: apply effect through your framework's status system
        TriggerClientEvent('myres:client:drank', src, effect.thirst)
    end
end)
```

> Never let the client report "I finished using item X" as the only proof. The server-side callback above runs only after ox_inventory validated and consumed the item.

---

## 7. Job Clock In/Out

```lua
-- Config (shared)
Config.DutyLocations = {
    { coords = vector3(441.1, -981.1, 30.7), job = 'police', label = 'Police Station' },
}
```

```lua
-- Client: one zone per location, no polling loop
for _, loc in ipairs(Config.DutyLocations) do
    lib.zones.sphere({
        coords = loc.coords,
        radius = 2.0,
        onEnter = function() lib.showTextUI('[E] - Toggle duty') end,
        onExit = function() lib.hideTextUI() end,
        inside = function()
            if IsControlJustPressed(0, 38) then
                local ok = lib.callback.await('myres:toggleDuty', false)
                lib.notify({ type = ok and 'success' or 'error', description = ok and 'Duty toggled' or 'Not allowed here' })
            end
        end,
    })
end
```

```lua
-- Server
lib.callback.register('myres:toggleDuty', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)  -- ADAPT: your framework
    if not xPlayer then return false end

    local coords = GetEntityCoords(GetPlayerPed(source))
    local job = xPlayer.getJob()
    for _, loc in ipairs(Config.DutyLocations) do
        if loc.job == job.name and #(coords - loc.coords) < 3.0 then
            -- ADAPT: ESX 1.16: xPlayer.setJob(job.name, job.grade, not job.onDuty)
            --        QBCore:   Player.Functions.SetJobDuty(not Player.PlayerData.job.onduty)
            return true
        end
    end
    return false
end)
```

---

## Security Checklist

- [ ] `local src = source` at the top of every server handler
- [ ] Server validates all client data (types, ranges, item names, distances)
- [ ] Prices/totals computed server-side; never accepted from the client
- [ ] Capacity checked before money is taken; failed adds are refunded
- [ ] Rate limiting on state-changing events/callbacks
- [ ] Server-side distance checks for physical interactions
- [ ] Gameplay entities spawned server-side; `sv_entityLockdown` configured
- [ ] Sensitive coords stored server-side
- [ ] ACE/framework permission checks in every admin command
- [ ] All SQL uses `?` placeholders
- [ ] ox_lib callbacks always return a value
- [ ] Optional exports guarded with `GetResourceState()`
- [ ] `RegisterNetEvent` called once at file scope
