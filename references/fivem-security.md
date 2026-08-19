# FiveM Security & Anti-Exploit

## 🛡️ Core Philosophy: NEVER TRUST THE CLIENT

The client is fully compromised. Every action affecting game state, economy, or other players MUST be validated on the server.

## Golden Rules

1. **Server Authority** — Server dictates truth. Client only requests.
2. **Never Trust Parameters** — Validate ALL arguments from client (don't blindly accept amounts)
3. **Distance Checks** — Always verify distance server-side before allowing interaction
4. **Rate Limiting** — Prevent event spamming with cooldowns
5. **Event Validation** — Use `GetInvokingResource()` only for resource-to-resource calls; it does not authenticate clients
6. **Server-Side Transactions** — Never handle money/items client-side

## Event Security

> Every server network event can be called by a compromised client. `GetInvokingResource()` is not client authentication. Always validate identity, permissions, state, distance, inventory, and cooldown on the server.


```lua
RegisterNetEvent('shop:server:purchase', function(itemId, price, quantity)
    -- 1. Check invoking resource (block cross-resource triggers)
    if GetInvokingResource() then return end
    
    -- 2. Get player and validate existence
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- 3. Validate quantity from client
    quantity = tonumber(quantity) or 1
    if quantity < 1 or quantity > 10 then return end  -- Sanity limit
    
    -- 4. Validate the request from SERVER config
    local item = Config.ShopItems[itemId]
    if not item then return end                         -- Invalid item
    if price ~= item.price then return end               -- Price tampered
    if item.quantity < quantity then return end          -- Not enough stock
    
    local totalPrice = item.price * quantity
    
    -- 5. Check player has funds
    if xPlayer.getMoney() < totalPrice then
        TriggerClientEvent('esx:showNotification', source, 'Not enough money!')
        return
    end
    
    -- 6. Check inventory space
    if not xPlayer.canCarryItem(itemId, quantity) then
        TriggerClientEvent('esx:showNotification', source, 'Inventory full!')
        return
    end
    
    -- 7. Server-side execution (never trust client to do this)
    xPlayer.removeMoney(totalPrice)
    xPlayer.addInventoryItem(itemId, quantity)
end)
```

## Distance Check Pattern

```lua
RegisterNetEvent('myres:server:loot', function(npcNetId, lootType)
    if GetInvokingResource() then return end
    
    local playerPed = GetPlayerPed(source)
    if not playerPed then return end
    
    local playerCoords = GetEntityCoords(playerPed)
    local npc = NetworkGetEntityFromNetworkId(npcNetId)
    if not npc or not DoesEntityExist(npc) then return end
    
    local npcCoords = GetEntityCoords(npc)
    
    -- Server-side distance validation
    if #(playerCoords - npcCoords) > 5.0 then
        print(('[myres] suspicious distance request from %s'):format(source))
        return
        return
    end
    
    -- Process loot
end)
```

## Rate Limiting

```lua
local rateLimits = {}

RegisterNetEvent('myres:server:action', function()
    if GetInvokingResource() then return end
    
    local now = GetGameTimer()
    local playerLimits = rateLimits[source]
    
    if playerLimits then
        if now - playerLimits.lastAction < 1000 then  -- 1s cooldown
            return  -- Ignore spam
        end
    else
        rateLimits[source] = { lastAction = now }
    end
    
    rateLimits[source].lastAction = now
    -- Process action
end)

-- Clean up on disconnect
AddEventHandler('playerDropped', function()
    rateLimits[source] = nil
end)
```

## Anti-Exploit Techniques

### Vehicle/Ped Spawning Security

```lua
-- Server: validate vehicle spawn requests
RegisterNetEvent('myres:server:spawnVehicle', function(model)
    if GetInvokingResource() then return end
    
    local player = ESX.GetPlayerFromId(source)
    if not player then return end
    
    -- Check if player owns this vehicle or has permission
    local playerJob = player.getJob().name
    if playerJob ~= 'police' and playerJob ~= 'mechanic' then
        local vehicle = Config.OwnedVehicles[player.getIdentifier()]
        if not vehicle or vehicle.model ~= model then
            DropPlayer(source, 'Vehicle spawn exploit')
            return
        end
    end
    
    -- Spawn on client
    TriggerClientEvent('myres:spawnVehicleClient', source, model)
end)
```

### Money Transaction Security

```lua
-- NEVER trust client-sent amounts!
RegisterNetEvent('myres:server:payPlayer', function(targetId, amount)
    if GetInvokingResource() then return end
    
    -- Validate amount is positive number
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount > 100000 then return end
    
    local sourcePlayer = ESX.GetPlayerFromId(source)
    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not sourcePlayer or not targetPlayer then return end
    if source == targetId then return end  -- Don't pay yourself
    
    -- Optional but recommended: ensure players are near each other
    local sourceCoords = GetEntityCoords(GetPlayerPed(source))
    local targetCoords = GetEntityCoords(GetPlayerPed(targetId))
    if #(sourceCoords - targetCoords) > 5.0 then return end
    
    -- Server-side money check and transfer
    if sourcePlayer.getMoney() >= amount then
        sourcePlayer.removeMoney(amount)
        targetPlayer.addMoney(amount)
    end
end)
```

### Resource Integrity Check

```lua
-- Verify that events are triggered from the correct resource
RegisterNetEvent('sensitive:server:action', function()
    local resource = GetInvokingResource()
    
    -- Only allow from same resource or whitelisted resources
    if resource ~= GetCurrentResourceName() and resource ~= 'trusted-resource' then
        return
    end
    
    -- Process
end)
```

## Common Exploits & Mitigations

| Exploit | Mitigation |
|---------|-----------|
| **Event spamming** | Rate limiting per player per event |
| **Item duplication** | Server-side inventory validation before accepting items |
| **Teleport hacks** | Server-side distance checks for all interactions |
| **Money hacks** | Never accept money amounts from client; calculate server-side |
| **God mode** | Periodic health checks from server |
| **Weapon hacks** | Give weapons only server-side, validate before giving |
| **Menu/UI exploits** | Validate all NUI callback data server-side |
| **Vehicle spawning** | Server-side permission check before spawning |
| **SQL injection** | Always use `?` placeholders in queries |
| **Command exploits** | Permission/ACE checks in every command handler |

## Server Config Security

```lua
-- server.cfg or server config
sv_maxClients 64                     -- Reasonable limit
sv_endpointPrivacy true              -- Hide IPs

# ACE Permissions (example)
add_ace group.admin command allow    -- Admin commands
add_ace group.admin command.car deny -- Restrict specific command
add_principal identifier.steam:xxx group.admin  -- Assign by Steam ID

# Advanced protection
sv_authMinTrust 5                    -- Minimum trust level
set sv_enhancedHostSupport 1          -- Enhanced host/network support
set sv_forceGameBuild 3258            -- Force specific game build

# Note: There is no server convar that reliably blocks client-side mod menus.
# Use a dedicated anti-cheat resource if you need protection against mod menus.
```

## Links

- FiveM Security docs: https://docs.fivem.net/docs/server-manual/security/
- ACE permissions: https://docs.fivem.net/docs/server-manual/administing-with-ace-perm/
