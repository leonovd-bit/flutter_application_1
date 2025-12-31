# Build, install, and run Flutter app on phone
# This script ensures the APK is always found and properly installed

Write-Host "Building APK..." -ForegroundColor Cyan
flutter build apk --debug

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

# Find the APK file in the build output
Write-Host "`nLocating APK..." -ForegroundColor Cyan
$apkPath = Get-ChildItem -Path "android\app\build\outputs\apk\debug" -Filter "*.apk" -Recurse | Select-Object -First 1 -ExpandProperty FullName

if (-not $apkPath) {
    Write-Host "APK not found in build output!" -ForegroundColor Red
    exit 1
}

Write-Host "Found APK at: $apkPath" -ForegroundColor Green

Write-Host "`nInstalling on phone..." -ForegroundColor Cyan
$env:ANDROID_SDK_ROOT = "$env:LOCALAPPDATA\Android\Sdk"
& "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe" install -r "$apkPath"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Installation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`nRestarting app..." -ForegroundColor Cyan
& "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe" shell am force-stop com.example.flutter_application_1
& "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe" shell am start -n com.example.flutter_application_1/.MainActivity

Write-Host "`nApp installed and running!" -ForegroundColor Green
