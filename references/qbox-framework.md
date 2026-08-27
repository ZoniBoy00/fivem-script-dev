# QBox Framework Development

> QBox started as a QBCore fork (Sep 2022) and now relies on Overextended resources. Maintains backwards compatibility with most QBCore scripts while providing a modern, optimized foundation.

## Core Concepts

QBox's goal is improving upon QBCore while maintaining backwards compatibility. It utilizes [Overextended resources](https://github.com/overextended) (ox_lib, ox_inventory, ox_target, oxmysql) instead of maintaining in-house alternatives.

> **⚠️ API Stability:** QBox is under active development and its APIs (especially module wiring, bridge layers, lifecycle events, and item config locations) can change between releases. Always verify the current docs at https://docs.qbox.re/ before relying on any specific pattern.

### Key Differences from QBCore

| Feature | QBCore | QBox |
|---------|--------|------|
| Core resource | `qb-core` | `qbx_core` |
| Player retrieval | `QBCore.Functions.GetPlayer(source)` | `exports.qbx_core:GetPlayer(source)` |
| Module system | Global exports (`QBCore.Shared`) | qbx_core modules + exports |
| UI library | qb-menu / qb-input | ox_lib (default) |
| Inventory | qb-inventory | ox_inventory (default) |
| Targeting | qb-target | ox_target (default) |
| Notifications | `QBCore.Functions.Notify()` | ox_lib notifications |
| Progress bar | qb-progress | ox_lib progressBar |
| Multicharacter | qb-multicharacter | Built into qbx_core |
| Items config | qb-core/shared/items.lua | ox_inventory/data/items.lua |
| Code quality | Community-driven | Strict standards + active contributors |

## QBCore Compatibility

**TL;DR: Yes, most QBCore scripts work with Qbox.**

Qbox provides a **bridge layer** for backwards compatibility with documented QBCore APIs:

```lua
-- This STILL works on Qbox:
local QBCore = exports['qb-core']:GetCoreObject()  -- Bridge layer handles it
local Player = QBCore.Functions.GetPlayer(source)
```

**Exceptions** — scripts that use QBCore in **undocumented/unsupported** ways will break:
- Direct access to database tables
- Direct access to `qb-core` internal files
- Invalid usage of existing functions
- Other unexpected/improper usage patterns

### Converting QBCore Resources

"Converting resources only helps to improve readability and reduce memory footprint" — Qbox team.

```lua
-- Old QBCore style (works via bridge)
local QBCore = exports['qb-core']:GetCoreObject()
local Player = QBCore.Functions.GetPlayer(source)
Player.Functions.AddMoney('cash', 100)
QBCore.Functions.Notify(source, 'Money added!')

-- New QBox style (recommended)
local player = exports.qbx_core:GetPlayer(source)
player.Functions.AddMoney('cash', 100)
TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = 'Money added!' })
```

## Developer's Golden Rules

1. **Do NOT access core database tables** — use exports. If data isn't available via export, create a GitHub issue.
2. **Do NOT modify core `qbx_core` code** — it breaks on updates. File a GitHub issue for new features.
3. **Do NOT use deprecated functions/events** — they'll be removed without warning.
4. **Set vehicleid statebag** when spawning owned vehicles: `Entity(veh).state:set('vehicleid', id, true)`
5. **Pass properties to spawnVehicle** — don't manually set properties after spawn (this is an anti-pattern)
6. **Don't rely on unreleased/unversioned resources** — they can change without notice

## Framework Initialization

```lua
-- CLIENT
-- In fxmanifest.lua, add:
-- shared_scripts {
--   '@qbx_core/modules/lib.lua',
--   '@qbx_core/modules/playerdata.lua',
-- }
-- qbx is then supplied by the documented client module.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    print('Player fully loaded')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    print('Player logged out')
end)

-- QBox also emits 'qbx_core:client:playerLoggedOut' after player cleanup.

-- SERVER
local player = exports.qbx_core:GetPlayer(source)
if not player then return end
```

## QBox API

### Player Methods

```lua
-- Server
local player = exports.qbx_core:GetPlayer(source)
if not player then return end

-- Money management
player.Functions.AddMoney('cash', amount)
player.Functions.RemoveMoney('cash', amount)
player.Functions.AddMoney('bank', amount)
player.Functions.RemoveMoney('bank', amount)

-- Player data access
player.PlayerData.job.name           -- 'police'
player.PlayerData.job.grade          -- 0-12
player.PlayerData.charinfo.firstname
player.PlayerData.charinfo.lastname
player.PlayerData.charinfo.phone
player.PlayerData.metadata
```

### Inventory (ox_inventory)

Since QBox uses ox_inventory by default, use its exports:

```lua
-- Check item count
local count = exports.ox_inventory:Search('count', 'water')

-- Add/remove items
exports.ox_inventory:AddItem(source, 'water', 5)
exports.ox_inventory:RemoveItem(source, 'water', 1)

-- Get all items
local items = exports.ox_inventory:GetInventoryItems(source)

-- Usable items: use the item server export configured in ox_inventory,
-- or the documented QBox CreateUseableItem export when using a QBCore bridge.
-- Verify the current signature in QBox/ox_inventory docs before implementation.
```

### Items — Dual Config

With QBox, configure the item in the inventory first. Add the QBox shared-item definition only when a QB bridge consumer specifically needs it:

1. **`ox_inventory/data/items.lua`** — Primary inventory definition, including client/server behaviour.
2. **`qbx_core/shared/items.lua`** — Optional compatibility definition for resources using the QB bridge; do not duplicate it by default.

```lua
-- qbx_core/shared/items.lua (bridge compatibility)
['water'] = {
    label = 'Water',
    weight = 500,
    stack = true,
    description = 'A bottle of fresh water',
}

-- ox_inventory/data/items.lua (full configuration)
['water'] = {
    label = 'Water',
    weight = 500,
    stack = true,
    close = true,
    description = 'A bottle of fresh water',
    client = {
        anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
        prop = { model = 'prop_ld_flow_bottle', pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
        usetime = 3,
        cancel = true,
    },
    server = {
        export = 'myresource.useWater',
    },
}
```

### Targeting (ox_target)

```lua
-- Target entity
exports.ox_target:addLocalEntity(entity, {
    {
        name = 'interact',
        label = 'Interact',
        icon = 'fa-solid fa-hand',
        distance = 2.5,
        onSelect = function() print('Interacted!') end,
    },
})
```

## Common QBox Issues & Solutions

### "No such export GetCoreObject in resource qbx_core"

Qbox does not have a core object. Use `exports['qb-core']:GetCoreObject()` — the bridge layer handles it.

### "[WARN] This resource is still using the deprecated qbx_core utils!"

Download the latest release/commit for that resource. Archived resources may need manual updating.

### Custom multicharacter

In `qbx_core/config/client.lua`:
```lua
useExternalCharacters = false,  -- Set to true if using external char management
```

If stuck on loading screen: Make sure your multicharacter resource calls `ShutdownLoadingScreen()` and `ShutdownLoadingScreenNui()` natives.

### Custom notification system

Modify `ox_lib` to pass the event to your notification system.

### Vehicle models starting with a number

Enclose in square brackets:
```lua
['5vigero'] = { label = '5Vigero', ... }
```

### Keybind changes not working

Clear binds manually — changes don't apply retroactively to connected clients.

### SCRIPT ERROR: failed to load model

Adjust timeout in `qbx_core/config/client.lua`:
```lua
loadingModelsTimeout = 10000,  -- Increase from default
```

### Foreign key constraint errors

Add charset to table creation:
```sql
DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

## QBox vs QBCore — Should You Migrate?

**QBox is recommended for:**
- New servers starting fresh
- Servers wanting modern Ox ecosystem
- Developers who want cleaner code standards

**Stick with QBCore if:**
- You have many custom resources that use undocumented QBCore internals
- Your resource dependencies only support QBCore
- You don't want to deal with dual item configs

## QBox Resources

> **⚠️ Always verify resource lists against the actual GitHub org https://github.com/Qbox-project.** Many old resource lists are inaccurate — Qbox has archived or removed several resources.

### ✅ Active & Maintained

| Resource | Purpose | Status | Last Updated |
|----------|---------|--------|-------------|
| **qbx_core** | Core framework | ✅ Stable | Active (131★, 261 forks) |
| **qbx_vehicles** | Vehicle management API | ✅ Stable | v1.4.2 (Dec 2024) |
| **qbx_garages** | Garage/storage (uses ox_inventory) | ✅ Stable | v1.1.4, 371 commits |
| **qbx_spawn** | Spawn selection | ✅ Active | 35 forks |
| **qbx_vehicleshop** | Vehicle dealerships | ✅ Active | 52 forks |
| **qbx_storerobbery** | Store robbery system | ✅ Active | 21 forks |
| **qbx_vehiclesales** | Player-to-player vehicle sales | ✅ Active | 16 forks |
| **qbx_weed** | Weed growing | ✅ Active | 20 forks |

### ❌ Archived / Unmaintained / Removed

| Resource | Truth |
|----------|-------|
| **qbx_doors** | ❌ **Removed (404)** — no longer exists on GitHub |
| **qbx_housing** | ❌ **Never existed.** `qbx_houses` is archived (unmaintained), `qbx_apartments` also archived |
| **qbx_phone** | ❌ **Archived December 2023** — no longer maintained |
| **qbx_stashes** | ❌ **Removed (404)** — no longer exists on GitHub |
| **qbx_multicharacter** | ❌ **Unmaintained** — multicharacter is **built directly into qbx_core**, no separate resource needed |
| **qbx_houses** | ⚠️ Archived, unmaintained |
| **qbx_apartments** | ⚠️ Archived, unmaintained |
| **qbx_traphouse** | ⚠️ Archived, not maintained |
| **qbx_prison** | ⚠️ Archived, not maintained |
| **qbx_vehiclefailure** | ⚠️ Archived, not maintained |
| **qbx_tunerchip** | ⚠️ Archived, not maintained |
| **qbx_lockpick** | ⚠️ Archived, not maintained |

> **💡 Rule of thumb:** If a resource isn't in the pinned repos or the README hasn't been updated in the last year, skip it. Qbox now focuses on qbx_core and the Overextended ecosystem — many old qbx_ resources have been replaced by direct ox libraries.

## Links

- Full docs: https://docs.qbox.re/
- Developer's Guide: https://docs.qbox.re/developers
- FAQ: https://docs.qbox.re/faq
- Converting from QBCore: https://docs.qbox.re/converting
- QBox Discord: https://discord.gg/qbox
- GitHub org: https://github.com/Qbox-project
- qbx_core source: https://github.com/Qbox-project/qbx_core
