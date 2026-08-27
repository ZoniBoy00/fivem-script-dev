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
add_principal group.moderator group.admin    # Inheritance
```

### Inheritance

ACE has no implicit group hierarchy. Declare every parent relationship explicitly with `add_principal`; the first principal inherits from the second:

```cfg
add_principal group.superadmin group.admin
add_principal group.moderator group.admin
add_principal group.moderator group.support
```

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
# Grant only the commands each role needs. Avoid combining a broad
# `command allow` grant with explicit `command.* deny` entries, because
# the explicit deny can continue to win during ACE evaluation.

# Superadmin
add_ace group.superadmin command allow
add_ace group.superadmin txadmin allow
add_principal identifier.steam:110000XXXXXX group.superadmin

# Admin
add_ace group.admin command.kick allow
add_ace group.admin command.ban allow
add_ace group.admin txadmin.view allow
add_principal group.admin group.moderator

# Moderator
add_ace group.moderator command.kick allow
add_ace group.moderator command.ban allow
add_ace group.moderator command.warn allow
add_ace group.moderator command.spectate allow
add_principal group.moderator group.support

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

- FiveM ACE docs: https://docs.fivem.net/docs/server-manual/server-commands/#access-control-commands
- ACE commands: https://docs.fivem.net/docs/server-manual/server-commands/#access-control-commands
