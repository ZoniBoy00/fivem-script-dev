# Ox Inventory & Ox Target

> Two modular, performant Overextended resources for inventory management and entity interaction.

## Ox Inventory

### Setup

```lua
-- fxmanifest.lua
shared_scripts {
    '@ox_lib/init.lua',
}

-- NOT required in your manifest — ox_inventory is a dependency resource started in server.cfg
dependencies {
    'ox_inventory',
}
```

### Key Exports

```lua
-- Check item count (client-side — returns local player's count)
local count = exports.ox_inventory:Search('count', 'water')

-- Check item count with metadata (client-side)
local count = exports.ox_inventory:Search('count', 'weapon_pistol', {serial = 'ABC123'})

-- Server-side: pass source as the FIRST argument
local count = exports.ox_inventory:Search(source, 'count', 'water')

-- Add item(s)
exports.ox_inventory:AddItem(source, 'water', 5)
-- With metadata
exports.ox_inventory:AddItem(source, 'weapon_pistol', 1, {serial = 'ABC123', components = {}})

-- Remove item(s)
exports.ox_inventory:RemoveItem(source, 'water', 1)
exports.ox_inventory:RemoveItem(source, 'weapon_pistol', 1, {serial = 'ABC123'})

-- Get item count for player
local total = exports.ox_inventory:GetItemCount(source, 'water')

-- Get all inventory items
local items = exports.ox_inventory:GetInventoryItems(source)

-- Get item in specific slot
local slot = exports.ox_inventory:GetSlot(source, slotNumber)

-- Check if player has item
local hasItem = exports.ox_inventory:Search('count', 'lockpick') > 0

-- Open inventory (client)
exports.ox_inventory:openInventory('stash', {id = 'police_armory'})  -- Open a stash
exports.ox_inventory:openInventory('shop', {id = 'ammunation'})       -- Open a shop

-- Client-side weight exports
local weight = exports.ox_inventory:GetPlayerWeight()
local maxWeight = exports.ox_inventory:GetPlayerMaxWeight()
```

### Register Usable Items

```lua
-- Server-side
exports.ox_inventory:registerUsableItem('lockpick', function(source, item, metadata)
    TriggerClientEvent('myres:useLockpick', source, metadata)
end)

-- Client-side
exports.ox_inventory:registerUsableItem('lockpick', function(data)
    print('Using lockpick with metadata:', data.metadata)
end)
```

### Custom Stashes

```lua
-- Register a stash (server-side, on resource start)
exports.ox_inventory:RegisterStash('police_armory', 'Police Armory', 100, 5000)
-- Stash ID, label, max slots, max weight

-- Open stash (client-side)
exports.ox_inventory:openInventory('stash', {id = 'police_armory'})
```

### Shops

```lua
-- Register shop
exports.ox_inventory:RegisterShop('ammunation', {
    name = 'Ammu-Nation',
    inventory = {
        { name = 'pistol_ammo', price = 100, count = 50 },
        { name = 'rifle_ammo',  price = 200, count = 30 },
    },
    locations = {
        vec3(21.34, -1106.38, 29.80),
    },
    blip = { id = 110, colour = 4, scale = 0.8 },
})

-- Open shop (client)
exports.ox_inventory:openInventory('shop', {id = 'ammunation'})
```

### Item Config (`ox_inventory/data/items.lua`)

```lua
-- Every item entry:
['water'] = {
    label = 'Water',
    weight = 500,           -- weight in grams
    stack = true,           -- stackable?
    close = true,           -- close menu on use?
    description = 'A bottle of water',
    consume = 1,            -- consume on use (0 = no consume)
    client = {
        anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
        prop = { model = 'prop_ld_flow_bottle', pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
        usetime = 3,
        cancel = true,       -- can be cancelled
    },
    server = {
        export = 'myresource.useWater',  -- server-side export to call on use
    },
}
```

## Ox Target

> Interaction/targeting system. Click (or press E) on entities/zones to interact.

### Setup

```lua
-- fxmanifest.lua
dependencies {
    'ox_target',
}

-- Client
local ox_target = exports.ox_target
```

### Local Entity

```lua
-- Add target to a specific entity
exports.ox_target:addLocalEntity(entity, {
    {
        name = 'open_trunk',
        label = 'Open Trunk',
        icon = 'fa-solid fa-car',
        distance = 2.5,
        canInteract = function(entity, distance, coords, name)
            return IsPedInVehicle(PlayerPedId(), entity, false)
        end,
        onSelect = function(data)
            print('Trunk opened for entity:', data.entity)
        end,
    },
})
```

### Global Entity (by model)

```lua
-- Add target to ALL entities of a model
exports.ox_target:addModel('prop_tool_chest_01', {
    {
        name = 'loot_chest',
        label = 'Search Chest',
        icon = 'fa-solid fa-search',
        distance = 2.0,
        canInteract = function(entity, distance, coords, name)
            return distance < 2.0
        end,
        onSelect = function(data)
            TriggerServerEvent('loot:search', NetworkGetNetworkIdFromEntity(data.entity))
        end,
    },
})

-- Server: validate the loot request
RegisterNetEvent('loot:search')
AddEventHandler('loot:search', function(entityNetId)
    if GetInvokingResource() then return end
    
    local playerPed = GetPlayerPed(source)
    if not playerPed then return end
    
    local entity = NetworkGetEntityFromNetworkId(entityNetId)
    if not entity or not DoesEntityExist(entity) then return end
    
    -- Distance check
    local playerCoords = GetEntityCoords(playerPed)
    local entityCoords = GetEntityCoords(entity)
    if #(playerCoords - entityCoords) > 3.0 then return end
    
    -- ADAPT: give loot, mark searched, cooldown, etc.
end)

-- Add target to multiple models
exports.ox_target:addModel({ 'prop_tool_chest_01', 'prop_box_ammo01a' }, options)
```

### Box Zone Target

```lua
exports.ox_target:addBoxZone({
    coords = vector3(100.0, 200.0, 30.0),
    size = vector3(2.0, 2.0, 2.0),
    rotation = 0,
    debug = false,    -- show zone outline
    options = {
        {
            name = 'shop',
            label = 'Open Shop',
            icon = 'fa-solid fa-store',
            onSelect = function()
                exports.ox_inventory:openInventory('shop', {id = 'ammunation'})
            end,
        },
    },
})
```

### Sphere Zone Target

```lua
exports.ox_target:addSphereZone({
    coords = vector3(100.0, 200.0, 30.0),
    radius = 3.0,
    options = { /* same as box zone */ },
})
```

### Removing Targets

```lua
-- Remove by model
exports.ox_target:removeModel('prop_tool_chest_01')

-- Remove by local entity
exports.ox_target:removeLocalEntity(entity)

-- Remove by zone
exports.ox_target:removeZone('zone_name')

-- Remove specific option by name
exports.ox_target:removeLocalEntity(entity, { 'option_name' })
exports.ox_target:removeModel('prop_tool_chest_01', { 'loot_chest' })
```

### Global Entities Add

```lua
-- Add target to a specific entity globally (visible to all)
exports.ox_target:addGlobalEntity(entity, options)

-- Add model globally
exports.ox_target:addGlobalModel(model, options)
```

### Player Targets

```lua
-- Add target to a player
exports.ox_target:addPlayer(playerId, {
    {
        name = 'check_player',
        label = 'Check ID',
        icon = 'fa-solid fa-address-card',
        distance = 2.5,
        onSelect = function(data)
            print('Checking player', data.entity)
        end,
    },
})
```

### Bone Targets

```lua
-- Target specific bone on entity (e.g. vehicle doors)
exports.ox_target:addBone('bonnet', {
    {
        name = 'open_hood',
        label = 'Open Hood',
        icon = 'fa-solid fa-car',
        distance = 2.0,
        onSelect = function() print('Hood opened') end,
    },
})
```

## Links

- Ox Inventory: https://overextended.dev/ox_inventory
- Ox Target: https://overextended.dev/ox_target
- Overextended docs: https://overextended.dev/
