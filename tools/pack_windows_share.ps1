# Packs the Godot Windows export in build/ into dist/ for sharing.
# Optional Authenticode sign if you have a purchased .pfx (not a self-signed cert).
#
# 1. In Godot: Project -> Export -> Windows Desktop -> Export Project
#    (release, not debug). Output is already set to build/GetTheMechOuttaDodge.exe
# 2. From the repo root:
#      powershell -File tools/pack_windows_share.ps1
# 3. To sign after you buy a code-signing cert:
#      $env:GTMOD_PFX = "C:\path\to\your.pfx"
#      $env:GTMOD_PFX_PASSWORD = "..."
#      powershell -File tools/pack_windows_share.ps1
#    Or enable Codesign in the Godot export preset (PKCS12 identity + Sign Tool path
#    in Editor Settings -> Export -> Windows) and skip the env vars.
#
# Self-signed certificates will not help SmartScreen. Do not pack/obfuscate the exe.

[CmdletBinding()]
param(
    [string]$BuildDir = "",
    [string]$OutDir = "",
    [string]$Version = "0.1.0"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $BuildDir) { $BuildDir = Join-Path $repoRoot "build" }
if (-not $OutDir) { $OutDir = Join-Path $repoRoot "dist" }

$exeName = "GetTheMechOuttaDodge.exe"
$exePath = Join-Path $BuildDir $exeName
if (-not (Test-Path -LiteralPath $exePath)) {
    throw "No export at $exePath. Export the Windows Desktop preset to build/ first (release, not debug)."
}

$pckPath = Join-Path $BuildDir "GetTheMechOuttaDodge.pck"
if (-not (Test-Path -LiteralPath $pckPath)) {
    Write-Warning "No GetTheMechOuttaDodge.pck next to the exe. Embed PCK is off, so friends need that file."
}

function Find-SignTool {
    $kitRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
    if (-not (Test-Path -LiteralPath $kitRoot)) { return $null }
    $found = Get-ChildItem -Path $kitRoot -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -eq "x64" } |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

$pfx = $env:GTMOD_PFX
$pfxPassword = $env:GTMOD_PFX_PASSWORD
if ($pfx) {
    if (-not (Test-Path -LiteralPath $pfx)) {
        throw "GTMOD_PFX is set but the file does not exist: $pfx"
    }
    $signTool = Find-SignTool
    if (-not $signTool) {
        throw "signtool.exe not found. Install the Windows 10/11 SDK and retry."
    }
    Write-Host "Signing $exeName with Authenticode..."
    $signArgs = @(
        "sign",
        "/fd", "SHA256",
        "/td", "SHA256",
        "/tr", "http://timestamp.digicert.com",
        "/d", "Get The Mech Outta Dodge",
        "/f", $pfx
    )
    if ($pfxPassword) {
        $signArgs += @("/p", $pfxPassword)
    }
    $signArgs += $exePath
    & $signTool @signArgs
    if ($LASTEXITCODE -ne 0) {
        throw "signtool failed with exit code $LASTEXITCODE"
    }
    & $signTool verify /pa $exePath
}

$stage = Join-Path $env:TEMP ("gtmod-share-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
    Copy-Item -LiteralPath $exePath -Destination $stage
    Get-ChildItem -LiteralPath $BuildDir -File | Where-Object {
        $_.Name -ne $exeName -and $_.Extension -notin @(".pdb", ".tmp")
    } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $stage
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "SHARE_README.txt") -Destination (Join-Path $stage "README.txt")

    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    $zipName = "GetTheMechOuttaDodge-$Version-win64.zip"
    $zipPath = Join-Path $OutDir $zipName
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -CompressionLevel Optimal

    $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $hashPath = "$zipPath.sha256"
    Set-Content -LiteralPath $hashPath -Value "$hash  $zipName" -Encoding ascii

    Write-Host ""
    Write-Host "Share this zip (itch.io or a GitHub/GitLab Release, not a Discord exe drop):"
    Write-Host "  $zipPath"
    Write-Host "SHA-256:"
    Write-Host "  $hash"
    Write-Host "Hash file:"
    Write-Host "  $hashPath"
    Write-Host ""
    Write-Host "If Defender still flags it: https://www.microsoft.com/en-us/wdsi/filesubmission"
}
finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}
