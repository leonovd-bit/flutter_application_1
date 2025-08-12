param(
  [string]$DeviceId = "emulator-5554"
)
$ErrorActionPreference = 'Stop'

Write-Host "=== FreshPunk Android clean run ===" -ForegroundColor Cyan

# 1) Ensure we're at project root
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) | Out-Null
Set-Location -Path (Join-Path (Get-Location).Path "..") | Out-Null

# 2) Configure Java & Gradle cache (avoid OneDrive path)
$androidJbr = 'C:\Program Files\Android\Android Studio\jbr'
if (Test-Path $androidJbr) {
  $env:JAVA_HOME = $androidJbr
  $env:PATH = "$env:JAVA_HOME\bin;" + $env:PATH
  Write-Host "JAVA_HOME => $env:JAVA_HOME" -ForegroundColor Yellow
} else {
  Write-Host "WARNING: Android Studio JBR not found at $androidJbr" -ForegroundColor Yellow
}
$env:GRADLE_USER_HOME = 'C:\GradleCacheNonOneDrive'
if (-not (Test-Path $env:GRADLE_USER_HOME)) { New-Item -ItemType Directory -Path $env:GRADLE_USER_HOME | Out-Null }
# Move Dart pub cache off OneDrive as well
$env:PUB_CACHE = 'C:\PubCache'
if (-not (Test-Path $env:PUB_CACHE)) { New-Item -ItemType Directory -Path $env:PUB_CACHE | Out-Null }

# 3) Stop Gradle/Java daemons to clear locks
try { .\android\gradlew.bat --stop | Out-Null } catch { }
Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# 4) Remove stale files and generated registrant
$pathsToRemove = @(
  ".\.dart_tool",
  ".\build",
  ".\android\.gradle",
  ".\android\local.properties",
  ".\android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java",
  ".\.flutter-plugins",
  ".\.flutter-plugins-dependencies"
)
foreach ($p in $pathsToRemove) {
  if (Test-Path $p) { Write-Host "Removing $p"; Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
}

# 5) Purge image_picker residue from pub cache
$pubHost = Join-Path $env:PUB_CACHE 'hosted\pub.dev'
if (Test-Path $pubHost) {
  Get-ChildItem $pubHost -Filter 'image_picker*' -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# 6) Clean + get
Write-Host "flutter clean" -ForegroundColor Green
flutter clean
Write-Host "flutter pub get" -ForegroundColor Green
flutter pub get

# 7) Ensure emulator has no stale APKs
Write-Host "adb uninstall (cleanup)" -ForegroundColor Green
adb uninstall com.example.flutter_application_1 | Out-Null
adb uninstall com.example.flutter_app | Out-Null

# 8) Build, install, and run
Write-Host "flutter build apk -v" -ForegroundColor Green
flutter build apk -v

Write-Host "flutter install -d $DeviceId" -ForegroundColor Green
flutter install -d $DeviceId

Write-Host "flutter run -d $DeviceId --verbose" -ForegroundColor Green
flutter run -d $DeviceId --verbose
