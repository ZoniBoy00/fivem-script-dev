---
name: fivem-script-dev
description: "FiveM (cfx.re) resource development. ESX, QBCore, QBox, Ox ecosystem, NUI, security, optimization. Method selection guide per framework. Custom integration wrappers for paid/third-party scripts. Load ONE reference at a time."
version: 2.3.1
author: ZoniBoy00
license: MIT
---

# FiveM Script Development

> **🤖 AI DIRECTIVE:** You are a FiveM Expert AI. When writing code, ALWAYS reference the rules in `references/<topic>.md` and use the architecture patterns found in `templates/` to ensure modern, secure, and optimized Lua. Never hallucinate natives — use https://docs.fivem.net/natives/ to verify parameter order and return types. Never mix framework conventions (e.g., don't use `QBCore.Functions.GetPlayer` in an ESX resource). Prioritize the Ox ecosystem (ox_lib, ox_inventory, oxmysql, ox_target) over custom implementations. Always validate client data server-side — the client is never trusted.

> **TOKEN EFFICIENCY:** Load ONLY `references/<topic>.md` matching the current task. Never load multiple references unless explicitly needed. Templates load only when writing scaffolds.

> **OX FIRST:** Always prefer Ox ecosystem (ox_lib, ox_inventory, oxmysql, ox_target) over custom implementations. No custom DrawText3D when `lib.showTextUI()` exists. No custom callbacks when `lib.callback` works. No custom inventory when `ox_inventory` is available. Ox is lighter, more secure, and community standard.

---

## When to Use

- User asks about FiveM resource structure, fxmanifest, or creating a new resource
- Writing or debugging Lua scripts for FiveM (client/server/shared)
- Working with ESX (`xPlayer`, `ESX.GetPlayerFromId`), QBCore (`Player`, `QBCore.Functions.GetPlayer`), or QBox
- Using Ox resources (ox_lib UI/callbacks/zones, oxmysql queries, ox_inventory, ox_target)
- Building NUI interfaces (HTML/CSS/JS ↔ FiveM messaging)
- Security review or optimization of FiveM resources
- Questions about event handling, exports, callbacks, or state bags
- Debugging server-side (server console) or client-side (F8 console) errors
- Setting up database queries (MySQL/MariaDB with oxmysql)

---

## Quick Reference

### Framework Comparison

| Feature | ESX | QBCore | QBox |
|---------|-----|--------|------|
| Core resource | `es_extended` | `qb-core` | `qbx_core` |
| Get player | `ESX.GetPlayerFromId(source)` | `QBCore.Functions.GetPlayer(source)` | `qbx:GetPlayer(source)` |
| Add money | `xPlayer.addMoney(amount)` | `Player.Functions.AddMoney('cash', amount)` | via ox_inventory |
| Callback C→S | `ESX.TriggerServerCallback` | `QBCore.Functions.TriggerCallback` | `lib.callback` |
| **Notify** | **ox_lib** (default) | **QBCore.Functions.Notify** (default) | **ox_lib** |
| **TextUI** | **ox_lib** | **QBCore.Functions.DrawText3D** (default) / ox_lib optional | **ox_lib** |
| Inventory | ESX built-in / ox_inventory | **qb-inventory** (default) / ⚠️ ox_inventory needs bridge | ox_inventory |
| Targeting | Third-party / ox_target | **qb-target** (default) / ox_target optional | ox_target |
| Status | Maintained (10k+ servers) | Maintained | Active development |

> **💡 QBCore note:** ox_lib notifications (`lib.notify`) and TextUI (`lib.showTextUI`) work fine with QBCore. But `ox_inventory` does NOT replace `qb-inventory` without a bridge resource. QBCore defaults to its own notify/DrawText3D unless you explicitly add ox_lib.

### Client vs Server

| Side | Runs on | Game Natives | Use for |
|------|---------|-------------|---------|
| **Client** | Each player's game | ✅ Yes | UI, gameplay, rendering, locals |
| **Server** | Once on server | ❌ No (server natives only) | Data, auth, validation, economy, DB |
| **Shared** | Both sides | ⚠️ Guard by env | Config, constants, helpers |

### Key Client Functions

| Function | Purpose |
|----------|---------|
| `PlayerPedId()` | Get local player ped (faster than `GetPlayerPed(-1)`) |
| `GetEntityCoords(ped)` | Get position as vector3 |
| `#(coords1 - coords2)` | Vector distance (faster than `GetDistanceBetweenCoords`) |
| `SendNUIMessage({})` | Send data to NUI HTML |
| `RegisterNuiCallback(name, fn)` | Receive data from NUI |
| `Citizen.CreateThread(fn)` | Spawn a new thread |
| `Citizen.Wait(ms)` | Yield thread for ms |
| `RegisterCommand(name, fn, restricted)` | Register a chat command |

### Key Server Functions

| Function | Purpose |
|----------|---------|
| `GetPlayerName(source)` | Get player's name |
| `GetPlayers()` | Get all connected player IDs |
| `GetPlayerIdentifiers(source)` | Get player identifiers (steam, license, etc.) |
| `TriggerClientEvent(event, source, ...)` | Trigger event on client(s) |
| `DropPlayer(source, reason)` | Kick player |
| `PerformHttpRequest(url, cb, method, data, headers)` | HTTP requests |
| `PerformHttpRequestAwait(url, options)` | Awaitable HTTP |

### Key Native Calls (client)

```lua
-- Vehicle creation
RequestModel(vehicleHash)
while not HasModelLoaded(vehicleHash) do Wait(100) end
local veh = CreateVehicle(vehicleHash, x, y, z, heading, true, false)
SetPedIntoVehicle(ped, veh, -1)    -- -1 = driver
SetEntityAsNoLongerNeeded(veh)
SetModelAsNoLongerNeeded(vehicleHash)

-- Ped creation
RequestModel(pedHash)
while not HasModelLoaded(pedHash) do Wait(100) end
local ped = CreatePed(0, pedHash, x, y, z, heading, true, false)
SetEntityAsNoLongerNeeded(ped)
SetModelAsNoLongerNeeded(pedHash)

-- Entity checks
IsPedDeadOrDying(ped)
DoesEntityExist(entity)
IsEntityDead(entity)
SetEntityCoords(entity, x, y, z)
GetEntityHeading(entity)
```

---

## Method Selection Guide

**Quick decision tree for which API to use per framework:**

```
QBCore resource?
├── YES → QBCore.Functions.Notify (notify)
│         QBCore.Functions.DrawText3D (text UI)
│         qb-inventory exports (inventory)
│         qb-target exports (targeting)
│         ox_lib CAN be used for notify/textUI if server has it
│         ⚠️ ox_inventory needs a bridge — NOT default
│
└── NO → ESX or QBox?
    ├── ESX → ox_lib notify + showTextUI
    │         ox_inventory or ESX built-in
    │         ox_target or third-party
    │
    └── QBox → ox_lib notify + showTextUI
               ox_inventory (default!)
               ox_target (default!)

Unknown / custom systems?
    → load references/custom-integrations.md
    → Use the NotifyPlayer()/AddItem() wrapper functions
    → Config.Integrations lets server owner pick
```

**TL;DR:** Ox first for ESX/QBox. QBCore's own tools for QBCore. Custom wrappers for unknown systems.

---

## Skill Structure — Load ONE reference per task

```
gaming/fivem-script-dev/
├── SKILL.md                            ← This file (quick reference + directory)
├── references/                         ← Load ONE, not all
│   ├── fivem-basics.md                 → Resource structure, events, exports
│   ├── lua-for-fivem.md                → Lua best practices
│   ├── scripting-languages.md          → Lua/JS/C# comparison
│   ├── esx-framework.md                → ESX (xPlayer, jobs, inventory)
│   ├── qbcore-framework.md             → QBCore (Player, jobs, gangs)
│   ├── qbox-framework.md               → QBox (bridge, FAQ, conversion)
│   ├── ox-lib.md                       → UI, callbacks, zones, commands
│   ├── oxmysql.md                      → Queries, transactions, placeholders
│   ├── ox-inventory-target.md          → Inventory & target exports
│   ├── ace-permissions.md              → ACE groups, identifiers, allow/deny
│   ├── common-patterns.md              → Shop, doors, vehicles, whitelist
│   ├── standalone-and-bridge.md        → Multi-framework bridge helper
│   ├── custom-integrations.md          → Quasar, paid scripts, custom inventory/notify/target
│   ├── fivem-nui.md                    → NUI HTML/JS ↔ FiveM
│   ├── fivem-security.md               → Anti-exploit, server authority
│   ├── onesync.md                      → Routing buckets, entity migration
│   ├── server-cfg.md                   → Convars, game builds, commands
│   ├── error-handling.md               → pcall, debugging, defensive code
│   ├── other-resources.md              → Fivemanage, state bags
│   └── optimization.md                 → Variable wait, caching, events
└── templates/                          ← Load ONLY when writing scaffold
    ├── fxmanifest.lua                  → Manifest template
    ├── nui/                            → NUI (html/css/js separate)
    ├── esx-resource.lua                → ESX scaffold
    ├── qbcore-resource.lua             → QBCore scaffold
    ├── qbox-resource.lua               → QBox scaffold
    ├── oxmysql-queries.lua             → DB query patterns
    ├── admin-command.lua               → ACE + rate limits
    ├── discord-webhook.lua             → Logging with embeds
    └── inventory-hooks.lua             → ox_inventory registration
```

---

## Ox First — Golden Rule

| Instead of this | Use this | Reason |
|----------------|----------|--------|
| Custom `DrawText3D()` | `lib.showTextUI()` | Lighter, built-in positioning |
| Custom notification | `lib.notify()` | Consistent UX, 6 types |
| `ESX.TriggerServerCallback` | `lib.callback` | Framework-agnostic |
| `QBCore.Functions.TriggerCallback` | `lib.callback` | Works on all frameworks |
| Custom inventory | `exports.ox_inventory` | Secure, performant, standard |
| Manual distance loops | `lib.zones.box/poly/sphere` | Event-driven, no polling |
| Custom keybinds | `lib.addKeybind()` | Built-in settings UI |

**Rule:** If Ox has a built-in for it, use Ox. Only fall back to framework/custom when Ox doesn't cover the use case.

---

## How to Use — Load ONE reference at a time

1. **General FiveM** → `references/fivem-basics.md`
2. **Lua patterns** → `references/lua-for-fivem.md`
3. **Languages** → `references/scripting-languages.md`
4. **ESX** → `references/esx-framework.md`
5. **QBCore** → `references/qbcore-framework.md`
6. **QBox** → `references/qbox-framework.md`
7. **Ox Lib** → `references/ox-lib.md`
8. **Database** → `references/oxmysql.md`
9. **Inventory/Target** → `references/ox-inventory-target.md`
10. **ACE permissions** → `references/ace-permissions.md`
11. **Common patterns** → `references/common-patterns.md`
12. **Standalone/Bridge** → `references/standalone-and-bridge.md`
13. **NUI** → `references/fivem-nui.md`
14. **Security** → `references/fivem-security.md`
15. **OneSync** → `references/onesync.md`
16. **Server.cfg** → `references/server-cfg.md`
17. **Error handling** → `references/error-handling.md`
18. **Optimization** → `references/optimization.md`
19. **Template needed** → load from `templates/`

**🔑 Token tip:** SKILL.md is ~6KB. Each reference is 5-25KB. Load ONLY the one you need. If you need a second, close the first. Never load all references.

Also: **FiveM Natives:** https://docs.fivem.net/natives/ — always check here for exact native parameters.

---

## Common Pitfalls

1. **Not validating client data server-side** — Most common exploit vector. Always validate amounts, distances, ownership on server.
2. **Overusing `Wait(0)`** — Causes unnecessary CPU. Use appropriate intervals for each check.
3. **Game natives in server scripts** — Will error. Use `shared_scripts` only for pure Lua/config.
4. **NUI callback never called back** — `cb()` must always execute (even empty `{}`) or request times out.
5. **Hardcoded values** — Coordinates, item names, prices → externalize to `config.lua`. For sensitive locations, store coordinates **server-side** and send to client only when needed.
6. **Not handling nil player object** — Always check after `GetPlayerFromId()` / `GetPlayer()`.
7. **SQL injection** — Always use `?` placeholders, never concatenate.
8. **Event spam instead of state bags** — For frequent sync, use `Entity(entity).state:set()` instead.
9. **Modifying core framework files** — Breaks on updates. Create separate resources using exports/events.
10. **Accessing core DB tables directly** — Use framework exports/API instead.
11. **Using deprecated functions/events** — They'll be removed. Check current framework docs.
12. **Oversized network payloads** — Send only what's needed.
13. **Wrong manifest language** — `fxmanifest.lua` is ALWAYS Lua; scripts can be `.lua`, `.js`, or `.net.dll`.
14. **Trusting stale resource lists** — Online framework tables (QBox resources, ESX status, etc.) are often wrong. ALWAYS verify from GitHub: check pinned repos, last commit date, and whether the repo actually exists (404 check). Many QBox resources have been archived/removed. Verify at https://github.com/Qbox-project before citing any list.

---

## Links Reference

- FiveM docs: https://docs.fivem.net/docs/
- Natives search: https://docs.fivem.net/natives/
- ESX: https://docs.esx-framework.org/
- QBCore: https://docs.qbcore.org/qbcore-documentation
- QBox: https://docs.qbox.re/
- Ox Lib: https://coxdocs.dev/ox_lib
- Overextended: https://overextended.dev/docs
- Performance guide: https://forum.cfx.re/t/best-practice-improve-your-resource-performance/105509
