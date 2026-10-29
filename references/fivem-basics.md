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
game 'gta5'                    -- FiveM (GTA V)

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

data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
```

### fxmanifest Globbing

| Pattern | Matches |
|---------|---------|
| `*.lua` | All .lua in root (non-recursive) |
| `**/*.lua` | All .lua recursively |
| `client/cl_*.lua` | cl_-prefixed files in client/ |
| `dir/*.dll` | All .dll in dir/ |

### fx_version

Use `cerulean` (current FXv2 version; NUI runs in a secure `https://cfx-nui-<resource>/` context). Older values (`bodacious`, `adamant`) exist only for legacy resources.

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

Format: `{resourceName}:{side}:{action}` — always namespaced with the resource name.

✅ Good: `myshop:server:purchase`, `myshop:client:openMenu`
❌ Bad: `buyItem` (no namespace — collides with other resources)

### Event Security

```lua
RegisterNetEvent('myresource:server:doThing', function(arg)
    local src = source                      -- capture before any yield
    if GetInvokingResource() then return end -- only blocks other resources, NOT malicious clients

    -- Validate everything the client sent
    if type(arg) ~= 'string' or #arg > 64 then return end

    -- Handle event using src
end)
```

## Exports

**Defining (preferred — runtime `exports()`, no globals, works on client and server):**
```lua
local widget = nil
exports('getWidget', function() return widget end)
exports('setWidget', function(value) widget = value end)
```

**Consuming:**
```lua
local w = exports.myresource:getWidget()
exports.myresource:setWidget(42)
```

The legacy manifest form (`exports { ... }` / `server_export '...'` pointing at global functions) still works but is not needed for new resources.

Calling an export of a resource that is not started throws an error. Guard optional dependencies with `GetResourceState('name') == 'started'`.

## Core Events (Server)

### playerConnecting — with deferrals
```lua
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source  -- MUST be captured before deferrals.defer()/Wait(); `source` changes after a yield
    deferrals.defer()
    Wait(0)

    deferrals.update('Checking credentials...')

    -- Async check (DB query, HTTP, etc.)
    local license = GetPlayerIdentifierByType(src, 'license')
    local banned = checkBan(license)  -- your function
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
- `deferrals.handover(data)` — Attach handover data for the connecting client (see the Cfx deferrals docs)

> The server ID during `playerConnecting` is **temporary**. Do not key long-lived player tables by it; use `playerJoining` (source = final ID) or the framework's "player loaded" event.

### playerDropped
```lua
AddEventHandler('playerDropped', function(reason, resourceName, clientDropReason)
    local src = source
    print(('Player %s dropped: %s'):format(GetPlayerName(src), reason))
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
- NUI debugging: F8 → `nui_devtools` (opens CEF DevTools; use `nui_devtools mpMenu` for the main menu).
- Per-resource CPU/memory: F8 → `resmon 1`.

## Key Patterns

### Timer check (prevent exploits on client-triggered events)
```lua
local lastAction = {}
RegisterNetEvent('myres:server:action', function()
    local src = source
    if GetInvokingResource() then return end

    local now = GetGameTimer()
    if lastAction[src] and (now - lastAction[src]) < 1000 then
        return  -- Rate limit: 1 second
    end
    lastAction[src] = now

    -- Process action
end)

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)
```

### Server-side distance validation
```lua
RegisterNetEvent('myres:server:interact', function(entityNetId)
    local src = source
    if GetInvokingResource() then return end
    if type(entityNetId) ~= 'number' then return end

    local entity = NetworkGetEntityFromNetworkId(entityNetId)
    if entity == 0 or not DoesEntityExist(entity) then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    if #(playerCoords - GetEntityCoords(entity)) > 5.0 then return end  -- Too far
    
    -- Process interaction
end)
```
