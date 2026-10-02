<#
  Converts music + sound effects to .ogg (what Godot streams best, ~10x smaller than .wav).
  * Sound-effect folders (name contains "sfx" or "sound"): short WAVs stay WAV
    (zero decode delay for hits/shots/UI); long ones (ambience, loops) -> .ogg.
  * Reads every .wav .mp3 .flac .m4a .aac .mp4 .mov .webm in the folder (and subfolders).
  * Writes the .ogg copies into <folder>_ogg next to it, same subfolders.
  * NEVER changes or deletes the originals.
  Needs ffmpeg once:  winget install Gyan.FFmpeg   (then close + reopen PowerShell)
#>
param(
    # One or more folders. Default: the dump's music + sfx folders (whichever exist).
    [string[]]$Source = @("E:\Beyond_TheNeonVoid\music", "E:\Beyond_TheNeonVoid\sfx", "E:\Beyond_TheNeonVoid\SFX", "E:\Beyond_TheNeonVoid\sound effects"),
    [int]$Quality     = 6,   # 0-10; 6 is ~190 kbps, transparent for game audio
    # Sound effects: WAVs smaller than this stay WAV (Godot plays WAV with zero
    # decode delay - best for hits, shots, UI). Bigger ones (loops, ambience) -> .ogg.
    [int]$KeepWavUnderKB = 1024
)
$ErrorActionPreference = "Continue"
function Say($m, $c = "Cyan") { Write-Host $m -ForegroundColor $c }

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Say "ffmpeg isn't installed yet. Run this once, then close and reopen PowerShell:" "Yellow"
    Say "    winget install Gyan.FFmpeg" "Yellow"
    Read-Host "Enter to close"; exit 1
}
$exts = @(".wav", ".mp3", ".flac", ".m4a", ".aac", ".mp4", ".mov", ".webm", ".aiff", ".aif")
$n = 0; $before = 0; $after = 0; $kept = 0
$seen = @{}
foreach ($src in $Source) {
    $src = $src.Trim('"', ' ').TrimEnd('\')
    if (-not (Test-Path -LiteralPath $src -PathType Container)) { continue }
    $real = (Resolve-Path -LiteralPath $src).Path
    if ($seen.ContainsKey($real.ToLower())) { continue }   # sfx / SFX on Windows = same folder
    $seen[$real.ToLower()] = $true
    $isSfx = (Split-Path $real -Leaf) -match "sfx|sound"
    $Out = "$real" + "_ogg"
    $files = Get-ChildItem -LiteralPath $real -Recurse -File | Where-Object { $exts -contains $_.Extension.ToLower() }
    Say ("{0}: {1} file(s){2}  ->  {3}" -f $real, $files.Count, $(if ($isSfx) { "  (short WAVs kept as WAV)" } else { "" }), $Out) "Magenta"
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($real.Length).TrimStart('\')
        $keepWav = $isSfx -and $f.Extension.ToLower() -eq ".wav" -and $f.Length -lt ($KeepWavUnderKB * 1KB)
        $dst = Join-Path $Out $(if ($keepWav) { $rel } else { [IO.Path]::ChangeExtension($rel, ".ogg") })
        New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
        if ((Test-Path -LiteralPath $dst) -and ((Get-Item -LiteralPath $dst).LastWriteTime -ge $f.LastWriteTime)) { continue }
        if ($keepWav) { Copy-Item -LiteralPath $f.FullName -Destination $dst; $kept++; continue }
        $n++
        Say ("  [{0}] {1}" -f $n, $rel)
        # -vn drops video (for .mp4 music videos), -map_metadata keeps titles.
        ffmpeg -hide_banner -loglevel error -y -i "$($f.FullName)" -vn -map_metadata 0 -c:a libvorbis -q:a $Quality "$dst"
        if ($LASTEXITCODE -ne 0) { Say "   failed: $rel" "Red"; continue }
        $before += $f.Length; $after += (Get-Item -LiteralPath $dst).Length
    }
}
if ($seen.Count -eq 0) { Say "None of these folders exist: $($Source -join ', ')" "Red"; Read-Host "Enter to close"; exit 1 }
if ($kept -gt 0) { Say ("Kept {0} short sound effect(s) as WAV (instant playback)." -f $kept) "Green" }
if ($before -gt 0) { Say ("Done: {0:N0} MB -> {1:N0} MB" -f ($before / 1MB), ($after / 1MB)) "Green" } else { Say "Nothing new to convert." "Green" }
Say "Next: swap the _ogg folders' contents in for the originals (keep the originals somewhere safe), then run the intake bot again." "Green"
Read-Host "Enter to close"
