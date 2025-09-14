# Builds Flutter web and deploys to a Firebase Hosting preview channel
# Usage: run in a PowerShell with Firebase CLI logged in (firebase login)

param(
  [string]$Channel = "preview-$(Get-Date -Format 'yyyyMMdd-HHmm')"
)

Write-Host "Building Flutter web release..." -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) { throw "Flutter web build failed." }

Write-Host "Deploying to Firebase Hosting preview channel: $Channel" -ForegroundColor Cyan
firebase hosting:channel:deploy $Channel --json
if ($LASTEXITCODE -ne 0) { throw "Firebase deploy failed." }

Write-Host "Done. Above JSON includes the preview URL (expire in 7-30 days)." -ForegroundColor Green
