import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isOnline = true;
  Timer? _connectivityTimer;

  bool get isOnline => _isOnline;

  /// Check network connectivity by attempting a simple Firestore operation
  Future<bool> checkConnectivity() async {
    try {
      await _firestore
          .collection('users')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      _isOnline = true;
      return true;
    } catch (e) {
      _isOnline = false;
      return false;
    }
  }

  /// Start periodic connectivity checks
  void startConnectivityMonitoring() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      checkConnectivity();
    });
  }

  /// Stop connectivity monitoring
  void stopConnectivityMonitoring() {
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
  }

  /// Execute a Firestore operation with retry logic
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await operation().timeout(const Duration(seconds: 10));
      } catch (e) {
        attempts++;

        if (attempts >= maxRetries) {
          rethrow;
        }

        // Wait before retrying
        await Future.delayed(delay * attempts);
      }
    }

    throw Exception('Max retries exceeded');
  }

  /// Dispose of resources
  void dispose() {
    stopConnectivityMonitoring();
  }
}
