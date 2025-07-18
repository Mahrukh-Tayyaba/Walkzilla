import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/parallax.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flame/flame.dart';
import 'services/character_animation_service.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      print('Game focus changed: ${_focusNode.hasFocus}');
    });
    // Initialize with walking state as false
    _isUserWalking = false;
    _initializeRealTimeTracking();
  }

  void _initializeRealTimeTracking() async {
    try {
      // Force reset walking state to ensure correct initial state
      setState(() {
        _isUserWalking = false;
        _lastStepUpdate = null; // Reset step history
      });

      // Get initial steps using the same method as home.dart
      await _fetchSteps();

      // Force walking state to false after initial fetch
      if (_isUserWalking) {
        setState(() {
          _isUserWalking = false;
        });
        print('🔄 Force reset walking state after initial fetch');
      }

      // Initialize hybrid tracking system (Health Connect + real-time sensors)
      final initialized = await _healthService.initializeHybridTracking();

      if (initialized) {
        // Start hybrid monitoring (uses real-time sensors)
        await _healthService.startHybridMonitoring();

        // Set up real-time step stream listener
        _setupRealTimeStepListener();
      } else {
        // Fallback to periodic polling if sensors not available
        print('⚠️ Real-time sensors not available, using periodic polling');
        _startPeriodicUpdates();
      }
    } catch (e) {
      print('❌ Error initializing real-time tracking: $e');
      // Fallback to periodic polling
      _startPeriodicUpdates();
    }
  }

  void _setupRealTimeStepListener() {
    // Listen to unified step updates from the hybrid system
    _stepSubscription = StepCounterService.stepStream.listen(
      (data) {
        if (data['type'] == 'step_update') {
          // Get the unified step count from the hybrid system
          _fetchSteps().then((_) {
            if (mounted) {
              final timestamp = data['timestamp'] as DateTime;
              // Check walking status with proper timing
              _checkUserWalkingWithTiming(timestamp);
              // Sync character animation
              _syncCharacterAnimation();
            }
          });
        }
      },
      onError: (error) {
        print('❌ Error in real-time step stream: $error');
        // Fallback to periodic polling on error
        _startPeriodicUpdates();
      },
    );
  }

  void _setWalkingState(bool walking) {
    if (_isUserWalking != walking) {
      setState(() {
        _isUserWalking = walking;
      });
      walking ? _startCharacterWalking() : _stopCharacterWalking();
      print(walking ? '🚶‍♂️ User started walking' : '🛑 User stopped walking');
    }
  }

  void _checkUserWalkingWithTiming(DateTime timestamp) {
    final now = DateTime.now();

    // If steps increased, user is walking
    if (_steps > _previousSteps) {
      _setWalkingState(true);
      _lastStepUpdate = now;
      print(
          '🚶‍♂️ Steps increased: $_previousSteps -> $_steps, user is walking');
    } else {
      // If steps didn't increase, user stopped walking immediately
      if (_isUserWalking) {
        _setWalkingState(false);
        print('🛑 Steps didn\'t increase, user stopped walking immediately');
      }
    }
  }

  void _startPeriodicUpdates() {
    // Fallback: Check steps every 5 seconds if real-time sensors fail
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _fetchSteps();
        // Ensure character animation is synchronized
        _syncCharacterAnimation();
        _startPeriodicUpdates(); // Recursive call for periodic updates
      }
    });
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
  }

  void _syncCharacterAnimation() {
    // Ensure character animation matches walking state
    _game?.updateWalkingState(_isUserWalking);
  }

  Future<void> _fetchSteps() async {
    try {
      // Use the same method as home.dart to get consistent step count
      int steps = await _healthService.fetchHybridStepsData();
      if (mounted) {
        setState(() {
          _previousSteps = _steps; // Store previous steps
          _steps = steps;
          _isLoading = false;
        });

        // Check if user is walking (steps increased)
        _checkUserWalkingWithTiming(DateTime.now());
      }
    } catch (e) {
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
    _healthService.stopHybridMonitoring();
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
                ),

                // Unified Stats Container - positioned as overlay
                Positioned(
                  top: 90,
                  left: 32,
                  right: 32,
                  child: GestureDetector(
                    onTap: () async {
                      // Manual refresh for testing
                      await _fetchSteps();
                      _ensureCharacterAnimation();
                      _syncCharacterAnimation();
                      _debugWalkingState();
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

                // Walking Status Indicator
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _isUserWalking
                          ? Colors.green.withOpacity(0.3)
                          : Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isUserWalking ? Colors.green : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _isUserWalking
                            ? Icons.directions_walk
                            : Icons.accessibility_new,
                        color: Colors.white,
                        size: 40,
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
      return;
    }
    if (walking && animation != walkingAnimation) {
      animation = walkingAnimation;
    } else if (!walking && animation != idleAnimation) {
      animation = idleAnimation;
    }
  }

  void startWalking() {
    isWalking = true;
    updateAnimation(true);
  }

  void stopWalking() {
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
      walking ? character!.startWalking() : character!.stopWalking();
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
