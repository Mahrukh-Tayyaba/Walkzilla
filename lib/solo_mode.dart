import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
// Removed unused import
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
// Removed unused import
import 'dart:async';
// Removed unused import
import 'services/character_animation_service.dart';
// Removed unused import
import 'services/health_service.dart';
import 'services/step_counter_service.dart';

class SoloMode extends StatefulWidget {
  const SoloMode({super.key});

  @override
  State<SoloMode> createState() => _SoloModeState();
}

class _SoloModeState extends State<SoloMode> {
  final FocusNode _focusNode = FocusNode();
  final HealthService _healthService = HealthService();
  SoloModeGame? _game; // Local game instance
  int _steps = 0;
  int _previousSteps = 0; // Track previous steps to detect movement
  bool _isLoading = true;
  bool _isUserWalking = false; // Track if user is currently walking
  StreamSubscription<Map<String, dynamic>>? _stepSubscription;
  DateTime? _lastStepUpdate; // Track when last step was detected
  bool _isInitialized = false; // Track if screen is fully initialized
  DateTime? _initializationTime; // Track when screen was initialized

  // Day change detection
  DateTime? _lastKnownDate;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      print('Game focus changed: ${_focusNode.hasFocus}');
    });

    // Set initialization time and start grace period
    _initializationTime = DateTime.now();
    print('🎯 SOLO MODE: Initialization started at $_initializationTime');

    // Initialize with walking state as false
    _isUserWalking = false;
    _initializeRealTimeTracking();

    // Mark as initialized after 3 seconds to prevent false walking detection
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _isInitialized = true;
        print(
            '🎯 SOLO MODE: Grace period ended, now accepting walking detection');
      }
    });
  }

  void _initializeRealTimeTracking() async {
    try {
      // Force reset walking state to ensure correct initial state
      setState(() {
        _isUserWalking = false;
        _lastStepUpdate = null; // Reset step history
      });

      // APPROACH 9: Use the same method as home.dart for consistency
      await _fetchStepsFromHomeMethod();

      // APPROACH 24: PROPERLY INITIALIZE STEP TRACKING
      // Set previous steps to current steps for proper comparison
      setState(() {
        _previousSteps = _steps;
      });
      print(
          '📊 Initialized step tracking: previous=$_previousSteps, current=$_steps');

      // Force walking state to false after initial fetch
      setState(() {
        _isUserWalking = false;
      });
      print('🔄 Force reset walking state after initial fetch');

      // Force character to idle state during initialization
      if (_game?.character != null) {
        _game!.character!.isWalking = false;
        _game!.character!.updateAnimation(false);
        print('🎬 INITIALIZATION: Forced character to idle state');
      }

      // APPROACH 26: START CONTINUOUS MONITORING
      _startContinuousMonitoring();

      // Use ONLY Health Connect monitoring to avoid false increments
      final hasPermissions =
          await _healthService.checkHealthConnectPermissions();

      if (hasPermissions) {
        // Start Health Connect monitoring only (no hybrid system)
        await _healthService.startRealTimeStepMonitoring();

        // Set up Health Connect listener
        _setupHealthConnectListener();

        print('✅ Health Connect monitoring started');
      } else {
        // Fallback to periodic polling if no permissions
        print('⚠️ No Health Connect permissions, using periodic polling');
        _startPeriodicUpdates();
      }
    } catch (e) {
      print('❌ Error initializing real-time tracking: $e');
      // Fallback to periodic polling
      _startPeriodicUpdates();
    }
  }

  // APPROACH 10: Use the animation-safe hybrid method
  Future<void> _fetchStepsFromHomeMethod() async {
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
          _isLoading = false;
        });

        // Check if user is walking (steps increased)
        _checkUserWalkingWithTiming(DateTime.now());

        print(
            '📱 SENSOR-OPTIMIZED: Fetched accurate steps: $stepsCount (previous: $_previousSteps)');

        // APPROACH 22: DEBUG STEP TRACKING
        print(
            '📊 Step tracking: previous=$_previousSteps, current=$_steps, difference=${_steps - _previousSteps}');
      }
    } catch (e) {
      print('❌ Error in animation-safe step fetch: $e');
      if (mounted) {
        setState(() {
          _steps = 0;
          _isLoading = false;
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
          _steps = accurateSteps; // Use accurate steps, not hybrid total
        });

        // Check if user is walking (steps increased)
        _checkUserWalkingWithTiming(DateTime.now());

        // Sync character animation
        _syncCharacterAnimation();

        print(
            '🏥 Health Connect update: +$stepIncrease steps (Accurate Total: $accurateSteps)');
      }
    });
  }

  // APPROACH 26: CONTINUOUS MONITORING SYSTEM
  void _startContinuousMonitoring() {
    print('🔄 Starting continuous monitoring system...');

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
        _startFrequentMonitoring(); // Recursive call
      }
    });
  }

  void _startBackupMonitoring() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkWalkingStateBackup();
        _startBackupMonitoring(); // Recursive call
      }
    });
  }

  void _startSafetyMonitoring() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _checkWalkingStateSafety();
        _startSafetyMonitoring(); // Recursive call
      }
    });
  }

  void _checkWalkingStateFrequently() {
    // GRACE PERIOD: Don't check walking state during initialization
    if (!_isInitialized) {
      return;
    }

    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep =
          DateTime.now().difference(_lastStepUpdate!).inSeconds;
      print('⚡ FREQUENT CHECK: Time since last step: ${timeSinceLastStep}s');

      if (timeSinceLastStep >= 5) {
        print(
            '⏰ FREQUENT 5-SECOND IDLE: No steps for ${timeSinceLastStep}s - FORCING IDLE NOW');
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      }
    }

    // APPROACH 29: CONTINUOUS CHARACTER SYNC
    // Always sync character animation with walking state
    if (mounted && _game?.character != null) {
      final characterIsWalking = _game!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        print(
            '🎬 FREQUENT SYNC: Character walking ($characterIsWalking) != User walking ($_isUserWalking) - FORCING SYNC');

        // APPROACH 34: AGGRESSIVE CHARACTER STATE FORCE
        _game!.character!.isWalking = _isUserWalking;
        _game!.character!.updateAnimation(_isUserWalking);

        // Force animation directly if still not synced
        if (!_isUserWalking && _game!.character!.idleAnimation != null) {
          print('🎬 FREQUENT FORCE: Directly setting idle animation');
          _game!.character!.animation = _game!.character!.idleAnimation;
        }
      }
    }
  }

  void _checkWalkingStateBackup() {
    // GRACE PERIOD: Don't check walking state during initialization
    if (!_isInitialized) {
      return;
    }

    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep =
          DateTime.now().difference(_lastStepUpdate!).inSeconds;
      print('🔄 BACKUP CHECK: Time since last step: ${timeSinceLastStep}s');

      if (timeSinceLastStep >= 5) {
        print(
            '⏰ BACKUP 5-SECOND IDLE: No steps for ${timeSinceLastStep}s - FORCING IDLE NOW');
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      }
    }

    // APPROACH 30: BACKUP CHARACTER SYNC
    if (mounted && _game?.character != null) {
      final characterIsWalking = _game!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        print(
            '🎬 BACKUP SYNC: Character walking ($characterIsWalking) != User walking ($_isUserWalking) - FORCING SYNC');

        // APPROACH 35: AGGRESSIVE BACKUP CHARACTER FORCE
        _game!.character!.isWalking = _isUserWalking;
        _game!.character!.updateAnimation(_isUserWalking);

        // Force animation directly if still not synced
        if (!_isUserWalking && _game!.character!.idleAnimation != null) {
          print('🎬 BACKUP FORCE: Directly setting idle animation');
          _game!.character!.animation = _game!.character!.idleAnimation;
        }
      }
    }
  }

  void _checkWalkingStateSafety() {
    // GRACE PERIOD: Don't check walking state during initialization
    if (!_isInitialized) {
      return;
    }

    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep =
          DateTime.now().difference(_lastStepUpdate!).inSeconds;
      print('🛡️ SAFETY CHECK: Time since last step: ${timeSinceLastStep}s');

      if (timeSinceLastStep >= 5) {
        print(
            '⏰ SAFETY 5-SECOND IDLE: No steps for ${timeSinceLastStep}s - FORCING IDLE NOW');
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      }
    }

    // APPROACH 31: SAFETY CHARACTER SYNC
    if (mounted && _game?.character != null) {
      final characterIsWalking = _game!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        print(
            '🎬 SAFETY SYNC: Character walking ($characterIsWalking) != User walking ($_isUserWalking) - FORCING SYNC');

        // APPROACH 36: AGGRESSIVE SAFETY CHARACTER FORCE
        _game!.character!.isWalking = _isUserWalking;
        _game!.character!.updateAnimation(_isUserWalking);

        // Force animation directly if still not synced
        if (!_isUserWalking && _game!.character!.idleAnimation != null) {
          print('🎬 SAFETY FORCE: Directly setting idle animation');
          _game!.character!.animation = _game!.character!.idleAnimation;
        }
      }
    }
  }

  void _setWalkingState(bool walking) {
    if (_isUserWalking != walking) {
      setState(() {
        _isUserWalking = walking;
      });
      walking ? _startCharacterWalking() : _stopCharacterWalking();
      print(walking ? '🚶‍♂️ User started walking' : '🛑 User stopped walking');

      // APPROACH 6: Additional safety check after state change
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _game?.character != null) {
          final characterIsWalking = _game!.character!.isWalking;
          if (characterIsWalking != walking) {
            print(
                '🛡️ Safety check: Character state mismatch, forcing correction');
            _game!.updateWalkingState(walking);
          }
        }
      });

      // APPROACH 13: IMMEDIATE ANIMATION FORCE
      if (!walking) {
        // When stopping walking, force idle animation immediately
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _game?.character != null) {
            print('🎬 IMMEDIATE: Forcing idle animation');
            _game!.character!.updateAnimation(false);
          }
        });
      }
    } else {
      // APPROACH 28: FORCE ANIMATION EVEN IF STATE IS SAME
      // If state is already correct but animation might not be
      print('🔄 State already correct ($walking), but forcing animation sync');
      walking ? _startCharacterWalking() : _stopCharacterWalking();

      // Force character animation immediately
      if (mounted && _game?.character != null) {
        print(
            '🎬 FORCE SYNC: Forcing character animation to ${walking ? "walking" : "idle"}');
        _game!.character!.updateAnimation(walking);
      }
    }
  }

  void _checkUserWalkingWithTiming(DateTime timestamp) {
    final now = DateTime.now();

    print(
        '🔍 Checking walking state: previous=$_previousSteps, current=$_steps, isWalking=$_isUserWalking, initialized=$_isInitialized');

    // GRACE PERIOD: Don't detect walking during initialization
    if (!_isInitialized) {
      print(
          '🎯 GRACE PERIOD: Screen not fully initialized, ignoring walking detection');
      return;
    }

    // APPROACH 1: Immediate detection with multiple checks
    bool shouldBeWalking = false;

    // Check if steps increased
    if (_steps > _previousSteps) {
      shouldBeWalking = true;
      _lastStepUpdate = now;
      print(
          '🚶‍♂️ Steps increased: $_previousSteps -> $_steps, user is walking');

      // APPROACH 23: UPDATE PREVIOUS STEPS WHEN WALKING
      // Update previous steps to current steps for next comparison
      _previousSteps = _steps;
      print('📊 Updated previous steps to: $_previousSteps');
    } else {
      // Steps didn't increase - user should be idle
      shouldBeWalking = false;
      print('🛑 Steps unchanged: $_steps, user should be idle');
    }

    // APPROACH 2: Force state change if different
    if (_isUserWalking != shouldBeWalking) {
      print('🔄 State change needed: $_isUserWalking -> $shouldBeWalking');
      _setWalkingState(shouldBeWalking);
    } else {
      print('✅ State is correct: $_isUserWalking');
    }

    // APPROACH 27: AGGRESSIVE WALKING FORCE
    // If steps are increasing but user is not marked as walking, force it
    if (_steps > _previousSteps && !_isUserWalking) {
      print(
          '🚨 AGGRESSIVE WALKING FORCE: Steps increasing but user not walking - FORCING WALKING');
      print(
          '🚨 AGGRESSIVE WALKING FORCE: $_previousSteps -> $_steps, forcing _isUserWalking = true');
      _setWalkingState(true);
    }

    // APPROACH 3: Additional safety check - force idle if no recent steps
    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep = now.difference(_lastStepUpdate!).inSeconds;
      print('⏰ Time since last step: ${timeSinceLastStep}s');

      if (timeSinceLastStep >= 5) {
        // Force idle after 5 seconds of no steps (proper idle detection)
        print(
            '⏰ 5-SECOND TIMEOUT: No steps for ${timeSinceLastStep}s, FORCING IDLE');
        print(
            '⏰ 5-SECOND TIMEOUT: User has stopped walking - switching to idle');
        _setWalkingState(false);
      } else if (timeSinceLastStep >= 3) {
        print(
            '⚠️ WARNING: No steps for ${timeSinceLastStep}s - preparing to force idle soon');
      } else if (timeSinceLastStep >= 1) {
        print(
            '👀 MONITORING: No steps for ${timeSinceLastStep}s - watching for idle state');
      }
    }

    // APPROACH 32: PROPER 5-SECOND IDLE DETECTION
    // Only force idle if steps haven't increased for 5 seconds
    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep = now.difference(_lastStepUpdate!).inSeconds;

      if (timeSinceLastStep >= 5) {
        print(
            '⏰ 5-SECOND IDLE: No steps for ${timeSinceLastStep}s, forcing idle');
        _setWalkingState(false);
        _forceCharacterAnimationSync();
      } else {
        print(
            '👀 MONITORING: ${timeSinceLastStep}s since last step - still in walking window');
      }
    }

    // APPROACH 16: DEBUG CHARACTER STATE
    if (_game?.character != null) {
      print(
          '🎬 Character state: isWalking=${_game!.character!.isWalking}, animation=${_game!.character!.animation == _game!.character!.walkingAnimation ? "walking" : "idle"}');

      // APPROACH 20: FORCE CHARACTER IDLE IF STEPS UNCHANGED
      if (_steps == _previousSteps && _game!.character!.isWalking) {
        print(
            '🚨 CHARACTER FORCE: Steps unchanged but character is walking - FORCING IDLE');
        _game!.character!.isWalking = false;
        _game!.character!.updateAnimation(false);
        if (_game!.character!.idleAnimation != null) {
          _game!.character!.animation = _game!.character!.idleAnimation;
          print('🎬 CHARACTER FORCE: Animation set to idle');
        }
      }
    }
  }

  void _forceCharacterAnimationSync() {
    // APPROACH 8: Force immediate character animation sync
    if (_game?.character != null) {
      print('🔄 FORCING character animation sync to IDLE');

      // APPROACH 37: ULTRA AGGRESSIVE CHARACTER FORCE
      _game!.character!.isWalking = false;
      _game!.character!.updateAnimation(false);
      _game!.character!.stopWalking();

      // Force idle animation directly
      if (_game!.character!.idleAnimation != null) {
        print('🎬 ULTRA FORCE: Setting animation to idleAnimation');
        _game!.character!.animation = _game!.character!.idleAnimation;

        // Force animation restart by reassignment
        print('🎬 ULTRA FORCE: Animation reassigned to force restart');
      }

      // Double-check state after forcing
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _game?.character != null) {
          final isWalking = _game!.character!.isWalking;
          if (isWalking) {
            print(
                '🎬 ULTRA FORCE: Character still walking after force, trying again');
            _game!.character!.isWalking = false;
            _game!.character!.updateAnimation(false);
          }
        }
      });
    }
  }

  // Day change detection
  void _checkForDayChange() {
    final currentDate = DateTime.now();

    if (_lastKnownDate == null) {
      _lastKnownDate = currentDate;
      return;
    }

    if (currentDate.day != _lastKnownDate!.day ||
        currentDate.month != _lastKnownDate!.month ||
        currentDate.year != _lastKnownDate!.year) {
      print('📅 DAY CHANGE DETECTED! Forcing step refresh...');
      print('📅 Previous date: ${_lastKnownDate!.toIso8601String()}');
      print('📅 Current date: ${currentDate.toIso8601String()}');

      // Force immediate refresh when day changes
      _fetchStepsFromHomeMethod();

      // Update last known date
      _lastKnownDate = currentDate;
    }
  }

  void _startPeriodicUpdates() {
    // APPROACH 5: More frequent updates with aggressive sync
    Future.delayed(const Duration(seconds: 5), () {
      // 5-second interval to ensure reliability
      if (mounted) {
        _fetchStepsFromHomeMethod();

        // Check for day change
        _checkForDayChange();

        // Force check walking state if still walking but no recent steps
        if (_isUserWalking && _lastStepUpdate != null) {
          final timeSinceLastStep =
              DateTime.now().difference(_lastStepUpdate!).inSeconds;
          print(
              '🔄 PERIODIC CHECK: Time since last step: ${timeSinceLastStep}s');

          if (timeSinceLastStep >= 5) {
            // Force idle after 5 seconds of no steps (proper idle detection)
            print(
                '⏰ PERIODIC 5-SECOND TIMEOUT: No steps for ${timeSinceLastStep}s - FORCING IDLE');
            print(
                '⏰ PERIODIC 5-SECOND TIMEOUT: User definitely stopped walking');
            _setWalkingState(false);
            _forceCharacterAnimationSync(); // Force immediate sync
          } else if (timeSinceLastStep >= 7) {
            print(
                '⚠️ PERIODIC WARNING: No steps for ${timeSinceLastStep}s - will force idle soon');
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
                '⏰ PERIODIC 5-SECOND IDLE: No steps for ${timeSinceLastStep}s, forcing idle');
            _setWalkingState(false);
            _forceCharacterAnimationSync();
          }
        }

        _startPeriodicUpdates(); // Recursive call for periodic updates
      }
    });
  }

  void _forceCharacterStateCheck() {
    // APPROACH 8: Force character state check
    if (_game?.character != null) {
      final characterIsWalking = _game!.character!.isWalking;
      if (characterIsWalking != _isUserWalking) {
        print(
            '🛡️ Force character state correction: character=$characterIsWalking, should=$_isUserWalking');
        _game!.updateWalkingState(_isUserWalking);
      }

      // APPROACH 11: AGGRESSIVE CHARACTER STATE FORCE
      if (_isUserWalking == false && characterIsWalking == true) {
        print(
            '🚨 AGGRESSIVE: Character is walking but should be idle - FORCING');
        _game!.character!.isWalking = false;
        _game!.character!.updateAnimation(false);
        _game!.character!.stopWalking();
      }
    }
  }

  void _debugWalkingState() {
    // Debug method to check current walking state
    final now = DateTime.now();
    final timeSinceLastStep = _lastStepUpdate != null
        ? now.difference(_lastStepUpdate!).inSeconds
        : 'No step history';

    print('🔍 DEBUG WALKING STATE:');
    print('  - Current steps: $_steps');
    print('  - Previous steps: $_previousSteps');
    print('  - Is walking: $_isUserWalking');
    print('  - Last step update: $_lastStepUpdate');
    print('  - Time since last step: $timeSinceLastStep seconds');
    print('  - Character walking: ${_game?.character?.isWalking}');

    // APPROACH 25: RESET STEP TRACKING IF NEEDED
    if (_steps != _previousSteps) {
      print('🔄 Resetting step tracking to current steps');
      setState(() {
        _previousSteps = _steps;
      });
    }
  }

  void _syncCharacterAnimation() {
    // APPROACH 4: Aggressive character animation sync with multiple attempts
    if (_game != null) {
      try {
        // Force update walking state
        _game!.updateWalkingState(_isUserWalking);

        // Additional check - ensure character state is correct
        if (_game!.character != null) {
          final characterIsWalking = _game!.character!.isWalking;
          if (characterIsWalking != _isUserWalking) {
            print(
                '🔄 Character state mismatch: character=$characterIsWalking, should=$_isUserWalking');
            // Force correct state
            _game!.updateWalkingState(_isUserWalking);
          }
        }

        print(
            '✅ Character animation synced: ${_isUserWalking ? "Walking" : "Idle"}');
      } catch (e) {
        print('❌ Error syncing character animation: $e');
      }
    } else {
      print('⚠️ Game instance not available for animation sync');
    }
  }

  Future<void> _fetchSteps() async {
    try {
      // Use sensor-optimized method to include accurate step data and responsive animations
      int steps = await _healthService.fetchHybridRealTimeSteps();
      if (mounted) {
        // Store the current steps as previous before updating
        int oldSteps = _steps;

        setState(() {
          _previousSteps = oldSteps; // Store the actual previous steps
          _steps = steps;
          _isLoading = false;
        });

        // Check if user is walking (steps increased)
        _checkUserWalkingWithTiming(DateTime.now());
      }
    } catch (e) {
      print('❌ Error in fallback step fetch: $e');
      if (mounted) {
        setState(() {
          _steps = 0;
          _isLoading = false;
        });
      }
    }
  }

  void _startCharacterWalking() {
    // Start character walking animation with proper error handling
    try {
      _game?.updateWalkingState(true);
      print('🎬 Character walking animation started');
    } catch (e) {
      print('❌ Error starting character walking: $e');
    }
  }

  void _stopCharacterWalking() {
    // Stop character walking animation with proper error handling
    try {
      _game?.updateWalkingState(false);
      print('🎬 Character walking animation stopped');
    } catch (e) {
      print('❌ Error stopping character walking: $e');
    }
  }

  void _checkAnimationStatus() async {
    final animationService = CharacterAnimationService();

    // If not loaded and not loading, start preloading
    if (!animationService.isLoaded && !animationService.isLoading) {
      animationService.preloadAnimations();
    }

    // Wait for animations to be ready using the service method
    await animationService.waitForLoad();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Ensure character animation is working
  void _ensureCharacterAnimation() {
    // Make sure the game instance and character are available
    if (_game?.character != null) {
      print('✅ Character animation system ready');
      // Ensure character starts in idle state
      _game!.updateWalkingState(false);
    } else {
      print('⚠️ Character animation system not ready yet');
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _stepSubscription?.cancel();
    _healthService.stopRealTimeStepMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.of(context).pop(),
              splashRadius: 20,
              color: Colors.black,
              padding: const EdgeInsets.only(left: 8, right: 4),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading character animations...'),
                ],
              ),
            )
          : Stack(
              children: [
                // Game Widget as background
                GameWidget(
                  game: _game ??= SoloModeGame(),
                  focusNode: _focusNode,
                  autofocus: true,
                  // APPROACH 5: Prevent game re-instantiation
                  key: const ValueKey('solo_mode_game'),
                ),

                // Unified Stats Container - positioned as overlay
                Positioned(
                  top: 90,
                  left: 32,
                  right: 32,
                  child: GestureDetector(
                    onTap: () async {
                      // Manual refresh for testing
                      await _fetchStepsFromHomeMethod();
                      _ensureCharacterAnimation();
                      _syncCharacterAnimation();
                      _debugWalkingState();

                      // APPROACH 18: MANUAL FORCE IDLE FOR TESTING
                      print('🔧 Manual force idle triggered');
                      _setWalkingState(false);
                      _forceCharacterAnimationSync();

                      // Force character to idle immediately
                      if (_game?.character != null) {
                        print('🎬 MANUAL: Forcing character to idle');
                        _game!.character!.isWalking = false;
                        _game!.character!.updateAnimation(false);
                        if (_game!.character!.idleAnimation != null) {
                          _game!.character!.animation =
                              _game!.character!.idleAnimation;
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isLoading
                              ? const CircularProgressIndicator()
                              : Text(
                                  _steps.toString(),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(255, 7, 50, 86),
                                  ),
                                ),
                          if (!_isLoading) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isUserWalking
                                      ? Icons.directions_walk
                                      : Icons.accessibility_new,
                                  color: _isUserWalking
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isUserWalking ? 'Walking' : 'Idle',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _isUserWalking
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Step Progress Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: StepProgressBar(currentSteps: _steps, stepGoal: 6000),
                ),
              ],
            ),
    );
  }
}

class Character extends SpriteAnimationComponent with KeyboardHandler {
  SpriteAnimation? idleAnimation;
  SpriteAnimation? walkingAnimation;
  bool isWalking = false;
  double moveSpeed = 100.0; // Reduced speed for smoother movement
  bool _animationsLoaded = false;

  Character()
      : super(size: Vector2(300, 300)); // Reduced size for better performance

  @override
  Future<void> onLoad() async {
    print('Character onLoad start');
    try {
      // Use preloaded animations from service
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
      // position = Vector2(20, 250);
      print('Character onLoad success');
    } catch (e, st) {
      print('Character onLoad error: $e');
      print(st);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // APPROACH 1: Force recheck animation every frame
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
      print('⚠️ Character updateAnimation: Animations not loaded');
      return;
    }

    final newAnimation = walking ? walkingAnimation : idleAnimation;

    if (animation != newAnimation) {
      print(
          '🔄 Character: Switching animation to ${walking ? "walking" : "idle"}');
      animation = newAnimation;
      // Force animation restart by reassigning
      print('🎬 Animation switched and will restart');
    }
  }

  void startWalking() {
    print('🎬 Character startWalking called');
    isWalking = true;
    updateAnimation(true);
  }

  void stopWalking() {
    print('🎬 Character stopWalking called');
    isWalking = false;
    updateAnimation(false);
  }
}

class SoloModeGame extends FlameGame with KeyboardEvents {
  static SoloModeGame? instance;
  Character? character;
  SpriteComponent? skyA;
  SpriteComponent? skyB;
  SpriteComponent? bushesA;
  SpriteComponent? bushesB;
  SpriteComponent? pathA;
  SpriteComponent? pathB;
  final double baseWidth = 1200;
  final double baseHeight = 2400;
  final double bushesHeight = 1841;
  final double pathHeight = 559;
  final double walkSpeed = 150; // pixels per second, adjust as needed

  SoloModeGame() {
    instance = this;
  }

  void updateWalkingState(bool walking) {
    if (character != null) {
      character!.isWalking = walking;
      character!.updateAnimation(walking);
      print('🎮 Game: Character ${walking ? "started" : "stopped"} walking');
    } else {
      print('⚠️ Game: Character not available for walking state update');
    }
  }

  @override
  Future<void> onLoad() async {
    print('SoloModeGame onLoad start');
    await super.onLoad();
    final screenWidth = size.x;
    final screenHeight = size.y;
    final scaleX = screenWidth / baseWidth;
    final scaleY = screenHeight / baseHeight;
    try {
      // Layer 1: Sky (endless scroll)
      final skySprite = await loadSprite('sky.png');
      skyA = SpriteComponent(
        sprite: skySprite,
        size: Vector2(screenWidth, screenHeight),
        position: Vector2(0, 0),
      );
      skyB = SpriteComponent(
        sprite: skySprite,
        size: Vector2(screenWidth, screenHeight),
        position: Vector2(screenWidth, 0),
      );
      add(skyA!);
      add(skyB!);

      // Layer 2: Bushes (endless scroll)
      final bushesSprite = await loadSprite('bushes.png');
      final double bushesH = bushesHeight * scaleY;
      bushesA = SpriteComponent(
        sprite: bushesSprite,
        size: Vector2(screenWidth, bushesH),
        position: Vector2(0, 0),
      );
      bushesB = SpriteComponent(
        sprite: bushesSprite,
        size: Vector2(screenWidth, bushesH),
        position: Vector2(screenWidth, 0),
      );
      add(bushesA!);
      add(bushesB!);

      // Layer 2.1: Path (endless scroll)
      final pathSprite = await loadSprite('path.png');
      final double pathH = pathHeight * scaleY;
      final double pathY = screenHeight - pathH;
      pathA = SpriteComponent(
        sprite: pathSprite,
        size: Vector2(screenWidth, pathH),
        position: Vector2(0, pathY),
      );
      pathB = SpriteComponent(
        sprite: pathSprite,
        size: Vector2(screenWidth, pathH),
        position: Vector2(screenWidth, pathY),
      );
      add(pathA!);
      add(pathB!);

      // Layer 3: Character (on top of path)
      // Compensate for transparent pixels at the bottom of the character sprite
      final double transparentBottomPx = 140; // Adjust this value as needed
      final double transparentOffset = transparentBottomPx * scaleY;
      character = Character();
      character!.size =
          Vector2(800 * scaleX, 800 * scaleY); // 800x800 base size
      character!.anchor = Anchor.bottomLeft;
      character!.position = Vector2(
        100 * scaleX, // X position (adjust as needed)
        screenHeight -
            (pathHeight * scaleY) +
            transparentOffset, // Y = top of path + offset
      );
      add(character!);

      // Ensure character starts in idle state during initialization
      character!.isWalking = false;
      character!.updateAnimation(false);
      print('🎬 GAME INITIALIZATION: Character forced to idle state');

      print('SoloModeGame onLoad success');
    } catch (e, st) {
      print('SoloModeGame onLoad error: $e');
      print(st);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (character?.isWalking == true) {
      final double dx = walkSpeed * dt;
      // APPROACH 3: Add debug logging for background movement
      print('🎮 Game: Moving background (character walking)');

      // Sky
      skyA?.x -= dx;
      skyB?.x -= dx;
      // Loop sky
      if (skyA != null && skyB != null) {
        if (skyA!.x <= -size.x) {
          skyA!.x = skyB!.x + size.x;
        }
        if (skyB!.x <= -size.x) {
          skyB!.x = skyA!.x + size.x;
        }
      }
      // Bushes
      bushesA?.x -= dx;
      bushesB?.x -= dx;
      if (bushesA != null && bushesB != null) {
        if (bushesA!.x <= -size.x) {
          bushesA!.x = bushesB!.x + size.x;
        }
        if (bushesB!.x <= -size.x) {
          bushesB!.x = bushesA!.x + size.x;
        }
      }
      // Path
      pathA?.x -= dx;
      pathB?.x -= dx;
      if (pathA != null && pathB != null) {
        if (pathA!.x <= -size.x) {
          pathA!.x = pathB!.x + size.x;
        }
        if (pathB!.x <= -size.x) {
          pathB!.x = pathA!.x + size.x;
        }
      }
    } else {
      // APPROACH 4: Debug when character is not walking
      if (character != null) {
        print('🎮 Game: Background stopped (character idle)');
      }
    }
  }
}

class StepProgressBar extends StatelessWidget {
  final int currentSteps;
  final int stepGoal;
  const StepProgressBar({
    super.key,
    required this.currentSteps,
    required this.stepGoal,
  });

  @override
  Widget build(BuildContext context) {
    final double barWidth = MediaQuery.of(context).size.width - 64.0;
    final double progress =
        (currentSteps.toDouble() / stepGoal.toDouble()).clamp(0.0, 1.0);
    final double indicatorRadius = 16.0;
    final double indicatorLeft =
        (progress * (barWidth - indicatorRadius * 2)) + indicatorRadius;
    return Padding(
      padding: const EdgeInsets.only(left: 32, right: 32, bottom: 60),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Unfilled track
            Positioned(
              left: 0,
              top: 16,
              child: Container(
                width: barWidth,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A4A5A), // deep blue-grey
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            // Filled progress
            Positioned(
              left: 0,
              top: 16,
              child: Container(
                width: (progress * barWidth).clamp(0.0, barWidth),
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3), // blue accent
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            // Goal line and arrow
            Positioned(
              left: barWidth - 1.5,
              top: 8,
              child: Column(
                children: [
                  Container(
                    width: 3,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(Icons.arrow_forward,
                      color: Colors.white, size: 16),
                ],
              ),
            ),
            // Progress indicator
            Positioned(
              left: (indicatorLeft - indicatorRadius)
                  .clamp(0.0, barWidth - indicatorRadius * 2),
              top: 6,
              child: Container(
                width: indicatorRadius * 2,
                height: indicatorRadius * 2,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Center(
                  child: Icon(Icons.directions_walk,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
