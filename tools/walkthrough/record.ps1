# Record the in-world walkthrough: TTS -> Godot Movie Maker -> H.264 MP4
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $Root

$OutDir = Join-Path $Root "docs\walkthrough"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot "vo") | Out-Null

Write-Host "WALKTHROUGH root=$Root"

python -m pip install --quiet edge-tts
if ($LASTEXITCODE -ne 0) { throw "pip install edge-tts failed" }
python (Join-Path $PSScriptRoot "gen_vo.py")
if ($LASTEXITCODE -ne 0) { throw "gen_vo.py failed" }

function Find-Godot {
	foreach ($name in @("godot", "godot.exe", "Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe")) {
		$cmd = Get-Command $name -ErrorAction SilentlyContinue
		if ($cmd) { return $cmd.Source }
	}
	$hits = @()
	$roots = @(
		$env:GODOT,
		(Join-Path $env:USERPROFILE "Downloads"),
		(Join-Path $env:LOCALAPPDATA "Programs"),
		(Join-Path $env:LOCALAPPDATA "Godot"),
		${env:ProgramFiles},
		${env:ProgramFiles(x86)},
		"C:\Godot"
	) | Where-Object { $_ -and (Test-Path $_) }
	foreach ($r in $roots) {
		$hits += Get-ChildItem -Path $r -Filter "Godot*.exe" -File -Recurse -Depth 2 -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -match "4\.7" -and $_.Name -match "console" -and $_.Name -notmatch "mono" }
		if ($hits.Count -eq 0) {
			$hits += Get-ChildItem -Path $r -Filter "Godot*.exe" -File -Recurse -Depth 2 -ErrorAction SilentlyContinue |
				Where-Object { $_.Name -match "4\.7" -and $_.Name -notmatch "mono" }
		}
	}
	if ($hits.Count -gt 0) { return $hits[0].FullName }
	return $null
}

$Godot = Find-Godot
if (-not $Godot) { throw "Godot 4.7 not found on PATH. Install it or set GODOT to the exe." }
Write-Host "WALKTHROUGH godot=$Godot"

$Avi = Join-Path $OutDir "gtmod.avi"
$Mp4 = Join-Path $OutDir "get_the_mech_outta_dodge.mp4"
if (Test-Path $Avi) { Remove-Item -Force $Avi }
if (Test-Path $Mp4) { Remove-Item -Force $Mp4 }

$godotArgs = @(
	"--path", $Root,
	"--write-movie", $Avi,
	"--fixed-fps", "30",
	"--",
	"--walkthrough"
)
Write-Host "WALKTHROUGH recording (this is a long take)..."
& $Godot @godotArgs
$recordCode = $LASTEXITCODE
Write-Host "WALKTHROUGH godot exit=$recordCode"
if (-not (Test-Path $Avi)) { throw "Movie Maker did not write $Avi" }

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpeg) { throw "ffmpeg not on PATH; AVI is at $Avi" }
& $ffmpeg.Source -y -i $Avi -c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac -b:a 192k $Mp4
if ($LASTEXITCODE -ne 0) { throw "ffmpeg transcode failed" }
Write-Host "WALKTHROUGH mp4=$Mp4"
