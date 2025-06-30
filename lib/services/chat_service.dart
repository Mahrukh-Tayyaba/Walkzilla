import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get or create a chat between two users
  Future<String> getOrCreateChat(String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    // Create a unique chat ID by sorting user IDs
    final List<String> userIds = [currentUser.uid, otherUserId];
    userIds.sort();
    final chatId = userIds.join('_');

    // Check if chat already exists
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      // Create new chat
      await _firestore.collection('chats').doc(chatId).set({
        'participants': userIds,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageTime': null,
        'unreadCount': {
          currentUser.uid: 0,
          otherUserId: 0,
        },
      });
    }

    return chatId;
  }

  // Send a message
  Future<void> sendMessage(String chatId, String message) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final messageData = {
      'senderId': currentUser.uid,
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    // Add message to chat
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // Update chat metadata
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount.${currentUser.uid}': 0, // Reset sender's unread count
    });

    // Increment unread count for other participants
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (chatDoc.exists) {
      final chatData = chatDoc.data()!;
      final participants = List<String>.from(chatData['participants'] ?? []);

      for (final participantId in participants) {
        if (participantId != currentUser.uid) {
          await _firestore.collection('chats').doc(chatId).update({
            'unreadCount.$participantId': FieldValue.increment(1),
          });
        }
      }
    }
  }

  // Get messages for a chat
  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'text': data['text'] ?? '',
          'timestamp': data['timestamp'],
          'isMe': data['senderId'] == currentUser.uid,
          'isRead': data['isRead'] ?? false,
        };
      }).toList();
    });
  }

  // Get user's chats list
  Stream<List<Map<String, dynamic>>> getUserChats() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final chats = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final chatData = doc.data();
        final participants = List<String>.from(chatData['participants'] ?? []);

        // Get the other user's ID
        final otherUserId =
            participants.firstWhere((id) => id != currentUser.uid);

        // Get other user's data
        final userDoc =
            await _firestore.collection('users').doc(otherUserId).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final unreadCount = (chatData['unreadCount']
                  as Map<String, dynamic>?)?[currentUser.uid] ??
              0;

          chats.add({
            'chatId': doc.id,
            'name':
                userData['displayName'] ?? userData['username'] ?? 'Unknown',
            'avatar': userData['profileImage'] ?? userData['photoURL'] ?? '',
            'lastMessage': chatData['lastMessage'] ?? '',
            'lastMessageTime': chatData['lastMessageTime'],
            'unread': unreadCount,
            'online': userData['isOnline'] ?? false,
            'otherUserId': otherUserId,
          });
        }
      }

      return chats;
    });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Reset unread count for current user
    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount.${currentUser.uid}': 0,
    });

    // Mark unread messages as read
    final unreadMessages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Delete a chat
  Future<void> deleteChat(String chatId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Check if user is participant
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return;

    final participants =
        List<String>.from(chatDoc.data()!['participants'] ?? []);
    if (!participants.contains(currentUser.uid)) return;

    // Delete all messages
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // Delete chat document
    batch.delete(_firestore.collection('chats').doc(chatId));

    await batch.commit();
  }

  // Get chat by participants
  Future<String?> getChatByParticipants(String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    final List<String> userIds = [currentUser.uid, otherUserId];
    userIds.sort();
    final chatId = userIds.join('_');

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    return chatDoc.exists ? chatId : null;
  }
}
