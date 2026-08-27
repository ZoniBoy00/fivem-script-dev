# server.cfg Configuration Reference

> Treat this as a starting point, not a complete convar catalogue. Verify every version-sensitive or resource-specific setting against the current [Cfx.re server command documentation](https://docs.fivem.net/docs/server-manual/server-commands/) and the documentation for the resource that owns it.

## Basic configuration

```cfg
sv_hostname "My FiveM Server [EU] [RP]"
sets sv_projectName "MyServer"
sets sv_projectDesc "A custom roleplay server with unique scripts"

sv_maxclients 48
sv_licenseKey "YOUR_CFX_KEY"
set steam_webApiKey "YOUR_STEAM_KEY"
```

Keep licence keys, API keys, webhooks, and database credentials out of version control. Use server-only convars or a deployment secret store.

## Game build and OneSync

Choose the game build required by your maps, assets, and dependencies. The current build list changes, so do not copy a build number from an old guide without checking the official documentation.

```cfg
# Set this only when a verified build is required by the server's assets.
# sv_enforceGameBuild <verified-build-number>

# Valid modes: on, off, legacy. Most servers use on.
onesync on

# Optional: the documented convar is onesync_forceMigration.
onesync_forceMigration true
```

## Resource startup order

Start dependencies before resources that consume them. Pick the framework and inventory that match your server; do not enable mutually incompatible alternatives just because they appear in an example.

```cfg
ensure mapmanager
ensure chat

# Database and shared libraries first
ensure oxmysql
ensure ox_lib

# Choose one framework stack
ensure es_extended
# ensure qb-core
# ensure qbx_core

# Start only after its dependencies and bridge are ready
ensure ox_inventory

# Your resources last
ensure my_awesome_resource
```

If a resource ships its own setup documentation, that documentation takes precedence for start order and its convars.

## ACE permissions

Keep permissions in a separate file so they can be reviewed independently.

```cfg
# server.cfg
exec permissions.cfg
```

```cfg
# permissions.cfg
add_ace group.admin command.mycommand allow
add_principal identifier.license:YOUR_LICENSE group.admin
```

Grant the narrowest permission needed. Avoid broad `command allow` grants for groups that only need one custom command.

## Server listing metadata

```cfg
sets tags "roleplay, economy, custom"
sets locale "fi-FI"
sets discord_invite "https://discord.gg/yourserver"
sets banner_detail "https://example.invalid/banner-detail.png"
sets banner_connecting "https://example.invalid/banner-connecting.png"
```

## Voice, queues, whitelists and logging

Voice, queue, whitelist, AFK, ping-limit, and detailed logging settings are usually owned by a specific resource (for example pma-voice, a queue resource, txAdmin, or an administration resource). Configure those settings in that resource's documented configuration instead of relying on undocumented `sv_*` variables.

## Deployment checklist

1. Verify game build and OneSync convars against current Cfx.re docs.
2. Confirm dependency start order from the exact framework, inventory, database, and voice resource versions in use.
3. Store secrets with server-only `set` convars or deployment secrets; never use `setr` for secrets.
4. Test a clean boot, a resource restart, a player join, and a player disconnect.
5. Keep server-specific configuration outside the public skill repository.
