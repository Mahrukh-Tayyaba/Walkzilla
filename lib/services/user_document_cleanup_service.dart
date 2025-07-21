import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDocumentCleanupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Remove unnecessary fields from all existing user documents
  Future<void> cleanupAllUserDocuments() async {
    try {
      print('🧹 Starting cleanup of all user documents...');

      final usersSnapshot = await _firestore.collection('users').get();
      int cleanedCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        try {
          await cleanupUserDocument(userDoc.id);
          cleanedCount++;
        } catch (e) {
          print('❌ Error cleaning up user ${userDoc.id}: $e');
        }
      }

      print('✅ Successfully cleaned up $cleanedCount user documents');
    } catch (e) {
      print('❌ Error in bulk user document cleanup: $e');
    }
  }

  /// Remove unnecessary fields from a specific user document
  Future<void> cleanupUserDocument(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ User document not found: $userId');
        return;
      }

      final userData = userDoc.data()!;
      final fieldsToRemove = <String>[];

      // Check which unnecessary fields exist and need to be removed
      if (userData.containsKey('bestStreak')) fieldsToRemove.add('bestStreak');
      if (userData.containsKey('bio')) fieldsToRemove.add('bio');
      if (userData.containsKey('calories')) fieldsToRemove.add('calories');
      if (userData.containsKey('distance')) fieldsToRemove.add('distance');
      if (userData.containsKey('goalMetDays'))
        fieldsToRemove.add('goalMetDays');
      if (userData.containsKey('monthlyGoal'))
        fieldsToRemove.add('monthlyGoal');
      if (userData.containsKey('monthly_steps'))
        fieldsToRemove.add('monthly_steps');
      if (userData.containsKey('steps')) fieldsToRemove.add('steps');
      if (userData.containsKey('todaySteps')) fieldsToRemove.add('todaySteps');
      if (userData.containsKey('today_steps'))
        fieldsToRemove.add('today_steps');
      if (userData.containsKey('weeklyGoal')) fieldsToRemove.add('weeklyGoal');

      if (fieldsToRemove.isEmpty) {
        print(
            '✅ User $userId already has clean document (no unnecessary fields)');
        return;
      }

      // Create update data with FieldValue.delete() for each field to remove
      final updateData = <String, dynamic>{};
      for (final field in fieldsToRemove) {
        updateData[field] = FieldValue.delete();
      }

      await _firestore.collection('users').doc(userId).update(updateData);
      print(
          '✅ Cleaned up user $userId: removed ${fieldsToRemove.length} fields');
    } catch (e) {
      print('❌ Error cleaning up user document $userId: $e');
    }
  }

  /// Clean up current user's document
  Future<void> cleanupCurrentUserDocument() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      await cleanupUserDocument(user.uid);
    } catch (e) {
      print('❌ Error cleaning up current user document: $e');
    }
  }

  /// Check if current user's document needs cleanup
  Future<bool> currentUserNeedsCleanup() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;

      // Check if any unnecessary fields exist
      return userData.containsKey('bestStreak') ||
          userData.containsKey('bio') ||
          userData.containsKey('calories') ||
          userData.containsKey('distance') ||
          userData.containsKey('goalMetDays') ||
          userData.containsKey('monthlyGoal') ||
          userData.containsKey('monthly_steps') ||
          userData.containsKey('steps') ||
          userData.containsKey('todaySteps') ||
          userData.containsKey('today_steps') ||
          userData.containsKey('weeklyGoal');
    } catch (e) {
      print('❌ Error checking cleanup status: $e');
      return false;
    }
  }
}
