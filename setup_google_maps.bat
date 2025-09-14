@echo off
echo Google Maps API Key Configuration Script
echo =======================================
echo.

if "%~1"=="" (
    echo Usage: setup_google_maps.bat "WEB_API_KEY" "ANDROID_API_KEY" "IOS_API_KEY"
    echo.
    echo Example:
    echo setup_google_maps.bat "AIza..." "AIzb..." "AIzc..."
    echo.
    echo Get your API keys from: https://console.cloud.google.com/
    echo.
    pause
    exit /b 1
)

set WEB_KEY=%~1
set ANDROID_KEY=%~2
set IOS_KEY=%~3

echo Configuring Google Maps API keys...
echo.

REM Update web/index.html
echo Updating web configuration...
powershell -Command "(Get-Content 'web\index.html') -replace 'YOUR_WEB_API_KEY', '%WEB_KEY%' | Set-Content 'web\index.html'"

REM Update Android AndroidManifest.xml
echo Updating Android configuration...
powershell -Command "(Get-Content 'android\app\src\main\AndroidManifest.xml') -replace 'AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S', '%ANDROID_KEY%' | Set-Content 'android\app\src\main\AndroidManifest.xml'"

REM Update iOS Info.plist
echo Updating iOS configuration...
powershell -Command "(Get-Content 'ios\Runner\Info.plist') -replace 'YOUR_IOS_GOOGLE_MAPS_API_KEY', '%IOS_KEY%' | Set-Content 'ios\Runner\Info.plist'"

REM Update environment.dart with web key for now
echo Updating environment configuration...
powershell -Command "(Get-Content 'lib\config\environment.dart') -replace 'YOUR_PRODUCTION_GOOGLE_MAPS_WEB_KEY', '%WEB_KEY%' | Set-Content 'lib\config\environment.dart'"
powershell -Command "(Get-Content 'lib\config\environment.dart') -replace 'YOUR_DEVELOPMENT_GOOGLE_MAPS_WEB_KEY', '%WEB_KEY%' | Set-Content 'lib\config\environment.dart'"

echo.
echo ✅ Google Maps API keys configured successfully!
echo.
echo Next steps:
echo 1. Build your app: flutter build web --release
echo 2. Deploy: firebase deploy --only hosting
echo 3. Test the map functionality
echo.
pause
