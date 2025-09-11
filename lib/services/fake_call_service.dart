import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/fake_call_model.dart';
import '../screens/fake_call_screen.dart';

class FakeCallService {
  static final FakeCallService _instance = FakeCallService._internal();
  factory FakeCallService() => _instance;
  FakeCallService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _callTimer;
  Timer? _vibrationTimer;
  bool _isCallActive = false;
  bool _isRingtoneActive = false;

  // Get the singleton instance
  static FakeCallService get instance => _instance;

  /// Play ringtone sound
  Future<void> playRingtone() async {
    try {
      if (_isRingtoneActive) return;

      _isRingtoneActive = true;

      // For now, use haptic feedback as a simple ringtone substitute
      // This ensures the feature works without requiring audio assets
      HapticFeedback.mediumImpact();

      // Future enhancement: Add actual ringtone files to assets/sounds/
      // await _audioPlayer.play(AssetSource('sounds/default_ringtone.mp3'));
    } catch (e) {
      print('Error playing ringtone: $e');
      // Final fallback to haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  /// Stop ringtone
  Future<void> stopRingtone() async {
    try {
      _isRingtoneActive = false;
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping ringtone: $e');
    }
  }

  /// Vibrate phone with realistic calling pattern
  Future<void> vibratePhone() async {
    try {
      // Use HapticFeedback as a replacement for vibration
      // This provides tactile feedback without external dependencies
      _startVibrationPattern();
    } catch (e) {
      print('Error with haptic feedback: $e');
    }
  }

  /// Start realistic vibration pattern for incoming calls
  void _startVibrationPattern() {
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isCallActive) {
        timer.cancel();
        return;
      }

      // Use haptic feedback instead of vibration
      HapticFeedback.heavyImpact();
    });
  }

  /// Stop vibration
  Future<void> stopVibration() async {
    try {
      _vibrationTimer?.cancel();
      // No need to cancel anything with HapticFeedback
    } catch (e) {
      print('Error stopping haptic feedback: $e');
    }
  }

  /// Show incoming call screen
  void showIncomingCallScreen(BuildContext context, FakeCallConfig config) {
    if (_isCallActive) return;

    _isCallActive = true;

    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                FakeCallScreen(config: config),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;

                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));

                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
            fullscreenDialog: true,
          ),
        )
        .then((_) {
          // Call ended
          _isCallActive = false;
          stopRingtone();
          stopVibration();
        });
  }

  /// Schedule fake call with delay
  Future<void> scheduleFakeCall(
    BuildContext context,
    FakeCallConfig config,
  ) async {
    // Cancel any existing call
    cancelScheduledCall();

    print(
      'Scheduling fake call from ${config.callerName} in ${config.delayBeforeCall.inSeconds} seconds',
    );

    _callTimer = Timer(config.delayBeforeCall, () async {
      if (!context.mounted) return;

      // Start vibration and ringtone
      await vibratePhone();
      await playRingtone();

      // Show incoming call screen
      showIncomingCallScreen(context, config);
    });
  }

  /// Trigger immediate fake call
  Future<void> triggerImmediateFakeCall(
    BuildContext context,
    FakeCallConfig config,
  ) async {
    if (_isCallActive) return;

    print('Triggering immediate fake call from ${config.callerName}');

    // Start vibration and ringtone
    await vibratePhone();
    await playRingtone();

    // Show incoming call screen
    showIncomingCallScreen(context, config);
  }

  /// Cancel scheduled call
  void cancelScheduledCall() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  /// Check if a call is currently scheduled
  bool get hasScheduledCall => _callTimer?.isActive == true;

  /// Check if a call is currently active
  bool get isCallActive => _isCallActive;

  /// Generate a random caller name for emergency situations
  String generateRandomCallerName() {
    final names = ['Mom', 'Dad', 'Brother'];
    return names[Random().nextInt(names.length)];
  }

  /// Generate a random phone number
  String generateRandomPhoneNumber() {
    final random = Random();
    final areaCode = (200 + random.nextInt(799)).toString();
    final exchange = (200 + random.nextInt(799)).toString();
    final number = random.nextInt(9999).toString().padLeft(4, '0');
    return '+1 ($areaCode) $exchange-$number';
  }

  /// Create a quick emergency fake call config
  FakeCallConfig createEmergencyFakeCall() {
    return FakeCallConfig(
      id: 'emergency_${DateTime.now().millisecondsSinceEpoch}',
      callerName: generateRandomCallerName(),
      phoneNumber: generateRandomPhoneNumber(),
      delayBeforeCall: const Duration(seconds: 0), // Instant for emergencies
    );
  }

  /// Clean up resources
  void dispose() {
    _callTimer?.cancel();
    _vibrationTimer?.cancel();
    stopRingtone();
    stopVibration();
    _audioPlayer.dispose();
  }
}
