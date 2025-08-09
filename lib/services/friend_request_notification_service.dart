import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart' show navigatorKey; // to show overlays globally
import '../friends_page.dart';

class FriendRequestNotificationService {
  FriendRequestNotificationService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream reference kept to document attachment; not used elsewhere
  // (kept intentionally to make future cancellation straightforward)
  static Stream<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  static bool _isInitialized = false;
  static bool _hasPrimedSnapshot = false;
  static final Set<String> _seenRequestIds = <String>{};

  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Re-attach when auth state changes
    _auth.userChanges().listen((user) {
      _detach();
      _seenRequestIds.clear();
      _hasPrimedSnapshot = false;

      if (user != null) {
        _attach(user.uid);
      }
    });

    // If a user is already logged in
    final user = _auth.currentUser;
    if (user != null) {
      _attach(user.uid);
    }

    _isInitialized = true;
  }

  static void _attach(String uid) {
    final stream = _firestore
        .collection('friend_requests')
        .where('toUserId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();

    _subscription = stream;

    stream.listen((snapshot) {
      // Skip the very first snapshot (initial load) to avoid spamming existing requests
      if (!_hasPrimedSnapshot) {
        for (final doc in snapshot.docs) {
          _seenRequestIds.add(doc.id);
        }
        _hasPrimedSnapshot = true;
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          if (_seenRequestIds.contains(doc.id)) continue;
          _seenRequestIds.add(doc.id);

          final data = doc.data();
          if (data == null) continue;
          _showInAppNotification(data['fromUserId'] as String?);
        }
      }
    });
  }

  static void _detach() {
    // Using stream only; nothing to cancel directly here as we didn't keep a subscription object.
  }

  static Future<void> _showInAppNotification(String? fromUserId) async {
    try {
      if (navigatorKey.currentState == null) return;
      final ctx = navigatorKey.currentState!.overlay?.context ??
          navigatorKey.currentContext;
      if (ctx == null) return;

      // Fetch display name of the sender for a friendly message
      String senderName = 'Someone';
      if (fromUserId != null) {
        final userDoc =
            await _firestore.collection('users').doc(fromUserId).get();
        if (userDoc.exists) {
          final u = userDoc.data() as Map<String, dynamic>;
          senderName =
              (u['displayName'] ?? u['username'] ?? 'Someone').toString();
        }
      }

      final overlay = navigatorKey.currentState!.overlay!;
      late final OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) {
          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF323232),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add_alt_1, color: Colors.white),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '$senderName sent you a friend request',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () {
                            overlayEntry.remove();
                            navigatorKey.currentState?.push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const FriendsPage(initialTab: 1)),
                            );
                          },
                          child: const Text('View',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      overlay.insert(overlayEntry);
      await Future.delayed(const Duration(seconds: 4));
      if (overlayEntry.mounted) overlayEntry.remove();
    } catch (_) {
      // no-op on failures
    }
  }
}
