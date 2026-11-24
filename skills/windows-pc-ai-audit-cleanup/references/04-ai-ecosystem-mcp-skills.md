# Phase 4: Universal AI Ecosystem, MCPs, Skills & Chat Storage Governance

Machine-agnostic procedures for auditing, organizing, and verifying **whatever AI software, MCP servers, Skills, and chat databases** exist on the target Windows PC.

## 1. Dynamic AI Software Inventory
Never assume a fixed set of AI tools. Discover everything installed across:
- Uninstall registry (`HKCU`, `HKLM`, `WOW6432Node`) and `AppData\Local\Programs`, `AppData\Roaming`, `AppData\Local`, non-system program folders.
- Home dot-directories: `.claude`, `.codex`, `.gemini`, `.t3`, `.dsh`, `.agents`, `.cursor`, `.windsurf`, `.trae`, `.opencode`, `.aider*`, `.ollama`, `.lmstudio`, `.cherrystudio`, `.cockpit_tools`, `.keysmith-switch`, etc.
- Present findings in 3 plain-language buckets:
  1. **Active Core**: Keep intact, verify versions, auth/ready state, and env inheritance.
  2. **Overlapping / Rarely Used**: Show last-modified date, disk size, and verify whether any user notes/prompts/chats live inside before asking whether to uninstall.
  3. **Abandoned Leftovers**: Old empty dot-dirs, installer caches, `.bak`/`.tmp` manifests.
- **Uninstalling Safely**: Always run the app's official uninstaller first, verify exit code `0`, then remove confirmed leftover folders.
- **Version Check Caveat**: Check versions via official manifests/releases/app metadata (`version`, `package.json`, `caches/*.json`, `gh api`, `<cli> --version`). **Never** call `agy.exe --version` (can block waiting on stdin/server).

## 2. Universal MCP Server Architecture & Verification
Adapt to whichever MCP-capable clients exist on this PC (Claude Desktop, Claude Code, Cursor, Windsurf, VS Code/Cline/Roo, Codex, Antigravity/AGY, T3 Code, DeepSeek Harness, Cherry Studio, etc.):

### Common MCP Config Locations (Discover Dynamically)
- Claude Desktop: `%APPDATA%\Claude\claude_desktop_config.json`
- Claude Code: `~/.claude.json` / `~/.claude/settings.json`
- Cursor: `~/.cursor/mcp.json`
- Windsurf: `~/.codeium/windsurf/mcp_config.json`
- Antigravity / AGY: `~/.gemini/config/mcp_config.json` (and T3-hosted `~/.t3/userdata/providers/antigravity/<hash>/config/mcp_config.json`)
- Codex: `~/.codex/config.toml` (`[mcp_servers.*]`) or `codex mcp list`
- DeepSeek Harness: `~/.dsh/cordis.patch.yml`
- VS Code / Cline / Roo: `%APPDATA%\Code\User\globalStorage\*\settings\*mcp*.json`

### Best-Practice Layout (When User Chooses Unified Hub)
```text
<MCP_ROOT>\
├── mcp\<server-name>\     # Self-contained code + isolated .venv or node_modules
├── runtimes\              # Optional pinned portable node/python/jdk
├── setup\                 # Thin launcher scripts (if custom env/browser flags needed)
├── config\                # Canonical mcp-servers.json reference
└── data\                  # Persistent working dirs / browser profiles / temp
```
- **Isolate Dependencies**: Give every Python MCP its own `.venv` (`uv venv` / `python -m venv`) and verify its `cwd` exists.
- **Selective Wiring**: Only register an MCP into the specific clients the user requested in Phase 1.
- **Mandatory Smoke Tests (For Every Configured MCP)**:
  1. Verify every `command`, `args` target file, `cwd`, and `env` path exists on disk.
  2. Syntax/import check (`node --check`, `python -I -m py_compile`, venv `python -c "import <pkg>"`).
  3. For HTTPS proxy MCPs (e.g., `mitmproxy-mcp`), verify root CA cert trust in Windows `LocalMachine\Root` (if user requested HTTPS interception) and run a real strict-TLS test + confirm the listening port closes cleanly afterward.

## 3. Universal Cross-Client Skills Governance

### Common Global Skill Directories (Discover Dynamically)
| Path | Clients That Discover It |
|---|---|
| `~/.agents/skills/<name>/SKILL.md` | Codex, DeepSeek Harness (`customSkillDirs`), open `.agents` standard |
| `~/.claude/skills/<name>/SKILL.md` | Claude Code |
| `~/.gemini/config/skills/<name>/SKILL.md` | Antigravity / AGY (standalone & T3-hosted ACP via junction) |
| `~/.cursor/skills/<name>/SKILL.md` | Cursor (if configured) |
| `~/.codex/skills/.system/` | Codex built-in system skills (never delete) |

### Single-Source-of-Truth Pattern (Recommended)
1. Keep one canonical copy of each custom skill (default `~/.agents/skills/<skill-name>/`, or user-chosen path).
2. Link into other installed clients' global skill folders via Windows directory junctions (`cmd /c mklink /J "<client-skills>\<name>" "<canonical>\<name>"`) only as approved by the user.
3. Audit every skill folder for broken junctions (`LinkType` set + target missing) and clean broken links with `cmd /c rmdir "<link>"`.
4. Scan all discovered AI config files and instruction files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `config.toml`, `mcp*.json`, `settings.json`, `cordis.patch.yml`) for stale paths pointing to deleted/moved directories—**always redacting secrets**!

## 4. Safe Offline AI Chat / Database Cleanup

### General Rule for ANY AI Client Database
- **NEVER** edit SQLite WAL databases (`*.sqlite`, `*.db`) or in-memory-cached JSONL/protobuf indexes while the owning AI client or its background daemon is running.
- Always inspect in `?mode=ro` first, present exact counts/titles to the user, and require a full app exit (including system tray) before modifying databases.

### Specialized Case: T3 Code <-> Codex <-> AGY Orphaned Conversations
**Only apply when `~/.t3/userdata/statev2.sqlite` exists on this PC:**
1. Deleting a thread in T3 Code marks `deleted_at` in T3, but can leave orphaned sessions in Codex (`~/.codex/state_5.sqlite`, `thread_history_1.sqlite`, `logs_2.sqlite`, `session_index.jsonl`, `sessions/*.jsonl`), T3-hosted AGY (`~/.t3/userdata/providers/antigravity/*/antigravity-acp/`), and orphaned T3 delegated subagents.
2. **Never match UUIDs via naive regex on free-text messages** (a deleted chat may merely *mention* an active chat's ID!). Always use structural ownership tables (`provider_threads`, `provider_sessions`, `parent_conversation_id`) and preserve all active sessions, native subagents, standalone sessions, and unmatched non-empty historical handoff segments.
3. Run [../scripts/cleanup_t3_orphans.py](../scripts/cleanup_t3_orphans.py) in default **dry-run** mode first to preview exact counts/sizes.
4. Provide a one-click `.cmd` launcher invoking `python -X utf8 "<script>" --execute` so the user runs it **only after completely exiting T3 Code**. The script enforces a hard running-process block, `PRAGMA foreign_keys=ON`, `defer_foreign_keys=ON`, `foreign_key_check`, `quick_check`, `wal_checkpoint(TRUNCATE)`, and atomic file writes.

## 5. Final AI Environment Health Check (Post-Reboot)
- Confirm each active AI client refreshes its environment cache (e.g., `~/.t3/userdata/shell-environment-cache.json`) after reboot and inherits the updated `PATH` and DevEnv vars.
- Confirm `0` broken skill junctions, `0` stale config paths, and every active MCP passes smoke tests.
