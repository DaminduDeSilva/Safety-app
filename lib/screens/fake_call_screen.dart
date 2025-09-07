import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/fake_call_model.dart';
import '../services/fake_call_service.dart';

class FakeCallScreen extends StatefulWidget {
  final FakeCallConfig config;

  const FakeCallScreen({super.key, required this.config});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  Timer? _autoAnswerTimer;
  Timer? _callDurationTimer;
  bool _isAnswered = false;
  bool _isDeclined = false;
  int _callDurationSeconds = 0;
  @override
  void initState() {
    super.initState();

    // Hide system UI for full immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Start animations
    _pulseController.repeat(reverse: true);
    _slideController.forward();

    // Remove auto-answer - let user choose
    // Optional: Auto-decline after 60 seconds if no action (like real calls)
    _autoAnswerTimer = Timer(const Duration(seconds: 60), () {
      if (!_isAnswered && !_isDeclined) {
        _declineCall();
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pulseController.dispose();
    _slideController.dispose();
    _autoAnswerTimer?.cancel();
    _callDurationTimer?.cancel();
    super.dispose();
  }

  void _answerCall() {
    if (_isAnswered || _isDeclined) return;

    // Add haptic feedback for realism
    HapticFeedback.mediumImpact();

    setState(() {
      _isAnswered = true;
    });

    // Stop ringtone and vibration
    FakeCallService.instance.stopRingtone();
    FakeCallService.instance.stopVibration();

    // Stop the pulse animation
    _pulseController.stop();

    // Start call duration timer
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
        });
      } else {
        timer.cancel();
      }
    });

    // Don't auto-end the call - let user tap to end when ready
  }

  void _declineCall() {
    if (_isAnswered || _isDeclined) return;

    // Add haptic feedback for realism
    HapticFeedback.mediumImpact();

    setState(() {
      _isDeclined = true;
    });

    _endCall();
  }

  void _endCall() {
    // Add haptic feedback for realism
    HapticFeedback.lightImpact();

    // Stop ringtone and vibration
    FakeCallService.instance.stopRingtone();
    FakeCallService.instance.stopVibration();

    // Stop timers
    _autoAnswerTimer?.cancel();
    _callDurationTimer?.cancel();

    // Navigate back
    Navigator.of(context).pop();
  }

  Widget _buildCallerAvatar() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: widget.config.avatarUrl != null
            ? Image.network(
                widget.config.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    // Generate a color based on the caller name for consistency
    final colors = [
      Colors.blue[300]!,
      Colors.green[300]!,
      Colors.orange[300]!,
      Colors.purple[300]!,
      Colors.teal[300]!,
      Colors.pink[300]!,
    ];

    final colorIndex = widget.config.callerName.hashCode % colors.length;
    final backgroundColor = colors[colorIndex.abs()];

    return Container(
      color: backgroundColor,
      child: Center(
        child: Text(
          widget.config.callerName.isNotEmpty
              ? widget.config.callerName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact(); // Add haptic feedback
        onTap();
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 35),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _isAnswered ? _endCall : null, // Tap to end call when answered
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey[900]!, Colors.black],
            ),
          ),
          child: SafeArea(
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Top section with status
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          _isAnswered
                              ? 'Connected'
                              : _isDeclined
                              ? 'Call Declined'
                              : 'Incoming call',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!_isAnswered && !_isDeclined)
                          Text(
                            _formatCallDuration(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Spacer
                  const Spacer(flex: 1),

                  // Caller avatar with pulse animation
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isAnswered || _isDeclined
                            ? 1.0
                            : _pulseAnimation.value,
                        child: _buildCallerAvatar(),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // Caller name
                  Text(
                    widget.config.callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Phone number
                  Text(
                    widget.config.phoneNumber,
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 2),

                  // Call status or answered message
                  if (_isAnswered)
                    GestureDetector(
                      onTap: _endCall,
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.phone,
                              color: Colors.green,
                              size: 40,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _formatCallDuration(_callDurationSeconds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Tap to end call',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Add some call action buttons for realism
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildCallButton(
                                  icon: Icons.mic_off,
                                  backgroundColor: Colors.grey[700]!,
                                  onTap: () {}, // Mute button (visual only)
                                ),
                                _buildCallButton(
                                  icon: Icons.call_end,
                                  backgroundColor: Colors.red[600]!,
                                  onTap: _endCall,
                                ),
                                _buildCallButton(
                                  icon: Icons.volume_up,
                                  backgroundColor: Colors.grey[700]!,
                                  onTap: () {}, // Speaker button (visual only)
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (!_isDeclined)
                    // Call action buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Decline button
                          _buildCallButton(
                            icon: Icons.call_end,
                            backgroundColor: Colors.red[600]!,
                            onTap: _declineCall,
                          ),

                          // Answer button
                          _buildCallButton(
                            icon: Icons.call,
                            backgroundColor: Colors.green[600]!,
                            onTap: _answerCall,
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatCallDuration([int? seconds]) {
    if (seconds != null) {
      // Format call duration in MM:SS format
      int minutes = seconds ~/ 60;
      int remainingSeconds = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    // This shows current time when call is incoming
    return DateTime.now().toString().substring(11, 16); // Current time
  }
}
