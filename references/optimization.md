# FiveM Optimization Guide

Lightweight scripts do nothing until something happens. Most cost comes from per-frame loops, polling, oversized network traffic and per-player state that never gets freed.

## 1. Measure First

| Tool | Where | Use |
|------|-------|-----|
| `resmon 1` | F8 (client) | Per-resource CPU ms and memory, live |
| `profiler record 500` → `profiler view` | F8 or server console | Frame-level flame graph of 500 frames |
| `[resource] took X ms` | Server console | Slow server tick or event handler |
| `set mysql_slow_query_warning 150` | server.cfg | oxmysql warns about queries slower than the threshold (ms) |
| `set mysql_debug true` (or `["myres"]`) | server.cfg, dev only | Print every query (or only those resources' queries) |
| `os.microtime()` | Server Lua | Time a single handler: `local t = os.microtime() ... print(os.microtime() - t)` |

Rules of thumb (community practice, not official limits). Measure on your own server:

| State | Target in `resmon` |
|-------|--------------------|
| Idle (player far away, UI closed) | ~0.00–0.01 ms |
| Active (in zone, UI open) | ≲ 0.1 ms |
| Anything consistently above 0.2 ms | Investigate before shipping |

Measure with the resource idle **and** active. A resource that costs 0.05 ms everywhere is worse than one that costs 0.3 ms only while a menu is open.

## 2. Threads

### ❌ Per-frame polling everywhere

```lua
CreateThread(function()
    while true do
        local dist = #(GetEntityCoords(PlayerPedId()) - vec3(100.0, 200.0, 30.0))
        if dist < 50.0 then
            DrawMarker(1, 100.0, 200.0, 29.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 2.0, 255, 0, 0, 100)
            if dist < 2.0 and IsControlJustPressed(0, 38) then
                -- open shop
            end
        end
        Wait(0)  -- ❌ runs every frame even 5 km away
    end
end)
```

### ✅ Variable wait (no dependencies)

```lua
CreateThread(function()
    local target = vec3(100.0, 200.0, 30.0)
    while true do
        local sleep = 1000
        local dist = #(GetEntityCoords(PlayerPedId()) - target)

        if dist < 30.0 then
            sleep = 0  -- markers and key presses need every frame, but only here
            DrawMarker(1, target.x, target.y, target.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 1.0, 255, 0, 0, 100)
            if dist < 2.0 and IsControlJustPressed(0, 38) then
                -- open shop
            end
        end

        Wait(sleep)
    end
end)
```

### ✅ Event-driven: ox_lib points (nothing runs while far away)

`lib.points` checks distances on a shared ox_lib thread (~every 300 ms) and calls `nearby` every frame **only** for points in range. `self.currentDistance` and `self.isClosest` are maintained for you.

```lua
local shop = lib.points.new({
    coords = vec3(100.0, 200.0, 30.0),
    distance = 30.0,
})

function shop:onEnter() end   -- e.g. spawn the shop ped here
function shop:onExit() end    -- delete it here

function shop:nearby()
    DrawMarker(1, self.coords.x, self.coords.y, self.coords.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 1.0, 255, 0, 0, 100)
    if self.currentDistance < 2.0 and IsControlJustPressed(0, 38) then
        -- open shop
    end
end
```

Zones work the same way: `lib.zones.box/sphere/poly({ ..., onEnter, onExit, inside })`, where `inside` runs every frame only while the player is inside. With ox_target there is no loop or key check at all.

### ✅ Keys: mappings instead of polling

```lua
-- Zero cost until pressed; players can rebind it in Settings → Key Bindings → FiveM
local keybind = lib.addKeybind({
    name = 'myres_interact',
    description = 'Interact with shop',
    defaultKey = 'E',
    onPressed = function(self)
        -- open shop (check proximity here)
    end,
})
keybind:disable(true)  -- enable only while in the zone: keybind:disable(false) in onEnter

-- Without ox_lib:
RegisterCommand('+myres_interact', function() --[[ pressed ]] end, false)
RegisterCommand('-myres_interact', function() end, false)
RegisterKeyMapping('+myres_interact', 'Interact with shop', 'keyboard', 'E')
```

### Thread rules

- One thread per *concern*, not per object. 50 shops = one `lib.points` set or one loop over a table, never 50 threads.
- Stop loops you no longer need: `while active do ... end` and set `active = false` in `onExit`/close.
- Prefer `SetTimeout`/`lib.timer`/`lib.cron` for one-off or scheduled work over a `while true` loop with a long `Wait`.

## 3. Cache and Natives

```lua
-- ❌ Querying the same natives every frame
local ped = PlayerPedId()
local veh = GetVehiclePedIsIn(ped, false)

-- ✅ ox_lib cache: updated by ox_lib, read for free
local ped = cache.ped          -- also cache.playerId, cache.serverId, cache.vehicle, cache.seat, cache.weapon
lib.onCache('vehicle', function(vehicle)
    -- fires only when the player enters/leaves/changes vehicle (false when on foot)
end)
```

- `cache.ped` changes on respawn/model change; never store `PlayerPedId()` once at file load.
- Use backtick hashes `` `adder` `` (computed at compile time) instead of `GetHashKey('adder')` in hot paths.
- `#(a - b)` instead of `GetDistanceBetweenCoords`; `PlayerPedId()` instead of `GetPlayerPed(-1)`.
- Don't call expensive "closest X" natives every frame. `lib.getClosestVehicle`/`getNearbyPeds` are fine at interaction time, not in a `Wait(0)` loop.

## 4. Streaming and Entities

```lua
-- Load, use, release. lib.requestModel times out (default 10000 ms) instead of hanging
local model = lib.requestModel(`a_m_m_business_01`)
local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, heading, false, true)
SetModelAsNoLongerNeeded(model)
```

- Release what you request: `SetModelAsNoLongerNeeded`, `RemoveAnimDict`, `RemoveNamedPtfxAsset`, `SetStreamedTextureDictAsNoLongerNeeded`.
- Spawn decorative/local peds and props in `onEnter`, delete them in `onExit`. Don't keep 40 shop peds alive across the map.
- Delete everything you created (entities, blips, zones, points) in `onResourceStop` for your resource.
- Server-owned entities: delete them when no longer needed; orphaned networked entities cost every client.

## 5. Networking

| Need | Use | Why |
|------|-----|-----|
| Client asks server, needs an answer | `lib.callback.await` | One request/response, no paired events |
| Server tells one client/everyone something happened | `TriggerClientEvent` (`-1` = all) | Fire-and-forget |
| State attached to an entity/player (locked, owner, duty) | Entity / Player state bag | Synced to relevant clients only, late joiners get it automatically |
| Small global state (door table, server flags) | `GlobalState` | Synced to everyone; keep it small, every change goes to all clients |
| Large one-off payloads (config, big lists) | `TriggerLatentClientEvent(name, target, bps, ...)` | Rate-limited so it doesn't stall other traffic |
| Positions | Don't sync them | OneSync already does; read `GetEntityCoords(GetPlayerPed(src))` on the server |

```lua
-- ❌ Client → server every frame
CreateThread(function()
    while true do
        TriggerServerEvent('myres:pos', GetEntityCoords(cache.ped))
        Wait(0)
    end
end)

-- ✅ Send only what changed, only when it changed, only IDs
TriggerServerEvent('myres:server:purchase', itemName, quantity)  -- not the whole item table, never the price
```

- Batch: one event with an array instead of 50 events in a loop.
- Broadcast to a routing bucket/nearby players instead of `-1` when only they care.
- Don't write a state bag key every tick; write on change. Every `set(..., true)` replicates.

## 6. Server

- Never loop over `GetPlayers()` every frame. Use events, or a timer with a sensible interval.
- Keep hot data in memory (per-player table loaded in `playerJoining`/framework "loaded" event), write to the DB on change or periodically, and on `playerDropped`. Clean the table on drop so it can't grow forever.
- SQL: `?` placeholders, select only needed columns, index every column you `WHERE`/`JOIN` on, `MySQL.transaction` for multi-step writes, `MySQL.prepare` for batches. Watch `mysql_slow_query_warning` output.
- Cache static config/item data once on start; don't query it per request.
- Don't `Wait` inside ox_inventory hooks or net event handlers while holding a lock; finish fast and defer slow work.

## 7. NUI

- A hidden UI must do nothing: stop `setInterval`/`requestAnimationFrame`/CSS animations when closed (`display: none` stops rendering).
- Don't `SendNUIMessage` every frame. Push changes (health changed, item added), throttle anything continuous to ~5–10/s.
- Keep the bundle small: for a HUD or small menu, vanilla TypeScript or a small framework (Svelte, Preact) is lighter than React plus a component library.
- Release focus (`SetNuiFocus(false, false)`) on close and on resource stop.
- Use local assets (`nui://`) instead of CDN fonts/images: offline-safe and no external requests per open.
- See `templates/nui-vite/` for a TypeScript + Vite setup.

## 8. Memory

- Per-player tables: always `t[src] = nil` in `playerDropped`.
- Caches keyed by entity: remove entries when the entity is deleted, or use `lib.lru`-style bounded caches.
- Don't build strings/tables inside per-frame loops when they can be built once.
- `collectgarbage()` calls are not an optimization; fix what allocates instead.

## Quick Checklist

- [ ] Idle `resmon` ≈ 0.00 ms; active ≲ 0.1 ms (measured, not guessed)
- [ ] No `Wait(0)` loop runs while the player is away or the UI is closed
- [ ] Proximity via `lib.points`/`lib.zones`/ox_target, not one thread per location
- [ ] Keys via `lib.addKeybind`/`RegisterKeyMapping`, not `IsControlJustPressed` polling
- [ ] `cache.ped`/`cache.vehicle`/`lib.onCache` instead of repeated natives
- [ ] Models/dicts released after use; local peds/props spawned and deleted by proximity
- [ ] Everything created is removed in `onResourceStop`
- [ ] Callbacks for request/response, state bags for entity state, small `GlobalState`, latent events for big payloads
- [ ] Minimal payloads (IDs, not tables); no per-frame client → server events
- [ ] Server: no per-frame player loops; data cached in memory and cleaned on drop
- [ ] SQL: placeholders, indexes, needed columns only, slow-query warning enabled
- [ ] NUI idle when hidden; updates pushed on change; small bundle

## Links

- Cfx Forum Performance Guide: https://forum.cfx.re/t/best-practice-improve-your-resource-performance/105509
- ox_lib (points, zones, cache, addKeybind): https://overextended.dev/ox_lib
- oxmysql convars: https://overextended.dev/oxmysql
- FiveM Networking: https://docs.fivem.net/docs/scripting-manual/networking/
