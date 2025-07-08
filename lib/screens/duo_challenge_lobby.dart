import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DuoChallengeLobby extends StatefulWidget {
  final String inviteId;
  final String? otherUsername;

  const DuoChallengeLobby(
      {Key? key, required this.inviteId, this.otherUsername})
      : super(key: key);

  @override
  State<DuoChallengeLobby> createState() => _DuoChallengeLobbyState();
}

class _DuoChallengeLobbyState extends State<DuoChallengeLobby> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser!.uid;
    _setPresence(true);
  }

  @override
  void dispose() {
    _setPresence(false);
    super.dispose();
  }

  void _setPresence(bool present) async {
    final docRef =
        _firestore.collection('duo_challenge_invites').doc(widget.inviteId);
    await docRef.set({
      'lobbyPresence': {_userId: present}
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final docRef =
        _firestore.collection('duo_challenge_invites').doc(widget.inviteId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duo Challenge Lobby'),
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

          String statusText;
          if (usersPresent >= 2) {
            statusText = "Both users are present! You can start the game.";
          } else {
            statusText = "Waiting for the other player to join the lobby...";
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.groups, size: 80, color: Color(0xFF7C4DFF)),
                const SizedBox(height: 24),
                Text(
                  statusText,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Once both players are ready, the game will start!',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
