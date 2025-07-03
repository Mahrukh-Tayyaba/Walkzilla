import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/parallax.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flame/flame.dart';
import 'services/character_animation_service.dart';
import 'package:intl/intl.dart';

class SoloMode extends StatefulWidget {
  const SoloMode({super.key});

  @override
  State<SoloMode> createState() => _SoloModeState();
}

class _SoloModeState extends State<SoloMode> {
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = true;
  int _currentSteps = 2400; // Default value
  final double walkSpeed = 200; // pixels per second, adjust as needed

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      print('Game focus changed: ${_focusNode.hasFocus}');
    });
    _checkAnimationStatus();
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

  @override
  void dispose() {
    _focusNode.dispose();
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
                  game: SoloModeGame(),
                  focusNode: _focusNode,
                  autofocus: true,
                ),

                // Unified Stats Container - positioned as overlay
                Positioned(
                  top: 90,
                  left: 32,
                  right: 32,
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
                        // Steps (value only, no icon)
                        Text(
                          NumberFormat.decimalPattern().format(_currentSteps),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 7, 50, 86),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Time, Distance, Calories Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Time
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.access_time,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '24:30',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            // Distance
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.straighten,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '1.8 km',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            // Calories
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.local_fire_department,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '120',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Touch controls
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: GestureDetector(
                    onPanStart: (_) {
                      SoloModeGame.instance?.character?.startWalking();
                    },
                    onPanEnd: (_) {
                      SoloModeGame.instance?.character?.stopWalking();
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),

                // Step Progress Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: StepProgressBar(
                      currentSteps: _currentSteps, stepGoal: 6000),
                ),
              ],
            ),
    );
  }
}

class Character extends SpriteAnimationComponent
    with HasGameRef, KeyboardHandler {
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
