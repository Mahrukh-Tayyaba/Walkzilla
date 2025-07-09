import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CharacterMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Migrate existing users to have character sprite sheets
  Future<void> migrateExistingUsers() async {
    try {
      print('Starting character migration for existing users...');

      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();
      int migratedCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();

        // Check if user already has characterSpriteSheets
        if (!userData.containsKey('characterSpriteSheets')) {
          // Add default character sprite sheets
          await userDoc.reference.update({
            'characterSpriteSheets': {
              'idle': 'images/character_idle.json',
              'walking': 'images/character_walking.json'
            },
          });
          migratedCount++;
          print('Migrated user: ${userDoc.id}');
        }
      }

      print('Migration completed. $migratedCount users migrated.');
    } catch (e) {
      print('Error during migration: $e');
    }
  }

  /// Migrate current user if needed
  Future<void> migrateCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;

        // Check if user needs migration
        if (!userData.containsKey('characterSpriteSheets')) {
          await userDoc.reference.update({
            'characterSpriteSheets': {
              'idle': 'images/character_idle.json',
              'walking': 'images/character_walking.json'
            },
          });
          print('Migrated current user: ${user.uid}');
        }
      }
    } catch (e) {
      print('Error migrating current user: $e');
    }
  }

  /// Check if current user needs migration
  Future<bool> currentUserNeedsMigration() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return !userData.containsKey('characterSpriteSheets');
      }
      return false;
    } catch (e) {
      print('Error checking migration status: $e');
      return false;
    }
  }
}
