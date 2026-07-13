--[[
  ox_inventory Item & Shop Registration Template
  Stubs, item definitions, shops, crafting, and weapon tints
]]

-- 1. ITEM DEFINITION (ox_inventory/data/items.lua)
--[[
return {
    ['water'] = {
        label = 'Water Bottle',
        weight = 500,               -- grams
        stack = true,               -- Can stack (max 25000 by default)
        close = true,               -- Close inventory after use
        description = 'A bottle of clean drinking water'
    },
    ['phone'] = {
        label = 'Mobile Phone',
        weight = 200,
        stack = false,              -- Unique item
        close = true,
        description = 'A standard mobile phone',
        client = {
            image = 'phone.png',    -- Custom image in ox_inventory/web/images/
            usetime = 2.5,          -- Use time in seconds
            cancel = true,          -- Can cancel use
            anim = {                -- Animation while using
                dict = 'anim@heists@box_carry@',
                clip = 'idle',
                flag = 49,
            },
        },
        server = {
            export = 'myresource.usePhone', -- Export called on use
        }
    },
    ['weapon_pistol'] = {
        label = 'Pistol',
        weight = 1000,
        stack = false,
        close = true,
        description = 'A standard semi-automatic pistol',
        degrade = 60,               -- Degrade ammo count per use
        ammo = true,                -- Uses ammo system
        weapon = true,              -- Is a weapon
    },
    ['bread'] = {
        label = 'Bread',
        weight = 200,
        stack = true,
        close = true,
        description = 'A fresh loaf of bread',
        buttons = {
            { label = 'Eat', action = function(slot)
                TriggerServerEvent('myresource:eatFood', slot.metadata)
            end },
        },
        client = {
            status = { hunger = 100000 },  -- Restore 10% hunger (ESX/QBCore)
            anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger_fp' },
            prop = { model = 'prop_cs_burger_01', bone = 18905, pos = { 0.13, 0.05, 0.02 }, rot = { -50.0, 0.0, 0.0 } },
            usetime = 2.0,
        },
    },
}
]]

-- 2. SHOP DEFINITION (ox_inventory/data/shops.lua)
--[[
return {
    -- 24/7 market
    {
        name = 'twentyfourseven',
        label = '24/7 Market',
        slots = 20,
        inventory = {
            { name = 'water', price = 5 },
            { name = 'bread', price = 3 },
            { name = 'phone', price = 250 },
        },
        locations = {
            vector3(25.7, -1347.3, 29.5),   -- Legion Square
            vector3(-3038.71, 585.9, 7.9),  -- Paleto Bay
            vector3(1135.808, -982.281, 46.4158), -- Sandy Shores
        },
        blip = { id = 59, colour = 0, scale = 0.6 },
    },
    
    -- Weapon shop
    {
        name = 'weapon_shop',
        label = 'Ammu-Nation',
        slots = 12,
        inventory = {
            { name = 'weapon_pistol', price = 5000 },
            { name = 'pistol_ammo', price = 100, currency = 'ammo' },
        },
        locations = {
            vector3(-662.180, -935.961, 21.829),
        },
        groups = {                     -- Only accessible by these jobs
            police = 0,                -- 0 = any grade
        },
        blip = { id = 110, colour = 3, scale = 0.6 },
    },
}
]]

-- 3. WEAPON TINT / COMPONENT / AMMO REGISTRATION
--[[
-- In ox_inventory/data/weapons.lua (or custom resource)
return {
    ['WEAPON_PISTOL'] = {
        label = 'Pistol',
        weight = 1000,
        durability = 0.05,          -- Damage per shot
        ammoname = 'pistol_ammo',    -- Ammo type used
        ammo = { 'pistol_ammo' },
        tint = {
            { id = 0, name = 'Default' },
            { id = 1, name = 'Green' },
            { id = 2, name = 'Gold' },
            { id = 3, name = 'Pink' },
            { id = 4, name = 'Army' },
            { id = 5, name = 'LSPD' },
            { id = 6, name = 'Orange' },
            { id = 7, name = 'Platinum' },
        },
        components = {
            { name = 'at_pi_flsh',    label = 'Flashlight',  type = 'flashlight' },
            { name = 'at_pi_supp',    label = 'Suppressor',  type = 'suppressor' },
            { name = 'at_pi_supp_02', label = 'Suppressor 2',type = 'suppressor' },
        },
    },
}
]]

-- 4. CRAFTING (custom resource — wraps ox_inventory)
--[[
Config.Crafting = {
    recipes = {
        {
            name = 'lockpick',
            label = 'Lockpick',
            time = 5000,            -- ms to craft
            requirements = {
                { name = 'metalscrap', count = 5 },
                { name = 'plastic', count = 2 },
            },
            result = { name = 'lockpick', count = 1 },
        },
        {
            name = 'armor',
            label = 'Body Armor',
            time = 10000,
            requirements = {
                { name = 'iron', count = 10 },
                { name = 'fabric', count = 5 },
            },
            result = { name = 'armor', count = 1 },
        },
    },
}

-- Server: Craft handler
RegisterNetEvent('myresource:craftItem', function(recipeName)
    local src = source
    local recipe = Config.Crafting.recipes[recipeName]
    if not recipe then return end
    
    -- Check requirements
    for _, req in ipairs(recipe.requirements) do
        local count = exports.ox_inventory:Search('count', req.name)
        if count < req.count then
            TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Missing materials' })
            return
        end
    end
    
    -- Remove materials
    for _, req in ipairs(recipe.requirements) do
        exports.ox_inventory:RemoveItem(src, req.name, req.count)
    end
    
    -- Give result
    exports.ox_inventory:AddItem(src, recipe.result.name, recipe.result.count)
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Crafted ' .. recipe.label })
end)
]]

-- 5. INVENTORY EXPORTS QUICK REFERENCE
--[[
-- Check item count
local count = exports.ox_inventory:Search('count', 'water')
local count = exports.ox_inventory:Search('count', 'weapon_pistol', { serial = 'ABC123' })

-- Add item
exports.ox_inventory:AddItem(source, 'water', 5)
exports.ox_inventory:AddItem(source, 'weapon_pistol', 1, { serial = 'SERIAL123' })
local success, response = exports.ox_inventory:AddItem(source, 'water', 5)

-- Remove item
exports.ox_inventory:RemoveItem(source, 'water', 3)
exports.ox_inventory:RemoveItem(source, 'weapon_pistol', 1, { serial = 'SERIAL123' })

-- Get item data
local item = exports.ox_inventory:GetSlot(source, slotIndex)  -- Full slot data
local items = exports.ox_inventory:GetItems(source)           -- All items

-- Has item
local hasItem = exports.ox_inventory:Search('count', 'water', nil, source) > 0

-- Open inventory for player
exports.ox_inventory:openInventory(source, 'shop', { id = 'twentyfourseven' })
exports.ox_inventory:openInventory(source, 'stash', { id = 'closet_1' })
exports.ox_inventory:openInventory(source, 'craft', { id = 'crafting_table' })

-- Register usable item export
exports('usePhone', function(data, slot)
    -- Called when player uses phone item
    local source = source  -- From export context
    TriggerClientEvent('myresource:openPhone', source)
    return true  -- Item consumed
end)
]]

-- 6. STASH / GLOVEBOX / TRUNK REGISTRATION
--[[
-- In resource where you need persistent storage:
RegisterNetEvent('myresource:openStash', function(stashId, slots, weight)
    local src = source
    -- Each player gets their own stash instance
    exports.ox_inventory:openInventory(src, 'stash', {
        id = ('%s_%s'):format(stashId, GetPlayerIdentifiers(src)[1]),  -- Unique per player
        label = 'My Stash',
        slots = slots or 20,
        weight = weight or 10000,  -- grams (10kg)
    })
end)

-- Police evidence locker
RegisterNetEvent('police:openEvidence', function(evidenceId)
    local src = source
    exports.ox_inventory:openInventory(src, 'stash', {
        id = ('evidence_%s'):format(evidenceId),
        label = 'Evidence Locker',
        slots = 50,
        weight = 50000,
        owner = false,  -- Anyone with access can take
    })
end)
]]
