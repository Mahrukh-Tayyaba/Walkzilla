import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/friend_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/coin_service.dart';
import 'services/duo_challenge_service.dart';
import 'main.dart';
import 'screens/duo_challenge_lobby.dart';
import 'utils/user_avatar_helper.dart';

class DuoChallengeInviteScreen extends StatefulWidget {
  const DuoChallengeInviteScreen({super.key});

  @override
  State<DuoChallengeInviteScreen> createState() =>
      _DuoChallengeInviteScreenState();
}

class _DuoChallengeInviteScreenState extends State<DuoChallengeInviteScreen>
    with SingleTickerProviderStateMixin {
  final FriendService _friendService = FriendService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _selectedFriendId;
  bool _isInviting = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6E9),
      appBar: AppBar(
        title: const Text('Invite Friend to Duo Challenge',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFed3e57),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFed3e57),
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
        for (final doc in snapshot.data?.docs ?? []) {
          final users = List<String>.from(doc['users'] ?? []);
          final otherUserId =
              users.firstWhere((id) => id != currentUser.uid, orElse: () => '');
          if (otherUserId.isNotEmpty) {
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
                      .collection('duo_challenge_invites')
                      .where('status', isEqualTo: 'pending')
                      .where('challengeType', isEqualTo: 'duo')
                      .where('fromUserId',
                          whereIn: [currentUser.uid, friend['userId']]).get(),
                  builder: (context, inviteSnapshot) {
                    bool hasPendingInvite = false;
                    if (inviteSnapshot.hasData && inviteSnapshot.data != null) {
                      for (final doc in inviteSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        // Block if invite is between these two users in either direction
                        if ((data['fromUserId'] == currentUser.uid &&
                                data['toUserId'] == friend['userId']) ||
                            (data['fromUserId'] == friend['userId'] &&
                                data['toUserId'] == currentUser.uid)) {
                          hasPendingInvite = true;
                          break;
                        }
                      }
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
                        leading: UserAvatarHelper.buildAvatar(
                          userId: friend['userId'],
                          displayName: userData['displayName'] ??
                              userData['username'] ??
                              'Unknown',
                          profileImage: userData['profileImageUrl'],
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
                                    color: Color(0xFFed3e57)),
                                onPressed: _isInviting
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedFriendId = friend['userId'];
                                        });
                                        _sendDuoChallengeInvite();
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
          .collection('duo_challenge_invites')
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
                    leading: UserAvatarHelper.buildAvatar(
                      userId: data['fromUserId'],
                      displayName: userData['displayName'] ??
                          userData['username'] ??
                          'Unknown',
                      profileImage: userData['profileImageUrl'],
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
                            await _firestore
                                .collection('duo_challenge_invites')
                                .doc(doc.id)
                                .update({
                              'status': 'declined',
                              'declinedAt': FieldValue.serverTimestamp(),
                            });
                          },
                          child: const Text('Decline',
                              style: TextStyle(color: Colors.grey)),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await _firestore
                                  .collection('duo_challenge_invites')
                                  .doc(doc.id)
                                  .update({
                                'status': 'accepted',
                                'acceptedAt': FieldValue.serverTimestamp(),
                              });
                              if (!mounted) return;
                              Future.microtask(() {
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => DuoChallengeLobby(
                                      inviteId: doc.id,
                                      otherUsername: userData['displayName'] ??
                                          userData['username'] ??
                                          'Friend',
                                    ),
                                  ),
                                );
                              });
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Error accepting invite: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFed3e57),
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
          .collection('duo_challenge_invites')
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

        // Group invites by recipient and get the most recent one per person
        final Map<String, QueryDocumentSnapshot> groupedInvites = {};
        final Map<String, int> inviteCounts = {};

        for (final doc in pendingInvites) {
          final data = doc.data() as Map<String, dynamic>;
          final toUserId = data['toUserId'] as String;

          // Keep only the most recent invite per person
          if (!groupedInvites.containsKey(toUserId)) {
            groupedInvites[toUserId] = doc;
            inviteCounts[toUserId] = 1;
          } else {
            inviteCounts[toUserId] = (inviteCounts[toUserId] ?? 0) + 1;
          }
        }

        final uniqueInvites = groupedInvites.values.toList();

        return ListView.builder(
          itemCount: uniqueInvites.length,
          itemBuilder: (context, index) {
            final doc = uniqueInvites[index];
            final data = doc.data() as Map<String, dynamic>;
            final toUserId = data['toUserId'] as String;
            final inviteCount = inviteCounts[toUserId] ?? 1;

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
                                UserAvatarHelper.buildAvatar(
                                  userId: data['toUserId'],
                                  displayName: userData['displayName'] ??
                                      userData['username'] ??
                                      'Unknown',
                                  profileImage: userData['profileImageUrl'],
                                ),
                                if (inviteCount > 1)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 20,
                                        minHeight: 20,
                                      ),
                                      child: Text(
                                        inviteCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
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
                                  if (inviteCount > 1)
                                    Text(
                                      '$inviteCount invites sent',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
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

  Future<void> _sendDuoChallengeInvite() async {
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
          await _firestore.collection('duo_challenge_invites').add({
        'fromUserId': currentUser.uid,
        'toUserId': _selectedFriendId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'challengeType': 'duo',
        'expiresAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
        'senderNotified': false,
      });

      final friendDoc =
          await _firestore.collection('users').doc(_selectedFriendId).get();
      final friendData = friendDoc.data();
      final friendFcmToken = friendData != null ? friendData['fcmToken'] : null;
      final friendDisplayName = friendData != null
          ? (friendData['displayName'] ?? friendData['username'] ?? 'Friend')
          : 'Friend';
      if (friendFcmToken != null && friendFcmToken != '') {
        await _sendFcmDuoInvite(
          friendFcmToken,
          currentUser.displayName ?? currentUser.email ?? 'Someone',
          inviteDocRef.id,
        );
      }
      // Start listening for acceptance on the sender side
      final duoChallengeService =
          DuoChallengeService(navigatorKey: navigatorKey);
      duoChallengeService.listenForInviteAcceptedBySender(
          inviteDocRef.id, friendDisplayName);

      // Navigate to the "Invites Sent" tab instead of going back
      if (mounted && _tabController.index != 2) {
        _tabController.animateTo(2);
      }
    } catch (e) {
      // Error handling without snackbar
    } finally {
      if (mounted) {
        setState(() {
          _isInviting = false;
        });
      }
    }
  }

  Future<void> _sendFcmDuoInvite(
      String fcmToken, String inviterUsername, String inviteId) async {
    const String serverKey =
        'YOUR_SERVER_KEY_HERE'; // Replace with your FCM server key for testing
    final message = {
      'to': fcmToken,
      'notification': {
        'title': 'Duo Challenge Invite',
        'body': '$inviterUsername is inviting you to a Duo Challenge!',
      },
      'data': {
        'type': 'duo_challenge_invite',
        'inviterUsername': inviterUsername,
        'inviteId': inviteId,
      }
    };
    await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: jsonEncode(message),
    );
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
                'You need 50 coins to send a duo challenge invite.',
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
