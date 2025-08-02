# Dynamic Animation System

## Overview

The Dynamic Animation System allows the app to load character sprite sheet animations dynamically based on the user's current character selection stored in Firestore. This system eliminates the need for hardcoded animation paths and ensures that animations are always consistent with the user's selected character.

## Key Features

- **Dynamic Loading**: Sprite sheets are loaded based on the user's `currentCharacter` field in Firestore
- **Automatic Reloading**: Animations automatically reload when the user changes their character
- **Caching**: Animations are cached for performance, with intelligent cache invalidation
- **Character Change Detection**: The system detects when a character has changed and reloads accordingly
- **Login Integration**: Animations are automatically loaded when users log in

## Architecture

### Core Services

#### 1. CharacterAnimationService
The main service responsible for loading and managing character animations.

**Key Methods:**
- `preloadAnimations()`: Loads animations for the current user's character
- `preloadAnimationsForCharacter(String characterId)`: Loads animations for a specific character
- `reloadAnimationsForCurrentCharacter()`: Reloads animations when character changes
- `needsReload()`: Checks if animations need to be reloaded due to character change
- `autoReloadIfNeeded()`: Automatically reloads if character has changed
- `onCharacterChanged(String newCharacterId)`: Handles character change events

**Caching:**
- Caches both `SpriteAnimation` objects and `ui.Image` objects
- Tracks the last loaded character ID to detect changes
- Provides cache clearing and memory management

#### 2. CharacterDataService
Provides access to character-related data from Firestore.

**Key Methods:**
- `getCurrentSpriteSheets()`: Gets sprite sheet paths for current character
- `getCurrentCharacter()`: Gets the current character ID
- `getSpriteSheetsForCharacter(String characterId)`: Gets sprite sheet paths for a specific character

#### 3. UserLoginService
Handles user login events and initializes character animations.

**Key Methods:**
- `onUserLogin()`: Initializes animations when user logs in
- `onUserLogout()`: Cleans up animations when user logs out
- `isUserReady()`: Checks if user is logged in and animations are loaded

#### 4. ShopService
Updated to trigger animation reloads when characters are worn.

**Key Changes:**
- `wearItem()` method now calls `_animationService.onCharacterChanged(itemId)`
- Ensures animations are reloaded immediately when a character is worn

## Data Flow

### 1. User Login Flow
```
User Login → UserLoginService.onUserLogin() → 
CharacterDataService.getCurrentSpriteSheets() → 
CharacterAnimationService.preloadAnimationsForCharacter() → 
Animations Loaded and Cached
```

### 2. Character Change Flow
```
User Wears Character → ShopService.wearItem() → 
Firestore Update (currentCharacter, spriteSheets) → 
CharacterAnimationService.onCharacterChanged() → 
Cache Cleared → New Animations Loaded
```

### 3. Animation Request Flow
```
Game Requests Animations → CharacterAnimationService.getAnimations() → 
Check if reload needed → Reload if necessary → 
Return cached animations
```

## Integration Points

### Login/Signup Screens
- **login_screen.dart**: Calls `_userLoginService.onUserLogin()` after successful login
- **signup_screen.dart**: Calls `_userLoginService.onUserLogin()` after Google signup
- **email_verification_screen.dart**: Calls `_userLoginService.onUserLogin()` after email verification

### Shop System
- **shop_service.dart**: Updated `wearItem()` method to trigger animation reloads
- **shop_screen.dart**: No changes needed (uses existing shop service)

### Game Components
- **solo_mode.dart**: Uses `CharacterAnimationService.getAnimations()` to get current animations
- **Character class**: Loads animations from the service instead of hardcoded paths

## Firestore Document Structure

The user document contains these character-related fields:

```json
{
  "currentCharacter": "blossom",
  "spriteSheets": {
    "idle": "images/sprite_sheets/blossom_idle.json",
    "walking": "images/sprite_sheets/blossom_walking.json"
  },
  "owned_items": ["MyCharacter", "blossom", "sun"],
  "homeGlbPath": "assets/web/home/blossom_home.glb"
}
```

## Character Mappings

The `CharacterDataService` contains static mappings for all characters:

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

## Testing

### Test Scripts
- **test_dynamic_animations.dart**: Comprehensive test suite for the dynamic animation system
- **test_character_migration.dart**: Tests character data migration and cleanup

### Test Coverage
1. **Initial Login Loading**: Verifies animations load correctly on user login
2. **Character Switching**: Tests animation reloading when character changes
3. **Buy and Wear Flow**: Tests the complete purchase and wearing process
4. **Animation Caching**: Verifies caching performance and behavior
5. **Specific Character Testing**: Tests loading animations for specific characters

### Running Tests
```dart
// Run all dynamic animation tests
await DynamicAnimationTest.runAllTests();

// Test specific character
await DynamicAnimationTest.testSpecificCharacter('blossom');
```

## Performance Considerations

### Caching Strategy
- Animations are cached in memory for fast access
- Images are cached separately to avoid reloading
- Cache is cleared when character changes or on memory pressure

### Memory Management
- `clearCache()` method properly disposes of cached resources
- `forceMemoryCleanup()` provides additional memory cleanup
- Cache staleness detection prevents memory leaks

### Loading Optimization
- Animations are loaded sequentially to reduce memory pressure
- Error handling ensures graceful fallbacks
- Loading states are tracked to prevent duplicate loads

## Error Handling

### Fallback Strategy
- If character data is missing, defaults to "MyCharacter"
- If sprite sheets fail to load, uses cached animations if available
- Network errors are handled gracefully with retry logic

### Error Recovery
- Invalid character IDs fall back to "MyCharacter"
- Missing sprite sheet files trigger error logging
- Authentication errors are handled by the login service

## Future Enhancements

### Planned Features
1. **Preloading**: Preload animations for owned characters in background
2. **Compression**: Implement sprite sheet compression for better performance
3. **Streaming**: Stream animation updates in real-time
4. **Offline Support**: Cache animations for offline use

### Extensibility
- Easy to add new characters by updating the static mappings
- Service architecture allows for easy testing and mocking
- Modular design supports future enhancements

## Migration Guide

### From Hardcoded Animations
1. Replace direct sprite sheet path usage with `CharacterAnimationService.getAnimations()`
2. Update initialization to call `UserLoginService.onUserLogin()`
3. Ensure character change events trigger animation reloads

### Code Examples

**Before (Hardcoded):**
```dart
final idleAnimation = await _loadTexturePackerAnimation(
    'images/sprite_sheets/MyCharacter_idle.json', 0.08);
```

**After (Dynamic):**
```dart
final animations = await _animationService.getAnimations();
final idleAnimation = animations['idle'];
```

**Character Change Handling:**
```dart
// In shop service
await _animationService.onCharacterChanged(newCharacterId);

// In game components
await _animationService.autoReloadIfNeeded();
```

## Troubleshooting

### Common Issues

1. **Animations not loading**: Check if user is logged in and character data exists
2. **Wrong character animations**: Verify `currentCharacter` field in Firestore
3. **Performance issues**: Check cache status and memory usage
4. **Character change not detected**: Ensure `wearItem()` calls animation service

### Debug Information
- All services provide detailed logging for debugging
- Test scripts can verify system functionality
- Cache status can be checked via service getters

### Support
For issues with the dynamic animation system:
1. Check the console logs for error messages
2. Run the test scripts to verify functionality
3. Verify Firestore document structure
4. Check character mappings in `CharacterDataService` 