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
  bool _gameStarted = false;
  String? _winner;
  bool _gameEnded = false;
  bool _isLoadingCharacters = true;
  String? _otherPlayerId;

  // Step-based racing system variables
  double _userPosition = 0.0;
  double _opponentPosition = 0.0;
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
    // Update the invite document to mark game as started
    await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .update({
      'gameStarted': true,
      'gameStartTime': FieldValue.serverTimestamp(),
      'positions': {
        _userId: 0.0,
        // The other player's position will be updated when they join
      },
      'steps': {
        _userId: 0,
        // The other player's steps will be updated when they join
      },
      'scores': {
        _userId: 0,
        // The other player's score will be updated when they join
      },
    });
  }

  void _startGameStateListener() {
    final docRef =
        _firestore.collection('duo_challenge_invites').doc(widget.inviteId);

    _gameStateSubscription = docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final positions = (data['positions'] ?? {}) as Map<String, dynamic>;
      final steps = (data['steps'] ?? {}) as Map<String, dynamic>;
      final gameEnded = data['gameEnded'] ?? false;
      final winner = data['winner'] as String?;

      // Update opponent position and steps in real-time
      final otherPlayerId =
          positions.keys.where((key) => key != _userId).firstOrNull;
      if (otherPlayerId != null) {
        final opponentPos = (positions[otherPlayerId] ?? 0.0).toDouble();
        final opponentSteps = (steps[otherPlayerId] ?? 0) as int;

        if (_opponentPosition != opponentPos) {
          setState(() {
            _opponentPosition = opponentPos;
            _opponentSteps = opponentSteps;
            _otherPlayerId = otherPlayerId;
            _isOpponentWalking = true; // Start walking animation
          });

          // Update opponent character animation
          _updateOpponentCharacterAnimation(true);

          // Stop walking animation after a short delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _isOpponentWalking = false;
              });
              _updateOpponentCharacterAnimation(false);
            }
          });
        }
      }

      // Check for game end
      if (gameEnded && !_gameEnded) {
        setState(() {
          _gameEnded = true;
          _winner = winner;
        });
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
    try {
      // Force reset walking state to ensure correct initial state
      setState(() {
        _isUserWalking = false;
        _lastStepUpdate = null;
      });

      // Use the same method as Solo Mode for consistency
      await _fetchStepsFromHealthService();

      // Set previous steps to current steps for proper comparison
      setState(() {
        _previousSteps = _steps;
      });
      print(
        '📊 DUO CHALLENGE: Initialized step tracking: previous=$_previousSteps, current=$_steps',
      );

      // Force walking state to false after initial fetch
      setState(() {
        _isUserWalking = false;
      });
      print('🔄 DUO CHALLENGE: Force reset walking state after initial fetch');

      // Force character to idle state during initialization
      if (_userGameInstance?.character != null) {
        _userGameInstance!.character!.isWalking = false;
        _userGameInstance!.character!.updateAnimation(false);
        print('🎬 DUO CHALLENGE: Forced character to idle state');
      }

      // Start continuous monitoring
      _startContinuousMonitoring();

      // Use Health Connect monitoring
      final hasPermissions =
          await _healthService.checkHealthConnectPermissions();
      if (hasPermissions) {
        await _healthService.startRealTimeStepMonitoring();
        _setupHealthConnectListener();
        print('✅ DUO CHALLENGE: Health Connect monitoring started');
      } else {
        print(
          '⚠️ DUO CHALLENGE: No Health Connect permissions, using periodic polling',
        );
        _startPeriodicUpdates();
      }
    } catch (e) {
      print('❌ DUO CHALLENGE: Error initializing step tracking: $e');
      _startPeriodicUpdates();
    }
  }

  Future<void> _fetchStepsFromHealthService() async {
    try {
      // Use the sensor-optimized method for accurate steps and responsive animations
      final stepsCount = await _healthService.fetchHybridRealTimeSteps();

      if (mounted) {
        // Store the current steps as previous before updating
        int oldSteps = _steps;

        setState(() {
          _previousSteps = oldSteps;
          _steps = stepsCount;
        });

        // Check if user is walking (steps increased)
        _checkUserWalkingWithTiming(DateTime.now());

        print(
          '📱 DUO CHALLENGE: Fetched accurate steps: $stepsCount (previous: $_previousSteps)',
        );
        print(
          '📊 DUO CHALLENGE: Step tracking: previous=$_previousSteps, current=$_steps, difference=${_steps - _previousSteps}',
        );
      }
    } catch (e) {
      print('❌ DUO CHALLENGE: Error in step fetch: $e');
      if (mounted) {
        setState(() {
          _steps = 0;
        });
      }
    }
  }

  void _setupHealthConnectListener() {
    // Set up callback for Health Connect step updates
    _healthService.setStepUpdateCallback((totalSteps, stepIncrease) async {
      if (mounted) {
        // Use sensor-optimized method to get accurate step count
        final accurateSteps = await _healthService.fetchHybridRealTimeSteps();

        // Update steps and check walking state
        setState(() {
          _previousSteps = _steps;
          _steps = accurateSteps;
        });

        // Check if user is walking (steps increased)
        _checkUserWalkingWithTiming(DateTime.now());

        // Sync character animation
        _syncCharacterAnimation();

        print(
          '🏥 DUO CHALLENGE: Health Connect update: +$stepIncrease steps (Accurate Total: $accurateSteps)',
        );
      }
    });
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
    if (!_isInitialized) return;

    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep =
          DateTime.now().difference(_lastStepUpdate!).inSeconds;
      if (timeSinceLastStep >= 5) {
        print(
          '⏰ DUO CHALLENGE: FREQUENT 5-SECOND IDLE: No steps for ${timeSinceLastStep}s - FORCING IDLE NOW',
        );
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      }
    }

    // Always sync character animation with walking state
    if (mounted && _userGameInstance?.character != null) {
      final characterIsWalking = _userGameInstance!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        print(
          '🎬 DUO CHALLENGE: FREQUENT SYNC: Character walking ($characterIsWalking) != User walking ($_isUserWalking) - FORCING SYNC',
        );
        _userGameInstance!.character!.isWalking = _isUserWalking;
        _userGameInstance!.character!.updateAnimation(_isUserWalking);
      }
    }
  }

  void _checkWalkingStateBackup() {
    if (!_isInitialized) return;

    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep =
          DateTime.now().difference(_lastStepUpdate!).inSeconds;
      if (timeSinceLastStep >= 5) {
        print(
          '⏰ DUO CHALLENGE: BACKUP 5-SECOND IDLE: No steps for ${timeSinceLastStep}s - FORCING IDLE NOW',
        );
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      }
    }

    if (mounted && _userGameInstance?.character != null) {
      final characterIsWalking = _userGameInstance!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        print(
          '🎬 DUO CHALLENGE: BACKUP SYNC: Character walking ($characterIsWalking) != User walking ($_isUserWalking) - FORCING SYNC',
        );
        _userGameInstance!.character!.isWalking = _isUserWalking;
        _userGameInstance!.character!.updateAnimation(_isUserWalking);
      }
    }
  }

  void _checkWalkingStateSafety() {
    if (!_isInitialized) return;

    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep =
          DateTime.now().difference(_lastStepUpdate!).inSeconds;
      if (timeSinceLastStep >= 5) {
        print(
          '⏰ DUO CHALLENGE: SAFETY 5-SECOND IDLE: No steps for ${timeSinceLastStep}s - FORCING IDLE NOW',
        );
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      }
    }

    if (mounted && _userGameInstance?.character != null) {
      final characterIsWalking = _userGameInstance!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        print(
          '🎬 DUO CHALLENGE: SAFETY SYNC: Character walking ($characterIsWalking) != User walking ($_isUserWalking) - FORCING SYNC',
        );
        _userGameInstance!.character!.isWalking = _isUserWalking;
        _userGameInstance!.character!.updateAnimation(_isUserWalking);
      }
    }
  }

  void _setWalkingState(bool walking) {
    if (_isUserWalking != walking) {
      setState(() {
        _isUserWalking = walking;
      });

      if (walking) {
        _startCharacterWalking();
        _moveUserForward();
      } else {
        _stopCharacterWalking();
      }

      print(
        walking
            ? '🚶‍♂️ DUO CHALLENGE: User started walking'
            : '🛑 DUO CHALLENGE: User stopped walking',
      );
    } else {
      // Force animation even if state is same
      print(
        '🔄 DUO CHALLENGE: State already correct ($walking), but forcing animation sync',
      );
      walking ? _startCharacterWalking() : _stopCharacterWalking();

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

    // Move user forward by a small amount (similar to Solo Mode movement)
    const double moveIncrement =
        10.0; // Smaller increment for smoother movement
    setState(() {
      _userPosition += moveIncrement;
    });

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

    // GRACE PERIOD: Don't detect walking during initialization
    if (!_isInitialized) {
      print(
        '🎯 DUO CHALLENGE: GRACE PERIOD: Screen not fully initialized, ignoring walking detection',
      );
      return;
    }

    // Check if steps increased
    bool shouldBeWalking = false;
    if (_steps > _previousSteps) {
      shouldBeWalking = true;
      _lastStepUpdate = now;
      print(
        '🚶‍♂️ DUO CHALLENGE: Steps increased: $_previousSteps -> $_steps, user is walking',
      );
      _previousSteps = _steps;
      print('📊 DUO CHALLENGE: Updated previous steps to: $_previousSteps');
    } else {
      shouldBeWalking = false;
      print('🛑 DUO CHALLENGE: Steps unchanged: $_steps, user should be idle');
    }

    // Force state change if different
    if (_isUserWalking != shouldBeWalking) {
      print(
        '🔄 DUO CHALLENGE: State change needed: $_isUserWalking -> $shouldBeWalking',
      );
      _setWalkingState(shouldBeWalking);
    } else {
      print('✅ DUO CHALLENGE: State is correct: $_isUserWalking');
    }

    // Force idle if no recent steps
    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep = now.difference(_lastStepUpdate!).inSeconds;
      if (timeSinceLastStep >= 5) {
        print(
          '⏰ DUO CHALLENGE: 5-SECOND TIMEOUT: No steps for ${timeSinceLastStep}s, FORCING IDLE',
        );
        _setWalkingState(false);
      }
    }
  }

  void _forceCharacterAnimationSync() {
    if (_userGameInstance?.character != null) {
      print('🔄 DUO CHALLENGE: FORCING character animation sync to IDLE');
      _userGameInstance!.character!.isWalking = false;
      _userGameInstance!.character!.updateAnimation(false);
      _userGameInstance!.character!.stopWalking();
    }
  }

  void _startPeriodicUpdates() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _fetchStepsFromHealthService();
        _syncCharacterAnimation();
        _startPeriodicUpdates();
      }
    });
  }

  void _syncCharacterAnimation() {
    if (_userGameInstance != null) {
      try {
        _userGameInstance!.updateWalkingState(_isUserWalking);
        print(
          '✅ DUO CHALLENGE: Character animation synced: ${_isUserWalking ? "Walking" : "Idle"}',
        );
      } catch (e) {
        print('❌ DUO CHALLENGE: Error syncing character animation: $e');
      }
    }
  }

  void _startCharacterWalking() {
    try {
      _userGameInstance?.updateWalkingState(true);
      print('🎬 DUO CHALLENGE: Character walking animation started');
    } catch (e) {
      print('❌ DUO CHALLENGE: Error starting character walking: $e');
    }
  }

  void _stopCharacterWalking() {
    try {
      _userGameInstance?.updateWalkingState(false);
      print('🎬 DUO CHALLENGE: Character walking animation stopped');
    } catch (e) {
      print('❌ DUO CHALLENGE: Error stopping character walking: $e');
    }
  }

  void _updateUserCharacterAnimation(bool walking) {
    print('_updateUserCharacterAnimation called with walking: $walking');
    print('_userGameInstance is null: ${_userGameInstance == null}');
    try {
      if (_userGameInstance != null) {
        print('Calling updateWalkingState on user game instance');
        _userGameInstance!.updateWalkingState(walking);
      } else {
        print('User game instance is null, cannot update animation');
      }
    } catch (e) {
      print('Error updating user character animation: $e');
    }
  }

  void _updateOpponentCharacterAnimation(bool walking) {
    try {
      if (_opponentGameInstance != null) {
        _opponentGameInstance!.updateWalkingState(walking);
      }
    } catch (e) {
      print('Error updating opponent character animation: $e');
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

    // Calculate target scroll position to center the user character
    final screenWidth = MediaQuery.of(context).size.width;
    final targetScroll =
        _userPosition - (screenWidth / 2) + 150; // +150 to center the character

    // Ensure scroll position is within bounds
    final maxScroll = _scrollController.position.maxScrollExtent;
    final clampedTarget = targetScroll.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clampedTarget,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
        // Scrollable track container
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
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
                // Finish line marker
                Positioned(
                  left: trackWidth - 100, // 100px from the end (at 9500px)
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
                // User character positioned on the road
                Positioned(
                  left: _userPosition - characterWidth / 2,
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
                // Opponent character positioned on the road
                if (_otherPlayerId != null)
                  Positioned(
                    left: _opponentPosition - characterWidth / 2,
                    top: roadTopY - characterHeight + 100, // Feet on road
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // The label, positioned exactly at the top of the character
                        Positioned(
                          top: 0,
                          child: nameLabel(widget.otherUsername ?? 'Opponent'),
                        ),
                        // The character, positioned directly below the label
                        SizedBox(
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
        // Step-based movement indicator (replaces manual arrow button)
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: () async {
                // Debug: Manual step increment for testing
                print('🔧 DUO CHALLENGE: Manual step increment triggered');
                setState(() {
                  _previousSteps = _steps;
                  _steps += 10; // Simulate 10 steps
                });
                _checkUserWalkingWithTiming(DateTime.now());
                _syncCharacterAnimation();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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
                          : 'Tap to test step movement',
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
                          'Steps: $_steps',
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
                            '${widget.otherUsername ?? 'Opponent'}: ${_opponentPosition.toInt()}m',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'Steps: $_opponentSteps',
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
                              color: Colors.orange,
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

// Update CharacterDisplayGame to accept characterWidth and characterHeight
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
    await super.onLoad();
    final screenWidth = size.x;
    final screenHeight = size.y;

    try {
      // No background layers here, only character
      character = Character(userId: userId);
      character!.size = Vector2(characterWidth, characterHeight);
      character!.anchor = Anchor.bottomCenter;
      character!.position = Vector2(
        screenWidth / 2,
        screenHeight,
      ); // Centered in widget
      if (!faceRight) {
        character!.flipHorizontally();
      }
      if (isWalking) {
        character!.startWalking();
      }
      add(character!);
    } catch (e) {
      print('CharacterDisplayGame onLoad error: $e');
    }
  }

  // Method to update walking state
  void updateWalkingState(bool walking) {
    print(
      'CharacterDisplayGame updateWalkingState called with walking: $walking',
    );
    print('Character is null: ${character == null}');
    isWalking = walking;
    if (character != null) {
      if (walking) {
        print('Calling character.startWalking()');
        character!.startWalking();
      } else {
        print('Calling character.stopWalking()');
        character!.stopWalking();
      }
    } else {
      print('Character is null, cannot update walking state');
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    print('Key event detected: ${event.logicalKey}');
    isWalking = keysPressed.contains(LogicalKeyboardKey.arrowRight);
    print('isWalking set to: $isWalking');
    if (character != null) {
      if (isWalking) {
        character!.startWalking();
      } else {
        character!.stopWalking();
      }
    } else {
      print('Character is null');
    }
    return KeyEventResult.handled;
  }
}

// Character component for display
class Character extends SpriteAnimationComponent with HasGameRef {
  final String userId;
  SpriteAnimation? idleAnimation;
  SpriteAnimation? walkingAnimation;
  bool isWalking = false;
  bool _animationsLoaded = false;

  Character({required this.userId})
      : super(size: Vector2(300, 300)); // Same size as solo mode

  @override
  Future<void> onLoad() async {
    print('Character onLoad started for userId: $userId');
    try {
      // Use character animation service like solo mode
      final animationService = CharacterAnimationService();

      if (animationService.isLoaded) {
        // Use cached animations
        idleAnimation = animationService.idleAnimation;
        walkingAnimation = animationService.walkingAnimation;
        _animationsLoaded = true;
        print('Character onLoad: Using cached animations');
      } else {
        // Wait for animations to load or load them now
        print('Character onLoad: Loading animations from service...');
        final animations = await animationService.getAnimations();
        idleAnimation = animations['idle'];
        walkingAnimation = animations['walking'];
        _animationsLoaded = true;
        print('Character onLoad: Animations loaded from service');
      }

      animation = idleAnimation;
      print('Character onLoad completed successfully');
    } catch (e) {
      print('Character onLoad error: $e');
    }
  }

  void startWalking() {
    print('Character startWalking called');
    isWalking = true;
    updateAnimation(true);
  }

  void stopWalking() {
    print('Character stopWalking called');
    isWalking = false;
    updateAnimation(false);
  }

  void updateAnimation(bool walking) {
    print('Character updateAnimation called with walking: $walking');
    if (!_animationsLoaded ||
        idleAnimation == null ||
        walkingAnimation == null) {
      print('Animations not loaded or null');
      return;
    }
    if (walking && animation != walkingAnimation) {
      print('Switching to walking animation');
      animation = walkingAnimation;
    } else if (!walking && animation != idleAnimation) {
      print('Switching to idle animation');
      animation = idleAnimation;
    }
  }
}
