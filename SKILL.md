---
name: fivem-script-dev
description: "FiveM (cfx.re, GTA V) resource development in Lua, JS and NUI for ESX, QBCore, QBox and the Ox ecosystem (ox_lib, ox_inventory, ox_target, oxmysql). Use when writing, reviewing or debugging FiveM scripts: fxmanifest.lua, client/server/shared Lua, net events, exports, callbacks, NUI (HTML/JS), xPlayer/QBCore Player/qbx_core APIs, inventory/target/notify integrations, state bags, OneSync, routing buckets, ACE permissions, server.cfg, anti-exploit validation and performance (resmon, Wait loops). Load only the references the task needs."
version: 2.7.0
author: ZoniBoy00
license: MIT
---

# FiveM Script Development

> **🤖 AI DIRECTIVE:** You are a FiveM expert. Follow the rules in `references/<topic>.md` and the structure of `templates/`. Never invent natives or exports — verify against https://docs.fivem.net/natives/ and the upstream resource source. Never mix framework conventions (no `QBCore.Functions.GetPlayer` in an ESX resource). Validate every client-supplied value on the server. `GetInvokingResource()` only filters resource-to-resource calls; it is not client authentication.

> **TOKEN EFFICIENCY:** Load the smallest set of references needed. Templates load only when writing scaffolds.

> **COMPATIBILITY FIRST:** Use the stack the server actually runs. Prefer Ox resources when they are installed and compatible; otherwise use the framework's own API (ESX: `esx_notify`/`esx_textui`/`esx_lib`; QBCore: `QBCore.Functions.*`, `qb-inventory`, `qb-target`). Never replace an inventory or target system without an explicit bridge decision.

---

## When to Use

- Creating a resource, fxmanifest, or project structure
- Writing or debugging client/server/shared Lua (or JS) for FiveM
- ESX (`xPlayer`), QBCore (`Player`), or QBox (`exports.qbx_core`) work
- ox_lib UI/callbacks/zones, oxmysql, ox_inventory, ox_target
- NUI interfaces (HTML/CSS/JS ↔ Lua)
- Security review, exploit hardening, or optimization
- Server console or F8 client console errors

---

## Quick Reference

### Framework Comparison

| Feature | ESX Legacy | QBCore | QBox |
|---------|-----|--------|------|
| Core resource | `es_extended` | `qb-core` | `qbx_core` |
| Core object | `@es_extended/imports.lua` (global `ESX`) | `exports['qb-core']:GetCoreObject()` | none — use `exports.qbx_core` |
| Get player (server) | `ESX.GetPlayerFromId(src)` | `QBCore.Functions.GetPlayer(src)` | `exports.qbx_core:GetPlayer(src)` |
| Add money | `xPlayer.addMoney(amount, reason)` | `Player.Functions.AddMoney('cash', amount, reason)` | `exports.qbx_core:AddMoney(src, 'cash', amount, reason)` |
| Callback C→S | `ESX.TriggerServerCallback` (or `lib.callback`) | `QBCore.Functions.TriggerCallback` (or `lib.callback`) | `lib.callback` |
| Notify (default) | `esx_notify` → `ESX.ShowNotification` / `xPlayer.showNotification` | `QBCore.Functions.Notify` | ox_lib (`exports.qbx_core:Notify`) |
| TextUI (default) | `esx_textui` → `ESX.TextUI` / `ESX.HideUI` | `exports['qb-core']:DrawText` | `lib.showTextUI` |
| Inventory (default) | es_extended items (UI: `esx_inventory`); ox_inventory via `Config.CustomInventory = 'ox'` | `qb-inventory` exports | ox_inventory |
| Targeting | ox_target or third-party | `qb-target` (ox_target optional) | ox_target |
| Shared lib | `esx_lib` (global `xLib`), ox_lib optional | ox_lib optional | ox_lib (required) |

> ox_lib UI (`lib.notify`, `lib.showTextUI`, `lib.callback`) works on every framework **when ox_lib is installed**. It does not replace the framework's inventory.

### Client vs Server

| Side | Runs on | Game natives | Use for |
|------|---------|-------------|---------|
| **Client** | Each player's game | ✅ Yes | UI, rendering, input, local entities |
| **Server** | Once on server | ❌ Server natives only | Data, auth, validation, economy, DB, networked entity creation |
| **Shared** | Both sides | ⚠️ Guard with `IsDuplicityVersion()` | Config, constants, pure helpers |

### Key Functions

| Function | Side | Purpose |
|----------|------|---------|
| `PlayerPedId()` / `cache.ped` (ox_lib) | Client | Local player ped |
| `#(a - b)` | Both | Vector distance |
| `SendNUIMessage` / `RegisterNUICallback` | Client | NUI messaging |
| `CreateThread(fn)` / `Wait(ms)` | Both | Threads (aliases of `Citizen.*`) |
| `RegisterCommand(name, fn, restricted)` | Both | Commands (`restricted = true` → ACE `command.<name>`) |
| `GetPlayers()` / `GetPlayerName(src)` | Server | Player list / name |
| `GetPlayerIdentifierByType(src, 'license')` | Server | Single identifier |
| `TriggerClientEvent(event, target, ...)` | Server | Server → client (`-1` = everyone) |
| `CreateVehicleServerSetter(model, type, x, y, z, h)` | Server | Server-owned networked vehicle (OneSync) |
| `PerformHttpRequest(url, cb, method, data, headers)` | Server | HTTP |

### Model Loading and Entity Creation

```lua
-- CLIENT: local/visual entities. Always time out model requests.
local model = joaat('adder')
if not IsModelInCdimage(model) then return end
RequestModel(model)
local timeout = GetGameTimer() + 5000
while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
if not HasModelLoaded(model) then return end
-- ox_lib alternative: lib.requestModel(model, 5000)

-- SERVER (OneSync): networked vehicles that matter to gameplay
local veh = CreateVehicleServerSetter(model, 'automobile', coords.x, coords.y, coords.z, heading)
local timeoutAt = GetGameTimer() + 5000
while not DoesEntityExist(veh) and GetGameTimer() < timeoutAt do Wait(0) end
if not DoesEntityExist(veh) then return end
SetPedIntoVehicle(GetPlayerPed(src), veh, -1)
```

---

## Method Selection Guide

```
QBCore?
├── Notify: QBCore.Functions.Notify (ox_lib only if installed)
├── Inventory: exports['qb-inventory']:AddItem/RemoveItem/HasItem
├── Target: qb-target (ox_target only if installed)
└── Callbacks: QBCore.Functions.CreateCallback / TriggerCallback

ESX?
├── Notify/TextUI/Progress: ESX.ShowNotification / ESX.TextUI / ESX.Progressbar
├── Inventory: xPlayer item methods (works with ox_inventory via Config.CustomInventory = 'ox')
├── Utilities: esx_lib (xLib) or ox_lib when installed
└── Callbacks: ESX.RegisterServerCallback / ESX.TriggerServerCallback, or lib.callback

QBox?
└── ox_lib + ox_inventory + ox_target + exports.qbx_core (defaults)

Standalone? → ox_lib + oxmysql (+ ox_inventory) → references/standalone-and-bridge.md
Unknown / paid scripts? → references/custom-integrations.md (Config-selected adapters)
```

---

## Task → Reference Map

| Task | Load |
|------|------|
| New resource, manifest, events, exports | `references/fivem-basics.md` + `templates/fxmanifest.lua` |
| Lua idioms (5.4) | `references/lua-for-fivem.md` |
| JS / C# runtimes | `references/scripting-languages.md` |
| ESX | `references/esx-framework.md` (+ `templates/esx-resource.lua`) |
| QBCore | `references/qbcore-framework.md` (+ `templates/qbcore-resource.lua`) |
| QBox | `references/qbox-framework.md` (+ `templates/qbox-resource.lua`) |
| ox_lib UI / callback / zone / command | `references/ox-lib.md` |
| SQL | `references/oxmysql.md` (+ `templates/oxmysql-queries.lua`) |
| ox_inventory / ox_target | `references/ox-inventory-target.md` (+ `templates/inventory-hooks.lua`) |
| Shops, doors, vehicles, whitelist | `references/common-patterns.md` |
| Multi-framework / standalone | `references/standalone-and-bridge.md` |
| Paid / custom integrations | `references/custom-integrations.md` |
| NUI | `references/fivem-nui.md` (+ `templates/nui/`) |
| Exploit protection | `references/fivem-security.md` |
| Admin command / ACE | `references/ace-permissions.md` (+ `templates/admin-command.lua`) |
| OneSync, entities, routing buckets, state bags | `references/onesync.md` |
| server.cfg | `references/server-cfg.md` |
| Debugging, pcall | `references/error-handling.md` |
| Performance | `references/optimization.md` |
| Fivemanage, spawnmanager, chat | `references/other-resources.md` |
| Discord logging | `templates/discord-webhook.lua` |
| Version-sensitive API | `references/documentation-and-versioning.md` |

---

## Common Pitfalls

1. **Trusting client data** — validate amounts, item names, distances, ownership and permissions on the server.
2. **Reading `source` after a yield** — `source` is a global that changes when the handler yields (`Wait`, `.await`, `lib.callback.await`, deferrals). Always start server handlers with `local src = source` and use `src`.
3. **Taking money before the action can succeed** — check capacity first, then remove money, then add the item; refund if the add fails.
4. **Accepting prices or totals from the client** — look them up server-side; never compare against a client-supplied price.
5. **Client-created networked entities** — spawn gameplay-relevant vehicles/peds server-side (`CreateVehicleServerSetter`) and set `sv_entityLockdown` (see `onesync.md`).
6. **`Wait(0)` everywhere** — use zones/points or variable sleep.
7. **Game natives in server scripts** — they error; keep them client-side.
8. **NUI callback never answered** — always call `cb(...)`.
9. **Nil player objects** — players disconnect mid-handler; check after every lookup.
10. **SQL concatenation** — always `?` placeholders.
11. **Event spam for continuous data** — use state bags for low-frequency shared state; never stream positions every frame.
12. **Editing framework core files** — use exports/events from your own resource.
13. **Unguarded optional dependencies** — check `GetResourceState(res) == 'started'` before calling optional exports.
14. **`RegisterNetEvent` inside loops/threads** — register once at file scope.
15. **`lua54 'yes'`** — no-op since June 2025 (Lua 5.4 is the only runtime); harmless in old manifests, omit in new ones.
16. **Model requests without timeout** — `while not HasModelLoaded()` without a deadline hangs on invalid models.
17. **Stale API knowledge** — framework APIs move (e.g. QBCore item functions moved to `qb-inventory` exports). Check `references/documentation-and-versioning.md`.
18. **NUI blackscreen** — see `references/fivem-nui.md` → "Blackscreen Fix".

---

## Required Generation Workflow

1. Identify framework, inventory, target, database, and OneSync assumptions.
2. Load only the required references.
3. Verify natives and third-party exports against official docs/source.
4. Keep economy, permission, distance, inventory, and state validation on the server.
5. Treat every net event, NUI callback, and client-supplied entity/net ID as untrusted.
6. Run syntax checks (`luac -p`) and give a focused test plan.
7. State assumptions and any unverified integration points.

### Security Boundary

`GetInvokingResource()` returns `nil` for net events from clients, so it cannot authenticate a client. Use it only to restrict calls from other resources; validate player, permissions, location, state, inventory, cooldown, and result on the server.

---

## Links

- FiveM docs: https://docs.fivem.net/docs/
- Natives: https://docs.fivem.net/natives/
- ESX: https://docs.esx-framework.org/
- QBCore: https://docs.qbcore.org/qbcore-documentation
- QBox: https://docs.qbox.re/
- Overextended (ox_lib, ox_inventory, ox_target, oxmysql): https://overextended.dev/
