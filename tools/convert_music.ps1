<#
  Converts music / sound files to .ogg (what Godot plays best, ~10x smaller than .wav).
  * Reads every .wav .mp3 .flac .m4a .aac .mp4 .mov .webm in the folder (and subfolders).
  * Writes the .ogg copies into <folder>_ogg next to it, same subfolders.
  * NEVER changes or deletes the originals.
  Needs ffmpeg once:  winget install Gyan.FFmpeg   (then close + reopen PowerShell)
#>
param(
    [string]$Source  = "E:\Beyond_TheNeonVoid\music",
    [int]$Quality    = 6   # 0-10; 6 is ~190 kbps, transparent for game music
)
$ErrorActionPreference = "Continue"
function Say($m, $c = "Cyan") { Write-Host $m -ForegroundColor $c }

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Say "ffmpeg isn't installed yet. Run this once, then close and reopen PowerShell:" "Yellow"
    Say "    winget install Gyan.FFmpeg" "Yellow"
    Read-Host "Enter to close"; exit 1
}
$Source = $Source.Trim('"', ' ').TrimEnd('\')
if (-not (Test-Path -LiteralPath $Source -PathType Container)) { Say "Folder not found: $Source" "Red"; Read-Host "Enter to close"; exit 1 }
$Out = "$Source" + "_ogg"
$exts = @(".wav", ".mp3", ".flac", ".m4a", ".aac", ".mp4", ".mov", ".webm", ".aiff", ".aif")
$files = Get-ChildItem -LiteralPath $Source -Recurse -File | Where-Object { $exts -contains $_.Extension.ToLower() }
Say ("Converting {0} file(s) from {1}" -f $files.Count, $Source) "Magenta"
Say ("Output: {0}   (originals untouched)" -f $Out) "Magenta"
$n = 0; $before = 0; $after = 0
foreach ($f in $files) {
    $rel = $f.FullName.Substring($Source.Length).TrimStart('\')
    $dst = Join-Path $Out ([IO.Path]::ChangeExtension($rel, ".ogg"))
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    if ((Test-Path -LiteralPath $dst) -and ((Get-Item -LiteralPath $dst).LastWriteTime -ge $f.LastWriteTime)) { continue }
    $n++
    Say ("[{0}/{1}] {2}" -f $n, $files.Count, $rel)
    # -vn drops video (for .mp4 music videos), -map_metadata keeps titles.
    ffmpeg -hide_banner -loglevel error -y -i "$($f.FullName)" -vn -map_metadata 0 -c:a libvorbis -q:a $Quality "$dst"
    if ($LASTEXITCODE -ne 0) { Say "   failed: $rel" "Red"; continue }
    $before += $f.Length; $after += (Get-Item -LiteralPath $dst).Length
}
if ($before -gt 0) { Say ("Done: {0:N0} MB -> {1:N0} MB" -f ($before / 1MB), ($after / 1MB)) "Green" } else { Say "Nothing new to convert." "Green" }
Say "Next: copy the .ogg files into E:\Beyond_TheNeonVoid\music (or tell Claude to use the _ogg folder) and run the intake bot again." "Green"
Read-Host "Enter to close"
