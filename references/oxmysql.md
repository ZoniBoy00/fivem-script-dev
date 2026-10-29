# OxMySQL — Database Queries

> All database access goes through **oxmysql** (the `MySQL.*` global it provides via `@oxmysql/lib/MySQL.lua`). Don't use other MySQL libraries or raw drivers in resources.
> Server-side only. `.await` variants must run inside a thread or event handler (not at file top level).
> Docs: https://overextended.dev/oxmysql

## Setup

```lua
-- fxmanifest.lua
server_script '@oxmysql/lib/MySQL.lua'  -- Must be ABOVE other server scripts
```

## Query Functions

### MySQL.query — SELECT (returns array of rows)

```lua
MySQL.query('SELECT * FROM users WHERE identifier = ?', {identifier}, function(rows)
    if rows[1] then
        print('Found user:', rows[1].name, rows[1].money)
    end
end)

-- Modern: await (no callback)
local rows = MySQL.query.await('SELECT * FROM users WHERE identifier = ?', {identifier})
```

### MySQL.insert — INSERT (returns insertId)

```lua
MySQL.insert('INSERT INTO users (identifier, name, money) VALUES (?, ?, ?)', {identifier, name, 500}, function(insertId)
    print('New user ID:', insertId)
end)

-- Await
local insertId = MySQL.insert.await('INSERT INTO users (identifier, name, money) VALUES (?, ?, ?)', {identifier, name, 500})
```

### MySQL.update — UPDATE/DELETE (returns affected rows)

```lua
local affected = MySQL.update.await('UPDATE users SET money = money + ? WHERE id = ?', {amount, userId})
-- affected = number of rows changed

MySQL.update.await('DELETE FROM sessions WHERE expires < NOW()', {})
```

### MySQL.prepare — Prepared statement (faster for repeated queries)

```lua
local result = MySQL.prepare.await('SELECT money FROM users WHERE id = ?', {id})
-- Returns the selected column, row, or rows depending on the query.
```

### MySQL.single — One row or nil

```lua
local user = MySQL.single.await('SELECT * FROM users WHERE id = ?', {id})
-- { identifier = 'steam:...', name = 'Player', money = 500 }
-- or nil if not found
```

### MySQL.scalar — Single value (one row, one column)

```lua
local count = MySQL.scalar.await('SELECT COUNT(*) FROM users', {})
-- Returns raw value (e.g. 42)

local money = MySQL.scalar.await('SELECT money FROM users WHERE id = ?', {id})
-- Returns number or nil
```

### MySQL.rawExecute — Raw execution, no result processing

```lua
MySQL.rawExecute('DELETE FROM expired_items WHERE date < NOW() - INTERVAL 30 DAY')
```

### MySQL.transaction — Multiple queries atomically

```lua
MySQL.transaction({
    'UPDATE bank SET balance = balance - 100 WHERE id = 1',
    'UPDATE bank SET balance = balance + 100 WHERE id = 2',
}, function(success)
    if success then
        print('Transaction committed')
    else
        print('Transaction failed — rolling back')
    end
end)

-- Await
local success = MySQL.transaction.await({
    {
        query = 'UPDATE inventory SET quantity = quantity - 1 WHERE id = ?',
        values = { itemId },
    },
})
```

## Placeholders (SAFETY)

**ALWAYS use `?` placeholders — NEVER concatenate values into SQL strings.**

```lua
-- ✅ SAFE — OxMySQL escapes and sanitizes
MySQL.query('SELECT * FROM users WHERE identifier = ?', {identifier})

-- ✅ Multiple placeholders
MySQL.query('SELECT * FROM users WHERE name = ? AND money > ?', {name, 100})

-- ❌ SQL INJECTION VULNERABLE — NEVER DO THIS
MySQL.query('SELECT * FROM users WHERE identifier = "' .. identifier .. '"')  -- NEVER!
MySQL.query("SELECT * FROM users WHERE name = '" .. name .. "'")              -- NEVER!
```

## Common Patterns

### Create tables (auto-migration)

```lua
MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS my_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        owner VARCHAR(60) NOT NULL,
        item VARCHAR(50) NOT NULL,
        quantity INT DEFAULT 1,
        metadata JSON DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_owner (owner)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])
```

### Player data save/load

```lua
-- Load player on join (inside a function / handler)
local function loadUser(identifier, playerName)
    local data = MySQL.single.await('SELECT * FROM users WHERE identifier = ?', {identifier})
    if data then return data end

    local id = MySQL.insert.await('INSERT INTO users (identifier, name) VALUES (?, ?)', {identifier, playerName})
    return { id = id, identifier = identifier, name = playerName }
end

-- Save player on disconnect
MySQL.update.await('UPDATE users SET money = ?, inventory = ? WHERE identifier = ?', {money, json.encode(inventory), identifier})
```

### Upsert pattern

```lua
-- Insert or update via oxmysql (requires a UNIQUE key on identifier)
MySQL.query.await([[
    INSERT INTO users (identifier, name, money) VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE name = VALUES(name), money = money + VALUES(money)
]], {identifier, name, amount})
```

### Bulk insert

Don't await one query per row in a loop. `MySQL.prepare` accepts an array of parameter sets and executes them as one batch:

```lua
local rows = {}
for i = 1, #items do
    rows[i] = { owner, items[i].name, items[i].qty }
end
MySQL.prepare.await('INSERT INTO player_items (owner, item, quantity) VALUES (?, ?, ?)', rows)
```

## Links

- Main docs: https://overextended.dev/oxmysql
- Placeholders: https://overextended.dev/oxmysql/placeholders
- Functions: https://overextended.dev/oxmysql (Functions section)
