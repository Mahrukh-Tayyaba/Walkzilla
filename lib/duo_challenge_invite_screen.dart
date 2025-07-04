import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/friend_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DuoChallengeInviteScreen extends StatefulWidget {
  const DuoChallengeInviteScreen({super.key});

  @override
  State<DuoChallengeInviteScreen> createState() =>
      _DuoChallengeInviteScreenState();
}

class _DuoChallengeInviteScreenState extends State<DuoChallengeInviteScreen> {
  final FriendService _friendService = FriendService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _selectedFriendId;
  bool _isInviting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Invite Friend to Duo Challenge',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a friend to challenge:',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can only invite one friend at a time',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _friendService.getFriends(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF7C4DFF)));
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Error loading friends',
                              style: TextStyle(color: Colors.red)));
                    }
                    final friends = snapshot.data ?? [];
                    if (friends.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.people_outline,
                                size: 60, color: Color(0xFF7C4DFF)),
                            SizedBox(height: 24),
                            Text('No friends yet',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            SizedBox(height: 8),
                            Text(
                                'Add some friends first to start duo challenges!',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final isSelected =
                            _selectedFriendId == friend['userId'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  const Color(0xFF7C4DFF).withOpacity(0.1),
                              backgroundImage:
                                  (friend['profileImage'] != null &&
                                          friend['profileImage'] != '')
                                      ? NetworkImage(friend['profileImage'])
                                      : null,
                              child: (friend['profileImage'] == null ||
                                      friend['profileImage'] == '')
                                  ? Text(
                                      (friend['displayName'] ??
                                                  friend['username'] ??
                                                  '?')
                                              .toString()
                                              .isNotEmpty
                                          ? (friend['displayName'] ??
                                                  friend['username'] ??
                                                  '?')
                                              .toString()[0]
                                              .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF7C4DFF)),
                                    )
                                  : null,
                            ),
                            title: Text(
                                friend['displayName'] ??
                                    friend['username'] ??
                                    'Unknown',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87)),
                            subtitle: Text(
                                '@${friend['username'] ?? 'unknown'}',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey)),
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF7C4DFF)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF7C4DFF)
                                      : const Color(0xFF7C4DFF)
                                          .withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: IconButton(
                                icon: Icon(isSelected ? Icons.check : Icons.add,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF7C4DFF)),
                                onPressed: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedFriendId = null;
                                    } else {
                                      _selectedFriendId = friend['userId'];
                                    }
                                  });
                                },
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedFriendId = null;
                                } else {
                                  _selectedFriendId = friend['userId'];
                                }
                              });
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_selectedFriendId != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isInviting ? null : _sendDuoChallengeInvite,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isInviting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Send Duo Challenge Invite',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
      await _firestore.collection('duo_challenge_invites').add({
        'fromUserId': currentUser.uid,
        'toUserId': _selectedFriendId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'challengeType': 'duo',
        'expiresAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      });
      final friendDoc =
          await _firestore.collection('users').doc(_selectedFriendId).get();
      final friendData = friendDoc.data();
      final friendFcmToken = friendData != null ? friendData['fcmToken'] : null;
      if (friendFcmToken != null && friendFcmToken != '') {
        await _sendFcmDuoInvite(friendFcmToken,
            currentUser.displayName ?? currentUser.email ?? 'Someone');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Duo challenge invite sent successfully!'),
            backgroundColor: Color(0xFF7C4DFF)),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error sending invite: [31m${e.toString()}[0m'),
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
      String fcmToken, String inviterUsername) async {
    const String serverKey =
        'YOUR_SERVER_KEY_HERE'; // Replace with your FCM server key for testing
    final message = {
      'to': fcmToken,
      'notification': {
        'title': 'Duo Challenge Invite',
        'body': 'A0$inviterUsername is inviting you to a Duo Challenge!',
      },
      'data': {
        'type': 'duo_challenge_invite',
        'inviterUsername': inviterUsername,
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
}
