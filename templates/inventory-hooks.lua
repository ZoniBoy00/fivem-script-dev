--[[
  ox_inventory integration template (server-side unless noted)
  Item definitions, usable-item exports, shops, stashes and crafting.
  Signatures follow overextended/ox_inventory. Data-file examples are in comments.
]]

-- ============================================================================
-- 1. ITEM DEFINITIONS (ox_inventory/data/items.lua)
-- ============================================================================
--[[
return {
    ['water'] = {
        label = 'Water Bottle',
        weight = 500,                 -- grams
        stack = true,
        close = true,                 -- close inventory on use
        consume = 1,                  -- removed per use
        description = 'A bottle of clean drinking water',
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = 'prop_ld_flow_bottle', pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,           -- ms
            cancel = true,
        },
    },
    ['phone'] = {
        label = 'Mobile Phone',
        weight = 200,
        stack = false,
        close = true,
        consume = 0,                  -- not removed on use
        server = {
            export = 'myresource.phone', -- calls exports.myresource:phone(event, item, inventory, slot, data)
        },
    },
}
]]

-- ============================================================================
-- 2. USABLE ITEM EXPORTS
-- ox_inventory has already verified the player owns the item before calling these.
-- ============================================================================

exports('phone', function(event, item, inventory, slot, data)
    if event == 'usingItem' then
        -- Return false to cancel the use (e.g. player is cuffed)
        return true
    elseif event == 'usedItem' then
        TriggerClientEvent('myresource:client:openPhone', inventory.id)  -- inventory.id = player server ID
    end
end)

-- ============================================================================
-- 3. SHOPS & STASHES (register once on start; ox_inventory enforces groups/coords)
-- ============================================================================

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    exports.ox_inventory:RegisterShop('myres_market', {
        name = '24/7 Market',
        inventory = {
            { name = 'water', price = 5 },
            { name = 'phone', price = 250 },
        },
        locations = { vec3(25.7, -1347.3, 29.5) },
    })

    -- RegisterStash(id, label, slots, maxWeight, owner, groups, coords)
    exports.ox_inventory:RegisterStash('police_evidence', 'Evidence Locker', 50, 100000, false, { police = 0 }, vec3(474.8, -996.3, 26.3))
    exports.ox_inventory:RegisterStash('personal_locker', 'Personal Locker', 20, 20000, true)  -- owner = true → one per player
end)

-- Opening from the server: only after YOUR authorization; never let the client choose size or id
local Lockers = {
    personal_locker = { coords = vec3(452.0, -993.0, 30.7), job = nil },
}

RegisterNetEvent('myresource:server:openLocker', function(lockerId)
    local src = source
    if GetInvokingResource() then return end

    local locker = type(lockerId) == 'string' and Lockers[lockerId]
    if not locker then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - locker.coords) > 3.0 then return end
    -- ADAPT: job/permission check if locker.job is set

    exports.ox_inventory:forceOpenInventory(src, 'stash', lockerId)
end)

-- ============================================================================
-- 4. CRAFTING (custom; recipes keyed by name)
-- ============================================================================

local Recipes = {
    lockpick = {
        label = 'Lockpick',
        requirements = { { name = 'metalscrap', count = 5 }, { name = 'plastic', count = 2 } },
        result = { name = 'lockpick', count = 1 },
    },
}

local crafting = {}  -- per-player lock against double requests

RegisterNetEvent('myresource:server:craft', function(recipeName)
    local src = source
    if GetInvokingResource() then return end
    local recipe = type(recipeName) == 'string' and Recipes[recipeName]
    if not recipe or crafting[src] then return end
    crafting[src] = true

    local ox = exports.ox_inventory

    -- Check materials and capacity before changing anything
    for _, req in ipairs(recipe.requirements) do
        if ox:GetItemCount(src, req.name) < req.count then
            crafting[src] = nil
            return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Missing materials' })
        end
    end
    if not ox:CanCarryItem(src, recipe.result.name, recipe.result.count) then
        crafting[src] = nil
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Inventory full' })
    end

    -- Remove materials, tracking what was removed so it can be restored
    local removed = {}
    for _, req in ipairs(recipe.requirements) do
        if not ox:RemoveItem(src, req.name, req.count) then
            for _, r in ipairs(removed) do ox:AddItem(src, r.name, r.count) end
            crafting[src] = nil
            return
        end
        removed[#removed + 1] = req
    end

    if not ox:AddItem(src, recipe.result.name, recipe.result.count) then
        for _, r in ipairs(removed) do ox:AddItem(src, r.name, r.count) end
        crafting[src] = nil
        return
    end

    crafting[src] = nil
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Crafted ' .. recipe.label })
end)

AddEventHandler('playerDropped', function()
    crafting[source] = nil
end)

-- ============================================================================
-- 5. QUICK REFERENCE
-- ============================================================================
--[[
-- Server
exports.ox_inventory:GetItemCount(src, 'water')                    -- total count
exports.ox_inventory:Search(src, 'count', 'water')                 -- same, via Search
exports.ox_inventory:Search(src, 'slots', 'weapon_pistol', { serial = 'ABC123' })
exports.ox_inventory:CanCarryItem(src, 'water', 5)
local ok, resp = exports.ox_inventory:AddItem(src, 'water', 5, { quality = 100 })  -- (inv, item, count, metadata, slot)
exports.ox_inventory:RemoveItem(src, 'water', 3)
exports.ox_inventory:GetSlot(src, 1)
exports.ox_inventory:GetInventoryItems(src)

-- Client (local player only — UI hints, never authorization)
exports.ox_inventory:Search('count', 'water')
exports.ox_inventory:GetItemCount('water')
exports.ox_inventory:openInventory('shop', { type = 'myres_market', id = 1 })
exports.ox_inventory:openInventory('stash', 'personal_locker')
]]
