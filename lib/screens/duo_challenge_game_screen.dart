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

          return Column(
            children: [
              // Game header with scores
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Player 1 (current user)
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.person,
                              size: 30, color: Colors.blue),
                        ),
                        const SizedBox(height: 8),
                        const Text('You',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Score: $player1Score',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    // VS indicator
                    Column(
                      children: [
                        Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[600],
                          ),
                        ),
                        if (gameStarted && !gameEnded)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    // Player 2 (other user)
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.red[100],
                          child: const Icon(Icons.person,
                              size: 30, color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        Text(widget.otherUsername ?? 'Opponent',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Score: $player2Score',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              // Game content
              Expanded(
                child: _gameEnded
                    ? _buildGameEndScreen(winner)
                    : _buildGameContent(),
              ),
            ],
          );
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

    return Column(
      children: [
        // Character display area
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                // Player 1 Character (Left side)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: GameWidget(
                              game: CharacterDisplayGame(
                                isPlayer1: true,
                                isWalking: _player1Score > _player2Score,
                                userId: _userId,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // VS divider
                Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),

                // Player 2 Character (Right side)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          widget.otherUsername ?? 'Opponent',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: GameWidget(
                              game: CharacterDisplayGame(
                                isPlayer1: false,
                                isWalking: _player2Score > _player1Score,
                                userId: _otherPlayerId ?? 'unknown',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Game controls
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Duo Challenge Game',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7C4DFF),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Game is in progress...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _simulateScoreIncrease,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text(
                  'Score Point',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameEndScreen(String? winner) {
    final isWinner = winner == _userId;

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

  void _simulateScoreIncrease() async {
    // Get current score and increment it
    final docRef =
        _firestore.collection('duo_challenge_invites').doc(widget.inviteId);
    final doc = await docRef.get();
    final data = doc.data() as Map<String, dynamic>;
    final scores = (data['scores'] ?? {}) as Map<String, dynamic>;
    final currentScore = (scores[_userId] ?? 0) as int;

    // Update score
    await docRef.update({
      'scores.$_userId': currentScore + 1,
    });

    // Update local state for immediate UI feedback
    setState(() {
      _player1Score = currentScore + 1;
    });

    // Check if game should end (first to 5 points wins)
    if (currentScore + 1 >= 5) {
      await docRef.update({
        'gameEnded': true,
        'winner': _userId,
        'endTime': FieldValue.serverTimestamp(),
      });
    }
  }
}

// Character display game for showing animated characters
class CharacterDisplayGame extends FlameGame {
  final bool isPlayer1;
  final bool isWalking;
  final String userId;
  Character? character;

  CharacterDisplayGame({
    required this.isPlayer1,
    required this.isWalking,
    required this.userId,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Create character component
    character = Character(userId: userId);
    if (character != null) {
      // Position character in the center
      character!.position = Vector2(size.x / 2, size.y / 2);

      // Flip character horizontally for player 2 to face the other direction
      if (!isPlayer1) {
        character!.flipHorizontally();
      }

      // Set walking animation if needed
      if (isWalking) {
        character!.startWalking();
      }

      add(character!);
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
      : super(size: Vector2(200, 200)); // Smaller size for display

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
