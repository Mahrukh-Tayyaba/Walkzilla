import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/character_migration_service.dart';
import 'services/character_data_service.dart';
import 'services/shop_service.dart'; // Added import for ShopService

/// Test script to verify character migration
class CharacterMigrationTest {
  static final CharacterMigrationService _migrationService =
      CharacterMigrationService();
  static final CharacterDataService _characterDataService =
      CharacterDataService();

  /// Test migration for current user
  static Future<void> testCurrentUserMigration() async {
    try {
      print('🧪 Testing current user migration...');

      // Check if migration is needed
      final needsMigration = await _migrationService.needsMigration();
      print('Needs migration: $needsMigration');

      if (needsMigration) {
        // Perform migration
        final success =
            await _migrationService.migrateCurrentUserCharacterData();
        print('Migration success: $success');
      }

      // Verify migration results
      final characterData =
          await _characterDataService.getCurrentUserCharacterData();
      print('✅ Character data after migration:');
      print('  - owned_items: ${characterData['owned_items']}');
      print('  - currentCharacter: ${characterData['currentCharacter']}');
      print('  - homeGlbPath: ${characterData['homeGlbPath']}');
      print('  - spriteSheets: ${characterData['spriteSheets']}');
    } catch (e) {
      print('❌ Error testing migration: $e');
    }
  }

  /// Test character switching
  static Future<void> testCharacterSwitching() async {
    try {
      print('🧪 Testing character switching...');

      // Get current character
      final currentCharacter =
          await _characterDataService.getCurrentCharacter();
      print('Current character: $currentCharacter');

      // Test switching to a different character (if owned)
      final ownedCharacters = await _characterDataService.getOwnedCharacters();
      print('Owned characters: $ownedCharacters');

      if (ownedCharacters.length > 1) {
        final newCharacter =
            ownedCharacters.firstWhere((c) => c != currentCharacter);
        print('Switching to: $newCharacter');

        final success =
            await _characterDataService.updateCurrentCharacter(newCharacter);
        print('Switch success: $success');

        if (success) {
          final updatedCharacter =
              await _characterDataService.getCurrentCharacter();
          final homeGlbPath =
              await _characterDataService.getCurrentHomeGlbPath();
          final spriteSheets =
              await _characterDataService.getCurrentSpriteSheets();

          print('✅ After switch:');
          print('  - currentCharacter: $updatedCharacter');
          print('  - homeGlbPath: $homeGlbPath');
          print('  - spriteSheets: $spriteSheets');
        }
      }
    } catch (e) {
      print('❌ Error testing character switching: $e');
    }
  }

  /// Test adding new character
  static Future<void> testAddingCharacter() async {
    try {
      print('🧪 Testing adding new character...');

      // Test adding a new character
      const testCharacter = 'blossom';
      final success =
          await _characterDataService.addOwnedCharacter(testCharacter);
      print('Add character success: $success');

      if (success) {
        final ownedCharacters =
            await _characterDataService.getOwnedCharacters();
        print('Updated owned characters: $ownedCharacters');

        final ownsCharacter =
            await _characterDataService.ownsCharacter(testCharacter);
        print('Owns $testCharacter: $ownsCharacter');
      }
    } catch (e) {
      print('❌ Error testing adding character: $e');
    }
  }

  /// Test the complete buy and wear flow
  static Future<void> testBuyAndWearFlow() async {
    print('\n=== Testing Buy and Wear Flow ===');
    
    try {
      // 1. Check initial state
      print('1. Checking initial state...');
      final initialData = await CharacterDataService().getCurrentUserCharacterData();
      print('Initial owned_items: ${initialData['owned_items']}');
      print('Initial currentCharacter: ${initialData['currentCharacter']}');
      print('Initial homeGlbPath: ${initialData['homeGlbPath']}');
      
      // 2. Buy a character (simulate shop purchase)
      print('\n2. Buying "blossom" character...');
      final shopService = ShopService();
      await shopService.buyItem('blossom');
      
      // 3. Check owned items after purchase
      print('\n3. Checking owned items after purchase...');
      final ownedItems = await shopService.getOwnedItems();
      print('Owned items: $ownedItems');
      
      // 4. Wear the new character
      print('\n4. Wearing "blossom" character...');
      await shopService.wearItem('blossom');
      
      // 5. Check final state
      print('\n5. Checking final state after wearing...');
      final finalData = await CharacterDataService().getCurrentUserCharacterData();
      print('Final owned_items: ${finalData['owned_items']}');
      print('Final currentCharacter: ${finalData['currentCharacter']}');
      print('Final homeGlbPath: ${finalData['homeGlbPath']}');
      print('Final spriteSheets: ${finalData['spriteSheets']}');
      
      // 6. Verify the changes
      print('\n6. Verifying changes...');
      if (finalData['currentCharacter'] == 'blossom' &&
          finalData['homeGlbPath'] == 'assets/web/home/blossom_home.glb' &&
          finalData['spriteSheets']['idle'] == 'assets/images/sprite_sheets/blossom_idle.json' &&
          finalData['spriteSheets']['walking'] == 'assets/images/sprite_sheets/blossom_walking.json') {
        print('✅ SUCCESS: All fields updated correctly!');
      } else {
        print('❌ FAILED: Some fields not updated correctly');
      }
      
    } catch (error) {
      print('❌ Error during buy and wear test: $error');
    }
  }

  /// Run all tests including the new buy and wear test
  static Future<void> runAllTests() async {
    print('🧪 Starting Character Management Tests...\n');
    
    await testCurrentUserMigration();
    await testCharacterSwitching();
    await testAddingCharacter();
    await testBuyAndWearFlow(); // New test
    
    print('\n🎉 All tests completed!');
  }
}
