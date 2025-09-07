# Safety App Prototype

A comprehensive Flutter-based safety application designed to help users stay safe and connected in emergency situations. The app provides various safety features including real-time location sharing, emergency SOS, unsafe zone reporting, and our newest addition - the **Fake Call** feature.

## 🚀 Latest Feature: Fake Call

The app now includes a sophisticated **Fake Call** feature that allows users to simulate incoming phone calls to help them exit uncomfortable or potentially dangerous situations discreetly.

### Key Features:

- **Realistic Call Interface**: Full-screen incoming call UI that looks exactly like a real phone call
- **Quick Emergency Access**: Floating action button for immediate fake call activation
- **Customizable Configurations**: Save multiple caller profiles with custom names, numbers, and delays
- **Pre-built Templates**: Ready-to-use profiles (Mom, Boss, Doctor, etc.) for quick access
- **Audio & Vibration**: Realistic ringtone and vibration patterns
- **Discreet Operation**: Can be triggered quickly and secretly during emergencies

### How It Works:

1. **Quick Access**: Tap the green "Quick Call" floating button on the home screen
2. **Scheduled Call**: Choose from 3-60 second delays before the fake call appears
3. **Realistic Experience**: Full-screen call interface with caller name, number, and avatar
4. **Interactive**: Answer or decline the call just like a real phone call
5. **Easy Exit**: Tap anywhere to end the call when answered

## 📱 Core Features

### 🏠 Home Dashboard

- Welcome section with user profile
- Emergency SOS button for critical situations
- Safety status indicators
- Quick actions for location sharing and zone reporting
- **NEW**: Fake call quick access and configuration

### 👥 Guardian System

- Add and manage emergency contacts
- Live location sharing with trusted guardians
- Real-time safety status updates
- Emergency invitation system

### 📍 Location Services

- Real-time GPS tracking
- Live location sharing
- Unsafe zone reporting and detection
- Google Maps integration

### 🚨 Emergency Features

- One-tap SOS emergency alerts
- Automatic emergency contact notification
- **NEW**: Fake call for discreet exit strategies
- Background location services

### 👤 Profile Management

- User profile setup and customization
- Emergency contact management
- Privacy and safety settings

## 🛠 Technical Stack

### Frontend

- **Flutter**: Cross-platform mobile development
- **Dart**: Programming language
- **Material Design**: UI/UX framework

### Backend & Services

- **Firebase Authentication**: User authentication and management
- **Cloud Firestore**: Real-time database for user data and configurations
- **Firebase Storage**: File storage for user avatars and media
- **Google Maps API**: Location services and mapping

### Audio & Vibration

- **audioplayers**: Audio playback for ringtones
- **vibration**: Realistic vibration patterns
- **flutter_ringtone_player**: System ringtone access

### Permissions & Hardware

- **permission_handler**: Device permission management
- **geolocator**: GPS and location services
- **flutter_contacts**: Contact access for emergency contacts

## 🔧 Installation & Setup

### Prerequisites

- Flutter SDK (>=3.8.1)
- Dart SDK
- Android Studio / VS Code
- Firebase project setup

### Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  geolocator: ^10.1.0
  geocoding: ^2.1.1
  url_launcher: ^6.2.5
  permission_handler: ^11.0.1
  flutter_contacts: ^1.1.9
  android_intent_plus: ^4.0.3
  google_maps_flutter: ^2.5.0
  http: ^1.1.0
  audioplayers: ^5.0.0 # For fake call audio
  vibration: ^1.7.5 # For fake call vibration
  flutter_ringtone_player: ^3.0.2 # For system ringtones
```

### Setup Instructions

1. **Clone the repository**:

   ```bash
   git clone [repository-url]
   cd safety_app_prototype
   ```

2. **Install dependencies**:

   ```bash
   flutter pub get
   ```

3. **Firebase Setup**:

   - Create a Firebase project
   - Add Android/iOS apps to the project
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place configuration files in appropriate directories

4. **Google Maps Setup**:

   - Enable Google Maps API in Google Cloud Console
   - Add API keys to `android/app/src/main/AndroidManifest.xml` and `ios/Runner/AppDelegate.swift`

5. **Run the app**:
   ```bash
   flutter run
   ```

## 📂 Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
│   ├── fake_call_model.dart     # NEW: Fake call configurations
│   ├── user_model.dart          # User profile model
│   ├── emergency_contact.dart   # Emergency contact model
│   └── ...
├── services/                    # Business logic services
│   ├── fake_call_service.dart   # NEW: Fake call functionality
│   ├── auth_service.dart        # Authentication service
│   ├── database_service.dart    # Firestore operations
│   ├── location_service.dart    # GPS and location services
│   └── ...
├── screens/                     # UI screens
│   ├── fake_call_screen.dart    # NEW: Realistic call interface
│   ├── fake_call_config_screen.dart # NEW: Call configuration
│   ├── home_screen.dart         # UPDATED: Added fake call integration
│   ├── main_navigation_screen.dart # Bottom navigation
│   └── ...
└── widgets/                     # Reusable UI components
```

## 🔒 Privacy & Security

- All user data is stored securely in Firebase Firestore
- Location data is encrypted in transit
- Fake call feature operates locally - no external phone network involvement
- User permissions are requested transparently
- Data retention follows privacy best practices

## 🧪 Testing

### Manual Testing Checklist

See `FAKE_CALL_FEATURE.md` for comprehensive testing instructions.

### Running Tests

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Static analysis
flutter analyze
```

## 🚀 Deployment

### Android

```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release
```

### iOS

```bash
# Debug build
flutter build ios --debug

# Release build
flutter build ios --release
```

## 🎯 Future Enhancements

### Planned Features

- **Volume Button Activation**: Secret fake call trigger using hardware buttons
- **Shake Gesture**: Motion-based emergency fake call activation
- **Custom Ringtones**: User-uploaded ringtone support
- **AI Safety Detection**: Automatic unsafe situation detection
- **Multi-language Support**: Internationalization for global use
- **Offline Mode**: Core features available without internet

### Advanced Integrations

- **Smart Watch Support**: Extend fake call to wearable devices
- **Voice Commands**: Voice-activated emergency features
- **Biometric Security**: Enhanced security with fingerprint/face recognition
- **Machine Learning**: Predictive safety alerts based on patterns

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For questions, issues, or feature requests:

- Create an issue on GitHub
- Contact the development team
- Check the documentation in the `docs/` folder

## 🙏 Acknowledgments

- Flutter team for the excellent framework
- Firebase for backend services
- Google Maps for location services
- Open source contributors and community
- Safety advocates who inspired this project

---

**Disclaimer**: The fake call feature is designed for safety purposes to help users exit uncomfortable situations. It should not be used to deceive in harmful ways or interfere with genuine emergency services.
