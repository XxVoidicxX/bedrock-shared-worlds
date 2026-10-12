<#
.SYNOPSIS
  Makes every Minecraft Bedrock account on this PC see the main account's worlds,
  without copying anything.

.DESCRIPTION
  Bedrock (GDK build) keeps per-account data in:
      %APPDATA%\Minecraft Bedrock\Users\<account id>\games\com.mojang
  and shared data (resource_packs, behavior_packs) in Users\Shared, which every
  account already reads. Worlds are the per-account part.

  This script replaces each secondary account's per-account folders
  (minecraftWorlds, world_templates, skin_packs by default) with NTFS directory
  junctions that point at the main account's folders. No data is copied or moved;
  every account reads and writes the same files on disk.

  Safe by design:
    - Waits for Minecraft to close before changing anything.
    - Never deletes a non-empty folder. A secondary account that has its own worlds
      is skipped unless you pass -Merge, which moves (renames, instant on the same
      drive) its worlds into the main folder first.
    - Idempotent. Re-run it after a new account signs in for the first time.
    - -Undo removes only the junctions and puts empty folders back.

.EXAMPLE
  .\Share-Worlds.ps1 -DryRun        # show what would happen
  .\Share-Worlds.ps1                # link all secondary accounts
  .\Share-Worlds.ps1 -Merge         # also fold in worlds other accounts already have
  .\Share-Worlds.ps1 -Status        # show which accounts are linked
  .\Share-Worlds.ps1 -Undo          # unlink everything
#>
[CmdletBinding()]
param(
    # Account folder that owns the real data. Auto-detected (most worlds) if omitted.
    [string]$MainId,
    # Per-account folders to share.
    [string[]]$Folders = @('minecraftWorlds', 'world_templates', 'skin_packs'),
    [switch]$Merge,
    [switch]$Undo,
    [switch]$Status,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Root = Join-Path $env:APPDATA 'Minecraft Bedrock\Users'

function Get-ComMojang([string]$id) { Join-Path $Root "$id\games\com.mojang" }

function Test-Junction([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $item = Get-Item -LiteralPath $path -Force
    return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Get-JunctionTarget([string]$path) {
    $t = (Get-Item -LiteralPath $path -Force).Target
    if ($t -is [array]) { $t = $t[0] }
    return $t
}

# Removes only the link itself. Never use Remove-Item -Recurse on a junction:
# on Windows PowerShell 5.1 that walks into the target and deletes the real data.
function Remove-Junction([string]$path) { [IO.Directory]::Delete($path, $false) }

$planned = 0
function Do-Step([string]$msg, [scriptblock]$action) {
    $script:planned++
    if ($DryRun) { Write-Host "  [dry-run] $msg" -ForegroundColor DarkGray }
    else { Write-Host "  $msg"; & $action }
}

if (-not (Test-Path -LiteralPath $Root)) {
    throw "Bedrock user data not found at $Root. This needs the current Windows version of Minecraft Bedrock (1.21.120 or newer), launched at least once."
}

$accounts = Get-ChildItem -LiteralPath $Root -Directory -Force |
    Where-Object { $_.Name -match '^\d+$' -and (Test-Path -LiteralPath (Get-ComMojang $_.Name)) } |
    Select-Object -ExpandProperty Name

# Main account: explicit, or the one whose minecraftWorlds is a real folder with the most worlds.
if (-not $MainId) {
    $MainId = $accounts | ForEach-Object {
        $w = Join-Path (Get-ComMojang $_) 'minecraftWorlds'
        $n = if ((Test-Path -LiteralPath $w) -and -not (Test-Junction $w)) {
            @(Get-ChildItem -LiteralPath $w -Directory -Force).Count } else { -1 }
        [pscustomobject]@{ Id = $_; Worlds = $n }
    } | Sort-Object Worlds -Descending | Select-Object -First 1 -ExpandProperty Id
}
if ($accounts -notcontains $MainId) { throw "Main account '$MainId' not found under $Root" }
$mainCm = Get-ComMojang $MainId
$others = $accounts | Where-Object { $_ -ne $MainId }

$mainWorlds = @(Get-ChildItem -LiteralPath (Join-Path $mainCm 'minecraftWorlds') -Directory -Force -EA SilentlyContinue).Count
Write-Host "Main account: $MainId ($mainWorlds worlds)" -ForegroundColor Cyan

if ($Status) {
    foreach ($id in $others) {
        Write-Host "Account $id" -ForegroundColor Cyan
        foreach ($f in $Folders) {
            $p = Join-Path (Get-ComMojang $id) $f
            if (Test-Junction $p) { Write-Host "  $f -> $(Get-JunctionTarget $p)" -ForegroundColor Green }
            elseif (Test-Path -LiteralPath $p) { Write-Host "  $f (own folder, $(@(Get-ChildItem -LiteralPath $p -Force).Count) items)" -ForegroundColor Yellow }
            else { Write-Host "  $f (missing)" -ForegroundColor DarkGray }
        }
    }
    return
}

if (-not $others) {
    Write-Host 'No other accounts found. Sign in to the other account in Minecraft once, close the game, then run this again.' -ForegroundColor Yellow
    exit 3
}

if (-not $DryRun -and (Get-Process -Name 'Minecraft.Windows' -EA SilentlyContinue)) {
    Write-Host 'Minecraft is running. Close the game to continue (Ctrl+C to cancel)...' -ForegroundColor Yellow
    while (Get-Process -Name 'Minecraft.Windows' -EA SilentlyContinue) { Start-Sleep -Seconds 2 }
    Start-Sleep -Seconds 2   # let it finish flushing world saves
}

$problems = 0
foreach ($id in $others) {
    Write-Host "Account $id" -ForegroundColor Cyan
    $cm = Get-ComMojang $id
    foreach ($f in $Folders) {
        $link = Join-Path $cm $f
        $target = Join-Path $mainCm $f

        if ($Undo) {
            if (Test-Junction $link) {
                Do-Step "unlink $f" { Remove-Junction $link; New-Item -ItemType Directory -Path $link | Out-Null }
            }
            continue
        }

        if (Test-Junction $link) {
            if ((Get-JunctionTarget $link) -eq $target) { Write-Host "  $f already linked" -ForegroundColor Green; continue }
            Do-Step "re-point $f (was $(Get-JunctionTarget $link))" { Remove-Junction $link }
        }
        elseif (Test-Path -LiteralPath $link) {
            $items = @(Get-ChildItem -LiteralPath $link -Force)
            if ($items.Count -gt 0) {
                if (-not $Merge) {
                    Write-Host "  $f has $($items.Count) item(s) of its own, skipped. Re-run with -Merge to move them into the main account." -ForegroundColor Yellow
                    $problems++; continue
                }
                $clash = $items | Where-Object { Test-Path -LiteralPath (Join-Path $target $_.Name) }
                if ($clash) {
                    Write-Host "  $f skipped: name clash with main for $($clash.Name -join ', ')" -ForegroundColor Red
                    $problems++; continue
                }
                if (-not (Test-Path -LiteralPath $target)) { Do-Step "create main $f" { New-Item -ItemType Directory -Path $target | Out-Null } }
                foreach ($i in $items) {
                    Do-Step "move $f\$($i.Name) into main" { Move-Item -LiteralPath $i.FullName -Destination $target }
                }
            }
            Do-Step "remove empty $f" { [IO.Directory]::Delete($link, $false) }
        }

        if (-not (Test-Path -LiteralPath $target)) { Do-Step "create main $f" { New-Item -ItemType Directory -Path $target | Out-Null } }
        Do-Step "link $f -> $target" { New-Item -ItemType Junction -Path $link -Target $target | Out-Null }
    }
}

if ($problems) { Write-Host "Done with $problems item(s) skipped." -ForegroundColor Yellow }
else { Write-Host 'Done.' -ForegroundColor Green }
# Exit 3 = nothing to change (the launcher uses this to skip its "Apply?" prompt).
if ($planned -eq 0) { exit 3 }
