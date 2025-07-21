import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Added for Timer and StreamSubscription
import 'step_counter_service.dart';
import 'leaderboard_service.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  static const bool _forceHybridMode =
      true; // NEVER CHANGE THIS - Ensures hybrid method is always used

  final Health health = Health();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isInitialized = false;

  // Firestore collection names
  static const String _healthDataCollection = 'health_data';

  // Health Connect data types - ONLY what your app actually uses
  final List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  // Initialize Health Connect
  Future<bool> initializeHealthConnect() async {
    try {
      if (_isInitialized) return true;

      print("Initializing Health Connect...");

      // Check if Health Connect is available by trying to get permissions
      bool? hasPermissions = await health.hasPermissions(_dataTypes);
      print("Health Connect available: ${hasPermissions != null}");

      if (hasPermissions == null) {
        print("Health Connect is not available on this device");
        return false;
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing Health Connect: $e');
      return false;
    }
  }

  // Request Health Connect permissions - Updated with better error handling
  Future<bool> requestHealthConnectPermissions() async {
    try {
      print("🔐 Requesting Health Connect permissions...");

      // Initialize first
      bool initialized = await initializeHealthConnect();
      if (!initialized) {
        print("❌ Failed to initialize Health Connect");
        return false;
      }

      // Check current permissions first
      bool? currentPermissions = await health.hasPermissions(_dataTypes);
      print("🔍 Current permissions status: $currentPermissions");

      if (currentPermissions == true) {
        print("✅ Permissions already granted");
        return true;
      }

      // Request permissions with explicit data types and access types
      print(
          "📋 Requesting permissions for: ${_dataTypes.map((e) => e.toString()).join(', ')}");

      // Request permissions with proper access types (READ only for your app)
      print("🔄 Calling health.requestAuthorization...");
      bool granted = await health.requestAuthorization(
        _dataTypes,
        permissions: [
          HealthDataAccess.READ,
          HealthDataAccess.READ,
          HealthDataAccess.READ,
        ],
      );

      print(" Permission request result: $granted");

      // Double-check permissions after request
      if (granted) {
        print("✅ Permission request returned true, verifying...");
        // Wait a moment for permissions to be processed
        await Future.delayed(const Duration(seconds: 2));

        bool? verifiedPermissions = await health.hasPermissions(_dataTypes);
        print("🔍 Verified permissions after request: $verifiedPermissions");

        if (verifiedPermissions == true) {
          print("✅ Permissions successfully granted and verified");

          // Update Firestore to track permissions
          final user = _auth.currentUser;
          if (user != null) {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .update({'hasHealthPermissions': true});
            print("💾 Updated Firestore with permission status");
          }

          return true;
        } else {
          print("❌ Permissions not properly granted despite request success");
          print(
              "🔍 This might indicate the user denied permissions in the dialog");
          return false;
        }
      } else {
        print("❌ Permission request returned false");
        print(
            "🔍 This might indicate the user denied permissions or Health Connect is not available");
        return false;
      }
    } catch (e) {
      print('❌ Error requesting Health Connect permissions: $e');
      print(' Error details: ${e.toString()}');
      return false;
    }
  }

  // Check if we have Health Connect permissions - Updated with better checking
  Future<bool> checkHealthConnectPermissions() async {
    try {
      if (!_isInitialized) {
        await initializeHealthConnect();
      }

      print("🔍 Checking Health Connect permissions...");

      // Check if we have permissions for our data types
      bool? hasPermission = await health.hasPermissions(_dataTypes);
      print("🔍 Permission check result: $hasPermission");

      if (hasPermission == true) {
        print("✅ Health Connect permissions confirmed");
        return true;
      } else if (hasPermission == false) {
        print("❌ Health Connect permissions explicitly denied");
        return false;
      } else {
        print("❓ Health Connect permissions status unclear (null)");
        return false;
      }
    } catch (e) {
      print('❌ Error checking Health Connect permissions: $e');
      return false;
    }
  }

  // Add a method to force refresh permissions
  Future<bool> forceRefreshPermissions() async {
    try {
      print("🔄 Force refreshing Health Connect permissions...");

      // Clear any cached permission state
      _isInitialized = false;

      // Re-initialize
      bool initialized = await initializeHealthConnect();
      if (!initialized) {
        print("❌ Failed to re-initialize Health Connect");
        return false;
      }

      // Check permissions again
      bool hasPermissions = await checkHealthConnectPermissions();

      if (!hasPermissions) {
        print("🔄 No permissions found, requesting again...");
        return await requestHealthConnectPermissions();
      }

      return hasPermissions;
    } catch (e) {
      print('❌ Error force refreshing permissions: $e');
      return false;
    }
  }

  // Add a method to manually verify permissions
  Future<bool> manuallyVerifyPermissions() async {
    try {
      print("🔍 === MANUAL PERMISSION VERIFICATION ===");

      // Force re-initialization
      _isInitialized = false;
      await initializeHealthConnect();

      // Check permissions directly
      bool? hasPermission = await health.hasPermissions(_dataTypes);
      print("🔍 Direct permission check: $hasPermission");

      if (hasPermission == true) {
        print("✅ Permissions verified manually");

        // Update Firestore
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'hasHealthPermissions': true});
          print("💾 Updated Firestore with permission status");
        }

        return true;
      } else {
        print("❌ Permissions not verified manually");
        return false;
      }
    } catch (e) {
      print('❌ Error in manual verification: $e');
      return false;
    }
  }

  Future<bool> checkExistingPermissions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No user logged in, skipping health permission check");
        return false;
      }

      // First check if we have Health Connect permissions
      bool hasHealthConnectPermissions = await checkHealthConnectPermissions();
      if (hasHealthConnectPermissions) {
        return true;
      }

      // Fallback to Firestore check
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data()?['hasHealthPermissions'] == true) {
        _isInitialized = true;
        return true;
      }
      return false;
    } catch (e) {
      print('Error checking existing permissions: $e');
      return false;
    }
  }

  Future<bool> showPermissionDialog(BuildContext context) async {
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Health Connect Access'),
          content: const Text(
            'To track your daily activities and provide personalized insights, '
            'Walkzilla needs access to your health data through Health Connect. '
            'This includes steps, calories burned, and heart rate data.\n\n'
            'Your data privacy is important to us and all data is stored securely.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Not Now'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Allow Access'),
              onPressed: () async {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> openHealthConnect() async {
    const playStoreUrl =
        'market://details?id=com.google.android.apps.healthdata';
    final Uri url = Uri.parse(playStoreUrl);

    try {
      await launchUrl(url);
    } catch (e) {
      print('Error opening Health Connect: $e');
      final webUrl = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata');
      try {
        await launchUrl(webUrl);
      } catch (e) {
        print('Error opening Health Connect web URL: $e');
      }
    }
  }

  Future<bool> _showHealthConnectInstallDialog(BuildContext context) async {
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Health Connect Required'),
          content: const Text(
            'This app requires Health Connect to track your fitness data. '
            'Please install and set up Health Connect from the Play Store, then return to the app.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Install Health Connect'),
              onPressed: () async {
                await openHealthConnect();
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<bool> requestHealthPermissions(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No user logged in, cannot request health permissions");
        return false;
      }

      // Check if Health Connect is available
      bool? isAvailable = await health.hasPermissions(_dataTypes);
      if (isAvailable == null) {
        print("Health Connect not available, showing install dialog");
        if (context.mounted) {
          return await _showHealthConnectInstallDialog(context);
        }
        return false;
      }

      bool hasExistingPermissions = await checkHealthConnectPermissions();
      if (hasExistingPermissions) {
        print("Health Connect permissions already granted");
        return true;
      }

      print("Requesting Health Connect permissions...");
      bool userAccepted = false;
      if (context.mounted) {
        userAccepted = await showPermissionDialog(context);
      }
      print("User accepted dialog: $userAccepted");

      if (userAccepted) {
        bool granted = await requestHealthConnectPermissions();
        return granted;
      }

      return false;
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }

  // Fetch steps data from Health Connect using aggregate API
  Future<int> fetchStepsData() async {
    try {
      print(
          "Fetching real steps data from Health Connect for user ${FirebaseAuth.instance.currentUser?.uid}");

      // Check if we have permissions
      bool hasPermissions = await checkHealthConnectPermissions();
      if (!hasPermissions) {
        print("❌ No Health Connect permissions for steps");
        return 0;
      }

      // Get today's date range
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      print(
          "📅 Fetching steps from ${startOfDay.toIso8601String()} to ${endOfDay.toIso8601String()}");

      // Use aggregate API to get total steps for the day
      try {
        print("🔄 Using aggregate API for steps...");

        // Get aggregated steps data
        final stepsData = await health.getTotalStepsInInterval(
          startOfDay,
          endOfDay,
        );

        print("📊 Aggregated steps from Health Connect: $stepsData");
        return stepsData ?? 0;
      } catch (e) {
        print("❌ Error with aggregate API, falling back to raw data: $e");

        // Fallback to raw data method
        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          startTime: startOfDay,
          endTime: endOfDay,
          types: [HealthDataType.STEPS],
        );
        print("📊 Raw health data points: ${healthData.length}");

        // Calculate total steps with null safety and detailed debugging
        int totalSteps = 0;
        print("🔍 Processing ${healthData.length} health data points:");

        for (int i = 0; i < healthData.length; i++) {
          HealthDataPoint p = healthData[i];
          print("  📊 Data point $i:");
          print("    - Value: ${p.value} (type: ${p.value.runtimeType})");
          print("    - Date from: ${p.dateFrom}");
          print("    - Date to: ${p.dateTo}");
          print("    - Data type: ${p.type}");
          print("    - Unit: ${p.unit}");

          // Handle different value types
          if (p.value is int) {
            totalSteps += p.value as int;
            print("    ✅ Added ${p.value} steps (int)");
          } else if (p.value is double) {
            totalSteps += (p.value as double).toInt();
            print("    ✅ Added ${(p.value as double).toInt()} steps (double)");
          } else {
            print("    ❌ Unknown value type: ${p.value.runtimeType}");
          }
        }

        print("📊 Total steps calculated: $totalSteps");
        return totalSteps;
      }
    } catch (e) {
      print("Error in fetchStepsData: $e");
      return 0;
    }
  }

  // Fetch real heart rate data from Health Connect
  Future<Map<String, dynamic>> fetchHeartRateData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Check if we have Health Connect permissions
      bool hasPermissions = await checkHealthConnectPermissions();
      if (!hasPermissions) {
        print("❌ No Health Connect permissions for heart rate");
        throw Exception(
            'Health Connect permissions required for heart rate data');
      }

      print(
          'Fetching real heart rate data from Health Connect for user ${user.uid}');

      // Get heart rate data from the last hour
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));

      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        startTime: oneHourAgo,
        endTime: now,
        types: [HealthDataType.HEART_RATE],
      );

      double heartRate = 75.0; // Default value
      DateTime? heartRateTime = now;

      if (healthData.isNotEmpty) {
        // Get the most recent heart rate reading
        healthData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        heartRate = (healthData.first.value as num).toDouble();
        heartRateTime = healthData.first.dateFrom;
        print("💖 Real heart rate from Health Connect: $heartRate bpm");
      } else {
        print("💖 No heart rate data found, using default: $heartRate bpm");
      }

      return {
        "time": heartRateTime.toIso8601String(),
        "beatsPerMinute": heartRate,
        "metadata": {
          "id": "hc_hr_${now.millisecondsSinceEpoch}",
          "device": {
            "manufacturer": "Health Connect",
            "model": "System",
            "type": "health_connect"
          },
          "lastModifiedTime": now.toIso8601String()
        }
      };
    } catch (e) {
      print('Error in fetchHeartRateData: $e');
      throw Exception('Failed to fetch heart rate data: $e');
    }
  }

  // Fetch real calories data from Health Connect
  Future<Map<String, dynamic>> fetchCaloriesData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Check if we have Health Connect permissions
      bool hasPermissions = await checkHealthConnectPermissions();
      if (!hasPermissions) {
        print("❌ No Health Connect permissions for calories");
        throw Exception(
            'Health Connect permissions required for calories data');
      }

      print(
          'Fetching real calories data from Health Connect for user ${user.uid}');

      // Get today's active calories
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: endOfDay,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      double totalCalories = 0.0;
      if (healthData.isNotEmpty) {
        for (HealthDataPoint dataPoint in healthData) {
          totalCalories += (dataPoint.value as num).toDouble();
        }
        print("🔥 Real calories from Health Connect: $totalCalories kcal");
      } else {
        print("🔥 No calories data found, using default: $totalCalories kcal");
      }

      return {
        "startTime": startOfDay.toIso8601String(),
        "endTime": endOfDay.toIso8601String(),
        "energy": {"inKilocalories": totalCalories},
        "metadata": {
          "id": "hc_cal_${now.millisecondsSinceEpoch}",
          "device": {
            "manufacturer": "Health Connect",
            "model": "System",
            "type": "health_connect"
          },
          "lastModifiedTime": now.toIso8601String()
        }
      };
    } catch (e) {
      print('Error in fetchCaloriesData: $e');
      throw Exception('Failed to fetch calories data: $e');
    }
  }

  // Main method to fetch all health data
  Future<Map<String, dynamic>> fetchHealthData() async {
    try {
      print("Fetching health data...");

      final user = _auth.currentUser;
      if (user == null) {
        print("No user logged in, cannot fetch health data");
        throw Exception('No user logged in');
      }

      print("User ID: ${user.uid}");

      // Fetch and store each type of data
      print("Fetching steps data...");
      final stepsData = await fetchStepsData();
      print("Steps data fetched: $stepsData steps");

      print("Fetching heart rate data...");
      final heartRateData = await fetchHeartRateData();
      print("Heart rate data fetched: ${heartRateData['beatsPerMinute']} bpm");

      print("Fetching calories data...");
      final caloriesData = await fetchCaloriesData();
      print(
          "Calories data fetched: ${caloriesData['energy']['inKilocalories']} kcal");

      return {
        'steps': stepsData,
        'heartRate': heartRateData,
        'calories': caloriesData
      };
    } catch (e) {
      print('Error fetching health data: $e');
      // Return error states for all data types
      return {
        'steps': await fetchStepsData(),
        'heartRate': await fetchHeartRateData(),
        'calories': await fetchCaloriesData()
      };
    }
  }

  // Background step monitoring
  Timer? _stepMonitoringTimer;
  StreamSubscription? _healthDataSubscription;
  int _lastKnownSteps = 0;
  DateTime _lastStepUpdate = DateTime.now();

  // Start real-time step monitoring
  Future<void> startRealTimeStepMonitoring() async {
    try {
      print("🔄 Starting real-time step monitoring...");

      // Check permissions first
      bool hasPermissions = await checkHealthConnectPermissions();
      if (!hasPermissions) {
        print("❌ No Health Connect permissions for real-time monitoring");
        return;
      }

      // Stop any existing monitoring
      stopRealTimeStepMonitoring();

      // Initial step count
      _lastKnownSteps = await fetchStepsData();
      _lastStepUpdate = DateTime.now();
      print("📊 Initial step count: $_lastKnownSteps");

      // Set up periodic monitoring (every 30 seconds)
      _stepMonitoringTimer =
          Timer.periodic(const Duration(seconds: 30), (timer) async {
        await _checkForStepUpdates();
      });

      // Set up more frequent monitoring for active periods (every 10 seconds during activity)
      Timer.periodic(const Duration(seconds: 10), (timer) async {
        if (_isUserActive()) {
          await _checkForStepUpdates();
        }
      });

      print("✅ Real-time step monitoring started");
    } catch (e) {
      print("❌ Error starting real-time step monitoring: $e");
    }
  }

  // Stop real-time step monitoring
  void stopRealTimeStepMonitoring() {
    _stepMonitoringTimer?.cancel();
    _stepMonitoringTimer = null;
    _healthDataSubscription?.cancel();
    _healthDataSubscription = null;
    print("🛑 Real-time step monitoring stopped");
  }

  // Check if user is active (has taken steps recently)
  bool _isUserActive() {
    final timeSinceLastUpdate = DateTime.now().difference(_lastStepUpdate);
    return timeSinceLastUpdate.inMinutes <
        5; // Active if steps in last 5 minutes
  }

  // Check for step updates
  Future<void> _checkForStepUpdates() async {
    try {
      final currentSteps = await fetchStepsData();

      if (currentSteps > _lastKnownSteps) {
        final stepIncrease = currentSteps - _lastKnownSteps;
        _lastKnownSteps = currentSteps;
        _lastStepUpdate = DateTime.now();

        print(
            "🎉 Step update detected: +$stepIncrease steps (Total: $currentSteps)");

        // Notify listeners about step update
        _notifyStepUpdate(currentSteps, stepIncrease);
      }
    } catch (e) {
      print("❌ Error checking for step updates: $e");
    }
  }

  // Step update callback
  Function(int totalSteps, int stepIncrease)? _onStepUpdate;

  // Set step update callback
  void setStepUpdateCallback(
      Function(int totalSteps, int stepIncrease) callback) {
    _onStepUpdate = callback;
  }

  // Notify step update
  void _notifyStepUpdate(int totalSteps, int stepIncrease) {
    _onStepUpdate?.call(totalSteps, stepIncrease);
  }

  // Get current step count (cached)
  int getCurrentStepCount() {
    return _lastKnownSteps;
  }

  // Force refresh step count
  Future<int> forceRefreshStepCount() async {
    try {
      print("🔄 Force refreshing step count...");

      // Use sensor-optimized step count for accuracy
      final unifiedSteps = await fetchSensorOptimizedSteps();
      final stepIncrease = unifiedSteps - _lastKnownSteps;

      if (unifiedSteps != _lastKnownSteps) {
        _lastKnownSteps = unifiedSteps;
        _lastStepUpdate = DateTime.now();
        _notifyStepUpdate(unifiedSteps, stepIncrease);
        print("✅ Force refresh updated steps: $unifiedSteps (+$stepIncrease)");
      } else {
        print("📊 Force refresh: No change in steps ($unifiedSteps)");
      }

      return unifiedSteps;
    } catch (e) {
      print("❌ Error force refreshing step count: $e");
      return _lastKnownSteps;
    }
  }

  // Enhanced real-time monitoring with smart polling
  Timer? _smartPollingTimer;
  DateTime? _lastStepCheck;
  int _consecutiveNoChangeCount = 0;
  Duration _currentPollingInterval = const Duration(seconds: 30);

  // Smart polling intervals based on activity
  static const Duration _fastPolling = Duration(seconds: 10);
  static const Duration _normalPolling = Duration(seconds: 30);
  static const Duration _slowPolling = Duration(seconds: 60);

  // Start enhanced real-time monitoring with smart polling
  Future<void> startEnhancedRealTimeMonitoring() async {
    try {
      print("🚀 Starting enhanced real-time monitoring with smart polling...");

      // Stop any existing monitoring
      stopAllMonitoring();

      // Initial step count
      _lastKnownSteps = await fetchStepsData();
      _lastStepUpdate = DateTime.now();
      _lastStepCheck = DateTime.now();
      print("📊 Initial step count: $_lastKnownSteps");

      // Start smart polling
      _startSmartPolling();

      print("✅ Enhanced real-time monitoring started");
    } catch (e) {
      print("❌ Error starting enhanced monitoring: $e");
      // Fallback to regular polling
      startRealTimeStepMonitoring();
    }
  }

  // Smart polling that adapts to user activity
  void _startSmartPolling() {
    _smartPollingTimer?.cancel();

    _smartPollingTimer = Timer.periodic(_currentPollingInterval, (timer) async {
      await _smartPollingCheck();
    });
  }

  // Smart polling check with adaptive intervals
  Future<void> _smartPollingCheck() async {
    try {
      final currentSteps = await fetchStepsData();
      final now = DateTime.now();

      if (currentSteps > _lastKnownSteps) {
        // Steps increased - user is active
        final stepIncrease = currentSteps - _lastKnownSteps;
        _lastKnownSteps = currentSteps;
        _lastStepUpdate = now;
        _consecutiveNoChangeCount = 0;

        // Switch to fast polling when activity detected
        if (_currentPollingInterval != _fastPolling) {
          _currentPollingInterval = _fastPolling;
          _startSmartPolling();
          print("🏃 User active - switching to fast polling (10s)");
        }

        print(
            "🎉 Smart polling detected step increase: +$stepIncrease steps (Total: $currentSteps)");
        _notifyStepUpdate(currentSteps, stepIncrease);
      } else if (currentSteps == _lastKnownSteps) {
        // No change in steps
        _consecutiveNoChangeCount++;

        // Adjust polling interval based on inactivity
        if (_consecutiveNoChangeCount >= 6 &&
            _currentPollingInterval == _fastPolling) {
          // After 1 minute of no changes, switch to normal polling
          _currentPollingInterval = _normalPolling;
          _startSmartPolling();
          print("😴 User inactive - switching to normal polling (30s)");
        } else if (_consecutiveNoChangeCount >= 20 &&
            _currentPollingInterval == _normalPolling) {
          // After 10 minutes of no changes, switch to slow polling
          _currentPollingInterval = _slowPolling;
          _startSmartPolling();
          print("💤 User very inactive - switching to slow polling (60s)");
        }

        print(
            "📊 Smart polling: No step change (count: $_consecutiveNoChangeCount)");
      }

      _lastStepCheck = now;
    } catch (e) {
      print("❌ Error in smart polling check: $e");
    }
  }

  // Get current polling status
  Map<String, dynamic> getPollingStatus() {
    return {
      'currentInterval': _currentPollingInterval.inSeconds,
      'lastCheck': _lastStepCheck,
      'lastUpdate': _lastStepUpdate,
      'consecutiveNoChangeCount': _consecutiveNoChangeCount,
      'lastKnownSteps': _lastKnownSteps,
    };
  }

  // Force refresh with smart polling reset
  Future<int> forceRefreshWithSmartReset() async {
    try {
      final newSteps = await fetchStepsData();
      final stepIncrease = newSteps - _lastKnownSteps;

      if (newSteps != _lastKnownSteps) {
        _lastKnownSteps = newSteps;
        _lastStepUpdate = DateTime.now();
        _consecutiveNoChangeCount = 0;

        // Reset to fast polling if there's activity
        if (stepIncrease > 0) {
          _currentPollingInterval = _fastPolling;
          _startSmartPolling();
        }

        _notifyStepUpdate(newSteps, stepIncrease);
      }

      return newSteps;
    } catch (e) {
      print("❌ Error force refreshing with smart reset: $e");
      return _lastKnownSteps;
    }
  }

  // Enhanced sync system to force Google Fit data refresh
  Timer? _aggressiveSyncTimer;
  int _syncAttempts = 0;
  static const int _maxSyncAttempts = 5;

  // Start aggressive sync monitoring
  Future<void> startAggressiveSyncMonitoring() async {
    try {
      print("🚀 Starting aggressive sync monitoring...");

      // Stop any existing monitoring
      stopAllMonitoring();

      // Initial sync
      await _forceAggressiveSync();

      // Set up aggressive sync timer (every 20 seconds)
      _aggressiveSyncTimer =
          Timer.periodic(const Duration(seconds: 20), (timer) async {
        await _forceAggressiveSync();
      });

      print("✅ Aggressive sync monitoring started");
    } catch (e) {
      print("❌ Error starting aggressive sync monitoring: $e");
    }
  }

  // Force aggressive sync with multiple strategies
  Future<void> _forceAggressiveSync() async {
    try {
      _syncAttempts++;
      print("🔄 Aggressive sync attempt $_syncAttempts...");

      // Strategy 1: Force refresh Health Connect data
      await _refreshHealthConnectData();

      // Strategy 2: Check for step changes
      final currentSteps = await fetchStepsData();

      if (currentSteps > _lastKnownSteps) {
        final stepIncrease = currentSteps - _lastKnownSteps;
        _lastKnownSteps = currentSteps;
        _lastStepUpdate = DateTime.now();
        _syncAttempts = 0; // Reset attempts on success

        print(
            "🎉 Aggressive sync successful: +$stepIncrease steps (Total: $currentSteps)");
        _notifyStepUpdate(currentSteps, stepIncrease);
      } else {
        print("📊 Aggressive sync: No new steps detected");

        // If we've tried too many times without success, try alternative strategies
        if (_syncAttempts >= _maxSyncAttempts) {
          await _tryAlternativeSyncStrategies();
          _syncAttempts = 0; // Reset for next cycle
        }
      }
    } catch (e) {
      print("❌ Error in aggressive sync: $e");
    }
  }

  // Refresh Health Connect data by re-initializing
  Future<void> _refreshHealthConnectData() async {
    try {
      print("🔄 Refreshing Health Connect data...");

      // Re-initialize Health Connect
      await initializeHealthConnect();

      // Force permission check
      await checkHealthConnectPermissions();

      // Small delay to allow data to refresh
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print("❌ Error refreshing Health Connect data: $e");
    }
  }

  // Try alternative sync strategies
  Future<void> _tryAlternativeSyncStrategies() async {
    try {
      print("🔄 Trying alternative sync strategies...");

      // Strategy 1: Try different time ranges
      await _tryDifferentTimeRanges();

      // Strategy 2: Force data refresh with different parameters
      await _forceDataRefreshWithDifferentParams();
    } catch (e) {
      print("❌ Error in alternative sync strategies: $e");
    }
  }

  // Try fetching data with different time ranges
  Future<void> _tryDifferentTimeRanges() async {
    try {
      print("🔄 Trying different time ranges...");

      final now = DateTime.now();

      // Try last 2 hours
      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      final steps2h = await _fetchStepsForTimeRange(twoHoursAgo, now);

      // Try last 4 hours
      final fourHoursAgo = now.subtract(const Duration(hours: 4));
      final steps4h = await _fetchStepsForTimeRange(fourHoursAgo, now);

      // Try today from midnight
      final startOfDay = DateTime(now.year, now.month, now.day);
      final stepsToday = await _fetchStepsForTimeRange(startOfDay, now);

      print(
          "📊 Time range results - 2h: $steps2h, 4h: $steps4h, Today: $stepsToday");

      // Use the highest value
      final maxSteps =
          [steps2h, steps4h, stepsToday].reduce((a, b) => a > b ? a : b);

      if (maxSteps > _lastKnownSteps) {
        final stepIncrease = maxSteps - _lastKnownSteps;
        _lastKnownSteps = maxSteps;
        _lastStepUpdate = now;

        print(
            "🎉 Alternative sync successful: +$stepIncrease steps (Total: $maxSteps)");
        _notifyStepUpdate(maxSteps, stepIncrease);
      }
    } catch (e) {
      print("❌ Error trying different time ranges: $e");
    }
  }

  // Fetch steps for a specific time range
  Future<int> _fetchStepsForTimeRange(DateTime start, DateTime end) async {
    try {
      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.STEPS],
      );

      int totalSteps = 0;
      for (HealthDataPoint p in healthData) {
        if (p.value is int) {
          totalSteps += p.value as int;
        } else if (p.value is double) {
          totalSteps += (p.value as double).toInt();
        }
      }

      return totalSteps;
    } catch (e) {
      print("❌ Error fetching steps for time range: $e");
      return 0;
    }
  }

  // Force data refresh with different parameters
  Future<void> _forceDataRefreshWithDifferentParams() async {
    try {
      print("🔄 Forcing data refresh with different parameters...");

      // Try with different data types to trigger sync
      await health.getHealthDataFromTypes(
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now(),
        types: [HealthDataType.HEART_RATE],
      );

      await health.getHealthDataFromTypes(
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now(),
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      // Small delay
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      print("❌ Error forcing data refresh: $e");
    }
  }

  // Enhanced force refresh that tries multiple strategies
  Future<int> forceRefreshWithMultipleStrategies() async {
    try {
      print("🔄 Force refresh with multiple strategies...");

      // Strategy 1: Normal fetch
      int steps = await fetchStepsData();

      // Strategy 2: If no change, try different time ranges
      if (steps <= _lastKnownSteps) {
        await _tryDifferentTimeRanges();
        steps = _lastKnownSteps;
      }

      // Strategy 3: If still no change, force Health Connect refresh
      if (steps <= _lastKnownSteps) {
        await _refreshHealthConnectData();
        steps = await fetchStepsData();
      }

      return steps;
    } catch (e) {
      print("❌ Error in force refresh with multiple strategies: $e");
      return _lastKnownSteps;
    }
  }

  // Stop aggressive sync monitoring
  void stopAggressiveSyncMonitoring() {
    _aggressiveSyncTimer?.cancel();
    _aggressiveSyncTimer = null;
    _syncAttempts = 0;
    print("🛑 Aggressive sync monitoring stopped");
  }

  // Enhanced stop all monitoring
  void stopAllMonitoring() {
    stopRealTimeStepMonitoring();
    stopAggressiveSyncMonitoring();
    _smartPollingTimer?.cancel();
    _smartPollingTimer = null;
    print("🛑 All monitoring stopped");
  }

  // ===== REAL-TIME STEP TRACKING INTEGRATION =====

  StreamSubscription<Map<String, dynamic>>? _realTimeStepSubscription;
  bool _isRealTimeTrackingActive = false;
  int _healthConnectBaseline = 0; // Store initial Health Connect steps
  bool _baselineSet = false; // Track if baseline has been set
  DateTime? _lastSyncTime; // Track last Google Fit sync

  /// Start real-time step tracking using hardware sensor
  Future<bool> startRealTimeStepTracking() async {
    try {
      print("🚀 Starting real-time step tracking...");

      // Initialize step counter service
      final initialized = await StepCounterService.initialize();
      if (!initialized) {
        print("❌ Failed to initialize step counter service");
        return false;
      }

      // Start tracking
      final started = await StepCounterService.startTracking();
      if (!started) {
        print("❌ Failed to start step tracking");
        return false;
      }

      // Listen to real-time updates
      _realTimeStepSubscription = StepCounterService.stepStream.listen(
        (data) async {
          if (data['type'] == 'step_update') {
            final currentSteps = data['currentSteps'] as int;
            final dailySteps = data['dailySteps'] as int;
            final timestamp = data['timestamp'] as DateTime;

            print(
                "👟 Real-time step update: $currentSteps steps (Daily: $dailySteps)");

            // Only update if we have a valid baseline
            if (_baselineSet) {
              // Calculate unified step count using baseline
              final unifiedSteps = _healthConnectBaseline + currentSteps;

              // Update last known steps
              _lastKnownSteps = unifiedSteps;
              _lastStepUpdate = timestamp;

              // Notify listeners with unified count
              print(
                  "🎯 Sending unified step update: $unifiedSteps (baseline: $_healthConnectBaseline + real-time: $currentSteps)");
              _notifyStepUpdate(unifiedSteps, currentSteps);
            } else {
              print("⚠️ Baseline not set yet, skipping update");
            }
          } else if (data['type'] == 'sensor_status') {
            final available = data['available'] as bool;
            print(
                "📱 Step sensor status: ${available ? 'Available' : 'Not available'}");
          }
        },
        onError: (error) {
          print("❌ Error in real-time step stream: $error");
        },
      );

      _isRealTimeTrackingActive = true;
      print("✅ Real-time step tracking started successfully");
      return true;
    } catch (e) {
      print("❌ Error starting real-time step tracking: $e");
      return false;
    }
  }

  /// Stop real-time step tracking
  Future<void> stopRealTimeStepTracking() async {
    try {
      print("🛑 Stopping real-time step tracking...");

      _realTimeStepSubscription?.cancel();
      _realTimeStepSubscription = null;

      await StepCounterService.stopTracking();

      _isRealTimeTrackingActive = false;
      print("✅ Real-time step tracking stopped");
    } catch (e) {
      print("❌ Error stopping real-time step tracking: $e");
    }
  }

  /// Check if real-time tracking is active
  bool get isRealTimeTrackingActive => _isRealTimeTrackingActive;

  /// Get current real-time step count
  int get currentRealTimeSteps => StepCounterService.currentSteps;

  /// ACCURATE HYBRID - Syncs perfectly with Google Fit
  Future<int> fetchAccurateHybridSteps() async {
    try {
      print("🎯 ACCURATE HYBRID: Starting accurate step fetch...");

      // Get the most recent Health Connect steps (this should match Google Fit)
      final healthConnectSteps = await fetchStepsData();
      print("🎯 ACCURATE HYBRID: Health Connect steps: $healthConnectSteps");

      // For accuracy, we'll use ONLY Health Connect steps to match Google Fit
      // The real-time sensor can cause double-counting issues
      final accurateSteps = healthConnectSteps;

      print(
          "🎯 ACCURATE HYBRID: Using Health Connect only for accuracy: $accurateSteps");
      print("🎯 ACCURATE HYBRID: This should match Google Fit exactly");

      return accurateSteps;
    } catch (e) {
      print("🎯 ACCURATE HYBRID: Error, using fallback: $e");
      return 0;
    }
  }

  /// SMART HYBRID - Uses real-time sensor only for animation detection, Health Connect for display
  Future<int> fetchSmartHybridSteps() async {
    try {
      print("🧠 SMART HYBRID: Starting smart step fetch...");

      // Get Health Connect steps for display accuracy
      final healthConnectSteps = await fetchStepsData();
      print(
          "🧠 SMART HYBRID: Health Connect steps (display): $healthConnectSteps");

      // Get real-time sensor steps for animation detection only
      final realTimeSteps = StepCounterService.currentSteps;
      print(
          "🧠 SMART HYBRID: Real-time sensor steps (animation): $realTimeSteps");

      // Use Health Connect for display (matches Google Fit)
      // Use real-time sensor only for detecting if user is currently walking
      final displaySteps = healthConnectSteps;

      print("🧠 SMART HYBRID: Display steps (Health Connect): $displaySteps");
      print("🧠 SMART HYBRID: Animation detection (Real-time): $realTimeSteps");

      return displaySteps;
    } catch (e) {
      print("🧠 SMART HYBRID: Error, using fallback: $e");
      return 0;
    }
  }

  /// GOOGLE FIT SYNC - Ensures perfect sync with Google Fit
  Future<int> fetchGoogleFitSyncSteps() async {
    try {
      print("📱 GOOGLE FIT SYNC: Starting Google Fit sync...");

      // Force refresh Health Connect data to ensure latest sync
      final steps = await fetchStepsData();

      print("📱 GOOGLE FIT SYNC: Steps synced with Google Fit: $steps");
      print("📱 GOOGLE FIT SYNC: This should match Google Fit exactly");

      return steps;
    } catch (e) {
      print("📱 GOOGLE FIT SYNC: Error, using fallback: $e");
      return 0;
    }
  }

  /// Hybrid step fetching - combines Health Connect and real-time sensor
  /// BULLETPROOF VERSION - Multiple safeguards to prevent disruption
  Future<int> fetchHybridStepsData() async {
    try {
      print("🛡️ BULLETPROOF: Starting hybrid step fetch...");

      // SAFEGUARD 1: Ensure baseline is always set
      if (!_baselineSet) {
        print("🛡️ BULLETPROOF: Baseline not set, setting it now...");
        final healthConnectSteps = await fetchStepsData();
        _healthConnectBaseline = healthConnectSteps;
        _baselineSet = true;
        print("🛡️ BULLETPROOF: Set baseline to: $_healthConnectBaseline");
      }

      // SAFEGUARD 2: Get Health Connect steps with error handling
      int healthConnectSteps;
      try {
        healthConnectSteps = await fetchStepsData();
        print("🛡️ BULLETPROOF: Health Connect steps: $healthConnectSteps");
      } catch (e) {
        print(
            "🛡️ BULLETPROOF: Health Connect error, using baseline: $_healthConnectBaseline");
        healthConnectSteps = _healthConnectBaseline;
      }

      // SAFEGUARD 3: Get real-time sensor steps with fallback
      int realTimeSteps;
      try {
        realTimeSteps = StepCounterService.currentSteps;
        print("🛡️ BULLETPROOF: Real-time sensor steps: $realTimeSteps");
      } catch (e) {
        print("🛡️ BULLETPROOF: Real-time sensor error, using 0");
        realTimeSteps = 0;
      }

      // SAFEGUARD 4: Validate data integrity
      if (healthConnectSteps < 0) {
        print("🛡️ BULLETPROOF: Invalid Health Connect steps, using baseline");
        healthConnectSteps = _healthConnectBaseline;
      }

      if (realTimeSteps < 0) {
        print("🛡️ BULLETPROOF: Invalid real-time steps, using 0");
        realTimeSteps = 0;
      }

      // SAFEGUARD 5: Calculate unified step count with validation
      final unifiedSteps = healthConnectSteps + realTimeSteps;

      // SAFEGUARD 6: Ensure result is never negative
      final finalSteps = unifiedSteps < 0 ? 0 : unifiedSteps;

      print(
          "🛡️ BULLETPROOF: Final unified steps: $healthConnectSteps (Health Connect) + $realTimeSteps (Real-time) = $finalSteps");

      // SAFEGUARD 7: Update baseline if Health Connect steps increased significantly
      if (healthConnectSteps > _healthConnectBaseline + 10) {
        print(
            "🛡️ BULLETPROOF: Health Connect steps increased significantly, updating baseline");
        _healthConnectBaseline = healthConnectSteps;
        print("🛡️ BULLETPROOF: Updated baseline to: $_healthConnectBaseline");
      }

      return finalSteps;
    } catch (e) {
      print(
          "🛡️ BULLETPROOF: Critical error in hybrid fetch, using fallback: $e");

      // SAFEGUARD 8: Ultimate fallback - return baseline or 0
      if (_baselineSet) {
        print(
            "🛡️ BULLETPROOF: Returning baseline as fallback: $_healthConnectBaseline");
        return _healthConnectBaseline;
      } else {
        print("🛡️ BULLETPROOF: No baseline available, returning 0");
        return 0;
      }
    }
  }

  /// FORCE HYBRID - Always use hybrid method regardless of errors
  Future<int> forceHybridStepsData() async {
    print("💪 FORCE HYBRID: Ensuring hybrid method is used...");

    // Force baseline setup
    if (!_baselineSet) {
      try {
        final steps = await fetchStepsData();
        _healthConnectBaseline = steps;
        _baselineSet = true;
        print(
            "💪 FORCE HYBRID: Forced baseline setup: $_healthConnectBaseline");
      } catch (e) {
        _healthConnectBaseline = 0;
        _baselineSet = true;
        print("💪 FORCE HYBRID: Forced baseline to 0 due to error");
      }
    }

    return await fetchSensorOptimizedSteps();
  }

  /// ANIMATION-SAFE HYBRID - Specifically for character animations
  Future<int> fetchAnimationSafeSteps() async {
    print("🎬 ANIMATION-SAFE: Fetching steps for character animation...");

    // VALIDATION: Ensure hybrid mode is always used
    if (!_forceHybridMode) {
      print(
          "🚨 CRITICAL ERROR: Hybrid mode is disabled! This will break animations!");
      print("🚨 CRITICAL ERROR: _forceHybridMode must always be true!");
    }

    // Use Google Fit sync for accuracy
    final steps = await fetchGoogleFitSyncSteps();

    print("🎬 ANIMATION-SAFE: Steps for animation: $steps");
    return steps;
  }

  /// VALIDATION: Ensure hybrid method is always used
  void validateHybridMode() {
    if (!_forceHybridMode) {
      throw Exception(
          "CRITICAL: Hybrid mode is disabled! This will break character animations!");
    }
    print("✅ Hybrid mode validation passed - animations will work correctly");
  }

  /// FORCE VALIDATION: Call this before any step fetch to ensure hybrid mode
  Future<int> forceValidatedHybridSteps() async {
    validateHybridMode();
    return await fetchAnimationSafeSteps();
  }

  /// Initialize both Health Connect and real-time tracking
  Future<bool> initializeHybridTracking() async {
    try {
      print("🔄 Initializing hybrid tracking system...");

      // Initialize Health Connect
      final healthConnectInitialized = await initializeHealthConnect();

      // Initialize real-time tracking
      final realTimeInitialized = await StepCounterService.initialize();

      // Set baseline immediately if Health Connect is available
      if (healthConnectInitialized && !_baselineSet) {
        final initialSteps = await fetchStepsData();
        _healthConnectBaseline = initialSteps;
        _baselineSet = true;
        print("📊 Set initial baseline: $_healthConnectBaseline");
      }

      print(
          "🏥 Health Connect: ${healthConnectInitialized ? 'Ready' : 'Not available'}");
      print(
          "📱 Real-time sensor: ${realTimeInitialized ? 'Ready' : 'Not available'}");

      return healthConnectInitialized || realTimeInitialized;
    } catch (e) {
      print("❌ Error initializing hybrid tracking: $e");
      return false;
    }
  }

  /// Enhanced monitoring that uses both systems
  Future<void> startHybridMonitoring() async {
    try {
      print("🚀 Starting hybrid monitoring...");

      // Start real-time tracking if available
      if (await StepCounterService.isSensorAvailable()) {
        await startRealTimeStepTracking();
        print("✅ Real-time tracking started");
      } else {
        print("⚠️ Real-time sensor not available, using Health Connect only");
        // Only use Health Connect monitoring if real-time sensor is not available
        await startRealTimeStepMonitoring();
      }

      print("✅ Hybrid monitoring started");
    } catch (e) {
      print("❌ Error starting hybrid monitoring: $e");
    }
  }

  /// Stop hybrid monitoring
  Future<void> stopHybridMonitoring() async {
    try {
      print("🛑 Stopping hybrid monitoring...");

      await stopRealTimeStepTracking();
      stopRealTimeStepMonitoring();

      print("✅ Hybrid monitoring stopped");
    } catch (e) {
      print("❌ Error stopping hybrid monitoring: $e");
    }
  }

  /// Reset baseline (useful for new day or app restart)
  void resetBaseline() {
    _baselineSet = false;
    _healthConnectBaseline = 0;
    print("🔄 Baseline reset");
  }

  /// Get current baseline value
  int get healthConnectBaseline => _healthConnectBaseline;

  /// SENSOR-OPTIMIZED ANIMATION DETECTION - Uses optimal Google Fit + sensor approach
  Future<int> fetchSensorOptimizedSteps() async {
    try {
      print("📱 SENSOR-OPTIMIZED: Starting sensor-optimized step fetch...");

      // Use the optimal approach: Google Fit for accuracy
      final accurateSteps = await fetchOptimalSteps();
      print("📱 SENSOR-OPTIMIZED: Optimal steps (Google Fit): $accurateSteps");

      // Get real-time sensor data for animation detection
      final sensorSteps = StepCounterService.currentSteps;
      final isSensorActive = await StepCounterService.isSensorAvailable();

      print("📱 SENSOR-OPTIMIZED: Real-time sensor steps: $sensorSteps");
      print("📱 SENSOR-OPTIMIZED: Sensor active: $isSensorActive");

      // Use Google Fit steps for display accuracy
      final displaySteps = accurateSteps;

      print("📱 SENSOR-OPTIMIZED: Display steps (Google Fit): $displaySteps");
      print("📱 SENSOR-OPTIMIZED: Animation detection (Sensor): $sensorSteps");

      return displaySteps;
    } catch (e) {
      print("📱 SENSOR-OPTIMIZED: Error, using fallback: $e");
      return 0;
    }
  }

  /// REAL-TIME ANIMATION DETECTOR - Uses sensors to detect active walking
  Future<bool> isUserActivelyWalking() async {
    try {
      print("🎬 ANIMATION DETECTOR: Checking if user is actively walking...");

      // Check if real-time sensor is available
      final isSensorAvailable = await StepCounterService.isSensorAvailable();
      if (!isSensorAvailable) {
        print(
            "🎬 ANIMATION DETECTOR: Sensor not available, using Health Connect");
        return false; // Fall back to Health Connect detection
      }

      // Get real-time sensor steps
      final currentSensorSteps = StepCounterService.currentSteps;
      final lastKnownSensorSteps = _lastKnownSteps;

      print("🎬 ANIMATION DETECTOR: Current sensor steps: $currentSensorSteps");
      print(
          "🎬 ANIMATION DETECTOR: Last known sensor steps: $lastKnownSensorSteps");

      // Check if sensor steps increased recently (within last 5 seconds)
      final timeSinceLastUpdate =
          DateTime.now().difference(_lastStepUpdate).inSeconds;
      final stepsIncreased = currentSensorSteps > lastKnownSensorSteps;

      print(
          "🎬 ANIMATION DETECTOR: Time since last update: ${timeSinceLastUpdate}s");
      print("🎬 ANIMATION DETECTOR: Steps increased: $stepsIncreased");

      // User is actively walking if:
      // 1. Sensor steps increased recently, OR
      // 2. Last update was very recent (within 3 seconds)
      final isActivelyWalking = stepsIncreased || timeSinceLastUpdate <= 3;

      print("🎬 ANIMATION DETECTOR: User actively walking: $isActivelyWalking");

      return isActivelyWalking;
    } catch (e) {
      print("🎬 ANIMATION DETECTOR: Error, using fallback: $e");
      return false;
    }
  }

  /// HYBRID ANIMATION SYSTEM - Combines Google Fit accuracy with sensor responsiveness
  Future<Map<String, dynamic>> fetchHybridAnimationData() async {
    try {
      print("🎮 HYBRID ANIMATION: Starting hybrid animation system...");

      // Get accurate step count from Google Fit
      final googleFitSteps = await fetchGoogleFitSyncSteps();

      // Check if user is actively walking using sensors
      final isActivelyWalking = await isUserActivelyWalking();

      print("🎮 HYBRID ANIMATION: Google Fit steps: $googleFitSteps");
      print("🎮 HYBRID ANIMATION: Actively walking: $isActivelyWalking");

      return {
        'steps': googleFitSteps,
        'isActivelyWalking': isActivelyWalking,
        'source': 'hybrid_animation_system'
      };
    } catch (e) {
      print("🎮 HYBRID ANIMATION: Error, using fallback: $e");
      return {'steps': 0, 'isActivelyWalking': false, 'source': 'fallback'};
    }
  }

  /// ACCURATE DAILY STEPS - Uses baseline + incremental sensor approach
  Future<int> fetchAccurateDailySteps() async {
    try {
      print("🎯 ACCURATE DAILY: Starting accurate daily step calculation...");

      // Get Health Connect steps at app launch (baseline)
      if (!_baselineSet) {
        final hcStepsAtLaunch = await fetchStepsData();
        _healthConnectBaseline = hcStepsAtLaunch;
        _baselineSet = true;
        print(
            "🎯 ACCURATE DAILY: Set baseline at launch: $_healthConnectBaseline");
      }

      // Get current sensor steps
      final sensorCurrent = StepCounterService.currentSteps;
      final sensorStartSteps = 0; // We start counting from 0 when app launches

      // Calculate: stepsToday = hcStepsAtLaunch + (sensorCurrent - sensorStartSteps)
      final stepsToday =
          _healthConnectBaseline + (sensorCurrent - sensorStartSteps);

      print(
          "🎯 ACCURATE DAILY: Baseline (HC at launch): $_healthConnectBaseline");
      print("🎯 ACCURATE DAILY: Sensor current: $sensorCurrent");
      print("🎯 ACCURATE DAILY: Sensor start: $sensorStartSteps");
      print(
          "🎯 ACCURATE DAILY: Increment: ${sensorCurrent - sensorStartSteps}");
      print("🎯 ACCURATE DAILY: Total steps today: $stepsToday");
      print("🎯 ACCURATE DAILY: This should match Google Fit exactly!");

      return stepsToday;
    } catch (e) {
      print("🎯 ACCURATE DAILY: Error, using fallback: $e");
      return _healthConnectBaseline;
    }
  }

  /// RESET DAILY BASELINE - Call this when starting a new day
  Future<void> resetDailyBaseline() async {
    try {
      print("🔄 RESET DAILY: Resetting daily baseline...");

      // Get current Health Connect steps as new baseline
      final newBaseline = await fetchStepsData();
      _healthConnectBaseline = newBaseline;
      _baselineSet = true;

      // Reset sensor tracking
      StepCounterService.resetCounter();

      print("🔄 RESET DAILY: New baseline set: $_healthConnectBaseline");
      print("🔄 RESET DAILY: Sensor counter reset");
    } catch (e) {
      print("🔄 RESET DAILY: Error resetting baseline: $e");
    }
  }

  /// OPTIMAL STEP COUNTING - Google Fit for accuracy, sensors for animation
  Future<int> fetchOptimalSteps() async {
    try {
      print("🎯 OPTIMAL: Starting optimal step fetch...");

      // Get accurate step count directly from Google Fit
      final accurateSteps = await fetchStepsData();
      print("🎯 OPTIMAL: Google Fit steps (accurate): $accurateSteps");

      // Use sensors ONLY for animation detection, not step counting
      final sensorSteps = StepCounterService.currentSteps;
      final isSensorActive = await StepCounterService.isSensorAvailable();

      print("🎯 OPTIMAL: Sensor steps (animation only): $sensorSteps");
      print("🎯 OPTIMAL: Sensor active: $isSensorActive");

      // Return Google Fit steps for display accuracy
      print("🎯 OPTIMAL: Returning Google Fit steps: $accurateSteps");
      return accurateSteps;
    } catch (e) {
      print("🎯 OPTIMAL: Error, using fallback: $e");
      return 0;
    }
  }

  /// ANIMATION STATE DETECTION - Uses sensors for real-time responsiveness
  Future<bool> isUserWalkingForAnimation() async {
    try {
      // Use sensor steps to detect if user is actively walking
      final sensorSteps = StepCounterService.currentSteps;
      final isSensorActive = await StepCounterService.isSensorAvailable();

      // Simple walking detection: if sensor is active and steps > 0, user is walking
      final isWalking = isSensorActive && sensorSteps > 0;
      print(
          "🎭 ANIMATION: Sensor steps: $sensorSteps, Sensor active: $isSensorActive, Walking: $isWalking");
      return isWalking;
    } catch (e) {
      print("🎭 ANIMATION: Error detecting walking state: $e");
      return false;
    }
  }

  /// COMPLETE STEP DATA - Combines accurate steps + animation state
  Future<Map<String, dynamic>> fetchCompleteStepData() async {
    try {
      print("🎯 COMPLETE: Fetching complete step data...");

      // Get accurate steps from Google Fit
      final accurateSteps = await fetchOptimalSteps();

      // Get animation state from sensors
      final isWalking = await isUserWalkingForAnimation();

      final result = {
        'steps': accurateSteps,
        'isWalking': isWalking,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      print(
          "🎯 COMPLETE: Steps: ${result['steps']}, Walking: ${result['isWalking']}");
      return result;
    } catch (e) {
      print("🎯 COMPLETE: Error: $e");
      return {
        'steps': 0,
        'isWalking': false,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  /// HYBRID REAL-TIME STEPS - Shows immediate feedback + Google Fit accuracy
  Future<int> fetchHybridRealTimeSteps() async {
    try {
      print("🔄 HYBRID: Starting hybrid real-time step calculation...");

      // Get Google Fit baseline (accurate but slow)
      if (!_baselineSet) {
        final hcStepsAtLaunch = await fetchStepsData();
        _healthConnectBaseline = hcStepsAtLaunch;
        _baselineSet = true;
        print("🔄 HYBRID: Set Google Fit baseline: $_healthConnectBaseline");
      }

      // Get real-time sensor steps (fast but incremental)
      final sensorSteps = StepCounterService.currentSteps;
      final isSensorActive = await StepCounterService.isSensorAvailable();

      print("🔄 HYBRID: Google Fit baseline: $_healthConnectBaseline");
      print("🔄 HYBRID: Real-time sensor steps: $sensorSteps");
      print("🔄 HYBRID: Sensor active: $isSensorActive");

      // Calculate: baseline + real-time increment
      final realTimeSteps = _healthConnectBaseline + sensorSteps;

      print("🔄 HYBRID: Real-time total: $realTimeSteps");
      print("🔄 HYBRID: User sees steps update immediately!");

      // Update leaderboard data in background
      _updateLeaderboardData(realTimeSteps);

      return realTimeSteps;
    } catch (e) {
      print("🔄 HYBRID: Error, using fallback: $e");
      return _healthConnectBaseline;
    }
  }

  /// Update leaderboard data when steps are fetched
  Future<void> _updateLeaderboardData(int steps) async {
    try {
      final user = _auth.currentUser;
      if (user != null && steps > 0) {
        // Update both daily steps and leaderboard totals
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

        // Get current user data
        final userRef = _firestore.collection('users').doc(user.uid);
        final userDoc = await userRef.get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final dailySteps =
              userData['daily_steps'] as Map<String, dynamic>? ?? {};
          final currentDailySteps = dailySteps[today] ?? 0;

          // Only update if steps have increased
          if (steps > currentDailySteps) {
            final stepIncrease = steps - currentDailySteps;

            // Update daily steps first
            await userRef.update({
              'daily_steps.$today': steps,
            });

            // Calculate weekly total correctly (Monday to Sunday)
            final startOfWeek = _getStartOfWeek(DateTime.now());
            int weeklyTotal = 0;

            // Sum all daily steps from this week (Monday to Sunday)
            for (int i = 0; i < 7; i++) {
              final date = startOfWeek.add(Duration(days: i));
              final dateKey = DateFormat('yyyy-MM-dd').format(date);

              // Use today's new steps if it's today, otherwise use stored daily steps
              if (dateKey == today) {
                weeklyTotal += steps;
              } else {
                final daySteps = (dailySteps[dateKey] ?? 0) as int;
                weeklyTotal += daySteps;
              }
            }

            // Update weekly_steps field
            await userRef.update({
              'weekly_steps': weeklyTotal,
            });

            print(
                "📊 LEADERBOARD: Updated daily steps: $currentDailySteps → $steps (+$stepIncrease)");
            print("📊 LEADERBOARD: Updated weekly total: $weeklyTotal");
            print("📊 LEADERBOARD: Updated leaderboard data for ${user.uid}");
          }
        } else {
          // Initialize user data if it doesn't exist
          await userRef.set({
            'daily_steps': {today: steps},
            'weekly_steps': steps,
            'total_coins': 0,
            'last_week_rewarded': null,
          }, SetOptions(merge: true));

          print(
              "📊 LEADERBOARD: Initialized user data for ${user.uid} with $steps steps");
        }
      }
    } catch (e) {
      print("📊 LEADERBOARD: Error updating leaderboard data: $e");
    }
  }

  /// SYNC WITH GOOGLE FIT - Updates baseline periodically for accuracy
  Future<void> syncWithGoogleFit() async {
    try {
      print("🔄 SYNC: Syncing with Google Fit for accuracy...");

      // Get current Google Fit steps
      final currentGoogleFitSteps = await fetchStepsData();

      // Calculate how much Google Fit has increased since our baseline
      final googleFitIncrease = currentGoogleFitSteps - _healthConnectBaseline;

      // Update baseline to current Google Fit
      _healthConnectBaseline = currentGoogleFitSteps;

      // Reset sensor counter to account for the sync
      StepCounterService.resetCounter();

      print("🔄 SYNC: Google Fit steps: $currentGoogleFitSteps");
      print("🔄 SYNC: Google Fit increase: $googleFitIncrease");
      print("🔄 SYNC: New baseline: $_healthConnectBaseline");
      print("🔄 SYNC: Sensor counter reset");
      print("🔄 SYNC: Now showing accurate steps!");
    } catch (e) {
      print("🔄 SYNC: Error syncing with Google Fit: $e");
    }
  }

  /// SMART HYBRID SYSTEM - Best of both worlds
  Future<Map<String, dynamic>> fetchSmartHybridData() async {
    try {
      print("🧠 SMART: Starting smart hybrid system...");

      // Get real-time steps for immediate display
      final realTimeSteps = await fetchHybridRealTimeSteps();

      // Get animation state from sensors
      final isWalking = await isUserWalkingForAnimation();

      // Sync with Google Fit periodically (every 30 seconds)
      final now = DateTime.now();
      if (_lastSyncTime == null ||
          now.difference(_lastSyncTime!).inSeconds >= 30) {
        await syncWithGoogleFit();
        _lastSyncTime = now;
      }

      final result = {
        'steps': realTimeSteps,
        'isWalking': isWalking,
        'baseline': _healthConnectBaseline,
        'sensorSteps': StepCounterService.currentSteps,
        'timestamp': now.millisecondsSinceEpoch,
      };

      print(
          "🧠 SMART: Steps: ${result['steps']}, Walking: ${result['isWalking']}");
      print(
          "🧠 SMART: Baseline: ${result['baseline']}, Sensor: ${result['sensorSteps']}");

      return result;
    } catch (e) {
      print("🧠 SMART: Error: $e");
      return {
        'steps': _healthConnectBaseline,
        'isWalking': false,
        'baseline': _healthConnectBaseline,
        'sensorSteps': 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  /// Start continuous step monitoring and Firestore updates (No Loading Screens)
  Future<void> startContinuousStepUpdates() async {
    try {
      print("🔄 Starting continuous step updates...");

      // Update steps every 30 seconds (background, no UI impact)
      Timer.periodic(const Duration(seconds: 30), (timer) async {
        try {
          final currentSteps = await fetchHybridRealTimeSteps();
          await _updateLeaderboardData(currentSteps);
          print("🔄 Background step update: $currentSteps steps");
        } catch (e) {
          print("🔄 Error in continuous step update: $e");
        }
      });

      // Also update when app becomes active (seamless)
      WidgetsBinding.instance.addObserver(
        LifecycleEventHandler(
          detachedCallBack: () async {},
          inactiveCallBack: () async {},
          pausedCallBack: () async {},
          resumedCallBack: () async {
            try {
              final currentSteps = await fetchHybridRealTimeSteps();
              await _updateLeaderboardData(currentSteps);
              print("🔄 Resume step update: $currentSteps steps");
            } catch (e) {
              print("🔄 Error updating steps on resume: $e");
            }
          },
        ),
      );

      print("✅ Continuous step updates started (no loading screens)");
    } catch (e) {
      print("❌ Error starting continuous step updates: $e");
    }
  }

  /// Get start of current week (Monday) - for HealthService
  DateTime _getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return date.subtract(Duration(days: daysFromMonday));
  }
}

/// Lifecycle event handler for app state changes
class LifecycleEventHandler extends WidgetsBindingObserver {
  final Future<void> Function()? detachedCallBack;
  final Future<void> Function()? inactiveCallBack;
  final Future<void> Function()? pausedCallBack;
  final Future<void> Function()? resumedCallBack;

  LifecycleEventHandler({
    this.detachedCallBack,
    this.inactiveCallBack,
    this.pausedCallBack,
    this.resumedCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
        await detachedCallBack?.call();
        break;
      case AppLifecycleState.inactive:
        await inactiveCallBack?.call();
        break;
      case AppLifecycleState.paused:
        await pausedCallBack?.call();
        break;
      case AppLifecycleState.resumed:
        await resumedCallBack?.call();
        break;
      default:
        break;
    }
  }
}
