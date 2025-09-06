# Google Maps Setup Script for Safety App (PowerShell)
# This script helps configure Google Maps integration on Windows

param(
    [Parameter(Mandatory=$true)]
    [string]$ApiKey
)

Write-Host "🗺️  Google Maps Integration Setup for Safety App" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

if ([string]::IsNullOrEmpty($ApiKey)) {
    Write-Host "❌ Error: Please provide your Google Maps API key" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage: .\setup_google_maps.ps1 -ApiKey YOUR_API_KEY_HERE" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To get an API key:" -ForegroundColor Green
    Write-Host "1. Go to https://console.cloud.google.com/"
    Write-Host "2. Create/select a project"
    Write-Host "3. Enable 'Maps SDK for Android' API"
    Write-Host "4. Create credentials -> API Key"
    Write-Host ""
    exit 1
}

$manifestFile = "android\app\src\main\AndroidManifest.xml"
$apiKeyShort = $ApiKey.Substring(0, [Math]::Min(10, $ApiKey.Length))

Write-Host "🔧 Configuring Google Maps with API key: $apiKeyShort..." -ForegroundColor Yellow
Write-Host ""

# Check if manifest file exists
if (-not (Test-Path $manifestFile)) {
    Write-Host "❌ Error: AndroidManifest.xml not found at $manifestFile" -ForegroundColor Red
    Write-Host "Please run this script from the root of your Flutter project" -ForegroundColor Red
    exit 1
}

# Backup the original manifest
$backupFile = "$manifestFile.backup"
Copy-Item $manifestFile $backupFile -Force
Write-Host "📋 Created backup: $backupFile" -ForegroundColor Green

# Replace the placeholder API key
$content = Get-Content $manifestFile -Raw
$newContent = $content -replace "YOUR_GOOGLE_MAPS_API_KEY_HERE", $ApiKey
Set-Content $manifestFile $newContent

Write-Host "✅ Updated AndroidManifest.xml with your API key" -ForegroundColor Green
Write-Host ""

# Clean and rebuild
Write-Host "🧹 Cleaning Flutter project..." -ForegroundColor Yellow
flutter clean

Write-Host "📦 Getting dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "🔨 Building debug APK..." -ForegroundColor Yellow
flutter build apk --debug

Write-Host ""
Write-Host "🎉 Google Maps integration completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📱 What's new:" -ForegroundColor Cyan
Write-Host "   • Live Location shows interactive Google Maps"
Write-Host "   • Guardian Dashboard displays contacts on map"
Write-Host "   • Report Unsafe Zone with map location picker"
Write-Host "   • Emergency SOS with map visualization"
Write-Host ""
Write-Host "🚀 To test:" -ForegroundColor Green
Write-Host "   flutter install"
Write-Host "   # or"
Write-Host "   flutter run"
Write-Host ""
Write-Host "📝 Note: If you see a gray screen instead of maps:" -ForegroundColor Yellow
Write-Host "   1. Check API key is correct"
Write-Host "   2. Ensure 'Maps SDK for Android' is enabled"
Write-Host "   3. Verify app package name in API restrictions"
Write-Host ""
