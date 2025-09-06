# Google Maps Integration Guide

## Overview

This guide will help you integrate Google Maps in all location features of the Safety App, including:

- Live Location Sharing with interactive maps
- Report Unsafe Zone with map picker
- Guardian Dashboard with multiple location tracking
- Emergency SOS with location visualization

## Step 1: Get Google Maps API Key

### 1.1 Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Note your project ID

### 1.2 Enable Required APIs

Enable these APIs in your Google Cloud project:

- **Maps SDK for Android** - For displaying maps on Android
- **Geocoding API** - For converting addresses to coordinates
- **Places API** - For location search and autocomplete (optional)

### 1.3 Create API Key

1. Go to "Credentials" in Google Cloud Console
2. Click "Create Credentials" → "API Key"
3. Copy your API key (looks like: `AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q`)

### 1.4 Restrict API Key (Recommended)

1. Click on your API key to edit it
2. Under "Application restrictions", select "Android apps"
3. Add your app's package name: `com.example.safety_app_prototype`
4. Add your SHA-1 certificate fingerprint (get it from Android Studio)

## Step 2: Configure Android App

### 2.1 Update AndroidManifest.xml

Replace the placeholder in `/android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Replace this line -->
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE" />

<!-- With your actual API key -->
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q" />
```

## Step 3: Update App to Use Maps Versions

### 3.1 Update Home Screen Imports

Edit `/lib/screens/home_screen.dart`:

```dart
// Change from safe versions
import 'live_location_screen_safe.dart';
import 'guardian_dashboard_safe_screen.dart';

// To maps versions
import 'live_location_screen.dart';
import 'guardian_dashboard_screen.dart';
```

### 3.2 Update Navigation Routes

In the same file, change the navigation:

```dart
// Change from:
Navigator.push(context, MaterialPageRoute(builder: (context) => const LiveLocationScreen()));
Navigator.push(context, MaterialPageRoute(builder: (context) => const GuardianDashboardSafeScreen()));

// To:
Navigator.push(context, MaterialPageRoute(builder: (context) => const LiveLocationScreen()));
Navigator.push(context, MaterialPageRoute(builder: (context) => const GuardianDashboardScreen()));
```

## Step 4: Add Map-Based Unsafe Zone Reporting

I'll create an enhanced unsafe zone reporting screen with map integration.

## Step 5: Test the Integration

### 5.1 Build and Test

```bash
flutter clean
flutter pub get
flutter build apk --debug
flutter install
```

### 5.2 Test Features

1. **Live Location**: Should show Google Maps with your location
2. **Guardian Dashboard**: Should show contacts' locations on map
3. **Report Unsafe Zone**: Should allow selecting location on map
4. **Emergency SOS**: Should include map view

## Features After Integration

### ✅ Live Location Screen

- Interactive Google Maps showing current position
- Real-time location marker updates
- Start/stop sharing with visual feedback
- Address display and map controls

### ✅ Guardian Dashboard

- Multiple contact locations on single map
- Real-time updates from shared locations
- Contact selection and map focusing
- Status indicators for each contact

### ✅ Report Unsafe Zone (Enhanced)

- Interactive map for precise location selection
- Drag to select exact unsafe location
- Preview of selected area before reporting
- Address lookup for selected location

### ✅ Emergency SOS (Enhanced)

- Map view showing emergency location
- Quick location sharing with emergency contacts
- Visual confirmation of SOS trigger location

## Troubleshooting

### Common Issues:

1. **Maps don't load (gray screen)**:

   - Check API key is correct
   - Ensure Maps SDK for Android is enabled
   - Verify package name in API restrictions

2. **Build errors**:

   - Run `flutter clean && flutter pub get`
   - Check Android Gradle Plugin compatibility

3. **Location not updating**:
   - Check location permissions
   - Verify GPS is enabled on device
   - Test location service in device settings

### Debug Commands:

```bash
# Check API key setup
adb logcat | grep -i "google\|maps\|api"

# Test location services
flutter run --debug
```

## Security Best Practices

1. **Restrict API Key**: Always restrict to your app package
2. **Monitor Usage**: Set up billing alerts in Google Cloud
3. **Environment Variables**: Consider using environment variables for API keys in production
4. **Rate Limiting**: Implement client-side rate limiting for API calls

## Cost Optimization

1. **Enable only needed APIs**: Don't enable unused APIs
2. **Set usage quotas**: Set daily quotas for each API
3. **Optimize map styles**: Use standard styles to reduce costs
4. **Cache results**: Cache geocoding results when possible

The app will now have full Google Maps integration across all location features!
