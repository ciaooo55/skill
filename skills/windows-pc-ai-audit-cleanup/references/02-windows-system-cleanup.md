# Phase 2: Universal Windows 10/11 System, Disk, Services & Hardware Cleanup

Machine-agnostic guidelines for safely reclaiming space and fixing OS/service/hardware issues on any Windows 10/11 PC (Chinese or English locale, laptop or desktop, single-drive or multi-drive).

## 1. Privilege & UAC Discipline
- Detect current privilege first (`IsInRole(Administrator)`).
- Execute all **non-admin** work first (user caches, user autostart, user-scope uninstallers, user env vars).
- Non-elevated agent shells on Windows often reject `Start-Process -Verb RunAs`. Never attempt UAC bypasses. When admin tasks are approved:
  1. Ask the user to relaunch the client/terminal as Administrator temporarily (and remind them to return to normal non-admin after reboot), OR
  2. Write a readable, commented `.ps1`/`.cmd` script for the user to review and run as Administrator.

## 2. Anti-Hang Scanning & Safe Deletion Rules
- **NEVER** run `Get-ChildItem -Recurse` blindly on `C:\`, `AppData`, or massive `node_modules`/`.pnpm-store`/`pkg\mod` trees. Use .NET `[System.IO.Directory]::EnumerateFiles()` (with `AttributesToSkip = ReparsePoint`) or `robocopy <dir> NULL /L /S /XJ /BYTES /NFL /NDL /NJH`.
- **Spinning HDD Small-File Trap**: Deleting or copying 100,000+ tiny files on a 5400/7200 rpm HDD can hang for >30 minutes. Always prefer tool-native cleanup (`go clean -modcache`, `pnpm store prune`, `conda clean --all`, `docker system prune`) or warn the user and defer non-urgent HDD giant-store deletions if that drive already has abundant free space.
- **Never `Remove-Item -Recurse` on a Junction/Symlink**: Check `LinkType` first; remove directory junctions/symlinks safely with `cmd /c rmdir "<path>"` so the link target is never wiped!

## 3. Universal Disk Space Recovery Checklist

### Tier 1 — Pure Caches & Temp (Zero Data Loss)
- `%TEMP%`, `C:\Windows\Temp` (admin), `%LOCALAPPDATA%\CrashDumps`, `C:\ProgramData\Microsoft\Windows\WER\ReportArchive`.
- Installed app updater caches (`%LOCALAPPDATA%\*-updater\*.exe`, `pending\*.exe`, Squirrel/Electron downloaded installers) — **never** delete app user configs or databases.
- Rotated old logs (`*.log.old`, `*.ndjson.\d+`, `*.log.\d+`), keeping current active logs.
- GPU driver unpack leftovers (`C:\NVIDIA\DisplayDriver`, `C:\AMD`, `C:\Intel\ExtremeGraphics` — unpack installers only, NOT installed `Program Files` drivers!).
- **Browser Pure Caches ONLY**: `Cache`, `Cache_Data`, `Code Cache`, `GPUCache`, `GrShaderCache`, `cache2\entries` across Chrome/Edge/Brave/Firefox/Arc/Quark. **NEVER** touch `Cookies`, `Login Data`, `Web Data`, `Bookmarks`, `Local Storage`, `places.sqlite`, `logins.json`, `key4.db`.
- **Electron / Chat App Pure Caches ONLY** (Discord, Slack, Teams, VS Code, Notion, CloudMusic, etc.): `Cache`, `Code Cache`, `GPUCache`, `CachedData`. **NEVER** touch WeChat `WeChat Files\...\Msg` or QQ `Tencent Files` message databases—only mention them as user-managed via the app's own Storage Management UI.
- Windows Update download cache (`C:\Windows\SoftwareDistribution\Download\*`, stopping `wuauserv` & `bits` first, restarting after).

### Tier 2 — System Reclaimables (Confirm With User First)
- **Windows Search Index (`Windows.db` / `Windows.edb`)**: If >1 GB:
  1. `Stop-Service WSearch -Force`
  2. Delete `C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.db*` (and `.edb` on Win10).
  3. **CRITICAL**: Set `HKLM:\SOFTWARE\Microsoft\Windows Search` → `SetupCompletedSuccessfully = 0` so `WSearch` actually rebuilds cleanly instead of staying `Stopped`!
  4. `Start-Service WSearch` and confirm `Status = Running`.
- **Component Store / Old OS (`Admin`)**:
  - Check `C:\Windows.old` (reclaim via `DISM` or Storage Sense only if user confirms they won't roll back Windows).
  - Run `Dism /Online /Cleanup-Image /StartComponentCleanup` when `C:\Windows\WinSxS` is bloated (avoid `/ResetBase` unless user understands updates become permanent).
- **WSL2 / Docker Desktop `ext4.vhdx` Compaction** (when huge reclaimed space isn't returned to Windows):
  - `wsl --shutdown`, then `Optimize-VHD -Path <vhdx> -Mode Full` (Pro/Hyper-V) or `diskpart` `compact vdisk` — warn user to close all WSL/Docker workloads first.
- **Hibernation (`C:\hiberfil.sys`)**: Only offer `powercfg /h off` (or `/h /type reduced`) if `C:` is critically tight AND user confirms they do not use Hibernate.
- **Pagefile (`C:\pagefile.sys`)**: Only cap when `C:` is SSD-constrained (<=256 GB), RAM >= 16 GB, and auto-managed pagefile bloated past 8+ GB (e.g., `2048–6144 MB` for 16 GB RAM; `4096–8192 MB` if heavy VMs/builds). Never disable pagefile completely (`0 MB` breaks crash dumps and causes app OOMs!). Verify size after reboot.

## 4. Zombie Services, Scheduled Tasks, Autostart & Registry
- **Prove Dead Before Deleting**: Only classify a service, task, or Uninstall entry as zombie when its target executable (`ImagePath` / `Execute` / `UninstallString`) no longer exists on disk AND/OR setup logs confirm prior uninstallation.
- **Avoid Hanging `Stop-Service`**: Broken telemetry/AV driver services often hang `Stop-Service`. Use:
  1. Official uninstaller first (`msiexec /x {GUID} /qn /norestart` or vendor uninstaller) if still installed.
  2. Otherwise `sc.exe config "<svc>" start= disabled` + `Stop-Process -Force` (if needed) + `sc.exe delete "<svc>"` (only for verified dead/missing-binary services).
- **Scheduled Tasks**: Inspect non-Microsoft tasks (`Get-ScheduledTask | Where-Object TaskPath -notlike '\Microsoft\*'`) for missing binaries, crashing updaters, or `SkipUAC` leftovers from uninstalled tools.
- **Autostart (`Run` & `StartupApproved`)**: Check `HKCU` & `HKLM` `Run` keys, Startup folders, AND `HKU\.DEFAULT` / `S-1-5-19` / `S-1-5-20` for leaked user-app autostart entries. Clean dead `StartupApproved\Run` entries whose apps are gone.

## 5. Hardware-Adaptive Tuning (Apply Only What Matches This PC)
- **Check Disks First**: Only apply HDD AC spin-down disable (`powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK DISKIDLE 0`) if the machine actually has a mechanical HDD!
- **Check CPU Min State on AC**: Inspect `powercfg /q SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN`. If stuck at `100%` (`0x64`) on a laptop causing constant heat/fan noise, lower AC min to `5%` and run `powercfg /setactive SCHEME_CURRENT`.
- **Check Wi-Fi Adapter**: Only tune 5GHz preference if an active wireless adapter exists (`Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.MediaType -match '802\.11' }`). Match the advanced property by localized/English `DisplayName` (`Preferred Band` / `首选频带`)—never hardcode one vendor's keyword (Intel uses `RoamingPreferredBandType`, Realtek/MediaTek differ)—and pass `-NoRestart` so active connections don't drop.
- **Optional UI/Background Bloat (User-Approved Only)**:
  - Edge background drain: `HKLM:\SOFTWARE\Policies\Microsoft\Edge` → `StartupBoostEnabled=0`, `BackgroundModeEnabled=0`.
  - Widgets: `HKLM:\SOFTWARE\Policies\Microsoft\Dsh` → `AllowNewsAndInterests=0`.
  - P2P Update upload: `DODownloadMode=0`.
  - GameDVR / Bing Search Suggestions / Explorer ads / silent consumer app installs.
