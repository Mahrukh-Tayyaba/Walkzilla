import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Health Connect data types
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

  // Request Health Connect permissions
  Future<bool> requestHealthConnectPermissions() async {
    try {
      print("Requesting Health Connect permissions...");

      // Initialize first
      bool initialized = await initializeHealthConnect();
      if (!initialized) {
        print("Failed to initialize Health Connect");
        return false;
      }

      // Request permissions
      bool granted = await health.requestAuthorization(_dataTypes);
      print("Health Connect permissions granted: $granted");

      if (granted) {
        // Update Firestore to track permissions
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'hasHealthPermissions': true});
        }
      }

      return granted;
    } catch (e) {
      print('Error requesting Health Connect permissions: $e');
      return false;
    }
  }

  // Check if we have Health Connect permissions
  Future<bool> checkHealthConnectPermissions() async {
    try {
      if (!_isInitialized) {
        await initializeHealthConnect();
      }

      // Check if we have permissions for our data types
      bool? hasPermission = await health.hasPermissions(_dataTypes);
      return hasPermission == true;
    } catch (e) {
      print('Error checking Health Connect permissions: $e');
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

  // Fetch real steps data from Health Connect
  Future<Map<String, dynamic>> fetchStepsData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Check if we have Health Connect permissions
      bool hasPermissions = await checkHealthConnectPermissions();
      if (!hasPermissions) {
        print("No Health Connect permissions, returning simulated data");
        return _getSimulatedStepsData();
      }

      print(
          'Fetching real steps data from Health Connect for user ${user.uid}');

      // Get today's date range
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Fetch steps data from Health Connect
      List<HealthDataPoint> healthData =
          await health.getHealthAggregateDataFromTypes(
        startDate: startOfDay,
        endDate: endOfDay,
        types: [HealthDataType.STEPS],
      );

      int totalSteps = 0;
      if (healthData.isNotEmpty) {
        for (HealthDataPoint dataPoint in healthData) {
          totalSteps += (dataPoint.value as int? ?? 0);
        }
      }

      print("Total steps from Health Connect: $totalSteps");

      return {
        "startTime": startOfDay.toIso8601String(),
        "endTime": endOfDay.toIso8601String(),
        "count": totalSteps,
        "metadata": {
          "id": "hc_${now.millisecondsSinceEpoch}",
          "device": {
            "manufacturer": "Health Connect",
            "model": "System",
            "type": "health_connect"
          },
          "lastModifiedTime": now.toIso8601String(),
          "clientRecordId": "hc_client_${now.millisecondsSinceEpoch}"
        }
      };
    } catch (e) {
      print('Error in fetchStepsData: $e');
      // Fallback to simulated data
      return _getSimulatedStepsData();
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
        print("No Health Connect permissions, returning simulated data");
        return _getSimulatedHeartRateData();
      }

      print(
          'Fetching real heart rate data from Health Connect for user ${user.uid}');

      // Get the most recent heart rate reading
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
      }

      print("Heart rate from Health Connect: $heartRate bpm");

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
        print("No Health Connect permissions, returning simulated data");
        return _getSimulatedCaloriesData();
      }

      print(
          'Fetching real calories data from Health Connect for user ${user.uid}');

      // Get today's active calories
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      List<HealthDataPoint> healthData =
          await health.getHealthAggregateDataFromTypes(
        startDate: startOfDay,
        endDate: endOfDay,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      double totalCalories = 0.0;
      if (healthData.isNotEmpty) {
        for (HealthDataPoint dataPoint in healthData) {
          totalCalories += (dataPoint.value as num).toDouble();
        }
      }

      print("Total calories from Health Connect: $totalCalories kcal");

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
      print("Steps data fetched: ${stepsData['count']} steps");

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
}
