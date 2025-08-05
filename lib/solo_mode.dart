import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'services/character_animation_service.dart';
import 'services/health_service.dart';
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

  // Removed unused milestone tracking field

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

      // Restore milestones and clean up out-of-range ones after initialization
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _restoreMilestones();
          _cleanupOutOfRangeMilestones();
          _cleanupOutOfRangeMilestonesRealTime();
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

        // IMMEDIATE MILESTONE CHECK: Check for milestone achievement immediately when steps are fetched
        if (_steps > _previousSteps) {
          print(
              '🎯 FETCH STEPS: Steps increased from $_previousSteps to $_steps - checking milestones immediately');
          _checkMilestoneAchievementRealTime();
        }

        // Check if user is walking (steps increased)
        _checkUserWalkingWithTiming(DateTime.now());

        // Check for milestone achievement on every step fetch (real-time)
        _checkMilestoneAchievementRealTime();

        // Restore milestones that should be visible and clean up out-of-range ones
        _restoreMilestones();
        _cleanupOutOfRangeMilestones();

        // Real-time cleanup of milestones that just went out of range
        _cleanupOutOfRangeMilestonesRealTime();

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

        // Store previous steps before updating
        int oldSteps = _steps;

        // Update steps and check walking state
        setState(() {
          _previousSteps = oldSteps;
          _steps = accurateSteps; // Use accurate steps, not hybrid total
        });

        // IMMEDIATE MILESTONE CHECK: Check for milestone achievement immediately when steps update
        if (_steps > _previousSteps) {
          print(
              '🎯 HEALTH CONNECT: Steps increased from $_previousSteps to $_steps - checking milestones immediately');
          _checkMilestoneAchievementRealTime();
        }

        // Check if user is walking (steps increased)
        _checkUserWalkingWithTiming(DateTime.now());

        // 🎯 REAL-TIME MILESTONE CHECK: Check for milestone achievement on EVERY step update
        print(
            '🎯 REAL-TIME MILESTONE CHECK: Steps=$_steps, Previous=$_previousSteps');
        _checkMilestoneAchievementRealTime();

        // Restore milestones that should be visible and clean up out-of-range ones
        _restoreMilestones();
        _cleanupOutOfRangeMilestones();

        // Real-time cleanup of milestones that just went out of range
        _cleanupOutOfRangeMilestonesRealTime();

        // Sync character animation
        _syncCharacterAnimation();

        print(
            '🏥 Health Connect update: +$stepIncrease steps (Accurate Total: $accurateSteps)');
      }
    });
  }

  // SIMPLIFIED MONITORING: Single monitoring system to prevent jitter
  void _startContinuousMonitoring() {
    print('🔄 Starting simplified monitoring system...');

    // Single monitoring system every 2 seconds
    _startSingleMonitoring();
  }

  void _startSingleMonitoring() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkWalkingStateSimple();
        _startSingleMonitoring(); // Recursive call
      }
    });
  }

  void _checkWalkingStateSimple() {
    // GRACE PERIOD: Don't check during initialization
    if (!_isInitialized) {
      return;
    }

    // Only check for idle timeout if currently walking
    if (_isUserWalking && _lastStepUpdate != null) {
      final timeSinceLastStep =
          DateTime.now().difference(_lastStepUpdate!).inSeconds;

      if (timeSinceLastStep >= 5) {
        print(
            '⏰ 5-SECOND IDLE: No steps for ${timeSinceLastStep}s, forcing idle');
        _setWalkingState(false);
      }
    }

    // ENHANCED MILESTONE CHECK: Check for milestone achievements during continuous monitoring
    if (_isUserWalking) {
      print('🎯 CONTINUOUS MONITORING: User is walking, checking milestones');
      _checkMilestoneAchievementRealTime();
    }
  }

  void _setWalkingState(bool walking) {
    if (_isUserWalking != walking) {
      setState(() {
        _isUserWalking = walking;
      });
      walking ? _startCharacterWalking() : _stopCharacterWalking();
      print(walking ? '🚶‍♂️ User started walking' : '🛑 User stopped walking');
    } else {
      print('✅ State already correct: $walking');
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

    // SIMPLIFIED LOGIC: Only two states - walking or idle
    bool shouldBeWalking = false;

    // Check if steps increased
    if (_steps > _previousSteps) {
      shouldBeWalking = true;
      _lastStepUpdate = now;
      print(
          '🚶‍♂️ Steps increased: $_previousSteps -> $_steps, user is walking');

      // IMMEDIATE MILESTONE CHECK: Check for milestone achievement when steps increase
      print(
          '🎯 IMMEDIATE MILESTONE CHECK: Steps increased, checking milestones');
      _checkMilestoneAchievementRealTime();

      // Update previous steps to current steps for next comparison
      _previousSteps = _steps;
      print('📊 Updated previous steps to: $_previousSteps');
    } else {
      // Steps didn't increase - check if we should go idle
      if (_isUserWalking && _lastStepUpdate != null) {
        final timeSinceLastStep = now.difference(_lastStepUpdate!).inSeconds;

        if (timeSinceLastStep >= 5) {
          // Force idle after 5 seconds of no steps
          shouldBeWalking = false;
          print(
              '⏰ 5-SECOND IDLE: No steps for ${timeSinceLastStep}s, forcing idle');
        } else {
          // Still in walking window, keep walking
          shouldBeWalking = true;
          print('👀 Still walking: ${timeSinceLastStep}s since last step');
        }
      } else {
        // Not walking, stay idle
        shouldBeWalking = false;
      }
    }

    // Only change state if it's actually different
    if (_isUserWalking != shouldBeWalking) {
      print('🔄 State change needed: $_isUserWalking -> $shouldBeWalking');
      _setWalkingState(shouldBeWalking);
    } else {
      print('✅ State is correct: $_isUserWalking');
    }
  }

  void _forceCharacterAnimationSync() {
    // APPROACH 8: Force immediate character animation sync
    try {
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
    } catch (e) {
      print('❌ Error forcing character animation sync: $e');
    }
  }

  // Day change detection
  void _checkForDayChange() async {
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
      await MilestoneHelper.resetMilestonesForNewDay();

      // Reset game milestone states
      if (_game != null) {
        _game!.milestoneShown.clear();
        for (final threshold in MilestoneHelper.milestones) {
          _game!.milestoneShown[threshold] = false;
        }
      }

      // Clean up any out-of-range milestones on day change
      _cleanupOutOfRangeMilestones();

      // Update last known date
      _lastKnownDate = currentDate;
    }
  }

  // Force check and show milestones that should be visible
  void _forceCheckVisibleMilestones() async {
    print('🔧 FORCE CHECKING VISIBLE MILESTONES: Current steps: $_steps');

    try {
      for (final milestone in MilestoneHelper.milestones) {
        bool isInRange = MilestoneHelper.isMilestoneInRange(milestone, _steps);
        bool alreadyShown = await MilestoneHelper.isShown(milestone);
        bool isInGame =
            _game?.children.contains(_game?.milestoneBoards[milestone]) ??
                false;
        bool boardExists = _game?.milestoneBoards[milestone] != null;

        print(
            '🔧 MILESTONE $milestone: inRange=$isInRange, alreadyShown=$alreadyShown, isInGame=$isInGame, boardExists=$boardExists');

        // If milestone should be visible but not in game, add it
        if (isInRange && alreadyShown && !isInGame && boardExists) {
          print(
              '🔧 FORCE ADDING: $milestone milestone should be visible but not in game');
          _game!.add(_game!.milestoneBoards[milestone]!);
          print('✅ FORCE ADDED: $milestone milestone to game');

          // Ensure character stays on top
          if (_game?.character != null) {
            _game!.remove(_game!.character!);
            _game!.add(_game!.character!);
          }

          if (mounted) {
            setState(() {});
          }
        } else if (isInRange && !boardExists) {
          print('❌ MILESTONE $milestone: Board does not exist!');
        }
      }
    } catch (e) {
      print('❌ Error in force checking visible milestones: $e');
    }
  }

  // Enhanced real-time milestone check for immediate response
  void _checkMilestoneAchievementRealTime() async {
    // Debug milestone check
    print(
        '🔍 REAL-TIME MILESTONE CHECK: Steps=$_steps, Previous=$_previousSteps, Walking=$_isUserWalking');

    try {
      // Check if we just crossed a milestone threshold
      for (final milestone in MilestoneHelper.milestones) {
        // Check if we just entered the milestone range (previous was below, current is within range)
        bool wasBelowRange = _previousSteps < milestone;
        bool isInRange = MilestoneHelper.isMilestoneInRange(milestone, _steps);

        // Also check if we just crossed the milestone exactly (for immediate response)
        bool justCrossedMilestone =
            _previousSteps < milestone && _steps >= milestone;

        // Check if we're currently walking and just reached the milestone
        bool walkingAndReached = _isUserWalking && justCrossedMilestone;

        print(
            '🔍 MILESTONE $milestone: wasBelowRange=$wasBelowRange, isInRange=$isInRange, justCrossedMilestone=$justCrossedMilestone, walkingAndReached=$walkingAndReached');

        // Enhanced condition: Show milestone if we just crossed it OR if we're walking and just entered range
        if (justCrossedMilestone ||
            (walkingAndReached && wasBelowRange && isInRange)) {
          print(
              '🎯 REAL-TIME: Just entered milestone range for $milestone! (Crossed: $justCrossedMilestone, Walking: $_isUserWalking)');

          // Check if this milestone has already been shown
          bool alreadyShown = await MilestoneHelper.isShown(milestone);

          if (!alreadyShown) {
            print(
                '🏆 REAL-TIME: $milestone milestone reached! Showing milestone board immediately');

            // Mark milestone as shown in SharedPreferences
            await MilestoneHelper.markAsShown(milestone);

            // Add the milestone board to the game immediately
            if (_game?.milestoneBoards[milestone] != null) {
              _game!.add(_game!.milestoneBoards[milestone]!);
              print(
                  '✅ REAL-TIME: $milestone milestone board added to game immediately');

              // Ensure character stays on top
              if (_game?.character != null) {
                _game!.remove(_game!.character!);
                _game!.add(_game!.character!);
                print('🎬 Character re-added to ensure it stays on top');
              }

              // Force a visual update immediately
              if (mounted) {
                setState(() {});
              }

              print('🎯 REAL-TIME MILESTONE $milestone SHOULD BE VISIBLE NOW!');
            } else {
              print('❌ REAL-TIME: Milestone board for $milestone is null!');
            }
          } else {
            print('ℹ️ REAL-TIME: $milestone milestone already shown');
          }
        }
      }
    } catch (e) {
      print('❌ Error in real-time milestone achievement check: $e');
    }
  }

  // Milestone display detection using MilestoneHelper
  void _checkMilestoneAchievement() async {
    // Debug milestone check
    print('🔍 MILESTONE CHECK: Steps=$_steps, Game=${_game != null}');

    try {
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
            if (mounted) {
              setState(() {});
            }

            print('🎯 MILESTONE $currentMilestone SHOULD BE VISIBLE NOW!');
          }
        } else {
          print('ℹ️ $currentMilestone milestone already shown');
        }
      }
    } catch (e) {
      print('❌ Error in milestone achievement check: $e');
    }

    // Debug: Show all milestone statuses (only if needed)
    // await _debugMilestoneStatus();
  }

  void _startPeriodicUpdates() {
    // APPROACH 5: More frequent updates with aggressive sync
    Future.delayed(const Duration(seconds: 5), () {
      // 5-second interval to ensure reliability
      if (mounted) {
        _fetchStepsFromHomeMethod();

        // Check for day change
        _checkForDayChange();

        // Check for milestone achievements (real-time)
        _checkMilestoneAchievementRealTime();

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

  // Real-time cleanup of milestones that just went out of range
  void _cleanupOutOfRangeMilestonesRealTime() async {
    print('🧹 REAL-TIME CLEANUP: Checking for out-of-range milestones');
    print('Current Steps: $_steps, Previous: $_previousSteps');

    try {
      for (final threshold in MilestoneHelper.milestones) {
        final isInGame =
            _game?.children.contains(_game?.milestoneBoards[threshold]) ??
                false;
        final isInRange = MilestoneHelper.isMilestoneInRange(threshold, _steps);
        final wasInRange =
            MilestoneHelper.isMilestoneInRange(threshold, _previousSteps);

        // Remove milestone if it was in range before but is out of range now
        if (isInGame && wasInRange && !isInRange) {
          print(
              '🗑️ REAL-TIME CLEANUP: Removing $threshold milestone (just went out of range: $_previousSteps → $_steps)');
          _game!.remove(_game!.milestoneBoards[threshold]!);
          print('✅ REAL-TIME: $threshold milestone board removed from game');

          // Force a visual update immediately
          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      print('❌ Error in real-time cleanup of out-of-range milestones: $e');
    }
  }

  // Clean up milestones that are out of range
  void _cleanupOutOfRangeMilestones() async {
    print('🧹 CLEANING UP OUT-OF-RANGE MILESTONES');
    print('Current Steps: $_steps');

    try {
      for (final threshold in MilestoneHelper.milestones) {
        final isInGame =
            _game?.children.contains(_game?.milestoneBoards[threshold]) ??
                false;
        final isInRange = MilestoneHelper.isMilestoneInRange(threshold, _steps);

        // Remove milestone if it's in game but out of range
        if (isInGame && !isInRange) {
          print(
              '🗑️ CLEANUP: Removing $threshold milestone (out of range: $_steps steps)');
          _game!.remove(_game!.milestoneBoards[threshold]!);
          print('✅ $threshold milestone board removed from game');
        }
      }
    } catch (e) {
      print('❌ Error cleaning up out-of-range milestones: $e');
    }

    print('✅ Out-of-range milestone cleanup completed');
  }

  // Restore milestones that should be visible based on current steps
  void _restoreMilestones() async {
    print('🔄 RESTORING MILESTONES');
    print('=======================');
    print('Current Steps: $_steps');

    try {
      for (final threshold in MilestoneHelper.milestones) {
        final isShown = await MilestoneHelper.isShown(threshold);
        final isAvailable = _game?.milestoneBoards[threshold] != null;
        final isInGame =
            _game?.children.contains(_game?.milestoneBoards[threshold]) ??
                false;
        final hasReached = _steps >= threshold;
        final isInRange = MilestoneHelper.isMilestoneInRange(threshold, _steps);

        // If milestone should be shown (reached, marked as shown, and in range) but not in game
        if (hasReached && isShown && isInRange && !isInGame && isAvailable) {
          print(
              '🔄 RESTORING: $threshold milestone (reached, shown, and in range)');

          // Add the milestone board back to the game
          _game!.add(_game!.milestoneBoards[threshold]!);
          print('✅ $threshold milestone board restored to game');
        } else if (hasReached && isShown && !isInRange && isInGame) {
          // Remove milestone if it's out of range but still in game
          print(
              '🗑️ REMOVING: $threshold milestone (out of range: $_steps steps)');
          _game!.remove(_game!.milestoneBoards[threshold]!);
          print('✅ $threshold milestone board removed from game');
        }
      }
    } catch (e) {
      print('❌ Error restoring milestones: $e');
    }

    print('✅ Milestone restoration completed');
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

        // Reduced debug logging to prevent performance issues
        // print('✅ Character animation synced: ${_isUserWalking ? "Walking" : "Idle"}');
      } catch (e) {
        print('❌ Error syncing character animation: $e');
      }
    } else {
      print('⚠️ Game instance not available for animation sync');
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

                      // MANUAL MILESTONE CHECK: Force check milestone achievement (real-time)
                      print('🔧 Manual milestone check triggered');
                      _checkMilestoneAchievementRealTime();

                      // FORCE CHECK: Check for milestones that should be visible
                      print('🔧 Force checking visible milestones');
                      _forceCheckVisibleMilestones();

                      // TEST: Reset 2000 milestone for testing
                      print('🧪 Resetting 2000 milestone for testing');
                      await MilestoneHelper.resetSpecificMilestone(2000);

                      // DEBUG: Check available milestone boards
                      print('🔍 DEBUG: Checking available milestone boards');
                      if (_game != null) {
                        print(
                            '🔍 Game milestone boards: ${_game!.milestoneBoards.keys.toList()}');
                      } else {
                        print('❌ Game is null!');
                      }

                      // RESTORE MILESTONES: Restore milestones that should be visible and clean up out-of-range ones
                      _restoreMilestones();
                      _cleanupOutOfRangeMilestones();

                      // Real-time cleanup of milestones that just went out of range
                      _cleanupOutOfRangeMilestonesRealTime();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
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
  bool _lastAnimationState =
      false; // Track last animation state to prevent redundant calls

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
    // REMOVED: Force recheck animation every frame - this was causing jittery animations
    // updateAnimation(isWalking);
    //
    // FIXED: Animation is now only updated when walking state actually changes,
    // preventing the jittery restart effect when steps increase
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

    try {
      // Prevent redundant animation calls if state hasn't changed
      if (_lastAnimationState == walking) {
        return; // State hasn't changed, don't update animation
      }

      final newAnimation = walking ? walkingAnimation : idleAnimation;

      if (animation != newAnimation) {
        print(
            '🔄 Character: Switching animation to ${walking ? "walking" : "idle"}');
        animation = newAnimation;
        print('🎬 Animation switched and will restart');
      } else {
        // Animation is already correct - don't restart it
        // This prevents jittery restarts when the same animation is already playing
      }

      // Update the last animation state
      _lastAnimationState = walking;
    } catch (e) {
      print('❌ Error updating character animation: $e');
    }
  }

  void startWalking() {
    print('🎬 Character startWalking called');
    try {
      isWalking = true;
      updateAnimation(true);
    } catch (e) {
      print('❌ Error starting character walking: $e');
    }
  }

  void stopWalking() {
    print('🎬 Character stopWalking called');
    try {
      isWalking = false;
      updateAnimation(false);
    } catch (e) {
      print('❌ Error stopping character walking: $e');
    }
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
    try {
      if (character != null) {
        character!.isWalking = walking;
        character!.updateAnimation(walking);
        print('🎮 Game: Character ${walking ? "started" : "stopped"} walking');
      } else {
        print('⚠️ Game: Character not available for walking state update');
      }
    } catch (e) {
      print('❌ Error updating walking state: $e');
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
      const double transparentBottomPx = 140; // Adjust this value as needed
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
      // Reduced debug logging to prevent performance issues
      // print('🎮 Game: Moving background (character walking)');

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
      // Reduced debug logging to prevent performance issues
      // if (character != null) {
      //   print('🎮 Game: Background stopped (character idle)');
      // }
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
    const double indicatorRadius = 16.0;
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
