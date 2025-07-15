import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'dart:convert';
import 'dart:ui' as ui;

class CharacterService {
  static final CharacterService _instance = CharacterService._internal();
  factory CharacterService() => _instance;
  CharacterService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for loaded character animations
  final Map<String, Map<String, SpriteAnimation>> _characterAnimations = {};
  final Map<String, ui.Image> _characterImages = {};
  bool _isLoading = false;

  /// Get the current user's character sprite sheets
  Future<Map<String, String>> getCurrentUserSpriteSheets() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return _getDefaultSpriteSheets();

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final spriteSheets =
            userData['characterSpriteSheets'] as Map<String, dynamic>?;
        if (spriteSheets != null) {
          return {
            'idle': spriteSheets['idle'] as String,
            'walking': spriteSheets['walking'] as String,
          };
        }
      }
      return _getDefaultSpriteSheets();
    } catch (e) {
      print('Error getting user sprite sheets: $e');
      return _getDefaultSpriteSheets();
    }
  }

  /// Get a specific user's character sprite sheets
  Future<Map<String, String>> getUserSpriteSheets(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final spriteSheets =
            userData['characterSpriteSheets'] as Map<String, dynamic>?;
        if (spriteSheets != null) {
          return {
            'idle': spriteSheets['idle'] as String,
            'walking': spriteSheets['walking'] as String,
          };
        }
      }
      return _getDefaultSpriteSheets();
    } catch (e) {
      print('Error getting user sprite sheets: $e');
      return _getDefaultSpriteSheets();
    }
  }

  /// Update the current user's character sprite sheets
  Future<bool> updateUserSpriteSheets(Map<String, String> spriteSheets) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('users').doc(user.uid).update({
        'characterSpriteSheets': spriteSheets,
      });

      // Clear cache for this user to force reload
      _clearUserCache(user.uid);

      return true;
    } catch (e) {
      print('Error updating user sprite sheets: $e');
      return false;
    }
  }

  /// Get default sprite sheets (fallback)
  Map<String, String> _getDefaultSpriteSheets() {
    return {
      'idle': 'images/character_idle.json',
      'walking': 'images/character_walking.json',
    };
  }

  /// Load animations for a specific user's character
  Future<Map<String, SpriteAnimation>> loadUserAnimations(String userId) async {
    // Check if already cached
    if (_characterAnimations.containsKey(userId)) {
      return _characterAnimations[userId]!;
    }

    try {
      _isLoading = true;

      // Get user's sprite sheet paths
      final spriteSheets = await getUserSpriteSheets(userId);
      final animations = <String, SpriteAnimation>{};

      // Load idle animation
      animations['idle'] = await _loadTexturePackerAnimation(
        spriteSheets['idle']!,
        0.08,
        userId,
      );

      // Load walking animation
      animations['walking'] = await _loadTexturePackerAnimation(
        spriteSheets['walking']!,
        0.15, // Slower animation speed to make it more noticeable
        userId,
      );

      // Cache the animations
      _characterAnimations[userId] = animations;
      _isLoading = false;

      return animations;
    } catch (e) {
      _isLoading = false;
      print('Error loading user animations: $e');
      rethrow;
    }
  }

  /// Load a single animation with memory optimization
  Future<SpriteAnimation> _loadTexturePackerAnimation(
    String jsonPath,
    double stepTime,
    String userId,
  ) async {
    try {
      // Load JSON first
      final jsonStr = await Flame.assets.readFile(jsonPath);
      final Map<String, dynamic> data = json.decode(jsonStr);
      final Map<String, dynamic> frames = data['frames'];

      // Load image with caching
      final String imageName = data['meta']['image'];
      ui.Image image;

      if (_characterImages.containsKey('${userId}_$imageName')) {
        image = _characterImages['${userId}_$imageName']!;
      } else {
        image = await Flame.images.load(imageName);
        _characterImages['${userId}_$imageName'] = image;
      }

      final List<Sprite> spriteList = [];
      final frameKeys = frames.keys.toList()..sort();

      // Create sprites
      for (final frameKey in frameKeys) {
        final frame = frames[frameKey]['frame'];
        final sprite = Sprite(
          image,
          srcPosition: Vector2(frame['x'].toDouble(), frame['y'].toDouble()),
          srcSize: Vector2(frame['w'].toDouble(), frame['h'].toDouble()),
        );
        spriteList.add(sprite);
      }

      return SpriteAnimation.spriteList(spriteList, stepTime: stepTime);
    } catch (e) {
      print('Error loading animation from $jsonPath: $e');
      rethrow;
    }
  }

  /// Preload all character animations for current user
  Future<void> preloadCurrentUserAnimations() async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      final user = _auth.currentUser;
      if (user != null) {
        await loadUserAnimations(user.uid);
      }
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      print('Error preloading current user animations: $e');
    }
  }

  /// Get animations for the current user's character
  Future<Map<String, SpriteAnimation>> getCurrentUserAnimations() async {
    final user = _auth.currentUser;
    if (user == null) {
      // Return default animations if no user
      final defaultSheets = _getDefaultSpriteSheets();
      return {
        'idle': await _loadTexturePackerAnimation(
            defaultSheets['idle']!, 0.08, 'default'),
        'walking': await _loadTexturePackerAnimation(
            defaultSheets['walking']!, 0.15, 'default'),
      };
    }
    return await loadUserAnimations(user.uid);
  }

  /// Check if animations are loaded for a user
  bool isUserAnimationsLoaded(String userId) {
    return _characterAnimations.containsKey(userId);
  }

  /// Get loading status
  bool get isLoading => _isLoading;

  /// Clear cache for a specific user
  void _clearUserCache(String userId) {
    _characterAnimations.remove(userId);
    // Remove cached images for this user
    _characterImages.removeWhere((key, value) => key.startsWith('${userId}_'));
  }

  /// Clear all cache for memory management
  void clearCache() {
    _characterAnimations.clear();
    _characterImages.clear();
  }

  /// Update character sprite sheets (for future shop integration)
  Future<bool> updateCharacterClothes(
      Map<String, String> newSpriteSheets) async {
    return await updateUserSpriteSheets(newSpriteSheets);
  }

  /// Get current character sprite sheet paths (for debugging)
  Future<Map<String, String>> getCurrentSpriteSheetPaths() async {
    return await getCurrentUserSpriteSheets();
  }
}
