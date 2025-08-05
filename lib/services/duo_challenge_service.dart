import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/duo_challenge_invite_dialog.dart';
import '../screens/duo_challenge_lobby.dart';

class DuoChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot>? _inviteSubscription;
  StreamSubscription<DocumentSnapshot>? _senderInviteSubscription;
  final GlobalKey<NavigatorState> navigatorKey;

  DuoChallengeService({required this.navigatorKey});

  /// Start listening for pending duo challenge invites for the current user
  void startListeningForInvites() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('[DuoChallengeService] No current user for listener');
      return;
    }
    print(
        '[DuoChallengeService] Listening for invites for UID: \\${currentUser.uid}');

    // Stop any existing subscription
    _inviteSubscription?.cancel();

    // Listen for pending invites where the current user is the recipient
    _inviteSubscription = _firestore
        .collection('duo_challenge_invites')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      print(
          '[DuoChallengeService] duo_challenge_invites snapshot received: \\${snapshot.docs.length}');
      for (final change in snapshot.docChanges) {
        print(
            '[DuoChallengeService] Change type: \\${change.type}, doc: \\${change.doc.id}');
        if (change.type == DocumentChangeType.added) {
          _handleNewInvite(change.doc);
        }
      }
    }, onError: (error) {
      print(
          '[DuoChallengeService] Error listening for duo challenge invites: $error');
    });
  }

  /// Stop listening for invites
  void stopListeningForInvites() {
    _inviteSubscription?.cancel();
    _inviteSubscription = null;
  }

  /// Handle a new invite by showing the dialog
  void _handleNewInvite(DocumentSnapshot inviteDoc) async {
    print('[DuoChallengeService] Handling new invite: \\${inviteDoc.id}');
    try {
      final inviteData = inviteDoc.data() as Map<String, dynamic>;
      final fromUserId = inviteData['fromUserId'] as String;
      final inviteId = inviteDoc.id;

      // Get the inviter's username
      final inviterDoc =
          await _firestore.collection('users').doc(fromUserId).get();
      String inviterUsername = 'Someone';

      if (inviterDoc.exists) {
        final inviterData = inviterDoc.data() as Map<String, dynamic>;
        inviterUsername =
            inviterData['displayName'] ?? inviterData['username'] ?? 'Someone';
      }

      // Show the invite dialog
      _showInviteDialog(inviterUsername, inviteId);
    } catch (e) {
      print('[DuoChallengeService] Error handling new invite: $e');
    }
  }

  /// Show the invite dialog using the global navigator key
  void _showInviteDialog(String inviterUsername, String inviteId) {
    print(
        '[DuoChallengeService] Attempting to show invite dialog for $inviterUsername, $inviteId');
    if (navigatorKey.currentContext != null) {
      // Add a small delay to ensure the UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (navigatorKey.currentContext != null) {
          print(
              '[DuoChallengeService] Showing invite dialog for $inviterUsername, $inviteId');
          showDialog(
            context: navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (context) => DuoChallengeInviteDialog(
              inviterUsername: inviterUsername,
              inviteId: inviteId,
            ),
          );
        } else {
          print(
              '[DuoChallengeService] navigatorKey.currentContext is null in delayed dialog');
        }
      });
    } else {
      print('[DuoChallengeService] navigatorKey.currentContext is null');
    }
  }

  /// Check for existing pending invites when user logs in
  Future<void> checkForExistingInvites() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print(
          '[DuoChallengeService] No current user for checkForExistingInvites');
      return;
    }
    print(
        '[DuoChallengeService] Checking for existing invites for UID: \\${currentUser.uid}');

    try {
      final pendingInvites = await _firestore
          .collection('duo_challenge_invites')
          .where('toUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      print(
          '[DuoChallengeService] Manual fetch invites: \\${pendingInvites.docs.length}');
      if (pendingInvites.docs.isNotEmpty) {
        // Show the most recent pending invite
        final latestInvite = pendingInvites.docs.first;
        final inviteData = latestInvite.data();
        final fromUserId = inviteData['fromUserId'] as String;
        final inviteId = latestInvite.id;

        // Get the inviter's username
        final inviterDoc =
            await _firestore.collection('users').doc(fromUserId).get();
        String inviterUsername = 'Someone';

        if (inviterDoc.exists) {
          final inviterData = inviterDoc.data() as Map<String, dynamic>;
          inviterUsername = inviterData['displayName'] ??
              inviterData['username'] ??
              'Someone';
        }

        // Show the invite dialog
        _showInviteDialog(inviterUsername, inviteId);
      }
    } catch (e) {
      print('[DuoChallengeService] Error checking for existing invites: $e');
    }
  }

  void listenForInviteAcceptedBySender(String inviteId, String toUsername) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    // Cancel previous subscription if any
    _senderInviteSubscription?.cancel();
    _senderInviteSubscription = _firestore
        .collection('duo_challenge_invites')
        .doc(inviteId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'accepted' && data['senderNotified'] != true) {
        // Mark as notified immediately to prevent duplicate popups
        doc.reference.update({'senderNotified': true});

        // Show dialog to sender
        if (navigatorKey.currentContext != null) {
          showDialog(
            context: navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Duo Challenge Accepted'),
              content: Text('$toUsername accepted the duo challenge request!'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _senderInviteSubscription?.cancel();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _senderInviteSubscription?.cancel();
                    // Navigate to lobby
                    Navigator.of(navigatorKey.currentContext!).push(
                      MaterialPageRoute(
                        builder: (context) => DuoChallengeLobby(
                          inviteId: inviteId,
                          otherUsername: toUsername,
                        ),
                      ),
                    );
                  },
                  child: const Text('Start the Game'),
                ),
              ],
            ),
          );
        }
      }
    });
  }
}
