import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDeletionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Delete user account and all associated data
  Future<bool> deleteUserAccount() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No user logged in');
        return false;
      }

      final userId = currentUser.uid;
      print('Starting account deletion for user: $userId');

      // Get user data before deletion for cleanup
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final username =
          userDoc.data()?['username']?.toString().toLowerCase() ?? '';

      // Start a batch for all Firestore operations
      final batch = _firestore.batch();

      // 1. Delete all friend requests where user is sender or recipient
      await _deleteFriendRequests(userId, batch);

      // 2. Delete all friendships involving the user
      await _deleteFriendships(userId, batch);

      // 3. Delete all chats and messages involving the user
      await _deleteChatsAndMessages(userId, batch);

      // 4. Delete username reservation
      if (username.isNotEmpty) {
        final usernameDoc = _firestore.collection('usernames').doc(username);
        batch.delete(usernameDoc);
      }

      // 5. Delete user document
      final userDocument = _firestore.collection('users').doc(userId);
      batch.delete(userDocument);

      // Commit all Firestore deletions
      await batch.commit();
      print('Firestore data deleted successfully');

      // 6. Delete Firebase Auth account
      await currentUser.delete();
      print('Firebase Auth account deleted successfully');

      return true;
    } catch (e) {
      print('Error deleting user account: $e');
      return false;
    }
  }

  /// Delete all friend requests involving the user
  Future<void> _deleteFriendRequests(String userId, WriteBatch batch) async {
    try {
      // Delete friend requests where user is sender
      final sentRequests = await _firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: userId)
          .get();

      for (final doc in sentRequests.docs) {
        batch.delete(doc.reference);
      }

      // Delete friend requests where user is recipient
      final receivedRequests = await _firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: userId)
          .get();

      for (final doc in receivedRequests.docs) {
        batch.delete(doc.reference);
      }

      print(
          'Deleted ${sentRequests.docs.length + receivedRequests.docs.length} friend requests');
    } catch (e) {
      print('Error deleting friend requests: $e');
    }
  }

  /// Delete all friendships involving the user
  Future<void> _deleteFriendships(String userId, WriteBatch batch) async {
    try {
      final friendships = await _firestore
          .collection('friendships')
          .where('users', arrayContains: userId)
          .get();

      for (final doc in friendships.docs) {
        batch.delete(doc.reference);
      }

      print('Deleted ${friendships.docs.length} friendships');
    } catch (e) {
      print('Error deleting friendships: $e');
    }
  }

  /// Delete all chats and messages involving the user
  Future<void> _deleteChatsAndMessages(String userId, WriteBatch batch) async {
    try {
      final chats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      for (final chatDoc in chats.docs) {
        // Delete all messages in the chat
        final messages = await chatDoc.reference.collection('messages').get();
        for (final messageDoc in messages.docs) {
          batch.delete(messageDoc.reference);
        }

        // Delete the chat document
        batch.delete(chatDoc.reference);
      }

      print('Deleted ${chats.docs.length} chats and their messages');
    } catch (e) {
      print('Error deleting chats and messages: $e');
    }
  }

  /// Check if user can be deleted (for Google/Apple sign-in users)
  Future<bool> canDeleteAccount() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // For Google/Apple sign-in users, we need to re-authenticate first
      // This is a simplified check - in practice, you might want to show
      // a re-authentication dialog for these users
      final providers = currentUser.providerData;
      final hasPasswordProvider =
          providers.any((provider) => provider.providerId == 'password');

      return hasPasswordProvider;
    } catch (e) {
      print('Error checking if account can be deleted: $e');
      return false;
    }
  }
}
