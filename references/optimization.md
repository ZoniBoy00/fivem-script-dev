# FiveM Optimization Guide

## Thread Management (The #1 Performance Issue)

### ❌ Bad Pattern — Wait(0) Everywhere

```lua
-- This thread runs EVERY FRAME even when nothing is near
Citizen.CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        local dist = #(coords - vector3(100, 200, 30))

        if dist < 50 then
            DrawMarker(1, 100, 200, 29, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 2.0, 255, 0, 0, 100)
            if dist < 2 then
                if IsControlJustPressed(0, 38) then
                    -- Open shop
                end
            end
        end

        Citizen.Wait(0)  -- ❌ per-frame check when player is 500m away
    end
end)
```

### ✅ Good Pattern — Variable Wait

```lua
-- Only runs fast when player is nearby
Citizen.CreateThread(function()
    while true do
        local sleep = 1000  -- Default: check once per second
        local coords = GetEntityCoords(PlayerPedId())
        local dist = #(coords - vector3(100, 200, 30))

        if dist < 50.0 then
            sleep = 100       -- Faster check within 50m
            DrawMarker(1, 100, 200, 29, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 2.0, 255, 0, 0, 100)

            if dist < 2.0 then
                sleep = 0     -- Every tick when close enough
                if IsControlJustPressed(0, 38) then
                    -- Open shop
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)
```

### ✅ Best Pattern — Activated Loop

```lua
-- Only runs when needed (entered/left zone)
local inZone = false

-- Zone management (ox_lib preferred)
local zone = lib.zones.box({
    coords = vector3(100, 200, 30),
    size = vector3(10, 10, 5),
    onEnter = function()
        inZone = true
        lib.showTextUI('[E] - Open Shop')
    end,
    onExit = function()
        inZone = false
        lib.hideTextUI()
    end,
})

-- Fast loop only runs when in zone
Citizen.CreateThread(function()
    while true do
        if inZone then
            if IsControlJustPressed(0, 38) then
                -- Open shop
            end
            Citizen.Wait(0)   -- OK because it only runs when active
        else
            Citizen.Wait(500) -- Long sleep when inactive
        end
    end
end)
```

## Native Caching

### ❌ Bad — Repeated Native Calls

```lua
Citizen.CreateThread(function()
    while true do
        -- Called every tick — expensive!
        local ped = GetPlayerPed(-1)
        local health = GetEntityHealth(ped)
        local armor = GetPedArmour(ped)
        local coords = GetEntityCoords(ped)

        -- Use
        SetPedArmour(ped, armor + 1)

        Citizen.Wait(0)
    end
end)
```

### ✅ Good — Cache Outside Loop

```lua
-- Cache PlayerPedId (built-in, faster than GetPlayerPed(-1))
-- Note: PlayerPedId can change after respawn. Refresh the cache if your logic runs across long sessions.
local playerPed = PlayerPedId()

Citizen.CreateThread(function()
    while true do
        local health = GetEntityHealth(playerPed)
        local armor = GetPedArmour(playerPed)
        SetPedArmour(playerPed, armor + 1)

        Citizen.Wait(500)
    end
end)
```

## Performance Comparison

| Pattern | Performance | Use Case |
|---------|------------|----------|
| `PlayerPedId()` | ✅ Fastest | Getting local player ped |
| `GetPlayerPed(-1)` | ❌ Slow | Never use — PlayerPedId exists |
| `#(coords1 - coords2)` | ✅ Fastest | Distance calculation |
| `GetDistanceBetweenCoords()` | ❌ Slow | Never use — vector math is native-accelerated |
| Local variable | ✅ Fast | Caching native results |
| Global variable | ❌ Slower | Only for cross-module access |
| `Wait(0)` | ❌ Heavy | Only for code that MUST run every frame |
| `Wait(100-1000)` | ✅ Light | Most checks can tolerate 100-500ms delay |
| Ox zone `onEnter/onExit` | ✅ Best | Event-driven, no loop needed |
| Manual distance check loop | ❌ Heavy | Replace with zone enter/exit events |

## Network & Data Optimization

### Minimize Event Spam

```lua
-- ❌ Bad: Spamming events every tick
Citizen.CreateThread(function()
    while true do
        TriggerServerEvent('myres:updatePosition', GetEntityCoords(PlayerPedId()))
        Citizen.Wait(0)
    end
end)

-- ✅ Good: the server reads positions itself (OneSync syncs entity coords)
local coords = GetEntityCoords(GetPlayerPed(src))

-- ✅ Good: state bags for low-frequency shared STATE (not positions)
Entity(vehicle).state:set('locked', true, true)
AddStateBagChangeHandler('locked', nil, function(bagName, key, value)
    -- fires only when the value changes
end)
```

### Send Minimal Payloads

```lua
-- ❌ Bad: Sending entire table
TriggerServerEvent('shop:server:purchase', fullItemTable)

-- ✅ Good: Send only needed data
TriggerServerEvent('shop:server:purchase', itemId, quantity)
```

## Server Optimization

### Use OxMySQL Transactions

```lua
-- Multiple queries in one transaction (faster than separate queries)
-- Use per-query values table; do NOT pass a flat parameter array.
local success = MySQL.transaction.await({
    { query = 'UPDATE bank SET balance = balance - 100 WHERE owner = ?', values = { playerId } },
    { query = 'UPDATE shop SET stock = stock - 1 WHERE item_id = ?', values = { itemId } },
})

if not success then
    print('Transaction failed — rollback')
end
```

### Profile Resources

- **Quick view:** F8 → `resmon 1` (client) shows per-resource CPU ms and memory.
- **Profiler:** `profiler record 500` (records 500 frames) → `profiler view` opens the result in the browser/DevTools. Works in the F8 client console and the server console.
- Server console warnings like `[resource] took X ms` point at heavy server ticks.
- Aim for idle resources near 0.00 ms; anything consistently above ~0.1 ms at idle is worth investigating.

## Client Optimization Quick Checklist

- [ ] All `Wait(0)` replaced with appropriate variable waits
- [ ] Loops only run fast (low sleep) when player is nearby/in zone
- [ ] `PlayerPedId()` used instead of `GetPlayerPed(-1)`
- [ ] Vector distance `#()` used instead of `GetDistanceBetweenCoords`
- [ ] Native results cached in local variables outside hot loops
- [ ] State bags used instead of event spam for frequent sync
- [ ] Network payloads kept minimal
- [ ] Ox zones used instead of manual distance-check loops
- [ ] Event handlers used instead of polling where possible
- [ ] Can't-carry-item checks done before adding inventory items
- [ ] Idle resmon cost near 0.00 ms; no unbounded `Wait(0)` loops

## Links

- Cfx Forum Performance Guide: https://forum.cfx.re/t/best-practice-improve-your-resource-performance/105509
- Script Optimization (QBCore): https://qbcore.org/docs/guides/script-optimization
- FiveM Networking: https://docs.fivem.net/docs/scripting-manual/networking/
