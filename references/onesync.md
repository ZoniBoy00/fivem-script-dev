# OneSync — Entity Management, Routing Buckets & State Bags

> Verify OneSync convars and native behaviour against the current [Cfx.re documentation](https://docs.fivem.net/docs/scripting-reference/onesync/) before deployment. Server configuration and resource versions can change.

## OneSync configuration

Current supported `onesync` modes are `on`, `off`, and `legacy`. Most servers should use `on`.

```cfg
onesync on
# Default is true. Set only when you need an explicit value.
onesync_forceMigration true
```

Do not use undocumented modes or convars. Choose `sv_enforceGameBuild` separately according to the assets and game content your server supports.

## Entity lockdown and server-side creation

```cfg
set sv_entityLockdown strict   # inactive (default) | relaxed | strict
```

| Mode | Effect |
|------|--------|
| `inactive` | Clients can create any networked entity |
| `relaxed` | Entities created by client **scripts** are blocked |
| `strict` | Clients cannot create networked entities at all |

With lockdown enabled, create networked entities on the server:

```lua
-- Server
local veh = CreateVehicleServerSetter(joaat('police'), 'automobile', x, y, z, heading)
local ped = CreatePed(4, joaat('s_m_y_cop_01'), x, y, z, heading, true, true)
local obj = CreateObjectNoOffset(joaat('prop_barrier_work05'), x, y, z, true, true, false)

local timeoutAt = GetGameTimer() + 5000
while not DoesEntityExist(veh) and GetGameTimer() < timeoutAt do Wait(0) end
```

Client-only, non-networked props (`isNetwork = false`) for visuals remain allowed. Clean up server-created entities with `DeleteEntity` when the resource stops or the player leaves.

`sv_filterRequestControl` additionally restricts clients from taking control of entities other players control — see the Cfx server commands documentation for its values.

## Routing buckets

Routing buckets isolate players and entities from other buckets. Bucket `0` is the main world; it is **not** visible from every other bucket. Move a player and any relevant entities to the same bucket.

Use routing buckets for temporary, isolated game modes or sessions where full world isolation is intentional. They are not a general solution for ordinary map interiors: population ownership and game events are bucket-scoped, so use concealment or another interior approach where appropriate.

```lua
-- Server-side
local bucketId = 1001

SetPlayerRoutingBucket(source, bucketId)

-- Put a server-created entity in the same isolated session.
SetEntityRoutingBucket(vehicleEntity, bucketId)

-- Return the player to the main world on cleanup.
SetPlayerRoutingBucket(source, 0)
```

Always validate who may enter an instance, clean it up on disconnect, and reset both players and owned entities when the session ends.

## State bags

State bags are a convenient replicated key/value mechanism. They do not make client data trustworthy: validate any client-originated action on the server.

```lua
-- Client: request replication of local player state to the server.
LocalPlayer.state:set('myVar', value, true)

-- Server: replicate a player-ped state value to relevant clients.
Entity(GetPlayerPed(source)).state:set('myVar', value, true)

-- Server-only/local state: do not replicate.
Entity(GetPlayerPed(source)).state:set('internalFlag', true, false)

-- Read state through its documented property form.
local value = Entity(entity).state.myVar
```

The third argument of `state:set` is a boolean replication flag. It is not a routing-bucket, numeric, or table filter. Use routing buckets and normal server-side authorization for audience control.

Listen for updates with a handler and check that the receiving entity still exists before acting:

```lua
AddStateBagChangeHandler('myVar', nil, function(bagName, key, value, _reserved, replicated)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end           -- not streamed in on this client
    -- validate value before acting on it
end)
```

On the **server**, a handler with `replicated == true` for a player/entity bag means a client wrote it. Clients can write replicated values only to their own player and entities they own — never trust those values for money, permissions or inventory.

## Practical rules

- Keep money, permissions, inventory, cooldowns, and authoritative game state on the server.
- Prefer state bags for durable, low-frequency replicated state; never write positions or other per-frame data to state bags (OneSync already syncs entity positions).
- Keep entity ownership and bucket membership explicit when moving players or vehicles.
- Use server-side player iteration such as `GetPlayers()`; do not rely on client entity pools on the server.
- Test joins, disconnects, restarts, bucket cleanup, and late-joining players.
