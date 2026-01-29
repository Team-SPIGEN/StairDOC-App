# =============================================================================
# StairDOC Mobile App - Production Build Script (Windows)
# =============================================================================

param(
    [string]$AppVersion = "1.0.0",
    [string]$BuildNumber = (Get-Date -Format "yyyyMMddHHmm"),
    [string]$ApiBaseUrl = "https://api.stairdoc.com/api/v1",
    [string]$WsBaseUrl = "wss://api.stairdoc.com/api/v1/ws"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "StairDOC Production Build" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Version: $AppVersion+$BuildNumber"
Write-Host "API URL: $ApiBaseUrl"
Write-Host "==========================================" -ForegroundColor Cyan

# Navigate to mobile app directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $ScriptDir "..")

# Clean previous builds
Write-Host "`n🧹 Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "`n📦 Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Analyze code
Write-Host "`n🔍 Analyzing code..." -ForegroundColor Yellow
flutter analyze --no-fatal-infos

# Run tests
Write-Host "`n🧪 Running tests..." -ForegroundColor Yellow
flutter test

# Build Android APK
Write-Host "`n🤖 Building Android APK..." -ForegroundColor Yellow
flutter build apk --release `
  --dart-define=ENVIRONMENT=production `
  --dart-define=API_BASE_URL=$ApiBaseUrl `
  --dart-define=WS_BASE_URL=$WsBaseUrl `
  --dart-define=APP_VERSION=$AppVersion `
  --dart-define=BUILD_NUMBER=$BuildNumber

# Build Android App Bundle
Write-Host "`n🤖 Building Android App Bundle..." -ForegroundColor Yellow
flutter build appbundle --release `
  --dart-define=ENVIRONMENT=production `
  --dart-define=API_BASE_URL=$ApiBaseUrl `
  --dart-define=WS_BASE_URL=$WsBaseUrl `
  --dart-define=APP_VERSION=$AppVersion `
  --dart-define=BUILD_NUMBER=$BuildNumber

# Build Windows (optional)
Write-Host "`n🪟 Building Windows..." -ForegroundColor Yellow
flutter build windows --release `
  --dart-define=ENVIRONMENT=production `
  --dart-define=API_BASE_URL=$ApiBaseUrl `
  --dart-define=WS_BASE_URL=$WsBaseUrl `
  --dart-define=APP_VERSION=$AppVersion `
  --dart-define=BUILD_NUMBER=$BuildNumber

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "✅ Build complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "APK: build\app\outputs\flutter-apk\app-release.apk"
Write-Host "AAB: build\app\outputs\bundle\release\app-release.aab"
Write-Host "Windows: build\windows\x64\runner\Release\"
