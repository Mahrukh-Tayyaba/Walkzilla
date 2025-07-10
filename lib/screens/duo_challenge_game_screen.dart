import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/parallax.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flame/flame.dart';
import '../services/character_service.dart';

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
  int _player1Score = 0;
  int _player2Score = 0;
  String? _winner;
  bool _gameEnded = false;
  bool _isLoadingCharacters = true;
  String? _otherPlayerId;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser!.uid;
    _initializeGame();
    _preloadCharacters();
  }

  void _initializeGame() async {
    // Update the invite document to mark game as started
    await _firestore
        .collection('duo_challenge_invites')
        .doc(widget.inviteId)
        .update({
      'gameStarted': true,
      'gameStartTime': FieldValue.serverTimestamp(),
      'scores': {
        _userId: 0,
        // The other player's score will be updated when they join
      }
    });
  }

  Future<void> _preloadCharacters() async {
    final characterService = CharacterService();

    // Preload current user's character animations
    await characterService.preloadCurrentUserAnimations();

    if (mounted) {
      setState(() {
        _isLoadingCharacters = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef =
        _firestore.collection('duo_challenge_invites').doc(widget.inviteId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Duo Challenge Game'),
        backgroundColor: const Color(0xFF7C4DFF),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final scores = (data['scores'] ?? {}) as Map<String, dynamic>;
          final gameStarted = data['gameStarted'] ?? false;
          final gameEnded = data['gameEnded'] ?? false;
          final winner = data['winner'] as String?;

          // Get scores for both players
          final player1Score = scores[_userId] ?? 0;
          final otherPlayerId = scores.entries
              .where((entry) => entry.key != _userId)
              .map((entry) => entry.key)
              .firstOrNull;
          final player2Score =
              otherPlayerId != null ? (scores[otherPlayerId] ?? 0) : 0;

          // Update local state using post frame callback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (gameStarted && !_gameStarted) {
              setState(() => _gameStarted = true);
            }
            if (gameEnded && !_gameEnded) {
              setState(() {
                _gameEnded = true;
                _winner = winner;
              });
            }
            if (_player1Score != player1Score ||
                _player2Score != player2Score ||
                _otherPlayerId != otherPlayerId) {
              setState(() {
                _player1Score = player1Score;
                _player2Score = player2Score;
                _otherPlayerId = otherPlayerId;
              });
            }
          });

          return _buildGameContent();
        },
      ),
    );
  }

  Widget _buildGameContent() {
    if (!_gameStarted) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Waiting for game to start...',
                style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    if (_isLoadingCharacters) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading characters...', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    if (_gameEnded) {
      return _buildGameEndScreen();
    }

    return _buildCharacterDisplay();
  }

  Widget _buildCharacterDisplay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double gameWidth = constraints.maxWidth;
        final double gameHeight = constraints.maxHeight;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Single Flame GameWidget for both characters
            Positioned(
              left: 0,
              top: 0,
              width: gameWidth,
              height: gameHeight,
              child: GameWidget(
                game: DuoRaceGame(
                  userId: _userId,
                  userName: 'You',
                  userScore: _player1Score,
                  userIsWalking: _isWalking,
                  opponentId: _otherPlayerId ?? 'unknown',
                  opponentName: widget.otherUsername ?? 'Opponent',
                  opponentScore: _player2Score,
                ),
              ),
            ),
            // Arrow button at the bottom center
            Positioned(
              bottom: 40,
              left: (gameWidth / 2) - 40,
              child: GestureDetector(
                onTapDown: (_) => _onArrowPressed(),
                onTapUp: (_) => _onArrowReleased(),
                onTapCancel: _onArrowReleased,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isWalking = false;

  void _onArrowPressed() async {
    setState(() {
      _isWalking = true;
    });
    // Simulate score increase
    final docRef =
        _firestore.collection('duo_challenge_invites').doc(widget.inviteId);
    final doc = await docRef.get();
    final data = doc.data() as Map<String, dynamic>;
    final scores = (data['scores'] ?? {}) as Map<String, dynamic>;
    final currentScore = (scores[_userId] ?? 0) as int;
    await docRef.update({
      'scores.$_userId': currentScore + 1,
    });
  }

  void _onArrowReleased() {
    setState(() {
      _isWalking = false;
    });
  }

  Widget _buildGameEndScreen() {
    final isWinner = _winner == _userId;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isWinner ? Icons.emoji_events : Icons.sports_esports,
            size: 100,
            color: isWinner ? Colors.amber : Colors.grey,
          ),
          const SizedBox(height: 24),
          Text(
            isWinner ? 'Congratulations!' : 'Game Over',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isWinner ? Colors.amber : Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isWinner ? 'You won the duo challenge!' : 'Better luck next time!',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text(
              'Back to Home',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// Info bubble widget styled like the provided image
class _InfoBubble extends StatelessWidget {
  final String name;
  final int score;
  const _InfoBubble({required this.name, required this.score});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                score.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        // Pointer triangle
        CustomPaint(
          size: const Size(24, 10),
          painter: _BubblePointerPainter(),
        ),
      ],
    );
  }
}

class _BubblePointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Character display game for showing animated characters
class CharacterDisplayGame extends FlameGame {
  final bool isPlayer1;
  final bool isWalking;
  final String userId;
  final Offset? customPosition;
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

  CharacterDisplayGame({
    required this.isPlayer1,
    required this.isWalking,
    required this.userId,
    this.customPosition,
  });

  @override
  Future<void> onLoad() async {
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
      character = Character(userId: userId);
      character!.size =
          Vector2(800 * scaleX, 800 * scaleY); // 800x800 base size
      character!.anchor = Anchor.bottomLeft;

      // Position character based on player side
      if (customPosition != null) {
        character!.position = Vector2(customPosition!.dx, customPosition!.dy);
      } else if (isPlayer1) {
        character!.position = Vector2(
          100 * scaleX, // X position (adjust as needed)
          screenHeight -
              (pathHeight * scaleY) +
              transparentOffset, // Y = top of path + offset
        );
      } else {
        // Player 2 on right side, flipped horizontally
        character!.flipHorizontally();
        character!.position = Vector2(
          screenWidth - (100 * scaleX), // X position on right side
          screenHeight -
              (pathHeight * scaleY) +
              transparentOffset, // Y = top of path + offset
        );
      }

      // Set walking animation if needed
      if (isWalking) {
        character!.startWalking();
      }

      add(character!);
    } catch (e) {
      print('CharacterDisplayGame onLoad error: $e');
    }
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
    try {
      // Use character service to get user's character animations
      final characterService = CharacterService();
      final animations = await characterService.loadUserAnimations(userId);

      idleAnimation = animations['idle'];
      walkingAnimation = animations['walking'];
      _animationsLoaded = true;
      animation = idleAnimation;
    } catch (e) {
      print('Character onLoad error: $e');
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
}

// Flame game for duo race, both characters in one game
class DuoRaceGame extends FlameGame {
  final String userId;
  final String userName;
  final int userScore;
  final bool userIsWalking;
  final String opponentId;
  final String opponentName;
  final int opponentScore;

  DuoRaceGame({
    required this.userId,
    required this.userName,
    required this.userScore,
    required this.userIsWalking,
    required this.opponentId,
    required this.opponentName,
    required this.opponentScore,
  });

  late Character userCharacter;
  late Character opponentCharacter;
  late InfoBubbleComponent userBubble;
  late InfoBubbleComponent opponentBubble;

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

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final screenWidth = size.x;
    final screenHeight = size.y;
    final scaleX = screenWidth / baseWidth;
    final scaleY = screenHeight / baseHeight;

    // Background layers (same as solo_mode.dart)
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

    // Characters (side by side, same logic as solo_mode.dart)
    final double transparentBottomPx = 140;
    final double transparentOffset = transparentBottomPx * scaleY;
    final double charY =
        screenHeight - (pathHeight * scaleY) + transparentOffset;
    final double charSize = 800 * scaleX;
    final double charOffset = 40 * scaleX;

    userCharacter = Character(userId: userId)
      ..size = Vector2(charSize, charSize)
      ..anchor = Anchor.bottomLeft
      ..position = Vector2(100 * scaleX - charOffset, charY);
    if (userIsWalking)
      userCharacter.startWalking();
    else
      userCharacter.stopWalking();
    add(userCharacter);

    opponentCharacter = Character(userId: opponentId)
      ..size = Vector2(charSize, charSize)
      ..anchor = Anchor.bottomLeft
      ..position = Vector2(100 * scaleX + charOffset, charY);
    // Opponent walks if their score is higher (optional, or you can use a flag)
    if (opponentScore > userScore)
      opponentCharacter.startWalking();
    else
      opponentCharacter.stopWalking();
    opponentCharacter.flipHorizontally();
    add(opponentCharacter);

    // Info bubbles above each character
    userBubble = InfoBubbleComponent(
      name: userName,
      score: userScore,
      position: Vector2(
          userCharacter.position.x + charSize / 2, charY - charSize - 40),
    );
    add(userBubble);
    opponentBubble = InfoBubbleComponent(
      name: opponentName,
      score: opponentScore,
      position: Vector2(
          opponentCharacter.position.x + charSize / 2, charY - charSize - 40),
    );
    add(opponentBubble);
  }
}

// Info bubble as a Flame component
class InfoBubbleComponent extends PositionComponent {
  final String name;
  final int score;
  InfoBubbleComponent({
    required this.name,
    required this.score,
    required Vector2 position,
  }) {
    this.position = position;
    size = Vector2(120, 60);
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y - 10);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final paint = Paint()..color = Colors.white;
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, borderPaint);
    // Draw pointer
    final path = Path();
    path.moveTo(size.x / 2 - 12, size.y - 10);
    path.lineTo(size.x / 2, size.y);
    path.lineTo(size.x / 2 + 12, size.y - 10);
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
    // Draw text
    final textPainter = TextPainter(
      text: TextSpan(
        text: name + '\n',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black,
        ),
        children: [
          TextSpan(
            text: score.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: size.x - 8);
    textPainter.paint(canvas, Offset((size.x - textPainter.width) / 2, 8));
  }
}
