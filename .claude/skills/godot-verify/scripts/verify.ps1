<#
.SYNOPSIS
  Beyond The Neon Void: one-shot verification gate for Windows (PowerShell 5.1 or 7+).
.DESCRIPTION
  Gates: preflight -> import -> data (validate_data.py) -> compile (tests/compile_all.gd + script-error scan)
         -> tests (tests/run_tests.gd; known art/fixture failures allowed) -> replay (seeded determinism + win rates).
  Logs go ONLY to $env:TEMP\btnv-verify\ ; nothing is written into the repo.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .claude\skills\godot-verify\scripts\verify.ps1
.EXAMPLE
  .\verify.ps1 -Repo D:\Games\BTNV -Godot C:\Godot\Godot_v4.7.2-stable_win64_console.exe -Quick
.EXAMPLE
  .\verify.ps1 -Only replay -Missions m02_shift_change -Seeds 5
.EXAMPLE
  .\verify.ps1 -Only replay -Rosters suite -Seeds 3     # the repo's 6 test rosters (balance)
#>
param(
  [string]$Repo = ".",
  [string]$Godot = $env:GODOT,
  [switch]$Quick,
  [ValidateSet("", "data", "compile", "tests", "replay")][string]$Only = "",
  [string]$Missions = "",
  [int]$Seeds = 2,
  [ValidateSet("default", "suite")][string]$Rosters = "default",
  [string]$Baseline = "",
  [switch]$KeepGoing
)
$ErrorActionPreference = "Continue"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Baseline) { $Baseline = Join-Path $Here "known_failures.txt" }
$Repo = (Resolve-Path $Repo).Path
$TempRoot = $env:TEMP
if (-not $TempRoot) { $TempRoot = [System.IO.Path]::GetTempPath() }
$Log = Join-Path $TempRoot "btnv-verify"
New-Item -ItemType Directory -Force -Path $Log | Out-Null
if (-not (Test-Path (Join-Path $Repo "project.godot"))) { Write-Host "No project.godot in $Repo" -ForegroundColor Red; exit 2 }

function Find-Godot {
  $names = @("godot4", "godot", "Godot_v4.7.2-stable_win64_console", "Godot_v4.7.2-stable_win64", "Godot_v4.7.2-stable_linux.x86_64")
  foreach ($n in $names) { $c = Get-Command $n -ErrorAction SilentlyContinue; if ($c) { return $c.Source } }
  $roots = @("$env:LOCALAPPDATA\Programs", "$env:USERPROFILE\scoop\apps\godot", "C:\Godot", "$env:USERPROFILE\Godot", "$env:USERPROFILE\Downloads", "C:\Program Files\Godot", "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine")
  foreach ($r in $roots) {
    if ($r -and (Test-Path $r)) {
      $hit = Get-ChildItem -Path $r -Recurse -Depth 3 -Filter "Godot_v4.7*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
      if (-not $hit) { $hit = Get-ChildItem -Path $r -Recurse -Depth 3 -Filter "Godot_v4.7*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 }
      if ($hit) { return $hit.FullName }
    }
  }
  return $null
}
if (-not $Godot) { $Godot = Find-Godot }
if (-not $Godot -or -not (Test-Path $Godot)) { Write-Host "Godot 4.7 not found. Pass -Godot <path to Godot_v4.7.2-stable_win64_console.exe> or set `$env:GODOT." -ForegroundColor Red; exit 2 }

$Py = $null
foreach ($cand in @(@("py", "-3"), @("python"), @("python3"))) {
  if (Get-Command $cand[0] -ErrorAction SilentlyContinue) { $Py = $cand; break }
}

# Run Godot (or any exe) with a timeout; stdout+stderr merged into one log file. Returns exit code.
function Invoke-Tool([string]$Exe, [string[]]$ArgList, [string]$OutFile, [int]$TimeoutSec = 900) {
  $out = "$OutFile.out"; $err = "$OutFile.err"
  $quoted = $ArgList | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
  $p = Start-Process -FilePath $Exe -ArgumentList $quoted -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
  $null = $p.Handle  # PS 5.1: keep a handle so ExitCode is populated
  if (-not $p.WaitForExit($TimeoutSec * 1000)) { try { $p.Kill() } catch {}; "TIMEOUT after $TimeoutSec s" | Out-File $OutFile -Encoding utf8; return 124 }
  $p.WaitForExit()
  Get-Content $out, $err -ErrorAction SilentlyContinue | Set-Content $OutFile -Encoding utf8
  Remove-Item $out, $err -ErrorAction SilentlyContinue
  return $p.ExitCode
}

$Result = [ordered]@{ preflight = "not run"; import = "not run"; data = "not run"; compile = "not run"; tests = "not run"; replay = "not run" }
$script:Failed = $false
function Show-Summary {
  Write-Host ""
  Write-Host ("== BTNV verify summary ({0}) ==" -f (Get-Date -Format "HH:mm"))
  foreach ($k in $Result.Keys) {
    $v = $Result[$k]
    $col = "Gray"; if ($v -eq "PASS") { $col = "Green" } elseif ($v -eq "FAIL") { $col = "Red" } elseif ($v -eq "WARN") { $col = "Yellow" }
    Write-Host ("  {0,-9} {1}" -f $k, $v) -ForegroundColor $col
  }
  Write-Host "  logs: $Log"
  if ($script:Failed) { exit 1 } else { exit 0 }
}
function Set-Gate([string]$Name, [string]$State) {
  $Result[$Name] = $State
  if ($State -eq "FAIL") { $script:Failed = $true; if (-not $KeepGoing) { Show-Summary } }
}
function Want([string]$Gate) { return (-not $Only) -or ($Only -eq $Gate) }

# 1. preflight
$ver = (& $Godot --version 2>$null | Select-Object -First 1)
Write-Host "Godot: $ver"
$pf = "PASS"
if ($ver -notmatch '^4\.7') { Write-Host "WARN: project targets Godot 4.7 (got $ver)" -ForegroundColor Yellow; $pf = "WARN" }
$legacy = Join-Path $Repo "legacy\original_gd"
if ((Test-Path $legacy) -and -not (Test-Path (Join-Path $legacy ".gdignore")) -and -not (Test-Path (Join-Path (Split-Path $legacy) ".gdignore"))) {
  Write-Host "FAIL: legacy\original_gd has no .gdignore: Godot parses the old scripts and autoloads break." -ForegroundColor Red
  Write-Host "      Fix (with Brian's OK): New-Item legacy\original_gd\.gdignore -ItemType File"
  $pf = "FAIL"
}
if (-not $Py) { Write-Host "WARN: Python 3 not found (py/python): data gate will be skipped" -ForegroundColor Yellow; if ($pf -eq "PASS") { $pf = "WARN" } }
Set-Gate "preflight" $pf

# 2. import (.godot\ class cache; required on a fresh clone)
if (-not (Test-Path (Join-Path $Repo ".godot")) -or -not $Quick) {
  $rc = Invoke-Tool $Godot @("--headless", "--path", $Repo, "--import") (Join-Path $Log "import.log") 900
  if ($rc -eq 0) { Set-Gate "import" "PASS" } else { Set-Gate "import" "FAIL" }
} else { Set-Gate "import" "SKIP" }

# 3. data
if (Want "data") {
  if ($Py) {
    $pyArgs = @()
    if ($Py.Count -gt 1) { $pyArgs += $Py[1..($Py.Count - 1)] }
    $pyArgs += @((Join-Path $Here "validate_data.py"), $Repo)
    $rc = Invoke-Tool (Get-Command $Py[0]).Source $pyArgs (Join-Path $Log "data.log") 300
    Get-Content (Join-Path $Log "data.log") | Select-Object -Last 8 | ForEach-Object { Write-Host $_ }
    if ($rc -eq 0) { Set-Gate "data" "PASS" } else { Set-Gate "data" "FAIL" }
  } else { Set-Gate "data" "SKIP" }
}

# 4. compile + script-error scan
if (Want "compile") {
  $cl = Join-Path $Log "compile.log"
  $rc = Invoke-Tool $Godot @("--headless", "--path", $Repo, "-s", "res://tests/compile_all.gd") $cl 600
  Select-String -Path $cl -Pattern "compile_all:|FAILED:|CANNOT INSTANTIATE" | ForEach-Object { Write-Host $_.Line }
  $errs = @(Select-String -Path $cl -Pattern "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script")
  $errs | Select-Object -First 20 | ForEach-Object { Write-Host $_.Line -ForegroundColor Red }
  if ($rc -eq 0 -and $errs.Count -eq 0) { Set-Gate "compile" "PASS" } else { Set-Gate "compile" "FAIL" }
}

# 5. tests (known art/fixture failures from known_failures.txt are allowed)
if ((Want "tests") -and -not $Quick) {
  $tl = Join-Path $Log "tests.log"
  $null = Invoke-Tool $Godot @("--headless", "--path", $Repo, "-s", "res://tests/run_tests.gd") $tl 1800
  Select-String -Path $tl -Pattern "^=== |AI-vs-AI" | ForEach-Object { Write-Host $_.Line }
  $patterns = @(Get-Content $Baseline | Where-Object { $_ -and -not $_.StartsWith("#") })
  $new = 0; $known = 0
  foreach ($line in (Select-String -Path $tl -Pattern "^FAIL" | ForEach-Object { $_.Line })) {
    $hit = $false
    foreach ($p in $patterns) { if ($line -match $p) { $hit = $true; break } }
    if ($hit) { $known++ } else { $new++; $short = $line; if ($short.Length -gt 220) { $short = $short.Substring(0, 220) }; Write-Host "NEW $short" -ForegroundColor Red }
  }
  $serr = @(Select-String -Path $tl -Pattern "SCRIPT ERROR").Count
  Write-Host "tests: $new new failure(s), $known known art/fixture failure(s), $serr SCRIPT ERROR line(s)"
  if ($new -eq 0) { Set-Gate "tests" "PASS" } else { Set-Gate "tests" "FAIL" }
} elseif (Want "tests") { Set-Gate "tests" "SKIP" }

# 6. seeded replay (determinism + balance numbers)
if ((Want "replay") -and -not $Quick) {
  $rl = Join-Path $Log "replay.log"
  $script = (Join-Path $Here "gd\replay_check.gd") -replace '\\', '/'
  $jsonOut = (Join-Path $Log "replay.json") -replace '\\', '/'
  $ra = @("--headless", "--path", $Repo, "-s", $script, "--", "--seeds=$Seeds", "--rosters=$Rosters", "--json=$jsonOut")
  if ($Missions) { $ra += "--missions=$Missions" }
  $null = Invoke-Tool $Godot $ra $rl 1800
  Select-String -Path $rl -Pattern "player side won|MISMATCH|TURN CAP|replay_check:|REPLAY|SKIP" | ForEach-Object { Write-Host $_.Line }
  if (Select-String -Path $rl -Pattern "REPLAY OK" -Quiet) { Set-Gate "replay" "PASS" } else { Set-Gate "replay" "FAIL" }
} elseif (Want "replay") { Set-Gate "replay" "SKIP" }

Show-Summary
