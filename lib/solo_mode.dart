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
import 'services/milestone_helper.dart';

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

  // Milestone tracking
  bool _milestoneShown = false;

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

      // Restore milestones after initialization
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _restoreMilestones();
        }
      });
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

        // Check for milestone achievement on every step fetch
        _checkMilestoneAchievement();

        // Restore milestones that should be visible
        _restoreMilestones();

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

        // 🎯 CRITICAL FIX: Check for milestone achievement on EVERY step update
        print('🎯 STEP UPDATE: Checking milestone for $_steps steps');
        _checkMilestoneAchievement();

        // Restore milestones that should be visible
        _restoreMilestones();

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

    // MILESTONE CHECK: Check for milestone achievements every second
    _checkMilestoneAchievement();

    // MILESTONE RESTORATION: Restore milestones that should be visible
    _restoreMilestones();
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

    // 🎯 BACKUP MILESTONE CHECK: Check for milestone achievements every 2 seconds
    _checkMilestoneAchievement();
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

    // 🎯 SAFETY MILESTONE CHECK: Check for milestone achievements every 3 seconds
    _checkMilestoneAchievement();
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

    // Check for milestone achievement (500 steps)
    _checkMilestoneAchievement();

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

      // Reset milestone tracking for new day
      _milestoneShown = false;
      // Reset all milestone states for new day
      if (_game != null) {
        _game!.milestoneShown.clear();
        for (final threshold in [
          500,
          1000,
          2000,
          4000,
          6000,
          8000,
          10000,
          15000,
          20000,
          25000
        ]) {
          _game!.milestoneShown[threshold] = false;
        }
        print('🔄 All milestone states reset for new day');
      }

      // Update last known date
      _lastKnownDate = currentDate;
    }
  }

  // Milestone display detection using MilestoneHelper
  void _checkMilestoneAchievement() async {
    // Debug milestone check
    print('🔍 MILESTONE CHECK: Steps=$_steps, Game=${_game != null}');

    // Check for current milestone using MilestoneHelper
    int? currentMilestone = await MilestoneHelper.getCurrentMilestone(_steps);

    if (currentMilestone != null) {
      print('🎯 Found milestone: $currentMilestone');

      // Check if this milestone has already been shown
      bool alreadyShown = await MilestoneHelper.isShown(currentMilestone);

      if (!alreadyShown) {
        print(
            '🏆 $currentMilestone milestone reached! Showing milestone board');

        // Mark milestone as shown in SharedPreferences
        await MilestoneHelper.markAsShown(currentMilestone);

        // Add the milestone board to the game
        if (_game?.milestoneBoards[currentMilestone] != null) {
          _game!.add(_game!.milestoneBoards[currentMilestone]!);
          print('✅ $currentMilestone milestone board added to game');

          // Ensure character stays on top
          if (_game?.character != null) {
            _game!.remove(_game!.character!);
            _game!.add(_game!.character!);
            print('🎬 Character re-added to ensure it stays on top');
          }

          // Force a visual update
          setState(() {});

          print('🎯 MILESTONE $currentMilestone SHOULD BE VISIBLE NOW!');
        }
      } else {
        print('ℹ️ $currentMilestone milestone already shown');
      }
    }

    // Debug: Show all milestone statuses
    await _debugMilestoneStatus();
  }

  // Debug milestone status using MilestoneHelper
  Future<void> _debugMilestoneStatus() async {
    print('🔍 MILESTONE STATUS (SharedPreferences):');
    print('Current Steps: $_steps');

    for (int milestone in MilestoneHelper.milestones) {
      bool isShown = await MilestoneHelper.isShown(milestone);
      bool isAvailable = _game?.milestoneBoards[milestone] != null;
      bool isInGame =
          _game?.children.contains(_game?.milestoneBoards[milestone]) ?? false;
      bool hasReached = _steps >= milestone;
      bool isInRange = _steps >= milestone && _steps <= milestone + 50;
      bool readyToShow = hasReached && isInRange && !isShown;

      String status = readyToShow ? '🎯 READY TO SHOW' : '⏸️ NOT READY';
      if (isShown) status = '✅ ALREADY SHOWN';
      if (!hasReached) status = '⏳ NOT REACHED';
      if (hasReached && !isInRange) status = '⏭️ OUT OF RANGE';

      print(
          '  - $milestone steps: Available=$isAvailable, Shown=$isShown, InGame=$isInGame, Reached=$hasReached, InRange=$isInRange | $status');

      // Additional debugging for milestone boards
      if (isAvailable && isInGame) {
        var milestoneBoard = _game?.milestoneBoards[milestone];
        if (milestoneBoard != null) {
          print(
              '    📍 Position: ${milestoneBoard.position}, Size: ${milestoneBoard.size}');
          print('    🎨 Priority: ${milestoneBoard.priority}');
        }
      }
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

        // Check for milestone achievements
        _checkMilestoneAchievement();

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

  // Debug milestone state
  void _debugMilestoneState() {
    print('🏆 MILESTONE STATE DEBUG:');
    print('  - Current Steps: $_steps');
    print('  - Game Available: ${_game != null}');
    print('  - Screen Initialized: $_isInitialized');
    print('');

    final milestoneThresholds = [
      500,
      1000,
      2000,
      4000,
      6000,
      8000,
      10000,
      15000,
      20000,
      25000
    ];

    print('📊 COMPLETE MILESTONE STATUS:');
    print('┌─────────┬──────────┬─────────┬─────────┬─────────┬─────────────┐');
    print('│ Steps   │ Available│ Shown   │ InGame  │ Reached │ Status      │');
    print('├─────────┼──────────┼─────────┼─────────┼─────────┼─────────────┤');

    for (final threshold in milestoneThresholds) {
      final isShown = _game?.milestoneShown[threshold] ?? false;
      final isAvailable = _game?.milestoneBoards[threshold] != null;
      final isInGame =
          _game?.children.contains(_game?.milestoneBoards[threshold]) ?? false;
      final hasReached = _steps >= threshold;

      String status = '';
      if (!isAvailable) {
        status = '❌ Not Loaded';
      } else if (hasReached && !isShown) {
        status = '🎯 READY TO SHOW';
      } else if (hasReached && isShown && isInGame) {
        status = '✅ Currently Displayed';
      } else if (hasReached && isShown && !isInGame) {
        status = '📋 Already Shown';
      } else if (!hasReached) {
        status = '⏳ Not Reached Yet';
      }

      print(
          '│ ${threshold.toString().padLeft(7)} │ ${isAvailable.toString().padLeft(8)} │ ${isShown.toString().padLeft(7)} │ ${isInGame.toString().padLeft(7)} │ ${hasReached.toString().padLeft(7)} │ ${status.padLeft(11)} │');
    }
    print('└─────────┴──────────┴─────────┴─────────┴─────────┴─────────────┘');
    print('');

    // Additional detailed info for milestones that should be shown
    print('🔍 DETAILED ANALYSIS:');
    for (final threshold in milestoneThresholds) {
      final isShown = _game?.milestoneShown[threshold] ?? false;
      final isAvailable = _game?.milestoneBoards[threshold] != null;
      final isInGame =
          _game?.children.contains(_game?.milestoneBoards[threshold]) ?? false;
      final hasReached = _steps >= threshold;

      if (hasReached && !isShown && isAvailable) {
        print(
            '  🎯 $threshold: READY TO SHOW - Steps=$_steps >= $threshold, Shown=false, Available=true');
      } else if (hasReached && isShown && !isInGame) {
        print(
            '  📋 $threshold: ALREADY SHOWN - Steps=$_steps >= $threshold, Shown=true, InGame=false');
      } else if (hasReached && isShown && isInGame) {
        print(
            '  ✅ $threshold: CURRENTLY DISPLAYED - Steps=$_steps >= $threshold, Shown=true, InGame=true');
      } else if (!hasReached) {
        print('  ⏳ $threshold: NOT REACHED - Steps=$_steps < $threshold');
      } else if (!isAvailable) {
        print('  ❌ $threshold: NOT AVAILABLE - Milestone board not loaded');
      }

      if (_game?.milestoneBoards[threshold] != null) {
        print(
            '    📍 Position: ${_game!.milestoneBoards[threshold]!.position}');
        print('    📏 Size: ${_game!.milestoneBoards[threshold]!.size}');
      }
    }
    print('');
  }

  // Reset milestone for testing
  void _resetMilestoneForTesting() async {
    print('🔄 RESETTING MILESTONE FOR TESTING');
    _milestoneShown = false;

    // Reset all milestone states in SharedPreferences
    await MilestoneHelper.resetMilestones();
    print('✅ All milestone states reset in SharedPreferences');

    // Remove all milestone boards from game
    if (_game != null) {
      for (final milestoneBoard in _game!.milestoneBoards.values) {
        if (_game!.children.contains(milestoneBoard)) {
          _game!.remove(milestoneBoard);
        }
      }
      print('✅ All milestone boards removed from game');
    }

    print('✅ Milestone state reset - ready for testing');
  }

  // Test milestone system by simulating step counts
  void _testMilestoneSystem() {
    print('🧪 TESTING MILESTONE SYSTEM');
    print('📋 Range System: Each milestone has a 50-step range');

    // Reset milestone states first
    _resetMilestoneForTesting();

    // Test with different step counts (including range testing)
    final testSteps = [
      500,
      510,
      1000,
      1020,
      2000,
      2030,
      4000,
      4020,
      6000,
      6030
    ];

    for (int i = 0; i < testSteps.length; i++) {
      final testStep = testSteps[i];
      Future.delayed(Duration(milliseconds: i * 800), () {
        if (mounted) {
          print('🧪 Testing with $testStep steps (Range Test)');
          setState(() {
            _steps = testStep;
          });
          _checkMilestoneAchievement();
          print('🧪 Test completed for $testStep steps');
        }
      });
    }
  }

  // Force show a specific milestone for testing
  void _forceShowMilestone(int threshold) async {
    print('🔧 FORCE SHOWING MILESTONE $threshold');
    print(
        '📋 Range System: This milestone has range ${threshold}-${threshold + 50}');

    if (_game?.milestoneBoards[threshold] != null) {
      // Mark milestone as shown in SharedPreferences
      await MilestoneHelper.markAsShown(threshold);

      // Remove any existing milestone boards
      for (final milestoneBoard in _game!.milestoneBoards.values) {
        if (_game!.children.contains(milestoneBoard)) {
          _game!.remove(milestoneBoard);
        }
      }

      // Add the specific milestone board
      _game!.add(_game!.milestoneBoards[threshold]!);

      print(
          '✅ Milestone $threshold forced to show (Range: ${threshold}-${threshold + 50})');
    } else {
      print('❌ Milestone $threshold not available');
    }
  }

  // Force restore a specific milestone (for testing)
  void _forceRestoreMilestone(int threshold) async {
    print('🔄 FORCE RESTORING MILESTONE $threshold');
    print('=======================================');

    bool isShown = await MilestoneHelper.isShown(threshold);
    bool isAvailable = _game?.milestoneBoards[threshold] != null;
    bool isInGame =
        _game?.children.contains(_game?.milestoneBoards[threshold]) ?? false;

    print('Status: Shown=$isShown, Available=$isAvailable, InGame=$isInGame');

    if (isAvailable && !isInGame) {
      // Add to game
      _game!.add(_game!.milestoneBoards[threshold]!);
      print('✅ $threshold milestone restored to game');

      // Ensure character stays on top
      if (_game?.character != null) {
        _game!.remove(_game!.character!);
        _game!.add(_game!.character!);
      }

      setState(() {});
      print('🎯 MILESTONE $threshold SHOULD BE VISIBLE NOW!');
    } else if (isInGame) {
      print('ℹ️ $threshold milestone already in game');
    } else {
      print('❌ $threshold milestone board not available');
    }
  }

  // Quick status check for all milestones
  void _quickMilestoneStatus() {
    print('🚀 QUICK MILESTONE STATUS CHECK');
    print('Current Steps: $_steps');
    print('Game Available: ${_game != null}');
    print('');

    final milestoneThresholds = [
      500,
      1000,
      2000,
      4000,
      6000,
      8000,
      10000,
      15000,
      20000,
      25000
    ];

    for (final threshold in milestoneThresholds) {
      final isShown = _game?.milestoneShown[threshold] ?? false;
      final isAvailable = _game?.milestoneBoards[threshold] != null;
      final hasReached = _steps >= threshold;
      final rangeStart = threshold;
      final rangeEnd = threshold + 50;
      final isInRange = _steps >= rangeStart && _steps <= rangeEnd;

      String icon = '⏳';
      if (isInRange && !isShown && isAvailable) {
        icon = '🎯';
      } else if (hasReached && isShown) {
        icon = '✅';
      } else if (!isAvailable) {
        icon = '❌';
      }

      print(
          '$icon $threshold: ${hasReached ? "REACHED" : "Not reached"} | Range: $rangeStart-$rangeEnd | InRange: $isInRange | Available: $isAvailable | Shown: $isShown');
    }
    print('');
  }

  // Complete milestone testing sequence
  void _completeMilestoneTest() {
    print('🧪 COMPLETE MILESTONE TESTING SEQUENCE');
    print('=====================================');
    print(
        '📋 Range System: Each milestone has a 50-step range (e.g., 500-550 for 500 milestone)');

    // Step 1: Show current status
    print('\n📊 STEP 1: Current Status');
    _quickMilestoneStatus();

    // Step 2: Reset all milestones
    print('\n🔄 STEP 2: Resetting All Milestones');
    _resetMilestoneForTesting();

    // Step 3: Show status after reset
    print('\n📊 STEP 3: Status After Reset');
    _quickMilestoneStatus();

    // Step 4: Test with different step counts (including range testing)
    print('\n🎯 STEP 4: Testing Milestone Display with Range System');
    final testSteps = [
      500,
      510,
      1000,
      1020,
      2000,
      2030,
      4000,
      4020,
      6000,
      6030
    ];

    for (int i = 0; i < testSteps.length; i++) {
      final testStep = testSteps[i];
      Future.delayed(Duration(milliseconds: (i + 1) * 1500), () {
        if (mounted) {
          print('\n🧪 Testing with $testStep steps (Range Test)...');
          setState(() {
            _steps = testStep;
          });

          // Check milestone achievement
          _checkMilestoneAchievement();

          // Show status after this test
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              print('📊 Status after $testStep steps:');
              _quickMilestoneStatus();
            }
          });
        }
      });
    }

    // Step 5: Final status check
    Future.delayed(Duration(milliseconds: (testSteps.length + 1) * 1500), () {
      if (mounted) {
        print('\n📊 STEP 5: Final Status Check');
        _debugMilestoneState();
        print('\n✅ Complete milestone testing finished!');
        print(
            '📋 Range System Tested: Milestones should trigger within their 50-step ranges');
      }
    });
  }

  // Quick one-click milestone test
  void _quickMilestoneTest() {
    print('⚡ QUICK MILESTONE TEST');
    print('======================');
    print('📋 Range System: Testing with 500 steps (Range: 500-550)');

    // Reset and test with 500 steps immediately
    _resetMilestoneForTesting();

    setState(() {
      _steps = 500;
    });

    _checkMilestoneAchievement();

    print('✅ Quick test completed - 500 milestone should be visible now!');
    print('📊 Current status:');
    _quickMilestoneStatus();
  }

  // Fix milestones that are marked as shown but not displayed
  void _fixMilestoneDisplay() {
    print('🔧 FIXING MILESTONE DISPLAY ISSUES');
    print('==================================');

    final milestoneThresholds = [
      500,
      1000,
      2000,
      4000,
      6000,
      8000,
      10000,
      15000,
      20000,
      25000
    ];

    for (final threshold in milestoneThresholds) {
      final isShown = _game?.milestoneShown[threshold] ?? false;
      final isAvailable = _game?.milestoneBoards[threshold] != null;
      final isInGame =
          _game?.children.contains(_game?.milestoneBoards[threshold]) ?? false;
      final rangeStart = threshold;
      final rangeEnd = threshold + 50;
      final isInRange = _steps >= rangeStart && _steps <= rangeEnd;
      final hasReached = _steps >= threshold;

      if (hasReached && isShown && !isInGame && isAvailable) {
        print(
            '🔧 FIXING: $threshold milestone marked as shown but not displayed (Range: $rangeStart-$rangeEnd, InRange: $isInRange)');
        _game!.add(_game!.milestoneBoards[threshold]!);
        print('✅ $threshold milestone board re-added to game');
      }
    }

    print('🔧 Milestone display fix completed');
  }

  // Handle missed milestones (reached but not shown)
  void _handleMissedMilestones() {
    print('🎯 HANDLING MISSED MILESTONES');
    print('=============================');

    final milestoneThresholds = [
      500,
      1000,
      2000,
      4000,
      6000,
      8000,
      10000,
      15000,
      20000,
      25000
    ];

    for (final threshold in milestoneThresholds) {
      final isShown = _game?.milestoneShown[threshold] ?? false;
      final isAvailable = _game?.milestoneBoards[threshold] != null;
      final isInGame =
          _game?.children.contains(_game?.milestoneBoards[threshold]) ?? false;
      final hasReached = _steps >= threshold;
      final rangeStart = threshold;
      final rangeEnd = threshold + 50;
      final isInRange = _steps >= rangeStart && _steps <= rangeEnd;

      // If milestone is reached but not shown and not in game
      if (hasReached && !isShown && !isInGame && isAvailable) {
        print(
            '🎯 MISSED MILESTONE: $threshold reached but not shown (Steps: $_steps, Range: $rangeStart-$rangeEnd)');
        print('🎯 SHOWING MISSED MILESTONE: $threshold');

        // Mark milestone as shown
        _game!.milestoneShown[threshold] = true;

        // Add the milestone board to the game
        _game!.add(_game!.milestoneBoards[threshold]!);
        print('✅ $threshold milestone board added to game');

        // Ensure character stays on top
        if (_game!.character != null) {
          _game!.remove(_game!.character!);
          _game!.add(_game!.character!);
        }

        // Force visual update
        setState(() {});

        print('🎯 MISSED MILESTONE $threshold SHOULD BE VISIBLE NOW!');
        return; // Only show one milestone at a time
      }
    }

    print('✅ No missed milestones found');
  }

  // Refresh step count to fix display issues
  void _refreshStepCount() async {
    print('🔄 REFRESHING STEP COUNT');
    print('========================');
    print('Current displayed steps: $_steps');

    try {
      // Fetch fresh step count
      final freshSteps = await _healthService.fetchHybridRealTimeSteps();
      print('Fresh step count from service: $freshSteps');

      if (mounted) {
        setState(() {
          _previousSteps = _steps;
          _steps = freshSteps;
        });

        print('✅ Step count refreshed: $_steps');
        print('📊 Step difference: ${_steps - _previousSteps}');

        // Check for milestones after refresh
        _checkMilestoneAchievement();
      }
    } catch (e) {
      print('❌ Error refreshing step count: $e');
    }
  }

  // Restore milestones that should be visible based on current steps
  void _restoreMilestones() async {
    print('🔄 RESTORING MILESTONES');
    print('=======================');
    print('Current Steps: $_steps');

    for (final threshold in MilestoneHelper.milestones) {
      final isShown = await MilestoneHelper.isShown(threshold);
      final isAvailable = _game?.milestoneBoards[threshold] != null;
      final isInGame =
          _game?.children.contains(_game?.milestoneBoards[threshold]) ?? false;
      final hasReached = _steps >= threshold;

      // If milestone should be shown (reached and marked as shown) but not in game
      if (hasReached && isShown && !isInGame && isAvailable) {
        print(
            '🔄 RESTORING: $threshold milestone (reached and should be shown)');

        // Add the milestone board back to the game
        _game!.add(_game!.milestoneBoards[threshold]!);
        print('✅ $threshold milestone board restored to game');
      }
    }

    print('✅ Milestone restoration completed');
  }

  // Test milestone with current steps
  void _testCurrentStepsMilestone() {
    print('🧪 TESTING MILESTONE WITH CURRENT STEPS');
    print('=======================================');
    print('Current Steps: $_steps');
    print('');

    // Reset all milestones first
    print('🔄 Resetting all milestones...');
    _resetMilestoneForTesting();

    // Check milestone achievement with current steps
    print('🎯 Checking milestone achievement...');
    _checkMilestoneAchievement();

    // Show final status
    print('📊 Final milestone status:');
    _quickMilestoneStatus();

    print('✅ Test completed! Check if milestone is visible on screen.');
    print(
        '📋 Range System: Each milestone has a 50-step range (e.g., 500-550 for 500 milestone)');
  }

  // 🧪 Simple milestone test with specific step count
  void _testMilestoneWithSteps(int testSteps) {
    print('🧪 SIMPLE MILESTONE TEST WITH $testSteps STEPS');
    print('==============================================');
    print('Current Steps: $_steps');
    print('Test Steps: $testSteps');
    print('');

    // Reset all milestones first
    print('🔄 Resetting all milestones...');
    _resetMilestoneForTesting();

    // Set test steps
    setState(() {
      _steps = testSteps;
    });

    print('📊 Steps set to: $_steps');

    // Check milestone achievement
    print('🎯 Checking milestone achievement...');
    _checkMilestoneAchievement();

    // Show final status
    print('📊 Final milestone status:');
    _quickMilestoneStatus();

    print('✅ Test completed! Check if milestone is visible on screen.');
    print('📋 Range System: Each milestone has a 50-step range');
    print(
        '🎯 Expected milestone for $testSteps steps: ${_getExpectedMilestone(testSteps)}');
  }

  // Helper method to get expected milestone for step count
  int? _getExpectedMilestone(int steps) {
    for (int milestone in MilestoneHelper.milestones) {
      if (steps >= milestone && steps <= milestone + 50) {
        return milestone;
      }
    }
    return null;
  }

  // 🧪 Test milestone system with simulated step increases
  void _testMilestoneWithStepIncreases() {
    print('🧪 TESTING MILESTONE WITH STEP INCREASES');
    print('=========================================');
    print('Current Steps: $_steps');
    print('');

    // Reset all milestones first
    print('🔄 Resetting all milestones...');
    _resetMilestoneForTesting();

    // Test step increases that should trigger milestones
    final testStepIncreases = [3990, 4000, 4010, 4020, 4030, 4040, 4050, 4060];

    for (int i = 0; i < testStepIncreases.length; i++) {
      final testSteps = testStepIncreases[i];
      Future.delayed(Duration(milliseconds: i * 1000), () {
        if (mounted) {
          print('\n🧪 Testing step increase to $testSteps...');

          // Simulate step increase
          setState(() {
            _previousSteps = _steps;
            _steps = testSteps;
          });

          // Check milestone achievement (this should trigger the milestone)
          _checkMilestoneAchievement();

          print('📊 Steps: $_previousSteps -> $_steps');
          print('🎯 Expected milestone: ${_getExpectedMilestone(testSteps)}');
        }
      });
    }

    print('✅ Step increase test started! Watch for milestone triggers.');
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

        // IMMEDIATE MILESTONE CHECK: Check milestones right after step update
        _checkMilestoneAchievement();
        _restoreMilestones();

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

                      // MILESTONE DEBUG: Check milestone state
                      _debugMilestoneState();

                      // MANUAL MILESTONE CHECK: Force check milestone achievement
                      print('🔧 Manual milestone check triggered');
                      _checkMilestoneAchievement();

                      // QUICK MILESTONE STATUS: Show all milestone status
                      print('📊 QUICK MILESTONE STATUS CHECK');
                      _quickMilestoneStatus();

                      // FIX MILESTONE DISPLAY: Fix milestones marked as shown but not displayed
                      _fixMilestoneDisplay();

                      // RESTORE MILESTONES: Restore milestones that should be visible
                      _restoreMilestones();

                      // FORCE RESTORE 2000 MILESTONE: Test specific milestone (uncomment to test)
                      // _forceRestoreMilestone(2000);

                      // REFRESH STEPS: Force refresh step count (uncomment to test)
                      // _refreshStepCount();

                      // TEST 500 MILESTONE: Test with current steps (uncomment to test)
                      // _testCurrentStepsMilestone();

                      // MILESTONE TEST: Reset milestone for testing (uncomment to test)
                      // _resetMilestoneForTesting();

                      // MILESTONE TEST: Test milestone system (uncomment to test)
                      // _testMilestoneSystem();

                      // MILESTONE TEST: Force show 500 milestone (uncomment to test)
                      // _forceShowMilestone(500);

                      // QUICK STATUS: Check all milestone status (uncomment to test)
                      // _quickMilestoneStatus();

                      // TEST SEQUENCE: Complete milestone testing (uncomment to test)
                      // _completeMilestoneTest();

                      // QUICK TEST: One-click milestone test (uncomment to test)
                      // _quickMilestoneTest();

                      // 🧪 SIMPLE MILESTONE TEST: Test with 4000 steps (uncomment to test)
                      // _testMilestoneWithSteps(4000);

                      // 🧪 STEP INCREASE TEST: Test milestone with step increases (uncomment to test)
                      // _testMilestoneWithStepIncreases();
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
  SpriteComponent? milestoneBoard; // Milestone board component
  Map<int, SpriteComponent> milestoneBoards = {}; // All milestone boards
  Map<int, bool> milestoneShown = {}; // Track which milestones have been shown
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

      // Layer 2.2: Milestone Boards (on top of path, touching the path)
      final double milestoneWidth = 300 * scaleX; // Adjust size as needed
      final double milestoneHeight = 300 * scaleY; // Adjust size as needed

      // Position to the right of the character
      final double characterX = 100 * scaleX; // Character's X position
      final double characterWidth = 800 * scaleX; // Character's width
      final double spacing =
          50 * scaleX; // Space between character and milestone board
      final double milestoneX = characterX +
          characterWidth +
          spacing; // Position to the right of character
      final double milestoneY = screenHeight -
          pathH -
          milestoneHeight; // Position exactly on top of path

      // Load all milestone boards
      final milestoneImages = {
        500: '500mile.png',
        1000: '1000mile.png',
        2000: '2000mile.png',
        4000: '4000mile.png',
        6000: '6000mile.png',
        8000: '8000mile.png',
        10000: '10kMile.png',
        15000: '15kMile.png',
        20000: '20kMile.png',
        25000: '25kMile.png',
      };

      for (final entry in milestoneImages.entries) {
        final stepThreshold = entry.key;
        final imageName = entry.value;

        try {
          final sprite = await loadSprite(imageName);
          final milestoneBoard = SpriteComponent(
            sprite: sprite,
            size: Vector2(milestoneWidth, milestoneHeight),
            position: Vector2(milestoneX, milestoneY),
            priority: 2, // Layer 2 - behind character (layer 3)
          );

          milestoneBoards[stepThreshold] = milestoneBoard;
          milestoneShown[stepThreshold] = false; // Initialize as not shown

          print(
              '🏆 MILESTONE: Created $stepThreshold milestone board at position ($milestoneX, $milestoneY)');
        } catch (e) {
          print('❌ Error loading milestone $stepThreshold: $e');
        }
      }

      // Set the default milestone board for backward compatibility
      milestoneBoard = milestoneBoards[500];
      print('🏆 MILESTONE: All milestone boards created successfully');
      // Don't add to the game initially - will be added when respective steps are reached

      // Layer 3: Character (on top of path)
      // Compensate for transparent pixels at the bottom of the character sprite
      final double transparentBottomPx = 140; // Adjust this value as needed
      final double transparentOffset = transparentBottomPx * scaleY;
      character = Character();
      character!.size =
          Vector2(800 * scaleX, 800 * scaleY); // 800x800 base size
      character!.anchor = Anchor.bottomLeft;
      character!.priority = 3; // Layer 3 - on top of milestone boards
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

      // Milestone Boards (move with the path)
      milestoneBoard?.x -= dx;
      // Move all milestone boards
      for (final milestoneBoard in milestoneBoards.values) {
        milestoneBoard.x -= dx;
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
