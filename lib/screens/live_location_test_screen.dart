import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Debug screen to test live location database operations
class LiveLocationTestScreen extends StatefulWidget {
  const LiveLocationTestScreen({super.key});

  @override
  State<LiveLocationTestScreen> createState() => _LiveLocationTestScreenState();
}

class _LiveLocationTestScreenState extends State<LiveLocationTestScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final List<String> _logs = [];
  bool _isSharing = false;

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  Future<void> _testStartSharing() async {
    try {
      _addLog('Starting location sharing...');
      await _databaseService.startLiveSharing(
        37.4219983, // Google HQ coordinates for testing
        -122.084,
        address: 'Test Location - Google HQ, Mountain View, CA',
      );
      setState(() => _isSharing = true);
      _addLog('✅ Location sharing started successfully');
    } catch (e) {
      _addLog('❌ Error starting sharing: $e');
    }
  }

  Future<void> _testUpdateLocation() async {
    try {
      _addLog('Updating location...');
      await _databaseService.updateLiveLocation(
        37.4220 +
            (DateTime.now().millisecond / 100000), // Slightly different coords
        -122.085 + (DateTime.now().millisecond / 100000),
        address: 'Updated Test Location - ${DateTime.now().millisecond}',
      );
      _addLog('✅ Location updated successfully');
    } catch (e) {
      _addLog('❌ Error updating location: $e');
    }
  }

  Future<void> _testStopSharing() async {
    try {
      _addLog('Stopping location sharing...');
      await _databaseService.stopLiveSharing();
      setState(() => _isSharing = false);
      _addLog('✅ Location sharing stopped successfully');
    } catch (e) {
      _addLog('❌ Error stopping sharing: $e');
    }
  }

  Future<void> _testCheckStatus() async {
    try {
      _addLog('Checking sharing status...');
      final isSharing = await _databaseService.isCurrentUserSharingLocation();
      setState(() => _isSharing = isSharing);
      _addLog(
        '📍 Current sharing status: ${isSharing ? "ACTIVE" : "INACTIVE"}',
      );
    } catch (e) {
      _addLog('❌ Error checking status: $e');
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location Test'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isSharing ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isSharing ? Colors.green : Colors.red,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isSharing ? Icons.location_on : Icons.location_off,
                  color: _isSharing ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  _isSharing ? 'SHARING ACTIVE' : 'SHARING INACTIVE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isSharing ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          // Test Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testStartSharing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start Sharing'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testUpdateLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Update Location'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testStopSharing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Stop Sharing'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _testCheckStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Check Status'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Logs
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Logs:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: log.contains('❌')
                                  ? Colors.red
                                  : log.contains('✅')
                                  ? Colors.green
                                  : Colors.black87,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
