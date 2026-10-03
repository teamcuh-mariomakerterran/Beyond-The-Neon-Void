<#
  PixelMatrix export sorter (PowerShell port of Grok's compile_assets.sh).
  Finds PM_<Res>_<Facing>_<Anim>[_<Layer>].png exports, checks each strip's
  height matches <Res> (mismatches go to _quarantine), and files them as
    assets\units\pixelmatrix\<Character or res_<Res>>\<Anim>\<Facing>[_<Layer>].png
  which the game loads as a unit (set a character's sprite path to that folder).

  Run from the game folder:
    .\tools\compile_pixelmatrix.ps1 -Character netrunner
    .\tools\compile_pixelmatrix.ps1 -From "D:\exports" -Copy
  -Copy keeps the originals (default moves them out of Downloads).
#>
param(
    [string]$From      = (Join-Path $env:USERPROFILE "Downloads"),
    [string]$Repo      = "C:\godot and game projects\Beyond-The-Neon-Void",
    [string]$Character = "",
    [switch]$Copy
)
$ErrorActionPreference = "Stop"
function Say($msg, $color = "Cyan") { Write-Host $msg -ForegroundColor $color }

# PNG width/height live in the IHDR chunk: bytes 16-23, big-endian.
function Get-PngSize($path) {
    $fs = [IO.File]::OpenRead($path)
    try {
        $b = New-Object byte[] 24
        [void]$fs.Read($b, 0, 24)
        $w = ($b[16] -shl 24) -bor ($b[17] -shl 16) -bor ($b[18] -shl 8) -bor $b[19]
        $h = ($b[20] -shl 24) -bor ($b[21] -shl 16) -bor ($b[22] -shl 8) -bor $b[23]
        return @($w, $h)
    } finally { $fs.Close() }
}

$root = Join-Path $Repo "assets\units\pixelmatrix"
$quarantine = Join-Path $root "_quarantine"
$files = @(Get-ChildItem -LiteralPath $From -Filter "PM_*.png" -File)
if ($files.Count -eq 0) { Say "No PM_*.png exports in $From" "Yellow"; exit 0 }
Say "Found $($files.Count) PixelMatrix export(s) in $From"
$facings = @("N", "NE", "E", "SE", "S", "SW", "W", "NW")
$done = 0; $bad = 0
foreach ($f in $files) {
    $parts = $f.BaseName.Split("_")
    if ($parts.Count -lt 4 -or -not ($parts[1] -match '^\d+$') -or -not ($facings -contains $parts[2])) {
        Say "  skip (name isn't PM_<Res>_<Facing>_<Anim>): $($f.Name)" "DarkGray"; continue
    }
    $res = [int]$parts[1]; $facing = $parts[2]; $anim = $parts[3]
    $layer = if ($parts.Count -gt 4) { "_" + (($parts[4..($parts.Count - 1)]) -join "_") } else { "" }
    $size = Get-PngSize $f.FullName
    if ($size[1] -ne $res -or ($size[0] % $res) -ne 0) {
        New-Item -ItemType Directory -Force -Path $quarantine | Out-Null
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $quarantine $f.Name) -Force
        Say "  QUARANTINE $($f.Name): strip is $($size[0])x$($size[1]), expected height $res and width a multiple of it" "Yellow"
        $bad++; continue
    }
    $who = if ($Character) { $Character } else { "res_$res" }
    $dir = Join-Path $root (Join-Path $who $anim)
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $dest = Join-Path $dir "$facing$layer.png"
    if ($Copy) { Copy-Item -LiteralPath $f.FullName -Destination $dest -Force }
    else { Move-Item -LiteralPath $f.FullName -Destination $dest -Force }
    Say ("  {0,-34} -> units\pixelmatrix\{1}\{2}\{3}{4}.png  ({5} frames)" -f $f.Name, $who, $anim, $facing, $layer, ($size[0] / $res)) "Green"
    $done++
}
Say "Filed $done strip(s); $bad quarantined. In the Forge, set the character's sprite path to res://assets/units/pixelmatrix/$(if ($Character) { $Character } else { 'res_<Res>' })" "Cyan"
