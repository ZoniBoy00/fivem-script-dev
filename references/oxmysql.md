# OxMySQL — Database Queries

> SQL integration for FiveM. Server-side only. Use MariaDB over MySQL 8 for best compatibility.
> Docs: https://overextended.dev/docs/oxmysql

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
-- Returns: single row or nil (similar to single)
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
    'UPDATE inventory SET quantity = quantity - 1 WHERE id = ?',
}, {itemId})
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
-- Load player on join
local data = MySQL.single.await('SELECT * FROM users WHERE identifier = ?', {identifier})
if data then
    -- Player exists, load data
    return data
else
    -- New player, create
    local id = MySQL.insert.await('INSERT INTO users (identifier, name) VALUES (?, ?)', {identifier, playerName})
end

-- Save player on disconnect
MySQL.update.await('UPDATE users SET money = ?, inventory = ? WHERE identifier = ?', {money, json.encode(inventory), identifier})
```

### Upsert pattern

```lua
-- Insert or update (MySQL)
MySQL.query.await([[
    INSERT INTO users (identifier, name, money) VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE name = VALUES(name), money = money + VALUES(money)
]], {identifier, name, amount})
```

### Bulk insert

```lua
for _, item in pairs(items) do
    MySQL.insert.await('INSERT INTO player_items (owner, item, quantity) VALUES (?, ?, ?)', {owner, item.name, item.qty})
end
```

## Links

- Main docs: https://overextended.dev/docs/oxmysql
- Placeholders: https://overextended.dev/docs/oxmysql/placeholders
- Functions: https://overextended.dev/docs/oxmysql (Functions section)
