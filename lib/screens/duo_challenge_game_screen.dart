import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
// Removed unused import
// Removed unused import
import 'package:flame/events.dart';
// Removed unused import
import '../services/character_animation_service.dart';
import '../services/health_service.dart';
import '../services/step_counter_service.dart';

class DuoChallengeGameScreen extends StatefulWidget {
  final String inviteId;
  final String? otherUsername;

  const DuoChallengeGameScreen({
    Key? key,
    required this.inviteId,
    this.otherUsername,
  }) : super(key: key);

  @override
  State<DuoChallengeGameScreen> createState() => _DuoChallengeGameScreenState();
}

class _DuoChallengeGameScreenState extends State<DuoChallengeGameScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final HealthService _healthService = HealthService();
  late String _userId;
  String? _winner;
  bool _gameEnded = false;
  bool _isLoadingCharacters = true;
  String? _otherPlayerId;

  // Step-based racing system variables
  double _userPosition = 200.0; // Start characters in visible area
  double _opponentPosition = 200.0; // Start characters in visible area
  bool _isUserWalking = false;
  bool _isOpponentWalking = false;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<DocumentSnapshot>? _gameStateSubscription;
  static const double trackWidth = 5000.0;
  static const double finishLinePosition = 5000.0;

  // Step tracking variables (similar to Solo Mode)
  int _steps = 0;
  int _previousSteps = 0;
  int _opponentSteps = 0;
  DateTime? _lastStepUpdate;
  bool _isInitialized = false;
  DateTime? _initializationTime;
  StreamSubscription<Map<String, dynamic>>? _stepSubscription;

  // Opponent state (no waiting - immediate display)
  bool _waitingForOpponent = false;

  // Callback functions to update character animations
  CharacterDisplayGame? _userGameInstance;
  CharacterDisplayGame? _opponentGameInstance;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser!.uid;

    // Set initialization time and start grace period
    _initializationTime = DateTime.now();
    print('🏁 DUO CHALLENGE: Initialization started at $_initializationTime');

    // Initialize with walking state as false
    _isUserWalking = false;

    _initializeGame();
    _preloadCharacters();
    _startGameStateListener();
    _initializeStepTracking();

    // Mark as initialized after 3 seconds to prevent false walking detection
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _isInitialized = true;
        print(
          '🏁 DUO CHALLENGE: Grace period ended, now accepting walking detection',
        );
      }
    });
  }

  @override
  void dispose() {
    _gameStateSubscription?.cancel();
    _stepSubscription?.cancel();
    _scrollController.dispose();
    _healthService.stopRealTimeStepMonitoring();
    super.dispose();
  }

  void _initializeGame() async {
    // Reset step counter to zero specifically for this challenge
    StepCounterService.resetCounter();
    print('🔄 DUO CHALLENGE: Step counter reset to zero for challenge start');

    // Check if this is the first player or second player joining
    final docSnapshot = await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .get();

    if (docSnapshot.exists && docSnapshot.data() != null) {
      final data = docSnapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        print('❌ DUO CHALLENGE: Document data is null in _initializeGame');
        return;
      }

      final positions =
          (data['positions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final gameStarted = data['gameStarted'] ?? false;

      // If game hasn't started yet, this is the first player
      if (!gameStarted) {
        print('🏁 DUO CHALLENGE: First player joining - initializing game');
        await _firestore
            .collection('duo_challenge_invites')
            .doc(widget.inviteId)
            .update({
          'gameStarted': true,
          'gameStartTime': FieldValue.serverTimestamp(),
          'positions.$_userId': 200.0, // Start in visible area
          'steps.$_userId': 0,
          'scores.$_userId': 0,
        });

        // For first player, create a placeholder opponent immediately
        setState(() {
          _otherPlayerId = 'waiting_for_opponent';
          _opponentPosition = 200.0;
          _opponentSteps = 0;
          _isOpponentWalking = false;
        });
        print('👥 DUO CHALLENGE: First player - created placeholder opponent');
      } else {
        // Game already started, this is the second player joining
        print(
          '🏁 DUO CHALLENGE: Second player joining - adding to existing game',
        );
        await _firestore
            .collection('duo_challenge_invites')
            .doc(widget.inviteId)
            .update({
          'positions.$_userId': 200.0, // Start in visible area
          'steps.$_userId': 0,
          'scores.$_userId': 0,
        });
      }
    }

    // Load existing game data to display both players immediately
    await _loadExistingGameData();

    // Ensure both players are visible immediately
    await _ensureBothPlayersVisible();

    // IMMEDIATE VISIBILITY: Force both characters to be visible right away
    if (mounted) {
      setState(() {
        // Ensure both characters are rendered immediately
        if (_otherPlayerId == null) {
          _otherPlayerId = 'waiting_for_opponent';
          _opponentPosition = 200.0;
          _opponentSteps = 0;
          _isOpponentWalking = false;
        }
      });
    }

    // Force immediate visibility check after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _forceImmediateVisibilityCheck();
      }
    });

    // Additional aggressive check after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _aggressiveVisibilityCheck();
      }
    });
  }

  Future<void> _loadExistingGameData() async {
    print('📊 DUO CHALLENGE: Loading existing game data...');

    final docSnapshot = await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .get();

    if (docSnapshot.exists && docSnapshot.data() != null) {
      final data = docSnapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        print(
          '❌ DUO CHALLENGE: Document data is null in _loadExistingGameData',
        );
        return;
      }

      final positions =
          (data['positions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final steps =
          (data['steps'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      print('📊 DUO CHALLENGE: Current positions: $positions');
      print('📊 DUO CHALLENGE: Current steps: $steps');
      print('📊 DUO CHALLENGE: Current user ID: $_userId');

      // Load current user's data first
      if (positions.containsKey(_userId)) {
        final userPos = (positions[_userId] ?? 200.0).toDouble();
        final userSteps = (steps[_userId] ?? 0) as int;

        if (mounted) {
          setState(() {
            _userPosition = userPos;
            _steps = userSteps;
          });
        }

        print(
          '📊 DUO CHALLENGE: Loaded user data - Position: $userPos, Steps: $userSteps',
        );
      }

      // Find and load the other player's data
      final otherPlayerId =
          positions.keys.where((key) => key != _userId).firstOrNull;

      print('📊 DUO CHALLENGE: Found other player ID: $otherPlayerId');

      if (otherPlayerId != null) {
        final opponentPos = (positions[otherPlayerId] ?? 200.0).toDouble();
        final opponentSteps = (steps[otherPlayerId] ?? 0) as int;

        print(
          '📊 DUO CHALLENGE: Found opponent data - Position: $opponentPos, Steps: $opponentSteps',
        );

        if (mounted) {
          setState(() {
            _opponentPosition = opponentPos;
            _opponentSteps = opponentSteps;
            _otherPlayerId = otherPlayerId;
            _isOpponentWalking = false; // Start in idle state
          });
        }

        print(
          '📊 DUO CHALLENGE: Set opponent data - _otherPlayerId: $_otherPlayerId, _opponentPosition: $_opponentPosition',
        );

        // IMMEDIATE VISIBILITY: Ensure opponent character is immediately visible
        print('👥 DUO CHALLENGE: Opponent immediately visible on game start!');
      } else {
        // If no real opponent found but we have a placeholder, keep it
        if (_otherPlayerId == 'waiting_for_opponent') {
          print(
            '📊 DUO CHALLENGE: Keeping placeholder opponent until real opponent joins',
          );
        } else {
          // Create placeholder opponent for immediate display
          if (mounted) {
            setState(() {
              _otherPlayerId = 'waiting_for_opponent';
              _opponentPosition = 200.0;
              _opponentSteps = 0;
              _isOpponentWalking = false;
            });
          }
          print(
            '📊 DUO CHALLENGE: Created placeholder opponent for immediate display',
          );
        }
      }
    } else {
      print('📊 DUO CHALLENGE: Document does not exist');
    }
  }

  Future<void> _ensureBothPlayersVisible() async {
    print('👥 DUO CHALLENGE: Ensuring both players are visible immediately...');

    // Get the latest game data
    final docSnapshot = await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .get();

    if (docSnapshot.exists && docSnapshot.data() != null) {
      final data = docSnapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        print(
          '❌ DUO CHALLENGE: Document data is null in _ensureBothPlayersVisible',
        );
        return;
      }

      final positions =
          (data['positions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final steps =
          (data['steps'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      // Ensure current user data is set
      if (positions.containsKey(_userId)) {
        final userPos = (positions[_userId] ?? 200.0).toDouble();
        final userSteps = (steps[_userId] ?? 0) as int;

        if (mounted) {
          setState(() {
            _userPosition = userPos;
            _steps = userSteps;
          });
        }

        print(
          '👥 DUO CHALLENGE: User data confirmed - Position: $userPos, Steps: $userSteps',
        );
      }

      // IMMEDIATE VISIBILITY: Ensure opponent data is set if available
      final otherPlayerId =
          positions.keys.where((key) => key != _userId).firstOrNull;
      if (otherPlayerId != null) {
        final opponentPos = (positions[otherPlayerId] ?? 200.0).toDouble();
        final opponentSteps = (steps[otherPlayerId] ?? 0) as int;

        if (mounted) {
          setState(() {
            _opponentPosition = opponentPos;
            _opponentSteps = opponentSteps;
            _otherPlayerId = otherPlayerId;
            _isOpponentWalking = false;
          });
        }

        print(
          '👥 DUO CHALLENGE: Opponent data confirmed - Position: $opponentPos, Steps: $opponentSteps',
        );
        print('👥 DUO CHALLENGE: BOTH PLAYERS NOW VISIBLE!');
      } else {
        // If no opponent yet, ensure placeholder is shown
        if (_otherPlayerId == null ||
            _otherPlayerId != 'waiting_for_opponent') {
          if (mounted) {
            setState(() {
              _otherPlayerId = 'waiting_for_opponent';
              _opponentPosition = 200.0;
              _opponentSteps = 0;
              _isOpponentWalking = false;
            });
          }
          print(
            '👥 DUO CHALLENGE: Created placeholder opponent for immediate visibility',
          );
        } else {
          print(
            '👥 DUO CHALLENGE: Placeholder opponent already visible - waiting for real opponent',
          );
        }
      }
    }
  }

  void _forceImmediateVisibilityCheck() {
    print('🔍 DUO CHALLENGE: Force checking immediate visibility...');

    // Force a state update to ensure both characters are rendered
    if (mounted) {
      setState(() {
        // This will trigger a rebuild and ensure both characters are visible
      });

      print(
        '🔍 DUO CHALLENGE: Visibility check completed - both characters should be visible',
      );

      // Additional check: if opponent is still not visible, force it
      if (_otherPlayerId == null) {
        print(
          '🚨 DUO CHALLENGE: Opponent still not visible - forcing placeholder',
        );
        if (mounted) {
          setState(() {
            _otherPlayerId = 'waiting_for_opponent';
            _opponentPosition = 200.0;
            _opponentSteps = 0;
            _isOpponentWalking = false;
          });
        }
      }
    }
  }

  void _aggressiveVisibilityCheck() {
    print('🚨 DUO CHALLENGE: AGGRESSIVE visibility check...');

    // Force reload game data to ensure both players are visible
    _loadExistingGameData();
    _ensureBothPlayersVisible();

    // Force a state update
    if (mounted) {
      setState(() {
        // Trigger rebuild
      });
    }

    print('🚨 DUO CHALLENGE: Aggressive visibility check completed');
  }

  void _startGameStateListener() {
    final docRef =
        _firestore.collection('duo_challenge_invites').doc(widget.inviteId);

    _gameStateSubscription = docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        print('❌ DUO CHALLENGE: Document data is null');
        return;
      }

      final positions =
          (data['positions'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final steps =
          (data['steps'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final gameEnded = data['gameEnded'] ?? false;
      final winner = data['winner'] as String?;

      // IMMEDIATE VISIBILITY: Always check for opponent and make them visible
      final otherPlayerId =
          positions.keys.where((key) => key != _userId).firstOrNull;

      print(
        '🔍 DUO CHALLENGE: Checking for opponent - found: $otherPlayerId, current: $_otherPlayerId',
      );

      if (otherPlayerId != null) {
        final opponentPos = (positions[otherPlayerId] ?? 200.0).toDouble();
        final opponentSteps = (steps[otherPlayerId] ?? 0) as int;

        print(
          '📊 DUO CHALLENGE: Real-time update - Opponent ID: $otherPlayerId, Position: $opponentPos, Steps: $opponentSteps',
        );

        // CRITICAL FIX: Always ensure opponent is visible, regardless of state changes
        bool shouldUpdateOpponent = false;

        // Case 1: New opponent joined (different ID)
        if (_otherPlayerId != otherPlayerId) {
          print(
            '👥 DUO CHALLENGE: NEW OPPONENT JOINED - Making immediately visible!',
          );
          shouldUpdateOpponent = true;
        }
        // Case 2: Same opponent but data changed
        else if (_opponentPosition != opponentPos ||
            _opponentSteps != opponentSteps) {
          print('📊 DUO CHALLENGE: Existing opponent data changed');
          shouldUpdateOpponent = true;
        }
        // Case 3: Same opponent, same data, but not visible (safety check)
        else if (_otherPlayerId == null ||
            _otherPlayerId == 'waiting_for_opponent') {
          print(
            '🚨 DUO CHALLENGE: Opponent exists but not visible - forcing visibility!',
          );
          shouldUpdateOpponent = true;
        }

        if (shouldUpdateOpponent) {
          // Determine if opponent is walking based on step changes
          bool opponentIsWalking = false;
          if (_otherPlayerId == otherPlayerId &&
              _opponentSteps != opponentSteps) {
            opponentIsWalking = opponentSteps > _opponentSteps;
          }

          if (mounted) {
            setState(() {
              _opponentPosition = opponentPos;
              _opponentSteps = opponentSteps;
              _otherPlayerId = otherPlayerId;
              _isOpponentWalking = opponentIsWalking;
            });
          }

          // Update opponent character animation immediately
          _updateOpponentCharacterAnimation(opponentIsWalking);

          print(
            '👥 DUO CHALLENGE: Opponent now visible with position: $opponentPos, steps: $opponentSteps',
          );

          // If opponent was walking, stop after a short delay for smooth animation
          if (opponentIsWalking) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _isOpponentWalking = false;
                });
                _updateOpponentCharacterAnimation(false);
              }
            });
          }
        } else {
          print('📊 DUO CHALLENGE: Opponent already visible and up-to-date');
        }
      } else {
        // No real opponent found, but keep placeholder if it exists
        if (_otherPlayerId == 'waiting_for_opponent') {
          print('📊 DUO CHALLENGE: No real opponent yet, keeping placeholder');
        } else if (_otherPlayerId == null) {
          // Create placeholder if no opponent and no placeholder
          print('📊 DUO CHALLENGE: No opponent found - creating placeholder');
          setState(() {
            _otherPlayerId = 'waiting_for_opponent';
            _opponentPosition = 200.0;
            _opponentSteps = 0;
            _isOpponentWalking = false;
          });
        } else {
          print('📊 DUO CHALLENGE: No opponent found in real-time update');
        }
      }

      // CRITICAL: Always ensure both characters are visible (final safety check)
      if (_otherPlayerId == null) {
        print(
          '🚨 DUO CHALLENGE: FINAL SAFETY CHECK - Creating placeholder opponent',
        );
        if (mounted) {
          setState(() {
            _otherPlayerId = 'waiting_for_opponent';
            _opponentPosition = 200.0;
            _opponentSteps = 0;
            _isOpponentWalking = false;
          });
        }
      }

      // Check for game end
      if (gameEnded && !_gameEnded) {
        if (mounted) {
          setState(() {
            _gameEnded = true;
            _winner = winner;
          });
        }
        _showWinnerDialog(winner);
      }
    });
  }

  Future<void> _preloadCharacters() async {
    final animationService = CharacterAnimationService();

    // If not loaded and not loading, start preloading
    if (!animationService.isLoaded && !animationService.isLoading) {
      animationService.preloadAnimations();
    }

    // Wait for animations to be ready using the service method
    await animationService.waitForLoad();

    if (mounted) {
      setState(() {
        _isLoadingCharacters = false;
      });
    }
  }

  void _initializeStepTracking() async {
    print(
      '🏁 DUO CHALLENGE: Initializing sensor-based step tracking for challenge...',
    );

    try {
      // Force reset walking state to ensure correct initial state (like Solo Mode)
      if (mounted) {
        setState(() {
          _isUserWalking = false;
          _lastStepUpdate = null; // Reset step history
        });
      }

      // APPROACH 9: Use the same method as solo_mode.dart for consistency
      await _fetchStepsFromSoloMethod();

      // APPROACH 24: PROPERLY INITIALIZE STEP TRACKING (like Solo Mode)
      // Set previous steps to current steps for proper comparison
      if (mounted) {
        setState(() {
          _previousSteps = _steps;
        });
      }
      print(
        '📊 DUO CHALLENGE: Initialized step tracking: previous=$_previousSteps, current=$_steps',
      );

      // Force walking state to false after initial fetch (like Solo Mode)
      if (mounted) {
        setState(() {
          _isUserWalking = false;
        });
      }
      print('🔄 DUO CHALLENGE: Force reset walking state after initial fetch');

      // Force character to idle state during initialization (like Solo Mode)
      if (_userGameInstance?.character != null) {
        _userGameInstance!.character!.isWalking = false;
        _userGameInstance!.character!.updateAnimation(false);
        print('🎬 DUO CHALLENGE: Forced character to idle state');
      }

      // APPROACH 26: START CONTINUOUS MONITORING (like Solo Mode)
      _startContinuousMonitoring();

      // Initialize sensor-based tracking only for the challenge
      await _initializeSensorBasedTracking();

      print(
        '✅ DUO CHALLENGE: Challenge-specific sensor-based step tracking initialized',
      );
    } catch (e) {
      print('❌ DUO CHALLENGE: Error initializing real-time tracking: $e');
      // Fallback to periodic polling
      _startPeriodicUpdates();
    }
  }

  Future<void> _initializeSensorBasedTracking() async {
    print('📱 DUO CHALLENGE: Initializing sensor-based tracking...');

    // Use ONLY Health Connect monitoring to avoid false increments (like Solo Mode)
    final hasPermissions = await _healthService.checkHealthConnectPermissions();

    if (hasPermissions) {
      // Start Health Connect monitoring only (no hybrid system)
      await _healthService.startRealTimeStepMonitoring();

      // Set up Health Connect listener
      _setupHealthConnectListener();

      print('✅ DUO CHALLENGE: Health Connect monitoring started');
    } else {
      // Fallback to periodic polling if no permissions
      print(
        '⚠️ DUO CHALLENGE: No Health Connect permissions, using periodic polling',
      );
      _startPeriodicUpdates();
    }
  }

  void _setupHealthConnectListener() {
    // Set up callback for Health Connect step updates (like Solo Mode)
    _healthService.setStepUpdateCallback((totalSteps, stepIncrease) async {
      if (mounted) {
        // Use sensor-optimized method to get accurate step count
        final accurateSteps = await _healthService.fetchHybridRealTimeSteps();

        // Update steps and check walking state
        setState(() {
          _previousSteps = _steps;
          _steps = accurateSteps; // Use accurate steps, not hybrid total
        });

        // Check if user is walking (steps increased)
        _checkUserWalkingWithTiming(DateTime.now());

        // Sync character animation
        _syncCharacterAnimation();

        // Update steps in Firestore for opponent visibility
        await _updateStepsInFirestore();

        print(
          '🏥 DUO CHALLENGE Health Connect update: +$stepIncrease steps (Accurate Total: $accurateSteps)',
        );
      }
    });
  }

  // APPROACH 10: Use the animation-safe hybrid method (like Solo Mode)
  Future<void> _fetchStepsFromSoloMethod() async {
    try {
      // Use the sensor-optimized method for accurate steps and responsive animations
      final stepsCount = await _healthService
          .fetchHybridRealTimeSteps(); // Use hybrid for immediate feedback + accuracy

      if (mounted) {
        // Store the current steps as previous before updating
        int oldSteps = _steps;

        setState(() {
          _previousSteps = oldSteps; // Store the actual previous steps
          _steps = stepsCount;
        });

        // Check if user is walking (steps increased)
        _checkUserWalkingWithTiming(DateTime.now());

        print(
          '📱 DUO CHALLENGE SENSOR-OPTIMIZED: Fetched accurate steps: $stepsCount (previous: $_previousSteps)',
        );

        // APPROACH 22: DEBUG STEP TRACKING
        print(
          '📊 DUO CHALLENGE Step tracking: previous=$_previousSteps, current=$_steps, difference=${_steps - _previousSteps}',
        );
      }
    } catch (e) {
      print('❌ DUO CHALLENGE Error in animation-safe step fetch: $e');
      if (mounted) {
        setState(() {
          _steps = 0;
        });
      }
    }
  }

  Future<void> _updateStepsInFirestore() async {
    await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .update({'steps.$_userId': _steps});
    print('📊 DUO CHALLENGE: Updated steps in Firestore: $_steps');
  }

  void _startPeriodicUpdates() {
    // APPROACH 5: More frequent updates with aggressive sync (like Solo Mode)
    Future.delayed(const Duration(seconds: 5), () {
      // 5-second interval to ensure reliability
      if (mounted) {
        _fetchStepsFromSoloMethod();

        // Force check walking state if still walking but no recent steps
        if (_isUserWalking && _lastStepUpdate != null) {
          final timeSinceLastStep =
              DateTime.now().difference(_lastStepUpdate!).inSeconds;
          print(
            '🔄 DUO CHALLENGE PERIODIC CHECK: Time since last step: ${timeSinceLastStep}s',
          );

          if (timeSinceLastStep >= 5) {
            // Force idle after 5 seconds of no steps (proper idle detection)
            print(
              '⏰ DUO CHALLENGE PERIODIC 5-SECOND TIMEOUT: No steps for ${timeSinceLastStep}s - FORCING IDLE',
            );
            print(
              '⏰ DUO CHALLENGE PERIODIC 5-SECOND TIMEOUT: User definitely stopped walking',
            );
            _setWalkingState(false);
            _forceCharacterAnimationSync(); // Force immediate sync
          } else if (timeSinceLastStep >= 7) {
            print(
              '⚠️ DUO CHALLENGE PERIODIC WARNING: No steps for ${timeSinceLastStep}s - will force idle soon',
            );
          }
        }

        // APPROACH 6: Always force sync character animation
        _syncCharacterAnimation();

        // APPROACH 7: Additional safety check every 5 seconds
        _forceCharacterStateCheck();

        // APPROACH 33: PROPER PERIODIC IDLE DETECTION (5 seconds)
        if (_isUserWalking && _lastStepUpdate != null) {
          final timeSinceLastStep =
              DateTime.now().difference(_lastStepUpdate!).inSeconds;

          if (timeSinceLastStep >= 5) {
            print(
              '⏰ DUO CHALLENGE PERIODIC 5-SECOND IDLE: No steps for ${timeSinceLastStep}s, forcing idle',
            );
            _setWalkingState(false);
            _forceCharacterAnimationSync();
          }
        }

        _startPeriodicUpdates(); // Recursive call for periodic updates
      }
    });
  }

  void _forceCharacterStateCheck() {
    // APPROACH 8: Force character state check (like Solo Mode)
    if (_userGameInstance?.character != null) {
      final characterIsWalking = _userGameInstance!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        print(
          '🛡️ DUO CHALLENGE Force character state correction: character=$characterIsWalking, should=$_isUserWalking',
        );
        _userGameInstance!.updateWalkingState(_isUserWalking);
      }

      // APPROACH 11: AGGRESSIVE CHARACTER STATE FORCE (like Solo Mode)
      if (_isUserWalking == false && characterIsWalking == true) {
        print(
          '🚨 DUO CHALLENGE AGGRESSIVE: Character is walking but should be idle - FORCING',
        );
        _userGameInstance!.character!.isWalking = false;
        _userGameInstance!.character!.updateAnimation(false);
        _userGameInstance!.character!.stopWalking();
      }
    }
  }

  void _startContinuousMonitoring() {
    print('🔄 DUO CHALLENGE: Starting continuous monitoring system...');

    // Monitor every 1 second for immediate response
    _startFrequentMonitoring();
    // Monitor every 2 seconds for backup
    _startBackupMonitoring();
    // Monitor every 3 seconds for safety
    _startSafetyMonitoring();
  }

  void _startFrequentMonitoring() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _checkWalkingStateFrequently();
        _startFrequentMonitoring();
      }
    });
  }

  void _startBackupMonitoring() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkWalkingStateBackup();
        _startBackupMonitoring();
      }
    });
  }

  void _startSafetyMonitoring() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _checkWalkingStateSafety();
        _startSafetyMonitoring();
      }
    });
  }

  void _checkWalkingStateFrequently() {
    // GRACE PERIOD: Don't check walking state during initialization (like Solo Mode)
    if (!_isInitialized) {
      return;
    }

    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep =
          DateTime.now().difference(_lastStepUpdate!).inSeconds;
      print(
        '⚡ DUO CHALLENGE: FREQUENT CHECK: Time since last step: ${timeSinceLastStep}s',
      );

      if (timeSinceLastStep >= 5) {
        print(
          '⏰ DUO CHALLENGE: FREQUENT 5-SECOND IDLE: No steps for ${timeSinceLastStep}s - FORCING IDLE NOW',
        );
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      }
    }

    // APPROACH 29: CONTINUOUS CHARACTER SYNC (like Solo Mode)
    // Always sync character animation with walking state
    if (mounted && _userGameInstance?.character != null) {
      final characterIsWalking = _userGameInstance!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        print(
          '🎬 DUO CHALLENGE: FREQUENT SYNC: Character walking ($characterIsWalking) != User walking ($_isUserWalking) - FORCING SYNC',
        );

        // APPROACH 34: AGGRESSIVE CHARACTER STATE FORCE (like Solo Mode)
        _userGameInstance!.character!.isWalking = _isUserWalking;
        _userGameInstance!.character!.updateAnimation(_isUserWalking);

        // Force animation directly if still not synced
        if (!_isUserWalking &&
            _userGameInstance!.character!.idleAnimation != null) {
          print(
            '🎬 DUO CHALLENGE: FREQUENT FORCE: Directly setting idle animation',
          );
          _userGameInstance!.character!.animation =
              _userGameInstance!.character!.idleAnimation;
        }
      }
    }
  }

  void _checkWalkingStateBackup() {
    // GRACE PERIOD: Don't check walking state during initialization (like Solo Mode)
    if (!_isInitialized) {
      return;
    }

    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep =
          DateTime.now().difference(_lastStepUpdate!).inSeconds;
      print(
        '🔄 DUO CHALLENGE: BACKUP CHECK: Time since last step: ${timeSinceLastStep}s',
      );

      if (timeSinceLastStep >= 5) {
        print(
          '⏰ DUO CHALLENGE: BACKUP 5-SECOND IDLE: No steps for ${timeSinceLastStep}s - FORCING IDLE NOW',
        );
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      }
    }

    // APPROACH 30: BACKUP CHARACTER SYNC (like Solo Mode)
    if (mounted && _userGameInstance?.character != null) {
      final characterIsWalking = _userGameInstance!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        print(
          '🎬 DUO CHALLENGE: BACKUP SYNC: Character walking ($characterIsWalking) != User walking ($_isUserWalking) - FORCING SYNC',
        );

        // APPROACH 35: AGGRESSIVE BACKUP CHARACTER FORCE (like Solo Mode)
        _userGameInstance!.character!.isWalking = _isUserWalking;
        _userGameInstance!.character!.updateAnimation(_isUserWalking);

        // Force animation directly if still not synced
        if (!_isUserWalking &&
            _userGameInstance!.character!.idleAnimation != null) {
          print(
            '🎬 DUO CHALLENGE: BACKUP FORCE: Directly setting idle animation',
          );
          _userGameInstance!.character!.animation =
              _userGameInstance!.character!.idleAnimation;
        }
      }
    }
  }

  void _checkWalkingStateSafety() {
    // GRACE PERIOD: Don't check walking state during initialization (like Solo Mode)
    if (!_isInitialized) {
      return;
    }

    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep =
          DateTime.now().difference(_lastStepUpdate!).inSeconds;
      print(
        '🛡️ DUO CHALLENGE: SAFETY CHECK: Time since last step: ${timeSinceLastStep}s',
      );

      if (timeSinceLastStep >= 5) {
        print(
          '⏰ DUO CHALLENGE: SAFETY 5-SECOND IDLE: No steps for ${timeSinceLastStep}s - FORCING IDLE NOW',
        );
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      }
    }

    // APPROACH 31: SAFETY CHARACTER SYNC (like Solo Mode)
    if (mounted && _userGameInstance?.character != null) {
      final characterIsWalking = _userGameInstance!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        print(
          '🎬 DUO CHALLENGE: SAFETY SYNC: Character walking ($characterIsWalking) != User walking ($_isUserWalking) - FORCING SYNC',
        );

        // APPROACH 36: AGGRESSIVE SAFETY CHARACTER FORCE (like Solo Mode)
        _userGameInstance!.character!.isWalking = _isUserWalking;
        _userGameInstance!.character!.updateAnimation(_isUserWalking);

        // Force animation directly if still not synced
        if (!_isUserWalking &&
            _userGameInstance!.character!.idleAnimation != null) {
          print(
            '🎬 DUO CHALLENGE: SAFETY FORCE: Directly setting idle animation',
          );
          _userGameInstance!.character!.animation =
              _userGameInstance!.character!.idleAnimation;
        }
      }
    }
  }

  void _setWalkingState(bool walking) {
    if (_isUserWalking != walking) {
      if (mounted) {
        setState(() {
          _isUserWalking = walking;
        });
      }
      walking ? _startCharacterWalking() : _stopCharacterWalking();
      print(
        walking
            ? '🚶‍♂️ DUO CHALLENGE: User started walking'
            : '🛑 DUO CHALLENGE: User stopped walking',
      );

      // APPROACH 6: Additional safety check after state change (like Solo Mode)
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _userGameInstance?.character != null) {
          final characterIsWalking = _userGameInstance!.character!.isWalking;
          if (characterIsWalking != walking) {
            print(
              '🛡️ DUO CHALLENGE: Safety check: Character state mismatch, forcing correction',
            );
            _userGameInstance!.updateWalkingState(walking);
          }
        }
      });

      // APPROACH 13: IMMEDIATE ANIMATION FORCE (like Solo Mode)
      if (!walking) {
        // When stopping walking, force idle animation immediately
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _userGameInstance?.character != null) {
            print('🎬 DUO CHALLENGE: IMMEDIATE: Forcing idle animation');
            _userGameInstance!.character!.updateAnimation(false);
          }
        });
      }
    } else {
      // APPROACH 28: FORCE ANIMATION EVEN IF STATE IS SAME (like Solo Mode)
      // If state is already correct but animation might not be
      print(
        '🔄 DUO CHALLENGE: State already correct ($walking), but forcing animation sync',
      );
      walking ? _startCharacterWalking() : _stopCharacterWalking();

      // Force character animation immediately
      if (mounted && _userGameInstance?.character != null) {
        print(
          '🎬 DUO CHALLENGE: FORCE SYNC: Forcing character animation to ${walking ? "walking" : "idle"}',
        );
        _userGameInstance!.character!.updateAnimation(walking);
      }
    }
  }

  void _moveUserForward() async {
    if (_gameEnded) return;

    // Move user forward with smooth increment (like Solo Mode)
    const double moveIncrement = 15.0; // Smooth increment for natural movement
    if (mounted) {
      setState(() {
        _userPosition += moveIncrement;
      });
    }

    // Update position and steps in Firestore for real-time sync
    await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .update({
      'positions.$_userId': _userPosition,
      'steps.$_userId': _steps,
    });

    // Auto-scroll to keep user character visible
    _autoScrollToUser();

    // Check if user reached finish line
    if (_userPosition >= finishLinePosition) {
      await _endGame(_userId);
    }
  }

  void _checkUserWalkingWithTiming(DateTime timestamp) {
    final now = DateTime.now();

    print(
      '🔍 DUO CHALLENGE: Checking walking state: previous=$_previousSteps, current=$_steps, isWalking=$_isUserWalking, initialized=$_isInitialized',
    );

    // GRACE PERIOD: Don't detect walking during initialization (like Solo Mode)
    if (!_isInitialized) {
      print(
        '🎯 DUO CHALLENGE: GRACE PERIOD: Screen not fully initialized, ignoring walking detection',
      );
      return;
    }

    // APPROACH 1: Immediate detection with multiple checks (like Solo Mode)
    bool shouldBeWalking = false;

    // Check if steps increased
    if (_steps > _previousSteps) {
      shouldBeWalking = true;
      _lastStepUpdate = now;
      print(
        '🚶‍♂️ DUO CHALLENGE: Steps increased: $_previousSteps -> $_steps, user is walking',
      );

      // Move character forward when steps increase
      _moveUserForward();

      // APPROACH 23: UPDATE PREVIOUS STEPS WHEN WALKING (like Solo Mode)
      // Update previous steps to current steps for next comparison
      _previousSteps = _steps;
      print('📊 DUO CHALLENGE: Updated previous steps to: $_previousSteps');
    } else {
      // Steps didn't increase - user should be idle
      shouldBeWalking = false;
      print('🛑 DUO CHALLENGE: Steps unchanged: $_steps, user should be idle');
    }

    // APPROACH 2: Force state change if different (like Solo Mode)
    if (_isUserWalking != shouldBeWalking) {
      print(
        '🔄 DUO CHALLENGE: State change needed: $_isUserWalking -> $shouldBeWalking',
      );
      _setWalkingState(shouldBeWalking);
    } else {
      print('✅ DUO CHALLENGE: State is correct: $_isUserWalking');
    }

    // APPROACH 27: AGGRESSIVE WALKING FORCE (like Solo Mode)
    // If steps are increasing but user is not marked as walking, force it
    if (_steps > _previousSteps && !_isUserWalking) {
      print(
        '🚨 DUO CHALLENGE: AGGRESSIVE WALKING FORCE: Steps increasing but user not walking - FORCING WALKING',
      );
      print(
        '🚨 DUO CHALLENGE: AGGRESSIVE WALKING FORCE: $_previousSteps -> $_steps, forcing _isUserWalking = true',
      );
      _setWalkingState(true);
    }

    // APPROACH 3: Additional safety check - force idle if no recent steps (like Solo Mode)
    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep = now.difference(_lastStepUpdate!).inSeconds;
      print('⏰ DUO CHALLENGE: Time since last step: ${timeSinceLastStep}s');

      if (timeSinceLastStep >= 5) {
        // Force idle after 5 seconds of no steps (proper idle detection)
        print(
          '⏰ DUO CHALLENGE: 5-SECOND TIMEOUT: No steps for ${timeSinceLastStep}s, FORCING IDLE',
        );
        print(
          '⏰ DUO CHALLENGE: 5-SECOND TIMEOUT: User has stopped walking - switching to idle',
        );
        _setWalkingState(false);
      } else if (timeSinceLastStep >= 3) {
        print(
          '⚠️ DUO CHALLENGE: WARNING: No steps for ${timeSinceLastStep}s - preparing to force idle soon',
        );
      } else if (timeSinceLastStep >= 1) {
        print(
          '👀 DUO CHALLENGE: MONITORING: No steps for ${timeSinceLastStep}s - watching for idle state',
        );
      }
    }

    // APPROACH 32: PROPER 5-SECOND IDLE DETECTION (like Solo Mode)
    // Only force idle if steps haven't increased for 5 seconds
    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep = now.difference(_lastStepUpdate!).inSeconds;

      if (timeSinceLastStep >= 5) {
        print(
          '⏰ DUO CHALLENGE: 5-SECOND IDLE: No steps for ${timeSinceLastStep}s, forcing idle',
        );
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      } else {
        print(
          '👀 DUO CHALLENGE: MONITORING: ${timeSinceLastStep}s since last step - still in walking window',
        );
      }
    }

    // APPROACH 16: DEBUG CHARACTER STATE (like Solo Mode)
    if (_userGameInstance?.character != null) {
      print(
        '🎬 DUO CHALLENGE: Character state: isWalking=${_userGameInstance!.character!.isWalking}, animation=${_userGameInstance!.character!.animation == _userGameInstance!.character!.walkingAnimation ? "walking" : "idle"}',
      );

      // APPROACH 20: FORCE CHARACTER IDLE IF STEPS UNCHANGED (like Solo Mode)
      if (_steps == _previousSteps && _userGameInstance!.character!.isWalking) {
        print(
          '🚨 DUO CHALLENGE: CHARACTER FORCE: Steps unchanged but character is walking - FORCING IDLE',
        );
        _userGameInstance!.character!.isWalking = false;
        _userGameInstance!.character!.updateAnimation(false);
        if (_userGameInstance!.character!.idleAnimation != null) {
          _userGameInstance!.character!.animation =
              _userGameInstance!.character!.idleAnimation;
          print('🎬 DUO CHALLENGE: CHARACTER FORCE: Animation set to idle');
        }
      }
    }
  }

  void _forceCharacterAnimationSync() {
    // APPROACH 8: Force immediate character animation sync (like Solo Mode)
    if (_userGameInstance?.character != null) {
      print('🔄 DUO CHALLENGE: FORCING character animation sync to IDLE');

      // APPROACH 37: ULTRA AGGRESSIVE CHARACTER FORCE (like Solo Mode)
      _userGameInstance!.character!.isWalking = false;
      _userGameInstance!.character!.updateAnimation(false);
      _userGameInstance!.character!.stopWalking();

      // Force idle animation directly
      if (_userGameInstance!.character!.idleAnimation != null) {
        print(
          '🎬 DUO CHALLENGE: ULTRA FORCE: Setting animation to idleAnimation',
        );
        _userGameInstance!.character!.animation =
            _userGameInstance!.character!.idleAnimation;

        // Force animation restart by reassignment
        print(
          '🎬 DUO CHALLENGE: ULTRA FORCE: Animation reassigned to force restart',
        );
      }

      // Double-check state after forcing
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _userGameInstance?.character != null) {
          final isWalking = _userGameInstance!.character!.isWalking;
          if (isWalking) {
            print(
              '🎬 DUO CHALLENGE: ULTRA FORCE: Character still walking after force, trying again',
            );
            _userGameInstance!.character!.isWalking = false;
            _userGameInstance!.character!.updateAnimation(false);
          }
        }
      });
    }
  }

  void _syncCharacterAnimation() {
    // APPROACH 4: Aggressive character animation sync with multiple attempts (like Solo Mode)
    if (_userGameInstance != null) {
      // Force update walking state
      _userGameInstance!.updateWalkingState(_isUserWalking);

      // Additional check - ensure character state is correct
      if (_userGameInstance!.character != null) {
        final characterIsWalking = _userGameInstance!.character!.isWalking;
        if (characterIsWalking != _isUserWalking) {
          print(
            '🔄 DUO CHALLENGE: Character state mismatch: character=$characterIsWalking, should=$_isUserWalking',
          );
          // Force correct state
          _userGameInstance!.updateWalkingState(_isUserWalking);
        }
      }

      print(
        '✅ DUO CHALLENGE: Character animation synced (Solo Mode style): ${_isUserWalking ? "Walking" : "Idle"}',
      );
    } else {
      print('⚠️ DUO CHALLENGE: Game instance not available for animation sync');
    }
  }

  void _startCharacterWalking() {
    // Start character walking animation with proper error handling (like Solo Mode)
    _userGameInstance?.updateWalkingState(true);
    print('🎬 DUO CHALLENGE: Character walking animation started');
  }

  void _stopCharacterWalking() {
    // Stop character walking animation with proper error handling (like Solo Mode)
    _userGameInstance?.updateWalkingState(false);
    print('🎬 DUO CHALLENGE: Character walking animation stopped');
  }

  void _updateUserCharacterAnimation(bool walking) {
    if (_userGameInstance != null && _userGameInstance!.character != null) {
      _userGameInstance!.updateWalkingState(walking);
      _userGameInstance!.character!.isWalking = walking;
      _userGameInstance!.character!.updateAnimation(walking);
    }
  }

  void _updateOpponentCharacterAnimation(bool walking) {
    if (_opponentGameInstance != null &&
        _opponentGameInstance!.character != null) {
      _opponentGameInstance!.updateWalkingState(walking);
      _opponentGameInstance!.character!.isWalking = walking;
      _opponentGameInstance!.character!.updateAnimation(walking);
    }
  }

  Widget _buildGameWidget({
    required bool isPlayer1,
    required bool isWalking,
    required String userId,
    required double characterWidth,
    required double characterHeight,
    required bool isUser,
  }) {
    final game = CharacterDisplayGame(
      isPlayer1: isPlayer1,
      isWalking: isWalking,
      userId: userId,
      faceRight: true,
      characterWidth: characterWidth,
      characterHeight: characterHeight,
    );

    // Store the game instance
    if (isUser) {
      print('Setting _userGameInstance');
      _userGameInstance = game;
    } else {
      print('Setting _opponentGameInstance');
      _opponentGameInstance = game;
    }

    return GameWidget(game: game);
  }

  void _autoScrollToUser() {
    if (!_scrollController.hasClients) return;

    // Calculate target scroll position to keep user character visible
    final screenWidth = MediaQuery.of(context).size.width;
    final targetScroll =
        _userPosition - (screenWidth / 2) + (280 / 2); // Center the character

    // Ensure scroll position is within bounds
    final maxScroll = _scrollController.position.maxScrollExtent;
    final clampedTarget = targetScroll.clamp(0.0, maxScroll);

    // Only auto-scroll if user is walking and character would be off-screen
    final currentScroll = _scrollController.offset;
    final characterLeftEdge = _userPosition - (280 / 2);
    final characterRightEdge = _userPosition + (280 / 2);
    final visibleLeft = currentScroll;
    final visibleRight = currentScroll + screenWidth;

    // Auto-scroll only if character is about to go off-screen (smooth like Solo Mode)
    if (characterLeftEdge < visibleLeft + 150 ||
        characterRightEdge > visibleRight - 150) {
      _scrollController.animateTo(
        clampedTarget,
        duration: const Duration(
          milliseconds: 200,
        ), // Smooth auto-scroll (like Solo Mode)
        curve: Curves.easeOut, // Smooth deceleration
      );
    }
  }

  Future<void> _endGame(String winnerId) async {
    final winnerUsername =
        winnerId == _userId ? 'You' : (widget.otherUsername ?? 'Opponent');

    await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .update({
      'gameEnded': true,
      'winner': winnerId,
      'winnerUsername': winnerUsername,
    });
  }

  void _showWinnerDialog(String? winnerId) {
    final winnerUsername =
        winnerId == _userId ? 'You' : (widget.otherUsername ?? 'Opponent');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🏆 Race Complete!'),
          content: Text('Winner is $winnerUsername!'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(
                  context,
                ).popUntil((route) => route.isFirst); // Go to home
              },
              child: const Text('Back to Home'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Duo Challenge Race'),
        backgroundColor: const Color(0xFF7C4DFF),
        automaticallyImplyLeading: false,
      ),
      body: _isLoadingCharacters
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading characters...',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            )
          : _buildRacingTrack(),
    );
  }

  Widget _buildRacingTrack() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height -
        AppBar().preferredSize.height -
        MediaQuery.of(context).padding.top;

    // Track dimensions
    const double trackWidth = 9600.0; // Total track width in pixels
    const double roadOriginalWidth = 1200;
    const double roadOriginalHeight = 395;

    // Calculate heights to maintain aspect ratio
    final double roadHeight =
        screenWidth * (roadOriginalHeight / roadOriginalWidth);
    final double buildingsHeight = screenHeight - roadHeight;

    // Character sizing
    final double characterWidth = 280;
    final double characterHeight = 280;
    final double roadTopY = screenHeight - roadHeight;

    // Calculate how many times to repeat the background images
    // Each image covers screenWidth, so we need trackWidth / screenWidth repeats
    final int buildingsRepeatCount = (trackWidth / screenWidth).ceil();
    final int roadRepeatCount = (trackWidth / screenWidth).ceil();

    Widget nameLabel(String name) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
          ),
          child: Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        );

    return Stack(
      children: [
        // Static sky background (covers full screen)
        Positioned.fill(
          child: Image.asset('assets/images/sky-race.png', fit: BoxFit.cover),
        ),
        // Scrollable track container with manual scrolling enabled
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics:
              const AlwaysScrollableScrollPhysics(), // Enable manual scrolling
          child: SizedBox(
            width: trackWidth,
            height: screenHeight,
            child: Stack(
              children: [
                // Repeating buildings layer
                Positioned(
                  top: 0,
                  left: 0,
                  child: Row(
                    children: List.generate(buildingsRepeatCount, (index) {
                      return Image.asset(
                        'assets/images/buildings-race.png',
                        width: screenWidth,
                        height: buildingsHeight,
                        fit: BoxFit.fill,
                      );
                    }),
                  ),
                ),
                // Repeating road layer
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Row(
                    children: List.generate(roadRepeatCount, (index) {
                      return Image.asset(
                        'assets/images/road-race.png',
                        width: screenWidth,
                        height: roadHeight,
                        fit: BoxFit.fill,
                      );
                    }),
                  ),
                ),
                // Finish line marker (positioned at actual finish line location)
                Positioned(
                  left:
                      finishLinePosition - 50, // Position at actual finish line
                  bottom: roadHeight - 50, // On the road
                  child: Container(
                    width: 100,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Center(
                      child: Text(
                        'FINISH',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                // User character positioned on the track based on actual position
                Positioned(
                  left: _userPosition -
                      (characterWidth / 2), // Position based on track location
                  top: roadTopY - characterHeight + 100, // Feet on road
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // The label, positioned exactly at the top of the character
                      Positioned(top: 0, child: nameLabel('You')),
                      // The character, positioned directly below the label
                      SizedBox(
                        width: characterWidth,
                        height: characterHeight,
                        child: _buildGameWidget(
                          isPlayer1: true,
                          isWalking: _isUserWalking,
                          userId: _userId,
                          characterWidth: characterWidth,
                          characterHeight: characterHeight,
                          isUser: true,
                        ),
                      ),
                    ],
                  ),
                ),
                // Opponent character positioned on the track based on actual position
                if (_otherPlayerId != null)
                  Positioned(
                    left: _opponentPosition -
                        (characterWidth /
                            2), // Position based on track location
                    top: roadTopY - characterHeight + 100, // Feet on road
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // The label, positioned exactly at the top of the character
                        Positioned(
                          top: 0,
                          child: nameLabel(
                            _otherPlayerId == 'waiting_for_opponent'
                                ? 'Waiting...'
                                : (widget.otherUsername ?? 'Opponent'),
                          ),
                        ),
                        // The character, positioned directly below the label
                        SizedBox(
                          width: characterWidth,
                          height: characterHeight,
                          child: _buildGameWidget(
                            isPlayer1: false,
                            isWalking: _isOpponentWalking,
                            userId: _otherPlayerId == 'waiting_for_opponent'
                                ? 'placeholder'
                                : _otherPlayerId!,
                            characterWidth: characterWidth,
                            characterHeight: characterHeight,
                            isUser: false,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Step-based movement indicator (replaces manual arrow button)
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isUserWalking
                        ? Icons.directions_walk
                        : Icons.accessibility_new,
                    color: _isUserWalking ? Colors.green : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isUserWalking
                        ? 'Walking - Move to advance!'
                        : 'Take steps to move forward',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isUserWalking ? Colors.green : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Visual Progress Indicator
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Text labels with steps and position
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You: ${_userPosition.toInt()}m',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C4DFF),
                          ),
                        ),
                        Text(
                          'Challenge Steps: $_steps',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    if (_otherPlayerId != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_otherPlayerId == 'waiting_for_opponent' ? 'Waiting...' : (widget.otherUsername ?? 'Opponent')}: ${_opponentPosition.toInt()}m',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'Challenge Steps: $_opponentSteps',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Visual track with characters and finish line
                SizedBox(
                  height: 40,
                  child: Stack(
                    children: [
                      // Dashed track line
                      Positioned(
                        top: 20,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey[400]!,
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Your character indicator
                      Positioned(
                        left: (_userPosition / 9600.0) *
                            (MediaQuery.of(context).size.width - 40),
                        top: 8,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C4DFF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      // Opponent character indicator
                      if (_otherPlayerId != null)
                        Positioned(
                          left: (_opponentPosition / 9600.0) *
                              (MediaQuery.of(context).size.width - 40),
                          top: 8,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _otherPlayerId == 'waiting_for_opponent'
                                  ? Colors.grey
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              _otherPlayerId == 'waiting_for_opponent'
                                  ? Icons.hourglass_empty
                                  : Icons.person,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      // Finish line indicator
                      Positioned(
                        right: 0,
                        top: 8,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.flag,
                            color: Colors.white,
                            size: 16,
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
      ],
    );
  }
}

// Update CharacterDisplayGame to match Solo Mode smooth animation system
class CharacterDisplayGame extends FlameGame with KeyboardEvents {
  static CharacterDisplayGame? instance;
  final bool isPlayer1;
  bool isWalking;
  final String userId;
  final bool faceRight;
  final double characterWidth;
  final double characterHeight;
  final Offset? customPosition;
  Character? character;
  final double baseWidth = 1200;
  final double baseHeight = 2400;
  final double walkSpeed = 150.0; // Match Solo Mode walk speed

  CharacterDisplayGame({
    required this.isPlayer1,
    required this.isWalking,
    required this.userId,
    this.faceRight = true,
    required this.characterWidth,
    required this.characterHeight,
    this.customPosition,
  }) {
    instance = this;
  }

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    print('DUO CharacterDisplayGame onLoad start');
    await super.onLoad();
    final screenWidth = size.x;
    final screenHeight = size.y;
    final scaleX = screenWidth / baseWidth;
    final scaleY = screenHeight / baseHeight;

    try {
      // No background layers here, only character (like Solo Mode)
      character = Character(userId: userId);
      // Use consistent character size (280x280)
      character!.size = Vector2(280, 280);
      character!.anchor = Anchor.bottomCenter;
      character!.position = Vector2(
        screenWidth / 2,
        screenHeight,
      ); // Centered in widget
      if (!faceRight) {
        character!.flipHorizontally();
      }

      // Ensure character starts in correct state (like Solo Mode)
      character!.isWalking = isWalking;
      if (isWalking) {
        character!.startWalking();
      } else {
        character!.stopWalking();
      }

      // Ensure character starts in idle state during initialization (like Solo Mode)
      character!.isWalking = false;
      character!.updateAnimation(false);
      print('🎬 DUO GAME INITIALIZATION: Character forced to idle state');

      add(character!);
      print(
        'DUO CharacterDisplayGame: Character added with smooth Solo Mode system',
      );
    } catch (e, st) {
      print('DUO CharacterDisplayGame onLoad error: $e');
      print(st);
    }
  }

  // Method to update walking state - Enhanced for smooth transitions (like Solo Mode)
  void updateWalkingState(bool walking) {
    if (character != null) {
      character!.isWalking = walking;
      character!.updateAnimation(walking);
      print(
        '🎮 DUO Game: Character ${walking ? "started" : "stopped"} walking',
      );
    } else {
      print('⚠️ DUO Game: Character not available for walking state update');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (character?.isWalking == true) {
      // APPROACH 3: Add debug logging for character movement (like Solo Mode)
      print('🎮 DUO Game: Character walking - smooth animation active');

      // APPROACH 3: Add subtle character movement feedback (like Solo Mode)
      // This provides visual feedback without affecting the main racing track
      if (character != null) {
        // Subtle character movement for visual feedback
        final subtleMovement = 2.0 * dt; // Very subtle movement
        character!.position.x += subtleMovement;

        // Reset position if it goes too far (keep it centered)
        if (character!.position.x > size.x + 50) {
          character!.position.x = size.x / 2;
        }
      }
    } else {
      // APPROACH 4: Debug when character is not walking (like Solo Mode)
      if (character != null) {
        print('🎮 DUO Game: Character idle - smooth animation active');
      }
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    isWalking = keysPressed.contains(LogicalKeyboardKey.arrowRight);
    if (character != null) {
      character!.isWalking = isWalking;
      if (isWalking) {
        character!.startWalking();
      } else {
        character!.stopWalking();
      }
    }
    return KeyEventResult.handled;
  }
}

// Character component for display - Updated to match Solo Mode smoothness
class Character extends SpriteAnimationComponent with KeyboardHandler {
  final String userId;
  SpriteAnimation? idleAnimation;
  SpriteAnimation? walkingAnimation;
  bool isWalking = false;
  double moveSpeed =
      100.0; // Reduced speed for smoother movement (like Solo Mode)
  bool _animationsLoaded = false;

  Character({required this.userId})
      : super(
          size: Vector2(300, 300),
        ); // Reduced size for better performance (like Solo Mode)

  @override
  Future<void> onLoad() async {
    print('DUO Character onLoad start for userId: $userId');
    try {
      // Use preloaded animations from service (like Solo Mode)
      final animationService = CharacterAnimationService();

      if (animationService.isLoaded) {
        // Use cached animations
        idleAnimation = animationService.idleAnimation;
        walkingAnimation = animationService.walkingAnimation;
        _animationsLoaded = true;
        print('DUO Character onLoad: Using cached animations');
      } else {
        // Wait for animations to load or load them now
        print('DUO Character onLoad: Loading animations from service...');
        final animations = await animationService.getAnimations();
        idleAnimation = animations['idle'];
        walkingAnimation = animations['walking'];
        _animationsLoaded = true;
        print('DUO Character onLoad: Animations loaded from service');
      }

      animation = idleAnimation;
      print('DUO Character onLoad success');
    } catch (e, st) {
      print('DUO Character onLoad error: $e');
      print(st);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // APPROACH 1: Force recheck animation every frame (like Solo Mode)
    updateAnimation(isWalking);
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    isWalking = keysPressed.contains(LogicalKeyboardKey.arrowRight);
    updateAnimation(isWalking);
    return true;
  }

  void updateAnimation(bool walking) {
    if (!_animationsLoaded ||
        idleAnimation == null ||
        walkingAnimation == null) {
      print('⚠️ DUO Character updateAnimation: Animations not loaded');
      return;
    }

    final newAnimation = walking ? walkingAnimation : idleAnimation;

    if (animation != newAnimation) {
      print(
        '🔄 DUO Character: Switching animation to ${walking ? "walking" : "idle"}',
      );
      animation = newAnimation;
      // Force animation restart by reassigning
      print('🎬 DUO Animation switched and will restart');
    }
  }

  void startWalking() {
    print('🎬 DUO Character startWalking called');
    isWalking = true;
    updateAnimation(true);
  }

  void stopWalking() {
    print('🎬 DUO Character stopWalking called');
    isWalking = false;
    updateAnimation(false);
  }
}
