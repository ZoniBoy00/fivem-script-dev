# FiveM Error Handling & Debugging

> Defensive coding, error recovery, and debugging techniques for FiveM scripts.

## Core Principles

1. **Never assume it works** — Check return values, nil guards, type checks
2. **Log everything in dev** — Strip logs for production, but keep critical errors
3. **pcall everything fallible** — DB queries, HTTP requests, network operations
4. **Protect the event chain** — One error shouldn't crash the resource

---

## pcall / xpcall Patterns

### Basic pcall

```lua
local success, result = pcall(function()
    -- Risky operation
    local data = MySQL.query.await('SELECT * FROM users WHERE identifier = ?', {identifier})
    return data
end)

if not success then
    print('[ERROR] Query failed:', result)  -- result = error message
    return
end

-- result is now the query data
```

### With xpcall for stack traces

```lua
local function errorHandler(err)
    return debug.traceback(err)
end

local success, result = xpcall(function()
    -- Code that might error
    local veh = CreateVehicle(model, x, y, z, h, true, false)
    assert(DoesEntityExist(veh), 'Vehicle creation failed')
end, errorHandler)

if not success then
    print('[CRITICAL] Stack trace:', result)
end
```

### pcall in Event Handlers

Always wrap event handler bodies to prevent one bad event from crashing the resource:

```lua
RegisterNetEvent('myres:server:doThing', function(...)
    if GetInvokingResource() then return end
    
    local success, err = pcall(function()
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end
        
        -- Actual logic
        xPlayer.addMoney(100)
    end)
    
    if not success then
        print(('[%s] Error in myres:server:doThing: %s'):format(GetCurrentResourceName(), err))
    end
end)
```

---

## nil Guards

### Player Objects

```lua
-- ALWAYS check after GetPlayerFromId
local xPlayer = ESX.GetPlayerFromId(source)
if not xPlayer then
    print('[WARNING] Player not found:', source)
    return
end

-- QB equivalent
local Player = QBCore.Functions.GetPlayer(source)
if not Player then return end
```

### Config Values

```lua
local price = Config.Items[itemName] and Config.Items[itemName].price
if not price then return end  -- Item doesn't exist

-- Or use a safe getter
function Config.GetItem(name)
    return Config.Items[name] or nil
end

local item = Config.GetItem(itemName)
if not item then
    lib.notify({ type = 'error', description = 'Invalid item' })
    return
end
```

### Entity Checks

```lua
local ped = PlayerPedId()
local vehicle = GetVehiclePedIsIn(ped, false)

if not DoesEntityExist(vehicle) then
    lib.notify({ type = 'error', description = 'You are not in a vehicle' })
    return
end

-- Vehicle exists — safe to proceed
```

---

## Type Checking

```lua
-- Validate function arguments
function BuyItem(source, itemName, amount)
    if type(source) ~= 'number' then
        print('[ERROR] Invalid source type:', type(source))
        return false
    end
    if type(itemName) ~= 'string' then
        return false
    end
    amount = tonumber(amount) or 1
    if amount < 1 or amount > 100 then
        return false
    end
    -- Proceed safely
end
```

---

## Safe Export Calls

Calling exports from other resources can crash your resource if the target isn't started. Always guard them:

```lua
local function safeExport(resource, exportName, ...)
    if GetResourceState(resource) ~= 'started' then
        print(('[ERROR] Resource %s is not started'):format(resource))
        return nil
    end
    
    local ok, result = pcall(exports[resource][exportName], exports[resource], ...)
    if not ok then
        print(('[ERROR] Export %s:%s failed: %s'):format(resource, exportName, tostring(result)))
        return nil
    end
    
    return result
end

-- Example
local count = safeExport('ox_inventory', 'Search', source, 'count', 'water')
```

---

## Debugging Techniques

### F8 Console (Client)

```lua
-- Print to F8 console (visible to that player only)
print('[^2INFO^7] Debug message')  -- ^2 = green, ^7 = reset
print(('^3WARNING^7: Player at %s is too far'):format(coords))

-- Dump table contents
for k, v in pairs(someTable) do
    print(('  %s = %s'):format(tostring(k), tostring(v)))
end
```

### Server Console

```lua
-- Print to server console
print(('[^1CRITICAL^7] Error in resource: %s'):format(message))

-- Structured logging
local function Log(level, resource, message, data)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local dataStr = data and json.encode(data) or '{}'
    print(('[%s] [%s] [%s] %s | %s'):format(timestamp, level, resource, message, dataStr))
end

Log('INFO', 'myres', 'Player joined', { source = src, name = name })
Log('ERROR', 'myres', 'Database timeout', { query = query })
```

### F8 Commands for Debugging

```lua
-- Register debug command (only for devs)
RegisterCommand('debug_coords', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    print(('Coords: vector3(%.2f, %.2f, %.2f) Heading: %.2f'):format(coords.x, coords.y, coords.z, heading))
end, false)  -- false = not restricted (client-side only anyway)
```

---

## Common Error Patterns

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `attempt to index a nil value (field '?')` | Player object nil | Check `GetPlayerFromId` return |
| `stack overflow` | Infinite recursion | Check your loop/recursion logic |
| `bad argument #1 to '?' (expected string, got nil)` | Missing config value | Add nil guard before use |
| `Server script tried to call a game native!` | Native in server script | Split client/server logic |
| `JSON decoding error` | Invalid NUI message | Validate JSON in JS before sending |
| `Query execution failure: Table '...' doesn't exist` | Wrong database/table | Check DB name, table name in query |

---

## Best Practices Summary

1. **Wrap ALL event handlers** in pcall to prevent cascading failures
2. **Never chain callbacks** without error checking between each
3. **Log with context** — include source, function name, and relevant values
4. **Strip debug prints** for production or use a config toggle
5. **Use assert() for critical preconditions** — vehicle creation, model loading
6. **Always provide a timeout** on HTTP requests and DB queries
7. **Don't suppress errors silently** — even if you handle it, log it
