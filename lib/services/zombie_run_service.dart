import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/zombie_run_invite_dialog.dart';
import '../screens/zombie_run_lobby.dart';
import '../services/fcm_notification_service.dart';

class ZombieRunService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot>? _inviteSubscription;
  StreamSubscription<DocumentSnapshot>? _senderInviteSubscription;
  final GlobalKey<NavigatorState> navigatorKey;

  ZombieRunService({required this.navigatorKey});

  /// Initialize the service and set up FCM callback
  void initialize() {
    // Set up FCM callback for zombie run invites
    FCMNotificationService.setZombieRunInviteCallback(_handleFCMInvite);
  }

  /// Handle FCM-triggered zombie run invite
  void _handleFCMInvite(Map<String, dynamic> data) {
    print('[ZombieRunService] FCM invite received: $data');
    
    final String? inviteId = data['inviteId'];
    final String? inviterUsername = data['inviterUsername'];
    
    if (inviteId != null && inviterUsername != null) {
      // Show the invite dialog immediately
      _showInviteDialog(inviterUsername, inviteId);
    }
  }

  /// Start listening for pending zombie run challenge invites for the current user
  void startListeningForInvites() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('[ZombieRunService] No current user for listener');
      return;
    }
    print(
        '[ZombieRunService] Listening for invites for UID: ${currentUser.uid}');

    // Stop any existing subscription
    _inviteSubscription?.cancel();

    // Listen for pending invites where the current user is the recipient
    _inviteSubscription = _firestore
        .collection('zombie_run_challenge_invites')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      print(
          '[ZombieRunService] zombie_run_challenge_invites snapshot received: ${snapshot.docs.length}');
      for (final change in snapshot.docChanges) {
        print(
            '[ZombieRunService] Change type: ${change.type}, doc: ${change.doc.id}');
        if (change.type == DocumentChangeType.added) {
          _handleNewInvite(change.doc);
        }
      }
    }, onError: (error) {
      print(
          '[ZombieRunService] Error listening for zombie run challenge invites: $error');
    });
  }

  /// Stop listening for invites
  void stopListeningForInvites() {
    _inviteSubscription?.cancel();
    _inviteSubscription = null;
  }

  /// Handle a new invite by showing the dialog
  void _handleNewInvite(DocumentSnapshot inviteDoc) async {
    print('[ZombieRunService] Handling new invite: ${inviteDoc.id}');
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
      print('[ZombieRunService] Error handling new invite: $e');
    }
  }

  /// Show the invite dialog using the global navigator key
  void _showInviteDialog(String inviterUsername, String inviteId) {
    print(
        '[ZombieRunService] Attempting to show invite dialog for $inviterUsername, $inviteId');
    if (navigatorKey.currentContext != null) {
      // Add a small delay to ensure the UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (navigatorKey.currentContext != null) {
          print(
              '[ZombieRunService] Showing invite dialog for $inviterUsername, $inviteId');
          showDialog(
            context: navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (context) => ZombieRunInviteDialog(
              inviterUsername: inviterUsername,
              inviteId: inviteId,
            ),
          );
        }
      });
    }
  }

  /// Listen for invite acceptance by the sender
  void listenForInviteAcceptedBySender(
      String inviteId, String friendDisplayName) {
    print('[ZombieRunService] Listening for invite acceptance: $inviteId');

    // Stop any existing subscription
    _senderInviteSubscription?.cancel();

    _senderInviteSubscription = _firestore
        .collection('zombie_run_challenge_invites')
        .doc(inviteId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status == 'accepted' && navigatorKey.currentContext != null) {
        print('[ZombieRunService] Invite accepted, navigating to lobby');
        // Navigate to the lobby
        Navigator.of(navigatorKey.currentContext!).push(
          MaterialPageRoute(
            builder: (context) => ZombieRunLobby(
              inviteId: inviteId,
              otherUsername: friendDisplayName,
            ),
          ),
        );
        // Stop listening after navigation
        _senderInviteSubscription?.cancel();
      }
    }, onError: (error) {
      print('[ZombieRunService] Error listening for invite acceptance: $error');
    });
  }

  /// Stop listening for invite acceptance
  void stopListeningForInviteAcceptance() {
    _senderInviteSubscription?.cancel();
    _senderInviteSubscription = null;
  }

  /// Check for existing pending invites when user logs in
  Future<void> checkForExistingInvites() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('[ZombieRunService] No current user for checkForExistingInvites');
      return;
    }
    print(
        '[ZombieRunService] Checking for existing invites for UID: ${currentUser.uid}');

    try {
      final pendingInvites = await _firestore
          .collection('zombie_run_challenge_invites')
          .where('toUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      print(
          '[ZombieRunService] Manual fetch invites: ${pendingInvites.docs.length}');
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
      print('[ZombieRunService] Error checking for existing invites: $e');
    }
  }
}
