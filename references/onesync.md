# OneSync — Entity Management & Routing Buckets

> OneSync controls how entities (players, vehicles, objects) are streamed across the server. Understanding it is critical for performance and multi-server setups.

---

## OneSync Modes

| Mode | Description | Use When |
|------|-------------|----------|
| **Off** | Legacy mode. Every player receives ALL entities. | Small servers (<32 players), max compatibility |
| **On** | Default. Players receive entities based on distance. | 32-128 players, most servers |
| **Essential** | Force-enabled. Players only see entities in their scope. | >128 players, large-scale servers |

**Set in server.cfg:**
```cfg
onesync on              -- Recommended for most servers
onesync_forceMigrate true  -- Force migrate entities to the new system
onesync_enableInfinity false -- Enable for extreme player counts (unstable)
```

---

## Routing Buckets

> Routing buckets isolate groups of players so they can't see or interact with each other. Think of them as "dimensions" or "shards."

### Basic Usage

```lua
-- Server-side: Set player's routing bucket
SetPlayerRoutingBucket(source, bucketId)  -- bucketId = number

-- Set entity's routing bucket
SetEntityRoutingBucket(entity, bucketId)

-- Get current bucket
local bucket = GetPlayerRoutingBucket(source)
```

### Common Use Cases

**1. Per-player housing instances**
```lua
-- When player enters their house
local houseId = 100  -- Unique per house
SetPlayerRoutingBucket(source, houseId)

-- When player exits, return to main world
SetPlayerRoutingBucket(source, 0)  -- Bucket 0 = main world
```

**2. Admin jail (isolated)**
```lua
local JAIL_BUCKET = 9999

function JailPlayer(source, duration)
    SetPlayerRoutingBucket(source, JAIL_BUCKET)
    SetEntityCoords(GetPlayerPed(source), jailX, jailY, jailZ)
    
    SetTimeout(duration * 60000, function()
        if GetPlayerRoutingBucket(source) == JAIL_BUCKET then
            SetPlayerRoutingBucket(source, 0)
        end
    end)
end
```

**3. Event/interior instances per player group**
```lua
-- When event starts
local eventBucket = nextEventId + 1000
for _, src in ipairs(eventPlayers) do
    SetPlayerRoutingBucket(src, eventBucket)
end

-- Teleport to event location
for _, src in ipairs(eventPlayers) do
    SetEntityCoords(GetPlayerPed(src), eventX, eventY, eventZ)
end

-- When event ends, return everyone to main world
for _, src in ipairs(eventPlayers) do
    SetPlayerRoutingBucket(src, 0)
end
```

---

## Entity Migration

> When an entity (car, object) needs to move between routing buckets or be seen by players in different buckets.

### Server-side Entity Setting

```lua
-- Set entity to be visible to specific routing bucket
SetEntityRoutingBucket(entity, bucketId)

-- Make entity visible to ALL buckets (global)
SetEntityRoutingBucket(entity, 0)  -- or use SetEntityAsMissionEntity

-- Set entity as no longer needed (let server manage it)
SetEntityAsNoLongerNeeded(entity)
```

### Vehicle Migration

```lua
-- When a player enters a vehicle, the vehicle should be in their bucket
-- Server-side: iterate players instead of using client-only entity pools
CreateThread(function()
    while true do
        Wait(5000)
        
        for _, source in ipairs(GetPlayers()) do
            local ped = GetPlayerPed(source)
            if ped and ped ~= 0 then
                local vehicle = GetVehiclePedIsIn(ped, false)
                if vehicle and vehicle ~= 0 then
                    local playerBucket = GetPlayerRoutingBucket(source)
                    local vehicleBucket = GetEntityRoutingBucket(vehicle)
                    
                    -- Migrate vehicle to driver's bucket if different
                    if vehicleBucket ~= playerBucket then
                        SetEntityRoutingBucket(vehicle, playerBucket)
                    end
                end
            end
        end
    end
end)
```

---

## State Bags (OneSync Data Sync)

> State bags replace event-based sync for frequently-changing entity data. Much more efficient.

### Set State

```lua
-- Set state on client (replicates to server)
local entity = Entity(PlayerPedId())
entity.state:set('myVar', value, true)  -- true = replicate to server

-- Set state on server (replicates to all clients)
Entity(GetPlayerPed(source)).state:set('myVar', value, false)  -- false = broadcast

-- Set with a filter
local NETWORK_OWNER_ONLY = 1
Entity(entity).state:set('myVar', value, NETWORK_OWNER_ONLY)

-- Set with a specific routing bucket target
local BUCKET_FILTER = { bucketId }
Entity(entity).state:set('myVar', value, BUCKET_FILTER)
```

### Get State

```lua
-- Get state (works client or server)
local value = Entity(entity).state.myVar
local value = Entity(entity).state:get('myVar')  -- Same, but safe for reserved keys

-- Check if state field exists
if Entity(entity).state.myVar ~= nil then
    -- State exists
end
```

### Listen for State Changes

```lua
-- Client: listen for state changes on entities
AddStateBagChangeHandler('myVar', nil, function(bagName, key, value, reserved, replicated)
    -- bagName = 'player:source' or 'entity:networkId'
    -- key = 'myVar'
    -- value = new value
    print(('State change: %s.%s = %s'):format(bagName, key, json.encode(value)))
end)

-- Listen for state changes on specific entity
AddStateBagChangeHandler('myVar', 'entity:12345', function(bagName, key, value)
    print('Entity 12345 myVar changed to:', value)
end)

-- Listen for ANY state change on a specific entity
AddStateBagChangeHandler(nil, 'entity:12345', function(bagName, key, value)
    print('Entity 12345 state change:', key, value)
end)
```

---

## Performance Considerations with OneSync

### DO
- Use state bags for frequently-changing data (position, health, custom states)
- Use routing buckets for isolated instances (houses, events, admin actions)
- Set `SetEntityAsNoLongerNeeded()` when spawning temporary entities
- Use `NetworkGetEntityOwner()` to check who controls an entity

### DON'T
- Spam `TriggerClientEvent` for position updates — use state bags
- Create hundreds of routing buckets — reuse them
- Use `GetGamePool('CPed')` for player iteration — use `GetPlayers()` instead
- Forget to reset routing buckets when player leaves instance

---

## Quick Reference

```lua
-- Player routing
SetPlayerRoutingBucket(source, bucket)
GetPlayerRoutingBucket(source)

-- Entity routing
SetEntityRoutingBucket(entity, bucket)
GetEntityRoutingBucket(entity)

-- State bags
Entity(entity).state:set(key, value, replicateToServer)
Entity(entity).state:get(key)
AddStateBagChangeHandler(key, bagFilter, callback)

-- Entity ownership
local ownerSrc = NetworkGetEntityOwner(entity)

-- Pool iteration (server-safe)
local vehicles = GetGamePool('CVehicle')
local peds = GetGamePool('CPed')
local objects = GetGamePool('CObject')
```
