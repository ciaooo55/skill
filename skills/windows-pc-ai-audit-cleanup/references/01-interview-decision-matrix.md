# Phase 1: Universal Interactive Decision Matrix

Run Phase 0 (`audit_pc_readonly.ps1`) **first** so every question adapts to the actual drives, folders, dev tools, and AI clients discovered on this specific PC. Keep questions concise, plain-spoken, and grouped into 1–2 short rounds with a clear `(Recommended)` default for each.

## 1. Scope & Workflow Mode
Adapt to what the user requested—never force a full PC overhaul if they only want one module:
- **Mode A — Standalone AI MCP & Skills Organizer (Fast, Zero OS Changes)**: Skip OS/disk/DevEnv cleanup completely. Consolidate MCP servers and Agent Skills into **one clean shared copy** usable by all installed AI clients (and portable across PCs).
- **Mode B — Full PC + DevEnv + AI Suite**: Complete checkup, system/disk/service cleanup, DevEnv & model cache consolidation, and AI/MCP/Skills governance end-to-end.
- **Mode C — Read-Only Checkup Report First (Recommended on unfamiliar PCs)**: Produce a numbered `.md` report (Issue → Fix → Risk/Impact) and change nothing until the user selects items by number.
- **Mode D — Focused Single-Domain Pass**: Pick only one—System Drive (`C:`) Space Rescue, DevEnv & PATH Deduplication, or Offline AI Chat Database Cleanup.

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

## 4. AI MCP Server Placement & Single-Copy Sharing
Let the user decide flexibly—never hardcode a fixed drive or folder name:
1. **Where to Keep the Single Master MCP Hub**:
   - **Unified Standalone Folder (Recommended for >=2 MCPs or multi-client sharing)**: User chooses ANY convenient location (e.g., a folder on a data drive, inside a workspace root, or in user home). Inside it, keep **one self-contained folder per MCP** (`mcp/<server-name>/`) with its own isolated `.venv` / `node_modules` / runtime so upgrading one never breaks another.
   - **Keep In-Place / Client-Managed**: Leave existing MCPs where they are if only 1–2 lightweight remote/npx servers exist.
2. **One Copy Shared Across Chosen Clients**:
   - List every MCP-capable AI client actually discovered on this PC (e.g. Codex, AGY, T3 Code, Claude Code, Claude Desktop, Cursor, Windsurf, VS Code/Cline/Roo, DeepSeek Harness, Cherry Studio, or any newly discovered client).
   - Ask **which clients should connect to which MCPs**. Every selected client's config points to that **exact same single MCP entrypoint**—zero duplicate MCP copies! Never silently inject MCPs into clients the user didn't pick.

## 5. AI Skills Placement & Cross-Client / Multi-PC Sharing
Show all skill folders discovered in Phase 0 and explain the two sharing options **in plain everyday language** before creating any link:
- **Option 1 — Single Master Copy + Folder Link / Junction (Recommended)**:
  - Plain-language explanation for the user: *"只在你选的一个主目录（甚至直接放进你的 Git 仓库里）存 1 份真实文件；其它 AI 软件通过类似‘文件夹快捷方式’的目录联接指向这 1 份。改一次全部 AI 软件自动同步最新版、不占双份空间，换一台电脑拉下来也能一键连上所有 AI 软件。"*
  - Works on Windows via Directory Junction (`mklink /J` / `New-Item -ItemType Junction`, **no Admin needed**) and macOS/Linux via `ln -s`.
- **Option 2 — Independent Real Folders / Copy-Sync (If User Dislikes Links)**:
  - Keep normal entity folders in each client's global skill directory with zero symlinks/junctions; optionally provide a simple sync/copy script when updating from a master folder.
- **Master Folder Choice**: Let the user pick ANY path (e.g., `~/.agents/skills/`, a Git repo like `<UserChosenPath>\skill\skills\`, or a data-drive folder). Never force a hardcoded path.
- Always ask permission before deleting any non-empty custom skill; always offer to clean dangling/broken links.

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
