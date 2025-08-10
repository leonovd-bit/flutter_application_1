#!/bin/bash

# Memory optimization build script for FreshPunk Flutter app

echo "🚀 Starting optimized build process..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Run memory analysis (if dart analyzer is available)
echo "🔍 Running code analysis..."
flutter analyze

# Build optimized APK
echo "🏗️  Building optimized release APK..."
flutter build apk --release --target-platform android-arm64 --shrink

# Build App Bundle (recommended for Play Store)
echo "📱 Building optimized App Bundle..."
flutter build appbundle --release

# Display build sizes
echo "📊 Build results:"
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    APK_SIZE=$(ls -lh build/app/outputs/flutter-apk/app-release.apk | awk '{print $5}')
    echo "   APK Size: $APK_SIZE"
fi

if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    AAB_SIZE=$(ls -lh build/app/outputs/bundle/release/app-release.aab | awk '{print $5}')
    echo "   App Bundle Size: $AAB_SIZE"
fi

echo "✅ Optimized build complete!"
echo ""
echo "Memory optimization features applied:"
echo "   • ProGuard enabled for code shrinking"
echo "   • Resource shrinking enabled"
echo "   • Image cache optimization"
echo "   • Lazy loading implemented"
echo "   • Timer disposal optimization"
echo "   • Static data reduction"
echo ""
