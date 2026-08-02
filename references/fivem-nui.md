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
SetNuiFocusKeepInput(false)    -- Allow game input when NUI is open (optional)

-- Alternative: keep some game input
SetNuiFocus(true, true)
SetNuiFocusKeepInput(true)     -- Player can still move while UI is open

-- Hide and return control to game
SetNuiFocus(false, false)
```

### Receive Data from UI

```lua
-- Register NUI callback (AJAX from UI)
RegisterNuiCallback('buyItem', function(data, cb)
    -- ⚠️ data comes from the client and can be tampered with.
    -- The server must re-validate everything (item, price, quantity, money).
    local itemName = data.itemName
    local quantity = tonumber(data.quantity) or 1
    
    TriggerServerEvent('shop:server:purchase', itemName, quantity)
    
    -- Don't claim success here — the server will send its own feedback.
    cb({ received = true })
end)

-- Register callback without args
RegisterNuiCallback('close', function(data, cb)
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
        div.innerHTML = `
            <span class="item-name">${item.name}</span>
            <span class="item-price">$${item.price}</span>
            <button onclick="buyItem('${item.name}')">Buy</button>
        `;
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
        if (resp.success) {
            console.log('Purchased:', resp.message);
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
RegisterNuiCallback('name', function(data, cb) cb({}) end)
```

## Referencing Assets

```html
<!-- Use cfx-nui- protocol (NOT nui:// — not secure context) -->
<script src="https://cfx-nui-my-resource/build/app.js"></script>
<link rel="stylesheet" href="https://cfx-nui-my-resource/css/style.css">
```

## Developer Tools

- CEF remote debugging: **http://localhost:13172/** (Chrome DevTools)
- In-game: Open F8 console → type `nui_devTools` (requires developer mode)
- Use `console.log()` in JS for client-side debugging

## Modern Build Pipelines

For complex UIs, plain HTML/CSS/JS can become hard to maintain. Many production resources use a bundler:

- **Vite / webpack** for hot reload, TypeScript, and component frameworks (React, Vue, Svelte).
- The bundled output (usually `dist/` or `build/`) is what you point `ui_page` to.
- Keep the final bundle small; NUI runs inside the game's CEF and large JS payloads can cause hitches.

Example `fxmanifest.lua` with a bundled UI:

```lua
ui_page 'dist/index.html'
files { 'dist/**/*' }
```

You still communicate with FiveM via `SendNUIMessage` and `fetch(.../callbackName)` exactly as shown above.

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
-- Validate that NUI callback is from the right source
RegisterNuiCallback('sensitiveAction', function(data, cb)
    -- Check invoking resource
    if GetInvokingResource() then
        cb({ error = 'Unauthorized' })
        return
    end
    
    -- Process
    cb({ success = true })
end)
```

## Blackscreen Fix (CEF opaque compositing layer)

**Symptom:** NUI loads (callbacks work, logs show messages) but the screen is black — the UI is "there" but invisible. Classic FiveM/CEF issue.

**Root cause:** CEF (the Chromium wrapper FiveM uses) composites a **fallback opaque layer** behind the UI. If `html`/`body` don't have an explicit transparent background, or the CSS forces a new compositing layer (`backdrop-filter`, heavy `box-shadow`, large `border-radius`), CEF draws a solid black rounded rectangle as the fallback instead of letting the game render through.

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

**Verification:** after the fix, open the UI — the game world should be visible through any transparent areas. Debug with `nui_devTools` (F8 → `nui_devTools`) and check the Computed styles: `html`/`body` must show `background: rgba(0, 0, 0, 0)`.

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
- RegisterNuiCallback: https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/RegisterNUICallback/
