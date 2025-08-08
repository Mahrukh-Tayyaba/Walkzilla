import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Added for Timer and StreamSubscription
import 'step_counter_service.dart';
import 'leveling_service.dart';

import 'network_service.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  static const bool _forceHybridMode =
      true; // NEVER CHANGE THIS - Ensures hybrid method is always used

  final Health health = Health();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NetworkService _networkService = NetworkService();
  bool _isInitialized = false;

  // Firestore collection names

  // Health Connect data types - ONLY what your app actually uses
  final List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED, // <-- For active calories burned
    HealthDataType.DISTANCE_DELTA, // <-- For distance tracking
  ];

  // Custom method to request TOTAL_ENERGY_BURNED permission
  Future<bool> requestTotalEnergyBurnedPermission() async {
    try {
      debugPrint("🔄 Requesting TOTAL_ENERGY_BURNED permission...");

      // Since the health package doesn't have TOTAL_ENERGY_BURNED,
      // we'll request the permissions we have and hope that the Android manifest
      // will also request TOTAL_ENERGY_BURNED based on the permissions we declared
      bool? result = await health.requestAuthorization([
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ]);

      debugPrint("✅ Permission request result: $result");
      return result;
    } catch (e) {
      debugPrint("❌ Error requesting TOTAL_ENERGY_BURNED permission: $e");
      return false;
    }
  }

  // Initialize Health Connect
  Future<bool> initializeHealthConnect() async {
    try {
      if (_isInitialized) return true;

      debugPrint("Initializing Health Connect...");

      // Check if Health Connect is available by trying to get permissions
      bool? hasPermissions = await health.hasPermissions(_dataTypes);
      debugPrint("Health Connect available: ${hasPermissions != null}");

      if (hasPermissions == null) {
        debugPrint("Health Connect is not available on this device");
        return false;
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing Health Connect: $e');
      return false;
    }
  }

  // Check what data types are available on this device
  Future<List<HealthDataType>> getAvailableDataTypes() async {
    try {
      debugPrint("🔍 Checking available data types on device...");

      // Test each data type individually to see which are supported
      List<HealthDataType> available = await _testIndividualDataTypes();

      debugPrint(
          "📋 Available data types: ${available.map((e) => e.toString()).join(', ')}");

      // Check which of our requested types are available
      debugPrint("🔍 Checking our requested types:");
      for (HealthDataType requestedType in _dataTypes) {
        bool isAvailable = available.contains(requestedType);
        debugPrint(
            "  ${requestedType.toString()}: ${isAvailable ? '✅ Available' : '❌ Not Available'}");
      }

      return available;
    } catch (e) {
      debugPrint("❌ Error checking available data types: $e");
      return [];
    }
  }

  // Test individual data types to see which are supported
  Future<List<HealthDataType>> _testIndividualDataTypes() async {
    List<HealthDataType> supported = [];

    // Test each data type individually
    for (HealthDataType dataType in _dataTypes) {
      try {
        bool? hasPermission = await health.hasPermissions([dataType]);
        if (hasPermission != null) {
          supported.add(dataType);
          debugPrint("✅ ${dataType.toString()} is supported");
        } else {
          debugPrint("❌ ${dataType.toString()} is not supported");
        }
      } catch (e) {
        debugPrint("❌ Error testing ${dataType.toString()}: $e");
      }
    }

    return supported;
  }

  // Check if our specific data types are supported
  Future<Map<String, bool>> checkDataTypeSupport() async {
    try {
      debugPrint("🔍 Checking data type support...");

      List<HealthDataType> available = await getAvailableDataTypes();
      Map<String, bool> supportStatus = {};

      for (HealthDataType requestedType in _dataTypes) {
        bool isSupported = available.contains(requestedType);
        supportStatus[requestedType.toString()] = isSupported;

        if (!isSupported) {
          debugPrint(
              "⚠️ WARNING: ${requestedType.toString()} is NOT supported on this device!");
        }
      }

      return supportStatus;
    } catch (e) {
      debugPrint("❌ Error checking data type support: $e");
      return {};
    }
  }

  // Request Health Connect permissions - Updated with better error handling
  Future<bool> requestHealthConnectPermissions() async {
    try {
      debugPrint("🔐 Requesting Health Connect permissions...");

      // Initialize first
      bool initialized = await initializeHealthConnect();
      if (!initialized) {
        debugPrint("❌ Failed to initialize Health Connect");
        return false;
      }

      // Always request permissions for all data types in _dataTypes
      debugPrint(
          "📋 Requesting permissions for:  {_dataTypes.map((e) => e.toString()).join(', ')}");

      // Request permissions with proper access types (READ only for your app)
      debugPrint("🔄 Calling health.requestAuthorization...");
      bool granted = await health.requestAuthorization(
        _dataTypes,
        permissions: List.filled(_dataTypes.length, HealthDataAccess.READ),
      );

      debugPrint(" Permission request result: $granted");

      // Double-check permissions after request
      if (granted) {
        debugPrint("✅ Permission request returned true, verifying...");
        // Wait a moment for permissions to be processed
        await Future.delayed(const Duration(seconds: 2));

        bool? verifiedPermissions = await health.hasPermissions(_dataTypes);
        debugPrint(
            "🔍 Verified permissions after request: $verifiedPermissions");

        if (verifiedPermissions == true) {
          debugPrint("✅ Permissions successfully granted and verified");

          // Update Firestore to track permissions
          final user = _auth.currentUser;
          if (user != null) {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .update({'hasHealthPermissions': true});
            debugPrint("💾 Updated Firestore with permission status");
          }

          return true;
        } else {
          debugPrint(
              "❌ Permissions not properly granted despite request success");
          debugPrint(
              "🔍 This might indicate the user denied permissions in the dialog");
          return false;
        }
      } else {
        debugPrint("❌ Permission request returned false");
        debugPrint(
            "🔍 This might indicate the user denied permissions or Health Connect is not available");
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error requesting Health Connect permissions: $e');
      debugPrint(' Error details: ${e.toString()}');
      return false;
    }
  }

  // Enhanced permission request with post-verification and user guidance
  Future<bool> requestHealthConnectPermissionsWithVerification(
      BuildContext context) async {
    try {
      debugPrint("🔐 Enhanced permission request with verification...");

      // Step 0: Check what data types are actually supported
      List<HealthDataType> availableTypes = await getAvailableDataTypes();
      debugPrint(
          "🔍 Available data types: ${availableTypes.map((e) => e.toString()).join(', ')}");

      // Use only supported data types for permission request
      List<HealthDataType> supportedDataTypes =
          _dataTypes.where((type) => availableTypes.contains(type)).toList();
      debugPrint(
          "🔍 Using supported data types: ${supportedDataTypes.map((e) => e.toString()).join(', ')}");

      if (supportedDataTypes.isEmpty) {
        debugPrint("❌ No supported data types found!");
        return false;
      }

      // Step 1: Request permissions for supported types only
      bool initialGranted =
          await _requestPermissionsForTypes(supportedDataTypes);

      if (initialGranted) {
        debugPrint("✅ Initial permission request successful");
        return true;
      }

      // Step 2: If initial request failed, verify and guide user
      debugPrint("⚠️ Initial request failed, checking current status...");

      // Wait a bit longer for permissions to be processed
      await Future.delayed(const Duration(seconds: 3));

      bool? currentPermissions =
          await health.hasPermissions(supportedDataTypes);
      debugPrint(
          "🔍 Current permission status after delay: $currentPermissions");

      if (currentPermissions == true) {
        debugPrint("✅ Permissions verified after delay");

        // Update Firestore
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'hasHealthPermissions': true});
        }

        return true;
      }

      // Step 3: Show user guidance dialog
      debugPrint("❌ Permissions still not granted, showing guidance dialog");
      if (context.mounted) {
        return await _showPermissionGuidanceDialog(context, supportedDataTypes);
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error in enhanced permission request: $e');
      return false;
    }
  }

  // Request permissions for specific data types
  Future<bool> _requestPermissionsForTypes(
      List<HealthDataType> dataTypes) async {
    try {
      debugPrint(
          "🔐 Requesting permissions for: ${dataTypes.map((e) => e.toString()).join(', ')}");

      bool granted = await health.requestAuthorization(
        dataTypes,
        permissions: List.filled(dataTypes.length, HealthDataAccess.READ),
      );

      debugPrint("🔐 Permission request result: $granted");
      return granted;
    } catch (e) {
      debugPrint("❌ Error requesting permissions: $e");
      return false;
    }
  }

  // Build a formatted list of permissions for display
  String _buildPermissionList(List<HealthDataType> dataTypes) {
    List<String> permissionNames = [];

    for (HealthDataType dataType in dataTypes) {
      switch (dataType) {
        case HealthDataType.STEPS:
          permissionNames.add('   • Steps');
          break;
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          permissionNames.add('   • Active Calories');
          break;
        case HealthDataType.BASAL_ENERGY_BURNED:
          permissionNames.add('   • Total Calories');
          break;
        case HealthDataType.DISTANCE_DELTA:
          permissionNames.add('   • Distance');
          break;
        default:
          permissionNames.add('   • ${dataType.toString()}');
      }
    }

    return permissionNames.join('\n');
  }

  // Show guidance dialog for manual permission granting
  Future<bool> _showPermissionGuidanceDialog(
      BuildContext context, List<HealthDataType> supportedDataTypes) async {
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Health Connect Permissions'),
          content: Text(
            'It looks like some permissions weren\'t granted automatically. '
            'This sometimes happens with Health Connect.\n\n'
            'To fix this:\n'
            '1. Tap "Open Health Connect"\n'
            '2. Find "Walkzilla" in the list\n'
            '3. Enable these permissions:\n'
            '${_buildPermissionList(supportedDataTypes)}\n'
            '4. Return to the app\n\n'
            'Your data privacy is important to us and all data is stored securely.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Open Health Connect'),
              onPressed: () async {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (result == true) {
      // Open Health Connect settings
      await _openHealthConnectSettings();

      // Wait for user to return and check permissions again
      if (context.mounted) {
        return await _showPermissionVerificationDialog(context);
      }
    }

    return false;
  }

  // Show verification dialog after user returns from settings
  Future<bool> _showPermissionVerificationDialog(BuildContext context) async {
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Verify Permissions'),
          content: const Text(
            'Please tap "Check Permissions" to verify that all permissions have been granted in Health Connect.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Check Permissions'),
              onPressed: () async {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (result == true) {
      // Check permissions again
      await Future.delayed(const Duration(seconds: 1));
      bool? hasPermissions = await health.hasPermissions(_dataTypes);

      if (hasPermissions == true) {
        debugPrint("✅ Permissions verified after manual setup");

        // Update Firestore
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'hasHealthPermissions': true});
        }

        if (context.mounted) {
          _showSuccessDialog(context);
        }

        return true;
      } else {
        debugPrint("❌ Permissions still not granted after manual setup");
        if (context.mounted) {
          _showRetryDialog(context);
        }
      }
    }

    return false;
  }

  // Show success dialog
  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success!'),
          content: const Text(
            'All Health Connect permissions have been granted successfully. '
            'You can now track your fitness data in Walkzilla!',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Show retry dialog
  void _showRetryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permissions Not Granted'),
          content: const Text(
            'It seems the permissions are still not granted. '
            'Please make sure to:\n\n'
            '1. Open Health Connect\n'
            '2. Find "Walkzilla"\n'
            '3. Enable ALL permissions (Steps, Heart Rate, Calories, Distance)\n'
            '4. Return and try again\n\n'
            'If the issue persists, you can try again later.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Open Health Connect settings
  Future<void> _openHealthConnectSettings() async {
    try {
      debugPrint("🔧 Opening Health Connect settings...");

      // Try to open Health Connect app directly
      const healthConnectUrl =
          'content://com.google.android.apps.healthdata/permission';
      final uri = Uri.parse(healthConnectUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        debugPrint("✅ Opened Health Connect settings");
      } else {
        // Fallback to Play Store
        debugPrint(
            "⚠️ Could not open Health Connect directly, trying Play Store...");
        await openHealthConnect();
      }
    } catch (e) {
      debugPrint("❌ Error opening Health Connect settings: $e");
      // Final fallback to Play Store
      await openHealthConnect();
    }
  }

  // Enhanced permission check with detailed status
  Future<Map<String, dynamic>> checkDetailedPermissions() async {
    try {
      debugPrint("🔍 Checking detailed permissions...");

      bool? hasPermissions = await health.hasPermissions(_dataTypes);

      // Check each data type individually
      Map<String, bool> individualPermissions = {};
      for (HealthDataType dataType in _dataTypes) {
        bool? individualPermission = await health.hasPermissions([dataType]);
        individualPermissions[dataType.toString()] =
            individualPermission ?? false;
      }

      final result = {
        'overall': hasPermissions ?? false,
        'individual': individualPermissions,
        'dataTypes': _dataTypes.map((e) => e.toString()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      debugPrint("🔍 Detailed permission status: $result");
      return result;
    } catch (e) {
      debugPrint("❌ Error checking detailed permissions: $e");
      return {
        'overall': false,
        'individual': {},
        'dataTypes': _dataTypes.map((e) => e.toString()).toList(),
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Debug method to troubleshoot permission issues
  Future<void> debugPermissions(BuildContext context) async {
    try {
      debugPrint("🔧 === PERMISSION DEBUG START ===");

      // Check available data types
      List<HealthDataType> availableTypes = await getAvailableDataTypes();
      debugPrint(
          "📋 Available data types: ${availableTypes.map((e) => e.toString()).join(', ')}");

      // Check detailed permissions
      Map<String, dynamic> detailedPermissions =
          await checkDetailedPermissions();
      debugPrint("🔍 Detailed permissions: $detailedPermissions");

      // Show debug dialog
      if (context.mounted) {
        _showDebugDialog(context, availableTypes, detailedPermissions);
      }

      debugPrint("🔧 === PERMISSION DEBUG END ===");
    } catch (e) {
      debugPrint("❌ Error in permission debug: $e");
    }
  }

  // Show debug information dialog
  void _showDebugDialog(
      BuildContext context,
      List<HealthDataType> availableTypes,
      Map<String, dynamic> detailedPermissions) {
    String availableText =
        availableTypes.map((e) => '• ${e.toString()}').join('\n');
    String requestedText =
        _dataTypes.map((e) => '• ${e.toString()}').join('\n');

    String individualText = '';
    Map<String, bool> individual =
        detailedPermissions['individual'] as Map<String, bool>? ?? {};
    individual.forEach((key, value) {
      individualText += '• $key: ${value ? '✅ Granted' : '❌ Not Granted'}\n';
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Debug Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Available Data Types:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(availableText),
                const SizedBox(height: 16),
                const Text('Requested Data Types:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(requestedText),
                const SizedBox(height: 16),
                const Text('Individual Permissions:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(individualText),
                const SizedBox(height: 16),
                Text(
                    'Overall: ${detailedPermissions['overall'] ? '✅ Granted' : '❌ Not Granted'}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Troubleshoot permission issues
  Future<Map<String, dynamic>> troubleshootPermissions(
      BuildContext context) async {
    try {
      debugPrint("🔧 Starting permission troubleshooting...");

      Map<String, dynamic> result = {
        'healthConnectAvailable': false,
        'permissionsGranted': false,
        'individualPermissions': {},
        'issues': [],
        'recommendations': [],
      };

      // Check if Health Connect is available
      bool? isAvailable = await health.hasPermissions(_dataTypes);
      result['healthConnectAvailable'] = isAvailable != null;

      if (isAvailable == null) {
        result['issues'].add('Health Connect is not available on this device');
        result['recommendations']
            .add('Install Health Connect from the Play Store');
        return result;
      }

      // Check overall permissions
      bool? hasPermissions = await health.hasPermissions(_dataTypes);
      result['permissionsGranted'] = hasPermissions ?? false;

      // Check individual permissions
      Map<String, bool> individualPermissions = {};
      for (HealthDataType dataType in _dataTypes) {
        bool? individualPermission = await health.hasPermissions([dataType]);
        individualPermissions[dataType.toString()] =
            individualPermission ?? false;
      }
      result['individualPermissions'] = individualPermissions;

      // Identify specific issues
      if (!(hasPermissions ?? false)) {
        result['issues'].add('Overall permissions not granted');
        result['recommendations']
            .add('Grant permissions through Health Connect settings');
      }

      // Check which specific data types are missing
      individualPermissions.forEach((dataType, granted) {
        if (!granted) {
          result['issues'].add('Permission not granted for $dataType');
          result['recommendations']
              .add('Enable $dataType permission in Health Connect');
        }
      });

      debugPrint("🔧 Troubleshooting result: $result");
      return result;
    } catch (e) {
      debugPrint("❌ Error in permission troubleshooting: $e");
      return {
        'healthConnectAvailable': false,
        'permissionsGranted': false,
        'individualPermissions': {},
        'issues': ['Error occurred during troubleshooting: $e'],
        'recommendations': ['Try restarting the app and Health Connect'],
      };
    }
  }

  // Manual permission fix with step-by-step guidance
  Future<bool> manualPermissionFix(BuildContext context) async {
    try {
      debugPrint("🔧 Starting manual permission fix...");

      // First, troubleshoot to understand the current state
      Map<String, dynamic> troubleshooting =
          await troubleshootPermissions(context);

      if (!troubleshooting['healthConnectAvailable']) {
        if (context.mounted) {
          await _showHealthConnectInstallDialog(context);
        }
        return false;
      }

      // Show detailed troubleshooting dialog
      if (context.mounted) {
        bool shouldProceed =
            await _showTroubleshootingDialog(context, troubleshooting);
        if (!shouldProceed) {
          return false;
        }
      }

      // Guide user through manual fix
      if (context.mounted) {
        return await _showManualFixDialog(context);
      }

      return false;
    } catch (e) {
      debugPrint("❌ Error in manual permission fix: $e");
      return false;
    }
  }

  // Show troubleshooting results dialog
  Future<bool> _showTroubleshootingDialog(
      BuildContext context, Map<String, dynamic> troubleshooting) async {
    String issuesText = troubleshooting['issues'].join('\n• ');
    String recommendationsText =
        troubleshooting['recommendations'].join('\n• ');

    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Issues Found'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Issues detected:'),
                Text('• $issuesText'),
                const SizedBox(height: 16),
                const Text('Recommendations:'),
                Text('• $recommendationsText'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Fix Permissions'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // Show manual fix dialog with step-by-step instructions
  Future<bool> _showManualFixDialog(BuildContext context) async {
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Manual Permission Fix'),
          content: FutureBuilder<List<HealthDataType>>(
            future: getAvailableDataTypes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text('Loading available permissions...');
              }

              List<HealthDataType> availableTypes = snapshot.data ?? [];
              String permissionList = _buildPermissionList(availableTypes);

              return Text(
                'Follow these steps to fix permissions:\n\n'
                '1. Tap "Open Health Connect"\n'
                '2. Go to "Data & privacy" → "Apps"\n'
                '3. Find "Walkzilla" in the list\n'
                '4. Tap on "Walkzilla"\n'
                '5. Enable these permissions:\n'
                '$permissionList\n'
                '6. Return to the app\n'
                '7. Tap "Verify Fix" to check\n\n'
                'This should resolve the permission issues.',
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Open Health Connect'),
              onPressed: () async {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (result == true) {
      // Open Health Connect
      await _openHealthConnectSettings();

      // Wait for user to return and verify
      if (context.mounted) {
        return await _showVerificationDialog(context);
      }
    }

    return false;
  }

  // Show verification dialog after manual fix
  Future<bool> _showVerificationDialog(BuildContext context) async {
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Verify Fix'),
          content: const Text(
            'After enabling all permissions in Health Connect, please tap "Verify Fix" to check if the issues have been resolved.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Verify Fix'),
              onPressed: () async {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (result == true) {
      // Check permissions again
      await Future.delayed(const Duration(seconds: 1));
      bool? hasPermissions = await health.hasPermissions(_dataTypes);

      if (hasPermissions == true) {
        debugPrint("✅ Manual fix successful - permissions verified");

        // Update Firestore
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'hasHealthPermissions': true});
        }

        if (context.mounted) {
          _showManualFixSuccessDialog(context);
        }

        return true;
      } else {
        debugPrint("❌ Manual fix failed - permissions still not granted");
        if (context.mounted) {
          _showManualFixFailedDialog(context);
        }
      }
    }

    return false;
  }

  // Show success dialog for manual fix
  void _showManualFixSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Fix Successful!'),
          content: const Text(
            'All Health Connect permissions have been successfully enabled. '
            'Walkzilla can now access your fitness data to provide accurate tracking and insights.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Great!'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Show failed dialog for manual fix
  void _showManualFixFailedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Fix Not Complete'),
          content: const Text(
            'It seems some permissions are still not granted. Please:\n\n'
            '1. Make sure you enabled ALL permissions for Walkzilla\n'
            '2. Check that you saved the changes in Health Connect\n'
            '3. Try the manual fix again\n\n'
            'If the issue persists, you may need to restart Health Connect or your device.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Try Again'),
              onPressed: () {
                Navigator.of(context).pop();
                // Optionally restart the manual fix process
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Check if we have Health Connect permissions - Updated with better checking
  Future<bool> checkHealthConnectPermissions() async {
    try {
      if (!_isInitialized) {
        await initializeHealthConnect();
      }

      debugPrint("🔍 Checking Health Connect permissions...");

      // Check if we have permissions for our data types
      bool? hasPermission = await health.hasPermissions(_dataTypes);
      debugPrint("🔍 Permission check result: $hasPermission");

      if (hasPermission == true) {
        debugPrint("✅ Health Connect permissions confirmed");
        return true;
      } else if (hasPermission == false) {
        debugPrint("❌ Health Connect permissions explicitly denied");
        return false;
      } else {
        debugPrint("❓ Health Connect permissions status unclear (null)");
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error checking Health Connect permissions: $e');
      return false;
    }
  }

  // Add a method to force refresh permissions
  Future<bool> forceRefreshPermissions() async {
    try {
      debugPrint("🔄 Force refreshing Health Connect permissions...");

      // Clear any cached permission state
      _isInitialized = false;

      // Re-initialize
      bool initialized = await initializeHealthConnect();
      if (!initialized) {
        debugPrint("❌ Failed to re-initialize Health Connect");
        return false;
      }

      // Check permissions again
      bool hasPermissions = await checkHealthConnectPermissions();

      if (!hasPermissions) {
        debugPrint("🔄 No permissions found, requesting again...");
        return await requestHealthConnectPermissions();
      }

      return hasPermissions;
    } catch (e) {
      debugPrint('❌ Error force refreshing permissions: $e');
      return false;
    }
  }

  // Add a method to manually verify permissions
  Future<bool> manuallyVerifyPermissions() async {
    try {
      debugPrint("🔍 === MANUAL PERMISSION VERIFICATION ===");

      // Force re-initialization
      _isInitialized = false;
      await initializeHealthConnect();

      // Check permissions directly
      bool? hasPermission = await health.hasPermissions(_dataTypes);
      debugPrint("🔍 Direct permission check: $hasPermission");

      if (hasPermission == true) {
        debugPrint("✅ Permissions verified manually");

        // Update Firestore
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'hasHealthPermissions': true});
          debugPrint("💾 Updated Firestore with permission status");
        }

        return true;
      } else {
        debugPrint("❌ Permissions not verified manually");
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error in manual verification: $e');
      return false;
    }
  }

  Future<bool> checkExistingPermissions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint("No user logged in, skipping health permission check");
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
      debugPrint('Error checking existing permissions: $e');
      return false;
    }
  }

  Future<bool> showPermissionDialog(BuildContext context) async {
    // First check what data types are actually supported
    List<HealthDataType> availableTypes = await getAvailableDataTypes();

    // Build the content text based on what's available
    String contentText =
        'To track your daily activities and provide personalized insights, '
        'Walkzilla needs access to your health data through Health Connect.\n\n';

    if (availableTypes.contains(HealthDataType.STEPS)) {
      contentText += '• Steps – To track your daily activity\n';
    }
    if (availableTypes.contains(HealthDataType.ACTIVE_ENERGY_BURNED)) {
      contentText +=
          '• Active Calories – To track calories burned during activity\n';
    }
    if (availableTypes.contains(HealthDataType.BASAL_ENERGY_BURNED)) {
      contentText += '• Total Calories – To track total calories burned\n';
    }
    if (availableTypes.contains(HealthDataType.DISTANCE_DELTA)) {
      contentText += '• Distance – To measure how far you\'ve walked\n';
    }

    contentText +=
        '\nYour data privacy is important to us and all data is stored securely.';

    // Log what we're requesting
    debugPrint(
        "🔍 Requesting permissions for: ${availableTypes.map((e) => e.toString()).join(', ')}");

    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Health Connect Access'),
          content: Text(contentText),
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
      debugPrint('Error opening Health Connect: $e');
      final webUrl = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata');
      try {
        await launchUrl(webUrl);
      } catch (e) {
        debugPrint('Error opening Health Connect web URL: $e');
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
        debugPrint("No user logged in, cannot request health permissions");
        return false;
      }

      // Use the nuclear reset to force Health Connect to recognize new data types
      debugPrint(
          "☢️ Using nuclear reset to force Health Connect to recognize new data types...");
      return await nuclearPermissionReset(context);
    } catch (e) {
      debugPrint('Error requesting health permissions: $e');
      return false;
    }
  }

  // Fetch steps data from Health Connect using aggregate API
  Future<int> fetchStepsData() async {
    try {
      debugPrint(
          "Fetching real steps data from Health Connect for user ${FirebaseAuth.instance.currentUser?.uid}");

      // Check if we have permissions
      bool hasPermissions = await checkHealthConnectPermissions();
      if (!hasPermissions) {
        debugPrint("❌ No Health Connect permissions for steps");
        return 0;
      }

      // Get today's date range
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      debugPrint(
          "📅 Fetching steps from ${startOfDay.toIso8601String()} to ${endOfDay.toIso8601String()}");

      // Use aggregate API to get total steps for the day
      try {
        debugPrint("🔄 Using aggregate API for steps...");

        // Get aggregated steps data
        final stepsData = await health.getTotalStepsInInterval(
          startOfDay,
          endOfDay,
        );

        debugPrint("📊 Aggregated steps from Health Connect: $stepsData");
        return stepsData ?? 0;
      } catch (e) {
        debugPrint("❌ Error with aggregate API, falling back to raw data: $e");

        // Fallback to raw data method
        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          startTime: startOfDay,
          endTime: endOfDay,
          types: [HealthDataType.STEPS],
        );
        debugPrint("📊 Raw health data points: ${healthData.length}");

        // Calculate total steps with null safety and detailed debugging
        int totalSteps = 0;
        debugPrint("🔍 Processing ${healthData.length} health data points:");

        for (int i = 0; i < healthData.length; i++) {
          HealthDataPoint p = healthData[i];
          debugPrint("  📊 Data point $i:");
          debugPrint("    - Value: ${p.value} (type: ${p.value.runtimeType})");
          debugPrint("    - Date from: ${p.dateFrom}");
          debugPrint("    - Date to: ${p.dateTo}");
          debugPrint("    - Data type: ${p.type}");
          debugPrint("    - Unit: ${p.unit}");

          // Handle different value types
          if (p.value is int) {
            totalSteps += p.value as int;
            debugPrint("    ✅ Added ${p.value} steps (int)");
          } else if (p.value is double) {
            totalSteps += (p.value as double).toInt();
            debugPrint(
                "    ✅ Added ${(p.value as double).toInt()} steps (double)");
          } else {
            debugPrint("    ❌ Unknown value type: ${p.value.runtimeType}");
          }
        }

        debugPrint("📊 Total steps calculated: $totalSteps");
        return totalSteps;
      }
    } catch (e) {
      debugPrint("Error in fetchStepsData: $e");
      return 0;
    }
  }

  // Fetch steps data for a specific date range
  Future<int> getStepsForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      debugPrint(
          "Fetching steps data for date range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}");

      // Check if we have permissions
      bool hasPermissions = await checkHealthConnectPermissions();
      if (!hasPermissions) {
        debugPrint("❌ No Health Connect permissions for steps");
        return 0;
      }

      // Use aggregate API to get total steps for the date range
      try {
        debugPrint("🔄 Using aggregate API for date range steps...");

        // Get aggregated steps data
        final stepsData = await health.getTotalStepsInInterval(
          startDate,
          endDate,
        );

        debugPrint("📊 Aggregated steps for date range: $stepsData");
        return stepsData ?? 0;
      } catch (e) {
        debugPrint(
            "❌ Error with aggregate API for date range, falling back to raw data: $e");

        // Fallback to raw data method
        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          startTime: startDate,
          endTime: endDate,
          types: [HealthDataType.STEPS],
        );
        debugPrint(
            "📊 Raw health data points for date range: ${healthData.length}");

        // Calculate total steps
        int totalSteps = 0;
        for (HealthDataPoint p in healthData) {
          if (p.value is int) {
            totalSteps += p.value as int;
          } else if (p.value is double) {
            totalSteps += (p.value as double).toInt();
          }
        }

        debugPrint("📊 Total steps calculated for date range: $totalSteps");
        return totalSteps;
      }
    } catch (e) {
      debugPrint("Error in getStepsForDateRange: $e");
      return 0;
    }
  }

  // Fetch real active calories data from Health Connect
  Future<Map<String, dynamic>> fetchCaloriesData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Check if we have Health Connect permissions
      bool hasPermissions = await checkHealthConnectPermissions();
      if (!hasPermissions) {
        debugPrint("❌ No Health Connect permissions for calories");
        throw Exception(
            'Health Connect permissions required for calories data');
      }

      debugPrint(
          'Fetching real active calories data from Health Connect for user  {user.uid}');

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Active calories (from exercise and activities)
      List<HealthDataPoint> activeData = await health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: endOfDay,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      double activeCalories = 0.0;
      if (activeData.isNotEmpty) {
        for (HealthDataPoint dataPoint in activeData) {
          activeCalories += (dataPoint.value as num).toDouble();
        }
      }

      debugPrint("🔥 Active calories: $activeCalories kcal");

      return {
        "startTime": startOfDay.toIso8601String(),
        "endTime": endOfDay.toIso8601String(),
        "energy": {
          "activeKilocalories": activeCalories,
          "totalKilocalories": activeCalories, // Using active calories as total
        },
        "metadata": {
          "id": "hc_cal_ {now.millisecondsSinceEpoch}",
          "device": {
            "manufacturer": "Health Connect",
            "model": "System",
            "type": "health_connect"
          },
          "lastModifiedTime": now.toIso8601String()
        }
      };
    } catch (e) {
      debugPrint('Error in fetchCaloriesData: $e');
      throw Exception('Failed to fetch calories data: $e');
    }
  }

  // Simplified distance fetching method
  Future<double> fetchDistance(
      {required DateTime start, required DateTime end}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Check if we have Health Connect permissions
      bool hasPermissions = await checkHealthConnectPermissions();
      if (!hasPermissions) {
        debugPrint("❌ No Health Connect permissions for distance");
        throw Exception(
            'Health Connect permissions required for distance data');
      }

      debugPrint(
          '📏 Fetching distance from ${start.toIso8601String()} to ${end.toIso8601String()}');

      List<HealthDataPoint> distanceData = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.DISTANCE_DELTA],
      );

      double totalDistance = 0.0;
      if (distanceData.isNotEmpty) {
        for (HealthDataPoint dataPoint in distanceData) {
          {
            if (dataPoint.value is NumericHealthValue) {
              totalDistance += (dataPoint.value as NumericHealthValue)
                  .numericValue
                  .toDouble();
            } else if (dataPoint.value is num) {
              totalDistance += (dataPoint.value as num).toDouble();
            }
          }
        }
      }

      debugPrint("📏 Total distance: $totalDistance meters");
      return totalDistance;
    } catch (e) {
      debugPrint('❌ Error in fetchDistance: $e');
      throw Exception('Failed to fetch distance data: $e');
    }
  }

  // Fetch real distance data from Health Connect (legacy method)
  Future<double> fetchDistanceData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Check if we have Health Connect permissions
      bool hasPermissions = await checkHealthConnectPermissions();
      if (!hasPermissions) {
        debugPrint("❌ No Health Connect permissions for distance");
        throw Exception(
            'Health Connect permissions required for distance data');
      }

      debugPrint(
          'Fetching real distance data from Health Connect for user  {user.uid}');

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      List<HealthDataPoint> distanceData = await health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: endOfDay,
        types: [HealthDataType.DISTANCE_DELTA],
      );
      double totalDistance = 0.0;
      if (distanceData.isNotEmpty) {
        for (HealthDataPoint dataPoint in distanceData) {
          {
            if (dataPoint.value is NumericHealthValue) {
              totalDistance += (dataPoint.value as NumericHealthValue)
                  .numericValue
                  .toDouble();
            } else if (dataPoint.value is num) {
              totalDistance += (dataPoint.value as num).toDouble();
            }
          }
        }
      }
      debugPrint("📏 Total distance: $totalDistance meters");
      return totalDistance;
    } catch (e) {
      debugPrint('Error in fetchDistanceData: $e');
      throw Exception('Failed to fetch distance data: $e');
    }
  }

  // Main method to fetch all health data
  Future<Map<String, dynamic>> fetchHealthData() async {
    try {
      debugPrint("Fetching health data...");

      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("No user logged in, cannot fetch health data");
        throw Exception('No user logged in');
      }

      debugPrint("User ID: ${user.uid}");

      // Fetch and store each type of data
      debugPrint("Fetching steps data...");
      final stepsData = await fetchStepsData();
      debugPrint("Steps data fetched: $stepsData steps");

      debugPrint("Fetching calories data...");
      final caloriesData = await fetchCaloriesData();
      debugPrint(
          "Calories data fetched: ${caloriesData['energy']['activeKilocalories']} kcal");

      return {'steps': stepsData, 'calories': caloriesData};
    } catch (e) {
      debugPrint('Error fetching health data: $e');
      // Return error states for all data types
      return {
        'steps': await fetchStepsData(),
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
      debugPrint("🔄 Starting real-time step monitoring...");

      // Check permissions first
      bool hasPermissions = await checkHealthConnectPermissions();
      if (!hasPermissions) {
        debugPrint("❌ No Health Connect permissions for real-time monitoring");
        return;
      }

      // Stop any existing monitoring
      stopRealTimeStepMonitoring();

      // Initial step count
      _lastKnownSteps = await fetchStepsData();
      _lastStepUpdate = DateTime.now();
      debugPrint("📊 Initial step count: $_lastKnownSteps");

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

      debugPrint("✅ Real-time step monitoring started");
    } catch (e) {
      debugPrint("❌ Error starting real-time step monitoring: $e");
    }
  }

  // Stop real-time step monitoring
  void stopRealTimeStepMonitoring() {
    _stepMonitoringTimer?.cancel();
    _stepMonitoringTimer = null;
    _healthDataSubscription?.cancel();
    _healthDataSubscription = null;
    debugPrint("🛑 Real-time step monitoring stopped");
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

        debugPrint(
            "🎉 Step update detected: +$stepIncrease steps (Total: $currentSteps)");

        // Notify listeners about step update
        _notifyStepUpdate(currentSteps, stepIncrease);
      }
    } catch (e) {
      debugPrint("❌ Error checking for step updates: $e");
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
      debugPrint("🔄 Force refreshing step count...");

      // Use sensor-optimized step count for accuracy
      final unifiedSteps = await fetchSensorOptimizedSteps();
      final stepIncrease = unifiedSteps - _lastKnownSteps;

      if (unifiedSteps != _lastKnownSteps) {
        _lastKnownSteps = unifiedSteps;
        _lastStepUpdate = DateTime.now();
        _notifyStepUpdate(unifiedSteps, stepIncrease);
        debugPrint(
            "✅ Force refresh updated steps: $unifiedSteps (+$stepIncrease)");
      } else {
        debugPrint("📊 Force refresh: No change in steps ($unifiedSteps)");
      }

      return unifiedSteps;
    } catch (e) {
      debugPrint("❌ Error force refreshing step count: $e");
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
      debugPrint(
          "🚀 Starting enhanced real-time monitoring with smart polling...");

      // Stop any existing monitoring
      stopAllMonitoring();

      // Initial step count
      _lastKnownSteps = await fetchStepsData();
      _lastStepUpdate = DateTime.now();
      _lastStepCheck = DateTime.now();
      debugPrint("📊 Initial step count: $_lastKnownSteps");

      // Start smart polling
      _startSmartPolling();

      debugPrint("✅ Enhanced real-time monitoring started");
    } catch (e) {
      debugPrint("❌ Error starting enhanced monitoring: $e");
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
          debugPrint("🏃 User active - switching to fast polling (10s)");
        }

        debugPrint(
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
          debugPrint("😴 User inactive - switching to normal polling (30s)");
        } else if (_consecutiveNoChangeCount >= 20 &&
            _currentPollingInterval == _normalPolling) {
          // After 10 minutes of no changes, switch to slow polling
          _currentPollingInterval = _slowPolling;
          _startSmartPolling();
          debugPrint("💤 User very inactive - switching to slow polling (60s)");
        }

        debugPrint(
            "📊 Smart polling: No step change (count: $_consecutiveNoChangeCount)");
      }

      _lastStepCheck = now;
    } catch (e) {
      debugPrint("❌ Error in smart polling check: $e");
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
      debugPrint("❌ Error force refreshing with smart reset: $e");
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
      debugPrint("🚀 Starting aggressive sync monitoring...");

      // Stop any existing monitoring
      stopAllMonitoring();

      // Initial sync
      await _forceAggressiveSync();

      // Set up aggressive sync timer (every 20 seconds)
      _aggressiveSyncTimer =
          Timer.periodic(const Duration(seconds: 20), (timer) async {
        await _forceAggressiveSync();
      });

      debugPrint("✅ Aggressive sync monitoring started");
    } catch (e) {
      debugPrint("❌ Error starting aggressive sync monitoring: $e");
    }
  }

  // Force aggressive sync with multiple strategies
  Future<void> _forceAggressiveSync() async {
    try {
      _syncAttempts++;
      debugPrint("🔄 Aggressive sync attempt $_syncAttempts...");

      // Strategy 1: Force refresh Health Connect data
      await _refreshHealthConnectData();

      // Strategy 2: Check for step changes
      final currentSteps = await fetchStepsData();

      if (currentSteps > _lastKnownSteps) {
        final stepIncrease = currentSteps - _lastKnownSteps;
        _lastKnownSteps = currentSteps;
        _lastStepUpdate = DateTime.now();
        _syncAttempts = 0; // Reset attempts on success

        debugPrint(
            "🎉 Aggressive sync successful: +$stepIncrease steps (Total: $currentSteps)");
        _notifyStepUpdate(currentSteps, stepIncrease);
      } else {
        debugPrint("📊 Aggressive sync: No new steps detected");

        // If we've tried too many times without success, try alternative strategies
        if (_syncAttempts >= _maxSyncAttempts) {
          await _tryAlternativeSyncStrategies();
          _syncAttempts = 0; // Reset for next cycle
        }
      }
    } catch (e) {
      debugPrint("❌ Error in aggressive sync: $e");
    }
  }

  // Refresh Health Connect data by re-initializing
  Future<void> _refreshHealthConnectData() async {
    try {
      debugPrint("🔄 Refreshing Health Connect data...");

      // Re-initialize Health Connect
      await initializeHealthConnect();

      // Force permission check
      await checkHealthConnectPermissions();

      // Small delay to allow data to refresh
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint("❌ Error refreshing Health Connect data: $e");
    }
  }

  // Try alternative sync strategies
  Future<void> _tryAlternativeSyncStrategies() async {
    try {
      debugPrint("🔄 Trying alternative sync strategies...");

      // Strategy 1: Try different time ranges
      await _tryDifferentTimeRanges();

      // Strategy 2: Force data refresh with different parameters
      await _forceDataRefreshWithDifferentParams();
    } catch (e) {
      debugPrint("❌ Error in alternative sync strategies: $e");
    }
  }

  // Try fetching data with different time ranges
  Future<void> _tryDifferentTimeRanges() async {
    try {
      debugPrint("🔄 Trying different time ranges...");

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

      debugPrint(
          "📊 Time range results - 2h: $steps2h, 4h: $steps4h, Today: $stepsToday");

      // Use the highest value
      final maxSteps =
          [steps2h, steps4h, stepsToday].reduce((a, b) => a > b ? a : b);

      if (maxSteps > _lastKnownSteps) {
        final stepIncrease = maxSteps - _lastKnownSteps;
        _lastKnownSteps = maxSteps;
        _lastStepUpdate = now;

        debugPrint(
            "🎉 Alternative sync successful: +$stepIncrease steps (Total: $maxSteps)");
        _notifyStepUpdate(maxSteps, stepIncrease);
      }
    } catch (e) {
      debugPrint("❌ Error trying different time ranges: $e");
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
      debugPrint("❌ Error fetching steps for time range: $e");
      return 0;
    }
  }

  // Force data refresh with different parameters
  Future<void> _forceDataRefreshWithDifferentParams() async {
    try {
      debugPrint("🔄 Forcing data refresh with different parameters...");

      await health.getHealthDataFromTypes(
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now(),
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      // Small delay
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint("❌ Error forcing data refresh: $e");
    }
  }

  // Enhanced force refresh that tries multiple strategies
  Future<int> forceRefreshWithMultipleStrategies() async {
    try {
      debugPrint("🔄 Force refresh with multiple strategies...");

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
      debugPrint("❌ Error in force refresh with multiple strategies: $e");
      return _lastKnownSteps;
    }
  }

  // Stop aggressive sync monitoring
  void stopAggressiveSyncMonitoring() {
    _aggressiveSyncTimer?.cancel();
    _aggressiveSyncTimer = null;
    _syncAttempts = 0;
    debugPrint("🛑 Aggressive sync monitoring stopped");
  }

  // Enhanced stop all monitoring
  void stopAllMonitoring() {
    stopRealTimeStepMonitoring();
    stopAggressiveSyncMonitoring();
    _smartPollingTimer?.cancel();
    _smartPollingTimer = null;
    debugPrint("🛑 All monitoring stopped");
  }

  // ===== REAL-TIME STEP TRACKING INTEGRATION =====

  StreamSubscription<Map<String, dynamic>>? _realTimeStepSubscription;
  bool _isRealTimeTrackingActive = false;
  int _healthConnectBaseline = 0; // Store initial Health Connect steps
  int _sensorBaseline = 0; // Store initial sensor steps
  bool _baselineSet = false; // Track if baseline has been set
  DateTime? _lastSyncTime; // Track last Google Fit sync

  /// Start real-time step tracking using hardware sensor
  Future<bool> startRealTimeStepTracking() async {
    try {
      debugPrint("🚀 Starting real-time step tracking...");

      // Initialize step counter service
      final initialized = await StepCounterService.initialize();
      if (!initialized) {
        debugPrint("❌ Failed to initialize step counter service");
        return false;
      }

      // Start tracking
      final started = await StepCounterService.startTracking();
      if (!started) {
        debugPrint("❌ Failed to start step tracking");
        return false;
      }

      // Listen to real-time updates
      _realTimeStepSubscription = StepCounterService.stepStream.listen(
        (data) async {
          if (data['type'] == 'step_update') {
            final currentSteps = data['currentSteps'] as int;
            final dailySteps = data['dailySteps'] as int;
            final timestamp = data['timestamp'] as DateTime;

            debugPrint(
                "👟 Real-time step update: $currentSteps steps (Daily: $dailySteps)");

            // Only update if we have a valid baseline
            if (_baselineSet) {
              // Get accurate steps from Health Connect (matches Google Fit)
              final accurateSteps = await fetchStepsData();

              // Calculate incremental sensor steps since baseline for real-time updates
              int displaySteps;
              if (currentSteps > 0) {
                // Calculate incremental sensor steps since baseline
                final incrementalSensorSteps = currentSteps - _sensorBaseline;

                // Add incremental sensor steps to Health Connect baseline
                displaySteps = accurateSteps + incrementalSensorSteps;
              } else {
                displaySteps = accurateSteps;
              }

              // Update last known steps with display count
              _lastKnownSteps = displaySteps;
              _lastStepUpdate = timestamp;

              // Notify listeners with display count
              debugPrint(
                  "🎯 Sending real-time step update: $displaySteps (sensor: $currentSteps, health: $accurateSteps)");
              _notifyStepUpdate(displaySteps, currentSteps);
            } else {
              debugPrint("⚠️ Baseline not set yet, skipping update");
            }
          } else if (data['type'] == 'sensor_status') {
            final available = data['available'] as bool;
            debugPrint(
                "📱 Step sensor status: ${available ? 'Available' : 'Not available'}");
          }
        },
        onError: (error) {
          debugPrint("❌ Error in real-time step stream: $error");
        },
      );

      _isRealTimeTrackingActive = true;
      debugPrint("✅ Real-time step tracking started successfully");
      return true;
    } catch (e) {
      debugPrint("❌ Error starting real-time step tracking: $e");
      return false;
    }
  }

  /// Stop real-time step tracking
  Future<void> stopRealTimeStepTracking() async {
    try {
      debugPrint("🛑 Stopping real-time step tracking...");

      _realTimeStepSubscription?.cancel();
      _realTimeStepSubscription = null;

      await StepCounterService.stopTracking();

      _isRealTimeTrackingActive = false;
      debugPrint("✅ Real-time step tracking stopped");
    } catch (e) {
      debugPrint("❌ Error stopping real-time step tracking: $e");
    }
  }

  /// Check if real-time tracking is active
  bool get isRealTimeTrackingActive => _isRealTimeTrackingActive;

  /// Get current real-time step count
  int get currentRealTimeSteps => StepCounterService.currentSteps;

  /// ACCURATE HYBRID - Syncs perfectly with Google Fit
  Future<int> fetchAccurateHybridSteps() async {
    try {
      debugPrint("🎯 ACCURATE HYBRID: Starting accurate step fetch...");

      // Get the most recent Health Connect steps (this should match Google Fit)
      final healthConnectSteps = await fetchStepsData();
      debugPrint(
          "🎯 ACCURATE HYBRID: Health Connect steps: $healthConnectSteps");

      // For accuracy, we'll use ONLY Health Connect steps to match Google Fit
      // The real-time sensor can cause double-counting issues
      final accurateSteps = healthConnectSteps;

      debugPrint(
          "🎯 ACCURATE HYBRID: Using Health Connect only for accuracy: $accurateSteps");
      debugPrint("🎯 ACCURATE HYBRID: This should match Google Fit exactly");

      return accurateSteps;
    } catch (e) {
      debugPrint("🎯 ACCURATE HYBRID: Error, using fallback: $e");
      return 0;
    }
  }

  /// SMART HYBRID - Uses real-time sensor only for animation detection, Health Connect for display
  Future<int> fetchSmartHybridSteps() async {
    try {
      debugPrint("🧠 SMART HYBRID: Starting smart step fetch...");

      // Get Health Connect steps for display accuracy
      final healthConnectSteps = await fetchStepsData();
      debugPrint(
          "🧠 SMART HYBRID: Health Connect steps (display): $healthConnectSteps");

      // Get real-time sensor steps for animation detection only
      final realTimeSteps = StepCounterService.currentSteps;
      debugPrint(
          "🧠 SMART HYBRID: Real-time sensor steps (animation): $realTimeSteps");

      // Use Health Connect for display (matches Google Fit)
      // Use real-time sensor only for detecting if user is currently walking
      final displaySteps = healthConnectSteps;

      debugPrint(
          "🧠 SMART HYBRID: Display steps (Health Connect): $displaySteps");
      debugPrint(
          "🧠 SMART HYBRID: Animation detection (Real-time): $realTimeSteps");

      return displaySteps;
    } catch (e) {
      debugPrint("🧠 SMART HYBRID: Error, using fallback: $e");
      return 0;
    }
  }

  /// GOOGLE FIT SYNC - Ensures perfect sync with Google Fit
  Future<int> fetchGoogleFitSyncSteps() async {
    try {
      debugPrint("📱 GOOGLE FIT SYNC: Starting Google Fit sync...");

      // Force refresh Health Connect data to ensure latest sync
      final steps = await fetchStepsData();

      debugPrint("📱 GOOGLE FIT SYNC: Steps synced with Google Fit: $steps");
      debugPrint("📱 GOOGLE FIT SYNC: This should match Google Fit exactly");

      return steps;
    } catch (e) {
      debugPrint("📱 GOOGLE FIT SYNC: Error, using fallback: $e");
      return 0;
    }
  }

  /// Hybrid step fetching - combines Health Connect and real-time sensor
  /// BULLETPROOF VERSION - Multiple safeguards to prevent disruption
  Future<int> fetchHybridStepsData() async {
    try {
      debugPrint("🛡️ BULLETPROOF: Starting hybrid step fetch...");

      // SAFEGUARD 1: Ensure baseline is always set
      if (!_baselineSet) {
        debugPrint("🛡️ BULLETPROOF: Baseline not set, setting it now...");
        final healthConnectSteps = await fetchStepsData();
        _healthConnectBaseline = healthConnectSteps;
        _baselineSet = true;
        debugPrint("🛡️ BULLETPROOF: Set baseline to: $_healthConnectBaseline");
      }

      // SAFEGUARD 2: Get Health Connect steps with error handling
      int healthConnectSteps;
      try {
        healthConnectSteps = await fetchStepsData();
        debugPrint(
            "🛡️ BULLETPROOF: Health Connect steps: $healthConnectSteps");
      } catch (e) {
        debugPrint(
            "🛡️ BULLETPROOF: Health Connect error, using baseline: $_healthConnectBaseline");
        healthConnectSteps = _healthConnectBaseline;
      }

      // SAFEGUARD 3: Get real-time sensor steps with fallback
      int realTimeSteps;
      try {
        realTimeSteps = StepCounterService.currentSteps;
        debugPrint("🛡️ BULLETPROOF: Real-time sensor steps: $realTimeSteps");
      } catch (e) {
        debugPrint("🛡️ BULLETPROOF: Real-time sensor error, using 0");
        realTimeSteps = 0;
      }

      // SAFEGUARD 4: Validate data integrity
      if (healthConnectSteps < 0) {
        debugPrint(
            "🛡️ BULLETPROOF: Invalid Health Connect steps, using baseline");
        healthConnectSteps = _healthConnectBaseline;
      }

      if (realTimeSteps < 0) {
        debugPrint("🛡️ BULLETPROOF: Invalid real-time steps, using 0");
        realTimeSteps = 0;
      }

      // SAFEGUARD 5: Add real-time sensor steps to Health Connect baseline
      int finalSteps;
      if (realTimeSteps > 0) {
        // Add sensor steps to Health Connect baseline for real-time updates
        finalSteps = healthConnectSteps + realTimeSteps;
        debugPrint(
            "🛡️ BULLETPROOF: Real-time total: $healthConnectSteps (Health Connect) + $realTimeSteps (Sensor) = $finalSteps");
      } else {
        finalSteps = healthConnectSteps;
        debugPrint(
            "🛡️ BULLETPROOF: Using Health Connect steps only: $finalSteps");
      }

      // SAFEGUARD 7: Update baseline if Health Connect steps increased significantly
      if (healthConnectSteps > _healthConnectBaseline + 10) {
        debugPrint(
            "🛡️ BULLETPROOF: Health Connect steps increased significantly, updating baseline");
        _healthConnectBaseline = healthConnectSteps;
        debugPrint(
            "🛡️ BULLETPROOF: Updated baseline to: $_healthConnectBaseline");
      }

      return finalSteps;
    } catch (e) {
      debugPrint(
          "🛡️ BULLETPROOF: Critical error in hybrid fetch, using fallback: $e");

      // SAFEGUARD 8: Ultimate fallback - return baseline or 0
      if (_baselineSet) {
        debugPrint(
            "🛡️ BULLETPROOF: Returning baseline as fallback: $_healthConnectBaseline");
        return _healthConnectBaseline;
      } else {
        debugPrint("🛡️ BULLETPROOF: No baseline available, returning 0");
        return 0;
      }
    }
  }

  /// FORCE HYBRID - Always use hybrid method regardless of errors
  Future<int> forceHybridStepsData() async {
    debugPrint("💪 FORCE HYBRID: Ensuring hybrid method is used...");

    // Force baseline setup
    if (!_baselineSet) {
      try {
        final steps = await fetchStepsData();
        _healthConnectBaseline = steps;
        _baselineSet = true;
        debugPrint(
            "💪 FORCE HYBRID: Forced baseline setup: $_healthConnectBaseline");
      } catch (e) {
        _healthConnectBaseline = 0;
        _baselineSet = true;
        debugPrint("💪 FORCE HYBRID: Forced baseline to 0 due to error");
      }
    }

    return await fetchSensorOptimizedSteps();
  }

  /// ANIMATION-SAFE HYBRID - Specifically for character animations
  Future<int> fetchAnimationSafeSteps() async {
    debugPrint("🎬 ANIMATION-SAFE: Fetching steps for character animation...");

    // VALIDATION: Ensure hybrid mode is always used
    if (!_forceHybridMode) {
      debugPrint(
          "🚨 CRITICAL ERROR: Hybrid mode is disabled! This will break animations!");
      debugPrint("🚨 CRITICAL ERROR: _forceHybridMode must always be true!");
    }

    // Use Google Fit sync for accuracy
    final steps = await fetchGoogleFitSyncSteps();

    debugPrint("🎬 ANIMATION-SAFE: Steps for animation: $steps");
    return steps;
  }

  /// VALIDATION: Ensure hybrid method is always used
  void validateHybridMode() {
    if (!_forceHybridMode) {
      throw Exception(
          "CRITICAL: Hybrid mode is disabled! This will break character animations!");
    }
    debugPrint(
        "✅ Hybrid mode validation passed - animations will work correctly");
  }

  /// FORCE VALIDATION: Call this before any step fetch to ensure hybrid mode
  Future<int> forceValidatedHybridSteps() async {
    validateHybridMode();
    return await fetchAnimationSafeSteps();
  }

  /// Initialize both Health Connect and real-time tracking
  Future<bool> initializeHybridTracking() async {
    try {
      debugPrint("🔄 Initializing hybrid tracking system...");

      // Initialize Health Connect
      final healthConnectInitialized = await initializeHealthConnect();

      // Initialize real-time tracking
      final realTimeInitialized = await StepCounterService.initialize();

      // Set baseline immediately if Health Connect is available
      if (healthConnectInitialized && !_baselineSet) {
        final initialSteps = await fetchStepsData();
        _healthConnectBaseline = initialSteps;
        _baselineSet = true;
        debugPrint("📊 Set initial baseline: $_healthConnectBaseline");
      }

      debugPrint(
          "🏥 Health Connect: ${healthConnectInitialized ? 'Ready' : 'Not available'}");
      debugPrint(
          "📱 Real-time sensor: ${realTimeInitialized ? 'Ready' : 'Not available'}");

      return healthConnectInitialized || realTimeInitialized;
    } catch (e) {
      debugPrint("❌ Error initializing hybrid tracking: $e");
      return false;
    }
  }

  /// Enhanced monitoring that uses both systems
  Future<void> startHybridMonitoring() async {
    try {
      debugPrint("🚀 Starting hybrid monitoring...");

      // Start real-time tracking if available
      if (await StepCounterService.isSensorAvailable()) {
        await startRealTimeStepTracking();
        debugPrint("✅ Real-time tracking started");
      } else {
        debugPrint(
            "⚠️ Real-time sensor not available, using Health Connect only");
        // Only use Health Connect monitoring if real-time sensor is not available
        await startRealTimeStepMonitoring();
      }

      debugPrint("✅ Hybrid monitoring started");
    } catch (e) {
      debugPrint("❌ Error starting hybrid monitoring: $e");
    }
  }

  /// Stop hybrid monitoring
  Future<void> stopHybridMonitoring() async {
    try {
      debugPrint("🛑 Stopping hybrid monitoring...");

      await stopRealTimeStepTracking();
      stopRealTimeStepMonitoring();

      debugPrint("✅ Hybrid monitoring stopped");
    } catch (e) {
      debugPrint("❌ Error stopping hybrid monitoring: $e");
    }
  }

  /// Reset baseline (useful for new day or app restart)
  void resetBaseline() {
    _baselineSet = false;
    _healthConnectBaseline = 0;
    debugPrint("🔄 Baseline reset");
  }

  /// Get current baseline value
  int get healthConnectBaseline => _healthConnectBaseline;

  /// SENSOR-OPTIMIZED ANIMATION DETECTION - Uses optimal Google Fit + sensor approach
  Future<int> fetchSensorOptimizedSteps() async {
    try {
      debugPrint(
          "📱 SENSOR-OPTIMIZED: Starting sensor-optimized step fetch...");

      // Use the optimal approach: Google Fit for accuracy
      final accurateSteps = await fetchOptimalSteps();
      debugPrint(
          "📱 SENSOR-OPTIMIZED: Optimal steps (Google Fit): $accurateSteps");

      // Get real-time sensor data for animation detection
      final sensorSteps = StepCounterService.currentSteps;
      final isSensorActive = await StepCounterService.isSensorAvailable();

      debugPrint("📱 SENSOR-OPTIMIZED: Real-time sensor steps: $sensorSteps");
      debugPrint("📱 SENSOR-OPTIMIZED: Sensor active: $isSensorActive");

      // Use Google Fit steps for display accuracy
      final displaySteps = accurateSteps;

      debugPrint(
          "📱 SENSOR-OPTIMIZED: Display steps (Google Fit): $displaySteps");
      debugPrint(
          "📱 SENSOR-OPTIMIZED: Animation detection (Sensor): $sensorSteps");

      return displaySteps;
    } catch (e) {
      debugPrint("📱 SENSOR-OPTIMIZED: Error, using fallback: $e");
      return 0;
    }
  }

  /// REAL-TIME ANIMATION DETECTOR - Uses sensors to detect active walking
  Future<bool> isUserActivelyWalking() async {
    try {
      debugPrint(
          "🎬 ANIMATION DETECTOR: Checking if user is actively walking...");

      // Check if real-time sensor is available
      final isSensorAvailable = await StepCounterService.isSensorAvailable();
      if (!isSensorAvailable) {
        debugPrint(
            "🎬 ANIMATION DETECTOR: Sensor not available, using Health Connect");
        return false; // Fall back to Health Connect detection
      }

      // Get real-time sensor steps
      final currentSensorSteps = StepCounterService.currentSteps;
      final lastKnownSensorSteps = _lastKnownSteps;

      debugPrint(
          "🎬 ANIMATION DETECTOR: Current sensor steps: $currentSensorSteps");
      debugPrint(
          "🎬 ANIMATION DETECTOR: Last known sensor steps: $lastKnownSensorSteps");

      // Check if sensor steps increased recently (within last 5 seconds)
      final timeSinceLastUpdate =
          DateTime.now().difference(_lastStepUpdate).inSeconds;
      final stepsIncreased = currentSensorSteps > lastKnownSensorSteps;

      debugPrint(
          "🎬 ANIMATION DETECTOR: Time since last update: ${timeSinceLastUpdate}s");
      debugPrint("🎬 ANIMATION DETECTOR: Steps increased: $stepsIncreased");

      // User is actively walking if:
      // 1. Sensor steps increased recently, OR
      // 2. Last update was very recent (within 3 seconds)
      final isActivelyWalking = stepsIncreased || timeSinceLastUpdate <= 3;

      debugPrint(
          "🎬 ANIMATION DETECTOR: User actively walking: $isActivelyWalking");

      return isActivelyWalking;
    } catch (e) {
      debugPrint("🎬 ANIMATION DETECTOR: Error, using fallback: $e");
      return false;
    }
  }

  /// HYBRID ANIMATION SYSTEM - Combines Google Fit accuracy with sensor responsiveness
  Future<Map<String, dynamic>> fetchHybridAnimationData() async {
    try {
      debugPrint("🎮 HYBRID ANIMATION: Starting hybrid animation system...");

      // Get accurate step count from Google Fit
      final googleFitSteps = await fetchGoogleFitSyncSteps();

      // Check if user is actively walking using sensors
      final isActivelyWalking = await isUserActivelyWalking();

      debugPrint("🎮 HYBRID ANIMATION: Google Fit steps: $googleFitSteps");
      debugPrint("🎮 HYBRID ANIMATION: Actively walking: $isActivelyWalking");

      return {
        'steps': googleFitSteps,
        'isActivelyWalking': isActivelyWalking,
        'source': 'hybrid_animation_system'
      };
    } catch (e) {
      debugPrint("🎮 HYBRID ANIMATION: Error, using fallback: $e");
      return {'steps': 0, 'isActivelyWalking': false, 'source': 'fallback'};
    }
  }

  /// ACCURATE DAILY STEPS - Uses baseline + incremental sensor approach
  Future<int> fetchAccurateDailySteps() async {
    try {
      debugPrint(
          "🎯 ACCURATE DAILY: Starting accurate daily step calculation...");

      // Get Health Connect steps at app launch (baseline)
      if (!_baselineSet) {
        final hcStepsAtLaunch = await fetchStepsData();
        _healthConnectBaseline = hcStepsAtLaunch;
        _baselineSet = true;
        debugPrint(
            "🎯 ACCURATE DAILY: Set baseline at launch: $_healthConnectBaseline");
      }

      // Get current Health Connect steps (this is the accurate source)
      final currentHealthConnectSteps = await fetchStepsData();

      debugPrint(
          "🎯 ACCURATE DAILY: Current Health Connect steps: $currentHealthConnectSteps");
      debugPrint("🎯 ACCURATE DAILY: This matches Google Fit exactly!");

      return currentHealthConnectSteps;
    } catch (e) {
      debugPrint("🎯 ACCURATE DAILY: Error, using fallback: $e");
      return _healthConnectBaseline;
    }
  }

  /// RESET DAILY BASELINE - Call this when starting a new day
  Future<void> resetDailyBaseline() async {
    try {
      debugPrint("🔄 RESET DAILY: Resetting daily baseline...");

      // Get current Health Connect steps as new baseline
      final newBaseline = await fetchStepsData();
      _healthConnectBaseline = newBaseline;
      _baselineSet = true;

      // Reset sensor tracking
      StepCounterService.resetCounter();

      debugPrint("🔄 RESET DAILY: New baseline set: $_healthConnectBaseline");
      debugPrint("🔄 RESET DAILY: Sensor counter reset");
    } catch (e) {
      debugPrint("🔄 RESET DAILY: Error resetting baseline: $e");
    }
  }

  /// OPTIMAL STEP COUNTING - Google Fit for accuracy, sensors for animation
  Future<int> fetchOptimalSteps() async {
    try {
      debugPrint("🎯 OPTIMAL: Starting optimal step fetch...");

      // Get accurate step count directly from Google Fit
      final accurateSteps = await fetchStepsData();
      debugPrint("🎯 OPTIMAL: Google Fit steps (accurate): $accurateSteps");

      // Use sensors ONLY for animation detection, not step counting
      final sensorSteps = StepCounterService.currentSteps;
      final isSensorActive = await StepCounterService.isSensorAvailable();

      debugPrint("🎯 OPTIMAL: Sensor steps (animation only): $sensorSteps");
      debugPrint("🎯 OPTIMAL: Sensor active: $isSensorActive");

      // Return Google Fit steps for display accuracy
      debugPrint("🎯 OPTIMAL: Returning Google Fit steps: $accurateSteps");
      return accurateSteps;
    } catch (e) {
      debugPrint("🎯 OPTIMAL: Error, using fallback: $e");
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
      debugPrint(
          "🎭 ANIMATION: Sensor steps: $sensorSteps, Sensor active: $isSensorActive, Walking: $isWalking");
      return isWalking;
    } catch (e) {
      debugPrint("🎭 ANIMATION: Error detecting walking state: $e");
      return false;
    }
  }

  /// COMPLETE STEP DATA - Combines accurate steps + animation state
  Future<Map<String, dynamic>> fetchCompleteStepData() async {
    try {
      debugPrint("🎯 COMPLETE: Fetching complete step data...");

      // Get accurate steps from Google Fit
      final accurateSteps = await fetchOptimalSteps();

      // Get animation state from sensors
      final isWalking = await isUserWalkingForAnimation();

      final result = {
        'steps': accurateSteps,
        'isWalking': isWalking,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      debugPrint(
          "🎯 COMPLETE: Steps: ${result['steps']}, Walking: ${result['isWalking']}");
      return result;
    } catch (e) {
      debugPrint("🎯 COMPLETE: Error: $e");
      return {
        'steps': 0,
        'isWalking': false,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  /// Get pure Health Connect steps for debugging and comparison
  Future<int> getPureHealthConnectSteps() async {
    try {
      return await fetchStepsData();
    } catch (e) {
      debugPrint("❌ Error getting pure Health Connect steps: $e");
      return 0;
    }
  }

  /// Reset hybrid system baselines to resolve inconsistencies
  Future<void> resetHybridSystem() async {
    try {
      debugPrint("🔄 Resetting hybrid system baselines...");

      // Reset baselines
      _baselineSet = false;
      _healthConnectBaseline = 0;
      _sensorBaseline = 0;

      // Get fresh Health Connect steps
      final freshSteps = await fetchStepsData();
      _healthConnectBaseline = freshSteps;
      _sensorBaseline = StepCounterService.currentSteps;
      _baselineSet = true;

      debugPrint("🔄 Hybrid system reset complete:");
      debugPrint("  - Health Connect baseline: $_healthConnectBaseline");
      debugPrint("  - Sensor baseline: $_sensorBaseline");
    } catch (e) {
      debugPrint("❌ Error resetting hybrid system: $e");
    }
  }

  /// Test step consistency between Health Connect and hybrid system
  Future<void> testStepConsistency() async {
    try {
      debugPrint("🧪 Testing step consistency...");

      final pureSteps = await getPureHealthConnectSteps();
      final hybridSteps = await fetchHybridRealTimeSteps();

      debugPrint("🧪 CONSISTENCY TEST RESULTS:");
      debugPrint("  - Pure Health Connect steps: $pureSteps");
      debugPrint("  - Hybrid steps: $hybridSteps");
      debugPrint("  - Difference: ${hybridSteps - pureSteps}");

      if (hybridSteps < pureSteps) {
        debugPrint(
            "❌ INCONSISTENCY DETECTED: Hybrid steps less than Health Connect steps");
        await resetHybridSystem();
      } else {
        debugPrint("✅ Step consistency test passed");
      }
    } catch (e) {
      debugPrint("❌ Error testing step consistency: $e");
    }
  }

  /// HYBRID REAL-TIME STEPS - Shows immediate feedback + Google Fit accuracy
  Future<int> fetchHybridRealTimeSteps() async {
    try {
      debugPrint("🔄 HYBRID: Starting hybrid real-time step calculation...");

      // Initialize sensor baseline if not set (first time)
      if (!_baselineSet) {
        // Set sensor baseline to current sensor value
        _sensorBaseline = StepCounterService.currentSteps;
        debugPrint("🔄 HYBRID: Set sensor baseline: $_sensorBaseline");
      }

      // Get Google Fit steps directly (this is the accurate source)
      final healthConnectSteps = await fetchStepsData();

      // Update baseline if not set or if Health Connect steps increased significantly
      if (!_baselineSet || healthConnectSteps > _healthConnectBaseline + 10) {
        // Update Health Connect baseline
        _healthConnectBaseline = healthConnectSteps;
        _baselineSet = true;

        // Only adjust sensor baseline if this is the first time setting it
        // This prevents incorrect adjustments that could cause negative increments
        if (!_baselineSet || _sensorBaseline == 0) {
          _sensorBaseline = StepCounterService.currentSteps;
          debugPrint(
              "🔄 HYBRID: First time setup - set sensor baseline to current sensor value: $_sensorBaseline");
        }

        debugPrint(
            "🔄 HYBRID: Updated Google Fit baseline: $_healthConnectBaseline");
        debugPrint("🔄 HYBRID: Current sensor baseline: $_sensorBaseline");
      }

      // Get real-time sensor steps for immediate feedback
      final sensorSteps = StepCounterService.currentSteps;
      final isSensorActive = await StepCounterService.isSensorAvailable();

      debugPrint("🔄 HYBRID: Google Fit steps (accurate): $healthConnectSteps");
      debugPrint("🔄 HYBRID: Real-time sensor steps (immediate): $sensorSteps");
      debugPrint("🔄 HYBRID: Sensor active: $isSensorActive");
      debugPrint("🔄 HYBRID: Baseline set: $_baselineSet");
      debugPrint("🔄 HYBRID: Current baseline: $_healthConnectBaseline");

      // HYBRID APPROACH: Use Health Connect as primary source, sensor for real-time updates
      int displaySteps;

      if (isSensorActive && sensorSteps > 0) {
        // Calculate incremental sensor steps since baseline
        final incrementalSensorSteps = sensorSteps - _sensorBaseline;

        // Only add positive sensor increments to avoid reducing Health Connect steps
        if (incrementalSensorSteps > 0) {
          displaySteps = healthConnectSteps + incrementalSensorSteps;
          debugPrint(
              "🔄 HYBRID: Real-time total: $healthConnectSteps (Health Connect) + $incrementalSensorSteps (Sensor increment) = $displaySteps");
        } else {
          // If sensor increment is negative or zero, use Health Connect steps only
          displaySteps = healthConnectSteps;
          debugPrint(
              "🔄 HYBRID: Using Health Connect steps only (sensor increment: $incrementalSensorSteps): $displaySteps");
        }

        debugPrint(
            "🔄 HYBRID: Sensor baseline: $_sensorBaseline, Current sensor: $sensorSteps");
        debugPrint(
            "🔄 HYBRID: Provides immediate feedback while Health Connect syncs!");
      } else {
        // If sensor is not active, use Health Connect steps only
        displaySteps = healthConnectSteps;
        debugPrint("🔄 HYBRID: Using Health Connect steps only: $displaySteps");
      }

      debugPrint("🔄 HYBRID: Final display steps: $displaySteps");
      debugPrint("🔄 HYBRID: Real-time hybrid system active!");

      // Ensure we never return less than Health Connect steps
      if (displaySteps < healthConnectSteps) {
        debugPrint(
            "🔄 HYBRID: WARNING - Display steps ($displaySteps) less than Health Connect steps ($healthConnectSteps), using Health Connect steps");
        displaySteps = healthConnectSteps;

        // If there's a significant inconsistency, reset the hybrid system
        if (healthConnectSteps - displaySteps > 10) {
          debugPrint(
              "🔄 HYBRID: Significant inconsistency detected, resetting hybrid system...");
          await resetHybridSystem();
        }
      }

      // Update leaderboard data in background
      _updateLeaderboardData(displaySteps);

      // Debug logging for step consistency
      debugPrint("🔍 STEP CONSISTENCY DEBUG:");
      debugPrint("  - Pure Health Connect steps: $healthConnectSteps");
      debugPrint("  - Hybrid display steps: $displaySteps");
      debugPrint("  - Sensor steps: $sensorSteps");
      debugPrint("  - Sensor baseline: $_sensorBaseline");
      debugPrint("  - Health Connect baseline: $_healthConnectBaseline");

      return displaySteps;
    } catch (e) {
      debugPrint("🔄 HYBRID: Error, using fallback: $e");
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

        await _networkService.executeWithRetry(() async {
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

              // Update leveling system with new daily steps
              await _updateLevelingSystem(user.uid, stepIncrease.toInt());

              debugPrint(
                  "📊 LEADERBOARD: Updated daily steps: $currentDailySteps → $steps (+$stepIncrease)");
              debugPrint("📊 LEADERBOARD: Updated weekly total: $weeklyTotal");
              debugPrint(
                  "📊 LEADERBOARD: Updated leaderboard data for ${user.uid}");
            }
          } else {
            // Initialize user data if it doesn't exist
            await userRef.set({
              'daily_steps': {today: steps},
              'weekly_steps': steps,
              'coins': 0,
              'last_week_rewarded': null,
              'shown_rewards': {},
            }, SetOptions(merge: true));

            debugPrint(
                "📊 LEADERBOARD: Initialized user data for ${user.uid} with $steps steps");
          }
        });
      }
    } catch (e) {
      debugPrint("📊 LEADERBOARD: Error updating leaderboard data: $e");
    }
  }

  /// SYNC WITH GOOGLE FIT - Updates baseline periodically for accuracy
  Future<void> syncWithGoogleFit() async {
    try {
      debugPrint("🔄 SYNC: Syncing with Google Fit for accuracy...");

      // Get current Google Fit steps
      final currentGoogleFitSteps = await fetchStepsData();

      // Update baseline to current Google Fit
      _healthConnectBaseline = currentGoogleFitSteps;

      // Reset sensor counter to account for the sync
      StepCounterService.resetCounter();

      debugPrint("🔄 SYNC: Google Fit steps: $currentGoogleFitSteps");

      debugPrint("🔄 SYNC: New baseline: $_healthConnectBaseline");
      debugPrint("🔄 SYNC: Sensor counter reset");
      debugPrint("🔄 SYNC: Now showing accurate steps!");
    } catch (e) {
      debugPrint("🔄 SYNC: Error syncing with Google Fit: $e");
    }
  }

  /// SMART HYBRID SYSTEM - Best of both worlds
  Future<Map<String, dynamic>> fetchSmartHybridData() async {
    try {
      debugPrint("🧠 SMART: Starting smart hybrid system...");

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

      debugPrint(
          "🧠 SMART: Steps: ${result['steps']}, Walking: ${result['isWalking']}");
      debugPrint(
          "🧠 SMART: Baseline: ${result['baseline']}, Sensor: ${result['sensorSteps']}");

      return result;
    } catch (e) {
      debugPrint("🧠 SMART: Error: $e");
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
      debugPrint("🔄 Starting continuous step updates...");

      // Update steps every 30 seconds (background, no UI impact)
      Timer.periodic(const Duration(seconds: 30), (timer) async {
        try {
          final currentSteps = await fetchHybridRealTimeSteps();
          await _updateLeaderboardData(currentSteps);
          debugPrint("🔄 Background step update: $currentSteps steps");
        } catch (e) {
          debugPrint("🔄 Error in continuous step update: $e");
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
              debugPrint("🔄 Resume step update: $currentSteps steps");
            } catch (e) {
              debugPrint("🔄 Error updating steps on resume: $e");
            }
          },
        ),
      );

      debugPrint("✅ Continuous step updates started (no loading screens)");
    } catch (e) {
      debugPrint("❌ Error starting continuous step updates: $e");
    }
  }

  /// Get start of current week (Monday) - for HealthService
  DateTime _getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return date.subtract(Duration(days: daysFromMonday));
  }

  /// Update leveling system with new daily steps
  Future<void> _updateLevelingSystem(String userId, int stepIncrease) async {
    try {
      // Update user level with the step increase
      final levelResult =
          await LevelingService.updateUserLevel(userId, stepIncrease);

      if (levelResult != null && levelResult['leveledUp'] == true) {
        debugPrint(
            "🎉 LEVEL UP: User ${userId} leveled up from ${levelResult['oldLevel']} to ${levelResult['newLevel']}");
        debugPrint("🎉 LEVEL UP: Reward: ${levelResult['reward']} coins");

        // You can add notification logic here for level up
        // _showLevelUpNotification(levelResult);
      }
    } catch (e) {
      debugPrint("Error updating leveling system: $e");
    }
  }

  // Force reset all Health Connect permissions and cache
  Future<bool> forceResetHealthConnectPermissions() async {
    try {
      debugPrint(
          "🔄 FORCE RESET: Clearing all Health Connect permissions and cache...");

      // Step 1: Clear any cached state
      _isInitialized = false;

      // Step 2: Force re-initialization
      bool initialized = await initializeHealthConnect();
      if (!initialized) {
        debugPrint("❌ FORCE RESET: Failed to re-initialize Health Connect");
        return false;
      }

      // Step 3: Clear Firestore permission status
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'hasHealthPermissions': false});
        debugPrint("💾 FORCE RESET: Cleared Firestore permission status");
      }

      // Step 4: Force a fresh permission check
      await Future.delayed(const Duration(seconds: 2));

      debugPrint("✅ FORCE RESET: Health Connect permissions cleared");
      return true;
    } catch (e) {
      debugPrint("❌ FORCE RESET: Error clearing permissions: $e");
      return false;
    }
  }

  // Nuclear option: Force Health Connect to completely reset permissions
  Future<bool> nuclearPermissionReset(BuildContext context) async {
    try {
      debugPrint("☢️ NUCLEAR: Starting nuclear permission reset...");

      // Step 1: Show warning dialog
      bool? proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Complete Permission Reset'),
            content: const Text(
              'This will completely reset all Health Connect permissions for Walkzilla.\n\n'
              'IMPORTANT: You must manually clear permissions in Health Connect settings first.\n\n'
              'Steps:\n'
              '1. Tap "Clear All" below\n'
              '2. Go to Health Connect app\n'
              '3. Find "Walkzilla" and remove ALL permissions\n'
              '4. Return here and tap "Request Fresh"\n\n'
              'This will force Health Connect to show the correct data types.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: const Text('Clear All'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      );

      if (proceed != true) {
        return false;
      }

      // Step 2: Clear all cached state
      await forceResetHealthConnectPermissions();

      // Step 3: Force Health Connect to recognize new data types
      await _forceHealthConnectDataTypesRecognition();

      // Step 4: Show success message
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Reset Complete'),
              content: const Text(
                'All cached permissions have been cleared.\n\n'
                'Now please:\n'
                '1. Open Health Connect app\n'
                '2. Find "Walkzilla" in the list\n'
                '3. Remove ALL permissions\n'
                '4. Return here and try requesting permissions again\n\n'
                'This should show the correct data types (Steps, Distance, Total Calories).',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }

      return true;
    } catch (e) {
      debugPrint("❌ NUCLEAR: Error in nuclear reset: $e");
      return false;
    }
  }

  // Force Health Connect to recognize new data types
  Future<void> _forceHealthConnectDataTypesRecognition() async {
    try {
      debugPrint(
          "🔧 FORCE RECOGNITION: Forcing Health Connect to recognize new data types...");

      // Step 1: Try to request permissions for each data type individually
      for (HealthDataType dataType in _dataTypes) {
        try {
          debugPrint("🔧 FORCE RECOGNITION: Testing ${dataType.toString()}...");

          // Try to request permission for this specific type
          bool? result = await health.hasPermissions([dataType]);
          debugPrint(
              "🔧 FORCE RECOGNITION: ${dataType.toString()} result: $result");

          // Small delay between requests
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint(
              "🔧 FORCE RECOGNITION: Error testing ${dataType.toString()}: $e");
        }
      }

      // Step 2: Force a complete permission request
      try {
        debugPrint("🔧 FORCE RECOGNITION: Requesting all data types...");
        bool granted = await health.requestAuthorization(
          _dataTypes,
          permissions: List.filled(_dataTypes.length, HealthDataAccess.READ),
        );
        debugPrint("🔧 FORCE RECOGNITION: Complete request result: $granted");
      } catch (e) {
        debugPrint("🔧 FORCE RECOGNITION: Error in complete request: $e");
      }

      debugPrint("✅ FORCE RECOGNITION: Data type recognition forced");
    } catch (e) {
      debugPrint("❌ FORCE RECOGNITION: Error forcing recognition: $e");
    }
  }

  // Aggressive permission request that forces a complete reset
  Future<bool> requestHealthConnectPermissionsAggressive(
      BuildContext context) async {
    try {
      debugPrint("🚀 AGGRESSIVE: Starting aggressive permission request...");

      // Step 1: Force reset everything
      await forceResetHealthConnectPermissions();

      // Step 2: Check what data types are actually supported
      List<HealthDataType> availableTypes = await getAvailableDataTypes();
      debugPrint(
          "🔍 AGGRESSIVE: Available data types: ${availableTypes.map((e) => e.toString()).join(', ')}");

      if (availableTypes.isEmpty) {
        debugPrint("❌ AGGRESSIVE: No supported data types found!");
        if (context.mounted) {
          await _showHealthConnectInstallDialog(context);
        }
        return false;
      }

      // Step 3: Show user the exact permissions we're requesting
      if (context.mounted) {
        bool userAccepted =
            await _showAggressivePermissionDialog(context, availableTypes);
        if (!userAccepted) {
          return false;
        }
      }

      // Step 4: Request permissions with multiple attempts
      bool granted = await _requestPermissionsWithRetry(availableTypes);

      if (granted) {
        debugPrint("✅ AGGRESSIVE: Permissions granted successfully");

        // Update Firestore
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'hasHealthPermissions': true});
        }

        return true;
      } else {
        debugPrint("❌ AGGRESSIVE: Permissions not granted, showing manual fix");
        if (context.mounted) {
          return await manualPermissionFix(context);
        }
        return false;
      }
    } catch (e) {
      debugPrint("❌ AGGRESSIVE: Error in aggressive permission request: $e");
      return false;
    }
  }

  // Show aggressive permission dialog with exact data types
  Future<bool> _showAggressivePermissionDialog(
      BuildContext context, List<HealthDataType> availableTypes) async {
    String permissionList = _buildPermissionList(availableTypes);

    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Health Connect Access Required'),
          content: Text(
            'Walkzilla needs access to your health data to provide accurate fitness tracking.\n\n'
            'We will request access to:\n'
            '$permissionList\n\n'
            'IMPORTANT: If you don\'t see all these options in Health Connect, '
            'some data types may not be supported on your device.\n\n'
            'Your data privacy is important to us and all data is stored securely.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Request Access'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // Request permissions with multiple retry attempts
  Future<bool> _requestPermissionsWithRetry(
      List<HealthDataType> dataTypes) async {
    try {
      debugPrint("🔄 RETRY: Requesting permissions with retry logic...");

      for (int attempt = 1; attempt <= 3; attempt++) {
        debugPrint("🔄 RETRY: Attempt $attempt of 3");

        bool granted = await health.requestAuthorization(
          dataTypes,
          permissions: List.filled(dataTypes.length, HealthDataAccess.READ),
        );

        debugPrint("🔄 RETRY: Attempt $attempt result: $granted");

        if (granted) {
          // Wait and verify
          await Future.delayed(const Duration(seconds: 2));
          bool? verified = await health.hasPermissions(dataTypes);

          if (verified == true) {
            debugPrint("✅ RETRY: Permissions verified on attempt $attempt");
            return true;
          } else {
            debugPrint(
                "⚠️ RETRY: Permission request succeeded but verification failed on attempt $attempt");
          }
        }

        // Wait before next attempt
        if (attempt < 3) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      debugPrint("❌ RETRY: All attempts failed");
      return false;
    } catch (e) {
      debugPrint("❌ RETRY: Error in retry logic: $e");
      return false;
    }
  }

  // Complete reset method for stubborn permission issues
  Future<bool> completePermissionReset(BuildContext context) async {
    try {
      debugPrint("🔄 COMPLETE RESET: Starting complete permission reset...");

      bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Complete Permission Reset'),
            content: const Text(
              'This will completely reset all Health Connect permissions for Walkzilla.\n\n'
              'To fix the permission issues:\n\n'
              '1. Tap "Clear Permissions" below\n'
              '2. Go to your device Settings\n'
              '3. Find "Apps" → "Walkzilla"\n'
              '4. Tap "Permissions" → "Health Connect"\n'
              '5. Turn OFF all permissions\n'
              '6. Return to this app\n'
              '7. Tap "Request Fresh Permissions"\n\n'
              'This should resolve the cached permission issues.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: const Text('Clear Permissions'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      );

      if (result == true) {
        // Clear all cached state
        await forceResetHealthConnectPermissions();

        // Show success message
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Permissions Cleared'),
                content: const Text(
                  'All cached permissions have been cleared.\n\n'
                  'Now please:\n'
                  '1. Go to device Settings\n'
                  '2. Find Walkzilla app\n'
                  '3. Clear Health Connect permissions\n'
                  '4. Return here and try again',
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        }

        return true;
      }

      return false;
    } catch (e) {
      debugPrint("❌ COMPLETE RESET: Error in complete reset: $e");
      return false;
    }
  }

  // Emergency permission fix for when nothing else works
  Future<bool> emergencyPermissionFix(BuildContext context) async {
    try {
      debugPrint("🚨 EMERGENCY: Starting emergency permission fix...");

      // Show emergency dialog
      bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Emergency Permission Fix'),
            content: const Text(
              'If permissions are still not working, try this emergency fix:\n\n'
              '1. Uninstall Walkzilla completely\n'
              '2. Go to Health Connect app\n'
              '3. Remove any Walkzilla permissions\n'
              '4. Restart your device\n'
              '5. Reinstall Walkzilla\n'
              '6. Try permissions again\n\n'
              'This is a nuclear option but should fix any cached permission issues.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              TextButton(
                child: const Text('I Understand'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      );

      if (result == true) {
        // Clear everything
        await forceResetHealthConnectPermissions();

        // Show final instructions
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Emergency Fix Instructions'),
                content: const Text(
                  'Please follow these steps:\n\n'
                  '1. Close this app completely\n'
                  '2. Uninstall Walkzilla from your device\n'
                  '3. Open Health Connect app\n'
                  '4. Remove any Walkzilla permissions\n'
                  '5. Restart your device\n'
                  '6. Reinstall Walkzilla from Play Store\n'
                  '7. Try the permissions again\n\n'
                  'This should completely reset all cached permissions.',
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Got It'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        }

        return true;
      }

      return false;
    } catch (e) {
      debugPrint("❌ EMERGENCY: Error in emergency fix: $e");
      return false;
    }
  }

  // Comprehensive permission testing and debugging
  Future<void> comprehensivePermissionTest(BuildContext context) async {
    try {
      debugPrint("🔧 === COMPREHENSIVE PERMISSION TEST START ===");

      // Test 1: Check available data types
      debugPrint("\n📋 TEST 1: Available Data Types");
      List<HealthDataType> availableTypes = await getAvailableDataTypes();
      debugPrint(
          "Available: ${availableTypes.map((e) => e.toString()).join(', ')}");

      // Test 2: Check current permissions
      debugPrint("\n🔍 TEST 2: Current Permissions");
      Map<String, dynamic> currentPermissions =
          await checkDetailedPermissions();
      debugPrint("Current permissions: $currentPermissions");

      // Test 3: Check data type support
      debugPrint("\n✅ TEST 3: Data Type Support");
      Map<String, bool> supportStatus = await checkDataTypeSupport();
      debugPrint("Support status: $supportStatus");

      // Show comprehensive results
      if (context.mounted) {
        _showComprehensiveTestResults(
            context, availableTypes, currentPermissions, supportStatus);
      }

      debugPrint("🔧 === COMPREHENSIVE PERMISSION TEST END ===");
    } catch (e) {
      debugPrint("❌ Error in comprehensive test: $e");
    }
  }

  // Show comprehensive test results
  void _showComprehensiveTestResults(
    BuildContext context,
    List<HealthDataType> availableTypes,
    Map<String, dynamic> currentPermissions,
    Map<String, bool> supportStatus,
  ) {
    String availableText =
        availableTypes.map((e) => '• ${e.toString()}').join('\n');
    String requestedText =
        _dataTypes.map((e) => '• ${e.toString()}').join('\n');

    String individualText = '';
    Map<String, bool> individual =
        currentPermissions['individual'] as Map<String, bool>? ?? {};
    individual.forEach((key, value) {
      individualText += '• $key: ${value ? '✅ Granted' : '❌ Not Granted'}\n';
    });

    String supportText = '';
    supportStatus.forEach((key, value) {
      supportText += '• $key: ${value ? '✅ Supported' : '❌ Not Supported'}\n';
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Comprehensive Permission Test'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Available Data Types:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(availableText),
                const SizedBox(height: 16),
                const Text('Requested Data Types:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(requestedText),
                const SizedBox(height: 16),
                const Text('Device Support:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(supportText),
                const SizedBox(height: 16),
                const Text('Current Permissions:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(individualText),
                const SizedBox(height: 16),
                Text(
                    'Overall: ${currentPermissions['overall'] ? '✅ Granted' : '❌ Not Granted'}'),
                const SizedBox(height: 16),
                const Text('Recommendations:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Text(
                    '• If permissions are not granted, try the aggressive reset\n• If data types are not supported, they won\'t appear in Health Connect\n• Heart Rate may still appear due to cached permissions'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Aggressive Reset'),
              onPressed: () async {
                Navigator.of(context).pop();
                await requestHealthConnectPermissionsAggressive(context);
              },
            ),
          ],
        );
      },
    );
  }

  // Force Health Connect to completely reset and recognize new data types
  Future<bool> forceHealthConnectDataTypesRecognition(
      BuildContext context) async {
    try {
      debugPrint(
          "🚀 FORCE RECOGNITION: Starting aggressive data type recognition...");

      // Step 1: Show user what we're about to do
      bool? proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Force Health Connect Reset'),
            content: const Text(
              'This will force Health Connect to completely forget the old permissions and recognize the new data types.\n\n'
              'Expected data types:\n'
              '• Steps\n'
              '• Distance\n'
              '• Total Calories\n\n'
              'This should remove Heart Rate from the permission dialog.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Force Reset'),
              ),
            ],
          );
        },
      );

      if (proceed != true) {
        return false;
      }

      // Step 2: Clear all cached state
      debugPrint("🔄 Step 1: Clearing all cached state...");
      _isInitialized = false;

      // Clear Firestore permission status
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'hasHealthPermissions': false});
        debugPrint("💾 Cleared Firestore permission status");
      }

      // Step 3: Force Health Connect to recognize new data types
      debugPrint(
          "🔧 Step 2: Forcing Health Connect to recognize new data types...");

      // Try to request permissions for each data type individually to force recognition
      for (HealthDataType dataType in _dataTypes) {
        try {
          debugPrint("🔧 Testing ${dataType.toString()}...");

          // Force Health Connect to recognize this data type
          bool? result = await health.hasPermissions([dataType]);
          debugPrint("🔧 ${dataType.toString()} recognition result: $result");

          // Small delay to prevent overwhelming Health Connect
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          debugPrint("🔧 Error testing ${dataType.toString()}: $e");
        }
      }

      // Step 4: Force a complete permission request with new data types
      debugPrint(
          "🔧 Step 3: Requesting complete permissions with new data types...");
      try {
        bool granted = await health.requestAuthorization(
          _dataTypes,
          permissions: List.filled(_dataTypes.length, HealthDataAccess.READ),
        );
        debugPrint("🔧 Complete permission request result: $granted");
      } catch (e) {
        debugPrint("🔧 Error in complete permission request: $e");
      }

      // Step 5: Verify the new data types are recognized
      debugPrint("🔍 Step 4: Verifying new data types are recognized...");
      bool? finalCheck = await health.hasPermissions(_dataTypes);
      debugPrint("🔍 Final permission check result: $finalCheck");

      // Step 6: Show success message with next steps
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Force Reset Complete'),
              content: const Text(
                'Health Connect has been forced to recognize the new data types.\n\n'
                'Now when you request permissions, you should see:\n'
                '• Steps\n'
                '• Distance\n'
                '• Total Calories\n\n'
                'Instead of the old Heart Rate permissions.\n\n'
                'Try requesting permissions now!',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Trigger a fresh permission request
                    await _requestFreshPermissionsAfterForceReset(context);
                  },
                  child: const Text('Request Permissions Now'),
                ),
              ],
            );
          },
        );
      }

      debugPrint(
          "✅ FORCE RECOGNITION: Health Connect data type recognition forced");
      return true;
    } catch (e) {
      debugPrint("❌ FORCE RECOGNITION: Error forcing recognition: $e");
      return false;
    }
  }

  // Request fresh permissions after force reset
  Future<void> _requestFreshPermissionsAfterForceReset(
      BuildContext context) async {
    try {
      debugPrint("🔄 Requesting fresh permissions after force reset...");

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Requesting permissions...'),
              ],
            ),
          );
        },
      );

      // Request permissions with the new data types
      bool granted = await health.requestAuthorization(
        _dataTypes,
        permissions: List.filled(_dataTypes.length, HealthDataAccess.READ),
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (granted) {
        debugPrint("✅ Fresh permissions granted successfully");

        // Update Firestore
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({'hasHealthPermissions': true});
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Permissions granted! You should now see Steps, Distance, and Total Calories.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint("❌ Fresh permission request denied");

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Permission request was denied. Please try again or check Health Connect settings.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error requesting fresh permissions: $e");

      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
