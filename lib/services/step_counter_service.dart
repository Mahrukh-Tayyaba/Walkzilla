import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class StepCounterService {
  static const MethodChannel _methodChannel =
      MethodChannel('walkzilla/step_counter');
  static const EventChannel _eventChannel =
      EventChannel('walkzilla/step_stream');

  static Stream<Map<String, dynamic>>? _stepStream;
  static bool _isInitialized = false;
  static int _currentSteps = 0;
  static int _baselineSteps = 0;
  static DateTime? _lastResetTime;

  /// Initialize the step counter service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request activity recognition permission
      final status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        final result = await Permission.activityRecognition.request();
        if (!result.isGranted) {
          print('Activity recognition permission denied');
          return false;
        }
      }

      // Check sensor availability
      final isAvailable =
          await _methodChannel.invokeMethod<bool>('getSensorAvailability') ??
              false;
      if (!isAvailable) {
        print('Step sensor not available on this device');
        return false;
      }

      _isInitialized = true;
      print('Step counter service initialized successfully');
      return true;
    } catch (e) {
      print('Error initializing step counter service: $e');
      return false;
    }
  }

  /// Start real-time step tracking
  static Future<bool> startTracking() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      await _methodChannel.invokeMethod('startStepCounter');
      print('Step tracking started');
      return true;
    } catch (e) {
      print('Error starting step tracking: $e');
      return false;
    }
  }

  /// Stop real-time step tracking
  static Future<bool> stopTracking() async {
    try {
      await _methodChannel.invokeMethod('stopStepCounter');
      print('Step tracking stopped');
      return true;
    } catch (e) {
      print('Error stopping step tracking: $e');
      return false;
    }
  }

  /// Get the real-time step stream
  static Stream<Map<String, dynamic>> get stepStream {
    if (_stepStream == null) {
      _stepStream = _eventChannel.receiveBroadcastStream().map((event) {
        final data = Map<String, dynamic>.from(event);

        if (data['type'] == 'step_update') {
          final totalSteps = data['totalSteps'] as int;
          final stepsSinceStart = data['stepsSinceStart'] as int;
          final timestamp = data['timestamp'] as int;

          // Update current steps
          _currentSteps = stepsSinceStart;

          return {
            'type': 'step_update',
            'totalSteps': totalSteps,
            'currentSteps': _currentSteps,
            'dailySteps': _calculateDailySteps(totalSteps),
            'timestamp': DateTime.fromMillisecondsSinceEpoch(timestamp),
          };
        } else if (data['type'] == 'sensor_status') {
          return {
            'type': 'sensor_status',
            'available': data['available'] as bool,
          };
        }

        return data;
      });
    }
    return _stepStream!;
  }

  /// Get current step count
  static int get currentSteps => _currentSteps;

  /// Calculate daily steps (handles device reboot)
  static int _calculateDailySteps(int totalSteps) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Reset baseline if it's a new day
    if (_lastResetTime == null || _lastResetTime!.isBefore(today)) {
      _baselineSteps = totalSteps;
      _lastResetTime = today;
    }

    return totalSteps - _baselineSteps;
  }

  /// Reset step counter (useful for daily goals)
  static void resetCounter() {
    _currentSteps = 0;
    print('Step counter reset');
  }

  /// Reset step baseline (useful for new games)
  static Future<bool> resetStepBaseline() async {
    try {
      await _methodChannel.invokeMethod('resetStepBaseline');
      print('Step baseline reset for new game');
      return true;
    } catch (e) {
      print('Error resetting step baseline: $e');
      return false;
    }
  }

  /// Check if step sensor is available
  static Future<bool> isSensorAvailable() async {
    try {
      return await _methodChannel.invokeMethod<bool>('getSensorAvailability') ??
          false;
    } catch (e) {
      print('Error checking sensor availability: $e');
      return false;
    }
  }

  /// Dispose resources
  static void dispose() {
    _stepStream = null;
    _isInitialized = false;
    stopTracking();
  }
}
