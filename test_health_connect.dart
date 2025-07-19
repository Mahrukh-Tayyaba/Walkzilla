import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'lib/services/health_service.dart';

// Simple test widget to verify Health Connect integration
class HealthConnectTest extends StatefulWidget {
  const HealthConnectTest({super.key});

  @override
  State<HealthConnectTest> createState() => _HealthConnectTestState();
}

class _HealthConnectTestState extends State<HealthConnectTest> {
  final HealthService _healthService = HealthService();
  final Health _health = Health();

  String _status = 'Initializing...';
  bool _hasPermissions = false;
  Map<String, dynamic>? _healthData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testHealthConnect();
  }

  Future<void> _testHealthConnect() async {
    setState(() {
      _status = 'Testing Health Connect...';
      _isLoading = true;
    });

    try {
      // Test 1: Check if Health Connect is available
      setState(() => _status = 'Checking Health Connect availability...');

      final dataTypes = [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ];

      bool? hasPermissions = await _health.hasPermissions(dataTypes);

      setState(() {
        _hasPermissions = hasPermissions == true;
        _status = hasPermissions == true
            ? 'Health Connect available and permissions granted'
            : hasPermissions == false
                ? 'Health Connect available but permissions not granted'
                : 'Health Connect not available on this device';
      });

      // Test 2: Try to fetch health data
      if (_hasPermissions) {
        setState(() => _status = 'Fetching health data...');

        final healthData = await _healthService.fetchHealthData();

        setState(() {
          _healthData = healthData;
          _status = 'Health data fetched successfully!';
          _isLoading = false;
        });

        // Debug logging - only in debug mode
        if (kDebugMode) {
          debugPrint('Health Data Test Results:');
          debugPrint('Steps: ${healthData['steps']['count']}');
          debugPrint(
              'Heart Rate: ${healthData['heartRate']['beatsPerMinute']} bpm');
          debugPrint(
              'Calories: ${healthData['calories']['energy']['inKilocalories']} kcal');
          debugPrint(
              'Data Source: ${healthData['steps']['metadata']['device']['manufacturer']}');
        }
      } else {
        setState(() {
          _status = 'Cannot fetch data without permissions';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        debugPrint('Health Connect Test Error: $e');
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _status = 'Requesting permissions...';
      _isLoading = true;
    });

    try {
      bool granted = await _healthService.requestHealthConnectPermissions();

      setState(() {
        _hasPermissions = granted;
        _status = granted
            ? 'Permissions granted! Testing data fetch...'
            : 'Permissions denied';
        _isLoading = false;
      });

      if (granted) {
        await _testHealthConnect();
      }
    } catch (e) {
      setState(() {
        _status = 'Error requesting permissions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Connect Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Permissions: ${_hasPermissions ? "✅ Granted" : "❌ Not Granted"}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _hasPermissions ? Colors.green : Colors.red,
                      ),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_hasPermissions)
              ElevatedButton(
                onPressed: _requestPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Request Health Connect Permissions'),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testHealthConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Health Data Fetch'),
            ),
            const SizedBox(height: 24),
            if (_healthData != null) ...[
              const Text(
                'Health Data Results:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Steps: ${_healthData!['steps']['count']}'),
                      Text(
                          'Heart Rate: ${_healthData!['heartRate']['beatsPerMinute']} bpm'),
                      Text(
                          'Calories: ${_healthData!['calories']['energy']['inKilocalories']} kcal'),
                      const SizedBox(height: 8),
                      Text(
                        'Data Source: ${_healthData!['steps']['metadata']['device']['manufacturer']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Instructions:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('1. Ensure Health Connect is installed'),
                    Text('2. Grant permissions when prompted'),
                    Text('3. Verify real data is displayed'),
                    Text('4. Check that data source shows "Health Connect"'),
                    Text('5. Test fallback to simulated data if needed'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// To use this test, add this to your main.dart temporarily:
/*
void main() {
  runApp(MaterialApp(
    home: HealthConnectTest(),
  ));
}
*/
