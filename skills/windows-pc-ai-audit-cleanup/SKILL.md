---
name: windows-pc-ai-audit-cleanup
description: >-
  Universal, interactive Windows PC audit, disk/system/service cleanup,
  development environment and AI model storage organization, and cross-client
  AI software/MCP/Skills governance. Adapts dynamically to any Windows 10/11
  machine regardless of drive letters, folder names, installed dev toolchains,
  or AI clients. Use when asked to audit, declutter, optimize, migrate, or
  organize a Windows PC, its dev environments, or its AI/MCP/Skills setup.
  Do not activate for single-file coding tasks or unrelated application bugs.
---

# Universal Windows PC, DevEnv & AI Ecosystem Audit, Cleanup & Organization

A machine-agnostic, step-by-step playbook for auditing, decluttering, and organizing **any** Windows 10/11 computer—whether single-drive (`C:` only) or multi-drive, SSD or HDD, laptop or desktop, with any combination of development toolchains and AI software.

Never assume fixed drive letters, folder names, or installed tools. Always discover what actually exists on the current machine first, align every structural decision with the user, execute safely in gated stages, and verify under real post-reboot conditions.

## Iron Safety Rules (Non-Negotiable on Every Machine)

1. **Discover Before Proposing; Confirm Before Mutating**: Phase 0 is 100% read-only. Never delete files, uninstall software, alter services/tasks/registry/env vars, or relocate directories until the user explicitly approves the scope and boundaries.
2. **Respect User Redlines Strictly**: Never silently alter antivirus/Windows Defender, Firewall, UAC, BitLocker, virtualization (Hyper-V, WSL2, Docker, Windows Sandbox), browser cookies/logins, chat history (WeChat/QQ/Telegram/Slack), personal Documents/Desktop/Downloads files, or any user-designated "do not touch" app/config.
3. **Zero Secret Exposure**: Never output raw tokens, API keys, bearer strings, passwords, SSH keys, or cookies from env vars or config files (`auth.json`, `config.toml`, `.gitconfig`, `.env`, `.credentials*`, `mcp*.json`). Always redact values before printing.
4. **Never Corrupt Live Databases or Active Builds**:
   - Check running processes before touching toolchains (`rustc`, `cargo`, `go`, `node`, `python`, `docker`) or AI/app databases (`SQLite` WAL files, protobuf/JSONL caches, browser profiles).
   - For active AI client databases or browsers, require the user to close the app completely (including system tray) before modifying its storage.
5. **Adapt to Real Disk & Tool Topology**:
   - Never assume a `D:` or `E:` drive exists. Detect actual drives and whether each is SSD/NVMe or HDD.
   - Ask before creating any directory junction/symlink. Verify `0` broken links and `0` stale config paths after any move.
6. **Never Guess on Unknowns, Portable Apps, or Duplicates**:
   - Never rely solely on the Uninstall registry—discover unregistered/deeply nested portable software via processes, shortcuts (`.lnk`), drive roots, and behavioral fingerprints.
   - Never blindly delete "duplicate" runtimes (bundled private runtimes vs competing global PATH runtimes) or unrecognized software/folders. Gather signature/metadata/last-used evidence and put unknowns in an explicit user-confirmation bucket.
7. **Plain-Language Decisions**: Present findings and options in concise everyday language. For every proposed change, clearly state **What**, **Why**, and **Impact / Risk / Rollback**.

---

## Universal 6-Phase Workflow

### Phase 0 — Dynamic Read-Only Discovery (Zero Mutations)
Run the universal read-only scanner to discover this specific PC's real hardware, drives, top space hogs, services, dev toolchains, and AI ecosystem (works in both PowerShell 7 `pwsh` and built-in Windows PowerShell 5.1 `powershell`):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\audit_pc_readonly.ps1"
# Or with built-in Windows PowerShell 5.1:
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\audit_pc_readonly.ps1"
```

Inspect what is **actually present on this PC**:
1. **Hardware, Drives & OS**: Drive letters, free space, SSD vs HDD media type, `pagefile.sys` / `hiberfil.sys` / `Windows.db` / `Windows.old`, boot error logs, power plan, laptop vs desktop network/battery traits, security & virtualization status.
2. **Dynamic Space Hogs**: Top large folders across `C:\`, `%USERPROFILE%`, `%LOCALAPPDATA%`, `%APPDATA%`, `C:\ProgramData` (caches, installers, browser profiles, WSL2/Docker `*.vhdx`, chat app caches, local AI model weights like Ollama/HuggingFace/LM Studio).
3. **Dev Toolchains & PATH**: Whichever languages, SDKs, package managers, and caches exist on this machine (`Rust`, `Go`, `Node/pnpm/npm/yarn/bun`, `Python/pip/uv/Conda/Poetry`, `Java/Gradle/Maven`, `.NET/NuGet`, `Android/Flutter`, `Docker/WSL`, `Git`).
4. **AI Clients, MCPs & Skills**: Dynamically locate installed AI IDEs/CLIs/desktop apps/local LLM runners, every MCP config file they use, every Skills directory (and dangling links), stale path references, and any multi-client orphaned chat storage.
5. **Deep/Portable Software, Duplicates & Unknowns**: Load [references/05-complex-cases-discovery-duplicates-unknowns.md](./references/05-complex-cases-discovery-duplicates-unknowns.md) whenever the PC has unregistered portable apps, deeply nested folders, competing duplicate runtimes/apps, or unfamiliar software/dot-directories.

If the user wants a full diagnostic report first, generate a clean numbered `.md` report (Problem → Proposed Fix → Impact/Risk) and pause for selection.

### Phase 1 — Interactive Alignment Interview (Mandatory Before Changes)
Using the real facts from Phase 0, guide the user through the decision menu in [references/01-interview-decision-matrix.md](./references/01-interview-decision-matrix.md). Never ask about tools not present on this PC; always cover the applicable choices:
- **Goal Scope**: Report-only / Full PC + Dev + AI / Dev + AI only / System-drive space rescue.
- **Redlines**: Security tools, virtualization (Hyper-V/WSL/Docker/Sandbox), active projects, chat apps, browser profiles, specific AI clients to leave untouched.
- **DevEnv & Large Model Storage**: Target drive/root folder (or single-drive cleanup strategy if only `C:` exists), pure env vars vs junctions, keeping fragile active Conda/venv shims intact.
- **AI MCP Architecture**: Where MCP servers should live (unified standalone folder vs per-client native config), isolated runtimes/venvs per server, and which AI clients should mount which MCPs.
- **AI Skills Architecture**: Single Source of Truth (e.g. `~/.agents/skills/` + zero-duplication junctions to other installed clients) vs independent per-client skills.
- **Cleanup Tier & Redundant Software**: Confirm Tier 1 (zero-risk caches) through Tier 4 (optional removals, hardware tuning, offline DB cleanup).

Echo back a short **"Will Do / Will NOT Touch"** confirmation checklist before executing.

### Phase 2 — Windows System, Disk, Services & Hardware Optimization
Load [references/02-windows-system-cleanup.md](./references/02-windows-system-cleanup.md) when OS cleanup or tuning is approved.
- Split tasks into **non-admin** and **admin** steps; handle UAC cleanly without hacks.
- Clean only confirmed pure caches, verified uninstalled-app leftovers (check missing `ImagePath` / setup logs), dead tasks/autostart/registry entries, bloated Search index (`Windows.db`), optional `hiberfil.sys` / `pagefile.sys` / WSL2 VHDX compaction, and hardware-appropriate power/HDD/Wi-Fi settings.

### Phase 3 — Development Environment & Model Storage Organization
Load [references/03-dev-env-migration.md](./references/03-dev-env-migration.md) when migrating or deduplicating dev toolchains, caches, or local AI model weights.
- Adapt automatically to the user's chosen drive/root (or single-drive layout) and only touch ecosystems actually installed on this PC.
- Verify no build processes hold locks, avoid breaking Conda `.exe` shims or thrashing spinning HDDs with 100k tiny-file copies, clean `PATH` duplicates/shadows and `.gitconfig` token leaks, and write a short `README` / `目录说明.txt` inside the target root.

### Phase 4 — AI Software, MCPs, Skills & Offline Chat Hygiene
Load [references/04-ai-ecosystem-mcp-skills.md](./references/04-ai-ecosystem-mcp-skills.md) when organizing AI clients, MCP servers, Skills, or chat databases.
- Uninstall user-approved redundant AI apps via official uninstallers before cleaning leftovers.
- Reorganize approved MCPs with isolated runtimes/venvs, update client configs cleanly, and **smoke-test every MCP entrypoint** (`node --check`, `py_compile`, venv import, live TLS check for proxy MCPs).
- Wire Skills per the user's chosen Single-Source-of-Truth layout, remove dangling junctions (`cmd /c rmdir`), and verify `0` broken links and `0` stale path references across all AI configs.
- If **T3 Code + Codex / AGY** are present and the user wants deleted-thread leftovers purged, run [scripts/cleanup_t3_orphans.py](./scripts/cleanup_t3_orphans.py) in `--dry-run` mode first and provide an offline `.cmd` launcher to execute only after exiting T3 Code.

### Phase 5 — Post-Reboot Real-Environment Verification
Whenever services, `pagefile.sys`, `PATH`, or persistent environment variables changed:
1. Ask the user to **reboot** (and drop back to normal non-admin user if elevated earlier).
2. Verify in a fresh shell **without** manual `$env:` overrides:
   - Before/after disk free space & `pagefile.sys` size.
   - Post-boot System & Application error logs (`0` new regressions).
   - Disabled bloat processes remain `0` running.
   - Every installed dev toolchain resolves cleanly, reports new cache/store paths, and did not recreate retired directories on `C:`.
   - Every active AI client starts cleanly, sees updated env vars, has `0` broken skill links, and passes MCP checks.

---

## Supporting Resources

- [references/01-interview-decision-matrix.md](./references/01-interview-decision-matrix.md) — Adaptive Phase 1 decision menu (drives, redlines, DevEnv, MCPs, Skills, cleanup tiers).
- [references/02-windows-system-cleanup.md](./references/02-windows-system-cleanup.md) — Universal Windows 10/11 disk, cache, service, registry, VHDX, and hardware optimization rules.
- [references/03-dev-env-migration.md](./references/03-dev-env-migration.md) — Universal multi-language DevEnv & AI model cache consolidation guide (multi-drive & single-drive).
- [references/04-ai-ecosystem-mcp-skills.md](./references/04-ai-ecosystem-mcp-skills.md) — Universal AI client inventory, MCP workbench setup, Cross-Client Skills SoT, and safe offline DB cleanup.
- [references/05-complex-cases-discovery-duplicates-unknowns.md](./references/05-complex-cases-discovery-duplicates-unknowns.md) — Deep/unregistered portable discovery, 3-way duplicate classification, and zero-guessing protocol for unseen/unknown software.
- [scripts/audit_pc_readonly.ps1](./scripts/audit_pc_readonly.ps1) — Zero-assumption, non-hanging read-only Windows PC + DevEnv + AI scanner.
- [scripts/cleanup_t3_orphans.py](./scripts/cleanup_t3_orphans.py) — Optional process-locked offline cleaner (dry-run by default) used only when T3 Code is installed.
