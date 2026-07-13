# Lua for FiveM — Best Practices

## Variables

```lua
-- ALWAYS prefer local unless value must be global
local myVar = true
local function myFunction() end

-- Constants (convention: ALL_CAPS)
local MAX_ITEMS = 100
local DEFAULT_SPAWN = vector3(686.245, 577.950, 130.461)

-- Free memory when done
local largeData = { 1, 2, 3, 4 }
largeData = nil  -- GC can reclaim

-- Global (only when necessary — exports, RegisterCommand handlers)
MyResource = MyResource or {}
```

## Tables

```lua
-- Prefer direct index over table.insert (faster)
local t = {}
t[#t + 1] = value          -- ✅ Fast
table.insert(t, value)     -- ✅ OK, but slightly slower

-- Reuse tables — don't create new ones in loops
local template = { x = 0, y = 0, z = 0 }
for i = 1, 10 do
    template.x = i * 10
    template.y = i * 20
    -- use template
end

-- Table iteration
for k, v in pairs(t) do end       -- unordered
for i = 1, #t do end               -- array (ordered)
for i, v in ipairs(t) do end       -- array (ordered, stops at nil)

-- Avoid # on tables with nil holes — use a counter variable
```

## Functions

```lua
-- Guard clauses / early returns
local function buyItem(player, itemId, amount)
    if not player then return false, 'No player' end
    if not itemId then return false, 'No item' end
    if amount < 1 then return false, 'Invalid amount' end
    
    -- Main logic
    return true
end

-- Parameterized functions are more reusable
local function processPayment(player, amount, reason)
    -- handles any payment scenario
end

-- Local functions for encapsulation
local function validatePurchase(player, item, price)
    return player.money >= price and item.quantity > 0
end

local function executePurchase(player, item)
    player.money = player.money - item.price
    item.quantity = item.quantity - 1
end
```

## Conditionals

```lua
-- Simplified truthiness (nil AND false are both falsy in Lua)
if xPlayer then  -- instead of if xPlayer ~= nil then
    xPlayer.addMoney(100)
end

-- Simplified boolean checks
if not xPlayer then return end  -- instead of if xPlayer == nil then return end

if bool then  -- true when NOT nil AND NOT false
    print('Truthy!')
end

-- String comparison
if name == 'police' then end
if string.find(name, 'police') then end  -- partial match

-- Ternary-like pattern
local value = condition and trueValue or falseValue
```

## String Operations

```lua
-- Concatenation
local full = first .. ' ' .. last

-- Format (useful for debug)
local msg = string.format('Player %s bought %dx %s for $%d', name, qty, item, price)

-- Check prefix
if string.sub(identifier, 1, 6) == 'steam:' then end

-- Check contains
if string.find(name, 'admin') then end
```

## Error Handling

```lua
-- Assert for preconditions
assert(xPlayer, 'xPlayer is nil — player not loaded?')

-- Guard with error
if not xPlayer then
    error('Cannot process purchase: player is nil')
end

-- pcall for risky operations
local success, result = pcall(function()
    return MySQL.single.await('SELECT * FROM users WHERE id = ?', {id})
end)
if not success then
    print('DB error:', result)
end
```

## Math & Vectors

```lua
-- vector3 native support (FiveM)
local pos = vector3(100.0, 200.0, 30.0)
print(pos.x, pos.y, pos.z)

-- Distance calculation (native-accelerated, use instead of GetDistanceBetweenCoords)
local dist = #(pos1 - pos2)          -- ✅ Fast
local dist = GetDistanceBetweenCoords(p1, p2, true)  -- ❌ Slow

-- Clamp
local clamped = math.max(0, math.min(100, value))

-- Round
local rounded = math.floor(value * 100) / 100  -- 2 decimals
```

## Performance Rules

1. **Localize everything** — local variables and functions are faster than globals
2. **`PlayerPedId()` over `GetPlayerPed(-1)`** — built-in FiveM function, faster
3. **Vector distance `#()` over `GetDistanceBetweenCoords()`** — native-accelerated, single operation
4. **Cache native results** into local variables when called multiple times
5. **Don't create tables inside hot loops** — initialize once, reuse
6. **Direct index over table.insert** — `t[#t+1]` is faster
7. **Short-circuit conditions** — put cheap checks first
8. **Avoid table.remove in tight loops** — it shifts all subsequent elements

## Common Lua Pitfalls

1. **Tables are 1-indexed** — `t[1]` is first element, not `t[0]`
2. **No integer division** — `5 / 2 = 2.5`, use `math.floor(5 / 2)` for integer
3. **No continue statement** — use `if not condition then goto continue end` or wrap in `if`
4. **Global by default** — forgetting `local` makes it global (and leaks memory)
5. **`#t` counts only sequential integer keys** — stops at first nil, doesn't work on mixed tables
6. **`==` compares tables by reference** — not by content
7. **No classes** — use tables + metatables for OOP patterns
