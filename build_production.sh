#!/bin/bash

# Production Build Script for Flutter App
# Run this script to create production-ready builds

echo "🚀 Starting Production Build Process..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

echo "📱 Building Android App Bundle (AAB) for Google Play Store..."
flutter build appbundle --release --obfuscate --split-debug-info=./debug-symbols

echo "📱 Building Android APKs (split by ABI)..."
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=./debug-symbols

echo "🍎 Building iOS App (requires macOS)..."
# flutter build ios --release --obfuscate --split-debug-info=./debug-symbols

echo "🌐 Building Web App..."
flutter build web --release

echo "✅ Production builds complete!"
echo ""
echo "📦 Build outputs:"
echo "   Android AAB: build/app/outputs/bundle/release/app-release.aab"
echo "   Android APKs: build/app/outputs/flutter-apk/"
echo "   iOS: build/ios/iphoneos/Runner.app"
echo "   Web: build/web/"
echo ""
echo "🔐 Debug symbols saved to: ./debug-symbols/"
echo ""
echo "📋 Next steps:"
echo "   1. Test the release builds thoroughly"
echo "   2. Upload AAB to Google Play Console"
echo "   3. Archive iOS app in Xcode and upload to App Store Connect"
echo "   4. Deploy web build to your hosting platform"
