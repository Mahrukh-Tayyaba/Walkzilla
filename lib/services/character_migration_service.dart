import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'character_data_service.dart';

class CharacterMigrationService {
  static final CharacterMigrationService _instance =
      CharacterMigrationService._internal();
  factory CharacterMigrationService() => _instance;
  CharacterMigrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CharacterDataService _characterDataService = CharacterDataService();

  /// Migrate current user's character data to new structure
  Future<bool> migrateCurrentUserCharacterData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final updates = <String, dynamic>{};

      // Check if user needs migration
      if (!userData.containsKey('owned_items')) {
        // Migrate from old 'ownedItems' field or set default
        final oldOwnedItems = userData['ownedItems'] as List<dynamic>?;
        updates['owned_items'] = oldOwnedItems != null
            ? List<String>.from(oldOwnedItems)
            : ['MyCharacter'];
      }

      if (!userData.containsKey('currentCharacter')) {
        // Migrate from old 'wornItem' field or set default
        final oldWornItem = userData['wornItem'] as String?;
        final currentCharacter = oldWornItem ?? 'MyCharacter';
        updates['currentCharacter'] = currentCharacter;

        // Update homeGlbPath and spriteSheets based on current character
        updates['homeGlbPath'] =
            _characterDataService.getHomeGlbPathForCharacter(currentCharacter);
        updates['spriteSheets'] =
            _characterDataService.getSpriteSheetsForCharacter(currentCharacter);
      }

      if (!userData.containsKey('homeGlbPath')) {
        final currentCharacter = userData['currentCharacter'] ?? 'MyCharacter';
        updates['homeGlbPath'] =
            _characterDataService.getHomeGlbPathForCharacter(currentCharacter);
      }

      if (!userData.containsKey('spriteSheets')) {
        final currentCharacter = userData['currentCharacter'] ?? 'MyCharacter';
        updates['spriteSheets'] =
            _characterDataService.getSpriteSheetsForCharacter(currentCharacter);
      }

      // Apply updates if needed
      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(updates);
        print('✅ Migrated character data for user: ${user.uid}');
        print('📝 Applied updates: ${updates.keys.join(', ')}');

        // Clean up old fields after successful migration
        await cleanupOldFields();
        return true;
      } else {
        print(
            'ℹ️ User ${user.uid} already has updated character data structure');

        // Still clean up old fields even if no migration was needed
        await cleanupOldFields();
        return true;
      }
    } catch (e) {
      print('❌ Error migrating character data: $e');
      return false;
    }
  }

  /// Migrate all users in the database (admin function)
  Future<void> migrateAllUsersCharacterData() async {
    try {
      print('🔄 Starting migration for all users...');

      final usersSnapshot = await _firestore.collection('users').get();
      int migratedCount = 0;
      int errorCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final updates = <String, dynamic>{};

          // Check if user needs migration
          if (!userData.containsKey('owned_items')) {
            final oldOwnedItems = userData['ownedItems'] as List<dynamic>?;
            updates['owned_items'] = oldOwnedItems != null
                ? List<String>.from(oldOwnedItems)
                : ['MyCharacter'];
          }

          if (!userData.containsKey('currentCharacter')) {
            final oldWornItem = userData['wornItem'] as String?;
            final currentCharacter = oldWornItem ?? 'MyCharacter';
            updates['currentCharacter'] = currentCharacter;

            updates['homeGlbPath'] = _characterDataService
                .getHomeGlbPathForCharacter(currentCharacter);
            updates['spriteSheets'] = _characterDataService
                .getSpriteSheetsForCharacter(currentCharacter);
          }

          if (!userData.containsKey('homeGlbPath')) {
            final currentCharacter =
                userData['currentCharacter'] ?? 'MyCharacter';
            updates['homeGlbPath'] = _characterDataService
                .getHomeGlbPathForCharacter(currentCharacter);
          }

          if (!userData.containsKey('spriteSheets')) {
            final currentCharacter =
                userData['currentCharacter'] ?? 'MyCharacter';
            updates['spriteSheets'] = _characterDataService
                .getSpriteSheetsForCharacter(currentCharacter);
          }

          if (updates.isNotEmpty) {
            await _firestore
                .collection('users')
                .doc(userDoc.id)
                .update(updates);
            migratedCount++;
            print('✅ Migrated user: ${userDoc.id}');
          }
        } catch (e) {
          errorCount++;
          print('❌ Error migrating user ${userDoc.id}: $e');
        }
      }

      print('🎉 Migration completed!');
      print('✅ Successfully migrated: $migratedCount users');
      print('❌ Errors: $errorCount users');
    } catch (e) {
      print('❌ Error during bulk migration: $e');
    }
  }

  /// Check if current user needs migration
  Future<bool> needsMigration() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;

      // Check if any of the new fields are missing
      return !userData.containsKey('owned_items') ||
          !userData.containsKey('currentCharacter') ||
          !userData.containsKey('homeGlbPath') ||
          !userData.containsKey('spriteSheets');
    } catch (e) {
      print('❌ Error checking migration status: $e');
      return false;
    }
  }

  /// Force update user to new structure (for testing)
  Future<bool> forceUpdateUserToNewStructure(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'owned_items': ['MyCharacter'],
        'currentCharacter': 'MyCharacter',
        'homeGlbPath':
            _characterDataService.getHomeGlbPathForCharacter('MyCharacter'),
        'spriteSheets':
            _characterDataService.getSpriteSheetsForCharacter('MyCharacter'),
      });

      print('✅ Force updated user $userId to new structure');
      return true;
    } catch (e) {
      print('❌ Error force updating user: $e');
      return false;
    }
  }

  /// Clean up old fields after migration
  Future<bool> cleanupOldFields() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final fieldsToRemove = <String>[];

      // Check for old fields that can be removed
      if (userData.containsKey('ownedItems')) {
        fieldsToRemove.add('ownedItems');
      }
      if (userData.containsKey('wornItem')) {
        fieldsToRemove.add('wornItem');
      }
      if (userData.containsKey('characterSpriteSheets')) {
        fieldsToRemove.add('characterSpriteSheets');
      }
      if (userData.containsKey('ownedShopItems')) {
        fieldsToRemove.add('ownedShopItems');
      }

      if (fieldsToRemove.isNotEmpty) {
        final updates = <String, dynamic>{};
        for (final field in fieldsToRemove) {
          updates[field] = FieldValue.delete();
        }

        await _firestore.collection('users').doc(user.uid).update(updates);
        print('✅ Cleaned up old fields: ${fieldsToRemove.join(', ')}');
        return true;
      }

      return true;
    } catch (e) {
      print('❌ Error cleaning up old fields: $e');
      return false;
    }
  }
}
