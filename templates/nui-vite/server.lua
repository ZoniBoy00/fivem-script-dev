--[[
    Server side for the Vite NUI example. Prices live here, never in the UI or client.
]]

local ITEMS = {
    water = { label = 'Water', price = 5 },
    bread = { label = 'Bread', price = 3 },
}

lib.callback.register('myres:getItems', function(src)
    local list = {}
    for name, item in pairs(ITEMS) do
        list[#list + 1] = { name = name, label = item.label, price = item.price }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end)

lib.callback.register('myres:purchase', function(src, itemName, quantity)
    local item = type(itemName) == 'string' and ITEMS[itemName]
    quantity = math.tointeger(quantity)
    if not item or not quantity or quantity < 1 or quantity > 10 then
        return { ok = false, reason = 'invalid' }
    end

    -- ADAPT: capacity check → remove money (check the bool) → add item → refund on failure.
    -- See references/common-patterns.md "Shop" for ESX / QBCore / QBox / ox_inventory versions.
    local total = item.price * quantity
    return { ok = false, reason = ('not implemented (would cost $%d)'):format(total) }
end)
