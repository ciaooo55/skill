<#
.SYNOPSIS
One-click Windows installer/uninstaller for all skills in this repository.
Creates Windows Directory Junctions (no Administrator privileges required) so
all selected AI clients share this repo as a Single Source of Truth.

.EXAMPLE
.\install-windows.ps1
.\install-windows.ps1 -Targets agents,gemini,claude,cursor
.\install-windows.ps1 -Skills windows-pc-ai-audit-cleanup
.\install-windows.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [string[]]$Targets = @('agents', 'gemini'),
    [string[]]$Skills = @(),
    [switch]$Force,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
$skillsRoot = Join-Path $repoRoot 'skills'

$validTargets = @('agents','gemini','claude','cursor')
$Targets = @($Targets | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
foreach ($t in $Targets) {
    if ($validTargets -notcontains $t) {
        throw "Invalid target '$t'. Allowed values: $($validTargets -join ', ')"
    }
}
$Skills = @($Skills | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

if (-not (Test-Path $skillsRoot)) {
    throw "Skills directory not found: $skillsRoot"
}

$targetMap = @{
    agents = Join-Path $env:USERPROFILE '.agents\skills'
    gemini = Join-Path $env:USERPROFILE '.gemini\config\skills'
    claude = Join-Path $env:USERPROFILE '.claude\skills'
    cursor = Join-Path $env:USERPROFILE '.cursor\skills'
}

$discovered = @(Get-ChildItem $skillsRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') })
if ($Skills.Count -gt 0) {
    $discovered = @($discovered | Where-Object { $Skills -contains $_.Name })
}
if ($discovered.Count -eq 0) {
    Write-Host "No matching skills found under $skillsRoot." -ForegroundColor Yellow
    exit 0
}

foreach ($t in $Targets) {
    $destBase = $targetMap[$t]
    Write-Host "`n[$t] -> $destBase" -ForegroundColor Cyan
    if (-not $Uninstall -and (-not (Test-Path $destBase))) {
        New-Item -ItemType Directory -Path $destBase -Force | Out-Null
    }
    if (-not (Test-Path $destBase)) { continue }

    foreach ($sk in $discovered) {
        $srcPath = $sk.FullName
        $dstPath = Join-Path $destBase $sk.Name
        $existing = Get-Item $dstPath -Force -ErrorAction SilentlyContinue

        if ($Uninstall) {
            if ($existing -and $existing.LinkType) {
                $tgt = ($existing.Target -join '')
                if ($tgt -ieq $srcPath -or $tgt.TrimStart('\?') -ieq $srcPath) {
                    cmd /c rmdir "$dstPath" | Out-Null
                    Write-Host "  [REMOVED] $($sk.Name)" -ForegroundColor Green
                } else {
                    Write-Host "  [SKIP] $($sk.Name) points elsewhere ($tgt)" -ForegroundColor DarkGray
                }
            } else {
                Write-Host "  [SKIP] $($sk.Name) not linked here" -ForegroundColor DarkGray
            }
            continue
        }

        if ($existing) {
            if ($existing.LinkType) {
                $tgt = ($existing.Target -join '')
                if ($tgt -ieq $srcPath -or $tgt.TrimStart('\?') -ieq $srcPath) {
                    Write-Host "  [OK] $($sk.Name) already linked" -ForegroundColor Green
                    continue
                }
                cmd /c rmdir "$dstPath" | Out-Null
            } elseif ($Force) {
                Remove-Item $dstPath -Recurse -Force
            } else {
                Write-Host "  [SKIP] $($sk.Name) already exists as a real folder (re-run with -Force to replace)" -ForegroundColor Yellow
                continue
            }
        }

        New-Item -ItemType Junction -Path $dstPath -Target $srcPath | Out-Null
        Write-Host "  [LINKED] $($sk.Name) -> $srcPath" -ForegroundColor Green
    }
}

Write-Host "`nDone! Pull updates in '$repoRoot' anytime to sync all linked AI clients." -ForegroundColor Green
