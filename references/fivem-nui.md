# FiveM NUI Development

> NUI (New User Interface) — HTML/CSS/JS ↔ FiveM communication.
> Use for custom UIs that need rich design beyond what ox_lib/ESX/QBCore built-in menus offer.

## Setup

```lua
-- fxmanifest.lua
fx_version 'cerulean'          -- Required for secure context
game 'gta5'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/**/*',               -- All UI assets (CSS, JS, images)
}
```

## Client-Side Lua (Game)

### Send Data to UI

```lua
-- Send JSON message to NUI page
SendNUIMessage({
    type = 'openMenu',
    data = {
        title = 'Shop',
        items = {
            { name = 'Water',  price = 5,  icon = 'water' },
            { name = 'Bread',  price = 3,  icon = 'bread' },
            { name = 'Phone',  price = 250, icon = 'phone' },
        },
    },
})
```

### Set NUI Focus

```lua
-- Show cursor and enable keyboard input
SetNuiFocus(true, true)        -- (keyboard, mouse)
SetNuiFocusKeepInput(false)    -- Block game input while NUI has focus (default)

-- Alternative: keep some game input
SetNuiFocus(true, true)
SetNuiFocusKeepInput(true)     -- Player can still move while UI is open

-- Hide and return control to game
SetNuiFocus(false, false)
```

### Receive Data from UI

```lua
-- Register NUI callback (AJAX from UI)
RegisterNUICallback('buyItem', function(data, cb)
    -- ⚠️ data comes from the client and can be tampered with.
    -- The server must re-validate everything (item, price, quantity, money).
    local itemName = data.itemName
    local quantity = tonumber(data.quantity) or 1

    TriggerServerEvent('shop:server:purchase', itemName, quantity)

    -- Don't claim success here — the server will send its own feedback.
    cb({ received = true })
end)

-- Register callback without args
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb({})
end)
```

## Frontend (HTML/JS)

### index.html

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Shop UI</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div id="app">
        <div id="shop-ui" class="hidden">
            <div class="header">
                <h1 id="shop-title">Shop</h1>
                <button id="close-btn">✕</button>
            </div>
            <div id="items-container"></div>
        </div>
    </div>
    <script src="app.js"></script>
</body>
</html>
```

### app.js

```js
// Listen for messages from the game
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.type) {
        case 'openMenu':
            openShop(data.data);
            break;
        case 'closeMenu':
            closeShop();
            break;
        case 'updateItems':
            updateItemList(data.data);
            break;
    }
});

function openShop(shopData) {
    document.getElementById('shop-ui').classList.remove('hidden');
    document.getElementById('shop-title').textContent = shopData.title;

    const container = document.getElementById('items-container');
    container.innerHTML = '';

    shopData.items.forEach(item => {
        const div = document.createElement('div');
        div.className = 'shop-item';

        const name = document.createElement('span');
        name.className = 'item-name';
        name.textContent = item.name;

        const price = document.createElement('span');
        price.className = 'item-price';
        price.textContent = `$${item.price}`;

        const button = document.createElement('button');
        button.textContent = 'Buy';
        button.dataset.itemName = item.name;
        button.addEventListener('click', () => buyItem(button.dataset.itemName));

        div.append(name, price, button);
        container.appendChild(div);
    });
}

function buyItem(itemName) {
    // Use fetch API to call NUI callback
    fetch(`https://${GetParentResourceName()}/buyItem`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            itemName: itemName,
            quantity: 1,
        })
    })
    .then(resp => resp.json())
    .then(resp => {
        if (resp.received) {
            console.log('Purchase request sent to the server');
        }
    })
    .catch(error => console.error('Error:', error));
}

function closeShop() {
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    });
    document.getElementById('shop-ui').classList.add('hidden');
}

// Close on Escape
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeShop();
    }
});

document.getElementById('close-btn').addEventListener('click', closeShop);
```

### GetParentResourceName

```js
// Built-in FiveM function — returns the resource name of the UI page
// Usage: fetch(`https://${GetParentResourceName()}/callbackName`, ...)
```

## Key Natives

```lua
-- CLIENT-SIDE LUA:

-- Send JSON to UI
SendNUIMessage({ type = 'action', data = { ... } })

-- Set focus (show/hide cursor + keyboard)
SetNuiFocus(hasKeyboard, hasMouse)

-- Keep some game input while NUI is open
SetNuiFocusKeepInput(keepInput)

-- Register callback from UI
RegisterNUICallback('name', function(data, cb) cb({}) end)
```

## Referencing Assets

```html
<!-- Use cfx-nui- protocol (NOT nui:// — not secure context) -->
<script src="https://cfx-nui-my-resource/build/app.js"></script>
<link rel="stylesheet" href="https://cfx-nui-my-resource/css/style.css">
```

## Developer Tools

- In-game: F8 → `nui_devtools` (or `nui_devtools mpMenu` for the main menu)
- Use `console.log()` in JS for client-side debugging

## Modern Build Pipelines (Vite + TypeScript)

Plain HTML/JS (`templates/nui/`) is fine for a small panel. For anything bigger, use Vite + TypeScript: `templates/nui-vite/` is a working scaffold (vanilla TS, ~3 kB built, typed messages and callbacks, browser dev mode with mock data).

```text
myres/
├── fxmanifest.lua        ui_page 'web/build/index.html', files { 'web/build/index.html', 'web/build/**/*' }
├── client.lua            SendNUIMessage({ action, data }) + RegisterNUICallback
├── server.lua            lib.callback handlers (prices and validation live here)
└── web/
    ├── vite.config.ts    base './' (required: NUI loads via nui://), outDir 'build'
    ├── src/types.ts      Lua ↔ UI contract (NuiMessage union, NuiCallbacks map)
    ├── src/nui.ts        fetchNui<K>(), onNuiMessage(), debugMessages(), isBrowser
    └── src/main.ts       UI logic
```

Workflow:

| Command (in `web/`) | Use |
|---|---|
| `npm run dev` | Browser preview with hot reload; `debugMessages()` fakes Lua messages, `fetchNui` returns its `mock` |
| `npm run watch` | Rebuild `build/` on save; `restart myres` (or `ensure`) in-game to load it |
| `npm run build` | Type-check (`tsc --noEmit`) and production build |

Rules:

- `base: './'` is mandatory. Absolute `/assets/...` paths break inside `nui://`.
- FiveM only serves files listed in `files {}`; ship `web/build/` with the resource. Players never run npm; `node_modules` is never shipped.
- Keep the message contract in one typed file (`types.ts`) so Lua and UI can't drift silently; mirror the action names in `client.lua`.
- Type `fetchNui` per callback (see `NuiCallbacks`); the Lua side must still validate every value, because types don't exist at runtime.
- Write text with `textContent` / framework bindings, never `innerHTML` with server or player data.

### Choosing a UI framework

| Option | Bundle | Use for |
|---|---|---|
| Vanilla TypeScript (template default) | Smallest | HUDs, small menus, progress/notify-style UIs |
| Svelte / Preact | Small | Medium UIs that want components and reactivity |
| Vue / React | Larger | Big apps (MDT, phone, tablet); React matches ox_lib/ox_inventory's own UIs |

Switch framework without losing the bridge: scaffold with `npm create vite@latest web -- --template react-ts` (or `svelte-ts`, `vue-ts`, `preact-ts`), copy `src/nui.ts` and `src/types.ts` in, set `base: './'` and `build.outDir: 'build'` in `vite.config.ts`. In React, wrap `onNuiMessage` in a `useEffect`.

Avoid heavy component libraries and CDN imports for small UIs; NUI runs in the game's CEF and every kB is parsed on each resource start.

## Common Patterns

### Loading Screen
```lua
-- fxmanifest.lua
loadscreen 'html/loadscreen.html'
loadscreen_manual_shutdown 'yes'  -- Control when loading screen closes
```
```lua
-- Close loading screen when ready
ShutdownLoadingScreenNui()
```

### NUI ↔ Callback Security

```lua
-- Forward NUI input for server-side validation
RegisterNUICallback('sensitiveAction', function(data, cb)
    -- NUI data is client-controlled. Validate it in the server event.
    TriggerServerEvent('myresource:server:sensitiveAction', data)
    cb({ received = true })
end)
```

## Blackscreen Fix (CEF opaque compositing layer)

**Symptom:** NUI loads (callbacks work, logs show messages) but the screen is black — the UI is "there" but invisible. Classic FiveM/CEF issue.

**Likely cause (community-observed, not officially documented):** CEF (the Chromium wrapper FiveM uses) composites a **fallback opaque layer** behind the UI. If `html`/`body` don't have an explicit transparent background, or the CSS forces a new compositing layer (`backdrop-filter`, heavy `box-shadow`, large `border-radius`), CEF draws a solid black rounded rectangle as the fallback instead of letting the game render through.

**Fixes (apply in this order):**

1. **Explicit transparent background on html/body** — tells CEF to render the game beneath the page:
```css
html, body {
    background: transparent !important;
    margin: 0;
    padding: 0;
    height: 100%;
    overflow: hidden;
}
```

2. **Remove/replace `backdrop-filter`** — it forces an opaque compositing layer. Use a semi-transparent RGBA card color instead:
```css
/* ❌ AVOID — forces opaque fallback layer */
.card { background: rgba(0,0,0,0.4); backdrop-filter: blur(10px); }

/* ✅ USE — plain semi-transparent color, no filter */
.card { background: rgba(0, 0, 0, 0.45); }
```

3. **Reduce heavy `box-shadow` and large `border-radius`** — both can trigger new compositing layers in CEF. Prefer flat/border-based styling, or keep shadows subtle.

4. If the black rectangle persists **only around a rounded element**, it's the fallback layer showing through — flatten the radii or remove the shadow on that element.

**Verification:** after the fix, open the UI — the game world should be visible through any transparent areas. Debug with F8 → `nui_devtools` and check the Computed styles: `html`/`body` must show `background: rgba(0, 0, 0, 0)`.

## Pitfalls

1. **Must always `cb({})`** — Every NUI callback MUST return a response or the request will time out
2. **Secure context** — With `cerulean`, use `https://cfx-nui-` not `nui://`
3. **CORS** — External URLs in `ui_page` must support CORS
4. **Performance** — Don't SendNUIMessage every frame; use event-driven updates
5. **Focus stacking** — Only one NUI resource has focus at a time; the most recently focused is on top
6. **JSON only** — All data passed via SendNUIMessage/fetch must be JSON-serializable
7. **XSS via innerHTML** — Always sanitize dynamic data before inserting into DOM. Use an `escapeHtml()` helper when using `innerHTML`:
   ```js
   function escapeHtml(text) {
       const div = document.createElement('div');
       div.textContent = text;
       return div.innerHTML;
   }
   ```
   This prevents script injection if item names or descriptions come from user input or the database.

## Links

- Fullscreen NUI: https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/
- NUI Callbacks: https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/
- SendNUIMessage: https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/SendNUIMessage/
- RegisterNUICallback: https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/RegisterNUICallback/
