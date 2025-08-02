# Dynamic GLB Loading Implementation

## Overview

The home screen now dynamically loads GLB files based on the user's current character from Firestore, replacing the previous hardcoded approach.

## Key Changes Made

### 1. **Added Dynamic GLB Path Variable**
```dart
String _currentGlbPath = 'assets/web/home/MyCharacter_home.glb'; // Dynamic GLB path
```

### 2. **Updated User Data Loading**
- Modified `_loadUserData()` to fetch `homeGlbPath` from Firestore
- Added GLB path to the state management
- Added debug logging for GLB path loading

### 3. **Added Real-time Listener**
- Created `_startUserDataListener()` method
- Listens for changes to user document in Firestore
- Automatically updates GLB path when character changes
- Only triggers updates when the path actually changes

### 4. **Updated ModelViewer Widget**
- Removed hardcoded `src` path
- Now uses `_currentGlbPath` variable
- Removed `const` keyword to allow dynamic updates
- Updated alt text to be more generic

### 5. **Added Cleanup**
- Updated `dispose()` method to cancel the user data listener
- Prevents memory leaks when screen is disposed

## How It Works

### On User Login:
1. `_loadUserData()` fetches the user's `homeGlbPath` from Firestore
2. Sets `_currentGlbPath` to the fetched value
3. Starts the real-time listener for future updates

### On Character Change:
1. User changes character in shop (updates Firestore)
2. `_startUserDataListener()` detects the change
3. Updates `_currentGlbPath` with new value
4. ModelViewer automatically reloads with new GLB file

### Real-time Updates:
- Listener continuously monitors user document
- Only updates UI when GLB path actually changes
- Provides debug logging for troubleshooting

## Code Structure

```dart
// Variables
String _currentGlbPath = 'assets/web/home/MyCharacter_home.glb';
StreamSubscription<DocumentSnapshot>? _userDataListener;

// Methods
void _startUserDataListener() // Real-time updates
Future<void> _loadUserData() // Initial loading
void dispose() // Cleanup

// Widget
ModelViewer(
  src: _currentGlbPath, // Dynamic path
  // ... other properties
)
```

## Testing

Use the `test_dynamic_glb.dart` script to verify functionality:

```dart
// Test current user's GLB path
await DynamicGlbTest.testCurrentUserGlbPath();

// Test GLB path updates
await DynamicGlbTest.testGlbPathUpdate();

// Run all tests
await DynamicGlbTest.runAllTests();
```

## Benefits

1. **Dynamic Loading**: GLB files load based on user's current character
2. **Real-time Updates**: Changes reflect immediately when character is changed
3. **No Hardcoding**: Removed static path references
4. **Consistent**: Works with existing character system
5. **Efficient**: Only updates when necessary
6. **Debuggable**: Comprehensive logging for troubleshooting

## Integration Points

- **CharacterDataService**: Provides character-to-GLB path mappings
- **ShopService**: Updates character data when user wears items
- **Firestore**: Stores and syncs user character data
- **ModelViewer**: Displays the dynamic GLB content

## Error Handling

- Fallback to default path if Firestore data is missing
- Graceful handling of network issues
- Proper cleanup of listeners
- Debug logging for troubleshooting

## Future Enhancements

- Add loading indicators during GLB transitions
- Implement GLB preloading for smoother transitions
- Add error handling for missing GLB files
- Consider caching mechanisms for better performance 