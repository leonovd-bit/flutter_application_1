@echo off
REM Restaurant Portal Deployment Script for Windows
REM This script copies the restaurant portal files to the build/web directory and deploys to Firebase Hosting

echo.
echo 🍴 FreshPunk Restaurant Portal Deployment
echo ===========================================

REM Check if build/web directory exists
if not exist "build\web" (
    echo ❌ build\web directory not found. Please run 'flutter build web' first.
    exit /b 1
)

REM Copy restaurant portal files
echo 📂 Copying restaurant portal files...
copy "restaurant_portal\index.html" "build\web\restaurant.html" >nul
copy "restaurant_portal\styles.css" "build\web\restaurant-styles.css" >nul
copy "restaurant_portal\script.js" "build\web\restaurant-script.js" >nul

echo ✅ Restaurant portal files prepared

REM Deploy to Firebase Hosting
echo 🚀 Deploying to Firebase Hosting...
firebase deploy --only hosting

if %ERRORLEVEL% EQU 0 (
    echo.
    echo 🎉 Deployment successful!
    echo.
    echo 📱 Your app: https://freshpunk-48db1.web.app
    echo 🏪 Restaurant portal: https://freshpunk-48db1.web.app/restaurant
    echo.
    echo Share the restaurant portal URL with your restaurant partners!
) else (
    echo ❌ Deployment failed
    exit /b 1
)