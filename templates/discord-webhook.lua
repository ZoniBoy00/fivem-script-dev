--[[
  Discord Webhook Logger Template (server-side)
  Rich embeds, a send queue that respects Discord rate limits, and mention suppression.
  The webhook URL is read from a server-only convar:
      set myresource_discord_webhook "https://discord.com/api/webhooks/<id>/<token>"
]]

-- CONFIG
Config = Config or {}
Config.DiscordLog = {
    WebhookConvar = 'myresource_discord_webhook', -- server-only; never commit the URL, never use setr
    BotName = 'My Server Logger',
    BotAvatar = '',             -- optional image URL
    SendInterval = 1000,        -- ms between requests (Discord allows ~5 requests / 2 s per webhook)
    MaxEmbedsPerMessage = 10,   -- Discord limit
    MaxQueue = 200,             -- drop oldest beyond this to bound memory
}

local function getWebhook(webhookOverride)
    if webhookOverride and webhookOverride ~= '' then return webhookOverride end
    return GetConvar(Config.DiscordLog.WebhookConvar, '')
end

-- QUEUE: messages are sent in order by one worker thread instead of being dropped
local queue = {}
local workerRunning = false

local function startWorker()
    if workerRunning then return end
    workerRunning = true
    CreateThread(function()
        while #queue > 0 do
            local job = table.remove(queue, 1)
            local retryAfter = 0
            local p = promise.new()
            PerformHttpRequest(job.webhook, function(status, _, headers)
                if status == 429 then
                    retryAfter = (tonumber(headers and (headers['Retry-After'] or headers['retry-after'])) or 2) * 1000
                    table.insert(queue, 1, job)  -- retry this message first
                elseif status ~= 200 and status ~= 204 then
                    print(('[DiscordLog] Request failed: %s'):format(status or 'unknown'))
                end
                p:resolve(true)
            end, 'POST', json.encode(job.payload), { ['Content-Type'] = 'application/json' })
            Citizen.Await(p)
            Wait(math.max(Config.DiscordLog.SendInterval, retryAfter))
        end
        workerRunning = false
    end)
end

local function enqueue(webhook, embeds)
    if #queue >= Config.DiscordLog.MaxQueue then table.remove(queue, 1) end
    queue[#queue + 1] = {
        webhook = webhook,
        payload = {
            username = Config.DiscordLog.BotName,
            avatar_url = Config.DiscordLog.BotAvatar ~= '' and Config.DiscordLog.BotAvatar or nil,
            embeds = embeds,
            allowed_mentions = { parse = {} },  -- player names like "@everyone" must not ping
        },
    }
    startWorker()
end

-- CORE: Send one embed
function SendDiscordEmbed(embedData, webhookOverride)
    local webhook = getWebhook(webhookOverride)
    if webhook == '' then
        print('[DiscordLog] No webhook URL configured')
        return
    end
    enqueue(webhook, { embedData })
end

-- BATCH: Send multiple embeds (chunked to Discord's per-message limit)
function SendDiscordEmbeds(embeds, webhookOverride)
    local webhook = getWebhook(webhookOverride)
    if webhook == '' then return end

    local size = Config.DiscordLog.MaxEmbedsPerMessage
    for i = 1, #embeds, size do
        enqueue(webhook, { table.unpack(embeds, i, math.min(i + size - 1, #embeds)) })
    end
end

-- Discord rejects empty field values and strings over its limits
local function clip(value, max)
    value = tostring(value or 'N/A')
    if value == '' then value = 'N/A' end
    return #value > max and value:sub(1, max - 3) .. '...' or value
end

-- HELPER: Build embed table
function BuildEmbed(config)
    local embed = {
        title = clip(config.title, 256),
        description = clip(config.description, 4096),
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
    local name = GetPlayerName(source) or 'unknown'
    local license = GetPlayerIdentifierByType(source, 'license') or 'N/A'

    local colors = {
        join = 0x2ecc71,       -- Green
        leave = 0xe74c3c,      -- Red
        kill = 0xe67e22,        -- Orange
    }

    local embed = BuildEmbed({
        title = ('Player %s'):format(action:sub(1,1):upper()..action:sub(2)),
        description = details or ('%s (%s)'):format(name, license),
        color = colors[action] or 0x3498db,
        fields = {
            { name = 'Player', value = clip(name, 1024), inline = true },
            { name = 'Source', value = tostring(source), inline = true },
            { name = 'License', value = license, inline = false },
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
            { name = 'Admin', value = clip(adminName, 1024), inline = true },
            { name = 'Target', value = clip(targetName, 1024), inline = true },
            { name = 'Reason', value = clip(reason, 1024), inline = false },
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
