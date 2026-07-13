# Changelog

## 2.3.1 (2026-07-13)

### Fixed
- **QBox GetPlayer syntax** — corrected `qbx:GetPlayer(source)` → `exports.qbx_core:GetPlayer(source)` in SKILL.md framework comparison table
- **Ox Lib documentation link** — updated from deprecated `coxdocs.dev/ox_lib` to official `overextended.dev/docs` in SKILL.md and ox-lib.md
- **Method Selection Guide** — added missing Standalone (no framework) branch to decision tree
- **`lua54 'yes'` removed from fxmanifest.lua template** — Lua 5.4 is now the default runtime (June 2025+), directive is ignored
- **Duplicate link merged** — removed redundant Ox Lib/Overextended link from Links Reference
- **QBCore bridge mention** — added concrete bridge name (`qb-ox_inventory`) to the ox_inventory note

### Added
- **AI DIRECTIVE expanded** — now a clear 7-step decision tree telling the AI when to load references vs. when SKILL.md alone is enough
- **3 new Common Pitfalls** — #15 (rate limiting on server events), #16 (exports without pcall), #17 (lua54 'yes' deprecated)
- **Task → Reference Quick Map** — new table mapping 15 common tasks to the correct reference file and template
- **CHANGELOG.md** — this file

### Security
- Added cooldown recommendation for server events (Pitfall #15)

---

## 2.3.0 (2026-07-13)

### Added
- **AI DIRECTIVE** — explicit instruction block at top of SKILL.md for LLM guidance
- **3 new references:** `error-handling.md`, `onesync.md`, `server-cfg.md`
- **3 new templates:** `admin-command.lua`, `discord-webhook.lua`, `inventory-hooks.lua`
- **README.md** — GitHub publishing page with usage instructions, framework support table, contributing guide
- **.gitignore** and **MIT LICENSE** file

### Fixed
- **QBox resources table** — all 8 entries verified against live GitHub; 6 were incorrect (404 repos, archived repos, or wrong status)
- Added warning about stale online resource lists (Pitfall #14)
- Split QBox resources into ✅ Active and ❌ Archived sections

---

## 2.2.0 (2026-07-13)

- Initial structured release with 17 references + 5 templates
- ESX, QBCore, QBox, Ox ecosystem coverage
- Method Selection Guide per framework
- Ox First golden rule
- Security and optimization references
