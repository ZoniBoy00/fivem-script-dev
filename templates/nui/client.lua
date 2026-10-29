--[[
    NUI client bridge — pairs with html/index.html, html/app.js, html/style.css
    Messages to the UI: { type = 'open' | 'close' | 'update', data = { title, items } }
    Callbacks from the UI: 'buyItem', 'close'
]]

local isOpen = false

local function openPanel(data)
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'open', data = data })
end

local function closePanel()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end

-- UI → Lua: always answer with cb(...) or the fetch() in app.js hangs
RegisterNUICallback('close', function(_, cb)
    closePanel()
    cb({ ok = true })
end)

RegisterNUICallback('buyItem', function(data, cb)
    -- NUI data is client-controlled: forward only identifiers, the server validates everything
    local itemName = type(data) == 'table' and data.itemName
    local quantity = type(data) == 'table' and math.tointeger(data.quantity) or 1
    if type(itemName) ~= 'string' or not quantity then
        return cb({ ok = false })
    end

    TriggerServerEvent('myres:server:purchase', itemName, quantity)
    cb({ ok = true })  -- "request sent", not "purchase succeeded"
end)

-- Example opener (replace with a zone/target interaction)
RegisterCommand('myshop', function()
    openPanel({
        title = 'Shop',
        items = {
            { name = 'water', price = 5 },
            { name = 'bread', price = 3 },
        },
    })
end, false)

-- Never leave the player stuck with NUI focus after a restart
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and isOpen then
        SetNuiFocus(false, false)
    end
end)
