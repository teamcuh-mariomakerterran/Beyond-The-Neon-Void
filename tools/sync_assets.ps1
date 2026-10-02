<#
  Beyond: The Neon Void - asset transfer bot
  ------------------------------------------
  COPIES art/music from your Black Doctrine folders (and any extra folders you
  point it at) into the game repo, then uploads to GitHub in safe-sized chunks.

  * Never moves, renames or deletes anything in the source folders.
  * Safe to run again any time: only new or changed files are copied/uploaded.
  * Skips files over 95 MB (GitHub refuses files over 100 MB) and lists them.

  Easiest way to run: double-click tools\sync_assets.bat
#>
param(
    [string]$Root          = "C:\godot and game projects",
    [string]$BlackDoctrine = "C:\godot and game projects\black-doctrine\public\assets",
    [string]$Repo          = "C:\godot and game projects\Beyond-The-Neon-Void",
    [string]$RepoUrl       = "https://github.com/teamcuh-mariomakerterran/Beyond-The-Neon-Void.git",
    [string]$Branch        = "claude/optimistic-fermat-pie49w",
    [int]$ChunkMB          = 300,
    # Dump mode: copy this whole folder (all subfolders, names as-is) into
    # assets\incoming\<folder name>; Claude sorts/renames/indexes from there.
    [string]$Dump          = "",
    [switch]$NoPrompt,
    [switch]$NoPush
)

# "Continue": Windows PowerShell treats git's progress output (stderr) as an
# error under "Stop" and would abort mid-upload.
$ErrorActionPreference = "Continue"
function Say($msg, $color = "Cyan") { Write-Host $msg -ForegroundColor $color }

# Splits whatever was dragged into a prompt: "a""b", "a" "b", a, b  ->  @(a, b)
function Split-DroppedPaths([string]$raw) {
    $out = @()
    if (-not $raw) { return ,$out }
    foreach ($m in [regex]::Matches($raw, '"([^"]+)"')) { $out += $m.Groups[1].Value.Trim() }
    $rest = [regex]::Replace($raw, '"[^"]*"', ',')
    foreach ($part in ($rest -split '[,;]')) { $t = $part.Trim(); if ($t) { $out += $t } }
    return ,$out
}

# Black Doctrine folder -> folder in our repo.  Edit freely.
$Map = [ordered]@{
    "all_structures"           = "assets\structures"
    "bg"                       = "assets\backgrounds"
    "tiles\god_tiles"          = "assets\tiles"          # includes all subfolders
    "ui"                       = "assets\ui"
    "ui\doctrine\green-purple" = "assets\ui\hud"
    "music"                    = "assets\music"
}
# Extra folders you'll be asked for (drag a folder into the window, or Enter to skip).
$Extras = [ordered]@{
    "Character models / sprite sheets"          = "assets\units"
    "Props"                                     = "assets\props"
    "Your SFX"                                  = "assets\sfx"
    "Cutscene art"                              = "assets\cutscenes"
    "Portraits"                                 = "assets\portraits"
}

Say "=== Beyond: The Neon Void - asset transfer ===" "Magenta"

# --- 1. git available? ---------------------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Say "Git isn't installed. Get it here (defaults are fine), then run this again:" "Yellow"
    Say "   https://git-scm.com/download/win" "Yellow"
    Start-Process "https://git-scm.com/download/win"
    Read-Host "Press Enter to close"; exit 1
}

# --- 2. local copy of the repo ---------------------------------------------------
if (-not (Test-Path (Join-Path $Repo ".git"))) {
    Say "Downloading the game repo to $Repo (first time only)..."
    git clone --branch $Branch $RepoUrl "$Repo"
    if ($LASTEXITCODE -ne 0) { Say "Clone failed - check your internet / GitHub login." "Red"; Read-Host "Enter to close"; exit 1 }
}
Push-Location $Repo
try {
    git fetch origin $Branch 2>$null
    git checkout $Branch 2>$null
    git pull --no-rebase --no-edit origin $Branch
    if (-not (git config user.email)) { git config user.email "teamcuh@gmail.com" }
    if (-not (git config user.name))  { git config user.name  "brian moore" }

    # --- 3. collect jobs ----------------------------------------------------------
    $jobs = @()
    if ($Dump) {
        $Dump = $Dump.Trim('"', ' ').TrimEnd('\')
        if (-not (Test-Path -LiteralPath $Dump -PathType Container)) { Say "Dump folder not found: $Dump" "Red"; Read-Host "Enter to close"; exit 1 }
        $leaf = Split-Path $Dump -Leaf
        $jobs += [pscustomobject]@{ Src = $Dump; Dst = "assets\incoming\$leaf"; Label = "dump" }
        $count = (Get-ChildItem -LiteralPath $Dump -Recurse -File | Measure-Object).Count
        $mb = (Get-ChildItem -LiteralPath $Dump -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
        Say ("Dump mode: {0} files ({1:N0} MB) from {2}" -f $count, $mb, $Dump) "Magenta"
        Say "Copying only - your originals are never moved or changed." "Magenta"
        $NoPromptExtras = $true
    }
    foreach ($k in $Map.Keys) {
        $src = Join-Path $BlackDoctrine $k
        if (Test-Path $src) { $jobs += [pscustomobject]@{ Src = $src; Dst = $Map[$k]; Label = $k } }
        else { Say "  (not found, skipping) $src" "DarkGray" }
    }
    if (-not $NoPrompt -and -not $NoPromptExtras) {
        Say ""
        Say "Optional extras. Drag one or more FOLDERS into this window (commas are fine)," "Cyan"
        Say "or just press Enter to skip. Folders already listed above are copied automatically." "Cyan"
        $autoSrcs = @($jobs | ForEach-Object { $_.Src.TrimEnd('\') + '\' })
        foreach ($label in $Extras.Keys) {
            $raw = Read-Host "$label"
            foreach ($p in (Split-DroppedPaths $raw)) {
                $p = $p.TrimEnd('\')
                $covered = @($autoSrcs | Where-Object { ($p + '\').StartsWith($_, [StringComparison]::OrdinalIgnoreCase) })
                if ($covered) { Say "  Already copied automatically (it's inside $($covered[0].TrimEnd('\'))) - skipping." "DarkGray"; continue }
                $isDir = $false
                try { $isDir = Test-Path -LiteralPath $p -PathType Container -ErrorAction Stop } catch { $isDir = $false }
                if ($isDir) {
                    $jobs += [pscustomobject]@{ Src = $p; Dst = $Extras[$label]; Label = $label }
                    Say "  + $p" "Green"
                } else { Say "  Not a folder, skipped: $p" "Yellow" }
            }
        }
    }
    if ($jobs.Count -eq 0) { Say "Nothing to copy." "Yellow"; Read-Host "Enter to close"; exit 0 }

    # --- 4. copy (never move) -------------------------------------------------------
    $tooBig = @()
    foreach ($j in $jobs) {
        $dst = Join-Path $Repo $j.Dst
        Say "Copying  $($j.Src)  ->  $($j.Dst)"
        $tooBig += Get-ChildItem -Path $j.Src -Recurse -File | Where-Object { $_.Length -gt 95MB }
        # /E = subfolders, /XO = skip older, /MAX = size cap. No /MOV, /MIR or /PURGE: sources are never touched.
        robocopy "$($j.Src)" "$dst" /E /XO /MAX:99614720 /R:1 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
        if ($LASTEXITCODE -ge 8) { Say "  robocopy reported an error for $($j.Src)" "Red" }
    }
    if ($tooBig.Count -gt 0) {
        Say "These files are over 95 MB and were skipped (GitHub limit). Compress or split them:" "Yellow"
        $tooBig | ForEach-Object { Say ("   {0}  ({1:N0} MB)" -f $_.FullName, ($_.Length / 1MB)) "Yellow" }
    }

    if ($NoPush) { Say "Copied. (-NoPush set: not uploading.)" "Green"; exit 0 }

    # --- 5. upload in chunks ----------------------------------------------------------
    foreach ($j in $jobs) {
        $files = @(git -c core.quotepath=off ls-files --others --modified --exclude-standard -- "$($j.Dst)")
        if ($files.Count -eq 0) { Say "  $($j.Dst): already up to date" "DarkGray"; continue }
        Say ("Uploading {0} file(s) in {1}..." -f $files.Count, $j.Dst)
        $batch = @(); $bytes = 0; $n = 1
        foreach ($f in $files + @($null)) {
            if ($f) {
                $size = (Get-Item -LiteralPath $f).Length
                $batch += $f; $bytes += $size
            }
            if ((-not $f -and $batch.Count) -or $bytes -ge ($ChunkMB * 1MB) -or $batch.Count -ge 400) {
                $list = Join-Path $env:TEMP "bnv_batch.txt"
                [IO.File]::WriteAllLines($list, [string[]]$batch)
                git add --pathspec-from-file="$list"
                git commit -q -m ("Add assets: {0} (part {1})" -f $j.Dst.Replace('\', '/'), $n)
                $ok = $false
                foreach ($try in 1..4) {
                    git push -q origin $Branch
                    if ($LASTEXITCODE -eq 0) { $ok = $true; break }
                    Say "  push failed, retrying in $([math]::Pow(2,$try)) s..." "Yellow"
                    Start-Sleep -Seconds ([math]::Pow(2, $try))
                }
                if (-not $ok) { Say "  Upload failed. Run the bot again later - it resumes where it stopped." "Red"; Read-Host "Enter to close"; exit 1 }
                Say ("  part {0}: {1} file(s), {2:N1} MB uploaded" -f $n, $batch.Count, ($bytes / 1MB)) "Green"
                $batch = @(); $bytes = 0; $n++
            }
        }
    }
    Say "All done. Tell Claude the assets are in!" "Green"
}
finally { Pop-Location }
if (-not $NoPrompt) { Read-Host "Press Enter to close" }
