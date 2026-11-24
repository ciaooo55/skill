# Complex Real-World Cases: Deep/Unregistered Installs, Duplicates & Unknown Software

Real Windows PCs rarely look neat. Software is frequently unzipped into arbitrary nested folders without registering in Windows, installed multiple times across drives/scopes, or completely unfamiliar (new AI agents, niche regional tools, enterprise software). Follow this protocol whenever handling non-standard machines.

## 1. Finding Deeply Nested & Unregistered (Portable) Software

Never treat `Uninstall` registry keys as the complete inventory. Always combine **7 fast discovery channels** (all read-only, bounded so they never hang):

1. **Running Processes Outside Standard Paths**:
   - Inspect `Win32_Process.ExecutablePath` for any running binary NOT under `C:\Windows` or `C:\Program Files*`. Portable tools, cracked/green utilities, and custom daemons surface immediately.
2. **Shortcut Targets (`.lnk`)**:
   - Parse `.lnk` files on Desktop, Public Desktop, Start Menu, and Startup folders. Shortcuts reveal exact deep paths like `D:\Soft\2025\Tools\SomeApp\bin\app.exe` that never touched the registry.
3. **Top-Level Inventory of ALL Fixed Drives**:
   - List depth-1 (and selective depth-2) directories on every fixed drive (`C:\` excluding `Windows/Program Files*`, plus `D:\`, `E:\`, `F:\`...). Flag large or unfamiliar tool/software roots (`Tools`, `Soft`, `Green`, `Portable`, `AI`, `Dev`, `Apps`, etc.).
4. **Windows Execution & Association Traces (Optional Deep Dive)**:
   - Registry `HKLM/HKCU\...\App Paths`, `Environment\Path` entries, and `Scheduled Tasks` `Execute` paths often point straight to unregistered executables.
5. **Behavioral Fingerprints for Unregistered AI / MCP / Skills / Models**:
   - Do **not** rely only on a hardcoded list of known AI app names! When searching a user-approved software/workspace root (bounded depth, skipping `node_modules`/`.git`/`WinSxS`), detect unknown AI/dev components by **structural fingerprints**:
     - **Skills**: files named `SKILL.md`
     - **MCP Configs**: JSON/YAML/TOML files containing `"mcpServers"`, `mcp_servers`, or `transport: stdio`
     - **Local LLM Weights**: large `*.gguf`, `*.safetensors`, `*.onnx`, `*.ckpt`, `*.bin` (>500 MB)
     - **Virtual Disks**: `*.vhdx`, `*.vmdk`, `*.vdi`, `*.qcow2`
     - **Isolated Runtimes**: `pyvenv.cfg`, `conda-meta`, `node.exe`, `python.exe`, `rustc.exe`, `go.exe`, `java.exe`
     - **Portable Electron Apps**: directories containing `resources\app.asar`
6. **Fast Indexed Search If Available**:
   - If the PC has `Everything` CLI (`es.exe`) installed, leverage it for instant NTFS-level discovery of `SKILL.md`, `*.vhdx`, `*.gguf`, or duplicate binaries without disk thrashing.
7. **Unclassified Dot-Directories**:
   - Any `%USERPROFILE%\.*` folder not recognized as standard Windows/known dev/known AI should be inspected (file count, size, last-modified time, config filenames) rather than ignored or blindly deleted.

---

## 2. Handling Duplicate Software & Multiple Runtimes Safely

Duplicates are one of the #1 causes of "environment chaos" (`环境乱、依赖乱`), **and also one of the easiest ways to break working apps if cleaned recklessly**.

Always classify every duplicate into **3 distinct categories** before recommending any action:

### Category A — Intentionally Isolated / Bundled Runtime (DO NOT MERGE OR DELETE!)
- Examples:
  - Python/Node/JDK inside an app's own folder (`<App>\resources\runtime\`, `<App>\runtimes\`, `<MCP>\.venv\`, JetBrains `jbr\`, Android Studio `jbr\`, Electron bundled Node).
  - Project-local `.venv`, `node_modules`, or Conda environments (`~/.conda/envs/<name>`) actively used by specific tools/scripts.
- **Rule**: Keep untouched. Never "deduplicate" an app's private runtime by replacing it with a system binary.

### Category B — Competing Global Runtimes / PATH Shadows (ASK & ALIGN!)
- Examples:
  - System `Git 2.54` + Conda `mingw64 Git 2.53` + `PortableGit` all in `PATH`.
  - Official `Python 3.12` + `Microsoft Store Python` + `Anaconda` + `uv python`.
  - Standalone `Node.js` + `NVM` + `Volta` + `Conda Node`.
  - Two copies of an AI CLI (e.g. global `npm -g` version vs official standalone `.exe`).
- **Rule**:
  1. Show exact paths, versions, and **which one currently wins in `PATH`** (`Get-Command <cmd> -All`).
  2. Check if any active project, script, or AI client depends on a specific one (e.g. `node` & `pnpm` living inside a Conda env).
  3. Let the user decide: adjust `PATH` order, uninstall the redundant global copy, or keep both intentionally.

### Category C — Truly Redundant Duplicate Apps / Obsolete Versions (CONFIRM THEN CLEAN)
- Examples:
  - Same desktop app installed in both `Program Files` (All Users) and `AppData\Local\Programs` (Current User), or an old portable copy on `D:\` alongside a new installed copy on `C:\`.
  - Old abandoned runtime version folders (`rustup` old toolchains, `nvm` ancient Node versions, old `pnpm-store/v3` beside `v11`, old uninstalled app folders).
- **Rule**: Compare version, last-modified time, active shortcut target, and user data inside BOTH copies before removing the inactive duplicate. Never delete the copy that holds the user's current configs/chats!

---

## 3. Handling Unknown / Never-Seen-Before Software & Folders

You **will** encounter tools, AI apps, services, drivers, and directories that have never appeared on previous machines.

### Strict Zero-Guessing Protocol
1. **NEVER delete, disable, move, or uninstall an unrecognized item on your own.**
2. **Collect Factual Evidence First (Read-Only)**:
   - Digital signature & signer: `(Get-AuthenticodeSignature <exe>).SignerCertificate.Subject`
   - Binary metadata: `(Get-Item <exe>).VersionInfo | Select FileDescription, ProductName, CompanyName, ProductVersion`
   - Folder clues: top-level `README*`, `package.json`, `LICENSE`, `*.ini`, size, and **last-modified date**.
   - Usage clues: Is it currently running? In autostart? Referenced by a desktop/Start Menu shortcut or another config?
3. **High-Risk "Do Not Touch Unless Explicitly Told" Categories**:
   - **Banking / Tax / Government / Enterprise Security Controls** (网银助手、税务插件、企业 VPN/DLP/零信任客户端、U-Key/加密狗驱动).
   - **OEM Hardware & Peripheral Control Suites** (laptop power/fan/RGB/audio/hotkey services like ASUS, Lenovo, Dell, HP, MSI, Razer, Logitech).
   - **Game Anti-Cheat & DRM Services** (Vanguard, EasyAntiCheat, BattlEye, ACE, Steam/Epic helpers).
   - **Proxy / Tunnel / Network Drivers** (Clash/Mihomo/v2ray/Sing-box/Tailscale/ZeroTier/WireGuard/TAP/Wintun).
   - **Specialized Industry / Local Chinese Portable Tools** (accounting, CAD, video/audio plugins, phone flashing/backup tools).
4. **Research & Ask Plainly**:
   - If evidence is still unclear, briefly look up the product/signer name (when web search is available) or place it in a clearly labeled **"待你确认（不认识/首次见到的项目）"** list showing:
     - Name & path
     - Signer / probable purpose
     - Size & last-used date
     - Running / autostart status
   - Ask the user plainly whether they still use it before proposing any action.
