# FiveM Scripting Languages

FiveM supports **three scripting languages** for writing resource logic. The `fxmanifest.lua` is **always** written in Lua, but your actual game scripts can be in any supported language.

## Supported Languages Overview

| Language | File Extension | Runtime | Best For |
|----------|---------------|---------|----------|
| **Lua** | `.lua` | CfxLua (Lua 5.4) | Most resources, fast development, community standard |
| **JavaScript** | `.js` | V8 (Chrome's JS engine) | Developers familiar with JS/Node.js |
| **C#** | `.net.dll` | Mono (.NET Framework 4.5+) | Complex systems, OOP patterns, performance-critical code |

### fxmanifest Script Loading

The manifest file (`fxmanifest.lua`) is **always** Lua — the language is detected by the file extension:

```lua
fx_version 'cerulean'
game 'gta5'

-- Lua
client_script 'client.lua'              -- .lua → Lua runtime

-- JavaScript
client_script 'client.js'               -- .js → V8 runtime

-- C#
client_script 'MyResourceClient.net.dll' -- .net.dll → Mono runtime
```

## Lua Scripting

**Runtime:** CfxLua (Lua 5.4 as of June 2025, Lua 5.3 deprecated)

Lua is the dominant language in the FiveM ecosystem — used by ~95% of resources. The runtime is modified from standard Lua to support:
- `Citizen.CreateThread()` / `Citizen.Wait()` — cooperative threading
- Built-in `vector2()`, `vector3()`, `vector4()` — native vector support
- Direct access to all FiveM natives
- `PerformHttpRequest()` / `PerformHttpRequestAwait()` — HTTP requests
- `GetGameTimer()` — millisecond timer

### Lua 5.4 Changes (June 2025)

- Lua 5.3 is fully removed — 5.4 is the only runtime
- `lua54 'yes'` is **no longer needed and should be removed** from new manifests — it does nothing
- New features available: `const` variables, `to-be-closed` variables, generational GC
- Old resources with `lua54 'yes'` still work, but it's dead config

### Lua-Specific Functions

```lua
AddEventHandler(eventName, handler)        -- Listen for events
Citizen.CreateThread(function)             -- Spawn a thread
Citizen.Wait(milliseconds)                 -- Yield thread
Citizen.Await(promise)                     -- Await a promise
RegisterNetEvent(eventName)                -- Register networked event
TriggerServerEvent(event, ...)             -- Send to server
TriggerClientEvent(event, player, ...)     -- Send to client
TriggerEvent(event, ...)                   -- Local event
SendNUIMessage(data)                       -- Send to NUI
RegisterNUICallback(name, handler)         -- Receive from NUI
RegisterCommand(name, handler, restricted) -- Register chat command

-- Vector support
local pos = vector3(100.0, 200.0, 30.0)
local dist = #(pos1 - pos2)                -- Distance calculation

-- HTTP
PerformHttpRequest(url, callback, method, data, headers)
local result = PerformHttpRequestAwait(url, options)
```

## JavaScript Scripting

**Runtime:** V8 (Node.js 16 by default, Node.js 22 available with `node_version '22'`)

JS scripts use FiveM-specific globals that mirror Lua functionality:

```js
// fxmanifest.lua
client_script 'client.js'
// or with custom Node.js version:
node_version '22'
```

### JavaScript-Specific API

```js
// Events
on('eventName', (args) => { ... })        // Listen for event
emit('eventName', ...)                     // Trigger local event
emitNet('eventName', ...)                  // Trigger networked event

// Threading — JS uses Promises/async (no Citizen.CreateThread)
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function main() {
    while (true) {
        // do work
        await delay(100);
    }
}
main();

// Natives — called directly
const ped = PlayerPedId();
const coords = GetEntityCoords(ped);

// NUI
SendNuiMessage(JSON.stringify({ type: 'open' }));
RegisterNuiCallback('close', (data, cb) => { cb({}); });

// Commands
RegisterCommand('car', (source, args, raw) => {
    console.log('Spawning car:', args[0]);
}, false);

// Exports
exports.myResource.myFunction(args);
on('onResourceStart', (resourceName) => { ... });
```

### JS-Specific Considerations

- **No `Citizen.Wait()`** — use `await delay(ms)` with Promises
- **Native return types differ** — `GetEntityCoords()` returns `number[]`, not `vector3`
- **`global.source`** — In event handlers, use `global.source` instead of Lua's implicit `source`
- **Console** — Use `console.log()` for debugging (shows in F8 console)
- **No built-in `PlayerPedId()`** check — same as Lua, just call it directly

## C# Scripting

**Runtime:** Mono (.NET Framework 4.5+ compatibility)

C# resources have the most complex setup — requires Visual Studio project structure.

### Project Structure

```
MyResource/
├── fxmanifest.lua
├── MyResourceClient/
│   ├── Class1.cs
│   └── MyResourceClient.net.dll      ← Build output
└── MyResourceServer/
    ├── Class1.cs
    └── MyResourceServer.net.dll       ← Build output
```

### C# API

```csharp
using CitizenFX.Core;
using static CitizenFX.Core.Native.API;

public class MainScript : BaseScript
{
    public MainScript()
    {
        // Events
        EventHandlers["onClientResourceStart"] += new Action<string>(OnStart);
        
        // Commands
        RegisterCommand("car", new Action<int, List<object>, string>((source, args, raw) =>
        {
            // Handle command
        }), false);
    }
    
    private async void OnStart(string resourceName)
    {
        if (GetCurrentResourceName() != resourceName) return;
        
        // Async vehicle spawn (uses C# wrapper)
        var vehicle = await World.CreateVehicle("adder", Game.PlayerPed.Position, Game.PlayerPed.Heading);
        Game.PlayerPed.SetIntoVehicle(vehicle, VehicleSeat.Driver);
    }
}
```

### C# NuGet Packages

- **Client:** `CitizenFX.Core.Client` (NuGet)
- **Server:** `CitizenFX.Core.Server` (NuGet)

### C# Debug Symbols

For proper line numbers in error traces, embed portable PDBs:
1. Build configuration: **Debug**
2. Optimize code: **unchecked**
3. Advanced → Debug Info: **Embedded**
4. Add `.pdb` files to `files {}` in manifest

### C#-Specific Considerations

- **Mono compatibility** — Only .NET Framework APIs that Mono implements; avoid .NET Core/.NET 5+ features
- **Build output** — Always need to compile before running; `.net.dll` goes in resource folder
- **Startup** — Slower initial load than Lua/JS due to JIT compilation
- **C# Wrapper types** — `Ped`, `Vehicle`, `Player`, `World`, `Game` classes provide typed interfaces over natives
- **async/await** — Native awaits via `Citizen.Invoke` internally; use `Delay(ms)` wrapper for waits

## Language Comparison

| Feature | Lua | JavaScript | C# |
|---------|-----|-----------|-----|
| **Setup complexity** | Low (single file) | Low (single file) | High (VS project, build) |
| **Community adoption** | ~95% of resources | ~3% of resources | ~2% of resources |
| **Performance (client)** | Fast | Fast | Fast (JIT after warmup) |
| **Performance (server)** | Fast | Fast | Fastest (compiled) |
| **Threading model** | Coroutines (`Citizen.Wait`) | Promises/async | async/await |
| **Typed natives** | Dynamic | Dynamic | Strongly typed wrapper |
| **Hot reload** | Yes (`restart resource`) | Yes | Yes |
| **NUI HTML** | Call Lua functions | Same (JS in browser) | Same (JS in browser) |
| **Learning curve** | Low | Low | Medium-High |
| **File size** | Tiny (KB) | Small (KB) | Medium (MB with DLL) |

## Mixing Languages

You can mix languages within a single resource:

```lua
-- fxmanifest.lua — ALWAYS Lua
fx_version 'cerulean'
game 'gta5'

client_scripts {
    'client_main.lua',     -- Lua
    'client_ui.js',         -- JavaScript
    'MyClient.net.dll',    -- C#
}

server_scripts {
    'server_main.lua',     -- Lua
    'MyServer.net.dll',    -- C#
}
```

Communication between languages works through the same event/exports system:
- `TriggerEvent('eventName', ...)` / `on('eventName', ...)` — works across Lua ↔ JS ↔ C#
- `exports.resource:function()` — works across all runtimes
- All runtimes share the same native function table

## Links

- Lua scripting: https://docs.fivem.net/docs/scripting-manual/introduction/creating-your-first-script/
- JavaScript scripting: https://docs.fivem.net/docs/scripting-manual/introduction/creating-your-first-script-javascript/
- C# scripting: https://docs.fivem.net/docs/scripting-manual/introduction/creating-your-first-script-csharp/
- Lua functions: https://docs.fivem.net/docs/scripting-reference/runtimes/lua/
- JS runtime: https://docs.fivem.net/docs/scripting-manual/runtimes/javascript/
- C# runtime: https://docs.fivem.net/docs/scripting-manual/runtimes/csharp/
- Node.js version: https://docs.fivem.net/docs/scripting-reference/resource-manifest/#node_version
