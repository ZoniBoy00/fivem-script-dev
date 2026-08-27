# FiveM Basics — Resource Structure, Manifest, Client/Server, Events, Exports

## Resource Structure

```
my-resource/
├── fxmanifest.lua
├── client/
│   ├── main.lua
│   └── ui.lua
├── server/
│   ├── main.lua
│   └── database.lua
├── shared/
│   └── config.lua
└── html/
    └── index.html
```

**Naming rules:**
- Resources: `my_awesome_resource` (underscores, no spaces)
- Files: `player_manager.lua` (lowercase, underscores/dashes)
- Avoid: camelCase filenames, spaces, special characters

## fxmanifest.lua

```lua
fx_version 'cerulean'          -- Latest (2020-05+)
game 'gta5'                    -- 'gta5', 'rdr3', or 'common'

author 'Your Name'
description 'What this resource does'
version '1.0.0'

shared_scripts {
    'shared/config.lua',
    '@ox_lib/init.lua',        -- ox_lib dependency
}

client_scripts {
    'client/main.lua',
    'client/**/*.lua',         -- globbing: all Lua in client/ recursively
}

server_scripts {
    'server/main.lua',
    'server/database.lua',
}

ui_page 'html/index.html'
files { 'html/index.html', 'html/**/*' }

dependencies {
    'ox_lib',
    'oxmysql',
}

exports { 'getWidget', 'setWidget' }
server_export 'getServerData'

data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
```

### fxmanifest Globbing

| Pattern | Matches |
|---------|---------|
| `*.lua` | All .lua in root (non-recursive) |
| `**/*.lua` | All .lua recursively |
| `client/cl_*.lua` | cl_-prefixed files in client/ |
| `dir/*.dll` | All .dll in dir/ |

### fx_version Options

- **cerulean** (2020-05) — Latest. Secure context for NUI (https:// instead of http://)
- **bodacious** (2020-02) — Older compatibility
- **adamant** (2019-12) — Minimum for RedM, requires `game` field

## Client vs Server Scripts

| Side | Runs On | Game Natives | Can Use |
|------|---------|-------------|---------|
| **Client** | Each player's game | Yes | Peds, vehicles, world, UI, drawing, camera, audio |
| **Server** | Once on server | No (CitizenFX server natives only) | Player list, identifiers, HTTP, DB, file I/O, events |
| **Shared** | Both | No (unless guarded) | Config, constants, helper functions |

**Know which side you're on:**
```lua
if IsDuplicityVersion() then
    -- We're on the server
else
    -- We're on the client
end
```

## Events

```lua
-- Register a networked event (client OR server)
RegisterNetEvent('myresource:client:itemReceived')
AddEventHandler('myresource:client:itemReceived', function(itemId, amount)
    -- handle
end)

-- Local-only event (same side, no network registration)
AddEventHandler('myresource:client:closeMenu', function()
    -- close menu
end)
```

### Triggering Events

| Function | Direction | Example |
|----------|-----------|---------|
| `TriggerServerEvent(event, ...)` | Client → Server | `TriggerServerEvent('shop:server:buyItem', 'water', 1)` |
| `TriggerClientEvent(event, playerId, ...)` | Server → Client | `TriggerClientEvent('shop:client:notify', source, 'Done!')` |
| `TriggerEvent(event, ...)` | Local only | `TriggerEvent('myres:closeMenu')` |

- `source` on server = the player who triggered the event
- `-1` as playerId = send to all clients
- TriggerClientEvent with `-1` broadcasts to EVERYONE

### Event Naming Convention

Format: `{resourceName}:{side}:{pastTenseEventName}`

✅ Good: `shop:server:itemPurchased` (describes what happened)
✅ Good: `inventory:client:itemAdded`
❌ Bad: `shop:server:checkPurchase` (imperative — describes what should happen)
❌ Bad: `buyItem` (too generic, no namespace)

### Event Security

```lua
RegisterNetEvent('myresource:client:eventName', function()
    -- Block if triggered by another resource (nil = legitimate client net event)
    if GetInvokingResource() then return end
    
    -- Block if source isn't valid
    if not source then return end
    
    -- Handle event
end)
```

## Exports

**Defining:**
```lua
-- fxmanifest.lua
exports { 'getWidget', 'setWidget' }

-- client.lua
local widget = nil
function getWidget() return widget end
function setWidget(value) widget = value end
```

**Consuming:**
```lua
local w = exports.myresource:getWidget()
exports.myresource:setWidget(42)
```

**Server exports:**
```lua
-- fxmanifest.lua
server_export 'getServerData'

-- server.lua
function getServerData()
    return { players = GetPlayers() }
end
```

## Core Events (Server)

### playerConnecting — with deferrals
```lua
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    deferrals.defer()
    Wait(0)
    
    deferrals.update('Checking credentials...')
    
    -- Async check (DB query, HTTP, etc.)
    local banned = checkBan(source)  -- your function
    Wait(0)
    
    if banned then
        deferrals.done('You are banned from this server.')
    else
        deferrals.done()
    end
end)
```

Deferrals object:
- `deferrals.defer()` — Initialize (must wait 1 tick after)
- `deferrals.update(msg)` — Send progress message
- `deferrals.presentCard(card, cb?)` — Send Adaptive Card
- `deferrals.done(reason?)` — Finalize (nil = allow, string = kick)
- `deferrals.handover({endpoints = {...}})` — Dynamic handover

### playerDropped
```lua
AddEventHandler('playerDropped', function(reason, resourceName, clientDropReason)
    print('Player ' .. GetPlayerName(source) .. ' dropped: ' .. reason)
    -- Cleanup player data, save to DB
end)
```

### onResourceStart / onResourceStop
```lua
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    print('My resource started!')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    print('My resource stopping — clean up!')
end)
```

## Debugging

- **Server console** (TxAdmin/terminal): server-side errors and prints
- **F8 client console** (in-game): client-side Lua errors (red) and prints
- If no server error → ask for F8 logs
- `Citizen.Trace('debug message')` — print without newline
- `print('msg')` — with newline
- NUI debugging: use F8 → `nui_devTools` with `sv_devMode true`.

## Key Patterns

### Timer check (prevent exploits on client-triggered events)
```lua
local lastAction = {}
RegisterNetEvent('myres:server:action', function()
    if GetInvokingResource() then return end
    
    local now = GetGameTimer()
    if lastAction[source] and (now - lastAction[source]) < 1000 then
        return  -- Rate limit: 1 second
    end
    lastAction[source] = now
    
    -- Process action
end)
```

### Server-side distance validation
```lua
RegisterNetEvent('myres:server:interact', function(entityNetId)
    if GetInvokingResource() then return end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local entity = NetworkGetEntityFromNetworkId(entityNetId)
    local entityCoords = GetEntityCoords(entity)
    
    if #(playerCoords - entityCoords) > 5.0 then return end  -- Too far
    
    -- Process interaction
end)
```
