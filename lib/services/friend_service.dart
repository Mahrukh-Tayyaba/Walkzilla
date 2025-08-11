import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Search users by username
  Future<List<Map<String, dynamic>>> searchUsersByUsername(
      String username) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      // Normalize the search term
      final searchTerm = username.toLowerCase().trim();

      // Search for users whose username contains the search term
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: searchTerm)
          .where('username', isLessThan: '$searchTerm\uf8ff')
          .limit(10)
          .get();

      final users = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        // Don't include the current user in search results
        if (doc.id != currentUser.uid) {
          final userData = doc.data();
          users.add({
            'userId': doc.id,
            'username': userData['username'] ?? '',
            'displayName':
                userData['displayName'] ?? userData['username'] ?? '',
            'profileImage': userData['profileImage'] ?? userData['photoURL'],
            'level': userData['level'] ?? 1,
            'currentStreak': userData['currentStreak'] ?? 0,
            'lastActive': userData['lastActive'],
          });
        }
      }

      return users;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Send friend request
  Future<bool> sendFriendRequest(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check if request already exists
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('toUserId', isEqualTo: targetUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        return false; // Request already sent
      }

      // Check if they are already friends
      final existingFriendship = await _firestore
          .collection('friendships')
          .where('users', arrayContains: currentUser.uid)
          .get();

      for (final doc in existingFriendship.docs) {
        final users = List<String>.from(doc.data()['users'] ?? []);
        if (users.contains(targetUserId)) {
          return false; // Already friends
        }
      }

      // Create friend request
      await _firestore.collection('friend_requests').add({
        'fromUserId': currentUser.uid,
        'toUserId': targetUserId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error sending friend request: $e');
      return false;
    }
  }

  // Accept friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Get the request
      final requestDoc =
          await _firestore.collection('friend_requests').doc(requestId).get();

      if (!requestDoc.exists) return false;

      final requestData = requestDoc.data()!;
      final fromUserId = requestData['fromUserId'] as String;
      final toUserId = requestData['toUserId'] as String;

      // Verify the current user is the recipient
      if (toUserId != currentUser.uid) return false;

      // Update request status
      await requestDoc.reference.update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Create friendship
      await _firestore.collection('friendships').add({
        'users': [fromUserId, toUserId],
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error accepting friend request: $e');
      return false;
    }
  }

  // Decline friend request
  Future<bool> declineFriendRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Get the request
      final requestDoc =
          await _firestore.collection('friend_requests').doc(requestId).get();

      if (!requestDoc.exists) return false;

      final requestData = requestDoc.data()!;
      final toUserId = requestData['toUserId'] as String;

      // Verify the current user is the recipient
      if (toUserId != currentUser.uid) return false;

      // Update request status
      await requestDoc.reference.update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error declining friend request: $e');
      return false;
    }
  }

  // Cancel sent friend request
  Future<bool> cancelFriendRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Get the request
      final requestDoc =
          await _firestore.collection('friend_requests').doc(requestId).get();

      if (!requestDoc.exists) return false;

      final requestData = requestDoc.data()!;
      final fromUserId = requestData['fromUserId'] as String;

      // Verify the current user is the sender
      if (fromUserId != currentUser.uid) return false;

      // Delete the request
      await requestDoc.reference.delete();

      return true;
    } catch (e) {
      print('Error canceling friend request: $e');
      return false;
    }
  }

  // Get friend requests received by current user
  Stream<List<Map<String, dynamic>>> getFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('friend_requests')
        .where('toUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final requests = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final requestData = doc.data();
        final fromUserId = requestData['fromUserId'] as String;

        // Get user data
        final userDoc =
            await _firestore.collection('users').doc(fromUserId).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          requests.add({
            'requestId': doc.id,
            'userId': fromUserId,
            'username': userData['username'] ?? '',
            'displayName':
                userData['displayName'] ?? userData['username'] ?? '',
            'profileImage': userData['profileImage'] ?? userData['photoURL'],
            'level': userData['level'] ?? 1,
            'currentStreak': userData['currentStreak'] ?? 0,
            'createdAt': requestData['createdAt'],
          });
        }
      }

      return requests;
    });
  }

  // Get friend requests sent by current user
  Stream<List<Map<String, dynamic>>> getSentFriendRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final requests = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final requestData = doc.data();
        final toUserId = requestData['toUserId'] as String;

        // Get user data
        final userDoc =
            await _firestore.collection('users').doc(toUserId).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          requests.add({
            'requestId': doc.id,
            'userId': toUserId,
            'username': userData['username'] ?? '',
            'displayName':
                userData['displayName'] ?? userData['username'] ?? '',
            'profileImage': userData['profileImage'] ?? userData['photoURL'],
            'createdAt': requestData['createdAt'],
          });
        }
      }

      return requests;
    });
  }

  // Get current user's friends
  Stream<List<Map<String, dynamic>>> getFriends() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('friendships')
        .where('users', arrayContains: currentUser.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final friends = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final friendshipData = doc.data();
        final users = List<String>.from(friendshipData['users'] ?? []);

        // Get the other user's ID safely
        final others = users.where((id) => id != currentUser.uid).toList();
        if (others.isEmpty) {
          continue;
        }
        final otherUserId = others.first;

        // Get user data
        final userDoc =
            await _firestore.collection('users').doc(otherUserId).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          friends.add({
            'userId': otherUserId,
            'username': userData['username'] ?? '',
            'displayName':
                userData['displayName'] ?? userData['username'] ?? '',
            'profileImage': userData['profileImage'] ?? userData['photoURL'],
            'level': userData['level'] ?? 1,
            'currentStreak': userData['currentStreak'] ?? 0,
            'lastActive': userData['lastActive'],
            'todaySteps': userData['todaySteps'] ?? 0,
            'steps': userData['steps'] ?? 0,
          });
        }
      }

      return friends;
    });
  }

  // Remove friend
  Future<bool> removeFriend(String friendUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Create a more specific query to find the exact friendship
      final friendshipQuery = await _firestore
          .collection('friendships')
          .where('users', arrayContains: currentUser.uid)
          .where('users', arrayContains: friendUserId)
          .limit(1)
          .get();

      if (friendshipQuery.docs.isNotEmpty) {
        await friendshipQuery.docs.first.reference.delete();
        return true;
      }

      return false;
    } catch (e) {
      print('Error removing friend: $e');
      return false;
    }
  }

  // Get suggested users (users who are not friends and not already requested)
  Future<List<Map<String, dynamic>>> getSuggestedUsers() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      // Get current user's friends
      final friendshipsQuery = await _firestore
          .collection('friendships')
          .where('users', arrayContains: currentUser.uid)
          .get();

      final friendUserIds = <String>{};
      for (final doc in friendshipsQuery.docs) {
        final users = List<String>.from(doc.data()['users'] ?? []);
        friendUserIds.addAll(users.where((id) => id != currentUser.uid));
      }

      // Get users with pending requests (sent by current user)
      final sentRequestsQuery = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      final requestedUserIds = <String>{};
      for (final doc in sentRequestsQuery.docs) {
        requestedUserIds.add(doc.data()['toUserId'] as String);
      }

      // Get all users, excluding friends, requested users, and current user
      final allUsersQuery = await _firestore
          .collection('users')
          .orderBy('lastActive', descending: true)
          .limit(20)
          .get();

      final suggestedUsers = <Map<String, dynamic>>[];

      for (final doc in allUsersQuery.docs) {
        final userId = doc.id;

        // Skip if it's the current user, a friend, or already requested
        if (userId == currentUser.uid ||
            friendUserIds.contains(userId) ||
            requestedUserIds.contains(userId)) {
          continue;
        }

        final userData = doc.data();
        suggestedUsers.add({
          'userId': userId,
          'username': userData['username'] ?? '',
          'displayName': userData['displayName'] ?? userData['username'] ?? '',
          'profileImage': userData['profileImage'] ?? userData['photoURL'],
          'level': userData['level'] ?? 1,
          'currentStreak': userData['currentStreak'] ?? 0,
          'lastActive': userData['lastActive'],
        });
      }

      return suggestedUsers;
    } catch (e) {
      print('Error getting suggested users: $e');
      return [];
    }
  }
}
