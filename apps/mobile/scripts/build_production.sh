#!/bin/bash
# =============================================================================
# StairDOC Mobile App - Production Build Script (Linux/macOS)
# =============================================================================

set -e

# Configuration
APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
API_BASE_URL="${API_BASE_URL:-https://api.stairdoc.com/api/v1}"
WS_BASE_URL="${WS_BASE_URL:-wss://api.stairdoc.com/api/v1/ws}"

echo "=========================================="
echo "StairDOC Production Build"
echo "=========================================="
echo "Version: $APP_VERSION+$BUILD_NUMBER"
echo "API URL: $API_BASE_URL"
echo "=========================================="

# Navigate to mobile app directory
cd "$(dirname "$0")/.."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Run code generation if needed
# flutter pub run build_runner build --delete-conflicting-outputs

# Analyze code
echo "🔍 Analyzing code..."
flutter analyze --no-fatal-infos

# Run tests
echo "🧪 Running tests..."
flutter test

# Build Android APK
echo "🤖 Building Android APK..."
flutter build apk --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=WS_BASE_URL="$WS_BASE_URL" \
  --dart-define=APP_VERSION="$APP_VERSION" \
  --dart-define=BUILD_NUMBER="$BUILD_NUMBER"

# Build Android App Bundle
echo "🤖 Building Android App Bundle..."
flutter build appbundle --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=WS_BASE_URL="$WS_BASE_URL" \
  --dart-define=APP_VERSION="$APP_VERSION" \
  --dart-define=BUILD_NUMBER="$BUILD_NUMBER"

# Build iOS (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "🍎 Building iOS..."
  flutter build ios --release --no-codesign \
    --dart-define=ENVIRONMENT=production \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=WS_BASE_URL="$WS_BASE_URL" \
    --dart-define=APP_VERSION="$APP_VERSION" \
    --dart-define=BUILD_NUMBER="$BUILD_NUMBER"
fi

echo "=========================================="
echo "✅ Build complete!"
echo "=========================================="
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
echo "AAB: build/app/outputs/bundle/release/app-release.aab"
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "iOS: build/ios/iphoneos/Runner.app"
fi
