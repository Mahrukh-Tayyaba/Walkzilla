import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isOnline = true;
  Timer? _connectivityTimer;
  Timer? _keepAliveTimer;
  int _consecutiveFailures = 0;
  static const int _maxFailures = 3;

  bool get isOnline => _isOnline;

  /// Check network connectivity by attempting a simple Firestore operation
  Future<bool> checkConnectivity() async {
    try {
      await _firestore
          .collection('users')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10)); // Increased timeout

      _isOnline = true;
      _consecutiveFailures = 0; // Reset failure counter on success
      print('✅ Network connectivity check successful');
      return true;
    } catch (e) {
      _consecutiveFailures++;
      print(
          '❌ Network connectivity check failed (attempt $_consecutiveFailures): $e');

      if (_consecutiveFailures >= _maxFailures) {
        _isOnline = false;
        print(
            '🔴 Network marked as offline after $_maxFailures consecutive failures');
      }
      return false;
    }
  }

  /// Start periodic connectivity checks with keep-alive mechanism
  void startConnectivityMonitoring() {
    _connectivityTimer?.cancel();
    _keepAliveTimer?.cancel();

    // Check connectivity every 30 seconds
    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      checkConnectivity();
    });

    // Keep-alive ping every 2 minutes to maintain connection
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _sendKeepAlivePing();
    });

    print('🔄 Network connectivity monitoring started');
  }

  /// Send a keep-alive ping to maintain connection
  Future<void> _sendKeepAlivePing() async {
    if (!_isOnline) return;

    try {
      await _firestore
          .collection('_keepalive')
          .doc('ping')
          .set({'timestamp': FieldValue.serverTimestamp()}).timeout(
              const Duration(seconds: 5));
      print('💓 Keep-alive ping sent successfully');
    } catch (e) {
      print('⚠️ Keep-alive ping failed: $e');
      // Don't mark as offline for keep-alive failures, just log them
    }
  }

  /// Stop connectivity monitoring
  void stopConnectivityMonitoring() {
    _connectivityTimer?.cancel();
    _keepAliveTimer?.cancel();
    _connectivityTimer = null;
    _keepAliveTimer = null;
    print('🛑 Network connectivity monitoring stopped');
  }

  /// Execute a Firestore operation with retry logic and connection recovery
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        // Check connectivity before attempting operation
        if (!_isOnline) {
          print('🔄 Attempting to reconnect before operation...');
          await checkConnectivity();
          if (!_isOnline) {
            throw Exception('No network connectivity');
          }
        }

        return await operation()
            .timeout(const Duration(seconds: 15)); // Increased timeout
      } catch (e) {
        attempts++;
        print('❌ Operation failed (attempt $attempts/$maxRetries): $e');

        if (attempts >= maxRetries) {
          print('🔴 Max retries exceeded, marking network as offline');
          _isOnline = false;
          rethrow;
        }

        // Exponential backoff
        final waitTime = delay * attempts;
        print('⏳ Waiting ${waitTime.inSeconds} seconds before retry...');
        await Future.delayed(waitTime);
      }
    }

    throw Exception('Max retries exceeded');
  }

  /// Force reconnection attempt
  Future<bool> forceReconnect() async {
    print('🔄 Forcing network reconnection...');
    _consecutiveFailures = 0;
    _isOnline = false;
    return await checkConnectivity();
  }

  /// Get current connection status
  String getConnectionStatus() {
    if (_isOnline) {
      return 'Online';
    } else {
      return 'Offline (${_consecutiveFailures} failures)';
    }
  }

  /// Dispose of resources
  void dispose() {
    stopConnectivityMonitoring();
  }
}
