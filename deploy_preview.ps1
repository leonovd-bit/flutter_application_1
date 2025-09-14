# Deploy a Firebase Hosting preview channel for this project.
# Usage: powershell -ExecutionPolicy Bypass -File ./deploy_preview.ps1 [-Channel preview-<timestamp>]

param(
    [string]$Channel
)

$ErrorActionPreference = 'Stop'

function Write-Section($msg) {
    Write-Host "`n=== $msg ===" -ForegroundColor Cyan
}

if (-not $Channel -or [string]::IsNullOrWhiteSpace($Channel)) {
    $Channel = "preview-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

Write-Section "Project"
Write-Host "Root: $projectRoot"
Write-Host "Channel: $Channel"

# Ensure web build exists
$webDir = Join-Path $projectRoot 'build/web'
if (-not (Test-Path (Join-Path $webDir 'index.html'))) {
    Write-Section "Building web (release)"
    & flutter build web --release
}

# Determine Firebase command
$firebaseCmd = Get-Command firebase -ErrorAction SilentlyContinue
if ($null -ne $firebaseCmd) {
    $cmd = 'firebase'
} else {
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($null -ne $nodeCmd) {
        $cmd = 'npx firebase-tools@latest'
    } else {
        Write-Host "Node.js is not installed or not on PATH. Install Node LTS, then re-run this script." -ForegroundColor Yellow
        Write-Host "Quick install (Windows): winget install -e --id OpenJS.NodeJS.LTS" -ForegroundColor DarkGray
        exit 1
    }
}

Write-Section "Deploying preview"
$deployArgs = @('hosting:channel:deploy', $Channel, '--project', 'freshpunk-48db1')
Write-Host ("Command: {0} {1}" -f $cmd, ($deployArgs -join ' ')) -ForegroundColor DarkGray

# Invoke and stream output
if ($cmd -eq 'firebase') {
    & firebase @deployArgs
} else {
    & npx firebase-tools@latest @deployArgs
}

Write-Section "Done"
