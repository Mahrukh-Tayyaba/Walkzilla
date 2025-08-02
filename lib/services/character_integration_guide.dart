import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'character_data_service.dart';
import 'character_migration_service.dart';

/// Integration guide for using the new character data structure
class CharacterIntegrationGuide {
  static final CharacterDataService _characterDataService =
      CharacterDataService();
  static final CharacterMigrationService _migrationService =
      CharacterMigrationService();

  /// Initialize character system for the app
  /// Call this when the app starts or user logs in
  static Future<void> initializeCharacterSystem() async {
    try {
      // Check if current user needs migration
      final needsMigration = await _migrationService.needsMigration();

      if (needsMigration) {
        print('🔄 Migrating user to new character structure...');
        await _migrationService.migrateCurrentUserCharacterData();
        print('✅ Migration completed');
      }

      // Verify character data is properly set up
      final characterData =
          await _characterDataService.getCurrentUserCharacterData();
      print('✅ Character system initialized:');
      print('  - Current character: ${characterData['currentCharacter']}');
      print('  - Owned characters: ${characterData['owned_items']}');
      print('  - Home GLB: ${characterData['homeGlbPath']}');
    } catch (e) {
      print('❌ Error initializing character system: $e');
    }
  }

  /// Get current character for display
  /// Use this in home screen, profile, etc.
  static Future<String> getCurrentCharacterForDisplay() async {
    return await _characterDataService.getCurrentCharacter();
  }

  /// Get home GLB path for 3D model display
  /// Use this in home screen for 3D character display
  static Future<String> getHomeGlbPathForDisplay() async {
    return await _characterDataService.getCurrentHomeGlbPath();
  }

  /// Get sprite sheets for 2D animations
  /// Use this in games, step counter, etc.
  static Future<Map<String, String>> getSpriteSheetsForDisplay() async {
    return await _characterDataService.getCurrentSpriteSheets();
  }

  /// Check if user owns a specific character
  /// Use this in shop to show/hide purchase buttons
  static Future<bool> checkCharacterOwnership(String characterId) async {
    return await _characterDataService.ownsCharacter(characterId);
  }

  /// Switch to a different character
  /// Use this when user selects a character in shop or profile
  static Future<bool> switchToCharacter(String characterId) async {
    try {
      final success =
          await _characterDataService.updateCurrentCharacter(characterId);
      if (success) {
        print('✅ Switched to character: $characterId');

        // Get updated data for UI refresh
        final characterData =
            await _characterDataService.getCurrentUserCharacterData();
        print('  - New home GLB: ${characterData['homeGlbPath']}');
        print('  - New sprite sheets: ${characterData['spriteSheets']}');
      }
      return success;
    } catch (e) {
      print('❌ Error switching character: $e');
      return false;
    }
  }

  /// Add character after purchase
  /// Use this after successful shop purchase
  static Future<bool> addCharacterAfterPurchase(String characterId) async {
    try {
      final success =
          await _characterDataService.addOwnedCharacter(characterId);
      if (success) {
        print('✅ Added character to owned items: $characterId');

        // Get updated owned characters list
        final ownedCharacters =
            await _characterDataService.getOwnedCharacters();
        print('  - Updated owned characters: $ownedCharacters');
      }
      return success;
    } catch (e) {
      print('❌ Error adding character: $e');
      return false;
    }
  }

  /// Get all owned characters for shop display
  /// Use this in shop to show owned vs available items
  static Future<List<String>> getOwnedCharactersForShop() async {
    return await _characterDataService.getOwnedCharacters();
  }

  /// Stream character data changes
  /// Use this for real-time UI updates
  static Stream<Map<String, dynamic>> getCharacterDataStream() {
    return _characterDataService.getCharacterDataStream();
  }

  /// Get character data for a specific user (for friend profiles, etc.)
  static Future<Map<String, dynamic>> getCharacterDataForUser(
      String userId) async {
    return await _characterDataService.getUserCharacterData(userId);
  }

  /// Clean up old fields after migration (optional)
  /// Call this after confirming migration works correctly
  static Future<void> cleanupOldFields() async {
    try {
      await _migrationService.cleanupOldFields();
      print('✅ Cleaned up old character fields');
    } catch (e) {
      print('❌ Error cleaning up old fields: $e');
    }
  }

  /// Example: How to use in a widget
  static Future<void> exampleWidgetUsage() async {
    // Initialize when widget builds
    await initializeCharacterSystem();

    // Get current character for display
    final currentCharacter = await getCurrentCharacterForDisplay();
    print('Current character: $currentCharacter');

    // Get home GLB for 3D display
    final homeGlbPath = await getHomeGlbPathForDisplay();
    print('Home GLB path: $homeGlbPath');

    // Get sprite sheets for 2D animations
    final spriteSheets = await getSpriteSheetsForDisplay();
    print('Sprite sheets: $spriteSheets');

    // Check ownership for shop
    final ownsBlossom = await checkCharacterOwnership('blossom');
    print('Owns blossom: $ownsBlossom');
  }

  /// Example: How to handle character switching
  static Future<void> exampleCharacterSwitching() async {
    // User selects a character in shop
    const selectedCharacter = 'blossom';

    // Check if they own it
    final ownsCharacter = await checkCharacterOwnership(selectedCharacter);

    if (ownsCharacter) {
      // Switch to the character
      final success = await switchToCharacter(selectedCharacter);
      if (success) {
        print('✅ Successfully switched to $selectedCharacter');
        // Update UI here
      }
    } else {
      print('❌ User does not own $selectedCharacter');
      // Show purchase option
    }
  }

  /// Example: How to handle shop purchase
  static Future<void> exampleShopPurchase() async {
    // After successful coin deduction
    const purchasedCharacter = 'blossom';

    // Add character to owned items
    final success = await addCharacterAfterPurchase(purchasedCharacter);
    if (success) {
      print('✅ Successfully purchased $purchasedCharacter');

      // Optionally switch to the new character
      await switchToCharacter(purchasedCharacter);

      // Update shop UI
      final ownedCharacters = await getOwnedCharactersForShop();
      print('Updated owned characters: $ownedCharacters');
    }
  }
}
