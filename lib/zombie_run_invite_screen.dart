import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/coin_service.dart';
import 'services/zombie_run_service.dart';
import 'main.dart';
import 'screens/zombie_run_lobby.dart';

class ZombieRunInviteScreen extends StatefulWidget {
  const ZombieRunInviteScreen({super.key});

  @override
  State<ZombieRunInviteScreen> createState() => _ZombieRunInviteScreenState();
}

class _ZombieRunInviteScreenState extends State<ZombieRunInviteScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _selectedFriendId;
  bool _isInviting = false;
  late TabController _tabController;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {Color backgroundColor = Colors.black}) {
    if (mounted && _scaffoldMessenger != null) {
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Friend to Zombie Run Challenge',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF7C4DFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF7C4DFF),
          tabs: const [
            Tab(icon: Icon(Icons.group_add), text: 'Invite Friends'),
            Tab(icon: Icon(Icons.inbox), text: 'Requests'),
            Tab(icon: Icon(Icons.send), text: 'Invites Sent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInviteFriendsTab(),
          _buildRequestsTab(),
          _buildInvitesSentTab(),
        ],
      ),
    );
  }

  // Tab 1: Invite Friends
  Widget _buildInviteFriendsTab() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Not authenticated.'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('friendships')
          .where('users', arrayContains: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error loading friends',
                  style: TextStyle(color: Colors.red)));
        }
        final friends = <Map<String, dynamic>>[];
        final seenUserIds = <String>{};
        for (final doc in snapshot.data?.docs ?? []) {
          final users = List<String>.from(doc['users'] ?? []);
          final otherUserId =
              users.firstWhere((id) => id != currentUser.uid, orElse: () => '');
          if (otherUserId.isNotEmpty && !seenUserIds.contains(otherUserId)) {
            seenUserIds.add(otherUserId);
            friends.add({'userId': otherUserId});
          }
        }
        if (friends.isEmpty) {
          return const Center(child: Text('No friends yet.'));
        }
        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return FutureBuilder<DocumentSnapshot>(
              future:
                  _firestore.collection('users').doc(friend['userId']).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || userSnapshot.data == null) {
                  return const ListTile(title: Text('Loading...'));
                }
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();
                // Check for existing pending invite in either direction
                return FutureBuilder<QuerySnapshot>(
                  future: _firestore
                      .collection('zombie_run_challenge_invites')
                      .where('status', isEqualTo: 'pending')
                      .where('challengeType', isEqualTo: 'zombie_run')
                      .where('fromUserId', isEqualTo: currentUser.uid)
                      .where('toUserId', isEqualTo: friend['userId'])
                      .get(),
                  builder: (context, inviteSnapshot) {
                    bool hasPendingInvite = false;
                    if (inviteSnapshot.hasData && inviteSnapshot.data != null) {
                      hasPendingInvite = inviteSnapshot.data!.docs.isNotEmpty;
                    }
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF7C4DFF).withOpacity(0.1),
                          child: Text(
                            (userData['displayName'] ??
                                        userData['username'] ??
                                        '?')
                                    .toString()
                                    .isNotEmpty
                                ? (userData['displayName'] ??
                                        userData['username'] ??
                                        '?')
                                    .toString()[0]
                                    .toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C4DFF)),
                          ),
                        ),
                        title: Text(
                            userData['displayName'] ??
                                userData['username'] ??
                                'Unknown',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                        subtitle: Text('@${userData['username'] ?? 'unknown'}',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey)),
                        trailing: hasPendingInvite
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Invited',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.add,
                                    color: Color(0xFF7C4DFF)),
                                onPressed: _isInviting
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedFriendId = friend['userId'];
                                        });
                                        _sendZombieRunChallengeInvite();
                                      },
                              ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // Tab 2: Requests (Invites to you)
  Widget _buildRequestsTab() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Not authenticated.'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('zombie_run_challenge_invites')
          .where('toUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error loading requests',
                  style: TextStyle(color: Colors.red)));
        }
        final requests = snapshot.data?.docs ?? [];
        if (requests.isEmpty) {
          return const Center(child: Text('No requests at the moment.'));
        }
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            return FutureBuilder<DocumentSnapshot>(
              future:
                  _firestore.collection('users').doc(data['fromUserId']).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || userSnapshot.data == null) {
                  return const ListTile(title: Text('Loading...'));
                }
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF7C4DFF).withOpacity(0.1),
                      child: Text(
                        (userData['displayName'] ?? userData['username'] ?? '?')
                                .toString()
                                .isNotEmpty
                            ? (userData['displayName'] ??
                                    userData['username'] ??
                                    '?')
                                .toString()[0]
                                .toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C4DFF)),
                      ),
                    ),
                    title: Text(
                        '${userData['displayName'] ?? userData['username'] ?? 'Unknown'} invited you!',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    subtitle: Text('@${userData['username'] ?? 'unknown'}',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            try {
                              await _firestore
                                  .collection('zombie_run_challenge_invites')
                                  .doc(doc.id)
                                  .update({
                                'status': 'declined',
                                'declinedAt': FieldValue.serverTimestamp(),
                              });
                              if (mounted) {
                                _showSnackBar('Invite declined',
                                    backgroundColor: Colors.grey);
                              }
                            } catch (e) {
                              if (mounted) {
                                _showSnackBar('Error declining invite: $e',
                                    backgroundColor: Colors.red);
                              }
                            }
                          },
                          child: const Text('Decline',
                              style: TextStyle(color: Colors.grey)),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              // Check if user has enough coins before accepting
                              final coinService = CoinService();
                              const requiredCoins = 50;
                              final hasEnoughCoins = await coinService
                                  .hasEnoughCoins(requiredCoins);

                              if (!hasEnoughCoins) {
                                if (mounted) {
                                  _showInsufficientCoinsDialog();
                                }
                                return;
                              }

                              await _firestore
                                  .collection('zombie_run_challenge_invites')
                                  .doc(doc.id)
                                  .update({
                                'status': 'accepted',
                                'acceptedAt': FieldValue.serverTimestamp(),
                              });

                              if (!mounted) return;

                              // Show success message
                              _showSnackBar('Zombie Run accepted!',
                                  backgroundColor: const Color(0xFF7C4DFF));

                              // Navigate to the zombie run lobby
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ZombieRunLobby(
                                    inviteId: doc.id,
                                    otherUsername: userData['displayName'] ??
                                        userData['username'] ??
                                        'Friend',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              _showSnackBar(
                                  'Error accepting invite: ${e.toString()}',
                                  backgroundColor: Colors.red);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C4DFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Accept',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Tab 3: Invites Sent (Invites from you)
  Widget _buildInvitesSentTab() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Not authenticated.'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('zombie_run_challenge_invites')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error loading invites',
                  style: TextStyle(color: Colors.red)));
        }
        final List<QueryDocumentSnapshot> invites =
            List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
        // Sort client-side by createdAt descending to avoid composite index
        invites.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTs = aData['createdAt'] as Timestamp?;
          final bTs = bData['createdAt'] as Timestamp?;
          final aMs = aTs?.millisecondsSinceEpoch ?? 0;
          final bMs = bTs?.millisecondsSinceEpoch ?? 0;
          return bMs.compareTo(aMs);
        });
        // Extra guard: filter to only pending in case any non-pending slipped in
        final List<QueryDocumentSnapshot> pendingInvites = invites.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'pending';
        }).toList();
        if (pendingInvites.isEmpty) {
          return const Center(child: Text('No invites sent yet.'));
        }

        // Since we're now properly filtering invites, we can use them directly
        final uniqueInvites = pendingInvites;

        return ListView.builder(
          itemCount: uniqueInvites.length,
          itemBuilder: (context, index) {
            final doc = uniqueInvites[index];
            final data = doc.data() as Map<String, dynamic>;
            final toUserId = data['toUserId'] as String;

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(toUserId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || userSnapshot.data == null) {
                  return const ListTile(title: Text('Loading...'));
                }
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();
                String statusText = '';
                if (data['status'] == 'pending') {
                  statusText = 'Pending';
                }
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withOpacity(0.18), // increased opacity
                        blurRadius: 18, // increased blur
                        spreadRadius: 2, // slight spread
                        offset: const Offset(0, 6), // more vertical offset
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      const Color(0xFF7C4DFF).withOpacity(0.1),
                                  child: Text(
                                    (userData['displayName'] ??
                                                userData['username'] ??
                                                '?')
                                            .toString()
                                            .isNotEmpty
                                        ? (userData['displayName'] ??
                                                userData['username'] ??
                                                '?')
                                            .toString()[0]
                                            .toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7C4DFF)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'To: ${userData['displayName'] ?? userData['username'] ?? 'Unknown'}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87),
                                  ),
                                  Text(
                                    '@${userData['username'] ?? 'unknown'}',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              statusText,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Only pending invites are shown; no extra actions needed
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _sendZombieRunChallengeInvite() async {
    if (_selectedFriendId == null) return;
    setState(() {
      _isInviting = true;
    });
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if user has enough coins before sending invite
      final coinService = CoinService();
      const requiredCoins = 50;
      final hasEnoughCoins = await coinService.hasEnoughCoins(requiredCoins);

      if (!hasEnoughCoins) {
        setState(() {
          _isInviting = false;
        });
        if (mounted) {
          _showInsufficientCoinsDialog();
        }
        return;
      }
      // Create the invite and get the document reference
      final inviteDocRef =
          await _firestore.collection('zombie_run_challenge_invites').add({
        'fromUserId': currentUser.uid,
        'toUserId': _selectedFriendId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'challengeType': 'zombie_run',
        'expiresAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
        'senderNotified': false,
        // Game state fields for both users
        'positions': {},
        'scores': {},
        'steps': {},
        'initialSteps': {},
        'rawSteps': {},
        'gameStarted': false,
        'matchStarted': false,
        'gameEnded': false,
        'winner': null,
        'gameStartTime': null,
        'matchStartTime': null,
        'gameEndTime': null,
      });

      final friendDoc =
          await _firestore.collection('users').doc(_selectedFriendId).get();
      final friendData = friendDoc.data();
      final friendFcmToken = friendData != null ? friendData['fcmToken'] : null;
      final friendDisplayName = friendData != null
          ? (friendData['displayName'] ?? friendData['username'] ?? 'Friend')
          : 'Friend';
      if (friendFcmToken != null && friendFcmToken != '') {
        await _sendFcmZombieRunInvite(
          friendFcmToken,
          currentUser.displayName ?? currentUser.email ?? 'Someone',
          inviteDocRef.id,
        );
      }
      // Start listening for acceptance on the sender side
      final zombieRunService = ZombieRunService(navigatorKey: navigatorKey);
      zombieRunService.listenForInviteAcceptedBySender(
          inviteDocRef.id, friendDisplayName);

      if (!mounted) return;
      _showSnackBar('Zombie run challenge invite sent successfully!',
          backgroundColor: const Color(0xFF7C4DFF));
      // Navigate to the "Invites Sent" tab instead of going back
      if (mounted && _tabController.index != 2) {
        _tabController.animateTo(2);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error sending invite: ${e.toString()}',
          backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isInviting = false;
        });
      }
    }
  }

  Future<void> _sendFcmZombieRunInvite(
      String fcmToken, String inviterUsername, String inviteId) async {
    // Cloud Function will automatically send FCM notification when invite is created
    // No need to manually send FCM here
    print('[ZombieRunService] FCM notification will be sent by Cloud Function');
  }

  Future<void> _acceptInviteRequest(
      String inviteId, String friendDisplayName) async {
    // Implementation of accepting the invite request
  }

  Future<void> _declineInviteRequest(String inviteId) async {
    // Implementation of declining the invite request
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
                'You need 50 coins to join this Zombie Run.',
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
              onPressed: () => Navigator.of(context).pop(),
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
}
