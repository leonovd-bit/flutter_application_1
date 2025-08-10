@echo off
REM Memory optimization build script for FreshPunk Flutter app

echo 🚀 Starting optimized build process...

REM Clean previous builds
echo 🧹 Cleaning previous builds...
flutter clean

REM Get dependencies
echo 📦 Getting dependencies...
flutter pub get

REM Run memory analysis
echo 🔍 Running code analysis...
flutter analyze

REM Build optimized APK
echo 🏗️  Building optimized release APK...
flutter build apk --release --target-platform android-arm64 --shrink

REM Build App Bundle
echo 📱 Building optimized App Bundle...
flutter build appbundle --release

REM Display build results
echo 📊 Build results:
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo    APK created successfully
)

if exist "build\app\outputs\bundle\release\app-release.aab" (
    echo    App Bundle created successfully
)

echo ✅ Optimized build complete!
echo.
echo Memory optimization features applied:
echo    • ProGuard enabled for code shrinking
echo    • Resource shrinking enabled  
echo    • Image cache optimization
echo    • Lazy loading implemented
echo    • Timer disposal optimization
echo    • Static data reduction
echo.

pause
