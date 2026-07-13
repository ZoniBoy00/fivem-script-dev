--[[
  Discord Webhook Logger Template
  Rich embed support with rate limiting
]]

-- CONFIG
Config = Config or {}
Config.DiscordLog = {
    WebhookURL = 'https://discord.com/api/webhooks/your_webhook_id/your_webhook_token',
    BotName = 'My Server Logger',
    BotAvatar = 'https://i.imgur.com/yourlogo.png',
    RateLimit = 1000,           -- ms between messages
    MaxEmbedsPerMessage = 5,    -- Discord limit
}

-- RATE LIMITER
local LastLogTime = 0
local PendingQueue = {}

-- CORE: Send embed to Discord
function SendDiscordEmbed(embedData, webhookOverride)
    local webhook = webhookOverride or Config.DiscordLog.WebhookURL
    if not webhook or webhook == '' then
        print('[DiscordLog] No webhook URL configured')
        return
    end
    
    local payload = {
        username = Config.DiscordLog.BotName,
        avatar_url = Config.DiscordLog.BotAvatar,
        embeds = { embedData }
    }
    
    PerformHttpRequest(webhook, function(err, text, headers)
        if err ~= 204 and err ~= 200 then
            print(('[DiscordLog] Failed to send embed: %s'):format(err or 'unknown'))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

-- BATCH: Send multiple embeds in one message
function SendDiscordEmbeds(embeds, webhookOverride)
    local webhook = webhookOverride or Config.DiscordLog.WebhookURL
    if not webhook or webhook == '' then return end
    
    -- Discord limit: max 10 embeds per message
    local chunks = {}
    for i = 1, #embeds, Config.DiscordLog.MaxEmbedsPerMessage do
        table.insert(chunks, { unpack(embeds, i, i + Config.DiscordLog.MaxEmbedsPerMessage - 1) })
    end
    
    for _, chunk in ipairs(chunks) do
        local payload = {
            username = Config.DiscordLog.BotName,
            avatar_url = Config.DiscordLog.BotAvatar,
            embeds = chunk
        }
        
        PerformHttpRequest(webhook, function(err, text, headers)
            if err ~= 204 and err ~= 200 then
                print(('[DiscordLog] Batch failed: %s'):format(err or 'unknown'))
            end
        end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
        
        -- Wait between chunks to avoid rate limiting
        Wait(500)
    end
end

-- HELPER: Build embed table
function BuildEmbed(config)
    local embed = {
        title = config.title or '',
        description = config.description or '',
        color = config.color or 0x3498db,       -- Default blue
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = config.footer or { text = 'FiveM Logger' },
    }
    
    -- Fields
    if config.fields and #config.fields > 0 then
        embed.fields = config.fields
    end
    
    -- Author
    if config.author then
        embed.author = config.author
    end
    
    -- Thumbnail
    if config.thumbnail then
        embed.thumbnail = { url = config.thumbnail }
    end
    
    -- Image
    if config.image then
        embed.image = { url = config.image }
    end
    
    return embed
end

-- PRESETS: Common embed types

-- Player action (join/leave/kill)
function LogPlayerAction(source, action, details)
    local name = GetPlayerName(source)
    local identifiers = GetPlayerIdentifiers(source)
    local steam = ''
    for _, id in ipairs(identifiers) do
        if id:match('steam:') then steam = id break end
    end
    
    local colors = {
        join = 0x2ecc71,       -- Green
        leave = 0xe74c3c,      -- Red
        kill = 0xe67e22,        -- Orange
    }
    
    local embed = BuildEmbed({
        title = ('Player %s'):format(action:sub(1,1):upper()..action:sub(2)),
        description = details or ('%s (%s)'):format(name, steam),
        color = colors[action] or 0x3498db,
        fields = {
            { name = 'Player', value = name, inline = true },
            { name = 'Source', value = tostring(source), inline = true },
            { name = 'Steam', value = steam or 'N/A', inline = false },
        },
        footer = { text = 'Player Logger' },
    })
    
    SendDiscordEmbed(embed)
end

-- Server event (startup, restart, command)
function LogServerEvent(eventName, description, fields)
    local embed = BuildEmbed({
        title = eventName,
        description = description,
        color = 0x9b59b6,       -- Purple
        fields = fields or {},
        footer = { text = 'Server Logger' },
    })
    
    SendDiscordEmbed(embed)
end

-- Admin action (ban, kick, warn)
function LogAdminAction(adminSource, targetSource, action, reason)
    local adminName = GetPlayerName(adminSource)
    local targetName = GetPlayerName(targetSource)
    
    local embed = BuildEmbed({
        title = ('Admin Action: %s'):format(action:sub(1,1):upper()..action:sub(2)),
        description = reason or 'No reason provided',
        color = 0xe74c3c,       -- Red
        fields = {
            { name = 'Admin', value = adminName, inline = true },
            { name = 'Target', value = targetName, inline = true },
            { name = 'Reason', value = reason or 'N/A', inline = false },
        },
        footer = { text = 'Admin Logger' },
    })
    
    SendDiscordEmbed(embed)
end

-- Error logging
function LogError(source, errorMsg, context)
    local embed = BuildEmbed({
        title = '⚠️ Script Error',
        description = errorMsg,
        color = 0xff0000,       -- Red
        fields = {
            { name = 'Source', value = tostring(source or 'N/A'), inline = true },
            { name = 'Resource', value = GetCurrentResourceName(), inline = true },
            { name = 'Context', value = context or 'N/A', inline = false },
        },
        footer = { text = 'Error Logger' },
    })
    
    SendDiscordEmbed(embed)
end

--[[
  USAGE:
  LogPlayerAction(source, 'join')                    -- Player joined
  LogPlayerAction(source, 'leave', 'Timed out')      -- Player left with reason
  LogServerEvent('Server Started', 'Server is now online')
  LogAdminAction(adminSrc, targetSrc, 'ban', 'Hacking')
  LogError(source, 'MySQL timeout', 'player_data query')
  SendDiscordEmbed(BuildEmbed({ title = 'Custom', description = 'Message', color = 0x00ff00 }))
]]
