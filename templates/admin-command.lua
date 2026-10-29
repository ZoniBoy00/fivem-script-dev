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
    WebhookConvar = 'myresource_discord_webhook', -- Set server-side; never commit secrets
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
        -- ESX: TriggerClientEvent('esx:showNotification', source, 'No permission', 'error')
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
    local license = GetPlayerIdentifierByType(source, 'license') or 'unknown'

    -- 4. ADAPT: Get player object
    -- ESX: local xPlayer = ESX.GetPlayerFromId(source)
    -- QBCore: local Player = QBCore.Functions.GetPlayer(source)
    -- export: local playerData = exports.qbx_core:GetPlayer(source)

    -- 5. Execute command logic
    local ok, err = pcall(function()
        -- YOUR COMMAND LOGIC HERE

        -- ADAPT: Send feedback
        -- TriggerClientEvent('chat:addMessage', source, { args = { 'System', 'Command executed!' } })
    end)
    if not ok then
        print(('[mycommand] command failed: %s'):format(err))
        return
    end

    -- 6. Log to console + optional Discord
    print(('[mycommand] %s (%s) executed command'):format(playerName, license))

    -- Discord webhook (optional)
    local webhook = GetConvar(Config.AdminCommand.WebhookConvar, '')
    if webhook ~= '' then
        PerformHttpRequest(webhook, function(status)
            if status ~= 204 and status ~= 200 then
                print(('[mycommand] Discord log failed: %s'):format(status or 'unknown'))
            end
        end, 'POST', json.encode({
            content = string.format('**Command Used**\nPlayer: %s (%s)\nCommand: `%s`', playerName, license, rawCommand),
            allowed_mentions = { parse = {} },  -- player names/args must never ping @everyone
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
  - Set webhook server-side: set myresource_discord_webhook "https://discord.com/api/webhooks/<id>/<token>"  # server-only; never use setr for secrets
  - In-game: /mycommand [args]
]]
