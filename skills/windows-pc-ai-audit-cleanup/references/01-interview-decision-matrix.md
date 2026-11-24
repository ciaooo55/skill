# Phase 1: Universal Interactive Decision Matrix

Run Phase 0 (`audit_pc_readonly.ps1`) **first** so every question adapts to the actual drives, folders, dev tools, and AI clients discovered on this specific PC. Keep questions concise, plain-spoken, and grouped into 1–2 short rounds with a clear `(Recommended)` default for each.

## 1. Scope & Workflow Mode
Let the user pick the depth of work:
- **Mode A — Read-Only Checkup Report First (Recommended on unfamiliar PCs)**: Produce a numbered `.md` report (Issue → Fix → Risk/Impact) and change nothing until the user selects items by number.
- **Mode B — Full PC + DevEnv + AI Organization**: Clean system/disk/services, organize dev toolchains & model caches, and govern AI clients/MCPs/Skills end-to-end.
- **Mode C — DevEnv & AI Ecosystem Only**: Leave Windows OS settings alone; only untangle dev toolchains, PATH, AI clients, MCP servers, and Skills.
- **Mode D — System Drive (`C:`) Space Rescue**: Strictly focus on safe disk space recovery (caches, installers, old OS/driver caches, optional offloading).

## 2. Hard Redlines ("Do Not Touch" Confirmation)
Explicitly confirm sensitive areas discovered in Phase 0 before touching anything:
- **Security Software**: Keep current Windows Defender / third-party antivirus / Windows Firewall state untouched unless explicitly requested.
- **Virtualization & Containers**: Ask whether Hyper-V, WSL2, Docker, VMware/VirtualBox, or Windows Sandbox are ever used (even occasionally) before touching virtualization services.
- **Personal & Work Data**: Always protect browser profiles/logins/cookies, chat histories (WeChat/QQ/Telegram/Slack/Discord), active project workspaces, SSH/GPG keys, and auth tokens/env vars.
- **Protected AI Clients**: Ask if any specific AI client (e.g., Cursor, Claude Code, Codex, AGY, Windsurf, VS Code) should remain untouched during this pass.

## 3. Drive Strategy & Dev Environment Placement
Adapt automatically to what Phase 0 found:
- **Case A — Multi-Drive PC (System `C:` + one or more data drives `D:` / `E:` / `F:` ...)**:
  - Show every available drive with **free space AND media type (SSD/NVMe vs HDD)**!
  - Let the user choose a target root folder (e.g., `<ChosenDrive>:\DevEnv\`).
  - Warn clearly about SSD vs HDD trade-offs: offloading package caches & AI models to HDD is great for C: relief, while active build directories / heavy toolchains run noticeably faster on SSD if one is available.
- **Case B — Single-Drive PC (`C:` only)**:
  - Do **not** suggest cross-drive migration. Instead offer:
    1. Clean pruning of duplicate versions, old caches, Docker/WSL VHDX compaction, and unused SDKs.
    2. Optional tidy unified folder (e.g., `C:\DevEnv\`) for easy backup/visibility if the user wants centralized caches.
- **Migration Style (Ask Explicitly)**:
  - **Pure Environment Variables + Tool Configs (Recommended)**: Cleanest, zero junctions/symlinks on `C:`.
  - **Directory Junctions (`mklink /J`)**: Only when a legacy tool ignores env vars and the user consents to junctions.
- **Fragile Coupled Environments**:
  - If Phase 0 finds Node/Python/Git living inside an existing Conda/virtual env on `C:`, explain that moving it directly breaks hardcoded Windows `.exe` shims. Recommend keeping the existing env in place while pointing future envs & package caches (`.condarc`, `PIP_CACHE_DIR`, `UV_CACHE_DIR`) to the target drive.

## 4. AI MCP Server Placement & Wiring (Only Ask If User Uses MCPs)
Let the user decide how to organize MCP servers across whatever AI clients exist on this PC:
1. **Where to Store MCP Servers**:
   - **Unified Standalone Hub (Recommended for >=2 MCPs)**: A single user-chosen root (e.g., `<ChosenDrive>:\AI-MCP\` or `<ChosenDrive>:\Tools\mcp\`) with one self-contained folder per MCP (`mcp/<name>/`), plus dedicated `runtimes/`, `config/`, `data/` folders. Easy to back up, inspect, and move across machines.
   - **Client-Managed / Native Only**: Leave MCP configs inside each client's default folder (simpler if only using 1–2 remote/npx MCPs).
2. **Dependency Isolation**:
   - **Isolated `.venv` / local `node_modules` per MCP (Recommended)**: Prevents upgrading system Python/Node from breaking MCP servers.
3. **Selective Client Wiring**:
   - List the AI clients actually installed on this PC (e.g. Claude Desktop, Claude Code, Cursor, Windsurf, VS Code/Cline, Codex, AGY, DeepSeek Harness, Cherry Studio) and ask **which clients should connect to which MCPs**. Never inject an MCP into every client unasked.

## 5. AI Skills Placement & Cross-Client Sync (Only Ask If User Uses Agent Skills)
Show the skill directories discovered in Phase 0 and offer clear choices:
- **Option 1 — Single Source of Truth + Junctions (Recommended)**:
  - Pick one canonical folder (default: `%USERPROFILE%\.agents\skills\`, or a user-chosen folder on a data drive).
  - Clients that natively read `~/.agents/skills/` or support custom skill directories read directly.
  - Other installed clients (e.g. `~/.claude/skills/`, `~/.gemini/config/skills/`, `~/.cursor/skills/`) link selectively via Windows directory junctions (`mklink /J`) — edit once, zero duplicate copies, zero version drift.
- **Option 2 — Independent Per-Client Skills**:
  - Keep separate copies per client (choose only when the user intentionally wants different skill versions for different models).
- Always ask permission before deleting any non-empty custom skill; always clean dangling/broken links.

## 6. Cleanup Aggressiveness & Optional Software/OS Choices
Present concrete findings from Phase 0 grouped into **4 tiers** (with estimated MB/GB saved):
- **Tier 1 — Zero-Risk Junk**: `%TEMP%`, `CrashDumps`, already-installed app updaters/installers, rotated logs, pure browser/Electron HTTP/GPU caches, Windows Update download cache, WER archive, obsolete NVIDIA/AMD driver unpack folders (`C:\NVIDIA`, `C:\AMD`).
- **Tier 2 — Hygiene & Broken Leftovers**: Verified zombie services (missing binary `ImagePath`), dead scheduled tasks, broken Uninstall entries, dead autostart items, abandoned empty browser profiles, bloated `Windows.db` search index reset, dangling skill junctions.
- **Tier 3 — User-Choice Removals & Tuning**:
  - Unused / overlapping AI apps or bundled OS apps (show last-used date, size, and check for user docs inside first).
  - Large reclaimables: `hiberfil.sys` (only if user doesn't use Hibernate/Fast Startup), `Windows.old` (only if user doesn't need OS rollback), WSL2/Docker `*.vhdx` compaction, `pagefile.sys` tuning (only when RAM >= 16 GB and `C:` is tight), offloading Ollama/HuggingFace/LM Studio model caches.
  - Hardware-appropriate tuning: AC CPU min state (if stuck at 100%), secondary HDD AC spin-down (if HDD exists), Wi-Fi prefer 5GHz (if Wi-Fi exists), disabling Widgets/Edge background boost/OS ad suggestions.
- **Tier 4 — Offline Database / Chat Cleanup**:
  - Multi-client orphaned AI chat records (e.g., deleted T3 Code threads left in Codex/AGY) or app DB compaction — always previewed via dry-run and executed **only after closing the app**.

## 7. Duplicates, Portable Apps & Unknown Items Confirmation
Whenever Phase 0 discovers any of the following, present them in a dedicated confirmation table before acting (never guess!):
- **Competing Duplicates** (e.g. multiple Python/Node/Git/AI CLI installs or User + Machine dual installs of the same app): show path, version, which one wins `PATH`, and ask which to keep as primary (always keep intentionally bundled app-private runtimes!).
- **Unregistered / Deeply Nested Portable Tools**: show where `.lnk` shortcuts, running processes, or drive-root scans found them; ask whether to keep in place, consolidate into a tidy folder, or remove.
- **Unrecognized / Never-Seen-Before Items**: show path, publisher signature, size, and last-used date; explicitly ask the user whether they still use it (watch out for banking/tax/enterprise/anti-cheat/OEM hardware utilities).

## 8. Execution Contract Before Starting
Once the user answers, summarize in <=8 concise bullets:
- **Approved scope & target paths** (exact drive/folder names the user picked)
- **Will NOT touch** (all confirmed redlines)
Then proceed cleanly without repeatedly asking for permission on already-approved steps.
