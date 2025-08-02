import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/character_migration_service.dart';

/// Test script to verify field cleanup
class CleanupTest {
  static final CharacterMigrationService _migrationService =
      CharacterMigrationService();

  /// Test the cleanup process
  static Future<void> testCleanup() async {
    print('🧹 Testing Field Cleanup Process...\n');

    try {
      // 1. Check current user document structure
      print('1. Checking current user document structure...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        print('❌ User document does not exist');
        return;
      }

      final userData = userDoc.data()!;
      print('Current fields in user document:');
      userData.forEach((key, value) {
        print('  - $key: $value');
      });

      // 2. Check for old fields
      print('\n2. Checking for old fields...');
      final oldFields = <String>[];
      if (userData.containsKey('characterSpriteSheets')) {
        oldFields.add('characterSpriteSheets');
      }
      if (userData.containsKey('ownedItems')) {
        oldFields.add('ownedItems');
      }
      if (userData.containsKey('ownedShopItems')) {
        oldFields.add('ownedShopItems');
      }
      if (userData.containsKey('wornItem')) {
        oldFields.add('wornItem');
      }

      if (oldFields.isEmpty) {
        print('✅ No old fields found - cleanup not needed');
      } else {
        print('⚠️ Found old fields: ${oldFields.join(', ')}');

        // 3. Run cleanup
        print('\n3. Running cleanup...');
        final success = await _migrationService.cleanupOldFields();
        print('Cleanup success: $success');

        // 4. Verify cleanup
        print('\n4. Verifying cleanup...');
        final updatedDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final updatedData = updatedDoc.data()!;
        print('Updated fields in user document:');
        updatedData.forEach((key, value) {
          print('  - $key: $value');
        });

        // Check if old fields are gone
        final remainingOldFields = <String>[];
        for (final field in oldFields) {
          if (updatedData.containsKey(field)) {
            remainingOldFields.add(field);
          }
        }

        if (remainingOldFields.isEmpty) {
          print('✅ SUCCESS: All old fields have been cleaned up!');
        } else {
          print(
              '❌ FAILED: Some old fields remain: ${remainingOldFields.join(', ')}');
        }
      }
    } catch (error) {
      print('❌ Error during cleanup test: $error');
    }
  }

  /// Test migration and cleanup together
  static Future<void> testMigrationAndCleanup() async {
    print('🔄 Testing Migration and Cleanup Together...\n');

    try {
      // Run migration (which includes cleanup)
      final success = await _migrationService.migrateCurrentUserCharacterData();
      print('Migration and cleanup completed: $success');

      // Verify final state
      await testCleanup();
    } catch (error) {
      print('❌ Error during migration and cleanup test: $error');
    }
  }
}
