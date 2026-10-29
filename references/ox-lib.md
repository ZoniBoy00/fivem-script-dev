# Ox Lib — UI, Callbacks, Commands, Zones, Keybinds

> Standalone library for FiveM. Always prefer over custom NUI or legacy patterns.
> Docs: https://overextended.dev/ox_lib

## Setup

```lua
-- fxmanifest.lua
shared_scripts {
    '@ox_lib/init.lua',
}

-- Optionally preload modules (others lazy-load on first use)
ox_libs { 'locale', 'math', 'table' }
```

> Docs: https://overextended.dev/ox_lib

## Interface

### Notifications

```lua
lib.notify({
    title = 'Shop',
    description = 'Item purchased!',
    type = 'success',           -- 'inform' (default; 'info' is accepted as alias), 'success', 'error', 'warning'
    duration = 5000,            -- ms
    position = 'top-right',     -- 'top', 'top-right', 'top-left', 'bottom', 'bottom-right', 'bottom-left', 'center-right', 'center-left'
    icon = 'fa-solid fa-check', -- optional Font Awesome 6 icon
})
```

### Alert Dialog

```lua
local result = lib.alertDialog({
    header = 'Confirm Purchase',
    content = 'Are you sure you want to buy this item for $500?',
    centered = true,
    cancel = true,              -- show cancel button
})
-- result: 'confirm' or 'cancel'
```

### Input Dialog

```lua
local input = lib.inputDialog('Vehicle Shop', {
    { type = 'input',    label = 'Model',       placeholder = 'adder',    default = 'adder' },
    { type = 'number',   label = 'Price',       default = 10000,          min = 0, max = 100000 },
    { type = 'select',   label = 'Color',       options = {
        { value = 'red',   label = 'Red' },
        { value = 'blue',  label = 'Blue' },
        { value = 'black', label = 'Black' },
    }},
    { type = 'checkbox', label = 'Insured',     checked = true },
    { type = 'slider',   label = 'Quantity',    min = 1, max = 10, default = 1 },
    { type = 'date',     label = 'Purchase Date' },
    { type = 'color',    label = 'Custom Color' },
})
-- Returns table of values in order, or nil if cancelled
```

### Menu

```lua
-- Register menu
lib.registerMenu({
    id = 'vehicle_menu',
    title = 'Vehicles',
    position = 'top-left',          -- 'top-left', 'top-right', 'bottom-left', 'bottom-right'
    onClose = function(keyPressed)  -- called when menu is closed
        print('Menu closed')
    end,
    options = {
        { label = 'Buy Vehicle',  icon = 'fa-solid fa-car',       description = 'Purchase a new vehicle' },
        { label = 'Sell Vehicle', icon = 'fa-solid fa-money-bill', description = 'Sell your current vehicle' },
        { label = 'Repair',       icon = 'fa-solid fa-wrench',     description = 'Repair vehicle', disabled = true },
    },
}, function(selected, optionIndex, optionData)
    print('Selected:', selected, optionIndex)
end)

-- Show/hide
lib.showMenu('vehicle_menu')
lib.hideMenu()

-- Dynamic menu update
lib.setMenuOptions('vehicle_menu', {
    { label = 'Refuel', icon = 'fa-solid fa-gas-pump' },
})
```

### Progress Bar

```lua
local completed = lib.progressBar({
    duration = 3000,                    -- ms
    label = 'Repairing vehicle...',
    useWhileDead = false,
    canCancel = true,                   -- allow cancelling
    disable = {
        move = true, car = true, combat = true, mouse = false,
    },
    anim = {
        dict = 'mini@repair',
        clip = 'fixing_a_ped',
    },
    prop = {
        model = 'prop_tool_hammer',
        pos = vec3(0.1, 0.0, 0.0),
        rot = vec3(0.0, 0.0, 0.0),
    },
})
-- completed: true if finished, false if cancelled
```

### TextUI

```lua
-- Show floating text on screen
lib.showTextUI('[E] - Interact', {
    icon = 'fa-solid fa-hand',
    position = 'left-center',       -- 'right-center' (default), 'left-center', 'top-center', 'bottom-center'
})

-- Hide
lib.hideTextUI()
```

### Skill Check (lockpick minigame)

```lua
local success = lib.skillCheck({'easy', 'easy', 'medium'}, {'w'})
-- Arguments: difficulty array, optional keys array
-- Returns: true if all succeeded, false if failed
```

## Callbacks (Client ↔ Server)

```lua
-- Client → Server (callback style)
lib.callback('myres:server:getData', false, function(data)
    print(data)
end, arg1, arg2)
-- The second argument is a re-trigger cooldown in milliseconds (false = no cooldown)

-- Client → Server (await style — must run inside a thread/handler)
local data = lib.callback.await('myres:server:getData', false, arg1, arg2)

-- Server registration (returns data back to client)
lib.callback.register('myres:server:getData', function(source, arg1, arg2)
    return { success = true, data = 'value' }
end)

-- Server → Client callbacks
lib.callback('myres:client:doSomething', source, function(result)
    print('Client result:', result)
end)

-- Client registration (for server → client callbacks)
lib.callback.register('myres:client:doSomething', function(data)
    return { done = true }
end)
```

## Commands

```lua
lib.addCommand('givecash', {
    help = 'Give cash to a player',
    params = {
        { name = 'target', type = 'playerId', help = 'Target server ID' },
        { name = 'amount', type = 'number', help = 'Amount' },
        { name = 'note', type = 'longString', help = 'Reason', optional = true },
    },
    restricted = 'group.admin',   -- ACE principal(s); false/nil = everyone
}, function(source, args, raw)
    -- args.target is a validated, online player ID; args.amount is a number
end)
```

### Parameter Types

| Type | Description |
|------|-------------|
| `string` | Single word |
| `longString` | Rest of the input (must be the last param) |
| `number` | Numeric value |
| `playerId` | Server ID of an online player (`me` = caller) |

Parameters without `optional = true` are required; ox_lib rejects the command with a usage message when they are missing or invalid.

## Zones

### Box Zone

```lua
local zone = lib.zones.box({
    coords = vector3(100.0, 200.0, 30.0),
    size = vector3(10.0, 10.0, 5.0),
    rotation = 0,
    debug = false,           -- show zone outline (dev only)
    
    onEnter = function()
        lib.showTextUI('[E] - Open Shop')
    end,
    
    onExit = function()
        lib.hideTextUI()
    end,
    
    inside = function()      -- called every tick while inside
        if IsControlJustPressed(0, 38) then  -- E key
            -- open shop
        end
    end,
})
```

### Poly Zone

```lua
local polyZone = lib.zones.poly({
    points = {
        vector2(100.0, 200.0),
        vector2(150.0, 200.0),
        vector2(150.0, 250.0),
        vector2(100.0, 250.0),
    },
    onEnter = function() end,
    onExit = function() end,
})
```

### Sphere Zone

```lua
local sphereZone = lib.zones.sphere({
    coords = vector3(100.0, 200.0, 30.0),
    radius = 5.0,
})
```

### Zone Methods

```lua
-- Check if point is inside
local isInside = zone:contains(vector3(105.0, 205.0, 30.0))

-- Remove zone
zone:remove()

-- Set debug
zone:setDebug(true)

-- Get zone position
local pos = zone:getPosition()
```

## Keybinds

```lua
lib.addKeybind({
    name = 'openMenu',
    description = 'Open Menu',
    defaultKey = 'F5',
    onPressed = function()
        lib.showMenu('vehicle_menu')
    end,
    onReleased = function()
        lib.hideMenu()
    end,
})
```

## Shared Utilities

```lua
-- Table (lib.table extends Lua's table library)
local merged = lib.table.merge(t1, t2)            -- merge t2 into t1
local contains = lib.table.contains(t, value)     -- value (or table of values) present?
local same = lib.table.matches(t1, t2)            -- deep equality
local copy = lib.table.deepclone(t)
local doubled = lib.table.map(t, function(v) return v * 2 end)
lib.table.freeze(t)                               -- read-only

-- String
local plate = lib.string.random('AA111AAA')       -- pattern-based random string

-- Math
local clamped = lib.math.clamp(value, min, max)
local rounded = lib.math.round(1.234, 2)          -- 1.23
local pretty = lib.math.groupdigits(1234567)      -- '1,234,567'
local inRange = value >= min and value <= max     -- no lib helper; use a plain comparison
```

## Locales

Locales are JSON files in `locales/` of your resource. The language comes from the `ox:locale` convar (`setr ox:locale fi`); missing keys fall back to `en`.

`locales/en.json`:

```json
{ "item_bought": "Bought %s", "not_enough_money": "Not enough money!" }
```

```lua
-- fxmanifest.lua
ox_libs { 'locale' }
files { 'locales/*.json' }

-- any script
lib.notify({ description = locale('item_bought', 'Water') })   -- global locale(key, ...)
```

## Links

- Main docs: https://overextended.dev/ox_lib
- Interface: https://overextended.dev/ox_lib/Modules/Interface
- Callback (client): https://overextended.dev/ox_lib/Modules/Callback/Client
- Callback (server): https://overextended.dev/ox_lib/Modules/Callback/Server
- AddCommand: https://overextended.dev/ox_lib/Modules/AddCommand/Server
- Zones: https://overextended.dev/ox_lib/Modules/Zones/Shared
- AddKeybind: https://overextended.dev/ox_lib/Modules/AddKeybind/Client
