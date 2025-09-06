#!/bin/bash

# Google Maps Setup Script for Safety App
# This script helps configure Google Maps integration

echo "🗺️  Google Maps Integration Setup for Safety App"
echo "================================================="
echo ""

# Check if API key is provided as argument
if [ "$1" = "" ]; then
    echo "❌ Error: Please provide your Google Maps API key"
    echo ""
    echo "Usage: ./setup_google_maps.sh YOUR_API_KEY_HERE"
    echo ""
    echo "To get an API key:"
    echo "1. Go to https://console.cloud.google.com/"
    echo "2. Create/select a project"
    echo "3. Enable 'Maps SDK for Android' API"
    echo "4. Create credentials -> API Key"
    echo ""
    exit 1
fi

API_KEY=$1
MANIFEST_FILE="android/app/src/main/AndroidManifest.xml"

echo "🔧 Configuring Google Maps with API key: ${API_KEY:0:10}..."
echo ""

# Check if manifest file exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "❌ Error: AndroidManifest.xml not found at $MANIFEST_FILE"
    echo "Please run this script from the root of your Flutter project"
    exit 1
fi

# Backup the original manifest
cp "$MANIFEST_FILE" "$MANIFEST_FILE.backup"
echo "📋 Created backup: $MANIFEST_FILE.backup"

# Replace the placeholder API key
sed -i.tmp "s/YOUR_GOOGLE_MAPS_API_KEY_HERE/$API_KEY/g" "$MANIFEST_FILE"
rm "$MANIFEST_FILE.tmp" 2>/dev/null || true

echo "✅ Updated AndroidManifest.xml with your API key"
echo ""

# Clean and rebuild
echo "🧹 Cleaning Flutter project..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Building debug APK..."
flutter build apk --debug

echo ""
echo "🎉 Google Maps integration completed successfully!"
echo ""
echo "📱 What's new:"
echo "   • Live Location shows interactive Google Maps"
echo "   • Guardian Dashboard displays contacts on map"
echo "   • Report Unsafe Zone with map location picker"
echo "   • Emergency SOS with map visualization"
echo ""
echo "🚀 To test:"
echo "   flutter install"
echo "   # or"
echo "   flutter run"
echo ""
echo "📝 Note: If you see a gray screen instead of maps:"
echo "   1. Check API key is correct"
echo "   2. Ensure 'Maps SDK for Android' is enabled"
echo "   3. Verify app package name in API restrictions"
echo ""
