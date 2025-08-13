import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/step_goal_provider.dart';
import 'providers/streak_provider.dart';

import 'package:health/health.dart';
import 'health_dashboard.dart'; // Import the health dashboard screen
import 'login_screen.dart';
import 'services/health_service.dart';
import 'services/character_service.dart';
import 'services/character_migration_service.dart';

import 'services/duo_challenge_service.dart';
import 'services/coin_service.dart';
import 'services/network_service.dart';
import 'services/zombie_run_service.dart';

import 'widgets/daily_challenge_spin.dart';
import 'widgets/reward_notification_widget.dart';

import 'challenges_screen.dart';
import 'notification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_page.dart';

import 'friends_page.dart';
import 'chat_list_page.dart';
import 'leaderboard_page.dart';
import 'streaks_screen.dart';
import 'shop_screen.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'solo_mode.dart';
import 'main.dart';
import 'screens/duo_challenge_lobby.dart';
import 'dart:async';
import 'services/fcm_notification_service.dart';
import 'services/user_login_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  final HealthService _healthService = HealthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CoinService _coinService = CoinService();
  final NetworkService _networkService = NetworkService();
  final UserLoginService _userLoginService = UserLoginService();

  int _steps = 0;
  double _calories = 0.0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _userName = 'User'; // Default name
  bool _isUserDataLoading = true; // Add loading state for user data
  int _coins = 0; // Will be loaded from coin service
  int _userLevel = 1; // User level for display
  bool _isUsingRealData = false; // Track if using real health data
  bool _isOnline = true; // Track network status
  String _currentGlbPath =
      'assets/web/home/MyCharacter_home.glb'; // Dynamic GLB path
  StreamSubscription<DocumentSnapshot>?
      _userDataListener; // Listen for user data changes
  DuoChallengeService? _duoChallengeService;
  ZombieRunService? _zombieRunService;
  StreamSubscription<QuerySnapshot>? _acceptedInviteListener;
  StreamSubscription<QuerySnapshot>? _declinedInviteListener;
  Timer? _connectionStatusTimer;
  bool _userDataListenerStarted = false; // Prevent multiple listeners
  String _lastProcessedGlbPath = ''; // Cache last processed GLB path
  Timer? _glbUpdateTimer; // Debounce GLB updates

  // Pending duo invites badge
  int _pendingDuoInviteCount = 0;
  StreamSubscription<QuerySnapshot>? _pendingInviteCountSub;

  // Leaderboard listeners
  StreamSubscription<QuerySnapshot>? _weeklyRewardListener;
  StreamSubscription<QuerySnapshot>? _dailyRewardListener;

  // Logout state
  bool _isLoggingOut = false;

  /// Validate if the GLB path is safe to use
  bool _isValidGlbPath(String path) {
    if (path.isEmpty) return false;
    if (!path.startsWith('assets/')) return false;
    if (!path.endsWith('.glb')) return false;

    // Check for common valid character paths
    final validPaths = [
      'assets/web/home/MyCharacter_home.glb',
      'assets/web/home/blossom_home.glb',
      'assets/web/home/sun_home.glb',
      'assets/web/home/cloud_home.glb',
      'assets/web/home/cool_home.glb',
      'assets/web/home/cow_home.glb',
      'assets/web/home/monster_home.glb',
      'assets/web/home/blueStar_home.glb',
      'assets/web/home/yellowstar_home.glb',
    ];

    return validPaths.contains(path);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Check if user is authenticated before initializing services
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('⚠️ No authenticated user, skipping initialization');
      return;
    }

    debugPrint('🚀 Initializing home screen for user: ${currentUser.uid}');

    // Add a small delay to prevent rapid initialization issues
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fetchHealthData();
        _startHealthDataRefresh();
        _startHybridStepMonitoring(); // Use hybrid monitoring instead
        _healthService
            .startContinuousStepUpdates(); // Start continuous Firestore updates
        _loadUserData();
        _startCharacterPreloading();
        _migrateCurrentUserCharacter();
        _initializeDuoChallengeService();
        _initializeZombieRunService();
        _listenPendingDuoInviteCount();
        _listenForAcceptedInvitesAsSender();
        _listenForDeclinedInvitesAsSender();
        _startCoinListener();
        _startRewardListener();
        _startConnectionStatusMonitoring();

        // Check for monthly goal after a delay to ensure providers are loaded
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _refreshProvidersAndCheckGoal();
          }
        });
      }
    });
  }

  /// Check if user is authenticated before performing Firebase operations
  bool _isUserAuthenticated() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ User not authenticated, skipping Firebase operation');
      return false;
    }
    return true;
  }

  // Goal checking methods
  Future<void> _refreshProvidersAndCheckGoal() async {
    try {
      final stepGoalProvider = context.read<StepGoalProvider>();
      final streakProvider = context.read<StreakProvider>();

      print("🔄 Home: Refreshing providers...");

      // Refresh both providers to ensure latest data
      await stepGoalProvider.refreshGoals();
      await streakProvider.reloadStreaks();

      print("✅ Home: Providers refreshed, checking goal...");
      _checkAndShowGoalDialog();
    } catch (e) {
      debugPrint('Error refreshing providers: $e');
    }
  }

  void _checkAndShowGoalDialog() {
    try {
      final stepGoalProvider = context.read<StepGoalProvider>();
      print("🔍 Home: Checking if must set goal...");

      if (stepGoalProvider.mustSetGoal()) {
        print("🔍 Home: Must set goal - showing dialog");
        _showMonthlyGoalDialog();
      } else {
        print("🔍 Home: No need to set goal");
      }
    } catch (e) {
      debugPrint('Error checking goal: $e');
    }
  }

  void _showMonthlyGoalDialog() {
    final stepGoalProvider = context.read<StepGoalProvider>();
    final now = DateTime.now();
    final hasCurrentGoal = stepGoalProvider.hasCurrentMonthGoal;
    int stepGoal = hasCurrentGoal ? stepGoalProvider.goalSteps : 10000;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, size: 22),
                          onPressed: () => Navigator.of(context).pop(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Set Your Daily Streak Goal!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set your daily step target to keep your streak alive!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month,
                              color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Setting goal for ${DateFormat('MMMM yyyy').format(now)}',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFF1F1F1), width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE0EDFF),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.star,
                                    color: Color(0xFF2563EB), size: 16),
                              ),
                              const SizedBox(width: 8),
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Text(
                                  'Daily Step Goal',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(32),
                                onTap: () {
                                  setState(() {
                                    if (stepGoal > 1000) stepGoal -= 1000;
                                  });
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF3F4F6),
                                  ),
                                  child: Icon(Icons.remove,
                                      size: 18, color: const Color(0xFF6B7280)),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${stepGoal.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} steps',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                      letterSpacing: 1.05,
                                    ),
                                  ),
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(32),
                                onTap: () {
                                  setState(() {
                                    stepGoal += 1000;
                                  });
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF3F4F6),
                                  ),
                                  child: Icon(Icons.add,
                                      size: 18, color: const Color(0xFF6B7280)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              try {
                                stepGoalProvider.setCurrentMonthGoal(stepGoal);
                                Navigator.of(context).pop();
                                // Goal set/updated successfully
                              } catch (e) {
                                // Error occurred while setting goal
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF111827),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              hasCurrentGoal ? 'Update Goal' : 'Save Goal',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Start monitoring connection status
  void _startConnectionStatusMonitoring() {
    _connectionStatusTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) {
      final isOnline = _networkService.isOnline;
      if (isOnline != _isOnline) {
        setState(() {
          _isOnline = isOnline;
        });

        if (isOnline) {
          debugPrint('✅ Connection restored - refreshing data');
          _refreshDataOnReconnection();
        } else {
          debugPrint('❌ Connection lost');
          _showConnectionWarning();
        }
      }
    });
  }

  /// Refresh data when connection is restored
  void _refreshDataOnReconnection() {
    _fetchHealthData();
    _loadUserData();
    _showSuccessMessage('Connection restored');
  }

  /// Show connection warning
  void _showConnectionWarning() {
    // SnackBar removed
  }

  void _initializeDuoChallengeService() {
    try {
      // Check if navigatorKey is available
      if (navigatorKey.currentContext == null) {
        debugPrint('Navigator key not ready, delaying initialization');
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
      debugPrint('Error initializing duo challenge service: $e');
      _duoChallengeService = null;
    }
  }

  void _initializeZombieRunService() {
    try {
      // Check if navigatorKey is available
      if (navigatorKey.currentContext == null) {
        debugPrint(
            'Navigator key not ready, delaying zombie run service initialization');
        // Retry after a short delay
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _initializeZombieRunService();
          }
        });
        return;
      }

      // Initialize the zombie run service with the global navigator key
      _zombieRunService = ZombieRunService(
        navigatorKey: navigatorKey,
      );

      // Initialize the service and set up FCM callback
      _zombieRunService?.initialize();

      // Start listening for invites
      _zombieRunService?.startListeningForInvites();

      // Check for existing pending invites
      _zombieRunService?.checkForExistingInvites();
    } catch (e) {
      debugPrint('Error initializing zombie run service: $e');
      _zombieRunService = null;
    }
  }

  /// Start listening for user data changes (including GLB path updates)
  void _startUserDataListener() {
    // Don't start listeners if logging out
    if (_isLoggingOut) {
      debugPrint('⚠️ Skipping user data listener setup - logging out');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    // Prevent multiple listeners
    if (_userDataListenerStarted) {
      debugPrint("🎯 User data listener already started, skipping...");
      return;
    }

    debugPrint("🎯 Starting user data listener for GLB path updates...");
    _userDataListener?.cancel();

    try {
      _userDataListener = _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        try {
          if (snapshot.exists && mounted) {
            final userData = snapshot.data()!;
            final homeGlbPath = userData['homeGlbPath'] ??
                'assets/web/home/MyCharacter_home.glb';

            // Only update if the GLB path has actually changed and is different from last processed
            if (homeGlbPath != _currentGlbPath &&
                homeGlbPath != _lastProcessedGlbPath) {
              debugPrint(
                  "🔄 GLB path update detected: $_currentGlbPath -> $homeGlbPath");

              // Cancel any pending update
              _glbUpdateTimer?.cancel();

              // Debounce the update to prevent rapid changes
              _glbUpdateTimer = Timer(const Duration(milliseconds: 500), () {
                if (mounted && homeGlbPath != _currentGlbPath) {
                  debugPrint("✅ Applying GLB path update: $homeGlbPath");
                  setState(() {
                    _currentGlbPath = homeGlbPath;
                    _lastProcessedGlbPath = homeGlbPath;
                    debugPrint("📁 State updated - new GLB path: $homeGlbPath");
                  });
                  debugPrint("✅ ModelViewer will now display: $homeGlbPath");
                }
              });
            }
          }
        } catch (e) {
          debugPrint("❌ Error in user data listener callback: $e");
        }
      }, onError: (error) {
        debugPrint("❌ Error in user data listener: $error");
        _userDataListenerStarted = false; // Reset flag on error
      });

      _userDataListenerStarted = true;
    } catch (e) {
      debugPrint("❌ Error setting up user data listener: $e");
      _userDataListenerStarted = false;
    }
  }

  Future<void> _loadUserData() async {
    try {
      // Check if user is authenticated before proceeding
      if (!_isUserAuthenticated()) {
        debugPrint('⚠️ Skipping user data load - user not authenticated');
        setState(() {
          _isUserDataLoading = false;
        });
        return;
      }

      setState(() {
        _isUserDataLoading = true;
      });

      final user = _auth.currentUser;
      if (user != null) {
        debugPrint("Loading user data for: ${user.uid}");
        debugPrint("User email: ${user.email}");

        // Get user data from Firestore (username is stored here)
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final username = userData['username'] ?? '';
          final homeGlbPath =
              userData['homeGlbPath'] ?? 'assets/web/home/MyCharacter_home.glb';
          final userLevel = userData['level'] ?? 1;
          debugPrint("Username from Firestore: $username");
          debugPrint("Home GLB path from Firestore: $homeGlbPath");
          debugPrint("User level from Firestore: $userLevel");

          setState(() {
            _userName = username.isNotEmpty ? username : 'User';
            _currentGlbPath = homeGlbPath;
            _lastProcessedGlbPath =
                homeGlbPath; // Initialize last processed path
            _userLevel = userLevel;
            _isUserDataLoading = false;
          });

          // Load user coins
          final userCoins = await _coinService.getCurrentUserCoins();
          setState(() {
            _coins = userCoins;
          });

          // Start listening for user data changes (including GLB path updates)
          _startUserDataListener();
        } else {
          debugPrint("No user document found in Firestore");
          setState(() {
            _userName = 'User';
            _currentGlbPath = 'assets/web/home/MyCharacter_home.glb';
            _lastProcessedGlbPath =
                'assets/web/home/MyCharacter_home.glb'; // Initialize last processed path
            _userLevel = 1;
            _isUserDataLoading = false;
          });
        }
      } else {
        debugPrint("No user logged in");
        setState(() {
          _isUserDataLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isUserDataLoading = false;
      });
    }
  }

  Future<void> _fetchHealthData() async {
    if (!mounted) return;

    try {
      debugPrint("🏥 Starting full health data fetch...");

      // First check if we have Health Connect permissions
      bool hasPermissions =
          await _healthService.checkHealthConnectPermissions();
      debugPrint("🔐 Health Connect permissions status: $hasPermissions");

      if (!hasPermissions) {
        debugPrint(
            "❌ No Health Connect permissions, requesting permissions...");
        // Request permissions if not granted
        bool granted = await _healthService.requestHealthConnectPermissions();
        if (!granted) {
          debugPrint("❌ Health Connect permissions not granted");
          if (!mounted) return;
          setState(() {
            _steps = 0;

            _calories = 0.0;
            _isUsingRealData = false;
          });
          return;
        }
      }

      debugPrint("📊 Fetching real health data from Health Connect...");

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

      debugPrint(
          "🏥 Steps data source: ${hasRealStepsData ? 'Health Connect' : 'No Data'}");
      debugPrint("🔥 Calories data source: $caloriesSource");

      // Determine if we're using real Health Connect data
      bool isRealData = hasRealStepsData && caloriesSource == "Health Connect";

      debugPrint("✅ Is real Health Connect data: $isRealData");
      debugPrint("📈 Steps count: $stepsCount");
      debugPrint("🔥 Calories: $calories kcal");

      if (!mounted) return;

      setState(() {
        _steps = stepsCount;
        _calories = calories;
        _isUsingRealData = isRealData;
      });

      debugPrint(
          "✅ Updated UI with health data: Steps: $_steps, Calories: $_calories");

      if (!isRealData) {
        debugPrint(
            "⚠️ No real health data available (Health Connect not available or no permissions)");
      }
    } catch (e) {
      debugPrint("❌ Error fetching health data: $e");
      if (!mounted) return;
      setState(() {
        _isUsingRealData = false;
      });
    }
  }

  // Add user feedback methods
  void _showSuccessMessage(String message) {
    // SnackBar removed
  }

  void _showWarningMessage(String message) {
    // SnackBar removed
  }

  void _showInfoMessage(String message) {
    // SnackBar removed
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

    // Step consistency check every 2 minutes
    Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        _healthService.testStepConsistency(); // Check for inconsistencies
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
      debugPrint("🔄 Starting real-time step monitoring...");

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

          debugPrint(
              "🎉 Real-time step update: +$stepIncrease steps (Total: $totalSteps)");
        }
      });

      // Start the aggressive sync monitoring (more effective for Google Fit sync issues)
      _healthService.startAggressiveSyncMonitoring();
    } catch (e) {
      debugPrint("❌ Error starting real-time step monitoring: $e");
    }
  }

  // Start hybrid step monitoring (combines Health Connect and real-time sensor)
  void _startHybridStepMonitoring() {
    try {
      debugPrint("🚀 Starting hybrid step monitoring...");

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

              debugPrint(
                  "🎉 Hybrid step update: +$stepIncrease steps (Total: $totalSteps)");
            }
          });
        } else {
          debugPrint(
              "❌ Hybrid tracking initialization failed, falling back to Health Connect only");
          _startRealTimeStepMonitoring();
        }
      });
    } catch (e) {
      debugPrint("❌ Error starting hybrid step monitoring: $e");
      // Fallback to original method
      _startRealTimeStepMonitoring();
    }
  }

  // Show step increase notification
  void _showStepIncreaseNotification(int stepIncrease) {
    // Step increase notification removed
  }

  Future<void> _fetchStepsData() async {
    if (!mounted) return;

    try {
      debugPrint("🔄 Fetching steps data...");

      // Check Health Connect permissions
      bool hasPermissions =
          await _healthService.checkHealthConnectPermissions();

      if (!hasPermissions) {
        debugPrint("❌ No Health Connect permissions for steps");
        setState(() {
          _steps = 0;
          _isUsingRealData = false;
        });
        return;
      }

      // Test step consistency first
      await _healthService.testStepConsistency();

      // Fetch Google Fit sync steps data to ensure accuracy
      int stepsCount = await _healthService.fetchHybridRealTimeSteps();
      debugPrint(
          "📱 GOOGLE FIT SYNC: Steps synced with Google Fit: $stepsCount");

      if (mounted) {
        setState(() {
          _steps = stepsCount;
          _isUsingRealData = true;
        });
        debugPrint("✅ Updated UI with steps: $_steps");
      }
    } catch (e) {
      debugPrint("❌ Error fetching steps data: $e");
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
      debugPrint("🔄 Force syncing steps...");

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
      debugPrint("❌ Error force syncing steps: $e");
      _showWarningMessage(
          "Failed to sync steps. Try opening Google Fit first.");
    }
  }

  // Add a method to handle Health Connect permission rationale
  Future<void> _handlePermissionRationale() async {
    try {
      debugPrint("📋 Showing permission rationale...");

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
        debugPrint("✅ User accepted permission rationale");
        // Proceed with permission request
        await _requestPermissionsManually();
      } else {
        debugPrint("❌ User declined permission rationale");
      }
    } catch (e) {
      debugPrint("❌ Error showing permission rationale: $e");
    }
  }

  // Update the permission check method to handle rationale
  Future<void> _checkHealthConnectPermissions() async {
    try {
      debugPrint("🔐 Checking Health Connect permissions on startup...");

      // First check if Health Connect is available
      bool isAvailable = await _checkHealthConnectAvailability();
      if (!isAvailable) {
        debugPrint("❌ Health Connect not available");
        _showWarningMessage(
            "Health Connect is not available. Please install it from the Play Store.");
        return;
      }

      // Force refresh permissions to ensure we have the latest status
      bool hasPermissions = await _healthService.forceRefreshPermissions();

      if (!hasPermissions) {
        debugPrint("❌ No Health Connect permissions, showing rationale...");

        // Show permission rationale first
        await _handlePermissionRationale();
      } else {
        debugPrint("✅ Health Connect permissions already granted");
      }
    } catch (e) {
      debugPrint("❌ Error checking Health Connect permissions: $e");
    }
  }

  // Add a dialog to explain why permissions are needed
  // Removed unused method _showPermissionExplanationDialog

  // Add a method to manually request permissions
  Future<void> _requestPermissionsManually() async {
    debugPrint("🔐 Manual permission request triggered");

    try {
      // First check if Health Connect is available
      bool? isAvailable = await _healthService.health.hasPermissions([
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ]);

      if (isAvailable == null) {
        debugPrint("❌ Health Connect not available on this device");
        _showWarningMessage(
            "Health Connect is not available on this device. Please install it from the Play Store.");
        return;
      }

      debugPrint(
          "✅ Health Connect is available, proceeding with permission request");

      // Request permissions
      bool granted = await _healthService.requestHealthConnectPermissions();

      if (granted) {
        debugPrint("✅ Manual permission request successful");
        _showSuccessMessage("Health Connect access granted!");
        // Refresh steps data immediately
        await _fetchStepsData();
      } else {
        debugPrint("❌ Manual permission request failed");
        _showWarningMessage(
            "Health Connect access denied. You can grant permissions manually in device settings.");
      }
    } catch (e) {
      debugPrint("❌ Error in manual permission request: $e");
      _showWarningMessage("Error requesting permissions. Please try again.");
    }
  }

  // Removed unused methods _showStepUpdateIndicator and _manualRefreshSteps

  // Add a direct permission request method
  Future<void> _directPermissionRequest() async {
    try {
      debugPrint("🎯 === DIRECT PERMISSION REQUEST ===");

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
        debugPrint("❌ User declined permission request");
        return;
      }

      debugPrint("✅ User accepted, requesting Health Connect permissions...");

      // Direct permission request
      bool granted = await _healthService.health.requestAuthorization([
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ]);

      debugPrint("🎯 Direct permission request result: $granted");

      if (granted) {
        debugPrint("✅ Direct permission request successful!");

        // Wait a moment and verify
        await Future.delayed(const Duration(seconds: 2));

        bool? verified = await _healthService.health.hasPermissions([
          HealthDataType.STEPS,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.DISTANCE_DELTA,
        ]);

        debugPrint("🎯 Verification after direct request: $verified");

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
        debugPrint("❌ Direct permission request failed");
        _showWarningMessage(
            "Permission request failed. Please check Health Connect settings.");
      }

      debugPrint("🎯 === END DIRECT PERMISSION REQUEST ===");
    } catch (e) {
      debugPrint("❌ Error in direct permission request: $e");
      _showWarningMessage("Error requesting permissions: $e");
    }
  }

  // Add a method to manually verify permissions and refresh data
  Future<void> _verifyAndRefreshPermissions() async {
    try {
      debugPrint("🔄 === VERIFY AND REFRESH PERMISSIONS ===");

      // Manually verify permissions
      bool hasPermissions = await _healthService.manuallyVerifyPermissions();

      if (hasPermissions) {
        debugPrint("✅ Permissions verified, refreshing data...");
        _showSuccessMessage(
            "Health Connect permissions verified! Refreshing data...");

        // Refresh all health data
        await _fetchHealthData();

        // Also refresh steps data specifically
        await _fetchStepsData();

        debugPrint("✅ Data refresh complete");
      } else {
        debugPrint("❌ Permissions not verified");
        _showWarningMessage(
            "Health Connect permissions not found. Please check device settings.");
      }

      debugPrint("🔄 === END VERIFY AND REFRESH ===");
    } catch (e) {
      debugPrint("❌ Error in verify and refresh: $e");
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
    // Don't start listeners if logging out
    if (_isLoggingOut) {
      debugPrint('⚠️ Skipping reward listener setup - logging out');
      return;
    }

    // Listen for weekly reward notifications
    _weeklyRewardListener = _firestore
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
    _dailyRewardListener = _firestore
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

  Future<void> _logout() async {
    try {
      // Show confirmation dialog
      final shouldLogout = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirm Logout'),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Yes, Logout'),
              ),
            ],
          );
        },
      );

      if (shouldLogout != true) return;

      debugPrint('🚪 Starting logout process...');

      // Set logout flag to prevent new operations
      setState(() {
        _isLoggingOut = true;
      });

      // Clean up resources before logout
      await _cleanupBeforeLogout();

      // Call UserLoginService logout cleanup
      try {
        await _userLoginService.onUserLogout();
        debugPrint('✅ UserLoginService logout cleanup completed');
      } catch (e) {
        debugPrint('⚠️ UserLoginService logout cleanup error: $e');
      }

      // Clear notifications token before sign out
      await FCMNotificationService.clearFCMTokenOnLogout();

      // Sign out from Firebase
      await _auth.signOut();
      debugPrint('✅ Firebase sign out completed');

      // The StreamBuilder in main.dart will automatically handle navigation
      // No need to manually navigate here
      debugPrint('✅ Logout completed successfully');
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      // Reset logout flag on error
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
        // Error signing out
      }
    }
  }

  Future<void> _cleanupBeforeLogout() async {
    try {
      debugPrint('🧹 Starting logout cleanup...');

      // Cancel all active listeners and timers with null checks
      try {
        if (_userDataListener != null) {
          _userDataListener!.cancel();
          _userDataListener = null;
          debugPrint('✅ User data listener cancelled');
        }
      } catch (e) {
        debugPrint('⚠️ Error cancelling user data listener: $e');
      }

      try {
        if (_acceptedInviteListener != null) {
          _acceptedInviteListener!.cancel();
          _acceptedInviteListener = null;
          debugPrint('✅ Accepted invite listener cancelled');
        }
      } catch (e) {
        debugPrint('⚠️ Error cancelling accepted invite listener: $e');
      }

      try {
        if (_declinedInviteListener != null) {
          _declinedInviteListener!.cancel();
          _declinedInviteListener = null;
          debugPrint('✅ Declined invite listener cancelled');
        }
      } catch (e) {
        debugPrint('⚠️ Error cancelling declined invite listener: $e');
      }

      try {
        if (_connectionStatusTimer != null) {
          _connectionStatusTimer!.cancel();
          _connectionStatusTimer = null;
          debugPrint('✅ Connection status timer cancelled');
        }
      } catch (e) {
        debugPrint('⚠️ Error cancelling connection status timer: $e');
      }

      try {
        if (_glbUpdateTimer != null) {
          _glbUpdateTimer!.cancel();
          _glbUpdateTimer = null;
          debugPrint('✅ GLB update timer cancelled');
        }
      } catch (e) {
        debugPrint('⚠️ Error cancelling GLB update timer: $e');
      }

      try {
        if (_weeklyRewardListener != null) {
          _weeklyRewardListener!.cancel();
          _weeklyRewardListener = null;
          debugPrint('✅ Weekly reward listener cancelled');
        }
      } catch (e) {
        debugPrint('⚠️ Error cancelling weekly reward listener: $e');
      }

      try {
        if (_dailyRewardListener != null) {
          _dailyRewardListener!.cancel();
          _dailyRewardListener = null;
          debugPrint('✅ Daily reward listener cancelled');
        }
      } catch (e) {
        debugPrint('⚠️ Error cancelling daily reward listener: $e');
      }

      // Stop health monitoring
      try {
        _healthService.stopAllMonitoring();
        debugPrint('✅ Health monitoring stopped');
      } catch (e) {
        debugPrint('⚠️ Error stopping health monitoring: $e');
      }

      // Clean up duo challenge service
      try {
        if (_duoChallengeService != null) {
          _duoChallengeService = null;
          debugPrint('✅ Duo challenge service cleaned');
        }
      } catch (e) {
        debugPrint('⚠️ Error cleaning duo challenge service: $e');
      }

      // Clear user ID from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_id');
        debugPrint('✅ User ID cleared');
      } catch (e) {
        debugPrint('⚠️ Error clearing user ID: $e');
      }

      // Clear any cached data and reset state
      if (mounted) {
        try {
          setState(() {
            _userName = 'User';
            _userLevel = 1;
            _coins = 0;
            _steps = 0;
            _calories = 0.0;
            _isUsingRealData = false;
            _isOnline = true;
            _currentGlbPath = 'assets/web/home/MyCharacter_home.glb';
            _lastProcessedGlbPath = '';
            _isUserDataLoading = false;
            _userDataListenerStarted = false;
            _isLoggingOut = false; // Reset logout flag
          });
          debugPrint('✅ State reset completed');
        } catch (e) {
          debugPrint('⚠️ Error resetting state: $e');
        }
      }

      // Force garbage collection if possible
      try {
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('⚠️ Error during cleanup delay: $e');
      }

      debugPrint('✅ Logout cleanup completed successfully');
    } catch (e) {
      debugPrint('❌ Error during logout cleanup: $e');
      // Don't rethrow - we want to continue with logout even if cleanup fails
    }
  }

  /// Start preloading character animations in the background
  void _startCharacterPreloading() {
    // Start preloading animations in the background
    CharacterService().preloadCurrentUserAnimations().catchError((error) {
      debugPrint('Failed to preload character animations: $error');
    });
  }

  /// Migrate current user's character data if needed
  void _migrateCurrentUserCharacter() {
    CharacterMigrationService()
        .migrateCurrentUserCharacterData()
        .catchError((error) {
      debugPrint('Failed to migrate character data: $error');
      return false;
    });
  }

  void _listenForAcceptedInvitesAsSender() {
    // Don't start listeners if logging out
    if (_isLoggingOut) {
      debugPrint('⚠️ Skipping accepted invite listener setup - logging out');
      return;
    }

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
    // Don't start listeners if logging out
    if (_isLoggingOut) {
      debugPrint('⚠️ Skipping declined invite listener setup - logging out');
      return;
    }

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
    _pendingInviteCountSub?.cancel();
    _userDataListener?.cancel();
    _glbUpdateTimer?.cancel(); // Cancel GLB update timer
    _weeklyRewardListener?.cancel(); // Cancel weekly reward listener
    _dailyRewardListener?.cancel(); // Cancel daily reward listener
    _duoChallengeService?.stopListeningForInvites();
    _zombieRunService?.stopListeningForInvites();
    _healthService.stopRealTimeStepMonitoring();
    _connectionStatusTimer?.cancel();

    // Clean up all listeners and subscriptions
    _acceptedInviteListener = null;
    _declinedInviteListener = null;
    _userDataListener = null;
    _glbUpdateTimer = null; // Clear GLB update timer
    _weeklyRewardListener = null; // Clear weekly reward listener
    _dailyRewardListener = null; // Clear daily reward listener
    _duoChallengeService = null;
    _zombieRunService = null;
    _userDataListenerStarted = false; // Reset listener flag

    debugPrint('🧹 Home screen disposed - all connections cleaned up');
    super.dispose();
  }

  /// Listen to count of pending duo challenge invites for current user
  void _listenPendingDuoInviteCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    _pendingInviteCountSub?.cancel();
    _pendingInviteCountSub = _firestore
        .collection('duo_challenge_invites')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      final count = snapshot.docs.length;
      if (mounted && count != _pendingDuoInviteCount) {
        setState(() {
          _pendingDuoInviteCount = count;
        });
      }
    }, onError: (e) {
      debugPrint('Error listening invite count: $e');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint("🔄 App resumed - refreshing step data");
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
        debugPrint("⏸️ App paused - continuing background monitoring");
        break;
      case AppLifecycleState.detached:
        debugPrint("🔌 App detached - stopping monitoring");
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
            debugPrint("🔄 Pull-to-refresh triggered");
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
                          // 3D ModelViewer widget - dynamically loads based on user's character
                          Builder(
                            builder: (context) {
                              // Only rebuild if the path has actually changed
                              if (_currentGlbPath == _lastProcessedGlbPath &&
                                  _currentGlbPath.isNotEmpty) {
                                debugPrint(
                                    "🎨 Using cached ModelViewer for path: $_currentGlbPath");
                              } else {
                                debugPrint(
                                    "🎨 Building new ModelViewer with path: $_currentGlbPath");
                              }

                              // Don't build ModelViewer if logging out
                              if (_isLoggingOut) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Logging out...',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return RepaintBoundary(
                                child: SizedBox(
                                  height: screenSize.width * 0.9,
                                  width: screenSize.width * 0.9,
                                  child: AbsorbPointer(
                                    child: _isValidGlbPath(_currentGlbPath)
                                        ? Builder(
                                            builder: (context) {
                                              try {
                                                return ModelViewer(
                                                  key: ValueKey(
                                                      _currentGlbPath), // Force rebuild when path changes
                                                  src: _currentGlbPath,
                                                  alt:
                                                      "A 3D model of the user's character",
                                                  autoRotate: false,
                                                  cameraControls: false,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  cameraOrbit:
                                                      "0deg 75deg 100%",
                                                  minCameraOrbit:
                                                      "0deg 75deg 100%",
                                                  maxCameraOrbit:
                                                      "0deg 75deg 100%",
                                                  interactionPrompt:
                                                      InteractionPrompt.none,
                                                  disableTap: true,
                                                  autoPlay: true,
                                                  disableZoom: true,
                                                  disablePan: true,
                                                  minFieldOfView: "45deg",
                                                  maxFieldOfView: "45deg",
                                                  fieldOfView: "45deg",
                                                );
                                              } catch (e) {
                                                debugPrint(
                                                    "❌ Error creating ModelViewer: $e");
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[200],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: const Center(
                                                    child: Text(
                                                      'Error loading character',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          )
                                        : Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                'Loading character...',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
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
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
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
                                if (_pendingDuoInviteCount > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 20,
                                        minHeight: 20,
                                      ),
                                      child: Text(
                                        _pendingDuoInviteCount.toString(),
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
                    // Refreshing user data
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
                              child: Text(
                                "Level $_userLevel",
                                style: const TextStyle(
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
                color: Colors.pink,
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
                icon: Icons.local_fire_department,
                title: "Streaks",
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const StreaksScreen()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.chat_bubble_outline,
                title: "Chats",
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ChatListPage()),
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
      debugPrint("🔍 === COMPREHENSIVE HEALTH CONNECT DEBUG ===");

      // 1. Check if Health Connect is available
      debugPrint("1️⃣ Checking Health Connect availability...");
      bool? isAvailable = await _healthService.health.hasPermissions([
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ]);
      debugPrint("   Health Connect available: ${isAvailable != null}");
      debugPrint("   Availability result: $isAvailable");

      // 2. Check current permissions
      debugPrint("2️⃣ Checking current permissions...");
      bool hasPermissions =
          await _healthService.checkHealthConnectPermissions();
      debugPrint("   Current permissions: $hasPermissions");

      // 3. Check Firestore status
      debugPrint("3️⃣ Checking Firestore status...");
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final hasHealthPerms = userDoc.data()?['hasHealthPermissions'] ?? false;
        debugPrint("   Firestore health permissions: $hasHealthPerms");
      } else {
        debugPrint("   No user logged in");
      }

      // 4. Test permission request
      debugPrint("4️⃣ Testing permission request...");
      if (!hasPermissions) {
        debugPrint("   Attempting permission request...");
        bool granted = await _healthService.requestHealthConnectPermissions();
        debugPrint("   Permission request result: $granted");

        // 5. Check permissions again after request
        debugPrint("5️⃣ Checking permissions after request...");
        bool? afterRequest = await _healthService.health.hasPermissions([
          HealthDataType.STEPS,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.DISTANCE_DELTA,
        ]);
        debugPrint("   Permissions after request: $afterRequest");
      }

      // 6. Check if we can fetch data
      debugPrint("6️⃣ Testing data fetch...");
      try {
        final stepsCount = await _healthService.fetchHybridRealTimeSteps();
        debugPrint("   Steps count: $stepsCount");
        debugPrint("   Steps data type: ${stepsCount.runtimeType}");
      } catch (e) {
        debugPrint("   Error fetching steps data: $e");
      }

      debugPrint("🔍 === END HEALTH CONNECT DEBUG ===");

      // Show summary to user
      String summary = "Health Connect Debug Complete\n";
      summary += "Available: ${isAvailable != null}\n";
      summary += "Permissions: $hasPermissions\n";
      summary += "User: ${user?.uid ?? 'Not logged in'}";

      _showDebugMessage(summary);
    } catch (e) {
      debugPrint("❌ Error in comprehensive debug: $e");
      _showDebugMessage("Debug Error: $e");
    }
  }

  // Add a method to show debug messages
  void _showDebugMessage(String message) {
    // Debug message display removed
  }

  // Add a method to check Health Connect availability
  Future<bool> _checkHealthConnectAvailability() async {
    try {
      debugPrint("🔍 Checking Health Connect availability...");

      // Try to get permissions to check if Health Connect is available
      bool? isAvailable = await _healthService.health.hasPermissions([
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ]);

      debugPrint("🔍 Health Connect available: ${isAvailable != null}");

      if (isAvailable == null) {
        debugPrint("❌ Health Connect not available - needs to be installed");
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("❌ Error checking Health Connect availability: $e");
      return false;
    }
  }
}
