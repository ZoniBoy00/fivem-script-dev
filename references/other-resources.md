# Other Resources — Fivemanage, State Bags, Spawnmanager, Events

## Fivemanage SDK

> Screenshots, image uploads, and centralized logging.
> Docs: https://docs.fivemanage.com/fivem-sdk/installation

### Installation

1. Download the latest `fmsdk.zip` release from the [Fivemanage SDK releases](https://github.com/fivemanage/sdk/releases/latest).
2. Extract the `fmsdk` folder into your server's `resources/` directory.
3. Install `screenshot-basic` if screenshot capture is needed.
4. Start `screenshot-basic` before `fmsdk`:

```cfg
ensure screenshot-basic
ensure fmsdk
```

5. Configure the server-only convars in `server.cfg` as needed:

```cfg
set FIVEMANAGE_MEDIA_API_KEY "your_media_api_key"
set FIVEMANAGE_LOGS_API_KEY "your_logs_api_key"
```

Never commit API keys. Both convars are not required if the corresponding SDK feature is unused.

### Screenshots

```lua
-- Client: take screenshot (returns a Promise-like awaitable result)
local imageData = exports.fmsdk:takeImage({
    name = 'Player screenshot',
})
print('Screenshot saved:', imageData.url)

-- Server: take screenshot of a specific player
local imageData = exports.fmsdk:takeServerImage(source, {
    name = 'Evidence Screenshot',
    description = 'Player interaction evidence',
})
print('Server screenshot:', imageData.url)
```

### Logging

```lua
-- Log(datasetId, level, message, metadata)
exports.fmsdk:Log('default', 'info', 'Player joined', {
    playerSource = source,
})

exports.fmsdk:Info('default', 'Player joined')
exports.fmsdk:Warn('default', 'Suspicious activity')
exports.fmsdk:Error('default', 'Script error')

-- LogMessage(message, level, metadata) uses the default dataset
exports.fmsdk:LogMessage('Custom Event', 'warn', {
    type = 'admin_action',
    playerSource = source,
    action = 'ban',
    targetSource = targetId,
})
```

See the SDK's current `config.json` for automatic player, chat, and txAdmin event settings.

## State Bags

> Entity-attached key-value store shared across client/server. More efficient than event spamming for frequent sync.

### Set State

```lua
-- Server: set state and replicate to all clients
Entity(vehicle).state:set('owner', playerId, true)  -- true = replicate

-- Server: set state without replication (server-only)
Entity(vehicle).state:set('internal_data', data, false)

-- Client: set local state (not sent to server)
Entity(vehicle).state:set('local_flag', true, false)

-- Global state (not entity-specific)
GlobalState:set('server_restarting', true)
```

### Get State

```lua
-- Client or Server
local owner = Entity(vehicle).state.owner
local isOpen = Entity(vehicle).state.isOpen

-- Global state
local restarting = GlobalState.server_restarting
```

### Listen for State Changes

```lua
-- Listen for changes to a specific key on any entity
AddStateBagChangeHandler('owner', nil, function(bagName, key, value, reserved, replicated)
    print('Owner changed to:', value)
end)

-- Listen on specific entity
AddStateBagChangeHandler('isOpen', 'entity:' .. NetworkGetNetworkIdFromEntity(vehicle), function(bagName, key, value)
    if value then
        print('Vehicle opened')
    end
end)

-- Listen for global state changes
AddStateBagChangeHandler('server_restarting', 'global', function()
    print('Server restarting soon!')
end)
```

### Entity State Methods

```lua
-- Get all keys
local allKeys = Entity(vehicle).state:getKeys()

-- Remove a key
Entity(vehicle).state:remove('temporary_key', true)  -- true = replicate removal

-- Check if key exists
if Entity(vehicle).state.owner ~= nil then end
```

### Best Practices

- Use for: vehicle ownership, door states, job status, locations
- NOT for: one-shot events, instant messages (use events for those)
- State bag data persists on the entity until explicitly removed or entity deleted

## Spawnmanager (Stock Resource)

```lua
-- Set auto-spawn callback
exports.spawnmanager:setAutoSpawnCallback(function()
    exports.spawnmanager:spawnPlayer({
        x = 686.245,
        y = 577.950,
        z = 130.461,
        model = 'a_m_m_skater_01',
    }, function()
        TriggerEvent('chat:addMessage', {
            args = { 'Welcome to the server!' }
        })
    end)
end)

exports.spawnmanager:setAutoSpawn(true)
exports.spawnmanager:forceRespawn()

-- Force spawn at specific coordinates only (no auto-spawn)
exports.spawnmanager:spawnPlayer({
    x = -275.522,
    y = 6635.835,
    z = 7.425,
    heading = 180.0,
    model = 'a_m_m_skater_01',
}, function()
    print('Spawned at custom location')
end)
```

## Chat Commands (Stock Resource)

```lua
-- Register a simple command
RegisterCommand('hello', function(source, args, rawCommand)
    if source == 0 then  -- console
        print('Hello from console!')
        return
    end
    
    TriggerClientEvent('chat:addMessage', -1, {
        color = { 255, 255, 255 },
        multiline = true,
        args = { GetPlayerName(source) .. ' says hello!' }
    })
end, false)  -- false = not restricted
```

## Baseevents (Stock Resource)

```lua
-- Listen for game events (client)
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim, attacker = args[1], args[2]
        local victimDied = args[4]
        
        if attacker == PlayerPedId() and victimDied then
            print('You killed someone!')
        end
    end
end)
```

## Links

- Fivemanage: https://docs.fivemanage.com/fivem-sdk/installation
- Stock resources: https://docs.fivem.net/docs/resources/
- State bags: https://docs.fivem.net/docs/scripting-manual/networking/state-bags/
- Baseevents (list of all core events): https://docs.fivem.net/docs/scripting-reference/events/list/
