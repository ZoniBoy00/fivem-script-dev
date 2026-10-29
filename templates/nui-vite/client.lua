--[[
    NUI client bridge for web/ (Vite + TypeScript)
    Lua → UI:  SendNUIMessage({ action = 'setVisible' | 'setItems', data = ... })  (typed in web/src/types.ts)
    UI → Lua:  fetchNui('close') / fetchNui('purchase', { item, quantity })
]]

local isOpen = false

local function setOpen(open)
    if isOpen == open then return end
    isOpen = open
    SetNuiFocus(open, open)
    SendNUIMessage({ action = 'setVisible', data = open })
end

RegisterCommand('myshop', function()
    -- Items/prices come from the server so the UI can never be the source of truth
    local items = lib.callback.await('myres:getItems', false)
    if not items then return end
    SendNUIMessage({ action = 'setItems', data = items })
    setOpen(true)
end, false)

RegisterNUICallback('close', function(_, cb)
    setOpen(false)
    cb(true)
end)

RegisterNUICallback('purchase', function(data, cb)
    -- NUI data is client-controlled: forward only identifiers, the server validates everything
    local item = type(data) == 'table' and data.item
    local quantity = type(data) == 'table' and math.tointeger(data.quantity)
    if type(item) ~= 'string' or not quantity then
        return cb({ ok = false, reason = 'invalid' })
    end

    -- Always answer, or the fetch() in the UI hangs
    cb(lib.callback.await('myres:purchase', false, item, quantity) or { ok = false, reason = 'error' })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and isOpen then
        SetNuiFocus(false, false)
    end
end)
