---
name: windows-pc-ai-audit-cleanup
description: >-
  Flexible, universal Windows PC cleanup and AI/MCP/Skills organization skill.
  Supports BOTH full end-to-end PC audit/cleanup/DevEnv migration AND standalone
  on-demand modes—especially consolidating MCP servers and Agent Skills into one
  clean shared copy usable across all installed AI clients (and portable across
  multiple PCs) without hardcoded paths or rigid steps. Adapts dynamically to any
  Windows 10/11 machine, drive layout, dev toolchain, or AI ecosystem. Do not
  trigger for single-file coding edits or unrelated application bugs.
---

# Universal Windows PC & AI (MCP / Skills) Organizer

A flexible, machine-agnostic playbook that works **either as a full PC cleanup suite OR as standalone focused workflows**—with zero hardcoded drives, folder names, or fixed AI client lists.

## Choose Your Mode First (Never Be Rigid)

Route directly to what the user actually asked for—skip irrelevant phases and questions:

| User Goal | Entry Mode | What to Run / Read |
|---|---|---|
| **Only organize MCP servers & Skills** (keep 1 clean copy shared across all installed AI apps / syncable across PCs) | **Standalone AI MCP & Skills Mode** | Run `audit_pc_readonly.ps1 -Mode AiOnly` → read [04-ai-ecosystem-mcp-skills.md](./references/04-ai-ecosystem-mcp-skills.md) + Section 4–5 of [01-interview-decision-matrix.md](./references/01-interview-decision-matrix.md). **Skip OS/disk/DevEnv steps.** |
| **Full PC checkup, cleanup & organization** (system + disk + DevEnv + AI) | **Full Suite Mode** | Run `audit_pc_readonly.ps1 -Mode Full` → follow Phases 0 → 5 below, loading references on demand. |
| **Only C: space rescue / OS tuning** | **Disk & System Mode** | Run `audit_pc_readonly.ps1 -Mode DiskOnly` → read [02-windows-system-cleanup.md](./references/02-windows-system-cleanup.md). |
| **Only fix messy dev toolchains / PATH / caches** | **DevEnv Mode** | Inspect toolchains/PATH → read [03-dev-env-migration.md](./references/03-dev-env-migration.md). |
| **Only clean orphaned AI chat databases (e.g. T3 ↔ Codex ↔ AGY)** | **Offline Chat Hygiene Mode** | Run [scripts/cleanup_t3_orphans.py](./scripts/cleanup_t3_orphans.py) (`--dry-run` first) → read Section 4 of [04-ai-ecosystem-mcp-skills.md](./references/04-ai-ecosystem-mcp-skills.md). |

---

## Iron Safety Rules (Enforce in Every Mode)

1. **Discover Before Proposing; Confirm Before Mutating**: Always inspect read-only first. Never delete files, uninstall apps, alter services/registry/env vars, or rewrite client configs until the user approves scope and paths.
2. **Respect User Redlines Strictly**: Never silently alter antivirus/Windows Defender, Firewall, UAC, BitLocker, virtualization (Hyper-V, WSL2, Docker, Windows Sandbox), browser logins/cookies, chat histories (WeChat/QQ/Telegram/Slack), personal files, or any client the user marks "do not touch".
3. **Zero Secret Exposure**: Never print raw tokens, API keys, bearer values, passwords, SSH keys, or cookies (`auth.json`, `config.toml`, `.gitconfig`, `.env`, `.credentials*`, `mcp*.json`). Always redact values before display.
4. **Never Corrupt Live Databases or Active Builds**: Check active processes before touching toolchains or SQLite/JSONL/protobuf stores. Require closing the owning app (including system tray) before modifying its live databases.
5. **No Hardcoded Paths & Transparent Linking**:
   - Dynamically discover drives (SSD vs HDD), installed AI clients, and user-preferred directories. Never assume fixed drive letters or folder names.
   - Always explain **in plain language** the choice between **Single Source of Truth + Junction/Symlink** ("only 1 real copy, other AI apps share it via folder shortcut so edits auto-sync everywhere") vs **Plain Entity Copies** ("no links on disk; separate real folders synced by copy"). Let the user pick; never create symlinks/junctions without explaining why.
6. **Never Guess on Unknowns, Portable Apps, or Duplicates**:
   - Discover deeply nested / unregistered portable tools via processes, `.lnk` shortcuts, drive roots, and behavioral fingerprints—not just the Uninstall registry.
   - Never blindly delete private bundled runtimes or unrecognized software; inspect signatures/metadata/last-used dates and put unknowns into an explicit user-confirmation list.
7. **Plain-Language Communication**: Keep every question and summary concise and jargon-free, stating **What**, **Why**, and **Impact / Rollback**.

---

## Adaptive Execution Workflow

### Phase 0 — Dynamic Read-Only Discovery (Scoped to Mode)
Run the scanner in the mode matching the user's request (works in both `pwsh` 7 and built-in Windows PowerShell 5.1 `powershell`):

```powershell
# Full PC audit:
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\audit_pc_readonly.ps1" -Mode Full
# Standalone MCP & Skills only (completes in ~1-2 seconds):
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\audit_pc_readonly.ps1" -Mode AiOnly
# Disk & OS space rescue only:
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\audit_pc_readonly.ps1" -Mode DiskOnly
# (Replace `pwsh` with `powershell` on machines without PowerShell 7.)
```

- When encountering deeply nested portable tools, duplicate runtimes/apps, or unfamiliar software/dot-directories, load [references/05-complex-cases-discovery-duplicates-unknowns.md](./references/05-complex-cases-discovery-duplicates-unknowns.md).
- If the user wants a diagnostic report before deciding, generate a clean numbered `.md` report (Issue → Fix → Risk/Impact).

### Phase 1 — Interactive Decision Alignment (Ask Only Relevant Questions)
Use [references/01-interview-decision-matrix.md](./references/01-interview-decision-matrix.md) to align choices concisely—**only ask questions relevant to the active mode and what actually exists on this PC**:
- **Standalone MCP & Skills Mode**: Where should the single master MCP folder and Skills folder live? Junction/Symlink (recommended, 1 copy shared across all clients & multi-PC Git sync) OR plain folder copies? Which installed AI clients should connect to which MCPs and Skills?
- **Full Suite Mode**: Additionally confirm redlines, drive/DevEnv placement (adapting to single-drive vs multi-drive, SSD vs HDD), cleanup tier (Tier 1–4), and any discovered duplicates/unknowns.

Echo back a short **"Will Do / Will NOT Touch"** checklist before making changes.

### Phase 2 — Windows System, Disk, Services & Hardware (Full / Disk Modes Only)
Load [references/02-windows-system-cleanup.md](./references/02-windows-system-cleanup.md) for safe UAC split, pure cache cleanup, zombie services/tasks/registry, `Windows.db` reset, optional `pagefile.sys` / `hiberfil.sys` / WSL VHDX compaction, and hardware-adaptive power/HDD/Wi-Fi tuning.

### Phase 3 — Development Environment & Model Storage (Full / DevEnv Modes Only)
Load [references/03-dev-env-migration.md](./references/03-dev-env-migration.md) for zero-duplication multi-language DevEnv & AI model cache consolidation (adapting cleanly to multi-drive or single-drive machines, avoiding Conda shim and HDD tiny-file traps).

### Phase 4 — AI Software, Single-Copy MCP Hub, Cross-Client Skills & Chat Hygiene
Load [references/04-ai-ecosystem-mcp-skills.md](./references/04-ai-ecosystem-mcp-skills.md) for:
- **Single-Copy MCP Hub**: Consolidate duplicate MCP servers into one clean self-contained directory per MCP (isolated `.venv`/runtime, zero hardcoded user paths), wire only user-selected AI clients to that single copy, and smoke-test every entrypoint.
- **Cross-Client & Multi-PC Skills Hub**: Maintain one canonical Skills directory (optionally backed by a Git repo for multi-PC sync), link (or copy, per user preference) into every installed AI client's global skill folder, remove dangling links (`cmd /c rmdir`), and verify `0` broken links and `0` stale config paths.
- **Optional Orphaned Chat Cleanup**: If T3 Code + Codex/AGY exist and cleanup is approved, run [scripts/cleanup_t3_orphans.py](./scripts/cleanup_t3_orphans.py) (`--dry-run` first) and provide an offline `.cmd` launcher for execution after exiting T3 Code.

### Phase 5 — Verification (Immediate or Post-Reboot)
- **Standalone MCP & Skills Mode** (no reboot required): Verify `0` broken links, every MCP passes syntax/import/runtime smoke test, all client config JSON/TOML/YAML parse cleanly with `0` stale paths, and skills resolve cleanly across all linked clients.
- **Full Suite / DevEnv / OS Modes**: After reboot (and returning to non-admin if elevated), verify real inherited env vars (no manual `$env:` overrides), disk space & `pagefile.sys`, `0` new boot errors, `0` disabled bloat processes, `0` recreated retired C: folders, and live tool + AI client health.

---

## Supporting Resources

- [references/01-interview-decision-matrix.md](./references/01-interview-decision-matrix.md) — Adaptive decision menu (modes, redlines, drives, MCP/Skills single-source vs copy choice, duplicates & unknowns).
- [references/02-windows-system-cleanup.md](./references/02-windows-system-cleanup.md) — Universal Windows 10/11 disk, cache, VHDX, service, registry, and hardware optimization rules.
- [references/03-dev-env-migration.md](./references/03-dev-env-migration.md) — Universal DevEnv & AI model cache consolidation guide (multi-drive & single-drive).
- [references/04-ai-ecosystem-mcp-skills.md](./references/04-ai-ecosystem-mcp-skills.md) — Standalone Single-Copy MCP & Cross-Client/Multi-PC Skills hub setup, AI inventory, and offline chat cleanup.
- [references/05-complex-cases-discovery-duplicates-unknowns.md](./references/05-complex-cases-discovery-duplicates-unknowns.md) — Deep/unregistered portable discovery, 3-way duplicate classification, and zero-guessing protocol for unseen software.
- [scripts/audit_pc_readonly.ps1](./scripts/audit_pc_readonly.ps1) — Universal read-only scanner supporting `-Mode Full | AiOnly | DiskOnly` (PowerShell 5.1 & 7 compatible).
- [scripts/cleanup_t3_orphans.py](./scripts/cleanup_t3_orphans.py) — Optional process-locked offline cleaner (dry-run by default) used only when T3 Code is present.
