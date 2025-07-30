import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:health/health.dart';
import 'health_dashboard.dart'; // Import the health dashboard screen
import 'login_screen.dart';
import 'services/health_service.dart';
import 'services/character_service.dart';
import 'services/character_migration_service.dart';
import 'services/leaderboard_migration_service.dart';
import 'services/duo_challenge_service.dart';
import 'services/coin_service.dart';
import 'widgets/daily_challenge_spin.dart';
import 'widgets/reward_notification_widget.dart';
import 'challenges_screen.dart';
import 'notification_page.dart';

import 'profile_page.dart';
import 'settings_page.dart';
import 'friends_page.dart';
import 'chat_list_page.dart';
import 'leaderboard_page.dart';
import 'shop_screen.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'solo_mode.dart';
import 'main.dart';
import 'screens/duo_challenge_lobby.dart';
import 'dart:async';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  final HealthService _healthService = HealthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CoinService _coinService = CoinService();
  int _steps = 0;
  double _calories = 0.0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _userName = 'User'; // Default name
  bool _isUserDataLoading = true; // Add loading state for user data
  int _coins = 0; // Will be loaded from coin service
  bool _isUsingRealData = false; // Track if using real health data
  DuoChallengeService? _duoChallengeService;
  StreamSubscription<QuerySnapshot>? _acceptedInviteListener;
  StreamSubscription<QuerySnapshot>? _declinedInviteListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkHealthConnectPermissions(); // This should be called first
    _fetchHealthData();
    _startHealthDataRefresh();
    _startHybridStepMonitoring(); // Use hybrid monitoring instead
    _healthService
        .startContinuousStepUpdates(); // Start continuous Firestore updates
    _loadUserData();
    _startCharacterPreloading();
    _migrateCurrentUserCharacter();
    _initializeLeaderboardData();
    _initializeDuoChallengeService();
    _listenForAcceptedInvitesAsSender();
    _listenForDeclinedInvitesAsSender();
    _startCoinListener();
    _startRewardListener();
  }

  void _initializeDuoChallengeService() {
    try {
      // Check if navigatorKey is available
      if (navigatorKey.currentContext == null) {
        print('Navigator key not ready, delaying initialization');
        // Retry after a short delay
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _initializeDuoChallengeService();
          }
        });
        return;
      }

      // Initialize the duo challenge service with the global navigator key
      _duoChallengeService = DuoChallengeService(
        navigatorKey: navigatorKey,
      );

      // Start listening for invites
      _duoChallengeService?.startListeningForInvites();

      // Check for existing pending invites
      _duoChallengeService?.checkForExistingInvites();
    } catch (e) {
      print('Error initializing duo challenge service: $e');
      _duoChallengeService = null;
    }
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isUserDataLoading = true;
      });

      final user = _auth.currentUser;
      if (user != null) {
        print("Loading user data for: ${user.uid}");
        print("User email: ${user.email}");

        // Get user data from Firestore (username is stored here)
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final username = userData['username'] ?? '';
          print("Username from Firestore: $username");

          setState(() {
            _userName = username.isNotEmpty ? username : 'User';
            _isUserDataLoading = false;
          });

          // Load user coins
          final userCoins = await _coinService.getCurrentUserCoins();
          setState(() {
            _coins = userCoins;
          });
        } else {
          print("No user document found in Firestore");
          setState(() {
            _userName = 'User';
            _isUserDataLoading = false;
          });
        }
      } else {
        print("No user logged in");
        setState(() {
          _isUserDataLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isUserDataLoading = false;
      });
    }
  }

  Future<void> _fetchHealthData() async {
    if (!mounted) return;

    try {
      print("🏥 Starting full health data fetch...");

      // First check if we have Health Connect permissions
      bool hasPermissions =
          await _healthService.checkHealthConnectPermissions();
      print("🔐 Health Connect permissions status: $hasPermissions");

      if (!hasPermissions) {
        print("❌ No Health Connect permissions, requesting permissions...");
        // Request permissions if not granted
        bool granted = await _healthService.requestHealthConnectPermissions();
        if (!granted) {
          print("❌ Health Connect permissions not granted");
          if (!mounted) return;
          setState(() {
            _steps = 0;

            _calories = 0.0;
            _isUsingRealData = false;
          });
          return;
        }
      }

      print("📊 Fetching real health data from Health Connect...");

      // Fetch hybrid real-time steps for immediate feedback + accuracy
      final stepsCount = await _healthService.fetchHybridRealTimeSteps();

      // Fetch total calories data (returns Map)
      final caloriesData = await _healthService.fetchCaloriesData();
      final calories =
          (caloriesData['energy']['totalKilocalories'] as num).toDouble();

      // Check if data source is Health Connect
      bool hasRealStepsData = hasPermissions;
      final caloriesSource =
          caloriesData['metadata']['device']['manufacturer'] as String;

      print(
          "🏥 Steps data source: ${hasRealStepsData ? 'Health Connect' : 'No Data'}");
      print("🔥 Calories data source: $caloriesSource");

      // Determine if we're using real Health Connect data
      bool isRealData = hasRealStepsData && caloriesSource == "Health Connect";

      print("✅ Is real Health Connect data: $isRealData");
      print("📈 Steps count: $stepsCount");
      print("🔥 Calories: $calories kcal");

      if (!mounted) return;

      setState(() {
        _steps = stepsCount;
        _calories = calories;
        _isUsingRealData = isRealData;
      });

      print(
          "✅ Updated UI with health data: Steps: $_steps, Calories: $_calories");

      if (!isRealData) {
        print(
            "⚠️ No real health data available (Health Connect not available or no permissions)");
      }
    } catch (e) {
      print("❌ Error fetching health data: $e");
      if (!mounted) return;
      setState(() {
        _isUsingRealData = false;
      });
    }
  }

  // Add user feedback methods
  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showWarningMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showInfoMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Show sync help dialog
  void _showSyncHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Steps Sync Help'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'If your steps aren\'t updating automatically:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Open Google Fit app'),
              Text('2. Wait for it to sync your data'),
              Text('3. Return to Walkzilla'),
              Text('4. Tap the sync button (🔄)'),
              SizedBox(height: 8),
              Text(
                'This happens because Health Connect waits for fitness apps to sync before sharing data.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  void _startHealthDataRefresh() {
    // More frequent updates for steps - every 30 seconds for real-time feel
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _fetchStepsData(); // Check steps every 30 seconds
      } else {
        timer.cancel();
      }
    });

    // Full health data every 3 minutes (reduced from 5 minutes)
    Timer.periodic(const Duration(minutes: 3), (timer) {
      if (mounted) {
        _fetchHealthData(); // Full health data less frequently
      } else {
        timer.cancel();
      }
    });
  }

  // Start real-time step monitoring
  void _startRealTimeStepMonitoring() {
    try {
      print("🔄 Starting real-time step monitoring...");

      // Set up step update callback
      _healthService.setStepUpdateCallback((totalSteps, stepIncrease) {
        if (mounted) {
          setState(() {
            _steps = totalSteps;
            _isUsingRealData = true;
          });

          // Show step increase animation/notification
          if (stepIncrease > 0) {
            _showStepIncreaseNotification(stepIncrease);
          }

          print(
              "🎉 Real-time step update: +$stepIncrease steps (Total: $totalSteps)");
        }
      });

      // Start the aggressive sync monitoring (more effective for Google Fit sync issues)
      _healthService.startAggressiveSyncMonitoring();
    } catch (e) {
      print("❌ Error starting real-time step monitoring: $e");
    }
  }

  // Start hybrid step monitoring (combines Health Connect and real-time sensor)
  void _startHybridStepMonitoring() {
    try {
      print("🚀 Starting hybrid step monitoring...");

      // Initialize hybrid tracking system
      _healthService.initializeHybridTracking().then((initialized) {
        if (initialized) {
          // Start hybrid monitoring
          _healthService.startHybridMonitoring();

          // Set up step update callback for both systems
          _healthService.setStepUpdateCallback((totalSteps, stepIncrease) {
            if (mounted) {
              setState(() {
                _steps = totalSteps;
                _isUsingRealData = true;
              });

              // Show step increase animation/notification
              if (stepIncrease > 0) {
                _showStepIncreaseNotification(stepIncrease);
              }

              print(
                  "🎉 Hybrid step update: +$stepIncrease steps (Total: $totalSteps)");
            }
          });
        } else {
          print(
              "❌ Hybrid tracking initialization failed, falling back to Health Connect only");
          _startRealTimeStepMonitoring();
        }
      });
    } catch (e) {
      print("❌ Error starting hybrid step monitoring: $e");
      // Fallback to original method
      _startRealTimeStepMonitoring();
    }
  }

  // Show step increase notification
  void _showStepIncreaseNotification(int stepIncrease) {
    if (mounted) {
      // Show a subtle notification for step increases
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+$stepIncrease steps! 🚶‍♂️'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
        ),
      );
    }
  }

  Future<void> _fetchStepsData() async {
    if (!mounted) return;

    try {
      print("🔄 Fetching steps data...");

      // Check Health Connect permissions
      bool hasPermissions =
          await _healthService.checkHealthConnectPermissions();

      if (!hasPermissions) {
        print("❌ No Health Connect permissions for steps");
        setState(() {
          _steps = 0;
          _isUsingRealData = false;
        });
        return;
      }

      // Fetch Google Fit sync steps data to ensure accuracy
      int stepsCount = await _healthService.fetchHybridRealTimeSteps();
      print("📱 GOOGLE FIT SYNC: Steps synced with Google Fit: $stepsCount");

      if (mounted) {
        setState(() {
          _steps = stepsCount;
          _isUsingRealData = true;
        });
        print("✅ Updated UI with steps: $_steps");
      }
    } catch (e) {
      print("❌ Error fetching steps data: $e");
      if (mounted) {
        setState(() {
          _steps = 0;
          _isUsingRealData = false;
        });
      }
    }
  }

  // Force sync steps from Google Fit/Health Connect
  Future<void> _forceSyncSteps() async {
    if (!mounted) return;

    try {
      print("🔄 Force syncing steps...");

      // Show a message to the user
      _showInfoMessage("Syncing steps from Google Fit...");

      // Use the enhanced force refresh method with multiple strategies
      final newSteps =
          await _healthService.forceRefreshWithMultipleStrategies();

      if (mounted) {
        setState(() {
          _steps = newSteps;
          _isUsingRealData = false;
        });

        // Show success message
        _showSuccessMessage("Steps synced successfully!");
      }
    } catch (e) {
      print("❌ Error force syncing steps: $e");
      _showWarningMessage(
          "Failed to sync steps. Try opening Google Fit first.");
    }
  }

  // Add a method to handle Health Connect permission rationale
  Future<void> _handlePermissionRationale() async {
    try {
      print("📋 Showing permission rationale...");

      bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Health Connect Permissions'),
            content: const Text(
              'Walkzilla needs access to your health data to provide personalized fitness tracking and insights.\n\n'
              'We request access to:\n'
              '• Steps - To track your daily activity\n'
              '• Active calories - To track calories burned during activities\n'
              '• Distance - To track your walking/running distance\n\n'
              'Your data is stored securely and is only used to provide you with better fitness insights.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Not Now'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              ElevatedButton(
                child: const Text('Allow Access'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      );

      if (result == true) {
        print("✅ User accepted permission rationale");
        // Proceed with permission request
        await _requestPermissionsManually();
      } else {
        print("❌ User declined permission rationale");
      }
    } catch (e) {
      print("❌ Error showing permission rationale: $e");
    }
  }

  // Update the permission check method to handle rationale
  Future<void> _checkHealthConnectPermissions() async {
    try {
      print("🔐 Checking Health Connect permissions on startup...");

      // First check if Health Connect is available
      bool isAvailable = await _checkHealthConnectAvailability();
      if (!isAvailable) {
        print("❌ Health Connect not available");
        _showWarningMessage(
            "Health Connect is not available. Please install it from the Play Store.");
        return;
      }

      // Force refresh permissions to ensure we have the latest status
      bool hasPermissions = await _healthService.forceRefreshPermissions();

      if (!hasPermissions) {
        print("❌ No Health Connect permissions, showing rationale...");

        // Show permission rationale first
        await _handlePermissionRationale();
      } else {
        print("✅ Health Connect permissions already granted");
      }
    } catch (e) {
      print("❌ Error checking Health Connect permissions: $e");
    }
  }

  // Add a dialog to explain why permissions are needed
  // Removed unused method _showPermissionExplanationDialog

  // Add a method to manually request permissions
  Future<void> _requestPermissionsManually() async {
    print("🔐 Manual permission request triggered");

    try {
      // First check if Health Connect is available
      bool? isAvailable = await _healthService.health.hasPermissions([
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ]);

      if (isAvailable == null) {
        print("❌ Health Connect not available on this device");
        _showWarningMessage(
            "Health Connect is not available on this device. Please install it from the Play Store.");
        return;
      }

      print(
          "✅ Health Connect is available, proceeding with permission request");

      // Request permissions
      bool granted = await _healthService.requestHealthConnectPermissions();

      if (granted) {
        print("✅ Manual permission request successful");
        _showSuccessMessage("Health Connect access granted!");
        // Refresh steps data immediately
        await _fetchStepsData();
      } else {
        print("❌ Manual permission request failed");
        _showWarningMessage(
            "Health Connect access denied. You can grant permissions manually in device settings.");
      }
    } catch (e) {
      print("❌ Error in manual permission request: $e");
      _showWarningMessage("Error requesting permissions. Please try again.");
    }
  }

  // Removed unused methods _showStepUpdateIndicator and _manualRefreshSteps

  // Add a direct permission request method
  Future<void> _directPermissionRequest() async {
    try {
      print("🎯 === DIRECT PERMISSION REQUEST ===");

      // Show a clear dialog to the user
      bool? userWantsPermissions = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Health Connect Access Required'),
          content: const Text(
            'Walkzilla needs access to your health data to track your steps and provide fitness insights.\n\n'
            'When the Health Connect dialog appears, please tap "Allow" for:\n'
            '• Steps\n'
            '• Active calories burned\n'
            '• Distance\n\n'
            'This will enable real-time tracking of your active calories.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Grant Access'),
            ),
          ],
        ),
      );

      if (userWantsPermissions != true) {
        print("❌ User declined permission request");
        return;
      }

      print("✅ User accepted, requesting Health Connect permissions...");

      // Direct permission request
      bool granted = await _healthService.health.requestAuthorization([
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ]);

      print("🎯 Direct permission request result: $granted");

      if (granted) {
        print("✅ Direct permission request successful!");

        // Wait a moment and verify
        await Future.delayed(const Duration(seconds: 2));

        bool? verified = await _healthService.health.hasPermissions([
          HealthDataType.STEPS,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.DISTANCE_DELTA,
        ]);

        print("🎯 Verification after direct request: $verified");

        if (verified == true) {
          _showSuccessMessage(
              "Health Connect access granted! Refreshing data...");

          // Update Firestore
          final user = _auth.currentUser;
          if (user != null) {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .update({'hasHealthPermissions': true});
          }

          // Refresh data
          await _fetchHealthData();
        } else {
          _showWarningMessage(
              "Permissions not verified. Please check Health Connect settings.");
        }
      } else {
        print("❌ Direct permission request failed");
        _showWarningMessage(
            "Permission request failed. Please check Health Connect settings.");
      }

      print("🎯 === END DIRECT PERMISSION REQUEST ===");
    } catch (e) {
      print("❌ Error in direct permission request: $e");
      _showWarningMessage("Error requesting permissions: $e");
    }
  }

  // Add a method to manually verify permissions and refresh data
  Future<void> _verifyAndRefreshPermissions() async {
    try {
      print("🔄 === VERIFY AND REFRESH PERMISSIONS ===");

      // Manually verify permissions
      bool hasPermissions = await _healthService.manuallyVerifyPermissions();

      if (hasPermissions) {
        print("✅ Permissions verified, refreshing data...");
        _showSuccessMessage(
            "Health Connect permissions verified! Refreshing data...");

        // Refresh all health data
        await _fetchHealthData();

        // Also refresh steps data specifically
        await _fetchStepsData();

        print("✅ Data refresh complete");
      } else {
        print("❌ Permissions not verified");
        _showWarningMessage(
            "Health Connect permissions not found. Please check device settings.");
      }

      print("🔄 === END VERIFY AND REFRESH ===");
    } catch (e) {
      print("❌ Error in verify and refresh: $e");
      _showWarningMessage("Error verifying permissions: $e");
    }
  }

  // Update the steps display to include verify and refresh option
  Widget _buildStepsDisplay(Size screenSize) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Steps display (left side)
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: _verifyAndRefreshPermissions, // Tap to verify and refresh
              onLongPress:
                  _directPermissionRequest, // Long press for direct permission request
              onDoubleTap: _debugHealthConnectStatus, // Double tap for debug
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$_steps',
                        style: TextStyle(
                          color: const Color(0xFF2D2D2D),
                          fontSize: screenSize.width * 0.045,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Steps',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: screenSize.width * 0.025,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.refresh,
                          size: screenSize.width * 0.02,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                    // Add sync status indicator
                    Text(
                      _isUsingRealData ? 'Real Data' : 'No Data',
                      style: TextStyle(
                        color: _isUsingRealData ? Colors.green : Colors.grey,
                        fontSize: screenSize.width * 0.01,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Refresh button (right side)
          Container(
            width: 40,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(15.0),
                bottomRight: Radius.circular(15.0),
              ),
            ),
            child: GestureDetector(
              onTap: _forceSyncSteps,
              onLongPress: _showSyncHelpDialog,
              child: IconButton(
                icon: Icon(
                  Icons.sync,
                  size: 20,
                  color: Colors.blue[600],
                ),
                onPressed: null, // Handled by GestureDetector
                tooltip: 'Tap: Sync steps • Long press: Help',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startCoinListener() {
    // Listen to coin balance changes in real-time
    _coinService.getCurrentUserCoinsStream().listen((coins) {
      if (mounted) {
        setState(() {
          _coins = coins;
        });
      }
    });
  }

  void _startRewardListener() {
    // Listen for weekly reward notifications
    _firestore
        .collection('leaderboard_history')
        .where('type', isEqualTo: 'weekly')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty && mounted) {
        final latestWeeklyReward = snapshot.docs.first;
        final rewardData = latestWeeklyReward.data();
        final winners = rewardData['winners'] as List<dynamic>? ?? [];
        final currentUserId = _auth.currentUser?.uid;
        final date = rewardData['date'] as String;

        // Check if current user is in the winners list
        for (final winner in winners) {
          if (winner['userId'] == currentUserId) {
            final rank = winner['rank'] as int;
            final steps = winner['steps'] as int;
            final reward = winner['reward'] as int;

            // Check if this reward has already been shown to the user
            final userDoc =
                await _firestore.collection('users').doc(currentUserId).get();
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              final shownRewards =
                  userData['shown_rewards'] as Map<String, dynamic>? ?? {};
              final rewardKey = 'weekly_$date';

              // Only show notification if it hasn't been shown before
              if (!shownRewards.containsKey(rewardKey)) {
                // Check health permissions before showing notification
                bool hasHealthPermissions =
                    await _healthService.checkHealthConnectPermissions();
                if (hasHealthPermissions) {
                  // Show notification for weekly reward
                  _showWeeklyRewardNotification(rank, steps, reward, date);
                }
              }
            }
            break;
          }
        }
      }
    });

    // Listen for leaderboard history to show daily reward notifications
    _firestore
        .collection('leaderboard_history')
        .where('type', isEqualTo: 'daily')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty && mounted) {
        final latestDailyReward = snapshot.docs.first;
        final rewardData = latestDailyReward.data();
        final winners = rewardData['winners'] as List<dynamic>? ?? [];
        final currentUserId = _auth.currentUser?.uid;
        final date = rewardData['date'] as String;

        // Check if current user is in the winners list
        for (final winner in winners) {
          if (winner['userId'] == currentUserId) {
            final rank = winner['rank'] as int;
            final steps = winner['steps'] as int;
            final reward = winner['reward'] as int;

            // Check if this reward has already been shown to the user
            final userDoc =
                await _firestore.collection('users').doc(currentUserId).get();
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              final shownRewards =
                  userData['shown_rewards'] as Map<String, dynamic>? ?? {};
              final rewardKey = 'daily_$date';

              // Only show notification if it hasn't been shown before
              if (!shownRewards.containsKey(rewardKey)) {
                // Check health permissions before showing notification
                bool hasHealthPermissions =
                    await _healthService.checkHealthConnectPermissions();
                if (hasHealthPermissions) {
                  // Show notification for daily reward
                  _showDailyRewardNotification(rank, steps, reward, date);
                }
              }
            }
            break;
          }
        }
      }
    });
  }

  void _showDailyRewardNotification(
      int rank, int steps, int reward, String date) async {
    final rankText = rank == 1
        ? '1st'
        : rank == 2
            ? '2nd'
            : '3rd';

    // Update the user's coin balance
    await _coinService.addCoins(reward);

    // Mark this reward as shown to prevent showing it again
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId != null) {
      final rewardKey = 'daily_$date';
      await _firestore.collection('users').doc(currentUserId).update({
        'shown_rewards.$rewardKey': {
          'shown_at': FieldValue.serverTimestamp(),
          'rank': rank,
          'steps': steps,
          'reward': reward,
          'date': date,
        },
      });
    }

    showRewardNotification(
      context: context,
      title: 'Daily Winner! 🏆',
      message:
          'Congratulations! You finished $rankText with $steps steps and earned $reward coins!',
      coins: reward,
      rank: rank,
      period: 'daily',
    );
  }

  void _showWeeklyRewardNotification(
      int rank, int steps, int reward, String date) async {
    final rankText = rank == 1
        ? '1st'
        : rank == 2
            ? '2nd'
            : '3rd';

    // Update the user's coin balance
    await _coinService.addCoins(reward);

    // Mark this reward as shown to prevent showing it again
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId != null) {
      final rewardKey = 'weekly_$date';
      await _firestore.collection('users').doc(currentUserId).update({
        'shown_rewards.$rewardKey': {
          'shown_at': FieldValue.serverTimestamp(),
          'rank': rank,
          'steps': steps,
          'reward': reward,
          'date': date,
        },
      });
    }

    showRewardNotification(
      context: context,
      title: 'Weekly Winner! 🏆',
      message:
          'Congratulations! You finished $rankText this week with $steps steps and earned $reward coins!',
      coins: reward,
      rank: rank,
      period: 'weekly',
    );
  }

  /// Handle FCM notifications for rewards
  void _handleRewardNotification(Map<String, dynamic> data) {
    try {
      final type = data['type'];
      final rank = int.tryParse(data['rank'] ?? '0') ?? 0;
      final coins = int.tryParse(data['coins'] ?? '0') ?? 0;

      if (type == 'daily_reward') {
        final rankText = rank == 1
            ? '1st'
            : rank == 2
                ? '2nd'
                : '3rd';
        showRewardNotification(
          context: context,
          title: 'Daily Winner! 🏆',
          message: '$rankText Place - $coins coins earned!',
          coins: coins,
          rank: rank,
          period: 'daily',
        );
      } else if (type == 'weekly_reward') {
        final rankText = rank == 1
            ? '1st'
            : rank == 2
                ? '2nd'
                : '3rd';
        showRewardNotification(
          context: context,
          title: 'Weekly Winner! 🏆',
          message: '$rankText Place - $coins coins earned!',
          coins: coins,
          rank: rank,
          period: 'weekly',
        );
      }
    } catch (e) {
      print('Error handling reward notification: $e');
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;

      // Clear the navigation stack and go to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  /// Start preloading character animations in the background
  void _startCharacterPreloading() {
    // Start preloading animations in the background
    CharacterService().preloadCurrentUserAnimations().catchError((error) {
      print('Failed to preload character animations: $error');
    });
  }

  /// Migrate current user's character data if needed
  void _migrateCurrentUserCharacter() {
    CharacterMigrationService().migrateCurrentUser().catchError((error) {
      print('Failed to migrate character data: $error');
    });
  }

  void _initializeLeaderboardData() {
    LeaderboardMigrationService()
        .initializeUserLeaderboardData(_auth.currentUser?.uid ?? '')
        .catchError((error) {
      print('Failed to initialize leaderboard data: $error');
    });
  }

  void _listenForAcceptedInvitesAsSender() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    _acceptedInviteListener?.cancel();
    _acceptedInviteListener = FirebaseFirestore.instance
        .collection('duo_challenge_invites')
        .where('fromUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'accepted')
        .where('senderNotified', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final toUserId = data['toUserId'];
        // Fetch the username of the invitee
        String inviteeName = 'Your friend';
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(toUserId)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            inviteeName = userData?['displayName'] ??
                userData?['username'] ??
                inviteeName;
          }
        } catch (_) {}
        if (navigatorKey.currentContext != null) {
          showDialog(
            context: navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Duo Challenge Accepted'),
              content: Text('$inviteeName accepted the duo challenge request!'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    doc.reference.update({'senderNotified': true});
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    doc.reference.update({'senderNotified': true});
                    Navigator.of(navigatorKey.currentContext!).push(
                      MaterialPageRoute(
                        builder: (context) => DuoChallengeLobby(
                          inviteId: doc.id,
                          otherUsername: inviteeName,
                        ),
                      ),
                    );
                  },
                  child: const Text('Start the Game'),
                ),
              ],
            ),
          );
        }
      }
    });
  }

  void _listenForDeclinedInvitesAsSender() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    _declinedInviteListener?.cancel();
    _declinedInviteListener = FirebaseFirestore.instance
        .collection('duo_challenge_invites')
        .where('fromUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'declined')
        .where('senderNotified', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final toUserId = data['toUserId'];
        // Fetch the username of the invitee
        String inviteeName = 'Your friend';
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(toUserId)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            inviteeName = userData?['displayName'] ??
                userData?['username'] ??
                inviteeName;
          }
        } catch (_) {}
        if (navigatorKey.currentContext != null) {
          showDialog(
            context: navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Duo Challenge Declined'),
              content: Text('$inviteeName declined your invitation.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    doc.reference.update({'senderNotified': true});
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _acceptedInviteListener?.cancel();
    _declinedInviteListener?.cancel();
    _duoChallengeService?.stopListeningForInvites();
    _healthService.stopRealTimeStepMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print("🔄 App resumed - refreshing step data");
        _healthService.forceRefreshStepCount().then((newSteps) {
          if (mounted) {
            setState(() {
              _steps = newSteps;
              _isUsingRealData = false;
            });
          }
        });
        break;
      case AppLifecycleState.paused:
        print("⏸️ App paused - continuing background monitoring");
        break;
      case AppLifecycleState.detached:
        print("🔌 App detached - stopping monitoring");
        _healthService.stopRealTimeStepMonitoring();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    // Removed unused variable buttonSpacing

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black, size: 30),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          elevation: 0,
          actions: [
            Padding(
              padding:
                  const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
              child: _buildCoinDisplay(),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            print("🔄 Pull-to-refresh triggered");
            await _fetchStepsData();
            await _fetchHealthData();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background circles
              Positioned(
                top: -screenSize.height * 0.1,
                right: -screenSize.width * 0.1,
                child: Container(
                  width: screenSize.width * 0.4,
                  height: screenSize.width * 0.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue[100]?.withValues(alpha: 0.3),
                  ),
                ),
              ),
              Positioned(
                bottom: -screenSize.height * 0.1,
                left: -screenSize.width * 0.1,
                child: Container(
                  width: screenSize.width * 0.5,
                  height: screenSize.width * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange[100]?.withValues(alpha: 0.3),
                  ),
                ),
              ),
              // Main content wrapped in SingleChildScrollView for RefreshIndicator
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: screenSize.height - 100, // Adjust for AppBar
                  child: Column(
                    children: [
                      // Top row with Steps, Events, and Challenges
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: screenSize.height * 0.02,
                          horizontal: screenSize.width * 0.05,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Daily Challenges Button
                            Expanded(
                              child: _buildTopButton(
                                icon: Icons.emoji_events,
                                label: 'Daily\nChallenges',
                                color: Colors.orange,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const DailyChallengeSpin()),
                                  );
                                },
                                screenSize: screenSize,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Steps counter (updated)
                            Expanded(
                              flex: 2,
                              child: _buildStepsDisplay(screenSize),
                            ),
                            const SizedBox(width: 8),
                            // Shop Button
                            Expanded(
                              child: _buildTopButton(
                                icon: Icons.shopping_bag,
                                label: 'Shop',
                                color: Colors.purple,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const ShopScreen()),
                                  );
                                },
                                screenSize: screenSize,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // 3D Character in the center
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background circle
                          Container(
                            width: screenSize.width * 0.8,
                            height: screenSize.width * 0.8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue[50],
                            ),
                          ),
                          // 3D ModelViewer widget - load once and stay stable
                          RepaintBoundary(
                            child: SizedBox(
                              height: screenSize.width * 0.9,
                              width: screenSize.width * 0.9,
                              child: AbsorbPointer(
                                child: const ModelViewer(
                                  src: 'assets/web/MyCharacter.glb',
                                  alt: "A 3D model of MyCharacter",
                                  autoRotate: false,
                                  cameraControls: false,
                                  backgroundColor: Colors.transparent,
                                  cameraOrbit: "0deg 75deg 100%",
                                  minCameraOrbit: "0deg 75deg 100%",
                                  maxCameraOrbit: "0deg 75deg 100%",
                                  interactionPrompt: InteractionPrompt.none,
                                  disableTap: true,
                                  autoPlay: true,
                                  disableZoom: true,
                                  disablePan: true,
                                  minFieldOfView: "45deg",
                                  maxFieldOfView: "45deg",
                                  fieldOfView: "45deg",
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Bottom navigation with three buttons
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: screenSize.height * 0.04,
                          left: screenSize.width * 0.05,
                          right: screenSize.width * 0.05,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Events Button (Moved from original position)
                            _buildCornerButton(
                              icon: Icons.directions_walk,
                              label: 'Solo Mode',
                              color: const Color(0xFF9C27B0), // Material Purple
                              onTap: () {
                                // Ensure animations are preloaded before navigating
                                CharacterService()
                                    .preloadCurrentUserAnimations();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const SoloMode()),
                                );
                              },
                            ),
                            _buildCornerButton(
                              icon: Icons.emoji_events,
                              label: 'Challenges',
                              color: Colors.blue,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ChallengesScreen()),
                                );
                              },
                            ),
                            // Health Button (Moved from original position)
                            _buildCornerButton(
                              icon: Icons.favorite,
                              label: 'Health',
                              color: Colors.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const HealthDashboard()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: Drawer(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(
                  top: 50,
                  bottom: 25,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange[400]!.withValues(alpha: 0.9),
                      Colors.orange[300]!.withValues(alpha: 0.9),
                    ],
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfilePage()),
                    ).then((_) {
                      // Add a small delay to ensure Firebase Auth update is complete
                      Future.delayed(const Duration(milliseconds: 500), () {
                        // Refresh user data when returning from profile page
                        _loadUserData();
                      });
                    });
                  },
                  onLongPress: () {
                    // Manual refresh on long press
                    _loadUserData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Refreshing user data...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.orange[300],
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _isUserDataLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    _userName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "Beginner",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildDrawerItem(
                icon: Icons.notifications_active_outlined,
                title: "Notifications",
                notificationCount: 2,
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationPage()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.alarm_outlined,
                title: "Reminders",
                color: Colors.purple,
                onTap: () {},
              ),
              _buildDrawerItem(
                icon: Icons.people_outlined,
                title: "Friends",
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FriendsPage()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.leaderboard,
                title: "Leaderboard",
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LeaderboardPage()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.chat_bubble_outline,
                title: "Chats",
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ChatListPage()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.settings_outlined,
                title: "Settings",
                color: Colors.grey[700],
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsPage()),
                  );
                },
              ),
              const Spacer(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  color: Colors.grey.withValues(alpha: 0.3),
                  thickness: 1,
                ),
              ),
              _buildDrawerItem(
                icon: Icons.logout_outlined,
                title: "Logout",
                color: Colors.red[400]!,
                onTap: _logout,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCornerButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 85,
        height: 85,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 10, // smaller font
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required Size screenSize,
  }) {
    return AspectRatio(
      aspectRatio: 1.1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: color,
                    size: screenSize.width * 0.05), // smaller icon
              ),
              const SizedBox(height: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontSize: screenSize.width * 0.025, // smaller font
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    double? iconSize,
    int? notificationCount,
  }) {
    final itemColor = color ?? Colors.grey[700]!;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: itemColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: itemColor,
              size: iconSize ?? 24,
            ),
          ),
          if (notificationCount != null && notificationCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  notificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: itemColor,
          fontSize: 14, // smaller font
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      hoverColor: itemColor.withValues(alpha: 0.05),
    );
  }

  Widget _buildCoinDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: const Color(0xFFF5E9B9), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Coin image
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/coin.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$_coins',
            style: const TextStyle(
              color: Color(0xFF222222),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // Add a comprehensive debug method to check Health Connect status
  Future<void> _debugHealthConnectStatus() async {
    try {
      print("🔍 === COMPREHENSIVE HEALTH CONNECT DEBUG ===");

      // 1. Check if Health Connect is available
      print("1️⃣ Checking Health Connect availability...");
      bool? isAvailable = await _healthService.health.hasPermissions([
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ]);
      print("   Health Connect available: ${isAvailable != null}");
      print("   Availability result: $isAvailable");

      // 2. Check current permissions
      print("2️⃣ Checking current permissions...");
      bool hasPermissions =
          await _healthService.checkHealthConnectPermissions();
      print("   Current permissions: $hasPermissions");

      // 3. Check Firestore status
      print("3️⃣ Checking Firestore status...");
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final hasHealthPerms = userDoc.data()?['hasHealthPermissions'] ?? false;
        print("   Firestore health permissions: $hasHealthPerms");
      } else {
        print("   No user logged in");
      }

      // 4. Test permission request
      print("4️⃣ Testing permission request...");
      if (!hasPermissions) {
        print("   Attempting permission request...");
        bool granted = await _healthService.requestHealthConnectPermissions();
        print("   Permission request result: $granted");

        // 5. Check permissions again after request
        print("5️⃣ Checking permissions after request...");
        bool? afterRequest = await _healthService.health.hasPermissions([
          HealthDataType.STEPS,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.DISTANCE_DELTA,
        ]);
        print("   Permissions after request: $afterRequest");
      }

      // 6. Check if we can fetch data
      print("6️⃣ Testing data fetch...");
      try {
        final stepsCount = await _healthService.fetchHybridRealTimeSteps();
        print("   Steps count: $stepsCount");
        print("   Steps data type: ${stepsCount.runtimeType}");
      } catch (e) {
        print("   Error fetching steps data: $e");
      }

      print("🔍 === END HEALTH CONNECT DEBUG ===");

      // Show summary to user
      String summary = "Health Connect Debug Complete\n";
      summary += "Available: ${isAvailable != null}\n";
      summary += "Permissions: $hasPermissions\n";
      summary += "User: ${user?.uid ?? 'Not logged in'}";

      _showDebugMessage(summary);
    } catch (e) {
      print("❌ Error in comprehensive debug: $e");
      _showDebugMessage("Debug Error: $e");
    }
  }

  // Add a method to show debug messages
  void _showDebugMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () {
              // You can add clipboard functionality here
              print("Debug message: $message");
            },
          ),
        ),
      );
    }
  }

  // Add a method to check Health Connect availability
  Future<bool> _checkHealthConnectAvailability() async {
    try {
      print("🔍 Checking Health Connect availability...");

      // Try to get permissions to check if Health Connect is available
      bool? isAvailable = await _healthService.health.hasPermissions([
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ]);

      print("🔍 Health Connect available: ${isAvailable != null}");

      if (isAvailable == null) {
        print("❌ Health Connect not available - needs to be installed");
        return false;
      }

      return true;
    } catch (e) {
      print("❌ Error checking Health Connect availability: $e");
      return false;
    }
  }
}
