# FiveM Script Development — AI Context Pack

> **A comprehensive, battle-tested knowledge pack for AI-assisted FiveM script development.**  
> Supports ESX, QBCore, QBox, and the Ox ecosystem with production-ready templates and security best practices.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![FiveM](https://img.shields.io/badge/FiveM-cfx.re-blue)](https://docs.fivem.net/docs/)
[![Ox](https://img.shields.io/badge/Ox-Overextended-green)](https://overextended.dev/docs)

---

## 📦 What's Inside

```
gaming/fivem-script-dev/
├── SKILL.md                           ← Master reference + usage guide
├── references/                        ← 20 focused reference documents
│   ├── fivem-basics.md               Resource structure, manifest, events
│   ├── lua-for-fivem.md              Lua best practices for FiveM
│   ├── scripting-languages.md        Lua vs JS vs C# comparison
│   ├── esx-framework.md              ESX (xPlayer, jobs, inventory)
│   ├── qbcore-framework.md           QBCore (Player, jobs, gangs)
│   ├── qbox-framework.md             QBox (bridge, FAQ, QBCore→QBox)
│   ├── ox-lib.md                     UI, callbacks, zones, commands
│   ├── oxmysql.md                    Queries, transactions, placeholders
│   ├── ox-inventory-target.md        Inventory & target exports
│   ├── ace-permissions.md            ACE groups, identifiers, allow/deny
│   ├── common-patterns.md            Shop, doors, vehicles, whitelist
│   ├── standalone-and-bridge.md      Multi-framework bridge patterns
│   ├── custom-integrations.md        Paid scripts, custom notify/target
│   ├── fivem-nui.md                  NUI HTML/JS ↔ FiveM communication
│   ├── fivem-security.md             Anti-exploit, server authority
│   ├── onesync.md                    Routing buckets, entity migration
│   ├── server-cfg.md                 Convars, game builds, commands
│   ├── error-handling.md             pcall, debugging, defensive code
│   ├── other-resources.md            Fivemanage, state bags
│   └── optimization.md               Variable wait, caching, events
└── templates/                         ← 8 production-ready templates
    ├── fxmanifest.lua                 Universal manifest template
    ├── nui/                           Full NUI scaffold (HTML/CSS/JS)
    ├── esx-resource.lua               ESX resource scaffold
    ├── qbcore-resource.lua            QBCore resource scaffold
    ├── qbox-resource.lua              QBox resource scaffold
    ├── oxmysql-queries.lua            Database query patterns
    ├── admin-command.lua              ACE + rate limits + Discord logging
    ├── discord-webhook.lua            Rich embed logger with presets
    └── inventory-hooks.lua            ox_inventory items, shops, crafting
```

---

## 🎯 Who Is This For?

| Role | Benefit |
|------|---------|
| **FiveM Server Owners** | Get AI-generated scripts that follow modern standards from day one |
| **FiveM Script Developers** | Reference battle-tested patterns and avoid common security/performance pitfalls |
| **AI Users (ChatGPT, Claude, Gemini)** | Feed the `references/` files as context — the AI will write correct, secure, and optimized Lua |
| **ESX → QBox Migrators** | Dedicated QBox reference with conversion guide |

---

## 🚀 How to Use with AI

### Option 1: Feed one reference at a time (recommended)

When asking an AI to help with a specific task, include the relevant reference:

> "Write a FiveM shop script using ESX. Follow the patterns in this reference:"
> 
> [paste `references/esx-framework.md`]

### Option 2: Load the full pack into an AI agent

If your AI agent supports skills (like Hermes, Claude Code, OpenCode):

```bash
# Copy the skill into your AI agent's skills directory
cp -r fivem-script-dev ~/.hermes/skills/gaming/
```

The AI will then automatically reference the correct patterns when you ask FiveM-related questions.

### Option 3: Templates for rapid scaffolding

Use templates when starting a new resource:

```bash
cp templates/esx-resource.lua my_new_resource/server.lua
cp templates/fxmanifest.lua my_new_resource/
```

---

## 🧠 Core Philosophies

### 🔒 Never Trust the Client
Every action that affects game state, economy, or other players **must** be validated on the server. The client is fully compromised.

### 🦊 Ox First
Prefer the Ox ecosystem (ox_lib, ox_inventory, oxmysql, ox_target) over custom implementations. Ox is lighter, more secure, and the community standard.

### ⚡ Performance by Default
Variable wait intervals, event-driven zones, state bags over event spam — every reference document includes performance considerations.

### 🔧 Framework-Agnostic Patterns
Common patterns (shops, doors, vehicles) are written with adapters for ESX, QBCore, and QBox — not locked into one framework.

---

## 📚 Framework Support

| Framework | Status | Notes |
|-----------|--------|-------|
| **ESX Legacy** | ✅ Full support | `es_extended`, xPlayer API |
| **QBCore** | ✅ Full support | `qb-core`, Player object |
| **QBox** | ✅ Full support | `qbx_core`, Ox-native |
| **Standalone** | ✅ Supported | Ox ecosystem only |

---

## 🔗 Quick Links

- [FiveM Documentation](https://docs.fivem.net/docs/)
- [FiveM Natives](https://docs.fivem.net/natives/)
- [ESX Framework](https://docs.esx-framework.org/)
- [QBCore Documentation](https://docs.qbcore.org/qbcore-documentation)
- [QBox Documentation](https://docs.qbox.re/)
- [Ox Lib Docs](https://coxdocs.dev/ox_lib)
- [Overextended Docs](https://overextended.dev/docs)
- [FiveM Performance Guide](https://forum.cfx.re/t/best-practice-improve-your-resource-performance/105509)
- [FiveM Native UI (NUI)](https://docs.fivem.net/docs/game-references/nui/)
- [FiveM ACE Permissions](https://docs.fivem.net/docs/server-manual/permissions/)

---

## 🤝 Contributing

Found an issue? Want to add a reference for another framework or common pattern? PRs welcome!

1. Fork the repository
2. Add or update a reference in `references/` or template in `templates/`
3. Update `SKILL.md` if adding new files
4. Submit a PR

**Guidelines:**
- Keep references focused (one topic per file)
- Prefer Ox ecosystem patterns where applicable
- Include security and performance notes in every reference
- Mark framework-specific code with `-- ADAPT:` comments

---

## 📄 License

MIT — free to use, modify, and share. Attribution appreciated but not required.

---

*Built for AI-assisted FiveM development. Maintained by [ZoniBoy00](https://github.com/ZoniBoy00).*
