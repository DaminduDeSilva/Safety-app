# Fake Call Feature Implementation Guide

## Overview

The **Fake Call** feature is a discreet safety tool that allows users to simulate an incoming phone call to help them exit uncomfortable or potentially dangerous situations. This feature provides a convincing way for users to create a believable excuse to leave without arousing suspicion.

## Features Implemented

### 1. Core Components

#### FakeCallModel (`lib/models/fake_call_model.dart`)

- **FakeCallConfig**: Main configuration model for fake calls

  - Caller name and phone number
  - Customizable delay before call (3-60 seconds)
  - Optional caller avatar URL
  - Ringtone preferences
  - Enable/disable toggles
  - Creation and update timestamps

- **FakeCallTemplates**: Predefined templates for quick use
  - Mom, Work Emergency, Doctor's Office, Roommate
  - Ready-to-use configurations with realistic details

#### FakeCallService (`lib/services/fake_call_service.dart`)

- **Audio Management**:

  - Plays system ringtone using `flutter_ringtone_player`
  - Falls back to haptic feedback if audio fails
  - Supports custom ringtones (extensible)

- **Vibration Patterns**:

  - Realistic calling vibration pattern (1s vibrate, 1s pause, repeat)
  - Uses `vibration` package for cross-platform support
  - Automatically stops when call ends

- **Call Scheduling**:

  - Schedule fake calls with custom delays
  - Cancel scheduled calls if needed
  - Immediate emergency fake call generation

- **Screen Management**:
  - Full-screen call interface
  - Smooth transitions and animations
  - Auto-answer option for realism

### 2. User Interface

#### FakeCallScreen (`lib/screens/fake_call_screen.dart`)

- **Realistic Call Interface**:

  - Native phone app appearance
  - Full-screen overlay with blurred background
  - Caller name and number prominently displayed
  - Generated avatar based on caller name
  - Pulsing animations for incoming calls

- **Interactive Elements**:

  - Accept/Decline buttons (both work as expected)
  - Tap-to-end when call is "answered"
  - Auto-answer after 30 seconds for realism
  - Proper call state management

- **Visual Effects**:
  - Smooth slide-in animations
  - Color-coded caller avatars
  - Gradient backgrounds
  - Hide system UI for full immersion

#### FakeCallConfigScreen (`lib/screens/fake_call_config_screen.dart`)

- **Configuration Management**:

  - Create custom fake call profiles
  - Save configurations to Firestore
  - Edit existing configurations
  - Delete unwanted profiles

- **Quick Templates**:

  - Pre-built realistic caller profiles
  - One-tap template application
  - Common contact types (family, work, medical)

- **Settings**:
  - Delay slider (3-60 seconds)
  - Custom caller names and numbers
  - Enable/disable toggles
  - Test call functionality

### 3. Integration Points

#### Home Screen Integration

- **Quick Actions Section**: Two new action cards

  - "Quick Call": Immediate emergency fake call
  - "Call Settings": Access configuration screen

- **Floating Action Button**:

  - Always-visible emergency fake call trigger
  - Green phone icon for easy recognition
  - Extended button with "Quick Call" label

- **Emergency Workflow**:
  - Confirmation dialog before triggering
  - Countdown notification with cancel option
  - Error handling and user feedback

## Usage Scenarios

### 1. Emergency Quick Call

```dart
// User taps floating action button or quick action card
// System generates random caller (Mom, Boss, Doctor, etc.)
// 3-second delay for immediate response
// Full-screen realistic incoming call interface
```

### 2. Planned Fake Call

```dart
// User opens Call Settings
// Creates custom caller profile
// Sets specific delay (10-60 seconds)
// Saves for future use
// Can test before saving
```

### 3. Template-Based Call

```dart
// User selects from predefined templates
// One-tap to use Mom, Boss, Doctor, etc.
// Immediately scheduled or customized first
// Realistic phone numbers and names included
```

## Technical Implementation

### Dependencies Added

```yaml
dependencies:
  audioplayers: ^5.0.0 # For playing ringtone sounds
  vibration: ^1.7.5 # For realistic vibration patterns
  flutter_ringtone_player: ^3.0.2 # For system ringtone access
```

### Database Integration

- Firestore integration for saving user configurations
- User-specific fake call profiles stored securely
- Real-time sync across devices
- Offline capability planned for future updates

### Privacy & Security

- All fake call data stored locally in user's Firestore
- No external services for call simulation
- Real phone calls are never affected
- Clear indication in code that calls are simulated

## Safety Considerations

### 1. Non-Interference

- Feature cannot interfere with real emergency calls
- Uses only audio/vibration simulation
- No actual phone network involvement
- Clear separation from real phone functions

### 2. Discrete Operation

- Can be triggered quickly and secretly
- Realistic appearance to outside observers
- No obvious indicators it's a fake call
- Professional-looking interface

### 3. Emergency Cancellation

- Scheduled calls can be cancelled
- Easy exit from fake call screen
- No permanent system changes
- Graceful error handling

## Future Enhancements

### Planned Features

1. **Volume Button Activation**: Secret trigger using volume button combinations
2. **Shake Gesture**: Shake phone to trigger emergency fake call
3. **Custom Ringtones**: User-uploaded ringtone support
4. **Location-Based**: Automatic fake calls in unsafe zones
5. **Multiple Languages**: Localized caller names and interfaces
6. **Voice Simulation**: Pre-recorded conversation snippets

### Advanced Safety Features

1. **SOS Integration**: Combine with emergency SOS features
2. **Guardian Notification**: Optional real alerts to guardians
3. **Situation Detection**: AI-powered unsafe situation detection
4. **Scheduled Calls**: Recurring fake calls for regular check-ins

## Usage Instructions

### For Users

1. **Quick Emergency Call**:

   - Tap green floating "Quick Call" button
   - Confirm in popup dialog
   - Fake call appears in 3 seconds
   - Answer or decline as needed
   - Tap anywhere to end when "connected"

2. **Custom Fake Call**:

   - Go to "Call Settings" from home screen
   - Fill in caller name and phone number
   - Set delay with slider
   - Save configuration
   - Use "Test" to preview

3. **Using Templates**:
   - Open "Call Settings"
   - Browse "Quick Templates" section
   - Tap "+" to add template to form
   - Customize if needed
   - Save or test immediately

### For Developers

1. **Adding New Templates**:

   ```dart
   // Edit FakeCallTemplates.defaultTemplates in fake_call_model.dart
   FakeCallConfig(
     id: 'template_new',
     callerName: 'New Contact',
     phoneNumber: '+1 (555) 000-0000',
     delayBeforeCall: const Duration(seconds: 15),
   )
   ```

2. **Custom Ringtones**:
   ```dart
   // Add sound files to assets/sounds/
   // Update FakeCallService.playRingtone() method
   await _audioPlayer.play(AssetSource('sounds/custom_ringtone.mp3'));
   ```

## Testing

### Test Scenarios

1. **Basic Functionality**:

   - Quick call button works
   - Configuration screen saves/loads
   - Templates apply correctly
   - Test calls trigger properly

2. **Edge Cases**:

   - Network connectivity issues
   - Permission denials (audio/vibration)
   - Rapid successive triggers
   - System interruptions

3. **User Experience**:
   - Call interface is convincing
   - Audio and vibration are realistic
   - Animations are smooth
   - Error messages are helpful

## Conclusion

The Fake Call feature provides a powerful, discreet safety tool that can help users exit uncomfortable situations safely. With realistic visuals, authentic sound and vibration patterns, and flexible configuration options, it offers a convincing way for users to create believable excuses to leave potentially dangerous situations.

The implementation prioritizes user safety, privacy, and ease of use while maintaining the authentic appearance necessary for the feature to be effective in real-world scenarios.
