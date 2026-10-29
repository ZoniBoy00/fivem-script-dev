# FiveM Security & Anti-Exploit

## 🛡️ Core Philosophy: NEVER TRUST THE CLIENT

The client is fully compromised. Every action affecting game state, economy, or other players MUST be validated on the server.

## Golden Rules

1. **Server Authority** — The server decides; the client only requests.
2. **Never Trust Parameters** — Validate type, range and existence of every argument. Never accept prices, totals, or rewards from the client.
3. **Capture `source`** — `local src = source` first; `source` changes after any yield.
4. **Distance Checks** — Verify distance server-side before allowing interaction.
5. **Rate Limiting** — Per player, per action.
6. **`GetInvokingResource()`** — Only filters resource-to-resource calls; it does not authenticate clients.
7. **Server-Side Transactions** — Money/items change only on the server, with capacity checked before money is taken.
8. **Server-Side Entities** — Spawn gameplay entities on the server and enable `sv_entityLockdown`.

## Event Security

> Every server net event can be called by a compromised client with any arguments. Validate identity, permissions, state, distance, inventory, and cooldown on the server.

```lua
-- The client sends ONLY what it wants (item + quantity). Never a price.
ShopStock = ShopStock or {}  -- server-side runtime stock

RegisterNetEvent('shop:server:purchase', function(itemName, quantity)
    local src = source                                   -- 0. capture before any yield
    if GetInvokingResource() then return end             -- 1. blocks other resources (not clients!)

    -- 2. Validate types and ranges
    if type(itemName) ~= 'string' then return end
    quantity = math.tointeger(quantity)
    if not quantity or quantity < 1 or quantity > 10 then return end

    -- 3. Price and stock from SERVER state (Config.ShopItems keyed by item name)
    local item = Config.ShopItems[itemName]
    if not item then return end
    local stock = ShopStock[itemName] or item.stock or 0
    if stock < quantity then return end
    local totalPrice = item.price * quantity

    -- 4. Player and location
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - Config.ShopCoords) > 5.0 then return end

    -- 5. Capacity first, then money (removeMoney returns false when too poor)
    if not xPlayer.canCarryItem(itemName, quantity) then
        return xPlayer.showNotification('Inventory full!', 'error')
    end
    if not xPlayer.removeMoney(totalPrice, 'shop') then
        return xPlayer.showNotification('Not enough money!', 'error')
    end

    -- 6. Commit
    ShopStock[itemName] = stock - quantity
    xPlayer.addInventoryItem(itemName, quantity)
end)
```

## Distance Check Pattern

```lua
RegisterNetEvent('myres:server:loot', function(npcNetId)
    local src = source
    if GetInvokingResource() then return end
    if type(npcNetId) ~= 'number' then return end

    local npc = NetworkGetEntityFromNetworkId(npcNetId)
    if npc == 0 or not DoesEntityExist(npc) then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(npc)) > 5.0 then
        print(('[myres] suspicious distance request from %s'):format(src))
        return
    end

    -- ADAPT: per-entity cooldown / "already looted" state bag, then give loot server-side
end)
```

## Rate Limiting

```lua
local rateLimits = {}

local function isRateLimited(src, key, cooldownMs)
    local now = GetGameTimer()
    local limits = rateLimits[src]
    if not limits then
        limits = {}
        rateLimits[src] = limits
    end
    if limits[key] and now - limits[key] < cooldownMs then return true end
    limits[key] = now
    return false
end

RegisterNetEvent('myres:server:action', function()
    local src = source
    if GetInvokingResource() then return end
    if isRateLimited(src, 'action', 1000) then return end  -- 1s per player per action

    -- Process action
end)

AddEventHandler('playerDropped', function()
    rateLimits[source] = nil
end)
```

## Anti-Exploit Techniques

### Entity Lockdown and Server-Side Spawns

```cfg
# server.cfg (OneSync)
set sv_entityLockdown strict    # strict: no client-created entities; relaxed: blocks client *script* entities only
```

Test `strict` first on a staging server: client-side `CreateVehicle`/`CreatePed`/`CreateObject` calls with `isNetwork = true` stop working, so those resources must move spawning to the server.

```lua
-- Server: validate ownership, then spawn server-side
RegisterNetEvent('myres:server:spawnOwnedVehicle', function(plate)
    local src = source
    if GetInvokingResource() then return end
    if type(plate) ~= 'string' or #plate > 8 then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local row = MySQL.single.await('SELECT vehicle FROM owned_vehicles WHERE owner = ? AND plate = ?', { xPlayer.getIdentifier(), plate })
    if not row then return end  -- not theirs: log it (could also be a UI bug), don't instantly drop

    local props = json.decode(row.vehicle)
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local veh = CreateVehicleServerSetter(props.model, 'automobile', coords.x, coords.y, coords.z, GetEntityHeading(ped))

    local timeoutAt = GetGameTimer() + 5000
    while not DoesEntityExist(veh) and GetGameTimer() < timeoutAt do Wait(0) end
    if not DoesEntityExist(veh) then return end

    SetVehicleNumberPlateText(veh, plate)
    Entity(veh).state:set('owner', xPlayer.getIdentifier(), true)
    -- ADAPT: apply remaining props on the owning client (e.g. via a state bag handler)
end)
```

### Money Transaction Security

```lua
RegisterNetEvent('myres:server:payPlayer', function(targetId, amount)
    local src = source
    if GetInvokingResource() then return end

    amount = math.tointeger(amount)
    if not amount or amount <= 0 or amount > 100000 then return end

    targetId = math.tointeger(targetId)
    if not targetId or targetId == src then return end

    local sourcePlayer = ESX.GetPlayerFromId(src)
    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not sourcePlayer or not targetPlayer then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId))) > 5.0 then return end

    if sourcePlayer.removeMoney(amount, 'transfer') then
        targetPlayer.addMoney(amount, 'transfer')
    end
end)
```

### Resource-to-Resource Restriction

```lua
-- Server events that should only come from specific resources (TriggerEvent on the server)
AddEventHandler('myres:server:internalGrant', function(src, amount)
    local resource = GetInvokingResource()
    if resource ~= 'my_trusted_resource' then return end
    -- ...
end)
```

Use `AddEventHandler` (not `RegisterNetEvent`) for server-internal events so clients cannot trigger them at all.

## Common Exploits & Mitigations

| Exploit | Mitigation |
|---------|-----------|
| **Event spamming** | Rate limiting per player per event |
| **Item duplication** | Check return values; capacity before money; refund/rollback on failure |
| **Teleport/remote interaction** | Server-side distance checks for every interaction |
| **Money hacks** | Never accept amounts/prices from the client; compute server-side |
| **Spawned entities / props** | Server-side spawns + `sv_entityLockdown` |
| **Net ID spoofing** | Resolve net IDs server-side; check existence, ownership, distance |
| **Weapon hacks** | Give weapons only server-side via framework/inventory |
| **NUI exploits** | Validate all NUI-originated data again on the server |
| **SQL injection** | Always `?` placeholders (oxmysql) |
| **Command exploits** | ACE/framework permission checks in every handler |
| **Internal events** | `AddEventHandler` for server-only events; never `RegisterNetEvent` them |

## Server Config Security

```cfg
# server.cfg
sv_maxclients 64
sv_endpointPrivacy true              # hide player IPs from public reports
set sv_entityLockdown strict         # see above; test before enabling in production

# ACE: grant narrowly (see ace-permissions.md)
add_ace group.admin command.mycommand allow
add_principal identifier.license:xxxxxxxx group.admin

# Keep secrets server-only: `set`, never `setr`
set myresource_discord_webhook "https://discord.com/api/webhooks/..."
```

There is no server convar that reliably blocks client-side mod menus; use a dedicated anti-cheat resource for that.

## Links

- FiveM server security: https://docs.fivem.net/docs/developers/server-security/
- Server commands & convars: https://docs.fivem.net/docs/server-manual/server-commands/
