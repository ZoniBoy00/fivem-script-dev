--[[
    OxMySQL — Common database query patterns
    Copy queries from here into your resource as needed
]]

-- ============================================================================
-- PLAYER LOADING (playerConnecting)
-- ============================================================================

-- Server event handler
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    deferrals.defer()
    Wait(0)
    
    local identifiers = GetPlayerIdentifiers(source)
    local license = nil
    
    for _, v in pairs(identifiers) do
        if string.find(v, 'license:') then
            license = v
            break
        end
    end
    
    if not license then
        deferrals.done('Could not find license identifier')
        return
    end
    
    deferrals.update('Loading your data...')
    Wait(0)
    
    -- Load or create player
    local user = MySQL.single.await('SELECT * FROM users WHERE identifier = ?', {license})
    
    if user then
        -- Returning player (update name/last_seen)
        MySQL.update.await('UPDATE users SET name = ?, last_seen = NOW() WHERE identifier = ?', {name, license})
    else
        -- New player
        MySQL.insert.await('INSERT INTO users (identifier, name, money, bank) VALUES (?, ?, ?, ?)', {license, name, 500, 0})
    end
    
    deferrals.done()
end)

-- ============================================================================
-- PLAYER SAVING (playerDropped)
-- ============================================================================

AddEventHandler('playerDropped', function(reason)
    local identifiers = GetPlayerIdentifiers(source)
    local license = nil
    
    for _, v in pairs(identifiers) do
        if string.find(v, 'license:') then
            license = v
            break
        end
    end
    
    if license then
        -- Save player data
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            MySQL.update.await('UPDATE users SET money = ?, bank = ? WHERE identifier = ?', {
                xPlayer.getMoney(),
                xPlayer.getAccount('bank').money,
                license,
            })
        end
    end
end)

-- ============================================================================
-- BASIC CRUD
-- ============================================================================

-- Fetch single row
MySQL.single.await('SELECT * FROM users WHERE identifier = ?', {identifier})

-- Fetch multiple rows
MySQL.query.await('SELECT * FROM items WHERE owner = ?', {owner})

-- Insert row
MySQL.insert.await('INSERT INTO player_data (owner, data_type, value) VALUES (?, ?, ?)', {owner, 'inventory', jsonData})

-- Update row
MySQL.update.await('UPDATE users SET money = money + ? WHERE identifier = ?', {amount, identifier})

-- Delete row
MySQL.update.await('DELETE FROM temp_data WHERE expires < NOW()', {})

-- ============================================================================
-- UPSERT (Insert or Update)
-- ============================================================================

MySQL.query.await([[
    INSERT INTO player_items (owner, item, quantity) VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)
]], {owner, 'water', 1})

-- ============================================================================
-- TRANSACTION (Multiple queries atomically)
-- ============================================================================

MySQL.transaction.await({
    'UPDATE bank SET balance = balance - 100 WHERE id = 1',
    'UPDATE bank SET balance = balance + 100 WHERE id = 2',
})

-- ============================================================================
-- TABLE CREATION (Auto-migration)
-- ============================================================================

MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS my_custom_table (
        id INT AUTO_INCREMENT PRIMARY KEY,
        owner VARCHAR(60) NOT NULL,
        data JSON DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_owner (owner)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])

-- ============================================================================
-- SCALARS (Single values)
-- ============================================================================

local playerCount = MySQL.scalar.await('SELECT COUNT(*) FROM users', {})

local totalMoney = MySQL.scalar.await('SELECT SUM(money) FROM users WHERE money > 0', {})
