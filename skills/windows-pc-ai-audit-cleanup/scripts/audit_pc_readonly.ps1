<#
.SYNOPSIS
Universal, zero-assumption, non-hanging, 100% READ-ONLY audit script for ANY Windows 10/11 PC.
Discovers hardware, drives (SSD vs HDD), dynamic top space hogs, boot errors, power/Wi-Fi,
security/virtualization status, dev toolchains & PATH conflicts, AI clients, MCP configs,
Skills health, zombie services, autostart, and memory usage.
Never mutates any file, service, or registry key; never prints raw secret values.
#>
[CmdletBinding()]
param(
    [int]$TopFolders = 12,
    [int]$MaxFilesPerDir = 80000
)

$ErrorActionPreference = 'SilentlyContinue'
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
if (Get-Variable -Name PSStyle -ErrorAction SilentlyContinue) { $PSStyle.OutputRendering = 'PlainText' }

if (-not ('FastDirSizer' -as [type])) {
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

public static class FastDirSizer {
    public struct DirStats {
        public long Bytes;
        public int Files;
        public bool Capped;
    }
    public static DirStats Measure(string root, int maxFiles, int maxMs) {
        var st = new DirStats();
        if (!Directory.Exists(root)) return st;
        var sw = Stopwatch.StartNew();
        var stack = new Stack<DirectoryInfo>();
        stack.Push(new DirectoryInfo(root));
        while (stack.Count > 0) {
            var dir = stack.Pop();
            FileInfo[] files = null;
            try { files = dir.GetFiles(); } catch { continue; }
            for (int i = 0; i < files.Length; i++) {
                st.Files++;
                try { st.Bytes += files[i].Length; } catch {}
                if (st.Files >= maxFiles || ((st.Files & 511) == 0 && sw.ElapsedMilliseconds >= maxMs)) {
                    st.Capped = true;
                    return st;
                }
            }
            DirectoryInfo[] subdirs = null;
            try { subdirs = dir.GetDirectories(); } catch { continue; }
            for (int i = 0; i < subdirs.Length; i++) {
                try {
                    if ((subdirs[i].Attributes & FileAttributes.ReparsePoint) == 0) {
                        stack.Push(subdirs[i]);
                    }
                } catch {}
            }
            if (sw.ElapsedMilliseconds >= maxMs) {
                st.Capped = true;
                return st;
            }
        }
        return st;
    }
}
"@ -ErrorAction SilentlyContinue
}

function Get-FastDirSizeMB([string]$Path, [int]$FileCap = 60000, [int]$MaxMs = 1500) {
    if (-not (Test-Path $Path)) { return $null }
    $st = [FastDirSizer]::Measure($Path, $FileCap, $MaxMs)
    $mb = [math]::Round($st.Bytes / 1MB, 1)
    if ($st.Capped) { return "${mb}+ MB (capped)" }
    return "$mb MB"
}

function Get-TopSubdirs([string]$Root, [int]$TopN = 8, [int]$FileCap = 50000, [string[]]$SkipNames = @()) {
    if (-not (Test-Path $Root)) { return @() }
    $rows = @()
    foreach ($d in (Get-ChildItem $Root -Directory -Force)) {
        if ($d.LinkType -or ($SkipNames -contains $d.Name)) { continue }
        $st = [FastDirSizer]::Measure($d.FullName, $FileCap, 1200)
        $mb = [math]::Round($st.Bytes / 1MB, 1)
        if ($mb -ge 50) {
            $rows += [PSCustomObject]@{ Path = $d.FullName; MB = $mb; Note = $(if ($st.Capped) { "capped (>=${mb}MB)" } else { "$($st.Files) files" }) }
        }
    }
    return ($rows | Sort-Object MB -Descending | Select-Object -First $TopN)
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "================ 1. OS, HARDWARE, PHYSICAL DISKS & VOLUMES ================"
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cs = Get-CimInstance Win32_ComputerSystem
$chassis = (Get-CimInstance Win32_SystemEnclosure | Select-Object -First 1).ChassisTypes
$isLaptop = ($chassis | Where-Object { $_ -in 8,9,10,11,12,14,18,21,30,31,32 }).Count -gt 0
Write-Host ("OS: {0} (Build {1}) | LastBoot: {2} | IsAdmin: {3}" -f $os.Caption, $os.BuildNumber, $os.LastBootUpTime, $isAdmin)
Write-Host ("CPU: {0} | RAM: {1} GB total / {2} GB free | FormFactor: {3}" -f $cpu.Name.Trim(), [math]::Round($os.TotalVisibleMemorySize/1MB,2), [math]::Round($os.FreePhysicalMemory/1MB,2), $(if ($isLaptop) {'Laptop'} else {'Desktop/Other'}))

Write-Host "`nPhysical Disks (MediaType & Health):"
Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus,@{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}} | Format-Table -AutoSize

Write-Host "Logical Volumes:"
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID,VolumeName,
    @{N='SizeGB';E={[math]::Round($_.Size/1GB,2)}},
    @{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,2)}},
    @{N='UsedPct';E={[math]::Round((1-$_.FreeSpace/$_.Size)*100,1)}} | Format-Table -AutoSize

Write-Host "System Files (pagefile / swapfile / hiberfil / Windows.old / Windows.db):"
Get-ChildItem "$env:SystemDrive\pagefile.sys","$env:SystemDrive\swapfile.sys","$env:SystemDrive\hiberfil.sys" -Force |
    Select-Object Name,@{N='GB';E={[math]::Round($_.Length/1GB,2)}} | Format-Table -AutoSize
Write-Host ("  Windows.old exists: {0}" -f (Test-Path "$env:SystemDrive\Windows.old"))
$wdb = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.db"
$wedb = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb"
if (Test-Path $wdb) { Write-Host ("  Search Windows.db:  {0} MB" -f [math]::Round((Get-Item $wdb -Force).Length/1MB,1)) }
elseif (Test-Path $wedb) { Write-Host ("  Search Windows.edb: {0} MB" -f [math]::Round((Get-Item $wedb -Force).Length/1MB,1)) }
else { Write-Host "  Search DB:          (requires admin to inspect size)" }

Write-Host "`n================ 2. BOOT ERRORS, POWER, WIFI & SECURITY ================"
$boot = $os.LastBootUpTime
$sysErr = @(Get-WinEvent -FilterHashtable @{LogName='System';Level=2;StartTime=$boot} -MaxEvents 20)
$appErr = @(Get-WinEvent -FilterHashtable @{LogName='Application';Level=2;StartTime=$boot} -MaxEvents 20)
Write-Host ("Errors since boot -> System: {0} | Application: {1}" -f $sysErr.Count, $appErr.Count)
if ($sysErr.Count -gt 0) { $sysErr | Select-Object -First 5 TimeCreated,ProviderName,Id,@{N='Msg';E={($_.Message -split "`n")[0]}} | Format-Table -AutoSize }
if ($appErr.Count -gt 0) { $appErr | Select-Object -First 5 TimeCreated,ProviderName,Id,@{N='Msg';E={($_.Message -split "`n")[0]}} | Format-Table -AutoSize }

$pCpu = (powercfg /q SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN | Select-String 'AC Power|交流电源') -join ' | '
$pDsk = (powercfg /q SCHEME_CURRENT SUB_DISK DISKIDLE | Select-String 'AC Power|交流电源') -join ' | '
Write-Host "Power AC PROCTHROTTLEMIN: $pCpu"
Write-Host "Power AC DISKIDLE:        $pDsk"

$wifi = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and ($_.InterfaceDescription -match 'Wi-Fi|Wireless|802\.11|WLAN' -or $_.Name -match 'WLAN|Wi-Fi') })
if ($wifi.Count -gt 0) {
    Write-Host "Active Wi-Fi:"
    netsh wlan show interfaces | Select-String 'Radio type|Channel|Receive rate|无线电类型|信道|接收速率' | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "Active Wi-Fi: None (Ethernet or offline)"
}

$defSvc = Get-Service WinDefend
Write-Host ("Security (READ-ONLY) -> WinDefend: {0} ({1})" -f $defSvc.Status, $defSvc.StartType)
Get-NetFirewallProfile | ForEach-Object { Write-Host ("  Firewall {0}: Enabled={1}" -f $_.Name, $_.Enabled) }
$virt = @('vmms','LxssManager','cmservice','com.docker.service') | ForEach-Object { $s = Get-Service $_; if ($s) { "$($s.Name)=$($s.Status)/$($s.StartType)" } }
Write-Host ("Virtualization Services: " + ($(if ($virt) { $virt -join ', ' } else { 'None detected' })))

Write-Host "`n================ 3. DYNAMIC TOP SPACE HOGS ON SYSTEM DRIVE ================"
foreach ($scanItem in @(
    @{ Root=$env:USERPROFILE; Skip=@('AppData') },
    @{ Root=$env:LOCALAPPDATA; Skip=@() },
    @{ Root=$env:APPDATA; Skip=@() }
)) {
    Write-Host "--- Top dirs >= 50 MB in $($scanItem.Root) ---"
    $top = Get-TopSubdirs -Root $scanItem.Root -TopN $TopFolders -FileCap $MaxFilesPerDir -SkipNames $scanItem.Skip
    if ($top) { $top | Format-Table -AutoSize } else { Write-Host "  (none >= 50 MB)" }
}
Write-Host "--- Notable Extra Large Folders (if present) ---"
foreach ($extra in @(
    "$env:SystemDrive\NVIDIA", "$env:SystemDrive\AMD", "$env:SystemDrive\Intel",
    "$env:SystemRoot\SoftwareDistribution\Download",
    "$env:ProgramData\NVIDIA\NGX\models",
    "$env:ProgramData\Package Cache",
    "$env:LOCALAPPDATA\Docker\wsl",
    "$env:LOCALAPPDATA\Packages",
    "$env:USERPROFILE\.ollama",
    "$env:USERPROFILE\.cache",
    "$env:USERPROFILE\.lmstudio"
)) {
    if (Test-Path $extra) {
        Write-Host ("  {0,-50} : {1}" -f $extra, (Get-FastDirSizeMB $extra 40000))
    }
}

Write-Host "`n================ 4. DEV TOOLCHAINS, ENV VARS & PATH CHECK ================"
$devVars = @('RUSTUP_HOME','CARGO_HOME','GOPATH','GOMODCACHE','GOCACHE','PNPM_HOME','npm_config_cache','YARN_CACHE_FOLDER','BUN_INSTALL_CACHE_DIR','ELECTRON_CACHE','PIP_CACHE_DIR','UV_CACHE_DIR','POETRY_CACHE_DIR','CONDA_PKGS_DIRS','HF_HOME','TORCH_HOME','OLLAMA_MODELS','GRADLE_USER_HOME','NUGET_PACKAGES','ANDROID_HOME','ANDROID_SDK_ROOT','PUB_CACHE','PLAYWRIGHT_BROWSERS_PATH','SE_CACHE_PATH')
foreach ($k in $devVars) {
    $v = [Environment]::GetEnvironmentVariable($k)
    if ($v) { Write-Host ("  {0,-24} = {1} (exists={2})" -f $k, $v, (Test-Path $v)) }
}
Write-Host "`nDetected Dev & CLI Commands (first 3 PATH hits each):"
foreach ($c in @('rustc','cargo','go','node','npm','pnpm','yarn','bun','nvm','fnm','volta','python','pip','uv','conda','poetry','java','mvn','gradle','dotnet','flutter','docker','wsl','git','gh','scoop','choco','winget')) {
    $hits = @(Get-Command $c -All)
    if ($hits.Count -gt 0) {
        $paths = ($hits | Select-Object -First 3 | ForEach-Object { $_.Source }) -join ' ; '
        Write-Host ("  {0,-8} -> {1}" -f $c, $paths)
    }
}
Write-Host "`nBroken or Duplicate User PATH Entries:"
$uPath = @([Environment]::GetEnvironmentVariable('Path','User') -split ';' | Where-Object { $_ -and $_.Trim() -ne '' })
$seen = @{}
foreach ($p in $uPath) {
    $norm = $p.Trim().TrimEnd('\').ToLower()
    if ($seen.ContainsKey($norm)) { Write-Host "  [DUPLICATE] $p" }
    elseif (-not (Test-Path $p)) { Write-Host "  [MISSING]   $p" }
    $seen[$norm] = $true
}

Write-Host "`n================ 5. AI SOFTWARE, MCP CONFIGS & SKILLS DISCOVERY ================"
$aiRegex = 't3|codex|antigravity|agy|deepseek|dsh|claude|gemini|cursor|trae|windsurf|zed|opencode|kiro|cherry|chatbox|lm.?studio|ollama|anythingllm|comfyui|typeless|roxy|keysmith|cockpit|qoder|codebuddy|aider'
$uninst = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
Write-Host "Installed AI Apps:"
Get-ItemProperty $uninst | Where-Object { $_.DisplayName -match $aiRegex } |
    Select-Object DisplayName,DisplayVersion,InstallLocation | Format-Table -AutoSize

Write-Host "Home AI Dot-Directories:"
Get-ChildItem $env:USERPROFILE -Force -Directory | Where-Object { $_.Name -match "^(\.)?($aiRegex|agents|mcp)" } |
    Select-Object Name,LastWriteTime,@{N='Link';E={$_.LinkType}} | Format-Table -AutoSize

Write-Host "Discovered MCP Config Files:"
$mcpCandidates = @(
    "$env:APPDATA\Claude\claude_desktop_config.json",
    "$env:USERPROFILE\.claude.json",
    "$env:USERPROFILE\.claude\settings.json",
    "$env:USERPROFILE\.cursor\mcp.json",
    "$env:USERPROFILE\.codeium\windsurf\mcp_config.json",
    "$env:USERPROFILE\.gemini\config\mcp_config.json",
    "$env:USERPROFILE\.codex\config.toml",
    "$env:USERPROFILE\.dsh\cordis.patch.yml"
)
Get-ChildItem "$env:USERPROFILE\.t3\userdata\providers\antigravity" -Directory | ForEach-Object {
    $mcpCandidates += (Join-Path $_.FullName "config\mcp_config.json")
}
foreach ($mc in $mcpCandidates) {
    if (Test-Path $mc) {
        $it = Get-Item $mc -Force
        Write-Host ("  [MCP CFG] {0} ({1} bytes, {2})" -f $mc, $it.Length, $it.LastWriteTime)
    }
}

Write-Host "`nDiscovered Skill Directories & Broken Link Check:"
$skillCandidates = @(
    "$env:USERPROFILE\.agents\skills",
    "$env:USERPROFILE\.claude\skills",
    "$env:USERPROFILE\.gemini\config\skills",
    "$env:USERPROFILE\.codex\skills",
    "$env:USERPROFILE\.cursor\skills",
    "$env:USERPROFILE\.windsurf\skills"
)
Get-ChildItem "$env:USERPROFILE\.t3\userdata\providers\antigravity" -Directory | ForEach-Object {
    $skillCandidates += (Join-Path $_.FullName "config\skills")
}
foreach ($sr in $skillCandidates) {
    if (Test-Path $sr) {
        $srItem = Get-Item $sr -Force
        $items = @(Get-ChildItem $sr -Force)
        $broken = @($items | Where-Object { $_.LinkType -and (-not (Test-Path $_.FullName)) })
        $linkNote = if ($srItem.LinkType) { " [dir-link->$($srItem.Target)]" } else { "" }
        Write-Host ("  {0}{1} -> total={2}, broken={3}" -f $sr, $linkNote, $items.Count, $broken.Count)
        foreach ($b in $broken) { Write-Host ("    [BROKEN] {0} -> {1}" -f $b.Name, ($b.Target -join ',')) }
    }
}

Write-Host "`n================ 6. ZOMBIE SERVICES, AUTOSTART & TOP RAM ================"
Write-Host "Potential Zombie Auto/Manual Services (missing binary on disk):"
Get-CimInstance Win32_Service | Where-Object { $_.PathName -and $_.PathName -notmatch 'svchost\.exe' } | ForEach-Object {
    $raw = $_.PathName.Trim()
    $exe = if ($raw.StartsWith('"')) { ($raw -split '"')[1] } else { ($raw -split '\s+')[0] }
    $exe = [Environment]::ExpandEnvironmentVariables($exe)
    if ($exe -match '^[A-Za-z]:\\' -and (-not (Test-Path $exe))) {
        [PSCustomObject]@{ Name=$_.Name; State=$_.State; StartMode=$_.StartMode; MissingBinary=$exe }
    }
} | Format-Table -AutoSize

Write-Host "Autostart (HKCU & HKLM Run):"
foreach ($rk in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')) {
    $props = Get-ItemProperty $rk
    if ($props) {
        Write-Host "  [$rk]"
        $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
            Write-Host ("    {0} = {1}" -f $_.Name, $_.Value)
        }
    }
}

Write-Host "`nTop 8 RAM Processes:"
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 Name,@{N='MB';E={[math]::Round($_.WorkingSet64/1MB,0)}} | Format-Table -AutoSize

Write-Host "`n================ 7. PORTABLE/DEEP APPS, DUPLICATES & UNKNOWNS ================"
Write-Host "Running Processes Outside Windows / Program Files (unregistered/portable candidates):"
Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and
    $_.ExecutablePath -notmatch '^C:\\Windows\\' -and
    $_.ExecutablePath -notmatch '^C:\\Program Files( \(x86\))?\\'
} | Select-Object Name,ExecutablePath -Unique | Sort-Object Name | Format-Table -AutoSize

Write-Host "Desktop & Start Menu Shortcuts Pointing Outside Windows / Program Files:"
$wsh = New-Object -ComObject WScript.Shell
$lnkRoots = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory'),
    [Environment]::GetFolderPath('StartMenu'),
    [Environment]::GetFolderPath('CommonStartMenu')
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
$portableLnks = @()
foreach ($lr in $lnkRoots) {
    foreach ($f in (Get-ChildItem $lr -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue)) {
        try {
            $t = $wsh.CreateShortcut($f.FullName).TargetPath
            if ($t -and $t -notmatch '^C:\\Windows\\' -and $t -notmatch '^C:\\Program Files( \(x86\))?\\' -and $t -match '^[A-Za-z]:\\') {
                $portableLnks += [PSCustomObject]@{ Shortcut=$f.BaseName; Target=$t; Exists=(Test-Path $t) }
            }
        } catch {}
    }
}
if ($portableLnks.Count -gt 0) {
    $portableLnks | Sort-Object Target -Unique | Select-Object -First 35 | Format-Table -AutoSize
} else {
    Write-Host "  (none)"
}

Write-Host "Top-Level Directories Across ALL Fixed Drives (excluding standard OS folders):"
$osSkip = @('Windows','Program Files','Program Files (x86)','ProgramData','Users','Recovery','PerfLogs','$Recycle.Bin','System Volume Information','Config.Msi','Documents and Settings','MSOCache')
foreach ($vol in (Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3")) {
    $root = "$($vol.DeviceID)\"
    $dirs = @(Get-ChildItem $root -Directory -Force | Where-Object { $osSkip -notcontains $_.Name -and $_.Name -notmatch '^\$' })
    if ($dirs.Count -gt 0) {
        Write-Host ("  [{0}] ({1} top-level folders): {2}" -f $vol.DeviceID, $dirs.Count, (($dirs | Select-Object -First 30 -ExpandProperty Name) -join ', '))
    }
}

Write-Host "`nCompeting / Duplicate Commands in PATH (same command in >1 distinct folder):"
foreach ($c in @('rustc','cargo','go','node','npm','pnpm','yarn','bun','python','pip','uv','conda','java','mvn','gradle','dotnet','git','gh','codex','claude','gemini','cursor','code','ollama','docker','t3')) {
    $hits = @(Get-Command $c -All | Where-Object { $_.Source -match '^[A-Za-z]:\\' })
    $uniqDirs = @($hits | ForEach-Object { Split-Path $_.Source -Parent } | Select-Object -Unique)
    if ($uniqDirs.Count -gt 1) {
        Write-Host ("  [MULTI] {0,-8} ({1} dirs) -> {2}" -f $c, $uniqDirs.Count, (($hits | ForEach-Object { $_.Source }) -join ' | '))
    }
}

Write-Host "`nDuplicate Uninstall Entries (excluding normal side-by-side Windows/VC++/.NET runtimes):"
$runtimeSkipRe = '^(microsoft visual c\+\+|microsoft \.net|microsoft windows desktop runtime|microsoft asp\.net|universal crt|office \d+ click-to-run|windows software development kit|vs_)'
$allUninst = @(Get-ItemProperty $uninst | Where-Object { $_.DisplayName -and $_.DisplayName -notmatch $runtimeSkipRe })
$dups = $allUninst | Group-Object { ($_.DisplayName -replace '\s+\d+(\.\d+)*.*$','').Trim().ToLower() } | Where-Object { $_.Count -gt 1 }
if ($dups) {
    foreach ($g in ($dups | Select-Object -First 15)) {
        Write-Host ("  [DUP APP] {0} (x{1}): {2}" -f $g.Name, $g.Count, (($g.Group | ForEach-Object { "$($_.DisplayName) [$($_.DisplayVersion)]" }) -join ' ; '))
    }
} else {
    Write-Host "  (none)"
}

Write-Host "`nUnclassified Home Dot-Directories (inspect before touching - may be unknown AI/dev tools):"
$knownDotRe = '^\.((agents|anaconda|android|antigravity|aws|azure|bashrc|bun|cache|claude|codex|conda|config|cursor|docker|dotnet|dsh|gemini|gitconfig|gnupg|gradle|ipython|java|jupyter|keras|kube|lmstudio|local|m2|mitmproxy|npm|nuget|ollama|opencode|pip|pnpm|poetry|profile|pyenv|rustup|cargo|ssh|t3|trae|uv|vscode|windsurf|yarn|zshrc).*)$'
$unkDots = @(Get-ChildItem $env:USERPROFILE -Force -Directory | Where-Object { $_.Name -like '.*' -and $_.Name -notmatch $knownDotRe })
if ($unkDots.Count -gt 0) {
    $unkDots | Select-Object Name,LastWriteTime,@{N='Size';E={Get-FastDirSizeMB $_.FullName 10000}} | Format-Table -AutoSize
} else {
    Write-Host "  (none)"
}

