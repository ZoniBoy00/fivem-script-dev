# ACE Permissions — FiveM Access Control System

> ACE (Access Control Entry) is FiveM's native permission system. It controls who can execute commands, access resources, and use features.

## Core Concepts

| Concept | Description | Example |
|---------|-------------|---------|
| **Principal** | Identity — player, group, or resource | `identifier.steam:110000xxx`, `group.admin` |
| **ACE** | The permission itself | `command.kick`, `resource.admin_menu` |
| **Allow/Deny** | Grant or revoke | `allow` or `deny` |

### Basic Syntax

```cfg
add_ace <principal> <permission> <allow/deny>
add_principal <identifier> <group>
add_ace group.admin group.moderator allow    -- Inheritance
```

### Inheritance

Groups inherit hierarchically: `superadmin → admin → moderator → support`. A superadmin automatically gets everything below.

### Deny by Default

```cfg
add_ace builtin.everyone command.restart deny
add_ace builtin.everyone resource.admin_menu deny
add_ace group.superadmin command.restart allow
```

## Identifier Types

| Type | Format | Reliability |
|------|--------|------------|
| Steam ID | `identifier.steam:110000XXXXXX` | ⭐ Most stable |
| License | `identifier.license:XXXXXXXXXX` | ⭐ Stable |
| Discord | `identifier.discord:123456789` | ⭐ Stable |
| FiveM ID | `identifier.fivem:XXXXXXXXXX` | 🟡 Medium |
| IP | `identifier.ip:1.2.3.4` | ❌ Avoid |

## Complete Role Hierarchy

```cfg
# Default denies
add_ace builtin.everyone command.restart deny
add_ace builtin.everyone command.stop deny
add_ace builtin.everyone command.exec deny
add_ace builtin.everyone command.ensure deny
add_ace builtin.everyone txadmin deny

# Superadmin
add_ace group.superadmin command allow
add_ace group.superadmin txadmin allow
add_principal identifier.steam:110000XXXXXX group.superadmin

# Admin
add_ace group.admin command allow
add_ace group.admin txadmin.view allow
add_principal group.admin group.moderator allow

# Moderator
add_ace group.moderator command.kick allow
add_ace group.moderator command.ban allow
add_ace group.moderator command.warn allow
add_ace group.moderator command.spectate allow
add_principal group.moderator group.support allow

# Support
add_ace group.support command.tp allow
add_ace group.support command.revive allow
add_ace group.support command.staffchat allow

# VIP
add_ace group.vip command.car allow
add_ace group.vip vip.priority allow
```

## Job-Specific Permissions

```cfg
add_ace group.police police.armory allow
add_ace group.police police.handcuff allow
add_ace group.ems command.revive allow
add_ace group.mechanic mechanic.repair allow
```

## Checking in Scripts

```lua
-- Server
if IsPlayerAceAllowed(source, 'police.armory') then end

-- Client (via server round-trip)
TriggerServerEvent('myres:checkPerm')
RegisterNetEvent('myres:permResult')
AddEventHandler('myres:permResult', function(allowed) end)
```

## Restricting an Entire Resource

```cfg
add_ace builtin.everyone resource.my_menu deny
add_ace group.admin resource.my_menu allow
```

## ACE with ESX/QBCore/QBox

Works alongside framework permissions. Same `add_ace` syntax. QBCore maps ACE groups natively in its config.

## Testing Commands

```cfg
test_ace <identifier> <permission>
list_aces
list_principals
```

## Common Pitfalls

1. **Order matters** — Create group + ACE before adding principals
2. **Case-sensitive** — `Command.kick` ≠ `command.kick`
3. **Server restart required** — `refresh` doesn't reload ACE
4. **Permissions only work server-side** — Can't check directly on client

## Links

- FiveM ACE docs: https://docs.fivem.net/docs/server-manual/administering-with-ace-perm/
- ACE commands: https://docs.fivem.net/docs/server-manual/ace-commands/
