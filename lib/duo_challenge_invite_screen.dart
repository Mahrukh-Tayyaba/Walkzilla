import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/friend_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/duo_challenge_service.dart';
import 'main.dart';
import 'screens/duo_challenge_lobby.dart';

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
      appBar: AppBar(
        title: const Text('Invite Friend to Duo Challenge',
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
                if (!userSnapshot.hasData) {
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
                    if (inviteSnapshot.hasData) {
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
                if (!userSnapshot.hasData) {
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
                            await _firestore
                                .collection('duo_challenge_invites')
                                .doc(doc.id)
                                .update({
                              'status': 'accepted',
                              'acceptedAt': FieldValue.serverTimestamp(),
                            });
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
          .collection('duo_challenge_invites')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
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
        final invites = snapshot.data?.docs ?? [];
        if (invites.isEmpty) {
          return const Center(child: Text('No invites sent yet.'));
        }
        return ListView.builder(
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final doc = invites[index];
            final data = doc.data() as Map<String, dynamic>;
            return FutureBuilder<DocumentSnapshot>(
              future:
                  _firestore.collection('users').doc(data['toUserId']).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const ListTile(title: Text('Loading...'));
                }
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();
                String statusText = '';
                if (data['status'] == 'pending') {
                  statusText = 'Pending';
                } else if (data['status'] == 'accepted') {
                  statusText = 'Accepted';
                } else if (data['status'] == 'declined') {
                  statusText = 'Declined';
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
                              style: TextStyle(
                                color: data['status'] == 'pending'
                                    ? Colors.orange
                                    : (data['status'] == 'accepted'
                                        ? Colors.green
                                        : Colors.red),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (data['status'] == 'accepted') ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              DuoChallengeLobby(
                                            inviteId: doc.id,
                                            otherUsername:
                                                userData['displayName'] ??
                                                    userData['username'] ??
                                                    'Friend',
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7C4DFF),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Start'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextButton(
                                    onPressed: () async {
                                      await doc.reference
                                          .update({'status': 'declined'});
                                    },
                                    style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Cancel',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Duo challenge invite sent successfully!'),
            backgroundColor: Color(0xFF7C4DFF)),
      );
      // Navigate to the "Invites Sent" tab instead of going back
      if (mounted && _tabController.index != 2) {
        _tabController.animateTo(2);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error sending invite:  [31m${e.toString()} [0m'),
            backgroundColor: Colors.red),
      );
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
}
