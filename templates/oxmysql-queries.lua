--[[
    oxmysql — common query patterns (server-side)

    fxmanifest.lua:
        server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
        dependency 'oxmysql'

    All database access goes through oxmysql's `MySQL` API. Always use `?` placeholders.
    `.await` calls must run inside a thread or event handler — never at file top level.
    Everything below is wrapped in functions so copying this file runs nothing by itself.
]]

local Db = {}

-- ============================================================================
-- SCHEMA (run once on start)
-- ============================================================================

function Db.migrate()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS myres_players (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(60) NOT NULL UNIQUE,
            name VARCHAR(100) NOT NULL,
            money INT NOT NULL DEFAULT 0,
            last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end

-- ============================================================================
-- PLAYER LOAD / SAVE
-- ============================================================================

-- Upsert on join: one round-trip, safe against duplicate joins (UNIQUE identifier)
function Db.loadPlayer(identifier, name)
    MySQL.insert.await([[
        INSERT INTO myres_players (identifier, name) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE name = VALUES(name)
    ]], { identifier, name })

    return MySQL.single.await('SELECT id, identifier, name, money FROM myres_players WHERE identifier = ?', { identifier })
end

function Db.savePlayer(identifier, money)
    return MySQL.update.await('UPDATE myres_players SET money = ? WHERE identifier = ?', { money, identifier })
end

-- ============================================================================
-- BASIC CRUD
-- ============================================================================

function Db.getOne(identifier)
    return MySQL.single.await('SELECT * FROM myres_players WHERE identifier = ?', { identifier })  -- row or nil
end

function Db.getMany(minMoney)
    return MySQL.query.await('SELECT identifier, money FROM myres_players WHERE money > ?', { minMoney })  -- array
end

function Db.addMoney(identifier, amount)
    return MySQL.update.await('UPDATE myres_players SET money = money + ? WHERE identifier = ?', { amount, identifier })  -- affected rows
end

function Db.count()
    return MySQL.scalar.await('SELECT COUNT(*) FROM myres_players')
end

function Db.delete(identifier)
    return MySQL.update.await('DELETE FROM myres_players WHERE identifier = ?', { identifier })
end

-- ============================================================================
-- TRANSACTION (all-or-nothing)
-- ============================================================================

function Db.transfer(fromIdentifier, toIdentifier, amount)
    return MySQL.transaction.await({
        { query = 'UPDATE myres_players SET money = money - ? WHERE identifier = ? AND money >= ?', values = { amount, fromIdentifier, amount } },
        { query = 'UPDATE myres_players SET money = money + ? WHERE identifier = ?', values = { amount, toIdentifier } },
    })
end

-- ============================================================================
-- BATCH INSERT (one prepared statement, many parameter sets)
-- ============================================================================

function Db.insertMany(rows)
    -- rows = { { identifier, name }, { identifier, name }, ... }
    return MySQL.prepare.await('INSERT IGNORE INTO myres_players (identifier, name) VALUES (?, ?)', rows)
end

-- ============================================================================
-- WIRING
-- ============================================================================

local players = {}

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Db.migrate()
end)

AddEventHandler('playerJoining', function()
    local src = source                                -- final server ID (capture before awaits)
    local identifier = GetPlayerIdentifierByType(src, 'license')
    if not identifier then return end
    players[src] = Db.loadPlayer(identifier, GetPlayerName(src))
end)

AddEventHandler('playerDropped', function()
    local src = source
    local data = players[src]
    players[src] = nil
    if data then Db.savePlayer(data.identifier, data.money) end
end)
