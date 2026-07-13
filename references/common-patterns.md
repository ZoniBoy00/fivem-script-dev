# Common FiveM Script Patterns

> Battle-tested patterns using the **Ox ecosystem** (ox_lib, oxmysql, ox_inventory, ox_target). Framework-specific parts marked with `-- ADAPT:`.

---

## 1. Item Shop (ox_lib + ox_inventory)

### Config
```lua
Config.ShopItems = {
    { name = 'water',  label = 'Water',  price = 5 },
    { name = 'bread',  label = 'Bread',  price = 3 },
    { name = 'phone',  label = 'Phone',  price = 250 },
}
```

### Client
```lua
-- ox_lib zone
lib.zones.box({
    coords = vector3(100.0, 200.0, 30.0),
    size = vector3(3.0, 3.0, 2.0),
    onEnter = function() lib.showTextUI('[E] - Open Shop') end,
    onExit = function() lib.hideTextUI() end,
    inside = function()
        if IsControlJustPressed(0, 38) then
            local result = lib.callback.await('myres:buyItem', false, 'water')
            if result.success then
                lib.notify({ type = 'success', description = result.message })
            else
                lib.notify({ type = 'error', description = result.error })
            end
        end
    end,
})
```

### Server
```lua
lib.callback.register('myres:buyItem', function(source, itemName)
    -- ADAPT: get player via your framework
    local itemData = nil
    for _, v in ipairs(Config.ShopItems) do if v.name == itemName then itemData = v; break end end
    if not itemData then return { success = false, error = 'Invalid item' } end

    -- ADAPT: money check
    -- ADAPT: use ox_inventory or framework method
    if not exports.ox_inventory:CanCarryItem(source, itemName, 1) then
        return { success = false, error = 'Inventory full' }
    end

    -- ADAPT: remove money + add item
    exports.ox_inventory:AddItem(source, itemName, 1)
    return { success = true, message = itemData.label .. ' purchased!' }
end)
```

---

## 2. Door Lock System

```lua
-- Config
Config.Doors = {
    { id = 'police_front', coords = vector3(434.7, -982.1, 30.7), model = 'v_ilev_ph_door002', locked = true, job = 'police' },
}

-- Client: ox_target interaction
CreateThread(function()
    for _, door in ipairs(Config.Doors) do
        exports.ox_target:addModel(door.model, {
            { name = 'toggle_'..door.id,
              label = door.locked and 'Unlock' or 'Lock',
              distance = 2.5,
              onSelect = function() TriggerServerEvent('myres:toggleDoor', door.id) end },
        })
    end
end)

-- Server
local doorStates = {}
CreateThread(function() for _, d in ipairs(Config.Doors) do doorStates[d.id] = d.locked end end)

RegisterNetEvent('myres:toggleDoor')
AddEventHandler('myres:toggleDoor', function(doorId)
    if GetInvokingResource() then return end
    -- ADAPT: job check
    local coords = GetEntityCoords(GetPlayerPed(source))
    local doorConfig = nil; for _, d in ipairs(Config.Doors) do if d.id == doorId then doorConfig = d; break end end
    if not doorConfig or #(coords - doorConfig.coords) > 5.0 then return end  -- Distance check
    doorStates[doorId] = not doorStates[doorId]
    TriggerClientEvent('myres:syncDoor', -1, doorId, doorStates[doorId])
end)
```

---

## 3. Vehicle Spawner

```lua
-- Client
lib.addCommand('car', { help = 'Spawn vehicle', params = { { name = 'model', type = 'string' } } }, function(source, args)
    local result = lib.callback.await('myres:spawnVehicle', false, args.model or 'adder')
    if not result.success then return end
    local model = args.model or 'adder'
    RequestModel(model); while not HasModelLoaded(model) do Wait(100) end
    local coords = GetEntityCoords(PlayerPedId()); local veh = CreateVehicle(model, coords.x+2, coords.y+2, coords.z, GetEntityHeading(PlayerPedId()), true, false)
    SetPedIntoVehicle(PlayerPedId(), veh, -1); SetModelAsNoLongerNeeded(model)
end)

-- Server
lib.callback.register('myres:spawnVehicle', function(source, model)
    -- ADAPT: framework money check + permission check
    return { success = true }
end)
```

---

## 4. Whitelist (playerConnecting)

```lua
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    deferrals.defer(); Wait(0)
    local ids = GetPlayerIdentifiers(source); local steamId = nil
    for _, v in ipairs(ids) do if string.find(v, 'steam:') then steamId = v; break end end
    if not steamId then deferrals.done('Steam required'); return end

    local banned = MySQL.single.await('SELECT * FROM bans WHERE identifier = ? AND (expires IS NULL OR expires > NOW())', {steamId})
    if banned then deferrals.done('Banned: ' .. (banned.reason or 'N/A')); return end

    if Config.WhitelistEnabled then
        local wl = MySQL.single.await('SELECT * FROM whitelist WHERE identifier = ?', {steamId})
        if not wl then deferrals.done('Not whitelisted'); return end
    end

    MySQL.rawExecute('INSERT IGNORE INTO users (identifier, name) VALUES (?, ?)', {steamId, name})
    deferrals.done()
end)
```

---

## 5. Basic Anti-Cheat

```lua
-- Health check (periodic)
CreateThread(function()
    while true do Wait(10000)
        for _, id in ipairs(GetPlayers()) do
            local ped = GetPlayerPed(id)
            if DoesEntityExist(ped) and GetEntityHealth(ped) > GetEntityMaxHealth(ped) + 50 then
                DropPlayer(id, 'Health manipulation')
            end
        end
    end
end)

-- Explosive spam
local lastExp = {}
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventExplosion' then return end
    local src = NetworkGetPlayerIndexFromPed(args[1]); if not src then return end
    local now = GetGameTimer()
    if lastExp[src] and now - lastExp[src] < 500 then DropPlayer(src, 'Exploit'); return end
    lastExp[src] = now
end)
```

---

## 6. Item Usage (ox_inventory + ox_lib)

```lua
-- Config
Config.UsableItems = {
    ['water'] = { usageTime = 3000, anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' }, effects = { thirst = 30 } },
}

-- Server
for itemName in pairs(Config.UsableItems) do
    exports.ox_inventory:registerUsableItem(itemName, function(source, item)
        TriggerClientEvent('myres:useItem', source, itemName)
    end)
end

-- Client
RegisterNetEvent('myres:useItem')
AddEventHandler('myres:useItem', function(itemName)
    local cfg = Config.UsableItems[itemName]; if not cfg then return end
    local completed = lib.progressBar({ duration = cfg.usageTime, label = 'Using ' .. itemName .. '...', canCancel = true, anim = cfg.anim })
    if completed then TriggerServerEvent('myres:itemUsed', itemName) end
end)
```

---

## 7. Job Clock In/Out

```lua
-- Config
Config.DutyLocations = {
    { coords = vector3(441.1, -981.1, 30.7), job = 'police', label = 'Police Station' },
}

-- Client
local nearDuty = false
CreateThread(function()
    while true do
        local sleep = 1500; local coords = GetEntityCoords(PlayerPedId())
        nearDuty = false
        for _, loc in ipairs(Config.DutyLocations) do
            if #(coords - loc.coords) < 5.0 then
                sleep = 0; nearDuty = true
                lib.showTextUI('[E] - ' .. loc.label, { position = 'left-center' })
                if IsControlJustPressed(0, 38) then
                    local result = lib.callback.await('myres:toggleDuty', false)
                    lib.notify({ type = result and 'success' or 'error', description = result and 'Duty toggled' or 'Failed' })
                end
                break
            end
        end
        if not nearDuty then lib.hideTextUI() end
        Wait(sleep)
    end
end)

-- Server
lib.callback.register('myres:toggleDuty', function(source)
    if GetInvokingResource() then return false end
    -- ADAPT: toggle duty via framework
    return true
end)
```

---

## Security Checklist

- [ ] Server validates ALL data from client (amounts, IDs, distances, item names)
- [ ] Rate limiting on all state-changing events
- [ ] `GetInvokingResource()` on every sensitive event
- [ ] Server-side distance validation for physical interactions
- [ ] Sensitive coords (drug spots, stashes) stored server-side; sent only when nearby
- [ ] Money/items transactions only server-side
- [ ] `IsPlayerAceAllowed()` for admin commands
- [ ] All SQL uses `?` placeholders
- [ ] ox_lib callbacks always return a response
- [ ] Loop wait times are appropriate (not all `Wait(0)`)
- [ ] Player object validated before use
- [ ] ox_inventory space checked before adding items
