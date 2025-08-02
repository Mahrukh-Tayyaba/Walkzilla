import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CharacterDataService {
  static final CharacterDataService _instance =
      CharacterDataService._internal();
  factory CharacterDataService() => _instance;
  CharacterDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Character ID to home GLB path mapping
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

  // Character ID to sprite sheet paths mapping
  static const Map<String, Map<String, String>> spriteSheets = {
    'blossom': {
      'idle': 'images/sprite_sheets/blossom_idle.json',
      'walking': 'images/sprite_sheets/blossom_walking.json',
    },
    'sun': {
      'idle': 'images/sprite_sheets/sun_idle.json',
      'walking': 'images/sprite_sheets/sun_walking.json',
    },
    'cloud': {
      'idle': 'images/sprite_sheets/cloud_idle.json',
      'walking': 'images/sprite_sheets/cloud_walking.json',
    },
    'cool': {
      'idle': 'images/sprite_sheets/cool_idle.json',
      'walking': 'images/sprite_sheets/cool_walking.json',
    },
    'cow': {
      'idle': 'images/sprite_sheets/cow_idle.json',
      'walking': 'images/sprite_sheets/cow_walking.json',
    },
    'monster': {
      'idle': 'images/sprite_sheets/monster_idle.json',
      'walking': 'images/sprite_sheets/monster_walking.json',
    },
    'blueStar': {
      'idle': 'images/sprite_sheets/blueStar_idle.json',
      'walking': 'images/sprite_sheets/blueStar_walking.json',
    },
    'yellowStar': {
      'idle': 'images/sprite_sheets/yellowStar_idle.json',
      'walking': 'images/sprite_sheets/yellowStar_walking.json',
    },
    'MyCharacter': {
      'idle': 'images/sprite_sheets/MyCharacter_idle.json',
      'walking': 'images/sprite_sheets/MyCharacter_walking.json',
    },
  };

  /// Initialize character data for a new user
  Future<void> initializeCharacterData(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'owned_items': ['MyCharacter'],
        'currentCharacter': 'MyCharacter',
        'homeGlbPath': characterHomeGlbPaths['MyCharacter'],
        'spriteSheets': spriteSheets['MyCharacter'],
      });
      print('✅ Initialized character data for user: $userId');
    } catch (e) {
      print('❌ Error initializing character data: $e');
    }
  }

  /// Get current user's character data
  Future<Map<String, dynamic>> getCurrentUserCharacterData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return _getDefaultCharacterData();

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return _getDefaultCharacterData();

      final userData = userDoc.data()!;
      return {
        'owned_items':
            List<String>.from(userData['owned_items'] ?? ['MyCharacter']),
        'currentCharacter': userData['currentCharacter'] ?? 'MyCharacter',
        'homeGlbPath':
            userData['homeGlbPath'] ?? characterHomeGlbPaths['MyCharacter'],
        'spriteSheets': userData['spriteSheets'] ?? spriteSheets['MyCharacter'],
      };
    } catch (e) {
      print('❌ Error getting character data: $e');
      return _getDefaultCharacterData();
    }
  }

  /// Get character data for a specific user
  Future<Map<String, dynamic>> getUserCharacterData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return _getDefaultCharacterData();

      final userData = userDoc.data()!;
      return {
        'owned_items':
            List<String>.from(userData['owned_items'] ?? ['MyCharacter']),
        'currentCharacter': userData['currentCharacter'] ?? 'MyCharacter',
        'homeGlbPath':
            userData['homeGlbPath'] ?? characterHomeGlbPaths['MyCharacter'],
        'spriteSheets': userData['spriteSheets'] ?? spriteSheets['MyCharacter'],
      };
    } catch (e) {
      print('❌ Error getting user character data: $e');
      return _getDefaultCharacterData();
    }
  }

  /// Update current character
  Future<bool> updateCurrentCharacter(String characterId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Verify character exists in mapping
      if (!characterHomeGlbPaths.containsKey(characterId)) {
        print('❌ Invalid character ID: $characterId');
        return false;
      }

      // Check if user owns the character
      final characterData = await getCurrentUserCharacterData();
      final ownedItems = characterData['owned_items'] as List<String>;

      if (!ownedItems.contains(characterId)) {
        print('❌ User does not own character: $characterId');
        return false;
      }

      // Update character data
      await _firestore.collection('users').doc(user.uid).update({
        'currentCharacter': characterId,
        'homeGlbPath': characterHomeGlbPaths[characterId],
        'spriteSheets': spriteSheets[characterId],
      });

      print('✅ Updated current character to: $characterId');
      return true;
    } catch (e) {
      print('❌ Error updating current character: $e');
      return false;
    }
  }

  /// Add character to owned items
  Future<bool> addOwnedCharacter(String characterId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('users').doc(user.uid).update({
        'owned_items': FieldValue.arrayUnion([characterId]),
      });

      print('✅ Added character to owned items: $characterId');
      return true;
    } catch (e) {
      print('❌ Error adding owned character: $e');
      return false;
    }
  }

  /// Get owned characters for current user
  Future<List<String>> getOwnedCharacters() async {
    try {
      final characterData = await getCurrentUserCharacterData();
      return characterData['owned_items'] as List<String>;
    } catch (e) {
      print('❌ Error getting owned characters: $e');
      return ['MyCharacter'];
    }
  }

  /// Get current character ID
  Future<String> getCurrentCharacter() async {
    try {
      final characterData = await getCurrentUserCharacterData();
      return characterData['currentCharacter'] as String;
    } catch (e) {
      print('❌ Error getting current character: $e');
      return 'MyCharacter';
    }
  }

  /// Get home GLB path for current character
  Future<String> getCurrentHomeGlbPath() async {
    try {
      final characterData = await getCurrentUserCharacterData();
      return characterData['homeGlbPath'] as String;
    } catch (e) {
      print('❌ Error getting home GLB path: $e');
      return characterHomeGlbPaths['MyCharacter']!;
    }
  }

  /// Get sprite sheets for current character
  Future<Map<String, String>> getCurrentSpriteSheets() async {
    try {
      final characterData = await getCurrentUserCharacterData();
      return Map<String, String>.from(characterData['spriteSheets'] as Map);
    } catch (e) {
      print('❌ Error getting sprite sheets: $e');
      return spriteSheets['MyCharacter']!;
    }
  }

  /// Check if user owns a character
  Future<bool> ownsCharacter(String characterId) async {
    try {
      final ownedCharacters = await getOwnedCharacters();
      return ownedCharacters.contains(characterId);
    } catch (e) {
      print('❌ Error checking character ownership: $e');
      return characterId == 'MyCharacter';
    }
  }

  /// Check if character is currently worn
  Future<bool> isCharacterWorn(String characterId) async {
    try {
      final currentCharacter = await getCurrentCharacter();
      return currentCharacter == characterId;
    } catch (e) {
      print('❌ Error checking if character is worn: $e');
      return characterId == 'MyCharacter';
    }
  }

  /// Stream character data changes
  Stream<Map<String, dynamic>> getCharacterDataStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(_getDefaultCharacterData());

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return _getDefaultCharacterData();

      final userData = doc.data()!;
      return {
        'owned_items':
            List<String>.from(userData['owned_items'] ?? ['MyCharacter']),
        'currentCharacter': userData['currentCharacter'] ?? 'MyCharacter',
        'homeGlbPath':
            userData['homeGlbPath'] ?? characterHomeGlbPaths['MyCharacter'],
        'spriteSheets': userData['spriteSheets'] ?? spriteSheets['MyCharacter'],
      };
    });
  }

  /// Get default character data
  Map<String, dynamic> _getDefaultCharacterData() {
    return {
      'owned_items': ['MyCharacter'],
      'currentCharacter': 'MyCharacter',
      'homeGlbPath': characterHomeGlbPaths['MyCharacter'],
      'spriteSheets': spriteSheets['MyCharacter'],
    };
  }

  /// Get home GLB path for a specific character
  String getHomeGlbPathForCharacter(String characterId) {
    return characterHomeGlbPaths[characterId] ??
        characterHomeGlbPaths['MyCharacter']!;
  }

  /// Get sprite sheets for a specific character
  Map<String, String> getSpriteSheetsForCharacter(String characterId) {
    return spriteSheets[characterId] ?? spriteSheets['MyCharacter']!;
  }
}
