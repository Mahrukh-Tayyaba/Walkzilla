import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flame/flame.dart';
import 'package:flame/events.dart';
import '../services/character_service.dart';
import '../services/character_animation_service.dart';

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
  late String _userId;
  bool _gameStarted = false;
  String? _winner;
  bool _gameEnded = false;
  bool _isLoadingCharacters = true;
  String? _otherPlayerId;

  // New racing system variables
  double _userPosition = 0.0;
  double _opponentPosition = 0.0;
  bool _isUserWalking = false;
  bool _isOpponentWalking = false;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<DocumentSnapshot>? _gameStateSubscription;
  static const double trackWidth = 5000.0;
  static const double moveDistance = 50.0;
  static const double finishLinePosition = 5000.0;

  // Callback functions to update character animations
  CharacterDisplayGame? _userGameInstance;
  CharacterDisplayGame? _opponentGameInstance;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser!.uid;
    _initializeGame();
    _preloadCharacters();
    _startGameStateListener();
  }

  @override
  void dispose() {
    _gameStateSubscription?.cancel();
    _scrollController.dispose();
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
      'scores': {
        _userId: 0,
        // The other player's score will be updated when they join
      }
    });
  }

  void _startGameStateListener() {
    final docRef =
        _firestore.collection('duo_challenge_invites').doc(widget.inviteId);

    _gameStateSubscription = docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final positions = (data['positions'] ?? {}) as Map<String, dynamic>;
      final gameEnded = data['gameEnded'] ?? false;
      final winner = data['winner'] as String?;

      // Update opponent position in real-time
      final otherPlayerId =
          positions.keys.where((key) => key != _userId).firstOrNull;
      if (otherPlayerId != null) {
        final opponentPos = (positions[otherPlayerId] ?? 0.0).toDouble();
        if (_opponentPosition != opponentPos) {
          setState(() {
            _opponentPosition = opponentPos;
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

  void _onArrowPressed() async {
    if (_gameEnded) return;

    print('Button pressed - starting walking animation');
    setState(() {
      _isUserWalking = true;
      _userPosition += moveDistance;
    });

    // Update character animation to walking
    _updateUserCharacterAnimation(true);

    // Update position in Firestore for real-time sync
    await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .update({
      'positions.$_userId': _userPosition,
    });

    // Auto-scroll to keep user character visible
    _autoScrollToUser();

    // Check if user reached finish line
    if (_userPosition >= finishLinePosition) {
      await _endGame(_userId);
    }
  }

  void _onArrowReleased() {
    print('Button released - stopping walking animation');
    setState(() {
      _isUserWalking = false;
    });

    // Update character animation to idle
    _updateUserCharacterAnimation(false);
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
                Navigator.of(context)
                    .popUntil((route) => route.isFirst); // Go to home
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
                  Text('Loading characters...', style: TextStyle(fontSize: 18)),
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
    const double buildingsOriginalWidth = 1200;
    const double buildingsOriginalHeight = 2005;
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
          child: Text(name,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        );

    return Stack(
      children: [
        // Static sky background (covers full screen)
        Positioned.fill(
          child: Image.asset(
            'assets/images/sky-race.png',
            fit: BoxFit.cover,
          ),
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
                      Positioned(
                        top: 0,
                        child: nameLabel('You'),
                      ),
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
        // Arrow button at bottom of screen
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onPanStart: (_) {
                print('Button pan start - starting walking animation');
                _onArrowPressed();
                // Direct character access like solo mode
                CharacterDisplayGame.instance?.character?.startWalking();
              },
              onPanEnd: (_) {
                print('Button pan end - stopping walking animation');
                _onArrowReleased();
                // Direct character access like solo mode
                CharacterDisplayGame.instance?.character?.stopWalking();
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 40,
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
                // Text labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'You: ${_userPosition.toInt()}m',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C4DFF),
                      ),
                    ),
                    if (_otherPlayerId != null)
                      Text(
                        '${widget.otherUsername ?? 'Opponent'}: ${_opponentPosition.toInt()}m',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
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
    final scaleX = screenWidth / baseWidth;
    final double scaleY = screenHeight / baseHeight;

    try {
      // No background layers here, only character
      character = Character(userId: userId);
      character!.size = Vector2(characterWidth, characterHeight);
      character!.anchor = Anchor.bottomCenter;
      character!.position =
          Vector2(screenWidth / 2, screenHeight); // Centered in widget
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
        'CharacterDisplayGame updateWalkingState called with walking: $walking');
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
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
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
