import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Added for Timer and StreamSubscription

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health health = Health();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isInitialized = false;

  // Firestore collection names
  static const String _healthDataCollection = 'health_data';
  static const String _stepsCollection = 'steps';
  static const String _heartRateCollection = 'heart_rate';
  static const String _caloriesCollection = 'calories';

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

  // Get the last synced timestamp for a specific data type
  Future<DateTime?> _getLastSyncTime(String userId, String collection) async {
    try {
      final querySnapshot = await _firestore
          .collection(_healthDataCollection)
          .doc(userId)
          .collection(collection)
          .orderBy('syncTime', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return DateTime.parse(querySnapshot.docs.first.data()['syncTime']);
      }
      return null;
    } catch (e) {
      print('Error getting last sync time: $e');
      return null;
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
        return await _showHealthConnectInstallDialog(context);
      }

      bool hasExistingPermissions = await checkHealthConnectPermissions();
      if (hasExistingPermissions) {
        print("Health Connect permissions already granted");
        return true;
      }

      print("Requesting Health Connect permissions...");
      bool userAccepted = await showPermissionDialog(context);
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

          if (p.value != null) {
            // Handle different value types
            if (p.value is int) {
              totalSteps += p.value as int;
              print("    ✅ Added ${p.value} steps (int)");
            } else if (p.value is double) {
              totalSteps += (p.value as double).toInt();
              print(
                  "    ✅ Added ${(p.value as double).toInt()} steps (double)");
            } else {
              print("    ❌ Unknown value type: ${p.value.runtimeType}");
            }
          } else {
            print("    ❌ Value is null");
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
        return _getSimulatedHeartRateData();
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
        "time": heartRateTime!.toIso8601String(),
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
      // Fallback to simulated data
      return _getSimulatedHeartRateData();
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
        return _getSimulatedCaloriesData();
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
      // Fallback to simulated data
      return _getSimulatedCaloriesData();
    }
  }

  // Simulated data methods (fallback)
  Map<String, dynamic> _getSimulatedStepsData() {
    final now = DateTime.now();
    final thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));

    return {
      "startTime": thirtyMinutesAgo.toIso8601String(),
      "endTime": now.toIso8601String(),
      "count": 1200,
      "metadata": {
        "id": "sim_${now.millisecondsSinceEpoch}",
        "device": {
          "manufacturer": "Google",
          "model": "Pixel 6",
          "type": "watch"
        },
        "lastModifiedTime": now.toIso8601String(),
        "clientRecordId": "sim_client_${now.millisecondsSinceEpoch}"
      }
    };
  }

  Map<String, dynamic> _getSimulatedHeartRateData() {
    final now = DateTime.now();

    return {
      "time": now.toIso8601String(),
      "beatsPerMinute": 75,
      "metadata": {
        "id": "sim_hr_${now.millisecondsSinceEpoch}",
        "device": {
          "manufacturer": "Samsung",
          "model": "Galaxy Watch",
          "type": "watch"
        },
        "lastModifiedTime": now.toIso8601String()
      }
    };
  }

  Map<String, dynamic> _getSimulatedCaloriesData() {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));

    return {
      "startTime": oneHourAgo.toIso8601String(),
      "endTime": now.toIso8601String(),
      "energy": {"inKilocalories": 145.5},
      "metadata": {
        "id": "sim_cal_${now.millisecondsSinceEpoch}",
        "device": {
          "manufacturer": "Garmin",
          "model": "Vivoactive 4",
          "type": "watch"
        },
        "lastModifiedTime": now.toIso8601String()
      }
    };
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
      final newSteps = await fetchStepsData();
      final stepIncrease = newSteps - _lastKnownSteps;

      if (newSteps != _lastKnownSteps) {
        _lastKnownSteps = newSteps;
        _lastStepUpdate = DateTime.now();
        _notifyStepUpdate(newSteps, stepIncrease);
      }

      return newSteps;
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
        if (p.value != null) {
          if (p.value is int) {
            totalSteps += p.value as int;
          } else if (p.value is double) {
            totalSteps += (p.value as double).toInt();
          }
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
}
