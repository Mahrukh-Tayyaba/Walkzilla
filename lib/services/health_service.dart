import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walkzilla/widgets/permissions_needed_dialog.dart';

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

  // Simulated health data with proper schema
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
          title: const Text('Health Data Access'),
          content: const Text(
            'To track your daily activities and provide personalized insights, '
            'Walkzilla needs access to your health data. This includes steps, '
            'calories burned, and heart rate data.\n\n'
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

      bool hasExistingPermissions = await checkExistingPermissions();
      if (hasExistingPermissions) {
        print("Health permissions already granted");
        return true;
      }

      print("Requesting health permissions...");
      bool userAccepted = await showPermissionDialog(context);
      print("User accepted dialog: $userAccepted");

      if (userAccepted) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'hasHealthPermissions': true,
        });
        _isInitialized = true;
        return true;
      }

      return false;
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }

  // Fetch steps data with proper error handling
  Future<Map<String, dynamic>> fetchStepsData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      print('Generating simulated steps data for user ${user.uid}');

      // Get simulated data
      final stepsData = _getSimulatedStepsData();

      return stepsData;
    } catch (e) {
      print('Error in fetchStepsData: $e');
      rethrow; // Rethrow to handle in the UI
    }
  }

  // Fetch heart rate data with proper error handling
  Future<Map<String, dynamic>> fetchHeartRateData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      print('Generating simulated heart rate data for user ${user.uid}');

      // Get simulated data
      final heartRateData = _getSimulatedHeartRateData();

      return heartRateData;
    } catch (e) {
      print('Error in fetchHeartRateData: $e');
      rethrow;
    }
  }

  // Fetch calories data with proper error handling
  Future<Map<String, dynamic>> fetchCaloriesData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      print('Generating simulated calories data for user ${user.uid}');

      // Get simulated data
      final caloriesData = _getSimulatedCaloriesData();

      return caloriesData;
    } catch (e) {
      print('Error in fetchCaloriesData: $e');
      rethrow;
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
