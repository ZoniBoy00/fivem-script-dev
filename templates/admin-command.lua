--[[
  Admin Command Template
  ACE permissions + rate limiting + logging
  Adapt framework-specific parts marked with -- ADAPT:
]]

-- CONFIG
Config = Config or {}
Config.AdminCommand = {
    Permission = 'command.mycommand',       -- ACE permission
    Cooldown = 3000,                         -- ms between uses
    LogChannel = 123456789,                  -- Discord webhook ID
}

-- SERVER
local Cooldowns = {}

RegisterCommand('mycommand', function(source, args, rawCommand)
    -- Check source validity
    if source == 0 then
        print('[mycommand] Cannot be used from console')
        return
    end
    
    -- 1. ACE permission check
    if not IsPlayerAceAllowed(source, Config.AdminCommand.Permission) then
        -- ADAPT: Notify using your framework
        -- ESX: TriggerClientEvent('chat:addMessage', source, { args = { 'System', 'No permission' } })
        -- QBCore: TriggerClientEvent('QBCore:Notify', source, 'No permission', 'error')
        -- Ox: TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'No permission' })
        print(('[mycommand] Player %s denied (no ACE)'):format(source))
        return
    end
    
    -- 2. Rate limit check
    local now = GetGameTimer()
    local lastUse = Cooldowns[source] or 0
    if now - lastUse < Config.AdminCommand.Cooldown then
        local remaining = math.ceil((Config.AdminCommand.Cooldown - (now - lastUse)) / 1000)
        -- ADAPT: Notify player
        print(('[mycommand] Player %s rate limited (%ds remaining)'):format(source, remaining))
        return
    end
    Cooldowns[source] = now
    
    -- 3. Get player info
    local playerName = GetPlayerName(source)
    local identifiers = GetPlayerIdentifiers(source)
    local steamId = ''
    for _, id in ipairs(identifiers) do
        if id:match('steam:') then
            steamId = id
            break
        end
    end
    
    -- 4. ADAPT: Get player object
    -- ESX: local xPlayer = ESX.GetPlayerFromId(source)
    -- QBCore: local Player = QBCore.Functions.GetPlayer(source)
    -- export: local playerData = exports.qbx_core:GetPlayer(source)
    
    -- 5. Execute command logic
    pcall(function()
        -- YOUR COMMAND LOGIC HERE
        
        -- ADAPT: Send feedback
        -- TriggerClientEvent('chat:addMessage', source, { args = { 'System', 'Command executed!' } })
    end)
    
    -- 6. Log to console + optional Discord
    print(('[mycommand] %s (%s) executed command'):format(playerName, steamId))
    
    -- Discord webhook (optional)
    if Config.AdminCommand.LogChannel then
        PerformHttpRequest(('https://discord.com/api/webhooks/%d'):format(Config.AdminCommand.LogChannel), function(err, text, headers)
            if err ~= 204 then
                print(('[mycommand] Discord log failed: %s'):format(err or 'unknown'))
            end
        end, 'POST', json.encode({
            content = string.format('**Command Used**\nPlayer: %s (%s)\nCommand: `%s`', playerName, steamId, rawCommand)
        }), { ['Content-Type'] = 'application/json' })
    end
end, true)

-- Optional: Clean up cooldowns when player disconnects
AddEventHandler('playerDropped', function(reason)
    local source = source
    Cooldowns[source] = nil
end)

--[[
  USAGE EXAMPLES:
  - Add ACE in server.cfg: add_ace group.admin command.mycommand allow
  - In-game: /mycommand [args]
]]
