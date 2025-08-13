import 'dart:async' as async;
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
  final Map<String, dynamic>? initialUserCharacterData;
  final Map<String, dynamic>? initialOpponentCharacterData;
  final String? initialOpponentUserId;

  const DuoChallengeGameScreen({
    Key? key,
    required this.inviteId,
    this.otherUsername,
    this.initialUserCharacterData,
    this.initialOpponentCharacterData,
    this.initialOpponentUserId,
  }) : super(key: key);

  @override
  State<DuoChallengeGameScreen> createState() => _DuoChallengeGameScreenState();
}

class _DuoChallengeGameScreenState extends State<DuoChallengeGameScreen>
    with WidgetsBindingObserver {
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
  async.StreamSubscription<DocumentSnapshot>? _gameStateSubscription;
  // Pixels advanced per step detected
  static const double pixelsPerStep = 2.0; // Tune mapping for realistic speed
  // Finish line is positioned based on step goal and pixel-per-step mapping
  double get finishLinePosition => _stepGoal * pixelsPerStep;
  static const int _idleTimeoutMs = 3000; // Idle after 3 seconds of no steps
  static const int _opponentIdleTimeoutMs =
      3000; // Friend idle timeout (3 seconds)

  // Presence and disconnect handling
  async.Timer? _presenceTimer;
  async.Timer? _opponentWaitTimer;
  bool _showWaitingForOpponent = false;
  int _waitingSecondsLeft = 0;

  // Step tracking variables (similar to Solo Mode)
  int _steps = 0;
  int _previousSteps = 0;
  int _opponentSteps = 0;
  DateTime? _lastStepUpdate;
  bool _isInitialized = false;
  DateTime? _initializationTime;
  async.StreamSubscription<Map<String, dynamic>>? _stepSubscription;

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
  final CharacterAnimationService _animationService =
      CharacterAnimationService();

  // NEW: Game state variables
  bool _matchStarted = false;
  bool _showingWinnerDialog = false;
  bool _showingQuitDialog = false;
  static const int _stepGoal = 2000; // Keep original step goal at 2000
  bool _showingMatchStartDialog = false;
  bool _countdownCompleted = false; // Track if countdown has finished

  // Callback functions to update character animations
  CharacterDisplayGame? _userGameInstance;
  CharacterDisplayGame? _opponentGameInstance;
  String? _userGameIdentity;
  String? _opponentGameIdentity;

  // Animation debouncing to prevent flickering

  // Opponent idle detection
  DateTime? _lastOpponentStepUpdate;

  // Track app lifecycle to publish in presence
  AppLifecycleState _currentLifecycleState = AppLifecycleState.resumed;

  Future<void> _pingPresence() async {
    try {
      await _firestore
          .collection('duo_challenge_invites')
          .doc(widget.inviteId)
          .set(
        {
          'presence': {
            _userId: {
              'lastSeen': FieldValue.serverTimestamp(),
              'appLifecycle': _currentLifecycleState.toString(),
            }
          }
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('⚠️ DUO CHALLENGE: Presence ping failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _currentLifecycleState = state;
    // Update presence immediately on lifecycle changes
    _pingPresence();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userId = _auth.currentUser!.uid;

    // If lobby provided opponent id early, set it before listeners
    if (widget.initialOpponentUserId != null &&
        widget.initialOpponentUserId!.isNotEmpty) {
      _otherPlayerId = widget.initialOpponentUserId;
    }

    // Set initialization time and start grace period
    _initializationTime = DateTime.now();
    debugPrint(
        '🏁 DUO CHALLENGE: Initialization started at $_initializationTime');

    // Initialize with walking state as false
    _isUserWalking = false;

    // Defer to actual user documents for character data (no default fallback here)
    _characterDataLoaded = false;

    _initializeGame();
    _preloadCharacters();
    _startGameStateListener();
    _initializeStepTracking();

    // Start presence heartbeat every 10 seconds
    _presenceTimer = async.Timer.periodic(const Duration(seconds: 10), (_) {
      _pingPresence();
    });

    // Immediate presence ping so presence map exists right away
    _pingPresence();

    // Mark as initialized after 3 seconds to prevent false walking detection
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _isInitialized = true;
        debugPrint(
          'DUO CHALLENGE: Grace period ended, now accepting walking detection',
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();
    _opponentWaitTimer?.cancel();
    _gameStateSubscription?.cancel();
    _stepSubscription?.cancel();
    _scrollController.dispose();
    _healthService.stopRealTimeStepMonitoring();

    // Reset the step counter baseline when disposing
    StepCounterService.resetStepBaseline();
    debugPrint('🔄 DUO CHALLENGE: Step counter baseline reset on dispose');

    super.dispose();
  }

  void _initializeGame() async {
    // Reset step counter to zero specifically for this challenge
    StepCounterService.resetCounter();
    debugPrint(
        '🔄 DUO CHALLENGE: Step counter reset to zero for challenge start');

    // Check if this is the first player or second player joining
    final docSnapshot = await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .get();

    if (docSnapshot.exists && docSnapshot.data() != null) {
      final data = docSnapshot.data();
      if (data == null) {
        debugPrint('❌ DUO CHALLENGE: Document data is null in _initializeGame');
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
        debugPrint(
            '🏁 DUO CHALLENGE: First player joining - initializing game');

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
        debugPrint(
            '👥 DUO CHALLENGE: First player - created placeholder opponent');
        debugPrint(
          '👥 DUO CHALLENGE: First player steps reset to 0 for challenge start',
        );
        debugPrint(
          '📊 DUO CHALLENGE: First player initial step count: $currentDeviceSteps',
        );
      } else {
        // Game already started, this is the second player joining
        debugPrint(
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

        debugPrint(
          '👥 DUO CHALLENGE: Second player steps reset to 0 for challenge start',
        );
        debugPrint(
          '📊 DUO CHALLENGE: Second player initial step count: $currentDeviceSteps',
        );

        // Check if both players are ready to start the match
        final allPlayers = positions.keys.toList();
        if (allPlayers.length >= 2 && !matchStarted) {
          debugPrint('🎮 DUO CHALLENGE: Both players ready - starting match!');
          await _startMatch();
        }
      }

      // If match is already started, join the ongoing match
      if (matchStarted) {
        debugPrint('🎮 DUO CHALLENGE: Joining ongoing match');

        // Reset step baseline even when joining ongoing match
        await StepCounterService.resetStepBaseline();
        debugPrint(
            '🔄 DUO CHALLENGE: Step counter baseline reset when joining ongoing match');

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
        debugPrint(
          '📊 DUO CHALLENGE: Loaded opponent initial step count: $_opponentInitialStepCount',
        );
        debugPrint(
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

        debugPrint(
          '👥 DUO CHALLENGE: Both characters forced to be visible immediately',
        );
        debugPrint(
          '👥 DUO CHALLENGE: User position: $_userPosition, Opponent position: $_opponentPosition',
        );
        debugPrint('👥 DUO CHALLENGE: Other player ID: $_otherPlayerId');
        debugPrint(
            '👥 DUO CHALLENGE: Steps reset to zero for sensor-only tracking');
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
    debugPrint('🎮 DUO CHALLENGE: Starting match with both players!');

    // Reset the step counter baseline for this new match
    await StepCounterService.resetStepBaseline();
    debugPrint('🔄 DUO CHALLENGE: Step counter baseline reset for new match');

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
                  color: const Color(0xFFED3E57).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFED3E57)),
                ),
                child: Text(
                  '🎯 Goal: $_stepGoal Steps',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFED3E57),
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

    // During the 5-second popup, try preloading opponent again if needed
    Future.delayed(const Duration(seconds: 1), () async {
      // Best-effort refresh while dialog is visible
      if (!mounted) return;
      try {
        if (_otherPlayerId != null &&
            _otherPlayerId != 'waiting_for_opponent') {
          if (_opponentCharacterData == null) {
            await _loadOpponentCharacterData(_otherPlayerId!);
          }
          if (_opponentCharacterData != null) {
            final oppId =
                '${_otherPlayerId}_${_opponentCharacterData!['currentCharacter']}';
            try {
              await CharacterAnimationService()
                  .preloadAnimationsForCharacterWithData(
                      oppId, _opponentCharacterData!);
            } catch (e) {
              debugPrint('⚠️ Preload during popup failed for $oppId: $e');
            }
          }
        }
      } catch (_) {}
    });

    // Show "🏁 Match Starting..." popup for 5 seconds, then start countdown
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        debugPrint(
          '🎮 DUO CHALLENGE: 5 seconds elapsed - closing "Match Starting..." dialog',
        );
        try {
          Navigator.of(
            context,
          ).pop(); // Close the "🏁 Match Starting..." dialog
          debugPrint(
            '🎮 DUO CHALLENGE: "Match Starting..." dialog closed successfully',
          );
        } catch (e) {
          debugPrint('🎮 DUO CHALLENGE: Error closing match start dialog: $e');
        }

        // Small delay to ensure dialog is fully closed before starting countdown
        Future.delayed(const Duration(milliseconds: 100), () async {
          if (mounted) {
            debugPrint(
              '🎮 DUO CHALLENGE: Starting countdown sequence after dialog close',
            );

            // Reset the match start dialog state
            setState(() {
              _showingMatchStartDialog = false;
            });

            // Final pre-check to ensure spritesheets are loaded right before countdown
            try {
              if (_userCharacterData != null) {
                final myId =
                    '${_userId}_${_userCharacterData!['currentCharacter']}';
                await CharacterAnimationService()
                    .preloadAnimationsForCharacterWithData(
                        myId, _userCharacterData!);
              }
              if (_opponentCharacterData != null &&
                  _otherPlayerId != null &&
                  _otherPlayerId != 'waiting_for_opponent') {
                final oppId =
                    '${_otherPlayerId}_${_opponentCharacterData!['currentCharacter']}';
                await CharacterAnimationService()
                    .preloadAnimationsForCharacterWithData(
                        oppId, _opponentCharacterData!);
              }
            } catch (_) {}

            _startCountdown(); // Start the 3-2-1 countdown
          }
        });
      }
    });
  }

  // NEW: Start countdown and automatically begin game
  void _startCountdown() {
    if (_countdownCompleted) {
      debugPrint('🎮 DUO CHALLENGE: Countdown already completed, skipping...');
      return;
    }

    debugPrint('🎮 DUO CHALLENGE: Starting countdown sequence...');

    // Use a clean timer approach to prevent loops
    _runCountdownSequence();
  }

  // NEW: Clean countdown sequence that runs only once
  void _runCountdownSequence() {
    int countdown = 3;
    bool countdownCompleted = false;

    void showCountdownNumber(int number) {
      if (!mounted || countdownCompleted) return;

      debugPrint('🎮 DUO CHALLENGE: Showing countdown number: $number');

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
                      color: Colors.blue,
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
        debugPrint(
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
              debugPrint(
                  '🎮 DUO CHALLENGE: Error closing countdown number: $e');
            }
            nextCountdownStep(); // Show next number
          } else {
            debugPrint(
              '🎮 DUO CHALLENGE: Countdown step skipped - widget not mounted or countdown completed',
            );
          }
        });
      } else {
        // Countdown finished, show GO!
        countdownCompleted = true;
        debugPrint('🎮 DUO CHALLENGE: Countdown finished, showing GO!');
        _showGoMessage();
      }
    }

    // Start the countdown sequence
    nextCountdownStep();
  }

  // NEW: Begin the actual game
  void _beginGame() {
    debugPrint('🎮 DUO CHALLENGE: Game officially started!');

    setState(() {
      _showingMatchStartDialog = false;
      _countdownCompleted = true; // Mark countdown as completed
    });

    // Game is now active - both characters should be visible and step tracking enabled
    debugPrint(
      '🎮 DUO CHALLENGE: Game is now active - step tracking and character movement enabled!',
    );

    // Ensure step tracking is fully enabled
    _enableStepTracking();

    // Final confirmation that countdown sequence is complete
    debugPrint(
      '🎮 DUO CHALLENGE: Countdown sequence completed - game is fully active!',
    );
  }

  // NEW: Enable step tracking when game officially starts
  void _enableStepTracking() {
    debugPrint('🎯 DUO CHALLENGE: Step tracking officially enabled!');

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

    debugPrint('🎯 DUO CHALLENGE: Both characters ready for step tracking!');
  }

  // NEW: Show "GO!" message
  void _showGoMessage() {
    debugPrint('🎮 DUO CHALLENGE: Showing GO! message...');

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
        debugPrint('🎮 DUO CHALLENGE: GO! message finished, starting game...');
        try {
          Navigator.of(context).pop();
        } catch (e) {
          debugPrint('🎮 DUO CHALLENGE: Error closing GO! message: $e');
        }
        _beginGame(); // Start the game after "GO!" message
      }
    });
  }

  Future<void> _loadExistingGameData() async {
    debugPrint('📊 DUO CHALLENGE: Loading existing game data...');

    final docSnapshot = await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .get();

    if (docSnapshot.exists && docSnapshot.data() != null) {
      final data = docSnapshot.data();
      if (data == null) {
        debugPrint(
          '❌ DUO CHALLENGE: Document data is null in _loadExistingGameData',
        );
        return;
      }

      final positions = (data['positions'] as Map<String, dynamic>?) ?? {};

      debugPrint('📊 DUO CHALLENGE: Current positions: $positions');
      debugPrint('📊 DUO CHALLENGE: Current user ID: $_userId');

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

        debugPrint(
          '📊 DUO CHALLENGE: Loaded user data - Position: $userPos, Steps: $_steps (sensor-only)',
        );
      }

      // Find and load the other player's data
      final otherPlayerId =
          positions.keys.where((key) => key != _userId).firstOrNull;

      debugPrint('📊 DUO CHALLENGE: Found other player ID: $otherPlayerId');

      if (otherPlayerId != null) {
        final opponentPos = (positions[otherPlayerId] ?? 200.0);
        // Don't load opponent steps from Firestore - they should start at 0 for challenge
        // final opponentSteps = (steps[otherPlayerId] ?? 0) as int;

        debugPrint(
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

        debugPrint(
          '📊 DUO CHALLENGE: Set opponent data - _otherPlayerId: $_otherPlayerId, _opponentPosition: $_opponentPosition, _opponentSteps: $_opponentSteps',
        );

        // IMMEDIATE VISIBILITY: Ensure opponent character is immediately visible
        debugPrint(
          '👥 DUO CHALLENGE: Opponent immediately visible on game start with 0 steps!',
        );
      } else {
        // If no real opponent found but we have a placeholder, keep it
        if (_otherPlayerId == 'waiting_for_opponent') {
          debugPrint(
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
          debugPrint(
            '📊 DUO CHALLENGE: Created placeholder opponent for immediate display',
          );
        }
      }
    } else {
      debugPrint('📊 DUO CHALLENGE: Document does not exist');

      // Fallback: Ensure opponent character is visible even if document doesn't exist
      if (mounted) {
        setState(() {
          _otherPlayerId = 'waiting_for_opponent';
          _opponentPosition = 200.0;
          _opponentSteps = 0;
          _isOpponentWalking = false;
        });
        debugPrint('📊 DUO CHALLENGE: Fallback - Created placeholder opponent');
      }
    }
  }

  Future<void> _ensureBothPlayersVisible() async {
    debugPrint(
        '👥 DUO CHALLENGE: Ensuring both players are visible immediately...');

    // Get the latest game data
    final docSnapshot = await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .get();

    if (docSnapshot.exists && docSnapshot.data() != null) {
      final data = docSnapshot.data();
      if (data == null) {
        debugPrint(
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

        debugPrint(
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

        debugPrint(
          '👥 DUO CHALLENGE: Opponent data confirmed - Position: $opponentPos, Steps: 0 (challenge start)',
        );
        debugPrint('👥 DUO CHALLENGE: BOTH PLAYERS NOW VISIBLE!');
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
          debugPrint(
            '👥 DUO CHALLENGE: Created placeholder opponent for immediate visibility',
          );
        } else {
          debugPrint(
            '👥 DUO CHALLENGE: Placeholder opponent already visible - waiting for real opponent',
          );
        }
      }
    }
  }

  void _forceImmediateVisibilityCheck() {
    debugPrint('🔍 DUO CHALLENGE: Force checking immediate visibility...');

    // Force a state update to ensure both characters are rendered
    if (mounted) {
      setState(() {
        // This will trigger a rebuild and ensure both characters are visible
      });

      debugPrint(
        '🔍 DUO CHALLENGE: Visibility check completed - both characters should be visible',
      );

      // Additional check: if opponent is still not visible, force it
      if (_otherPlayerId == null) {
        debugPrint(
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
    debugPrint('🚨 DUO CHALLENGE: AGGRESSIVE visibility check...');

    // Force reload game data to ensure both players are visible
    _loadExistingGameData();
    _ensureBothPlayersVisible();

    // Force a state update
    if (mounted) {
      setState(() {
        // Trigger rebuild
      });
    }

    debugPrint('🚨 DUO CHALLENGE: Aggressive visibility check completed');
  }

  void _startGameStateListener() {
    final docRef =
        _firestore.collection('duo_challenge_invites').doc(widget.inviteId);

    _gameStateSubscription = docRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) {
        debugPrint('❌ DUO CHALLENGE: Document data is null');
        return;
      }

      debugPrint(
          '📡 DUO CHALLENGE: Firestore update received - gameEnded: ${data['gameEnded']}, winner: ${data['winner']}, quitBy: ${data['quitBy']}, forfeitBy: ${data['forfeitBy']}');

      final positions = (data['positions'] as Map<String, dynamic>?) ?? {};
      final initialSteps =
          (data['initialSteps'] as Map<String, dynamic>?) ?? {};
      final rawSteps = (data['rawSteps'] as Map<String, dynamic>?) ?? {};
      final gameEnded = data['gameEnded'] ?? false;
      final winner = data['winner'] as String?;
      final matchStarted = data['matchStarted'] ?? false;
      final presence = (data['presence'] as Map<String, dynamic>?) ?? {};
      final quitBy = data['quitBy'] as String?;
      final forfeitBy = data['forfeitBy'] as String?;

      // NEW: Check if both players are ready and start match automatically
      if (!matchStarted && !_matchStarted) {
        final allPlayers = positions.keys.toList();
        if (allPlayers.length >= 2) {
          debugPrint(
            '🎮 DUO CHALLENGE: Both players detected - starting match automatically!',
          );
          debugPrint('🎮 DUO CHALLENGE: Player count: ${allPlayers.length}');
          debugPrint('🎮 DUO CHALLENGE: Players: $allPlayers');
          _startMatch();
          return;
        }
      }

      // NEW: Check if opponent quit or forfeited and current user should win
      if (gameEnded &&
          winner == _userId &&
          ((quitBy != null && quitBy != _userId) ||
              (forfeitBy != null && forfeitBy != _userId))) {
        debugPrint(
            '🎮 DUO CHALLENGE: Opponent quit/forfeited, user wins by default!');
        debugPrint(
            '🎮 DUO CHALLENGE: Quit/forfeit win check - quitBy: $quitBy, forfeitBy: $forfeitBy');
        if (!_showingWinnerDialog && !_gameEnded) {
          debugPrint(
              '🎮 DUO CHALLENGE: Calling _handleUserWin for quit/forfeit win');
          _handleUserWin();
        } else {
          debugPrint(
              '🎮 DUO CHALLENGE: Quit/forfeit win blocked - _showingWinnerDialog: $_showingWinnerDialog, _gameEnded: $_gameEnded');
        }
        return;
      }

      // NEW: Check if game ended with user as winner (normal win, not quit/forfeit)
      // Only handle if not already handled by quit/forfeit logic above
      if (gameEnded &&
          winner == _userId &&
          quitBy == null &&
          forfeitBy == null &&
          !_showingWinnerDialog &&
          !_gameEnded) {
        debugPrint('🎮 DUO CHALLENGE: Game ended with user as winner!');
        debugPrint(
            '🎮 DUO CHALLENGE: Normal win check - quitBy: $quitBy, forfeitBy: $forfeitBy');
        debugPrint('🎮 DUO CHALLENGE: Calling _handleUserWin for normal win');
        _handleUserWin();
        return;
      }

      // Detect opponent offline and start/stop wait timer (30s)
      if (_matchStarted && !_gameEnded) {
        final otherId =
            positions.keys.where((key) => key != _userId).firstOrNull;
        if (otherId != null) {
          final oppPresence =
              (presence[otherId] as Map<String, dynamic>?) ?? {};
          final Timestamp? lastSeenTs = oppPresence['lastSeen'] as Timestamp?;
          final lastSeen = lastSeenTs?.toDate();
          final now = DateTime.now();
          final isOffline =
              lastSeen == null || now.difference(lastSeen).inSeconds > 10;

          if (isOffline &&
              _opponentWaitTimer == null &&
              !_showWaitingForOpponent) {
            // Start 30s wait window
            _waitingSecondsLeft = 30;
            _showWaitingForOpponent = true;
            _opponentWaitTimer =
                async.Timer.periodic(const Duration(seconds: 1), (t) async {
              if (!mounted) return;
              setState(() => _waitingSecondsLeft--);
              // Check if opponent came back
              final snap = await _firestore
                  .collection('duo_challenge_invites')
                  .doc(widget.inviteId)
                  .get();
              final p =
                  (snap.data()?['presence'] as Map<String, dynamic>?) ?? {};
              final op = (p[otherId] as Map<String, dynamic>?) ?? {};
              final ts = op['lastSeen'] as Timestamp?;
              final ls = ts?.toDate();
              final backOnline =
                  ls != null && DateTime.now().difference(ls).inSeconds <= 10;
              if (backOnline) {
                t.cancel();
                _opponentWaitTimer = null;
                if (mounted) setState(() => _showWaitingForOpponent = false);
              } else if (_waitingSecondsLeft <= 0) {
                t.cancel();
                _opponentWaitTimer = null;
                if (mounted) setState(() => _showWaitingForOpponent = false);
                // Forfeit win to user
                debugPrint(
                    '🎮 DUO CHALLENGE: Opponent forfeited due to offline - calling _handleUserWin');
                await _firestore
                    .collection('duo_challenge_invites')
                    .doc(widget.inviteId)
                    .set({
                  'gameEnded': true,
                  'winner': _userId,
                  'winnerUsername': 'You',
                  'loser': otherId,
                  'loserUsername': widget.otherUsername ?? 'Opponent',
                  'winnerSteps': _steps,
                  'loserSteps': _opponentSteps,
                  'forfeitBy': otherId,
                  'winnerCoins': 100,
                  'matchEndTime': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                _handleUserWin();
              }
            });
          }

          if (!isOffline && _opponentWaitTimer != null) {
            // Opponent returned
            _opponentWaitTimer?.cancel();
            _opponentWaitTimer = null;
            if (mounted) setState(() => _showWaitingForOpponent = false);
          }
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
              debugPrint(
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

      debugPrint(
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
            debugPrint(
              '📊 DUO CHALLENGE: Set opponent initial step count: $_opponentInitialStepCount',
            );
          }
        }

        // Update opponent's raw steps
        _opponentRawSteps = opponentRawSteps;

        debugPrint(
          '📊 DUO CHALLENGE: Real-time update - Opponent ID: $otherPlayerId, Position: $opponentPos',
        );
        debugPrint(
          '📊 DUO CHALLENGE: Opponent raw steps: $opponentRawSteps, initial steps: ${initialSteps[otherPlayerId] ?? 0}',
        );
        debugPrint(
          '📊 DUO CHALLENGE: Calculated opponent challenge steps: $calculatedOpponentSteps',
        );

        // CRITICAL FIX: Always ensure opponent is visible, regardless of state changes
        bool shouldUpdateOpponent = false;

        // Case 1: New opponent joined (different ID)
        if (_otherPlayerId != otherPlayerId) {
          debugPrint(
            '👥 DUO CHALLENGE: NEW OPPONENT JOINED - Making immediately visible!',
          );
          shouldUpdateOpponent = true;

          // Load opponent's character data when they join
          await _loadOpponentCharacterData(otherPlayerId);

          // Ensure character data is loaded before updating state
          if (_opponentCharacterData != null) {
            debugPrint(
                '✅ DUO CHALLENGE: Opponent character data loaded successfully');
            // Strong warm-up to guarantee opponent animations are ready
            try {
              final opponentCharacterId =
                  '${otherPlayerId}_${_opponentCharacterData!['currentCharacter']}';
              await CharacterAnimationService()
                  .preloadAnimationsForCharacterWithData(
                      opponentCharacterId, _opponentCharacterData!);
              debugPrint(
                  '✅ DUO CHALLENGE: Opponent animations warmed up for $opponentCharacterId');
            } catch (e) {
              debugPrint(
                  '❌ DUO CHALLENGE: Opponent animation warm-up failed: $e');
            }
          } else {
            debugPrint(
                '⚠️ DUO CHALLENGE: Opponent character data failed to load, using fallback');
          }
        }
        // Case 2: Same opponent but data changed
        else if (_opponentPosition != opponentPos ||
            _opponentSteps != calculatedOpponentSteps) {
          debugPrint(
            '📊 DUO CHALLENGE: Existing opponent data changed - Position: $_opponentPosition -> $opponentPos, Steps: $_opponentSteps -> $calculatedOpponentSteps',
          );
          shouldUpdateOpponent = true;
        }
        // Case 3: Same opponent, same data, but not visible (safety check)
        else if (_otherPlayerId == null ||
            _otherPlayerId == 'waiting_for_opponent') {
          debugPrint(
            '🚨 DUO CHALLENGE: Opponent exists but not visible - forcing visibility!',
          );
          shouldUpdateOpponent = true;
        }

        if (shouldUpdateOpponent) {
          // -- walking state from steps OR position delta --
          final bool sameOpponent = (_otherPlayerId == otherPlayerId);
          const double posEpsilon = 0.5;

          final bool stepsAdvanced = calculatedOpponentSteps > _opponentSteps;
          final bool posAdvanced =
              sameOpponent && (opponentPos > _opponentPosition + posEpsilon);
          final bool opponentIsWalking = stepsAdvanced || posAdvanced;
          if (opponentIsWalking) _lastOpponentStepUpdate = DateTime.now();

          final bool needsStateUpdate = _opponentPosition != opponentPos ||
              _opponentSteps != calculatedOpponentSteps ||
              _otherPlayerId != otherPlayerId ||
              _isOpponentWalking != opponentIsWalking;

          if (needsStateUpdate && mounted) {
            setState(() {
              _opponentPosition = opponentPos;
              _opponentSteps = calculatedOpponentSteps;
              _otherPlayerId = otherPlayerId;
              _isOpponentWalking = opponentIsWalking;
            });

            // Switch animation after the frame so the Flame instance is ready
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateOpponentCharacterAnimation(opponentIsWalking);
            });
          }

          debugPrint(
            '👥 DUO CHALLENGE: Opponent now visible with position: $opponentPos, steps: $calculatedOpponentSteps, walking: $opponentIsWalking',
          );

          // Removed forced 300ms stop; idle is now controlled by timeout when no new steps/pos arrive
        } else {
          debugPrint(
              '📊 DUO CHALLENGE: Opponent already visible and up-to-date');
        }
      } else {
        // No real opponent found, but keep placeholder if it exists
        if (_otherPlayerId == 'waiting_for_opponent') {
          debugPrint(
              '📊 DUO CHALLENGE: No real opponent yet, keeping placeholder');
        } else if (_otherPlayerId == null) {
          // Create placeholder if no opponent and no placeholder
          debugPrint(
              '📊 DUO CHALLENGE: No opponent found - creating placeholder');
          setState(() {
            _otherPlayerId = 'waiting_for_opponent';
            _opponentPosition = 200.0;
            _opponentSteps = 0;
            _isOpponentWalking = false;
          });
        } else {
          debugPrint('📊 DUO CHALLENGE: No opponent found in real-time update');
        }
      }

      // CRITICAL: Always ensure both characters are visible (final safety check)
      if (_otherPlayerId == null) {
        debugPrint(
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
    debugPrint(
        '🎭 DUO CHALLENGE: Loading character data for opponent: $opponentId');

    try {
      _opponentCharacterData =
          await _characterDataService.getUserCharacterData(opponentId);
      debugPrint(
          '✅ DUO CHALLENGE: Loaded opponent character data: ${_opponentCharacterData!['currentCharacter']}');
      debugPrint(
          '🎭 DUO CHALLENGE: Opponent sprite sheets: ${_opponentCharacterData!['spriteSheets']}');

      // Verify the opponent sprite sheets; if missing, synthesize from character id map
      if (_opponentCharacterData!['spriteSheets'] == null) {
        debugPrint(
            '⚠️ DUO CHALLENGE: Opponent sprite sheets missing, deriving from character id');
        final picked = _opponentCharacterData!['currentCharacter'] as String? ??
            'MyCharacter';
        _opponentCharacterData!['spriteSheets'] =
            CharacterDataService.spriteSheets[picked] ??
                CharacterDataService.spriteSheets['MyCharacter'];
      }

      // Preload opponent character animations
      final animationService = CharacterAnimationService();
      final opponentCharacterId =
          '${opponentId}_${_opponentCharacterData!['currentCharacter']}';

      debugPrint(
          '🎭 DUO CHALLENGE: Preloading opponent animations for ID: $opponentCharacterId');
      debugPrint(
          '🎭 DUO CHALLENGE: Opponent sprite sheets to load: ${_opponentCharacterData!['spriteSheets']}');

      await animationService.preloadAnimationsForCharacterWithData(
          opponentCharacterId, _opponentCharacterData!);
      debugPrint(
          '✅ DUO CHALLENGE: Preloaded opponent character animations for ${_opponentCharacterData!['currentCharacter']}');
    } catch (e) {
      debugPrint('❌ DUO CHALLENGE: Error loading opponent character data: $e');
      debugPrint(
          '❌ DUO CHALLENGE: Stack trace: ${StackTrace.current.toString()}');

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
      debugPrint('🎭 DUO CHALLENGE: Opponent character data updated in UI');
      debugPrint(
          '🎭 DUO CHALLENGE: Final opponent sprite sheets after update: ${_opponentCharacterData!['spriteSheets']}');
    }
  }

  // NEW: Force reload character data if loading fails
  Future<void> _forceReloadCharacterData() async {
    debugPrint('🔄 DUO CHALLENGE: Force reloading character data...');

    try {
      // Clear existing data
      _userCharacterData = null;
      _opponentCharacterData = null;
      _characterDataLoaded = false;

      // Reload character data
      await _preloadCharacters();

      debugPrint('✅ DUO CHALLENGE: Character data force reload completed');
    } catch (e) {
      debugPrint('❌ DUO CHALLENGE: Error in force reload: $e');
    }
  }

  Future<void> _preloadCharacters() async {
    debugPrint('🎭 DUO CHALLENGE: Preloading character data (game screen)...');

    // Prefer character data passed from lobby
    if (widget.initialUserCharacterData != null) {
      _userCharacterData = widget.initialUserCharacterData;
    }
    if (widget.initialOpponentUserId != null &&
        widget.initialOpponentCharacterData != null) {
      _otherPlayerId = widget.initialOpponentUserId;
      _opponentCharacterData = widget.initialOpponentCharacterData;
    }

    // If anything missing, fetch in background
    if (_userCharacterData == null) {
      await _loadUserCharacterDataInBackground();
    }
    if (_opponentCharacterData == null) {
      await _loadOpponentCharacterDataInBackground();
    }

    // Preload animations in background (service will skip if already loaded)
    await _preloadAnimationsInBackground();

    if (mounted) {
      setState(() {
        _characterDataLoaded = true;
      });
    }
  }

  // Load user character data in background
  Future<void> _loadUserCharacterDataInBackground() async {
    try {
      debugPrint(
          '🎭 DUO CHALLENGE: Loading user character data from Firestore...');
      final userData =
          await _characterDataService.getCurrentUserCharacterData();
      debugPrint(
          '✅ DUO CHALLENGE: Loaded user character data: ${userData['currentCharacter']}');
      debugPrint(
          '🎭 DUO CHALLENGE: User sprite sheets from Firestore: ${userData['spriteSheets']}');
      debugPrint(
          '🎭 DUO CHALLENGE: User owned items: ${userData['owned_items']}');

      if (mounted) {
        setState(() {
          _userCharacterData = userData;
          // Ensure sprite sheets exist from canonical mapping if missing
          if (_userCharacterData!['spriteSheets'] == null) {
            final picked = _userCharacterData!['currentCharacter'] as String? ??
                'MyCharacter';
            _userCharacterData!['spriteSheets'] =
                CharacterDataService.spriteSheets[picked] ??
                    CharacterDataService.spriteSheets['MyCharacter'];
          }
        });
        debugPrint('✅ DUO CHALLENGE: Updated user character data in UI');
        debugPrint(
            '🎭 DUO CHALLENGE: Current user sprite sheets in UI: ${_userCharacterData!['spriteSheets']}');
      }
    } catch (e) {
      debugPrint('❌ DUO CHALLENGE: Error loading user character data: $e');
      debugPrint(
          '🎭 DUO CHALLENGE: Keeping fallback user sprite sheets: ${_userCharacterData!['spriteSheets']}');
      // Keep existing fallback data
    }
  }

  // Load opponent character data in background
  Future<void> _loadOpponentCharacterDataInBackground() async {
    if (_otherPlayerId != null &&
        _otherPlayerId != 'waiting_for_opponent' &&
        _otherPlayerId != 'placeholder') {
      try {
        debugPrint(
            '🎭 DUO CHALLENGE: Loading opponent character data from Firestore for ID: $_otherPlayerId');
        final opponentData =
            await _characterDataService.getUserCharacterData(_otherPlayerId!);
        debugPrint(
            '✅ DUO CHALLENGE: Loaded opponent character data: ${opponentData['currentCharacter']}');
        debugPrint(
            '🎭 DUO CHALLENGE: Opponent sprite sheets from Firestore: ${opponentData['spriteSheets']}');
        debugPrint(
            '🎭 DUO CHALLENGE: Opponent owned items: ${opponentData['owned_items']}');

        if (mounted) {
          setState(() {
            _opponentCharacterData = opponentData;
          });
          debugPrint('✅ DUO CHALLENGE: Updated opponent character data in UI');
          debugPrint(
              '🎭 DUO CHALLENGE: Current opponent sprite sheets in UI: ${_opponentCharacterData!['spriteSheets']}');
        }
      } catch (e) {
        debugPrint(
            '❌ DUO CHALLENGE: Error loading opponent character data: $e');
        debugPrint(
            '🎭 DUO CHALLENGE: Keeping fallback opponent sprite sheets: ${_opponentCharacterData!['spriteSheets']}');
        // Keep existing fallback data
      }
    } else {
      debugPrint(
          '🎭 DUO CHALLENGE: No opponent ID available yet for character data');
    }
  }

  // Preload animations in background
  Future<void> _preloadAnimationsInBackground() async {
    try {
      final animationService = CharacterAnimationService();

      // Preload user character animations (only if data ready)
      if (_userCharacterData != null &&
          _userCharacterData!['currentCharacter'] != null &&
          _userCharacterData!['spriteSheets'] != null) {
        final userCharacterId =
            '${_userId}_${_userCharacterData!['currentCharacter']}';
        debugPrint(
            '🎭 DUO CHALLENGE: Preloading user animations for ID: $userCharacterId');
        debugPrint(
            '🎭 DUO CHALLENGE: User sprite sheets for animation: ${_userCharacterData!['spriteSheets']}');
        await animationService.preloadAnimationsForCharacterWithData(
            userCharacterId, _userCharacterData!);
        debugPrint('✅ DUO CHALLENGE: Preloaded user character animations');
      } else {
        debugPrint(
            '⏳ DUO CHALLENGE: User character data not ready, skipping user animation preload');
      }

      // Preload opponent character animations (only if data ready)
      if (_opponentCharacterData != null &&
          _opponentCharacterData!['currentCharacter'] != null &&
          _opponentCharacterData!['spriteSheets'] != null &&
          _otherPlayerId != null &&
          _otherPlayerId != 'waiting_for_opponent' &&
          _otherPlayerId != 'placeholder') {
        final opponentCharacterId =
            '${_otherPlayerId}_${_opponentCharacterData!['currentCharacter']}';
        debugPrint(
            '🎭 DUO CHALLENGE: Preloading opponent animations for ID: $opponentCharacterId');
        debugPrint(
            '🎭 DUO CHALLENGE: Opponent sprite sheets for animation: ${_opponentCharacterData!['spriteSheets']}');
        await animationService.preloadAnimationsForCharacterWithData(
            opponentCharacterId, _opponentCharacterData!);
        debugPrint('✅ DUO CHALLENGE: Preloaded opponent character animations');
      } else {
        debugPrint(
            '⏳ DUO CHALLENGE: Opponent character data not ready, skipping opponent animation preload');
      }
    } catch (e) {
      debugPrint('❌ DUO CHALLENGE: Error preloading character animations: $e');
      debugPrint(
          '🎭 DUO CHALLENGE: User sprite sheets at error: ${_userCharacterData?['spriteSheets'] ?? 'null'}');
      debugPrint(
          '🎭 DUO CHALLENGE: Opponent sprite sheets at error: ${_opponentCharacterData?['spriteSheets'] ?? 'null'}');
    }

    // Final summary of sprite sheets
    debugPrint('🎭 DUO CHALLENGE: SPRITE SHEET SUMMARY:');
    debugPrint(
        '🎭 DUO CHALLENGE: User character: ${_userCharacterData?['currentCharacter'] ?? 'null'}');
    debugPrint(
        '🎭 DUO CHALLENGE: User sprite sheets: ${_userCharacterData?['spriteSheets'] ?? 'null'}');
    debugPrint(
        '🎭 DUO CHALLENGE: Opponent character: ${_opponentCharacterData?['currentCharacter'] ?? 'null'}');
    debugPrint(
        '🎭 DUO CHALLENGE: Opponent sprite sheets: ${_opponentCharacterData?['spriteSheets'] ?? 'null'}');
  }

  void _initializeStepTracking() async {
    debugPrint(
      '🏁 DUO CHALLENGE: Initializing StepCounterService-based step tracking for challenge...',
    );

    try {
      // Reset the step counter baseline for this new game
      await StepCounterService.resetStepBaseline();
      debugPrint('🔄 DUO CHALLENGE: Step counter baseline reset for new game');

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
      debugPrint(
          '🔄 DUO CHALLENGE: Force reset walking state after initialization');

      // Force character to idle state during initialization
      if (_userGameInstance?.character != null) {
        _userGameInstance!.character!.isWalking = false;
        _userGameInstance!.updateWalkingState(false);
        debugPrint('🎬 DUO CHALLENGE: Forced character to idle state');
      }

      // Start continuous monitoring for idle detection
      _startContinuousMonitoring();

      debugPrint(
        '✅ DUO CHALLENGE: StepCounterService-based step tracking initialized',
      );
      debugPrint('🎯 DUO CHALLENGE: Step goal set to: $_stepGoal steps');
    } catch (e) {
      debugPrint('❌ DUO CHALLENGE: Error initializing step tracking: $e');
      // Fallback to periodic polling
      _startPeriodicUpdates();
    }
  }

  void _setupStepCounterServiceListener() {
    debugPrint(
        '📱 DUO CHALLENGE: Setting up StepCounterService stream listener...');

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

            debugPrint(
                '🔄 DUO CHALLENGE: Step counter update - calling _checkUserWalkingWithTiming');
            debugPrint(
                '🔄 DUO CHALLENGE: Current state before step check - _gameEnded: $_gameEnded, _showingWinnerDialog: $_showingWinnerDialog');
            _checkUserWalkingWithTiming(timestamp);
            _syncCharacterAnimation();
            await _updateStepsInFirestore(); // Firestore sync
          }

          debugPrint(
            '🏥 DUO CHALLENGE StepCounterService update: Device Steps: $currentSteps, Challenge Steps: $challengeSteps (Baseline: $_userInitialStepCount)',
          );
        }
      },
      onError: (error) {
        debugPrint('❌ DUO CHALLENGE: Error in step stream: $error');
      },
    );

    debugPrint(
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
    debugPrint(
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
          debugPrint(
            '🔄 DUO CHALLENGE PERIODIC CHECK: Time since last step: ${timeSinceLastStep}s',
          );

          if (timeSinceLastStep >= 5) {
            // Force idle after 5 seconds of no steps (proper idle detection)
            debugPrint(
              '⏰ DUO CHALLENGE PERIODIC 5-SECOND TIMEOUT: No steps for ${timeSinceLastStep}s - FORCING IDLE',
            );
            debugPrint(
              '⏰ DUO CHALLENGE PERIODIC 5-SECOND TIMEOUT: User definitely stopped walking',
            );
            _setWalkingState(false);
            _forceCharacterAnimationSync(); // Force immediate sync
          } else if (timeSinceLastStep >= 7) {
            debugPrint(
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
            debugPrint(
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
        debugPrint(
          '🛡️ DUO CHALLENGE Force character state correction: character=$characterIsWalking, should=$_isUserWalking',
        );
        _userGameInstance!.updateWalkingState(_isUserWalking);
      }

      // APPROACH 11: AGGRESSIVE CHARACTER STATE FORCE (like Solo Mode)
      if (_isUserWalking == false && characterIsWalking == true) {
        debugPrint(
          '🚨 DUO CHALLENGE AGGRESSIVE: Character is walking but should be idle - FORCING',
        );
        _userGameInstance!.character!.isWalking = false;
        _userGameInstance!.updateWalkingState(false);
      }
    }
  }

  void _startOpponentAnimationMonitoring() {
    // Monitor opponent character animation and idle timeout periodically
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _checkOpponentAnimationSync();
        _checkOpponentIdleTimeout();
        _startOpponentAnimationMonitoring(); // Recursive call
      }
    });
  }

  void _checkOpponentAnimationSync() {
    // Ensure opponent character animation matches walking state immediately
    if (_opponentGameInstance?.character != null) {
      final characterIsWalking = _opponentGameInstance!.character!.isWalking;
      if (characterIsWalking != _isOpponentWalking) {
        debugPrint(
          '🎬 DUO CHALLENGE OPPONENT SYNC: Character walking ($characterIsWalking) != Opponent walking ($_isOpponentWalking) - FORCING SYNC',
        );

        // Immediate state change - no delay or animation transition
        _opponentGameInstance!.character!.isWalking = _isOpponentWalking;
        _opponentGameInstance!.updateWalkingState(_isOpponentWalking);

        debugPrint(
          '✅ DUO CHALLENGE OPPONENT SYNC: Opponent character animation synced',
        );
      }
    }
  }

  void _checkOpponentIdleTimeout() {
    if (_isOpponentWalking && _lastOpponentStepUpdate != null) {
      final int since =
          DateTime.now().difference(_lastOpponentStepUpdate!).inMilliseconds;
      // Consider opponent idle after timeout
      if (since >= _opponentIdleTimeoutMs) {
        debugPrint(
            '⏰ DUO CHALLENGE OPPONENT IDLE: No steps for ${since}ms (>= $_opponentIdleTimeoutMs) - forcing idle');
        if (mounted) {
          setState(() {
            _isOpponentWalking = false;
          });
        }
        _updateOpponentCharacterAnimation(false);
      }
    }
  }

  void _startContinuousMonitoring() {
    debugPrint('🔄 DUO CHALLENGE: Starting continuous monitoring system...');

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
      final timeSinceLastStepMs =
          DateTime.now().difference(_lastStepUpdate!).inMilliseconds;
      debugPrint(
        '⚡ DUO CHALLENGE: FREQUENT CHECK: Time since last step: ${timeSinceLastStepMs}ms',
      );

      if (timeSinceLastStepMs >= _idleTimeoutMs) {
        debugPrint(
          '⏰ DUO CHALLENGE: FREQUENT IDLE: No steps for ${timeSinceLastStepMs}ms (>= $_idleTimeoutMs) - FORCING IDLE NOW',
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
        debugPrint(
          '🎬 DUO CHALLENGE: FREQUENT SYNC: Character walking ($characterIsWalking) != User walking ($_isUserWalking) - FORCING SYNC',
        );

        // Immediate state change - no delay or animation transition
        _userGameInstance!.character!.isWalking = _isUserWalking;
        _userGameInstance!.updateWalkingState(_isUserWalking);
      }
    }
  }

  void _checkWalkingStateBackup() {
    // GRACE PERIOD: Don't check walking state during initialization (like Solo Mode)
    if (!_isInitialized) {
      return;
    }

    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStepMs =
          DateTime.now().difference(_lastStepUpdate!).inMilliseconds;
      debugPrint(
        '🔄 DUO CHALLENGE: BACKUP CHECK: Time since last step: ${timeSinceLastStepMs}ms',
      );

      if (timeSinceLastStepMs >= _idleTimeoutMs) {
        debugPrint(
          '⏰ DUO CHALLENGE: BACKUP IDLE: No steps for ${timeSinceLastStepMs}ms (>= $_idleTimeoutMs) - FORCING IDLE NOW',
        );
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      }
    }

    // APPROACH 30: BACKUP CHARACTER SYNC (like Solo Mode)
    if (mounted && _userGameInstance?.character != null) {
      final characterIsWalking = _userGameInstance!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        debugPrint(
          '🎬 DUO CHALLENGE: BACKUP SYNC: Character walking ($characterIsWalking) != User walking ($_isUserWalking) - FORCING SYNC',
        );

        // Immediate state change - no delay or animation transition
        _userGameInstance!.character!.isWalking = _isUserWalking;
        _userGameInstance!.updateWalkingState(_isUserWalking);
      }
    }
  }

  void _checkWalkingStateSafety() {
    // GRACE PERIOD: Don't check walking state during initialization (like Solo Mode)
    if (!_isInitialized) {
      return;
    }

    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStepMs =
          DateTime.now().difference(_lastStepUpdate!).inMilliseconds;
      debugPrint(
        '🛡️ DUO CHALLENGE: SAFETY CHECK: Time since last step: ${timeSinceLastStepMs}ms',
      );

      if (timeSinceLastStepMs >= _idleTimeoutMs) {
        debugPrint(
          '⏰ DUO CHALLENGE: SAFETY IDLE: No steps for ${timeSinceLastStepMs}ms (>= $_idleTimeoutMs) - FORCING IDLE NOW',
        );
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      }
    }

    // APPROACH 31: SAFETY CHARACTER SYNC (like Solo Mode)
    if (mounted && _userGameInstance?.character != null) {
      final characterIsWalking = _userGameInstance!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        debugPrint(
          '🎬 DUO CHALLENGE: SAFETY SYNC: Character walking ($characterIsWalking) != User walking ($_isUserWalking) - FORCING SYNC',
        );

        // Immediate state change - no delay or animation transition
        _userGameInstance!.character!.isWalking = _isUserWalking;
        _userGameInstance!.updateWalkingState(_isUserWalking);
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

      // Immediate state change - no delay or animation transition
      if (walking) {
        _startCharacterWalking();
      } else {
        _stopCharacterWalking();
      }

      debugPrint(
        walking
            ? '🚶‍♂️ DUO CHALLENGE: User started walking'
            : '🛑 DUO CHALLENGE: User stopped walking',
      );
    }
  }

  void _moveUserForward([int stepDelta = 1]) async {
    if (_gameEnded) return;

    // Move user forward proportionally using the global pixels-per-step mapping
    final int effectiveDelta = stepDelta <= 0 ? 1 : stepDelta;
    final double moveIncrement = pixelsPerStep * effectiveDelta;
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

    debugPrint(
      '🔍 DUO CHALLENGE: Checking walking state: previous=$_previousSteps, current=$_steps, isWalking=$_isUserWalking, initialized=$_isInitialized, _gameEnded=$_gameEnded, _showingWinnerDialog=$_showingWinnerDialog',
    );

    // GRACE PERIOD: Don't detect walking during initialization (like Solo Mode)
    if (!_isInitialized) {
      debugPrint(
        '🎯 DUO CHALLENGE: GRACE PERIOD: Screen not fully initialized, ignoring walking detection',
      );
      return;
    }

    // NEW: Check for win condition if match has started
    // Only check if game hasn't ended and user hasn't already won
    debugPrint(
        '🏆 DUO CHALLENGE: About to check step goal win condition - _matchStarted: $_matchStarted, _steps: $_steps, _stepGoal: $_stepGoal, _gameEnded: $_gameEnded, _showingWinnerDialog: $_showingWinnerDialog');
    if (_matchStarted &&
        _steps >= _stepGoal &&
        !_gameEnded &&
        !_showingWinnerDialog) {
      debugPrint('🏆 DUO CHALLENGE: User reached step goal! User wins!');
      debugPrint(
          '🏆 DUO CHALLENGE: Step goal win check - _gameEnded: $_gameEnded, _showingWinnerDialog: $_showingWinnerDialog');
      debugPrint('🏆 DUO CHALLENGE: Calling _handleUserWin for step goal win');
      _handleUserWin();
      return;
    } else {
      debugPrint(
          '🏆 DUO CHALLENGE: Step goal win check blocked - _matchStarted: $_matchStarted, _steps: $_steps, _stepGoal: $_stepGoal, _gameEnded: $_gameEnded, _showingWinnerDialog: $_showingWinnerDialog');
    }

    // Decide walking state based strictly on whether steps increased
    bool shouldBeWalking = false;

    // Check if steps increased
    if (_steps > _previousSteps) {
      shouldBeWalking = true;
      _lastStepUpdate = now;
      debugPrint(
        '🚶‍♂️ DUO CHALLENGE: Steps increased: $_previousSteps -> $_steps, user is walking',
      );

      // Move character forward based on exact number of steps added
      final int stepDelta = _steps - _previousSteps;
      _moveUserForward(stepDelta);

      // APPROACH 23: UPDATE PREVIOUS STEPS WHEN WALKING (like Solo Mode)
      // Update previous steps to current steps for next comparison
      _previousSteps = _steps;
      debugPrint(
          '📊 DUO CHALLENGE: Updated previous steps to: $_previousSteps');
    } else {
      // Steps didn't increase - user should be idle
      shouldBeWalking = false;
      debugPrint(
          '🛑 DUO CHALLENGE: Steps unchanged: $_steps, user should be idle');
    }

    // Apply state change only if it differs; avoid restarting animation when already walking
    if (_isUserWalking != shouldBeWalking) {
      debugPrint(
        '🔄 DUO CHALLENGE: State change needed: $_isUserWalking -> $shouldBeWalking',
      );
      _setWalkingState(shouldBeWalking);
    } else {
      debugPrint('✅ DUO CHALLENGE: State is correct: $_isUserWalking');
    }

    // No aggressive restart: keep walking continuously until idle timeout below

    // Idle timeout: stop walking only if no step increase for >= 1500ms
    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStepMs =
          now.difference(_lastStepUpdate!).inMilliseconds;
      debugPrint(
          '⏰ DUO CHALLENGE: Time since last step: ${timeSinceLastStepMs}ms');

      if (timeSinceLastStepMs >= _idleTimeoutMs) {
        // Force idle after timeout of no steps
        debugPrint(
          '⏰ DUO CHALLENGE: IDLE TIMEOUT: No steps for ${timeSinceLastStepMs}ms (>= $_idleTimeoutMs), FORCING IDLE',
        );
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      } else {
        debugPrint(
          '👀 DUO CHALLENGE: MONITORING: ${timeSinceLastStepMs}ms since last step - still in walking window',
        );
      }
    }

    // APPROACH 16: DEBUG CHARACTER STATE (like Solo Mode)
    if (_userGameInstance?.character != null) {
      debugPrint(
        '🎬 DUO CHALLENGE: Character state: isWalking=${_userGameInstance!.character!.isWalking}, animation=${_userGameInstance!.character!.animation == _userGameInstance!.character!.walkingAnimation ? "walking" : "idle"}',
      );

      // APPROACH 20: FORCE CHARACTER IDLE IF STEPS UNCHANGED (like Solo Mode)
      if (_steps == _previousSteps && _userGameInstance!.character!.isWalking) {
        debugPrint(
          '🚨 DUO CHALLENGE: CHARACTER FORCE: Steps unchanged but character is walking - FORCING IDLE',
        );
        _userGameInstance!.character!.isWalking = false;
        _userGameInstance!.updateWalkingState(false);
      }
    }
  }

  // NEW: Handle user win
  Future<void> _handleUserWin() async {
    debugPrint(
        '🔒 DUO CHALLENGE: _handleUserWin called - guards: _showingWinnerDialog=$_showingWinnerDialog, _gameEnded=$_gameEnded');
    if (_showingWinnerDialog || _gameEnded) {
      debugPrint('🔒 DUO CHALLENGE: _handleUserWin blocked by guards');
      return;
    }

    debugPrint('🔒 DUO CHALLENGE: _handleUserWin proceeding - setting state');
    setState(() {
      _showingWinnerDialog = true;
      _gameEnded = true;
    });

    debugPrint('🏆 DUO CHALLENGE: User won the challenge!');

    // Award coins to winner
    const int winnerCoins = 100;
    debugPrint('💰 DUO CHALLENGE: Awarding $winnerCoins coins to winner');
    final coinService = CoinService();
    await coinService.addCoins(winnerCoins);
    debugPrint('💰 DUO CHALLENGE: Coins awarded successfully');

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

    debugPrint('😢 DUO CHALLENGE: Opponent won the challenge');

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
                  debugPrint(
                      '🎮 DUO CHALLENGE: Error closing loser dialog: $e');
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
                  debugPrint(
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
                  debugPrint(
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
    debugPrint('🚪 DUO CHALLENGE: User quit the challenge');

    // Award full coins to opponent (same as winning normally)
    const int winnerCoins = 100;

    // Add coins to opponent's account
    if (_otherPlayerId != null && _otherPlayerId != 'waiting_for_opponent') {
      try {
        final coinService = CoinService();
        await coinService.addCoinsForUser(_otherPlayerId!, winnerCoins);
        debugPrint(
            '🎮 DUO CHALLENGE: Added $winnerCoins coins to opponent $_otherPlayerId');
      } catch (e) {
        debugPrint('🎮 DUO CHALLENGE: Error adding coins to opponent: $e');
      }
    }

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
                  debugPrint(
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
    // Reset the step counter baseline when leaving the game
    StepCounterService.resetStepBaseline();
    debugPrint(
        '🔄 DUO CHALLENGE: Step counter baseline reset when leaving game');

    try {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('🎮 DUO CHALLENGE: Error returning to home: $e');
      // Fallback: try to pop once
      try {
        Navigator.of(context).pop();
      } catch (e2) {
        debugPrint('🎮 DUO CHALLENGE: Error with fallback pop: $e2');
      }
    }
  }

  void _forceCharacterAnimationSync() {
    // Force immediate character animation sync to IDLE
    if (_userGameInstance?.character != null) {
      debugPrint('🔄 DUO CHALLENGE: FORCING character animation sync to IDLE');

      // Immediate state change - no delay or animation transition
      _userGameInstance!.character!.isWalking = false;
      _userGameInstance!.updateWalkingState(false);
    }
  }

  void _syncCharacterAnimation() {
    // Sync character animation immediately
    if (_userGameInstance != null && _userGameInstance!.character != null) {
      // Immediate state change - no delay or animation transition
      _userGameInstance!.character!.isWalking = _isUserWalking;
      _userGameInstance!.updateWalkingState(_isUserWalking);

      debugPrint(
        '✅ DUO CHALLENGE: Character animation synced: ${_isUserWalking ? "Walking" : "Idle"}',
      );
    } else {
      debugPrint(
          '⚠️ DUO CHALLENGE: Game instance not available for animation sync');
    }

    // Also sync opponent character animation
    _syncOpponentCharacterAnimation();
  }

  void _syncOpponentCharacterAnimation() {
    // Sync opponent character animation immediately
    if (_opponentGameInstance != null &&
        _opponentGameInstance!.character != null) {
      // Immediate state change - no delay or animation transition
      _opponentGameInstance!.character!.isWalking = _isOpponentWalking;
      _opponentGameInstance!.updateWalkingState(_isOpponentWalking);

      debugPrint(
        '✅ DUO CHALLENGE: Opponent character animation synced: ${_isOpponentWalking ? "Walking" : "Idle"}',
      );
    } else {
      debugPrint(
        '⚠️ DUO CHALLENGE: Opponent game instance not available for animation sync',
      );
    }
  }

  void _startCharacterWalking() {
    if (_userGameInstance?.character != null) {
      _userGameInstance!.updateWalkingState(true);
    }
    debugPrint('🎬 DUO CHALLENGE: Character walking animation started');
  }

  void _stopCharacterWalking() {
    if (_userGameInstance?.character != null) {
      _userGameInstance!.updateWalkingState(false);
    }
    debugPrint('🎬 DUO CHALLENGE: Character walking animation stopped');
  }

  /// IMMEDIATE OPPONENT ANIMATION UPDATE - No delays for instant player visibility
  void _updateOpponentCharacterAnimation(bool walking) {
    if (_opponentGameInstance != null &&
        _opponentGameInstance!.character != null) {
      debugPrint(
        '🎬 DUO CHALLENGE: IMMEDIATE opponent animation update to ${walking ? "walking" : "idle"}',
      );

      // IMMEDIATE state change - no delay or animation transition for instant player visibility
      _opponentGameInstance!.character!.isWalking = walking;
      _opponentGameInstance!.updateWalkingState(walking);

      debugPrint(
        '✅ DUO CHALLENGE: Opponent character animation updated IMMEDIATELY',
      );
    } else {
      debugPrint(
        '⚠️ DUO CHALLENGE: Opponent game instance or character not available for animation update',
      );
    }
  }

  // NEW: Verify character data is ready
  bool _isCharacterDataReady() {
    // Since we always provide fallback data in initState, this should always be true
    if (!_characterDataLoaded) {
      debugPrint('⚠️ DUO CHALLENGE: Character data not loaded yet');
      return false;
    }

    debugPrint('✅ DUO CHALLENGE: Character data is ready');
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
      debugPrint(
          '🎭 DUO CHALLENGE: Building user character widget with data: ${characterData?['currentCharacter'] ?? 'null'}');
      debugPrint(
          '🎭 DUO CHALLENGE: User sprite sheets in widget build: ${characterData?['spriteSheets']}');
    } else {
      characterData = _opponentCharacterData;
      debugPrint(
          '🎭 DUO CHALLENGE: Building opponent character widget with data: ${characterData?['currentCharacter'] ?? 'null'}');
      debugPrint(
          '🎭 DUO CHALLENGE: Opponent sprite sheets in widget build: ${characterData?['spriteSheets']}');
    }

    // Ensure we ALWAYS render a character: use temporary fallback until real data is ready
    if (characterData == null) {
      debugPrint(
          '⚠️ DUO CHALLENGE: Character data is null, using temporary fallback');
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
    if (characterData['spriteSheets'] == null) {
      debugPrint(
          '⚠️ DUO CHALLENGE: Sprite sheets missing, using temporary fallback');
      characterData['spriteSheets'] = {
        'idle': 'images/sprite_sheets/MyCharacter_idle.json',
        'walking': 'images/sprite_sheets/MyCharacter_walking.json',
      };
    }
    if (characterData['currentCharacter'] == null) {
      debugPrint(
          '⚠️ DUO CHALLENGE: currentCharacter missing, using temporary fallback');
      characterData['currentCharacter'] = 'MyCharacter';
    }

    debugPrint(
        '🎭 DUO CHALLENGE: Final character data for widget: ${characterData['currentCharacter']}');
    debugPrint(
        '🎭 DUO CHALLENGE: Final sprite sheets: ${characterData['spriteSheets']}');
    debugPrint(
        '🎭 DUO CHALLENGE: Widget build complete for ${isUser ? 'user' : 'opponent'} character');

    final identity = '${userId}_${characterData['currentCharacter']}';

    // Ensure animations are preloaded for this identity to avoid blank render
    final characterId = '${userId}_${characterData['currentCharacter']}';
    _ensureAnimationsPreloaded(characterId, characterData);

    // If animations are not ready yet, render a lightweight placeholder and retry soon
    final bool animationsReady =
        _animationService.isLoadedForCharacter(characterId);
    if (!animationsReady) {
      // Trigger a rebuild soon to swap in the GameWidget once ready
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) setState(() {});
      });
      return SizedBox(
        width: characterWidth,
        height: characterHeight,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Reuse existing Flame game to avoid animation restarts on rebuilds
    if (isUser) {
      if (_userGameInstance == null || _userGameIdentity != identity) {
        debugPrint('🎮 DUO CHALLENGE: Creating user game instance ($identity)');
        _userGameInstance = CharacterDisplayGame(
          isPlayer1: isPlayer1,
          isWalking: isWalking,
          userId: userId,
          faceRight: true,
          characterWidth: characterWidth,
          characterHeight: characterHeight,
          characterData: characterData,
        );
        _userGameIdentity = identity;

        // Initialize animation state once
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _userGameInstance?.character != null) {
            _userGameInstance!.character!.isWalking = _isUserWalking;
            _userGameInstance!.character!.updateAnimation(_isUserWalking);
          }
        });
      }

      return ClipRect(
        clipBehavior: Clip.hardEdge,
        child: GameWidget(
          key: ValueKey('user:${_userGameIdentity}'),
          game: _userGameInstance!,
        ),
      );
    } else {
      if (_opponentGameInstance == null || _opponentGameIdentity != identity) {
        debugPrint(
            '🎮 DUO CHALLENGE: Creating opponent game instance ($identity)');
        _opponentGameInstance = CharacterDisplayGame(
          isPlayer1: isPlayer1,
          isWalking: isWalking,
          userId: userId,
          faceRight: true,
          characterWidth: characterWidth,
          characterHeight: characterHeight,
          characterData: characterData,
        );
        _opponentGameIdentity = identity;

        // Initialize animation state immediately - no delays
        if (_opponentGameInstance?.character != null) {
          _opponentGameInstance!.character!.isWalking = _isOpponentWalking;
          _opponentGameInstance!.character!.updateAnimation(_isOpponentWalking);
        }

        // First-build kick for opponent
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateOpponentCharacterAnimation(_isOpponentWalking);
        });
      }

      return ClipRect(
        clipBehavior: Clip.hardEdge,
        child: GameWidget(
          key: ValueKey('opp:${_opponentGameIdentity}'),
          game: _opponentGameInstance!,
        ),
      );
    }
  }

  void _ensureAnimationsPreloaded(
      String characterId, Map<String, dynamic> data) {
    // Skip if already loaded or loading
    if (_animationService.isLoadedForCharacter(characterId) ||
        _animationService.isLoadingForCharacter(characterId)) {
      return;
    }
    // Kick off preload; when done, trigger rebuild for visibility
    _animationService
        .preloadAnimationsForCharacterWithData(characterId, data)
        .then((_) {
      if (mounted) setState(() {});
    }).catchError((e) {
      debugPrint('❌ DUO CHALLENGE: Preload failed for $characterId: $e');
    });
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
    // Reset the step counter baseline when game ends
    await StepCounterService.resetStepBaseline();
    debugPrint(
        '🔄 DUO CHALLENGE: Step counter baseline reset after game ended');

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
                  '+100 Coins',
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
                  debugPrint(
                      '🎮 DUO CHALLENGE: Error closing winner dialog: $e');
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
          debugPrint('🎮 DUO CHALLENGE: Error auto-closing winner dialog: $e');
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
        title: const Text('Step Duel'),
        backgroundColor: const Color(0xFFED3E57),
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

    // Track dimensions: ensure finish container is fully visible
    // The finish line container is 100px wide and centered at finishLinePosition
    // Need to extend track width to show the full container
    final double trackWidth = finishLinePosition + 50;
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
    // Each image covers screenWidth, so we need to cover exactly up to the finish line
    final double contentLimit =
        finishLinePosition; // Stop exactly at finish line
    final int buildingsRepeatCount = (contentLimit / screenWidth).ceil();
    final int roadRepeatCount = (contentLimit / screenWidth).ceil();

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
        if (_showWaitingForOpponent)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Waiting for your friend to come back…',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text('$_waitingSecondsLeft s',
                          style: const TextStyle(
                              fontSize: 18, color: Colors.orange)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Scrollable track container with manual scrolling enabled
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics:
              const ClampingScrollPhysics(), // Prevent overscroll beyond content
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
                  left: finishLinePosition -
                      50, // Position at actual finish line based on steps
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
                  top: roadTopY - characterHeight + 100 - 15, // Slightly higher
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
                  top: roadTopY - characterHeight + 100 + 15, // Slightly lower
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
                      (_otherPlayerId == null ||
                              _otherPlayerId == 'waiting_for_opponent')
                          ? SizedBox(
                              width: characterWidth,
                              height: characterHeight,
                            )
                          : SizedBox(
                              width: characterWidth,
                              height: characterHeight,
                              child: _buildGameWidget(
                                isPlayer1: false,
                                isWalking: _isOpponentWalking,
                                userId: _otherPlayerId!,
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
        // Removed bottom step prompt (characters move via steps only)
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
                    color: const Color(0xFFED3E57).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFED3E57)),
                  ),
                  child: Text(
                    '🎯 Goal: $_stepGoal Steps',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFED3E57),
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
                            color: Color(0xFFED3E57),
                          ),
                        ),
                        Text(
                          '$_steps',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFED3E57),
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
                        left: (_userPosition / finishLinePosition) *
                            (MediaQuery.of(context).size.width - 40),
                        top: 8,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFED3E57),
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
                          left: (_opponentPosition / finishLinePosition) *
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
      debugPrint(
          '🔄 DUO CHALLENGE: Character data not ready, forcing reload...');
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
    debugPrint('DUO CharacterDisplayGame onLoad start');
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

      // Do not force idle here; keep state consistent with isWalking

      add(character!);
      debugPrint(
        'DUO CharacterDisplayGame: Character added with smooth Solo Mode system',
      );
    } catch (e, st) {
      debugPrint('DUO CharacterDisplayGame onLoad error: $e');
      debugPrint(st.toString());
    }
  }

  @override
  void onGameResize(Vector2 sz) {
    super.onGameResize(sz);
    if (character != null) {
      character!
        ..anchor = Anchor.bottomCenter
        ..position = Vector2(sz.x / 2, sz.y);
    }
  }

  // Method to update walking state - Enhanced for smooth transitions (like Solo Mode)
  void updateWalkingState(bool walking) {
    if (character != null) {
      character!.isWalking = walking; // set the flag
      character!.updateAnimation(walking); // ALWAYS apply the clip
      debugPrint(
        '🎮 DUO Game: Character ${walking ? "started" : "stopped"} walking',
      );
    } else {
      debugPrint(
          '⚠️ DUO Game: Character not available for walking state update');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Movement is handled at the Flutter layer by positioning the GameWidget.
    // Keep character anchored and do not apply internal drift.
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
  Map<String, dynamic>? characterData;
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
    debugPrint('DUO Character onLoad start for userId: $userId');
    debugPrint('DUO Character onLoad: characterData: $characterData');
    debugPrint(
        'DUO Character onLoad: characterData spriteSheets: ${characterData?['spriteSheets']}');
    debugPrint(
        'DUO Character onLoad: characterData currentCharacter: ${characterData?['currentCharacter']}');

    try {
      // Ensure character data is available
      if (characterData == null) {
        debugPrint(
            '⚠️ DUO Character onLoad: Character data is null, using fallback');
        // Create a fallback character data
        characterData = {
          'owned_items': ['MyCharacter'],
          'currentCharacter': 'MyCharacter',
          'homeGlbPath': 'assets/web/home/MyCharacter_home.glb',
          'spriteSheets': {
            'idle': 'images/sprite_sheets/MyCharacter_idle.json',
            'walking': 'images/sprite_sheets/MyCharacter_walking.json',
          },
        };

        // Load fallback animations for THIS characterId (not current_user)
        final animationService = CharacterAnimationService();
        final String characterId =
            '${userId}_${characterData!['currentCharacter']}';
        await animationService.preloadAnimationsForCharacterWithData(
            characterId, characterData!);
        final animations =
            await animationService.getAnimationsForCharacter(characterId);
        idleAnimation = animations['idle'];
        walkingAnimation = animations['walking'];
        _animationsLoaded = true;

        if (_animationsLoaded && idleAnimation != null) {
          animation = idleAnimation;
          debugPrint(
              'DUO Character onLoad: Fallback per-character animations loaded successfully');
        }
        return;
      }

      // Load character-specific animations using the new multi-character service
      final animationService = CharacterAnimationService();

      // Create a unique character ID for this character instance
      final characterId =
          '${userId}_${characterData!['currentCharacter'] ?? 'default'}';

      debugPrint('DUO Character onLoad: Character ID: $characterId');
      debugPrint(
          'DUO Character onLoad: Character sprite sheets: ${characterData!['spriteSheets']}');

      try {
        // Load animations for this specific character using the character data
        if (characterData!['currentCharacter'] != null) {
          debugPrint(
              'DUO Character onLoad: Preloading animations for ${characterData!['currentCharacter']}');
          await animationService.preloadAnimationsForCharacterWithData(
              characterId, characterData!);
          debugPrint(
              'DUO Character onLoad: Preloaded character-specific animations for ${characterData!['currentCharacter']} (ID: $characterId)');
        } else {
          // Use default animations for current user
          debugPrint(
              'DUO Character onLoad: Using default animations for current user');
          await animationService.preloadAnimations();
        }

        // Get animations for this specific character
        debugPrint(
            'DUO Character onLoad: Getting animations for character ID: $characterId');
        final animations =
            await animationService.getAnimationsForCharacter(characterId);
        idleAnimation = animations['idle'];
        walkingAnimation = animations['walking'];
        _animationsLoaded = true;

        debugPrint(
            'DUO Character onLoad: Loaded character-specific animations for ${characterData!['currentCharacter'] ?? 'default'} (ID: $characterId)');
        debugPrint(
            'DUO Character onLoad: Idle animation loaded: ${idleAnimation != null}');
        debugPrint(
            'DUO Character onLoad: Walking animation loaded: ${walkingAnimation != null}');
        debugPrint(
            'DUO Character onLoad: Final sprite sheets used: ${characterData!['spriteSheets']}');
      } catch (e) {
        debugPrint(
            'DUO Character onLoad: Error loading character animations: $e');
        debugPrint('DUO Character onLoad: Stack trace: ${StackTrace.current}');

        // Fallback to per-character safe data instead of current_user
        try {
          final dataSvc = CharacterDataService();
          final picked =
              (characterData?['currentCharacter'] as String?) ?? 'MyCharacter';
          final safeData = {
            'currentCharacter': picked,
            'spriteSheets': dataSvc.getSpriteSheetsForCharacter(picked),
          };
          await animationService.preloadAnimationsForCharacterWithData(
              characterId, safeData);
          final animations =
              await animationService.getAnimationsForCharacter(characterId);
          idleAnimation = animations['idle'];
          walkingAnimation = animations['walking'];
          _animationsLoaded = true;
          debugPrint(
              'DUO Character onLoad: Using fallback per-character animations');
          debugPrint(
              'DUO Character onLoad: Fallback idle animation loaded: ${idleAnimation != null}');
          debugPrint(
              'DUO Character onLoad: Fallback walking animation loaded: ${walkingAnimation != null}');
        } catch (fallbackError) {
          debugPrint(
              'DUO Character onLoad: Fallback animation loading also failed: $fallbackError');
          debugPrint(
              'DUO Character onLoad: Fallback stack trace: ${StackTrace.current}');
          _animationsLoaded = false;
        }
      }

      if (_animationsLoaded) {
        // Pick the correct animation based on current isWalking flag
        animation = isWalking ? walkingAnimation : idleAnimation;
        debugPrint('DUO Character onLoad: Animation set from current state');
      } else {
        debugPrint(
            'DUO Character onLoad: WARNING - No animations loaded, character may not display properly');
        debugPrint(
            'DUO Character onLoad: _animationsLoaded: $_animationsLoaded');
        debugPrint('DUO Character onLoad: idleAnimation: $idleAnimation');
        debugPrint('DUO Character onLoad: walkingAnimation: $walkingAnimation');
      }

      debugPrint('DUO Character onLoad success');
    } catch (e, st) {
      debugPrint('DUO Character onLoad error: $e');
      debugPrint('DUO Character onLoad stack trace: $st');

      // Final fallback - load per-character safe animations
      try {
        final animationService = CharacterAnimationService();
        final dataSvc = CharacterDataService();
        final picked =
            (characterData?['currentCharacter'] as String?) ?? 'MyCharacter';
        final safeData = {
          'currentCharacter': picked,
          'spriteSheets': dataSvc.getSpriteSheetsForCharacter(picked),
        };
        final characterId = '${userId}_${picked}';
        await animationService.preloadAnimationsForCharacterWithData(
            characterId, safeData);
        final animations =
            await animationService.getAnimationsForCharacter(characterId);
        idleAnimation = animations['idle'];
        walkingAnimation = animations['walking'];
        _animationsLoaded = true;

        if (_animationsLoaded && idleAnimation != null) {
          animation = idleAnimation;
          debugPrint(
              'DUO Character onLoad: Final fallback per-character animations loaded');
        }
      } catch (finalError) {
        debugPrint(
            'DUO Character onLoad: Final fallback also failed: $finalError');
        _animationsLoaded = false;
      }
    }
  }

  void updateAnimation(bool walking) {
    // If not loaded yet, remember the desired state and exit; onLoad will apply it
    if (!_animationsLoaded ||
        idleAnimation == null ||
        walkingAnimation == null) {
      isWalking = walking;
      return;
    }

    final newAnimation = walking ? walkingAnimation : idleAnimation;

    // Only switch animation if it's actually different to prevent flickering
    if (animation != newAnimation) {
      animation = newAnimation;
    }
  }

  void startWalking() {
    debugPrint('🎬 DUO Character startWalking called');
    isWalking = true;
    updateAnimation(true);
  }

  void stopWalking() {
    debugPrint('🎬 DUO Character stopWalking called');
    isWalking = false;
    updateAnimation(false);
  }
}
