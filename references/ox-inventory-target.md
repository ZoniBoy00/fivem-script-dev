# Ox Inventory & Ox Target

> Overextended resources for inventory management and entity interaction. Signatures verified against `overextended/ox_inventory` and `overextended/ox_target` source.

## Ox Inventory

### Setup

```lua
-- fxmanifest.lua
shared_script '@ox_lib/init.lua'
dependency 'ox_inventory'   -- started from server.cfg; you only call its exports
```

### Server Exports

`inv` is a player server ID, a stash ID, or an inventory table.

```lua
local src = source
local ox = exports.ox_inventory

-- Count / search
local count = ox:GetItemCount(src, 'water')                         -- (inv, item, metadata?, strict?)
local count2 = ox:Search(src, 'count', 'water')                      -- (inv, 'count'|'slots', item(s), metadata?)
local slots = ox:Search(src, 'slots', 'weapon_pistol', { serial = 'ABC123' })

-- Capacity before adding
if ox:CanCarryItem(src, 'water', 5) then
    -- AddItem(inv, item, count, metadata?, slot?, cb?) → success, response
    local success, response = ox:AddItem(src, 'water', 5)
    if not success then print('AddItem failed:', response) end
end

-- With metadata (4th argument — NOT the slot)
ox:AddItem(src, 'weapon_pistol', 1, { serial = 'ABC123' })

-- RemoveItem(inv, item, count, metadata?, slot?) → success, response
local removed = ox:RemoveItem(src, 'water', 1)

local items = ox:GetInventoryItems(src)
local slot = ox:GetSlot(src, 3)

-- Open an inventory for a player from the server (after your own authorization checks)
ox:forceOpenInventory(src, 'stash', 'police_armory')
```

### Client Exports

```lua
local count = exports.ox_inventory:Search('count', 'water')         -- local player only
local hasLockpick = exports.ox_inventory:GetItemCount('lockpick') > 0
local weight = exports.ox_inventory:GetPlayerWeight()
local maxWeight = exports.ox_inventory:GetPlayerMaxWeight()

exports.ox_inventory:openInventory('stash', 'police_armory')
exports.ox_inventory:openInventory('shop', { type = 'ammunation', id = 1 })
```

Client-side counts are for UI only — re-check on the server before granting anything.

### Usable Items (server)

ox_inventory has no `registerUsableItem`. Point the item at an export in `data/items.lua`:

```lua
-- ox_inventory/data/items.lua
return {
    ['lockpick'] = {
        label = 'Lockpick',
        weight = 100,
        server = { export = 'myresource.lockpick' },
    },
}
```

```lua
-- myresource/server.lua — called as (event, item, inventory, slot, data)
exports('lockpick', function(event, item, inventory, slot, data)
    if event == 'usingItem' then
        -- return false to cancel use
        return true
    elseif event == 'usedItem' then
        TriggerClientEvent('myres:client:useLockpick', inventory.id) -- inventory.id = player server ID
    end
end)
```

Client-only behaviour (animation, progress) goes in the item's `client = { ... }` block (`usetime` in ms, `anim`, `prop`, `cancel`) or `client.export`.

### Stashes

```lua
-- Server, at resource start: RegisterStash(id, label, slots, maxWeight, owner?, groups?, coords?)
exports.ox_inventory:RegisterStash('police_armory', 'Police Armory', 100, 500000, false, { police = 0 }, vec3(452.1, -980.0, 30.7))

-- Personal stash: owner = true → separate inventory per player
exports.ox_inventory:RegisterStash('personal_locker', 'Locker', 20, 20000, true)
```

With `groups` and `coords` set, ox_inventory itself rejects open requests from the wrong job or from too far away.

### Shops

```lua
-- Server: RegisterShop(shopType, data)
exports.ox_inventory:RegisterShop('ammunation', {
    name = 'Ammu-Nation',
    inventory = {
        { name = 'ammo-9', price = 5 },
        { name = 'WEAPON_PISTOL', price = 2500, license = 'weapon' },
    },
    locations = { vec3(21.34, -1106.38, 29.80) },
    groups = nil, -- or { police = 0 }
})

-- Client
exports.ox_inventory:openInventory('shop', { type = 'ammunation', id = 1 })
```

Prices and stock live on the server; the client never decides what an item costs.

### Item Config (`ox_inventory/data/items.lua`)

```lua
return {
    ['water'] = {
        label = 'Water',
        weight = 500,           -- grams
        stack = true,
        close = true,           -- close inventory on use
        consume = 1,            -- amount removed per use (0 = none)
        description = 'A bottle of water',
        client = {
            status = { thirst = 200000 },  -- applied by the framework bridge (ESX/QBox status)
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = 'prop_ld_flow_bottle', pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,      -- ms
            cancel = true,
        },
    },
}
```

## Ox Target

### Setup

```lua
-- fxmanifest.lua
dependency 'ox_target'
```

### Option Fields

| Field | Purpose |
|-------|---------|
| `name` | Unique option name (needed for removal) |
| `label`, `icon`, `distance` | Display and reach (default 7.0 — usually set ~2.0) |
| `groups` | `'police'`, `{ 'police', 'ems' }` or `{ police = 2 }` |
| `items` | Required item(s) |
| `bones` | Bone name(s) for entity/vehicle options, e.g. `{ 'door_dside_f', 'bonnet' }` |
| `canInteract(entity, distance, coords, name, bone)` | Extra client-side condition |
| `onSelect(data)` / `event` / `serverEvent` / `export` / `command` | Action |

`groups`, `items` and `canInteract` only hide options on the client. **Repeat every check on the server** in the handler that performs the action.

### Local Entity

```lua
exports.ox_target:addLocalEntity(entity, {
    {
        name = 'myres:talk',
        label = 'Talk',
        icon = 'fa-solid fa-comment',
        distance = 2.0,
        onSelect = function(data) print('Selected entity', data.entity) end,
    },
})
```

### Networked Entity

```lua
exports.ox_target:addEntity(netId, options)        -- netId or table of netIds
exports.ox_target:removeEntity(netId, 'myres:talk')
```

### By Model

```lua
exports.ox_target:addModel('prop_tool_chest_01', {
    {
        name = 'myres:loot',
        label = 'Search Chest',
        icon = 'fa-solid fa-magnifying-glass',
        distance = 2.0,
        onSelect = function(data)
            TriggerServerEvent('myres:server:loot', NetworkGetNetworkIdFromEntity(data.entity))
        end,
    },
})

exports.ox_target:addModel({ 'prop_tool_chest_01', 'prop_box_ammo01a' }, options)
```

```lua
-- Server: validate the loot request
RegisterNetEvent('myres:server:loot', function(netId)
    local src = source
    if type(netId) ~= 'number' then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(entity)) > 3.0 then return end

    -- ADAPT: cooldown per entity, mark as searched, give loot server-side
end)
```

### Global Types

```lua
exports.ox_target:addGlobalVehicle({
    {
        name = 'myres:hood',
        label = 'Open Hood',
        icon = 'fa-solid fa-car',
        bones = { 'bonnet' },
        distance = 2.0,
        onSelect = function(data) SetVehicleDoorOpen(data.entity, 4, false, false) end,
    },
})

exports.ox_target:addGlobalPlayer(options)   -- all other players
exports.ox_target:addGlobalPed(options)      -- all non-player peds
exports.ox_target:addGlobalObject(options)
exports.ox_target:addGlobalOption(options)   -- any entity type
```

### Zones

```lua
local zoneId = exports.ox_target:addBoxZone({
    name = 'myres:shop',
    coords = vec3(100.0, 200.0, 30.0),
    size = vec3(2.0, 2.0, 2.0),
    rotation = 0,
    debug = false,
    options = {
        {
            name = 'myres:openShop',
            label = 'Open Shop',
            icon = 'fa-solid fa-store',
            onSelect = function()
                exports.ox_inventory:openInventory('shop', { type = 'ammunation', id = 1 })
            end,
        },
    },
})

exports.ox_target:addSphereZone({
    coords = vec3(100.0, 200.0, 30.0),
    radius = 1.5,
    options = {
        { name = 'myres:sphere', label = 'Interact', onSelect = function() end },
    },
})
```

### Removing Targets

```lua
exports.ox_target:removeZone(zoneId)                 -- id returned by add*Zone, or the zone name
exports.ox_target:removeLocalEntity(entity, 'myres:talk')
exports.ox_target:removeModel('prop_tool_chest_01', 'myres:loot')
exports.ox_target:removeGlobalVehicle('myres:hood')
```

Remove targets in `onResourceStop` only for things you created outside ox_target's own cleanup (ox_target removes options of a stopped resource automatically).

## Links

- Ox Inventory: https://overextended.dev/ox_inventory
- Ox Target: https://overextended.dev/ox_target
