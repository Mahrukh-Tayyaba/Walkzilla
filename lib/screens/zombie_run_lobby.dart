import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'zombie_run_game_screen.dart';
import '../services/character_data_service.dart';
import '../services/character_animation_service.dart';
import '../services/coin_service.dart';

class ZombieRunLobby extends StatefulWidget {
  final String inviteId;
  final String? otherUsername;

  const ZombieRunLobby({
    Key? key,
    required this.inviteId,
    this.otherUsername,
  }) : super(key: key);

  @override
  State<ZombieRunLobby> createState() => _ZombieRunLobbyState();
}

class _ZombieRunLobbyState extends State<ZombieRunLobby>
    with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late String _userId;
  final CharacterDataService _characterDataService = CharacterDataService();
  final CharacterAnimationService _animationService =
      CharacterAnimationService();
  bool coinsMerged = false;
  StreamSubscription<DocumentSnapshot>? _gameStartSubscription;
  late AnimationController _leftCoinsController;
  late AnimationController _rightCoinsController;
  bool _showCenterAmount = false;
  static const int _coinCount = 7;
  bool _redirectedToGame = false;
  bool _preloadedUser = false;
  bool _preloadedOpponent = false;
  Map<String, dynamic>? _preUserCharacterData;
  Map<String, dynamic>? _preOpponentCharacterData;
  String? _opponentUserId;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser!.uid;
    _setPresence(true);

    // Start preloading current user's character immediately
    _preloadCurrentUserCharacter();

    // Derive opponent from invite document and preload immediately (works even before presence appears)
    _deriveOpponentFromInviteAndPreload();

    _leftCoinsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _rightCoinsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Listen for game start
    _listenForGameStart();
  }

  Future<void> _deriveOpponentFromInviteAndPreload() async {
    try {
      final doc = await _firestore
          .collection('zombie_run_challenge_invites')
          .doc(widget.inviteId)
          .get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final fromUserId = data['fromUserId'] as String?;
      final toUserId = data['toUserId'] as String?;
      if (fromUserId == null || toUserId == null) return;
      final oppId = _userId == fromUserId ? toUserId : fromUserId;
      if (oppId.isEmpty) return;
      _opponentUserId = oppId;

      if (!_preloadedOpponent) {
        await _preloadOpponentCharacter(oppId);
      }
    } catch (e) {
      debugPrint('⚠️ Lobby: Failed to derive opponent from invite: $e');
    }
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Insufficient Coins',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You need 50 coins to join this challenge.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'To earn more coins:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Walk more steps to earn coins\n• Play daily challenges to earn more coins',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to home
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _setPresence(false);
    _leftCoinsController.dispose();
    _rightCoinsController.dispose();
    _gameStartSubscription?.cancel();
    super.dispose();
  }

  void _setPresence(bool present) async {
    final docRef = _firestore
        .collection('zombie_run_challenge_invites')
        .doc(widget.inviteId);
    await docRef.set({
      'lobbyPresence': {_userId: present},
    }, SetOptions(merge: true));
  }

  void _listenForGameStart() {
    final docRef = _firestore
        .collection('zombie_run_challenge_invites')
        .doc(widget.inviteId);
    _gameStartSubscription = docRef.snapshots().listen((doc) async {
      if (!doc.exists) return;
      final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      final gameStarted = data['gameStarted'] ?? false;
      final presence = (data['lobbyPresence'] ?? {}) as Map<String, dynamic>;

      // Attempt to determine opponent userId from lobby presence
      final keys = presence.keys.cast<String>().toList();
      if (keys.isNotEmpty) {
        final maybeOpponentId = keys.firstWhere(
          (k) => k != _userId,
          orElse: () => '',
        );
        if (maybeOpponentId.isNotEmpty) {
          _opponentUserId = maybeOpponentId;
          // Preload opponent character if not yet
          if (!_preloadedOpponent) {
            await _preloadOpponentCharacter(maybeOpponentId);
          }
        }
      }

      if (gameStarted && !_redirectedToGame && mounted) {
        // Ensure preloads are done before navigation
        await _ensurePreloadsCompleteWithTimeout(const Duration(seconds: 5));

        _redirectedToGame = true;
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ZombieRunGameScreen(
              inviteId: widget.inviteId,
              otherUsername: widget.otherUsername,
              initialUserCharacterData: _preUserCharacterData,
              initialOpponentCharacterData: _preOpponentCharacterData,
              initialOpponentUserId: _opponentUserId,
            ),
          ),
        );
      }
    });
  }

  Future<void> _ensurePreloadsCompleteWithTimeout(Duration timeout) async {
    final List<Future<void>> futures = [];
    if (!_preloadedUser) futures.add(_preloadCurrentUserCharacter());
    if (!_preloadedOpponent && _opponentUserId != null) {
      futures.add(_preloadOpponentCharacter(_opponentUserId!));
    }
    if (futures.isEmpty) return;
    try {
      await Future.wait(futures).timeout(timeout);
    } on TimeoutException {
      debugPrint('⏳ Lobby: Preload timeout, proceeding to game');
    } catch (e) {
      debugPrint('❌ Lobby: Preload error before game: $e');
    }
  }

  Future<void> _preloadCurrentUserCharacter() async {
    if (_preloadedUser) return;
    try {
      final userData =
          await _characterDataService.getCurrentUserCharacterData();
      _preUserCharacterData = userData;
      final userCharacterId = '${_userId}_${userData['currentCharacter']}';
      await _animationService.preloadAnimationsForCharacterWithData(
        userCharacterId,
        userData,
      );
      _preloadedUser = true;
      debugPrint(
          '🎭 Lobby: Preloaded current user animations for $userCharacterId');
    } catch (e) {
      debugPrint('❌ Lobby: Failed to preload current user character: $e');
    }
  }

  Future<void> _preloadOpponentCharacter(String opponentUserId) async {
    if (_preloadedOpponent) return;
    try {
      final oppData =
          await _characterDataService.getUserCharacterData(opponentUserId);
      _preOpponentCharacterData = oppData;
      final opponentCharacterId =
          '${opponentUserId}_${oppData['currentCharacter']}';
      await _animationService.preloadAnimationsForCharacterWithData(
        opponentCharacterId,
        oppData,
      );
      _preloadedOpponent = true;
      debugPrint(
          '🎭 Lobby: Preloaded opponent animations for $opponentCharacterId');
    } catch (e) {
      debugPrint('❌ Lobby: Failed to preload opponent character: $e');
    }
  }

  Future<void> _startGame() async {
    try {
      // Update the invite document to start the game
      await _firestore
          .collection('zombie_run_challenge_invites')
          .doc(widget.inviteId)
          .update({
        'gameStarted': true,
        'gameStartTime': FieldValue.serverTimestamp(),
      });

      // Navigate to the game screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ZombieRunGameScreen(
              inviteId: widget.inviteId,
              otherUsername: widget.otherUsername,
              initialUserCharacterData: _preUserCharacterData,
              initialOpponentCharacterData: _preOpponentCharacterData,
              initialOpponentUserId: _opponentUserId,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error starting game: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deductCoinsIfNeeded() async {
    if (coinsMerged) return;
    coinsMerged = true;

    // Use the coin service to properly deduct coins with validation
    final coinService = CoinService();
    final success = await coinService.deductCoins(50);

    if (!success) {
      print(
          '❌ Failed to deduct coins for zombie run challenge - insufficient balance');
      // Show error dialog and redirect user
      if (mounted) {
        _showInsufficientCoinsDialog();
      }
    } else {
      print('✅ Successfully deducted 50 coins for zombie run challenge');
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef = _firestore
        .collection('zombie_run_challenge_invites')
        .doc(widget.inviteId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Zombie Run Challenge Lobby'),
        backgroundColor: const Color(0xFF7C4DFF),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final presence =
              (data['lobbyPresence'] ?? {}) as Map<String, dynamic>;
          final usersPresent =
              presence.entries.where((e) => e.value == true).length;

          // Placeholder user info (replace with actual user data as needed)
          final leftPlayer = {
            'username': 'You',
            'avatar': _auth.currentUser?.photoURL,
            'coins': 50,
          };
          final rightPlayer = usersPresent >= 2
              ? {
                  'username': widget.otherUsername ?? 'Friend',
                  'avatar': null,
                  'coins': 50,
                }
              : {
                  'username': 'Waiting...',
                  'avatar': null,
                  'coins': 50,
                  'isLoading': true,
                };

          // Animation trigger
          if (usersPresent >= 2 && !coinsMerged) {
            _deductCoinsIfNeeded();
            _leftCoinsController.forward();
            _rightCoinsController.forward();
            Future.delayed(const Duration(milliseconds: 900), () {
              if (mounted) setState(() => _showCenterAmount = true);
            });

            // Preload characters after 5 seconds to allow sprite sheets to preload
            Future.delayed(const Duration(seconds: 5), () async {
              if (mounted) {
                // Ensure we have attempted preloading for both
                if (!_preloadedUser) {
                  await _preloadCurrentUserCharacter();
                }
                if (!_preloadedOpponent && _opponentUserId != null) {
                  await _preloadOpponentCharacter(_opponentUserId!);
                }
                // Double-check that both character data exist
                if (_preUserCharacterData == null) {
                  try {
                    _preUserCharacterData = await _characterDataService
                        .getCurrentUserCharacterData();
                  } catch (_) {}
                }
                if (_preOpponentCharacterData == null &&
                    _opponentUserId != null) {
                  try {
                    _preOpponentCharacterData = await _characterDataService
                        .getUserCharacterData(_opponentUserId!);
                  } catch (_) {}
                }

                // Auto-start the game
                _startGame();
              }
            });
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left Player Card
                      _buildPlayerCard(leftPlayer, isCurrentUser: true),
                      // Center VS and Prize Pot
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              'VS',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[600],
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildPrizePotBox(usersPresent, _showCenterAmount),
                            const SizedBox(height: 20),
                            // Auto-start countdown when both players are present
                            if (usersPresent >= 2)
                              const SizedBox
                                  .shrink(), // Hidden countdown - functionality remains
                          ],
                        ),
                      ),
                      // Right Player Card
                      _buildPlayerCard(rightPlayer, isCurrentUser: false),
                    ],
                  ),
                  // Animated coins from left
                  if (usersPresent >= 2 && !_showCenterAmount)
                    ...List.generate(
                      _coinCount,
                      (i) => _buildAnimatedCoin(
                        fromLeft: true,
                        index: i,
                        controller: _leftCoinsController,
                      ),
                    ),
                  // Animated coins from right
                  if (usersPresent >= 2 && !_showCenterAmount)
                    ...List.generate(
                      _coinCount,
                      (i) => _buildAnimatedCoin(
                        fromLeft: false,
                        index: i,
                        controller: _rightCoinsController,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnimatedCoin({
    required bool fromLeft,
    required int index,
    required AnimationController controller,
  }) {
    // Layout constants
    final double startX = fromLeft ? -110 : 110;
    final double endX = 0;
    final double startY = 90.0;
    final double endY =
        -10.0 + Random(index).nextInt(20).toDouble(); // small vertical spread
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(0.0, 1.0, curve: Curves.easeInOut),
    );
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = curve.value;
        final x = startX +
            (endX - startX) * t +
            (fromLeft ? index * 6.0 : -index * 6.0);
        final y = startY + (endY - startY) * t;
        return Positioned(
          left: MediaQuery.of(context).size.width / 2 + x,
          top: MediaQuery.of(context).size.height / 2 + y,
          child: Opacity(
            opacity: 1.0 - t,
            child: Image.asset('assets/images/coin.png', width: 28, height: 28),
          ),
        );
      },
    );
  }

  Widget _buildPlayerCard(
    Map<String, dynamic> player, {
    required bool isCurrentUser,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Card with avatar, level badge, and username bar
        Container(
          width: 120,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey[400]!, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 120,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: player['isLoading'] == true
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 3,
                            ),
                          )
                        : player['avatar'] != null
                            ? ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                                child: Image.network(
                                  player['avatar'],
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Text(
                    player['username'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Coin/status box below the card
        const SizedBox(height: 12),
        Container(
          width: 120,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.yellow[700]!, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/coin.png', width: 22, height: 22),
              const SizedBox(width: 6),
              Text(
                '${player['coins']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrizePotBox(int usersPresent, bool showAmount) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow[700]!, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/coin.png', width: 28, height: 28),
          const SizedBox(height: 2),
          Text(
            showAmount ? '100' : '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}
