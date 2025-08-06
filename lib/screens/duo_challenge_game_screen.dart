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
import '../services/character_data_service.dart';
import '../services/health_service.dart';
import '../services/step_counter_service.dart';
import '../services/coin_service.dart';

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
  bool _gameEnded = false;
  String? _otherPlayerId;

  // Step-based racing system variables
  double _userPosition = 200.0; // Start characters in visible area
  double _opponentPosition = 200.0; // Start characters in visible area
  bool _isUserWalking = false;
  bool _isOpponentWalking = false;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<DocumentSnapshot>? _gameStateSubscription;
  static const double finishLinePosition = 5000.0;

  // Step tracking variables (similar to Solo Mode)
  int _steps = 0;
  int _previousSteps = 0;
  int _opponentSteps = 0;
  DateTime? _lastStepUpdate;
  bool _isInitialized = false;
  DateTime? _initializationTime;
  StreamSubscription<Map<String, dynamic>>? _stepSubscription;

  // NEW: Firestore-based step tracking variables
  int? _userInitialStepCount;
  int? _opponentInitialStepCount;
  int _userRawSteps = 0;
  int _opponentRawSteps = 0;

  // NEW: Character data for both players
  Map<String, dynamic>? _userCharacterData;
  Map<String, dynamic>? _opponentCharacterData;
  final CharacterDataService _characterDataService = CharacterDataService();
  bool _characterDataLoaded = false;

  // NEW: Game state variables
  bool _matchStarted = false;
  bool _showingWinnerDialog = false;
  bool _showingQuitDialog = false;
  static const int _stepGoal = 2000; // Updated step goal to 2000
  bool _showingMatchStartDialog = false;
  bool _countdownCompleted = false; // Track if countdown has finished

  // Callback functions to update character animations
  CharacterDisplayGame? _userGameInstance;
  CharacterDisplayGame? _opponentGameInstance;

  // Animation debouncing to prevent flickering
  DateTime? _lastOpponentAnimationUpdate;
  static const Duration _animationDebounceTime = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser!.uid;

    // Set initialization time and start grace period
    _initializationTime = DateTime.now();
    print('🏁 DUO CHALLENGE: Initialization started at $_initializationTime');

    // Initialize with walking state as false
    _isUserWalking = false;

    // IMMEDIATE CHARACTER VISIBILITY: Characters are immediately visible
    // Set up immediate fallback character data so characters show right away
    _userCharacterData = {
      'owned_items': ['MyCharacter'],
      'currentCharacter': 'MyCharacter',
      'homeGlbPath': 'assets/web/home/MyCharacter_home.glb',
      'spriteSheets': {
        'idle': 'images/sprite_sheets/MyCharacter_idle.json',
        'walking': 'images/sprite_sheets/MyCharacter_walking.json',
      },
    };
    _opponentCharacterData = {
      'owned_items': ['MyCharacter'],
      'currentCharacter': 'MyCharacter',
      'homeGlbPath': 'assets/web/home/MyCharacter_home.glb',
      'spriteSheets': {
        'idle': 'images/sprite_sheets/MyCharacter_idle.json',
        'walking': 'images/sprite_sheets/MyCharacter_walking.json',
      },
    };
    _characterDataLoaded = true;

    print(
        '🎭 DUO CHALLENGE INIT: User fallback sprite sheets: ${_userCharacterData!['spriteSheets']}');
    print(
        '🎭 DUO CHALLENGE INIT: Opponent fallback sprite sheets: ${_opponentCharacterData!['spriteSheets']}');
    print(
        '🎭 DUO CHALLENGE INIT: User character: ${_userCharacterData!['currentCharacter']}');
    print(
        '🎭 DUO CHALLENGE INIT: Opponent character: ${_opponentCharacterData!['currentCharacter']}');

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

      final positions = (data['positions'] as Map<String, dynamic>?) ?? {};
      final gameStarted = data['gameStarted'] ?? false;
      final matchStarted = data['matchStarted'] ?? false;
      final initialSteps =
          (data['initialSteps'] as Map<String, dynamic>?) ?? {};
      final rawSteps = (data['rawSteps'] as Map<String, dynamic>?) ?? {};

      // If game hasn't started yet, this is the first player
      if (!gameStarted) {
        print('🏁 DUO CHALLENGE: First player joining - initializing game');

        // Get current device step count for baseline
        final currentDeviceSteps = StepCounterService.currentSteps;

        await _firestore
            .collection('duo_challenge_invites')
            .doc(widget.inviteId)
            .update({
          'gameStarted': true,
          'gameStartTime': FieldValue.serverTimestamp(),
          'positions.$_userId': 200.0, // Start in visible area
          'steps.$_userId': 0,
          'scores.$_userId': 0,
          'initialSteps.$_userId':
              currentDeviceSteps, // Store initial step count
          'rawSteps.$_userId': currentDeviceSteps, // Store current raw steps
        });

        // Set user's initial step count locally
        _userInitialStepCount = currentDeviceSteps;
        _userRawSteps = currentDeviceSteps;

        // For first player, create a placeholder opponent immediately
        setState(() {
          _otherPlayerId = 'waiting_for_opponent';
          _opponentPosition = 200.0;
          _opponentSteps = 0; // Initialize to zero
          _isOpponentWalking = false;
          _steps = 0; // Ensure user steps start at zero
          _previousSteps = 0; // Ensure previous steps start at zero
        });
        print('👥 DUO CHALLENGE: First player - created placeholder opponent');
        print(
          '👥 DUO CHALLENGE: First player steps reset to 0 for challenge start',
        );
        print(
          '📊 DUO CHALLENGE: First player initial step count: $currentDeviceSteps',
        );
      } else {
        // Game already started, this is the second player joining
        print(
          '🏁 DUO CHALLENGE: Second player joining - adding to existing game',
        );

        // Get current device step count for baseline
        final currentDeviceSteps = StepCounterService.currentSteps;

        await _firestore
            .collection('duo_challenge_invites')
            .doc(widget.inviteId)
            .update({
          'positions.$_userId': 200.0, // Start in visible area
          'steps.$_userId': 0, // Reset to 0 for challenge start
          'scores.$_userId': 0,
          'initialSteps.$_userId':
              currentDeviceSteps, // Store initial step count
          'rawSteps.$_userId': currentDeviceSteps, // Store current raw steps
        });

        // Set user's initial step count locally
        _userInitialStepCount = currentDeviceSteps;
        _userRawSteps = currentDeviceSteps;

        // Ensure steps are initialized to zero for the challenge
        if (mounted) {
          setState(() {
            _steps = 0; // Ensure user steps start at zero
            _previousSteps = 0; // Ensure previous steps start at zero
          });
        }

        print(
          '👥 DUO CHALLENGE: Second player steps reset to 0 for challenge start',
        );
        print(
          '📊 DUO CHALLENGE: Second player initial step count: $currentDeviceSteps',
        );

        // Check if both players are ready to start the match
        final allPlayers = positions.keys.toList();
        if (allPlayers.length >= 2 && !matchStarted) {
          print('🎮 DUO CHALLENGE: Both players ready - starting match!');
          await _startMatch();
        }
      }

      // If match is already started, join the ongoing match
      if (matchStarted) {
        print('🎮 DUO CHALLENGE: Joining ongoing match');
        setState(() {
          _matchStarted = true;
        });
      }

      // Load opponent's initial step count if available
      final otherPlayerId =
          positions.keys.where((key) => key != _userId).firstOrNull;
      if (otherPlayerId != null && initialSteps.containsKey(otherPlayerId)) {
        _opponentInitialStepCount = (initialSteps[otherPlayerId] ?? 0) as int;
        _opponentRawSteps = (rawSteps[otherPlayerId] ?? 0) as int;
        print(
          '📊 DUO CHALLENGE: Loaded opponent initial step count: $_opponentInitialStepCount',
        );
        print(
          '📊 DUO CHALLENGE: Loaded opponent raw steps: $_opponentRawSteps',
        );
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
        }

        // Force immediate character visibility with proper positioning
        _userPosition = 200.0;
        _opponentPosition = 200.0;
        _opponentSteps = 0;
        _isOpponentWalking = false;

        // Ensure steps start at zero for sensor-only tracking
        _steps = 0;
        _previousSteps = 0;

        print(
          '👥 DUO CHALLENGE: Both characters forced to be visible immediately',
        );
        print(
          '👥 DUO CHALLENGE: User position: $_userPosition, Opponent position: $_opponentPosition',
        );
        print('👥 DUO CHALLENGE: Other player ID: $_otherPlayerId');
        print('👥 DUO CHALLENGE: Steps reset to zero for sensor-only tracking');
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

    // Check character data loading after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _ensureCharacterDataReady();
      }
    });
  }

  // NEW: Start the match when both players are ready
  Future<void> _startMatch() async {
    print('🎮 DUO CHALLENGE: Starting match with both players!');

    await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .update({
      'matchStarted': true,
      'matchStartTime': FieldValue.serverTimestamp(),
      'stepGoal': _stepGoal,
    });

    if (mounted) {
      setState(() {
        _matchStarted = true;
        _countdownCompleted = false; // Reset countdown state for new match
      });
    }

    // Show match start dialog with 5-second countdown
    _showMatchStartDialog();
  }

  // NEW: Show match start dialog with automatic countdown
  void _showMatchStartDialog() {
    if (_showingMatchStartDialog) return;

    setState(() {
      _showingMatchStartDialog = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '🏁 Match Starting...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7C4DFF),
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Both players are ready!',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF7C4DFF)),
                ),
                child: Text(
                  '🎯 Goal: $_stepGoal Steps',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7C4DFF),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Game will start automatically in 5 seconds...',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    // Show "🏁 Match Starting..." popup for 5 seconds, then start countdown
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        print(
          '🎮 DUO CHALLENGE: 5 seconds elapsed - closing "Match Starting..." dialog',
        );
        try {
          Navigator.of(
            context,
          ).pop(); // Close the "🏁 Match Starting..." dialog
          print(
            '🎮 DUO CHALLENGE: "Match Starting..." dialog closed successfully',
          );
        } catch (e) {
          print('🎮 DUO CHALLENGE: Error closing match start dialog: $e');
        }

        // Small delay to ensure dialog is fully closed before starting countdown
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            print(
              '🎮 DUO CHALLENGE: Starting countdown sequence after dialog close',
            );

            // Reset the match start dialog state
            setState(() {
              _showingMatchStartDialog = false;
            });

            _startCountdown(); // Start the 3-2-1 countdown
          }
        });
      }
    });
  }

  // NEW: Start countdown and automatically begin game
  void _startCountdown() {
    if (_countdownCompleted) {
      print('🎮 DUO CHALLENGE: Countdown already completed, skipping...');
      return;
    }

    print('🎮 DUO CHALLENGE: Starting countdown sequence...');

    // Use a clean timer approach to prevent loops
    _runCountdownSequence();
  }

  // NEW: Clean countdown sequence that runs only once
  void _runCountdownSequence() {
    int countdown = 3;
    bool countdownCompleted = false;

    void showCountdownNumber(int number) {
      if (!mounted || countdownCompleted) return;

      print('🎮 DUO CHALLENGE: Showing countdown number: $number');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.transparent,
            content: Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(75),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    number.toString(),
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C4DFF),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    void nextCountdownStep() {
      if (!mounted || countdownCompleted) {
        print(
          '🎮 DUO CHALLENGE: Countdown step cancelled - widget not mounted or countdown completed',
        );
        return;
      }

      if (countdown > 0) {
        // Show current number
        showCountdownNumber(countdown);

        // Schedule next number
        countdown--;
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && !countdownCompleted) {
            try {
              Navigator.of(context).pop(); // Close current number
            } catch (e) {
              print('🎮 DUO CHALLENGE: Error closing countdown number: $e');
            }
            nextCountdownStep(); // Show next number
          } else {
            print(
              '🎮 DUO CHALLENGE: Countdown step skipped - widget not mounted or countdown completed',
            );
          }
        });
      } else {
        // Countdown finished, show GO!
        countdownCompleted = true;
        print('🎮 DUO CHALLENGE: Countdown finished, showing GO!');
        _showGoMessage();
      }
    }

    // Start the countdown sequence
    nextCountdownStep();
  }

  // NEW: Begin the actual game
  void _beginGame() {
    print('🎮 DUO CHALLENGE: Game officially started!');

    setState(() {
      _showingMatchStartDialog = false;
      _countdownCompleted = true; // Mark countdown as completed
    });

    // Game is now active - both characters should be visible and step tracking enabled
    print(
      '🎮 DUO CHALLENGE: Game is now active - step tracking and character movement enabled!',
    );

    // Ensure step tracking is fully enabled
    _enableStepTracking();

    // Final confirmation that countdown sequence is complete
    print(
      '🎮 DUO CHALLENGE: Countdown sequence completed - game is fully active!',
    );
  }

  // NEW: Enable step tracking when game officially starts
  void _enableStepTracking() {
    print('🎯 DUO CHALLENGE: Step tracking officially enabled!');

    // Ensure both characters are visible and ready
    if (mounted) {
      setState(() {
        // Force both characters to be visible and in correct state
        _isUserWalking = false;
        _isOpponentWalking = false;
      });
    }

    // Sync character animations to ensure they're in idle state
    _syncCharacterAnimation();
    _syncOpponentCharacterAnimation();

    print('🎯 DUO CHALLENGE: Both characters ready for step tracking!');
  }

  // NEW: Show "GO!" message
  void _showGoMessage() {
    print('🎮 DUO CHALLENGE: Showing GO! message...');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          content: Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(90),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'GO!',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // Close after 1 second and start the game
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        print('🎮 DUO CHALLENGE: GO! message finished, starting game...');
        try {
          Navigator.of(context).pop();
        } catch (e) {
          print('🎮 DUO CHALLENGE: Error closing GO! message: $e');
        }
        _beginGame(); // Start the game after "GO!" message
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

      final positions = (data['positions'] as Map<String, dynamic>?) ?? {};

      print('📊 DUO CHALLENGE: Current positions: $positions');
      print('📊 DUO CHALLENGE: Current user ID: $_userId');

      // Load current user's data first (position only, not steps)
      if (positions.containsKey(_userId)) {
        final userPos = (positions[_userId] ?? 200.0);
        // Don't load steps from Firestore - keep sensor-only tracking
        // final userSteps = (steps[_userId] ?? 0) as int;

        if (mounted) {
          setState(() {
            _userPosition = userPos;
            // Keep steps at zero for sensor-only tracking
            // _steps = userSteps;
          });
        }

        print(
          '📊 DUO CHALLENGE: Loaded user data - Position: $userPos, Steps: $_steps (sensor-only)',
        );
      }

      // Find and load the other player's data
      final otherPlayerId =
          positions.keys.where((key) => key != _userId).firstOrNull;

      print('📊 DUO CHALLENGE: Found other player ID: $otherPlayerId');

      if (otherPlayerId != null) {
        final opponentPos = (positions[otherPlayerId] ?? 200.0);
        // Don't load opponent steps from Firestore - they should start at 0 for challenge
        // final opponentSteps = (steps[otherPlayerId] ?? 0) as int;

        print(
          '📊 DUO CHALLENGE: Found opponent data - Position: $opponentPos, Steps: 0 (challenge start)',
        );

        if (mounted) {
          setState(() {
            _opponentPosition = opponentPos;
            _opponentSteps = 0; // Always start at 0 for challenge
            _otherPlayerId = otherPlayerId;
            _isOpponentWalking = false; // Start in idle state
          });
        }

        print(
          '📊 DUO CHALLENGE: Set opponent data - _otherPlayerId: $_otherPlayerId, _opponentPosition: $_opponentPosition, _opponentSteps: $_opponentSteps',
        );

        // IMMEDIATE VISIBILITY: Ensure opponent character is immediately visible
        print(
          '👥 DUO CHALLENGE: Opponent immediately visible on game start with 0 steps!',
        );
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

      // Fallback: Ensure opponent character is visible even if document doesn't exist
      if (mounted) {
        setState(() {
          _otherPlayerId = 'waiting_for_opponent';
          _opponentPosition = 200.0;
          _opponentSteps = 0;
          _isOpponentWalking = false;
        });
        print('📊 DUO CHALLENGE: Fallback - Created placeholder opponent');
      }
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

      final positions = (data['positions'] as Map<String, dynamic>?) ?? {};

      // Ensure current user data is set (position only, not steps)
      if (positions.containsKey(_userId)) {
        final userPos = (positions[_userId] ?? 200.0);
        // Don't load steps from Firestore - keep sensor-only tracking
        // final userSteps = (steps[_userId] ?? 0) as int;

        if (mounted) {
          setState(() {
            _userPosition = userPos;
            // Keep steps at current sensor value - don't overwrite
            // _steps = userSteps;
          });
        }

        print(
          '👥 DUO CHALLENGE: User data confirmed - Position: $userPos, Steps: $_steps (sensor-only)',
        );
      }

      // IMMEDIATE VISIBILITY: Ensure opponent data is set if available
      final otherPlayerId =
          positions.keys.where((key) => key != _userId).firstOrNull;
      if (otherPlayerId != null) {
        final opponentPos = (positions[otherPlayerId] ?? 200.0);
        // Don't load opponent steps from Firestore - they should start at 0 for challenge
        // final opponentSteps = (steps[otherPlayerId] ?? 0) as int;

        if (mounted) {
          setState(() {
            _opponentPosition = opponentPos;
            _opponentSteps = 0; // Always start at 0 for challenge
            _otherPlayerId = otherPlayerId;
            _isOpponentWalking = false;
          });
        }

        print(
          '👥 DUO CHALLENGE: Opponent data confirmed - Position: $opponentPos, Steps: 0 (challenge start)',
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

    _gameStateSubscription = docRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        print('❌ DUO CHALLENGE: Document data is null');
        return;
      }

      final positions = (data['positions'] as Map<String, dynamic>?) ?? {};
      final initialSteps =
          (data['initialSteps'] as Map<String, dynamic>?) ?? {};
      final rawSteps = (data['rawSteps'] as Map<String, dynamic>?) ?? {};
      final gameEnded = data['gameEnded'] ?? false;
      final winner = data['winner'] as String?;
      final matchStarted = data['matchStarted'] ?? false;

      // NEW: Check if both players are ready and start match automatically
      if (!matchStarted && !_matchStarted) {
        final allPlayers = positions.keys.toList();
        if (allPlayers.length >= 2) {
          print(
            '🎮 DUO CHALLENGE: Both players detected - starting match automatically!',
          );
          print('🎮 DUO CHALLENGE: Player count: ${allPlayers.length}');
          print('🎮 DUO CHALLENGE: Players: $allPlayers');
          _startMatch();
          return;
        }
      }

      // NEW: Check for opponent win condition
      if (_matchStarted && !_gameEnded && !_showingWinnerDialog) {
        final otherPlayerId =
            positions.keys.where((key) => key != _userId).firstOrNull;
        if (otherPlayerId != null) {
          // Calculate opponent's challenge steps based on Firestore baseline
          int calculatedOpponentSteps = 0;
          if (initialSteps.containsKey(otherPlayerId) &&
              rawSteps.containsKey(otherPlayerId)) {
            final opponentInitialSteps =
                (initialSteps[otherPlayerId] ?? 0) as int;
            final opponentRawSteps = (rawSteps[otherPlayerId] ?? 0) as int;
            calculatedOpponentSteps = opponentRawSteps - opponentInitialSteps;

            if (calculatedOpponentSteps >= _stepGoal) {
              print(
                '😢 DUO CHALLENGE: Opponent reached step goal! Opponent wins!',
              );
              _handleOpponentWin();
              return;
            }
          }
        }
      }

      // IMMEDIATE VISIBILITY: Always check for opponent and make them visible
      final otherPlayerId =
          positions.keys.where((key) => key != _userId).firstOrNull;

      print(
        '🔍 DUO CHALLENGE: Checking for opponent - found: $otherPlayerId, current: $_otherPlayerId',
      );

      if (otherPlayerId != null) {
        final opponentPos = (positions[otherPlayerId] ?? 200.0);
        final opponentRawSteps = (rawSteps[otherPlayerId] ?? 0) as int;

        // Calculate opponent's challenge steps based on Firestore baseline
        int calculatedOpponentSteps = 0;
        if (initialSteps.containsKey(otherPlayerId)) {
          final opponentInitialSteps =
              (initialSteps[otherPlayerId] ?? 0) as int;
          calculatedOpponentSteps = opponentRawSteps - opponentInitialSteps;

          // Update opponent's initial step count if not set locally
          if (_opponentInitialStepCount == null) {
            _opponentInitialStepCount = opponentInitialSteps;
            print(
              '📊 DUO CHALLENGE: Set opponent initial step count: $_opponentInitialStepCount',
            );
          }
        }

        // Update opponent's raw steps
        _opponentRawSteps = opponentRawSteps;

        print(
          '📊 DUO CHALLENGE: Real-time update - Opponent ID: $otherPlayerId, Position: $opponentPos',
        );
        print(
          '📊 DUO CHALLENGE: Opponent raw steps: $opponentRawSteps, initial steps: ${initialSteps[otherPlayerId] ?? 0}',
        );
        print(
          '📊 DUO CHALLENGE: Calculated opponent challenge steps: $calculatedOpponentSteps',
        );

        // CRITICAL FIX: Always ensure opponent is visible, regardless of state changes
        bool shouldUpdateOpponent = false;

        // Case 1: New opponent joined (different ID)
        if (_otherPlayerId != otherPlayerId) {
          print(
            '👥 DUO CHALLENGE: NEW OPPONENT JOINED - Making immediately visible!',
          );
          shouldUpdateOpponent = true;

          // Load opponent's character data when they join
          await _loadOpponentCharacterData(otherPlayerId);

          // Ensure character data is loaded before updating state
          if (_opponentCharacterData != null) {
            print(
                '✅ DUO CHALLENGE: Opponent character data loaded successfully');
          } else {
            print(
                '⚠️ DUO CHALLENGE: Opponent character data failed to load, using fallback');
          }
        }
        // Case 2: Same opponent but data changed
        else if (_opponentPosition != opponentPos ||
            _opponentSteps != calculatedOpponentSteps) {
          print(
            '📊 DUO CHALLENGE: Existing opponent data changed - Position: $_opponentPosition -> $opponentPos, Steps: $_opponentSteps -> $calculatedOpponentSteps',
          );
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
          // Determine if opponent is walking based on step changes (like Solo Mode)
          bool opponentIsWalking = false;
          if (_otherPlayerId == otherPlayerId &&
              _opponentSteps != calculatedOpponentSteps) {
            opponentIsWalking = calculatedOpponentSteps > _opponentSteps;
            print(
              '👟 DUO CHALLENGE: Opponent steps changed: $_opponentSteps -> $calculatedOpponentSteps, walking: $opponentIsWalking',
            );
          }

          // Only update state if values actually changed to prevent unnecessary rebuilds
          bool needsStateUpdate = false;
          if (_opponentPosition != opponentPos ||
              _opponentSteps != calculatedOpponentSteps ||
              _otherPlayerId != otherPlayerId ||
              _isOpponentWalking != opponentIsWalking) {
            needsStateUpdate = true;
          }

          if (needsStateUpdate && mounted) {
            setState(() {
              _opponentPosition = opponentPos;
              _opponentSteps = calculatedOpponentSteps;
              _otherPlayerId = otherPlayerId;
              _isOpponentWalking = opponentIsWalking;
            });
          }

          // Update opponent character animation immediately with smooth transitions
          _updateOpponentCharacterAnimation(opponentIsWalking);

          print(
            '👥 DUO CHALLENGE: Opponent now visible with position: $opponentPos, steps: $calculatedOpponentSteps, walking: $opponentIsWalking',
          );

          // If opponent was walking, stop after a short delay for smooth animation (like Solo Mode)
          if (opponentIsWalking) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && _isOpponentWalking == true) {
                setState(() {
                  _isOpponentWalking = false;
                });
                _updateOpponentCharacterAnimation(false);
                print(
                  '🎬 DUO CHALLENGE: Opponent walking animation stopped after delay',
                );
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
          });
        }
        _showWinnerDialog(winner);
      }
    });
  }

  Future<void> _loadOpponentCharacterData(String opponentId) async {
    print('🎭 DUO CHALLENGE: Loading character data for opponent: $opponentId');

    try {
      _opponentCharacterData =
          await _characterDataService.getUserCharacterData(opponentId);
      print(
          '✅ DUO CHALLENGE: Loaded opponent character data: ${_opponentCharacterData!['currentCharacter']}');
      print(
          '🎭 DUO CHALLENGE: Opponent sprite sheets: ${_opponentCharacterData!['spriteSheets']}');

      // Verify the opponent sprite sheets are properly loaded from Firestore
      if (_opponentCharacterData!['spriteSheets'] == null) {
        print(
            '⚠️ DUO CHALLENGE: Opponent sprite sheets are null, using fallback');
        _opponentCharacterData!['spriteSheets'] = {
          'idle': 'images/sprite_sheets/MyCharacter_idle.json',
          'walking': 'images/sprite_sheets/MyCharacter_walking.json',
        };
      }

      // Preload opponent character animations
      final animationService = CharacterAnimationService();
      final opponentCharacterId =
          '${opponentId}_${_opponentCharacterData!['currentCharacter']}';

      print(
          '🎭 DUO CHALLENGE: Preloading opponent animations for ID: $opponentCharacterId');
      print(
          '🎭 DUO CHALLENGE: Opponent sprite sheets to load: ${_opponentCharacterData!['spriteSheets']}');

      await animationService.preloadAnimationsForCharacterWithData(
          opponentCharacterId, _opponentCharacterData!);
      print(
          '✅ DUO CHALLENGE: Preloaded opponent character animations for ${_opponentCharacterData!['currentCharacter']}');
    } catch (e) {
      print('❌ DUO CHALLENGE: Error loading opponent character data: $e');
      print('❌ DUO CHALLENGE: Stack trace: ${StackTrace.current}');

      // Use fallback character data
      _opponentCharacterData = {
        'owned_items': ['MyCharacter'],
        'currentCharacter': 'MyCharacter',
        'homeGlbPath': 'assets/web/home/MyCharacter_home.glb',
        'spriteSheets': {
          'idle': 'images/sprite_sheets/MyCharacter_idle.json',
          'walking': 'images/sprite_sheets/MyCharacter_walking.json',
        },
      };
    }

    // Trigger rebuild to update character sprites
    if (mounted) {
      setState(() {
        // Force rebuild to show the new opponent character
      });
      print('🎭 DUO CHALLENGE: Opponent character data updated in UI');
      print(
          '🎭 DUO CHALLENGE: Final opponent sprite sheets after update: ${_opponentCharacterData!['spriteSheets']}');
    }
  }

  // NEW: Force reload character data if loading fails
  Future<void> _forceReloadCharacterData() async {
    print('🔄 DUO CHALLENGE: Force reloading character data...');

    try {
      // Clear existing data
      _userCharacterData = null;
      _opponentCharacterData = null;
      _characterDataLoaded = false;

      // Reload character data
      await _preloadCharacters();

      print('✅ DUO CHALLENGE: Character data force reload completed');
    } catch (e) {
      print('❌ DUO CHALLENGE: Error in force reload: $e');
    }
  }

  Future<void> _preloadCharacters() async {
    print('🎭 DUO CHALLENGE: Preloading character data for both players...');

    // Load current user's character data in background (don't block UI)
    _loadUserCharacterDataInBackground();

    // Load opponent's character data in background (don't block UI)
    _loadOpponentCharacterDataInBackground();

    // Preload animations in background
    _preloadAnimationsInBackground();
  }

  // Load user character data in background
  Future<void> _loadUserCharacterDataInBackground() async {
    try {
      print('🎭 DUO CHALLENGE: Loading user character data from Firestore...');
      final userData =
          await _characterDataService.getCurrentUserCharacterData();
      print(
          '✅ DUO CHALLENGE: Loaded user character data: ${userData['currentCharacter']}');
      print(
          '🎭 DUO CHALLENGE: User sprite sheets from Firestore: ${userData['spriteSheets']}');
      print('🎭 DUO CHALLENGE: User owned items: ${userData['owned_items']}');

      if (mounted) {
        setState(() {
          _userCharacterData = userData;
        });
        print('✅ DUO CHALLENGE: Updated user character data in UI');
        print(
            '🎭 DUO CHALLENGE: Current user sprite sheets in UI: ${_userCharacterData!['spriteSheets']}');
      }
    } catch (e) {
      print('❌ DUO CHALLENGE: Error loading user character data: $e');
      print(
          '🎭 DUO CHALLENGE: Keeping fallback user sprite sheets: ${_userCharacterData!['spriteSheets']}');
      // Keep existing fallback data
    }
  }

  // Load opponent character data in background
  Future<void> _loadOpponentCharacterDataInBackground() async {
    if (_otherPlayerId != null && _otherPlayerId != 'waiting_for_opponent') {
      try {
        print(
            '🎭 DUO CHALLENGE: Loading opponent character data from Firestore for ID: $_otherPlayerId');
        final opponentData =
            await _characterDataService.getUserCharacterData(_otherPlayerId!);
        print(
            '✅ DUO CHALLENGE: Loaded opponent character data: ${opponentData['currentCharacter']}');
        print(
            '🎭 DUO CHALLENGE: Opponent sprite sheets from Firestore: ${opponentData['spriteSheets']}');
        print(
            '🎭 DUO CHALLENGE: Opponent owned items: ${opponentData['owned_items']}');

        if (mounted) {
          setState(() {
            _opponentCharacterData = opponentData;
          });
          print('✅ DUO CHALLENGE: Updated opponent character data in UI');
          print(
              '🎭 DUO CHALLENGE: Current opponent sprite sheets in UI: ${_opponentCharacterData!['spriteSheets']}');
        }
      } catch (e) {
        print('❌ DUO CHALLENGE: Error loading opponent character data: $e');
        print(
            '🎭 DUO CHALLENGE: Keeping fallback opponent sprite sheets: ${_opponentCharacterData!['spriteSheets']}');
        // Keep existing fallback data
      }
    } else {
      print(
          '🎭 DUO CHALLENGE: No opponent ID available, keeping fallback opponent sprite sheets: ${_opponentCharacterData!['spriteSheets']}');
    }
  }

  // Preload animations in background
  Future<void> _preloadAnimationsInBackground() async {
    try {
      final animationService = CharacterAnimationService();

      // Preload user character animations
      final userCharacterId =
          '${_userId}_${_userCharacterData!['currentCharacter']}';
      print(
          '🎭 DUO CHALLENGE: Preloading user animations for ID: $userCharacterId');
      print(
          '🎭 DUO CHALLENGE: User sprite sheets for animation: ${_userCharacterData!['spriteSheets']}');
      await animationService.preloadAnimationsForCharacterWithData(
          userCharacterId, _userCharacterData!);
      print('✅ DUO CHALLENGE: Preloaded user character animations');

      // Preload opponent character animations
      final opponentCharacterId =
          '${_otherPlayerId ?? 'opponent'}_${_opponentCharacterData!['currentCharacter']}';
      print(
          '🎭 DUO CHALLENGE: Preloading opponent animations for ID: $opponentCharacterId');
      print(
          '🎭 DUO CHALLENGE: Opponent sprite sheets for animation: ${_opponentCharacterData!['spriteSheets']}');
      await animationService.preloadAnimationsForCharacterWithData(
          opponentCharacterId, _opponentCharacterData!);
      print('✅ DUO CHALLENGE: Preloaded opponent character animations');
    } catch (e) {
      print('❌ DUO CHALLENGE: Error preloading character animations: $e');
      print(
          '🎭 DUO CHALLENGE: User sprite sheets at error: ${_userCharacterData!['spriteSheets']}');
      print(
          '🎭 DUO CHALLENGE: Opponent sprite sheets at error: ${_opponentCharacterData!['spriteSheets']}');
    }

    // Final summary of sprite sheets
    print('🎭 DUO CHALLENGE: SPRITE SHEET SUMMARY:');
    print(
        '🎭 DUO CHALLENGE: User character: ${_userCharacterData!['currentCharacter']}');
    print(
        '🎭 DUO CHALLENGE: User sprite sheets: ${_userCharacterData!['spriteSheets']}');
    print(
        '🎭 DUO CHALLENGE: Opponent character: ${_opponentCharacterData!['currentCharacter']}');
    print(
        '🎭 DUO CHALLENGE: Opponent sprite sheets: ${_opponentCharacterData!['spriteSheets']}');
  }

  void _initializeStepTracking() async {
    print(
      '🏁 DUO CHALLENGE: Initializing StepCounterService-based step tracking for challenge...',
    );

    try {
      // Force reset walking state to ensure correct initial state
      if (mounted) {
        setState(() {
          _isUserWalking = false;
          _lastStepUpdate = null; // Reset step history
          _steps = 0; // Start from zero
          _previousSteps = 0; // Start from zero
        });
      }

      // Set up StepCounterService stream listener
      _setupStepCounterServiceListener();

      // Force walking state to false after initialization
      if (mounted) {
        setState(() {
          _isUserWalking = false;
        });
      }
      print('🔄 DUO CHALLENGE: Force reset walking state after initialization');

      // Force character to idle state during initialization
      if (_userGameInstance?.character != null) {
        _userGameInstance!.character!.isWalking = false;
        _userGameInstance!.character!.updateAnimation(false);
        print('🎬 DUO CHALLENGE: Forced character to idle state');
      }

      // Start continuous monitoring for idle detection
      _startContinuousMonitoring();

      print(
        '✅ DUO CHALLENGE: StepCounterService-based step tracking initialized',
      );
      print('🎯 DUO CHALLENGE: Step goal set to: $_stepGoal steps');
    } catch (e) {
      print('❌ DUO CHALLENGE: Error initializing step tracking: $e');
      // Fallback to periodic polling
      _startPeriodicUpdates();
    }
  }

  void _setupStepCounterServiceListener() {
    print('📱 DUO CHALLENGE: Setting up StepCounterService stream listener...');

    _stepSubscription = StepCounterService.stepStream.listen(
      (data) async {
        if (data['type'] == 'step_update') {
          final currentSteps = data['currentSteps'] as int;
          final timestamp = data['timestamp'] as DateTime;

          // Update user's raw steps
          _userRawSteps = currentSteps;

          // Calculate challenge-specific steps using Firestore baseline
          int challengeSteps = 0;
          if (_userInitialStepCount != null) {
            challengeSteps = currentSteps - _userInitialStepCount!;
          }

          if (mounted) {
            setState(() {
              _previousSteps = _steps;
              _steps = challengeSteps;
            });

            _checkUserWalkingWithTiming(timestamp);
            _syncCharacterAnimation();
            await _updateStepsInFirestore(); // Firestore sync
          }

          print(
            '🏥 DUO CHALLENGE StepCounterService update: Device Steps: $currentSteps, Challenge Steps: $challengeSteps (Baseline: $_userInitialStepCount)',
          );
        }
      },
      onError: (error) {
        print('❌ DUO CHALLENGE: Error in step stream: $error');
      },
    );

    print(
      '✅ DUO CHALLENGE: StepCounterService stream listener set up with Firestore baseline tracking',
    );
  }

  Future<void> _updateStepsInFirestore() async {
    await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .update({
      'steps.$_userId': _steps,
      'rawSteps.$_userId':
          _userRawSteps, // Update raw steps for opponent calculation
    });
    print(
      '📊 DUO CHALLENGE: Updated steps in Firestore: $_steps (raw: $_userRawSteps)',
    );
  }

  void _startPeriodicUpdates() {
    // APPROACH 5: More frequent updates with aggressive sync (like Solo Mode)
    Future.delayed(const Duration(seconds: 5), () {
      // 5-second interval to ensure reliability
      if (mounted) {
        // StepCounterService handles step updates via stream - no need to fetch here

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

  void _startOpponentAnimationMonitoring() {
    // Monitor opponent character animation every 2 seconds to prevent excessive updates
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkOpponentAnimationSync();
        _startOpponentAnimationMonitoring(); // Recursive call
      }
    });
  }

  void _checkOpponentAnimationSync() {
    // Ensure opponent character animation matches walking state (like Solo Mode)
    if (_opponentGameInstance?.character != null) {
      final characterIsWalking = _opponentGameInstance!.character!.isWalking;
      if (characterIsWalking != _isOpponentWalking) {
        print(
          '🎬 DUO CHALLENGE OPPONENT SYNC: Character walking ($characterIsWalking) != Opponent walking ($_isOpponentWalking) - FORCING SYNC',
        );

        // Force correct state
        _opponentGameInstance!.character!.isWalking = _isOpponentWalking;
        _opponentGameInstance!.character!.updateAnimation(_isOpponentWalking);

        // Force animation directly if still not synced
        if (!_isOpponentWalking &&
            _opponentGameInstance!.character!.idleAnimation != null) {
          print(
            '🎬 DUO CHALLENGE OPPONENT FORCE: Directly setting opponent idle animation',
          );
          _opponentGameInstance!.character!.animation =
              _opponentGameInstance!.character!.idleAnimation;
        }

        print(
          '✅ DUO CHALLENGE OPPONENT SYNC: Opponent character animation synced',
        );
      } else {
        print(
          '🎬 DUO CHALLENGE OPPONENT SYNC: Animation already in sync, no update needed',
        );
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
    // Monitor opponent character animation every 500ms for smooth updates
    _startOpponentAnimationMonitoring();
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
      // Only force animation if there's a mismatch to prevent unnecessary updates
      if (mounted && _userGameInstance?.character != null) {
        final characterIsWalking = _userGameInstance!.character!.isWalking;
        if (characterIsWalking != walking) {
          print(
            '🔄 DUO CHALLENGE: Animation mismatch detected, forcing sync to ${walking ? "walking" : "idle"}',
          );
          walking ? _startCharacterWalking() : _stopCharacterWalking();
          _userGameInstance!.character!.updateAnimation(walking);
        } else {
          print('🎬 DUO CHALLENGE: Animation already correct, no force needed');
        }
      }
    }
  }

  void _moveUserForward() async {
    if (_gameEnded) return;

    // Move user forward with step-based increment
    const double moveIncrement =
        25.0; // Larger increment for step-based movement
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

    // NEW: Check for win condition if match has started
    if (_matchStarted &&
        _steps >= _stepGoal &&
        !_gameEnded &&
        !_showingWinnerDialog) {
      print('🏆 DUO CHALLENGE: User reached step goal! User wins!');
      _handleUserWin();
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

    // 5-SECOND IDLE DETECTION: Only check timeout if currently walking
    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep = now.difference(_lastStepUpdate!).inSeconds;
      print('⏰ DUO CHALLENGE: Time since last step: ${timeSinceLastStep}s');

      if (timeSinceLastStep >= 5) {
        // Force idle after exactly 5 seconds of no steps
        print(
          '⏰ DUO CHALLENGE: 5-SECOND TIMEOUT: No steps for ${timeSinceLastStep}s, FORCING IDLE',
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

  // NEW: Handle user win
  Future<void> _handleUserWin() async {
    if (_showingWinnerDialog) return;

    setState(() {
      _showingWinnerDialog = true;
      _gameEnded = true;
    });

    print('🏆 DUO CHALLENGE: User won the challenge!');

    // Award coins to winner
    const int winnerCoins = 50;
    final coinService = CoinService();
    await coinService.addCoins(winnerCoins);

    // Update Firestore with match result
    await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .update({
      'gameEnded': true,
      'winner': _userId,
      'winnerUsername': 'You',
      'loser': _otherPlayerId,
      'loserUsername': widget.otherUsername ?? 'Opponent',
      'winnerSteps': _steps,
      'loserSteps': _opponentSteps,
      'winnerCoins': winnerCoins,
      'matchEndTime': FieldValue.serverTimestamp(),
    });

    // Show winner dialog
    _showWinnerDialog(_userId);
  }

  // NEW: Handle opponent win
  void _handleOpponentWin() {
    if (_showingWinnerDialog) return;

    setState(() {
      _showingWinnerDialog = true;
      _gameEnded = true;
    });

    print('😢 DUO CHALLENGE: Opponent won the challenge');

    // Show loser dialog
    _showLoserDialog();
  }

  // NEW: Show loser dialog
  void _showLoserDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('😢 You Lost'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.otherUsername ?? 'Opponent'} reached $_stepGoal steps first!',
              ),
              const SizedBox(height: 16),
              const Text('Better luck next time!'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                try {
                  Navigator.of(context).pop();
                } catch (e) {
                  print('🎮 DUO CHALLENGE: Error closing loser dialog: $e');
                }
                _returnToHome();
              },
              child: const Text('Back to Home'),
            ),
          ],
        );
      },
    );
  }

  // NEW: Show quit confirmation dialog
  void _showQuitConfirmation() {
    if (_showingQuitDialog) return;

    setState(() {
      _showingQuitDialog = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ Quit Challenge?'),
          content: const Text(
            'Are you sure you want to quit? Your opponent will win and you will lose the match.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                try {
                  Navigator.of(context).pop();
                } catch (e) {
                  print(
                    '🎮 DUO CHALLENGE: Error closing quit confirmation dialog: $e',
                  );
                }
                setState(() {
                  _showingQuitDialog = false;
                });
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                try {
                  Navigator.of(context).pop();
                } catch (e) {
                  print(
                    '🎮 DUO CHALLENGE: Error closing quit confirmation dialog: $e',
                  );
                }
                _handleUserQuit();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Quit'),
            ),
          ],
        );
      },
    );
  }

  // NEW: Handle user quit
  Future<void> _handleUserQuit() async {
    print('🚪 DUO CHALLENGE: User quit the challenge');

    // Award coins to opponent
    const int winnerCoins = 50;

    // Update Firestore with quit result
    await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .update({
      'gameEnded': true,
      'winner': _otherPlayerId,
      'winnerUsername': widget.otherUsername ?? 'Opponent',
      'loser': _userId,
      'loserUsername': 'You',
      'winnerSteps': _opponentSteps,
      'loserSteps': _steps,
      'winnerCoins': winnerCoins,
      'quitBy': _userId,
      'matchEndTime': FieldValue.serverTimestamp(),
    });

    // Show quit confirmation
    _showQuitConfirmationDialog();
  }

  // NEW: Show quit confirmation dialog
  void _showQuitConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🚪 Challenge Quit'),
          content: const Text(
            'You have quit the challenge. Your opponent wins by default.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                try {
                  Navigator.of(context).pop();
                } catch (e) {
                  print(
                    '🎮 DUO CHALLENGE: Error closing quit confirmation dialog: $e',
                  );
                }
                _returnToHome();
              },
              child: const Text('Back to Home'),
            ),
          ],
        );
      },
    );
  }

  // NEW: Return to home screen
  void _returnToHome() {
    try {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      print('🎮 DUO CHALLENGE: Error returning to home: $e');
      // Fallback: try to pop once
      try {
        Navigator.of(context).pop();
      } catch (e2) {
        print('🎮 DUO CHALLENGE: Error with fallback pop: $e2');
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

    // Also sync opponent character animation
    _syncOpponentCharacterAnimation();
  }

  void _syncOpponentCharacterAnimation() {
    // Sync opponent character animation with the same aggressive approach (like Solo Mode)
    if (_opponentGameInstance != null) {
      // Force update walking state
      _opponentGameInstance!.updateWalkingState(_isOpponentWalking);

      // Additional check - ensure opponent character state is correct
      if (_opponentGameInstance!.character != null) {
        final characterIsWalking = _opponentGameInstance!.character!.isWalking;
        if (characterIsWalking != _isOpponentWalking) {
          print(
            '🔄 DUO CHALLENGE: Opponent character state mismatch: character=$characterIsWalking, should=$_isOpponentWalking',
          );
          // Force correct state
          _opponentGameInstance!.updateWalkingState(_isOpponentWalking);
        }
      }

      print(
        '✅ DUO CHALLENGE: Opponent character animation synced (Solo Mode style): ${_isOpponentWalking ? "Walking" : "Idle"}',
      );
    } else {
      print(
        '⚠️ DUO CHALLENGE: Opponent game instance not available for animation sync',
      );
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

  void _updateOpponentCharacterAnimation(bool walking) {
    if (_opponentGameInstance != null &&
        _opponentGameInstance!.character != null) {
      // Debounce animation updates to prevent flickering
      final now = DateTime.now();
      if (_lastOpponentAnimationUpdate != null &&
          now.difference(_lastOpponentAnimationUpdate!) <
              _animationDebounceTime) {
        print(
          '🎬 DUO CHALLENGE: Opponent animation update debounced to prevent flickering',
        );
        return;
      }

      // Only update if the walking state actually changed to prevent blinking
      if (_opponentGameInstance!.character!.isWalking != walking) {
        print(
          '🎬 DUO CHALLENGE: Updating opponent character animation to ${walking ? "walking" : "idle"}',
        );

        // Apply the same smooth animation logic as Solo Mode
        _opponentGameInstance!.updateWalkingState(walking);
        _opponentGameInstance!.character!.isWalking = walking;
        _opponentGameInstance!.character!.updateAnimation(walking);

        // Force animation sync like Solo Mode (but only if needed)
        if (!walking &&
            _opponentGameInstance!.character!.idleAnimation != null) {
          print('🎬 DUO CHALLENGE: Force setting opponent idle animation');
          _opponentGameInstance!.character!.animation =
              _opponentGameInstance!.character!.idleAnimation;
        }

        _lastOpponentAnimationUpdate = now;
        print(
          '✅ DUO CHALLENGE: Opponent character animation updated successfully',
        );
      } else {
        print(
          '🎬 DUO CHALLENGE: Opponent animation state unchanged, skipping update to prevent blinking',
        );
      }
    } else {
      print(
        '⚠️ DUO CHALLENGE: Opponent game instance or character not available for animation update',
      );
    }
  }

  // NEW: Verify character data is ready
  bool _isCharacterDataReady() {
    // Since we always provide fallback data in initState, this should always be true
    if (!_characterDataLoaded) {
      print('⚠️ DUO CHALLENGE: Character data not loaded yet');
      return false;
    }

    print('✅ DUO CHALLENGE: Character data is ready');
    return true;
  }

  Widget _buildGameWidget({
    required bool isPlayer1,
    required bool isWalking,
    required String userId,
    required double characterWidth,
    required double characterHeight,
    required bool isUser,
  }) {
    // Get character data for this specific character
    Map<String, dynamic>? characterData;
    if (isUser) {
      characterData = _userCharacterData;
      print(
          '🎭 DUO CHALLENGE: Building user character widget with data: ${characterData?['currentCharacter'] ?? 'null'}');
      print(
          '🎭 DUO CHALLENGE: User sprite sheets in widget build: ${characterData?['spriteSheets']}');
    } else {
      characterData = _opponentCharacterData;
      print(
          '🎭 DUO CHALLENGE: Building opponent character widget with data: ${characterData?['currentCharacter'] ?? 'null'}');
      print(
          '🎭 DUO CHALLENGE: Opponent sprite sheets in widget build: ${characterData?['spriteSheets']}');
    }

    // Ensure character data is available, use fallback if not
    if (characterData == null) {
      print('⚠️ DUO CHALLENGE: Character data is null, using fallback data');
      characterData = {
        'owned_items': ['MyCharacter'],
        'currentCharacter': 'MyCharacter',
        'homeGlbPath': 'assets/web/home/MyCharacter_home.glb',
        'spriteSheets': {
          'idle': 'images/sprite_sheets/MyCharacter_idle.json',
          'walking': 'images/sprite_sheets/MyCharacter_walking.json',
        },
      };
    }

    // Ensure sprite sheets are available
    if (characterData['spriteSheets'] == null) {
      print('⚠️ DUO CHALLENGE: Sprite sheets missing, using fallback');
      characterData['spriteSheets'] = {
        'idle': 'images/sprite_sheets/MyCharacter_idle.json',
        'walking': 'images/sprite_sheets/MyCharacter_walking.json',
      };
    }

    // Ensure currentCharacter is available
    if (characterData['currentCharacter'] == null) {
      print('⚠️ DUO CHALLENGE: currentCharacter missing, using fallback');
      characterData['currentCharacter'] = 'MyCharacter';
    }

    print(
        '🎭 DUO CHALLENGE: Final character data for widget: ${characterData['currentCharacter']}');
    print(
        '🎭 DUO CHALLENGE: Final sprite sheets: ${characterData['spriteSheets']}');
    print(
        '🎭 DUO CHALLENGE: Widget build complete for ${isUser ? 'user' : 'opponent'} character');

    final game = CharacterDisplayGame(
      isPlayer1: isPlayer1,
      isWalking: isWalking,
      userId: userId,
      faceRight: true,
      characterWidth: characterWidth,
      characterHeight: characterHeight,
      characterData: characterData,
    );

    // Store the game instance
    if (isUser) {
      print('🎮 DUO CHALLENGE: Setting _userGameInstance for user character');
      _userGameInstance = game;

      // Ensure user character starts with correct animation state
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _userGameInstance?.character != null) {
          print(
            '🎬 DUO CHALLENGE: Initializing user character animation state',
          );
          _userGameInstance!.character!.isWalking = _isUserWalking;
          _userGameInstance!.character!.updateAnimation(_isUserWalking);
        }
      });
    } else {
      print(
        '🎮 DUO CHALLENGE: Setting _opponentGameInstance for opponent character',
      );
      _opponentGameInstance = game;

      // Ensure opponent character starts with correct animation state
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _opponentGameInstance?.character != null) {
          print(
            '🎬 DUO CHALLENGE: Initializing opponent character animation state',
          );
          _opponentGameInstance!.character!.isWalking = _isOpponentWalking;
          _opponentGameInstance!.character!.updateAnimation(_isOpponentWalking);
        }
      });
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
    final isUserWinner = winnerId == _userId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isUserWinner ? '🎉 You Win!' : '🏆 Race Complete!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUserWinner) ...[
                const Text('Congratulations! You reached the step goal first!'),
                const SizedBox(height: 16),
                const Text(
                  '+50 Coins',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ] else ...[
                Text('Winner is $winnerUsername!'),
              ],
              const SizedBox(height: 16),
              const Text('Returning to home in 3 seconds...'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                try {
                  Navigator.of(context).pop(); // Close dialog
                } catch (e) {
                  print('🎮 DUO CHALLENGE: Error closing winner dialog: $e');
                }
                _returnToHome();
              },
              child: const Text('Back to Home'),
            ),
          ],
        );
      },
    );

    // Auto-return to home after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        try {
          Navigator.of(context).pop(); // Close dialog
        } catch (e) {
          print('🎮 DUO CHALLENGE: Error auto-closing winner dialog: $e');
        }
        _returnToHome();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Duo Challenge Race'),
        backgroundColor: const Color(0xFF7C4DFF),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_gameEnded) {
              _returnToHome();
            } else {
              _showQuitConfirmation();
            }
          },
        ),
        actions: [
          if (!_gameEnded)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _showQuitConfirmation,
              tooltip: 'Quit Challenge',
            ),
        ],
      ),
      body: _buildRacingTrack(),
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
    const double characterWidth = 280;
    const double characterHeight = 280;
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
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
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
                Positioned(
                  left: _opponentPosition -
                      (characterWidth / 2), // Position based on track location
                  top: roadTopY - characterHeight + 100, // Feet on road
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // The label, positioned exactly at the top of the character
                      Positioned(
                        top: 0,
                        child: nameLabel(
                          _otherPlayerId == null ||
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
                          userId: _otherPlayerId == null ||
                                  _otherPlayerId == 'waiting_for_opponent'
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
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
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
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Step goal indicator - always visible
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF7C4DFF)),
                  ),
                  child: Text(
                    '🎯 Goal: $_stepGoal Steps',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C4DFF),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Text labels with descriptive step format
                Column(
                  children: [
                    // Your steps
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your steps:',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C4DFF),
                          ),
                        ),
                        Text(
                          '$_steps',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C4DFF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Friend's steps
                    if (_otherPlayerId != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_otherPlayerId == 'waiting_for_opponent' ? 'Waiting...' : (widget.otherUsername ?? 'Opponent')} steps:',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            '$_opponentSteps',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
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

  // NEW: Force reload character data if not ready
  Future<void> _ensureCharacterDataReady() async {
    if (!_isCharacterDataReady()) {
      print('🔄 DUO CHALLENGE: Character data not ready, forcing reload...');
      await _forceReloadCharacterData();
    }
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
  final Map<String, dynamic>? characterData;
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
    this.characterData,
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

    try {
      // No background layers here, only character (like Solo Mode)
      character = Character(userId: userId, characterData: characterData);
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
  final Map<String, dynamic>? characterData;
  SpriteAnimation? idleAnimation;
  SpriteAnimation? walkingAnimation;
  bool isWalking = false;
  double moveSpeed =
      100.0; // Reduced speed for smoother movement (like Solo Mode)
  bool _animationsLoaded = false;

  Character({required this.userId, this.characterData})
      : super(
          size: Vector2(300, 300),
        ); // Reduced size for better performance (like Solo Mode)

  @override
  Future<void> onLoad() async {
    print('DUO Character onLoad start for userId: $userId');
    print('DUO Character onLoad: characterData: $characterData');
    print(
        'DUO Character onLoad: characterData spriteSheets: ${characterData?['spriteSheets']}');
    print(
        'DUO Character onLoad: characterData currentCharacter: ${characterData?['currentCharacter']}');

    try {
      // Ensure character data is available
      if (characterData == null) {
        print(
            '⚠️ DUO Character onLoad: Character data is null, using fallback');
        // Create a fallback character data
        final fallbackData = {
          'owned_items': ['MyCharacter'],
          'currentCharacter': 'MyCharacter',
          'homeGlbPath': 'assets/web/home/MyCharacter_home.glb',
          'spriteSheets': {
            'idle': 'images/sprite_sheets/MyCharacter_idle.json',
            'walking': 'images/sprite_sheets/MyCharacter_walking.json',
          },
        };

        // Load fallback animations
        final animationService = CharacterAnimationService();
        await animationService.preloadAnimations();
        final defaultAnimations = await animationService.getAnimations();
        idleAnimation = defaultAnimations['idle'];
        walkingAnimation = defaultAnimations['walking'];
        _animationsLoaded = true;

        if (_animationsLoaded && idleAnimation != null) {
          animation = idleAnimation;
          print(
              'DUO Character onLoad: Fallback animations loaded successfully');
        }
        return;
      }

      // Load character-specific animations using the new multi-character service
      final animationService = CharacterAnimationService();

      // Create a unique character ID for this character instance
      final characterId =
          '${userId}_${characterData!['currentCharacter'] ?? 'default'}';

      print('DUO Character onLoad: Character ID: $characterId');
      print(
          'DUO Character onLoad: Character sprite sheets: ${characterData!['spriteSheets']}');

      try {
        // Load animations for this specific character using the character data
        if (characterData!['currentCharacter'] != null) {
          print(
              'DUO Character onLoad: Preloading animations for ${characterData!['currentCharacter']}');
          await animationService.preloadAnimationsForCharacterWithData(
              characterId, characterData!);
          print(
              'DUO Character onLoad: Preloaded character-specific animations for ${characterData!['currentCharacter']} (ID: $characterId)');
        } else {
          // Use default animations for current user
          print(
              'DUO Character onLoad: Using default animations for current user');
          await animationService.preloadAnimations();
        }

        // Get animations for this specific character
        print(
            'DUO Character onLoad: Getting animations for character ID: $characterId');
        final animations =
            await animationService.getAnimationsForCharacter(characterId);
        idleAnimation = animations['idle'];
        walkingAnimation = animations['walking'];
        _animationsLoaded = true;

        print(
            'DUO Character onLoad: Loaded character-specific animations for ${characterData!['currentCharacter'] ?? 'default'} (ID: $characterId)');
        print(
            'DUO Character onLoad: Idle animation loaded: ${idleAnimation != null}');
        print(
            'DUO Character onLoad: Walking animation loaded: ${walkingAnimation != null}');
        print(
            'DUO Character onLoad: Final sprite sheets used: ${characterData!['spriteSheets']}');
      } catch (e) {
        print('DUO Character onLoad: Error loading character animations: $e');
        print('DUO Character onLoad: Stack trace: ${StackTrace.current}');

        // Fallback to default animations
        try {
          print(
              'DUO Character onLoad: Trying fallback to default animations...');
          await animationService.preloadAnimations();
          final defaultAnimations = await animationService.getAnimations();
          idleAnimation = defaultAnimations['idle'];
          walkingAnimation = defaultAnimations['walking'];
          _animationsLoaded = true;
          print('DUO Character onLoad: Using fallback default animations');
          print(
              'DUO Character onLoad: Fallback idle animation loaded: ${idleAnimation != null}');
          print(
              'DUO Character onLoad: Fallback walking animation loaded: ${walkingAnimation != null}');
        } catch (fallbackError) {
          print(
              'DUO Character onLoad: Fallback animation loading also failed: $fallbackError');
          print(
              'DUO Character onLoad: Fallback stack trace: ${StackTrace.current}');
          _animationsLoaded = false;
        }
      }

      if (_animationsLoaded && idleAnimation != null) {
        animation = idleAnimation;
        print('DUO Character onLoad: Animation set to idle animation');
      } else {
        print(
            'DUO Character onLoad: WARNING - No animations loaded, character may not display properly');
        print('DUO Character onLoad: _animationsLoaded: $_animationsLoaded');
        print('DUO Character onLoad: idleAnimation: $idleAnimation');
        print('DUO Character onLoad: walkingAnimation: $walkingAnimation');
      }

      print('DUO Character onLoad success');
    } catch (e, st) {
      print('DUO Character onLoad error: $e');
      print('DUO Character onLoad stack trace: $st');

      // Final fallback - try to load default animations even if everything else fails
      try {
        final animationService = CharacterAnimationService();
        await animationService.preloadAnimations();
        final defaultAnimations = await animationService.getAnimations();
        idleAnimation = defaultAnimations['idle'];
        walkingAnimation = defaultAnimations['walking'];
        _animationsLoaded = true;

        if (_animationsLoaded && idleAnimation != null) {
          animation = idleAnimation;
          print('DUO Character onLoad: Final fallback animations loaded');
        }
      } catch (finalError) {
        print('DUO Character onLoad: Final fallback also failed: $finalError');
        _animationsLoaded = false;
      }
    }
  }

  void updateAnimation(bool walking) {
    if (!_animationsLoaded ||
        idleAnimation == null ||
        walkingAnimation == null) {
      print('⚠️ DUO Character updateAnimation: Animations not loaded');
      print(
          '⚠️ DUO Character updateAnimation: _animationsLoaded: $_animationsLoaded');
      print('⚠️ DUO Character updateAnimation: idleAnimation: $idleAnimation');
      print(
          '⚠️ DUO Character updateAnimation: walkingAnimation: $walkingAnimation');
      return;
    }

    final newAnimation = walking ? walkingAnimation : idleAnimation;

    // Only switch animation if it's actually different to prevent flickering
    if (animation != newAnimation) {
      print(
        '🔄 DUO Character: Switching animation to ${walking ? "walking" : "idle"}',
      );
      animation = newAnimation;
      // Force animation restart by reassigning
      print('🎬 DUO Animation switched and will restart');
    } else {
      // Animation is already correct, no need to restart
      print('🎬 DUO Character: Animation already correct, no restart needed');
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
