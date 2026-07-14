# server.cfg Configuration Reference

> The server configuration file controls everything from player limits to resource startup order to game build.

---

## File Location

- **Standard:** `/server-data/server.cfg` (root of your server data directory)
- **Windows TXAdmin:** Usually auto-generated, accessible via web panel

---

## Basic Configuration

```cfg
# Hostname (shows in server browser)
sv_hostname "My FiveM Server [EU] [RP]"

# Server description (HUD tooltip)
sets sv_projectDesc "A custom roleplay server with unique scripts"
sets sv_projectName "MyServer"

# Maximum connected players
sv_maxclients 48

# Server ID for txAdmin or standalone (must be unique)
sv_serverId 1

# Steam API key (optional, enables some Steam features)
set steam_webApiKey "YOUR_STEAM_KEY"

# License key (REQUIRED — from cfx.re)
sv_licenseKey "YOUR_CFX_KEY"
```

---

## Essential Settings

### Game Build

```cfg
# Controls game build version (affects packfiles, DLCs, ymaps)
sv_enforceGameBuild 3258       # Example build — always use the newest your assets support
# Build numbers are GTA Online title updates. Common examples:
# 3258+ = various 2024–2025 builds
# 2944 = GTA Online Danny & The Veteran
# 2802 = Bottom Dollar Bounties
# 2699 = Agents of Sabotage
# 2545 = Chop Shop
# 2372 = San Andreas Mercenaries
# 2189 = Drug Wars (popular for modding)
# 2060 = Criminal Enterprises
# 1604 = Cayo Perico (legacy)

# If using map mods, match the build to the mod requirements
# Check the current latest build at https://docs.fivem.net/docs/server-manual/server-commands/#sv_enforcegamebuild
```

### OneSync

```cfg
# Entity streaming mode
onesync on                     # Recommended (32-128 players)
# onesync off                  # Legacy (<32 players)
# onesync essential            # Force scoped entities (>128 players)

# Force migration to new entity system
onesync_forceMigrate true

# Enable Infinity (EXTREME player counts — experimental)
# onesync_enableInfinity false
```

### Network

```cfg
# Network optimization
sv_forceIndirectListing true   # Hide from server list (optional)
sv_master1 ""                  # Unset if not listing publicly
sv_endpointPrivacy true        # Hide IPs from players

# Packet loss / latency
sv_maxPing 300                 # Kick players above this ping (0 = disabled)
sv_packetLossThreshold 0.5    # % threshold
sv_pingSmoothing 500           # Ping calculation smoothing (ms)

# Bandwidth
sv_maxBitrate 1024             # Max upload per player (kbps, 0 = auto)
sv_minClientVersion "0"        # Min client build version
```

---

## Resource Management

```cfg
# Auto-start resources (order matters!)
ensure mapmanager
ensure spawnmanager
ensure sessionmanager
ensure basic-gamemode
ensure chat

# Database
ensure mysql-async              # Legacy — prefer oxmysql
ensure oxmysql                  # Modern

# Core framework
ensure es_extended              # ESX
# ensure qb-core                # QBCore
# ensure qbx_core               # QBox

# UI
ensure ox_lib

# Inventory
ensure ox_inventory             # Modern inventory

# Your resources
ensure my_awesome_resource
ensure vehicle_shop

# Manual start only (not auto-started)
# start admin_menu
```

### Resource Start Order Rules

1. **Managers:** `mapmanager`, `spawnmanager`, `sessionmanager` first
2. **Database:** `oxmysql` before anything that queries DB
3. **Framework:** Core resource (`es_extended`/`qb-core`) before dependent resources
4. **Utils:** `ox_lib` before resources that use it
5. **Your resources:** After all dependencies are loaded

---

## ACE Permissions (in server.cfg)

```cfg
# Define groups
add_ace group.admin command allow           # All commands
add_ace group.admin command.kick allow       # Specific command
add_ace group.moderator command.say allow   # Limited commands

# Add players to groups
add_principal identifier.steam:11000010xxxxx group.admin
add_principal identifier.license:xxxxxxxxx group.moderator

# Default denies
add_ace builtin.everyone command.restart deny
add_ace builtin.everyone command.stop deny
add_ace builtin.everyone resource.menu deny
```

**Better practice:** Use a separate `permissions.cfg` and include it:

```cfg
# In server.cfg
exec permissions.cfg
```

---

## Script Logging & Debugging

```cfg
# Console logging
sv_scriptLogLevel 3            # 0=none, 1=error, 2=warn, 3=info, 4=verbose
sv_scriptDebugInfo false       # Enable for debug, disable in production

# Error handling
sv_scriptHookLogLevel 3        # Hook logging level
sv_sqlTraceEnable false        # SQL query logging (debug only!)

# Print all resources loading
sv_forceResourceScan true      # Re-scan resources on server start
sv_enableResourceMetadataScan true
```

---

## Tags & Browser Display

```cfg
# Server tags (for filter/search in server browser)
sets tags "roleplay, economy, custom, active_admin"

# Discord invite
sets discord_invite "https://discord.gg/yourserver"

# Locale
sets locale "en-US"            # or "fi-FI", "sv-SE", etc.

# Banner image (must be a direct image URL)
sets banner_detail "https://i.imgur.com/yourbanner.png"
sets banner_connecting "https://i.imgur.com/yourbanner2.png"
```

---

## Player Limits & Queue

```cfg
# Queue system
sv_queueMaxPlayers 64          # Queue size
sv_queuePriorityLevel 1        # Priority for VIPs etc.

# Whitelist
sv_authMinTrustLevel 1         # 0=none, 1=basic, 2=steam, 3=fivem
sv_whitelistEnabled false      # Enable to restrict to whitelisted identifiers

# AFK kick
sv_afkTimer 600                # AFK kick after seconds (0 = disabled)
```

---

## Voice

```cfg
# Voice chat (built-in) — largely deprecated
# Most servers use pma-voice or a similar dedicated voice resource instead.
set voice_useNativeAudio true
set voice_useSendingRangeOnly true
set voice_defaultVolume 1.0

# 3D voice proximity
set voice_enableRadioChat false
set voice_radioChatVolume 0.3
set voice_proximityVolume 1.0
set voice_range 15.0           # Talk range in meters
set voice_enableProximity true
set voice_enableUi true
```

---

## Full Example server.cfg

```cfg
# --- Basic ---
sv_hostname "My FiveM Server [EU]"
sv_maxclients 48
sv_licenseKey "YOUR_KEY_HERE"
set steam_webApiKey "YOUR_STEAM_KEY"

# --- Game ---
sv_enforceGameBuild 3258
onesync on
onesync_forceMigrate true

# --- Network ---
sv_maxPing 300
sv_endpointPrivacy true

# --- Resources ---
ensure mapmanager
ensure spawnmanager
ensure sessionmanager
ensure basic-gamemode
ensure chat
ensure oxmysql
ensure es_extended
ensure ox_lib
ensure ox_inventory

# --- Permissions ---
exec permissions.cfg

# --- Metadata ---
sets tags "roleplay, custom, active"
sets discord_invite "https://discord.gg/yourserver"
sets locale "en-US"

# --- Voice ---
set voice_useNativeAudio true
set voice_defaultVolume 1.0
set voice_range 15.0

# --- Logging (production) ---
sv_scriptLogLevel 2
```

---

## Quick Reference — Common Convars

| Convar | Default | Description |
|--------|---------|-------------|
| `sv_maxclients` | 32 | Max players |
| `sv_enforceGameBuild` | 0 | Game build version |
| `onesync` | off | Entity streaming mode |
| `sv_scriptLogLevel` | 3 | Verbosity of script logs |
| `sv_maxPing` | 0 | Ping limit (0 = disabled) |
| `sv_endpointPrivacy` | false | Hide player IPs |
| `sv_forceIndirectListing` | false | Hide from server list |
| `sv_afkTimer` | 0 | AFK kick timeout (seconds) |
| `sv_authMinTrustLevel` | 0 | Minimum trust for auth |
| `sv_whitelistEnabled` | false | Enable whitelist |
