# Custom & Third-Party Integrations

> Third-party export/event names below change between versions and are often closed-source. **Verify each against the vendor's current documentation** before shipping; make the choice overridable in `Config.Integrations` instead of relying only on auto-detection.

> Many FiveM servers use **paid or custom scripts** (Quasar, etc.) that replace default inventory, notification, or targeting systems. This reference shows how to detect and integrate with them so your scripts work anywhere.

---

## Detection — What's Running?

```lua
Config = Config or {}

function DetectSystems()
    local result = { inventory = nil, notify = nil, target = nil }

    -- Inventory
    if GetResourceState('ox_inventory') == 'started' then result.inventory = 'ox_inventory'
    elseif GetResourceState('qb-inventory') == 'started' then result.inventory = 'qb-inventory'
    elseif GetResourceState('qs-inventory') == 'started' then result.inventory = 'qs-inventory'
    end

    -- Notify
    if GetResourceState('ox_lib') == 'started' then result.notify = 'ox_lib'
    elseif GetResourceState('qs-notify') == 'started' then result.notify = 'qs-notify'
    elseif GetResourceState('mythic_notify') == 'started' then result.notify = 'mythic_notify'
    elseif GetResourceState('okokNotify') == 'started' then result.notify = 'okokNotify'
    elseif GetResourceState('boii_ui') == 'started' then result.notify = 'boii_ui'
    elseif GetResourceState('qb-core') == 'started' then result.notify = 'qb'
    elseif GetResourceState('es_extended') == 'started' then result.notify = 'esx'
    end

    -- Targeting
    if GetResourceState('ox_target') == 'started' then result.target = 'ox_target'
    elseif GetResourceState('qb-target') == 'started' then result.target = 'qb-target'
    elseif GetResourceState('qs-target') == 'started' then result.target = 'qs-target'
    elseif GetResourceState('bt-target') == 'started' then result.target = 'bt-target'
    end

    return result
end
```

Detect once when the file loads (start integrations before your resource in `server.cfg`), and let the server owner override it:

```lua
local Systems = DetectSystems()
for k, v in pairs(Config.Integrations or {}) do
    if v and v ~= 'auto' then Systems[k] = v end   -- e.g. Config.Integrations = { inventory = 'qs-inventory' }
end
```

## Notify Integration

```lua
function NotifyPlayer(source, type, message)
    local typeMap = { success = 'success', error = 'error', info = 'info', warning = 'warning' }

    if Systems.notify == 'ox_lib' then
        TriggerClientEvent('ox_lib:notify', source, { type = typeMap[type] or 'inform', description = message })
    elseif Systems.notify == 'qs-notify' then
        TriggerClientEvent('qs-notify:client:Notify', source, { type = typeMap[type] or 'info', text = message, length = 5000 })
    elseif Systems.notify == 'mythic_notify' then
        TriggerClientEvent('mythic_notify:client:SendAlert', source, { type = typeMap[type] or 'info', text = message, length = 5000 })
    elseif Systems.notify == 'okokNotify' then
        TriggerClientEvent('okokNotify:Alert', source, 'Server', message, 5000, typeMap[type] or 'info')
    elseif Systems.notify == 'boii_ui' then
        TriggerClientEvent('boii_ui:client:notify', source, { type = typeMap[type] or 'info', message = message, duration = 5000 })
    elseif Systems.notify == 'qb' or Systems.notify == 'qbox' then
        TriggerClientEvent('QBCore:Notify', source, message, typeMap[type] or 'info')
    elseif Systems.notify == 'esx' then
        TriggerClientEvent('esx:showNotification', source, message)
    else
        TriggerClientEvent('ox_lib:notify', source, { type = typeMap[type] or 'info', description = message })
    end
end
```

## Inventory Integration

```lua
-- Every wrapper returns true/false so callers can roll back.
function AddItem(source, item, amount, metadata)
    amount = amount or 1
    if Systems.inventory == 'ox_inventory' then
        return (exports.ox_inventory:AddItem(source, item, amount, metadata)) -- (inv, item, count, metadata, slot)
    elseif Systems.inventory == 'qb-inventory' then
        return exports['qb-inventory']:AddItem(source, item, amount, false, metadata or false, GetCurrentResourceName())
    elseif Systems.inventory == 'qs-inventory' then
        return exports['qs-inventory']:AddItem(source, item, amount, nil, metadata) and true or false -- VERIFY with vendor docs
    end
    return false
end

function RemoveItem(source, item, amount)
    amount = amount or 1
    if Systems.inventory == 'ox_inventory' then
        return (exports.ox_inventory:RemoveItem(source, item, amount))
    elseif Systems.inventory == 'qb-inventory' then
        return exports['qb-inventory']:RemoveItem(source, item, amount, false, GetCurrentResourceName())
    elseif Systems.inventory == 'qs-inventory' then
        return exports['qs-inventory']:RemoveItem(source, item, amount) and true or false -- VERIFY with vendor docs
    end
    return false
end

function HasItem(source, item, amount)
    amount = amount or 1
    if Systems.inventory == 'ox_inventory' then
        return exports.ox_inventory:GetItemCount(source, item) >= amount
    elseif Systems.inventory == 'qb-inventory' then
        return exports['qb-inventory']:HasItem(source, item, amount)
    elseif Systems.inventory == 'qs-inventory' then
        return (exports['qs-inventory']:GetItemTotalAmount(source, item) or 0) >= amount -- VERIFY with vendor docs
    end
    return false
end
```

## Common Scripts Reference

| Script | Type | Add Item | Notify |
|--------|------|----------|--------|
| **ox_inventory** | Inventory | `exports.ox_inventory:AddItem(src, item, count, metadata)` | — |
| **qb-inventory** | Inventory | `exports['qb-inventory']:AddItem(src, item, count, slot, info, reason)` | — |
| **qs-inventory** | Inventory | `exports['qs-inventory']:AddItem(src, item, count, slot, info)` (verify) | — |
| **qs-notify** | Notify | — | `TriggerClientEvent('qs-notify:client:Notify', src, {})` |
| **mythic_notify** | Notify | — | `TriggerClientEvent('mythic_notify:client:SendAlert', src, {})` |
| **okokNotify** | Notify | — | `TriggerClientEvent('okokNotify:Alert', src, title, msg, time, type)` |
| **boii_ui** | Notify | — | `TriggerClientEvent('boii_ui:client:notify', src, {})` |
| **qs-target** | Target | — | — |
| **bt-target** | Target | — | — |
