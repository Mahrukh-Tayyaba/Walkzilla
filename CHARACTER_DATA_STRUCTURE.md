# Character Data Structure Documentation

## Overview

This document describes the updated Firestore user document structure for supporting shop ownership, character switching, and consistent display across the Walkzilla app.

## New Firestore User Document Fields

### 🔹 1. owned_items (List<String>)
Stores the list of character item IDs the user owns.

**Default Value:** `["MyCharacter"]`

**Example:**
```json
"owned_items": ["MyCharacter", "blossom", "sun", "cloud"]
```

### 🔹 2. currentCharacter (String)
Stores the ID of the currently worn character.

**Default Value:** `"MyCharacter"`

**Example:**
```json
"currentCharacter": "blossom"
```

### 🔹 3. homeGlbPath (String)
Stores the path to the .glb file shown on the home screen based on the currentCharacter.

**Default Value:** `"assets/web/home/MyCharacter_home.glb"`

**Example:**
```json
"homeGlbPath": "assets/web/home/blossom_home.glb"
```

### 🔹 4. spriteSheets (Map<String, dynamic>)
Stores the sprite JSON file paths for the selected character.

**Default Value:**
```json
{
  "idle": "assets/images/sprite_sheets/MyCharacter_idle.json",
  "walking": "assets/images/sprite_sheets/MyCharacter_walking.json"
}
```

**Example:**
```json
"spriteSheets": {
  "idle": "assets/images/sprite_sheets/blossom_idle.json",
  "walking": "assets/images/sprite_sheets/blossom_walking.json"
}
```

## Character Mappings

### Home GLB Path Mapping
```dart
static const Map<String, String> characterHomeGlbPaths = {
  'blossom': 'assets/web/home/blossom_home.glb',
  'sun': 'assets/web/home/sun_home.glb',
  'cloud': 'assets/web/home/cloud_home.glb',
  'cool': 'assets/web/home/cool_home.glb',
  'cow': 'assets/web/home/cow_home.glb',
  'monster': 'assets/web/home/monster_home.glb',
  'blueStar': 'assets/web/home/blueStar_home.glb',
  'yellowStar': 'assets/web/home/yellowstar_home.glb',
  'MyCharacter': 'assets/web/home/MyCharacter_home.glb',
};
```

### Sprite Sheet Mapping
```dart
  static const Map<String, Map<String, String>> spriteSheets = {
    'blossom': {
      'idle': 'images/sprite_sheets/blossom_idle.json',
      'walking': 'images/sprite_sheets/blossom_walking.json',
    },
    'sun': {
      'idle': 'images/sprite_sheets/sun_idle.json',
      'walking': 'images/sprite_sheets/sun_walking.json',
    },
    // ... other characters
  };
```

## Services

### CharacterDataService
Main service for managing character data operations.

**Key Methods:**
- `initializeCharacterData(String userId)` - Initialize new user
- `getCurrentUserCharacterData()` - Get current user's character data
- `updateCurrentCharacter(String characterId)` - Switch to different character
- `addOwnedCharacter(String characterId)` - Add character to owned items
- `getOwnedCharacters()` - Get list of owned characters
- `getCurrentCharacter()` - Get current character ID
- `getCurrentHomeGlbPath()` - Get current home GLB path
- `getCurrentSpriteSheets()` - Get current sprite sheets

### CharacterMigrationService
Service for migrating existing users to the new structure.

**Key Methods:**
- `migrateCurrentUserCharacterData()` - Migrate current user
- `migrateAllUsersCharacterData()` - Migrate all users (admin)
- `needsMigration()` - Check if migration is needed
- `cleanupOldFields()` - Remove old fields after migration

## Migration Process

### For New Users
New users automatically get the correct structure during signup:

```dart
await _firestore.collection('users').doc(userId).set({
  'owned_items': ['MyCharacter'],
  'currentCharacter': 'MyCharacter',
  'homeGlbPath': 'assets/web/home/MyCharacter_home.glb',
  'spriteSheets': {
    'idle': 'assets/images/sprite_sheets/MyCharacter_idle.json',
    'walking': 'assets/images/sprite_sheets/MyCharacter_walking.json',
  },
  // ... other user fields
});
```

### For Existing Users
Existing users are automatically migrated when they log in:

1. **Check for missing fields**
2. **Migrate from old structure:**
   - `ownedItems` → `owned_items`
   - `wornItem` → `currentCharacter`
   - `characterSpriteSheets` → `spriteSheets` (format: `images/sprite_sheets/character_idle.json`)
3. **Add missing fields:**
   - `homeGlbPath` based on `currentCharacter`
   - Update `spriteSheets` based on `currentCharacter`

## Usage Examples

### Switching Characters
```dart
final characterDataService = CharacterDataService();

// Check if user owns the character
final ownsCharacter = await characterDataService.ownsCharacter('blossom');

if (ownsCharacter) {
  // Switch to the character
  final success = await characterDataService.updateCurrentCharacter('blossom');
  if (success) {
    // Character switched successfully
    final homeGlbPath = await characterDataService.getCurrentHomeGlbPath();
    final spriteSheets = await characterDataService.getCurrentSpriteSheets();
  }
}
```

### Adding New Character
```dart
// After successful purchase
final success = await characterDataService.addOwnedCharacter('blossom');
if (success) {
  // Character added to owned items
  final ownedCharacters = await characterDataService.getOwnedCharacters();
}
```

### Getting Current Character Data
```dart
final characterData = await characterDataService.getCurrentUserCharacterData();
print('Current character: ${characterData['currentCharacter']}');
print('Home GLB: ${characterData['homeGlbPath']}');
print('Sprite sheets: ${characterData['spriteSheets']}');
```

## Testing

Use the `CharacterMigrationTest` class to verify the migration works correctly:

```dart
await CharacterMigrationTest.runAllTests();
```

This will test:
- Current user migration
- Character switching
- Adding new characters

## Backward Compatibility

The migration service ensures backward compatibility by:
1. Preserving existing data during migration
2. Providing fallback values for missing fields
3. Supporting both old and new field names during transition

## File Structure

```
lib/services/
├── character_data_service.dart      # Main character data management
├── character_migration_service.dart # Migration utilities
├── character_service.dart           # Updated to use new structure
└── shop_service.dart               # Updated to use new structure

lib/
├── test_character_migration.dart   # Test utilities
└── CHARACTER_DATA_STRUCTURE.md     # This documentation
```

## Notes

- All paths use the `assets/` prefix for consistency
- Only .json files are stored in spriteSheets (not .png files)
- The structure supports easy addition of new characters
- Migration is automatic and transparent to users
- Old fields are cleaned up after successful migration 