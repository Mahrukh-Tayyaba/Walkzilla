import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

import 'character_data_service.dart';

class CharacterAnimationService {
  static final CharacterAnimationService _instance =
      CharacterAnimationService._internal();
  factory CharacterAnimationService() => _instance;
  CharacterAnimationService._internal();

  final CharacterDataService _characterDataService = CharacterDataService();

  // Cache for loaded animations per character ID
  final Map<String, SpriteAnimation> _cachedIdleAnimations = {};
  final Map<String, SpriteAnimation> _cachedWalkingAnimations = {};
  final Map<String, ui.Image> _cachedIdleImages = {};
  final Map<String, ui.Image> _cachedWalkingImages = {};
  final Map<String, bool> _isLoading = {};
  final Map<String, bool> _isLoaded = {};
  final Map<String, DateTime> _lastLoadTime = {};
  final Map<String, String> _lastLoadedCharacterId = {};

  // Getters for current user (backward compatibility)
  SpriteAnimation? get idleAnimation => _cachedIdleAnimations['current_user'];
  SpriteAnimation? get walkingAnimation =>
      _cachedWalkingAnimations['current_user'];
  bool get isLoading => _isLoading['current_user'] ?? false;
  bool get isLoaded => _isLoaded['current_user'] ?? false;
  DateTime? get lastLoadTime => _lastLoadTime['current_user'];
  String? get lastLoadedCharacterId => _lastLoadedCharacterId['current_user'];

  /// Get animations for a specific character ID
  SpriteAnimation? getIdleAnimation(String characterId) =>
      _cachedIdleAnimations[characterId];
  SpriteAnimation? getWalkingAnimation(String characterId) =>
      _cachedWalkingAnimations[characterId];
  bool isLoadingForCharacter(String characterId) =>
      _isLoading[characterId] ?? false;
  bool isLoadedForCharacter(String characterId) =>
      _isLoaded[characterId] ?? false;

  /// Preload character animations for the current user's character
  Future<void> preloadAnimations() async {
    await preloadAnimationsForCharacter('current_user');
  }

  /// Preload animations for a specific character (useful for testing or preview)
  Future<void> preloadAnimationsForCharacter(String characterId) async {
    if (_isLoading[characterId] == true) return;

    _isLoading[characterId] = true;
    debugPrint(
        'CharacterAnimationService: Starting preload for character: $characterId');

    try {
      // Get sprite sheet paths for the specific character
      Map<String, String> spriteSheets;
      if (characterId == 'current_user') {
        spriteSheets = await _characterDataService.getCurrentSpriteSheets();
        final currentCharacter =
            await _characterDataService.getCurrentCharacter();
        _lastLoadedCharacterId[characterId] = currentCharacter;
      } else {
        // For opponent characters, we need to get their character data
        // This will be handled by the calling code that provides characterData
        throw UnimplementedError(
            'Use preloadAnimationsForCharacterWithData for opponent characters');
      }

      debugPrint(
          'CharacterAnimationService: Sprite sheets for $characterId: $spriteSheets');

      // Load animations using the character's paths
      _cachedIdleAnimations[characterId] = await _loadTexturePackerAnimation(
          spriteSheets['idle']!, 0.08, characterId);
      _cachedWalkingAnimations[characterId] = await _loadTexturePackerAnimation(
          spriteSheets['walking']!, 0.06, characterId);

      _isLoaded[characterId] = true;
      _isLoading[characterId] = false;
      _lastLoadTime[characterId] = DateTime.now();

      debugPrint(
          'CharacterAnimationService: Preload completed successfully for $characterId');
    } catch (e, st) {
      _isLoading[characterId] = false;
      debugPrint(
          'CharacterAnimationService: Preload failed for $characterId: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Verify sprite sheet paths exist
  Future<bool> _verifySpriteSheetPaths(Map<String, String> spriteSheets) async {
    try {
      for (final entry in spriteSheets.entries) {
        final path = entry.value;
        debugPrint(
            'CharacterAnimationService: Verifying sprite sheet path: $path');

        // Try to read the JSON file to verify it exists
        await Flame.assets.readFile(path);
        debugPrint(
            'CharacterAnimationService: ✅ Sprite sheet path verified: $path');
      }
      return true;
    } catch (e) {
      debugPrint(
          'CharacterAnimationService: ❌ Sprite sheet path verification failed: $e');
      return false;
    }
  }

  /// Preload animations for a specific character with provided character data
  Future<void> preloadAnimationsForCharacterWithData(
      String characterId, Map<String, dynamic> characterData) async {
    // If already loaded for this character, skip
    if (_isLoaded[characterId] == true) {
      debugPrint(
          'CharacterAnimationService: Preload skipped, already loaded for $characterId');
      return;
    }

    if (_isLoading[characterId] == true) return;

    _isLoading[characterId] = true;
    debugPrint(
        'CharacterAnimationService: Starting preload for character: $characterId with data: ${characterData['currentCharacter']}');

    try {
      // Get sprite sheet paths from the provided character data
      final spriteSheets = _normalizeSpriteSheetPaths(
        Map<String, dynamic>.from(characterData['spriteSheets'] as Map),
      );
      _lastLoadedCharacterId[characterId] = characterData['currentCharacter'];

      debugPrint(
          'CharacterAnimationService: Sprite sheets for $characterId: $spriteSheets');

      // Verify sprite sheet paths exist before loading
      final pathsValid = await _verifySpriteSheetPaths(spriteSheets);
      if (!pathsValid) {
        throw Exception(
            'Sprite sheet paths verification failed for character: $characterId');
      }

      // Load animations using the character's paths
      _cachedIdleAnimations[characterId] = await _loadTexturePackerAnimation(
          spriteSheets['idle']!, 0.08, characterId);
      _cachedWalkingAnimations[characterId] = await _loadTexturePackerAnimation(
          spriteSheets['walking']!, 0.06, characterId);

      _isLoaded[characterId] = true;
      _isLoading[characterId] = false;
      _lastLoadTime[characterId] = DateTime.now();

      debugPrint(
          'CharacterAnimationService: Preload completed successfully for $characterId (${characterData['currentCharacter']})');
    } catch (e, st) {
      _isLoading[characterId] = false;
      debugPrint(
          'CharacterAnimationService: Preload failed for $characterId: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  /// Reload animations when character changes
  Future<void> reloadAnimationsForCurrentCharacter() async {
    debugPrint(
        'CharacterAnimationService: Reloading animations for current character...');

    // Clear existing cache for current user
    clearCacheForCharacter('current_user');

    // Load new animations
    await preloadAnimations();
  }

  /// Check if animations need to be reloaded (character changed)
  Future<bool> needsReload() async {
    if (!(_isLoaded['current_user'] ?? false)) return true;

    try {
      final currentCharacter =
          await _characterDataService.getCurrentCharacter();
      return _lastLoadedCharacterId['current_user'] != currentCharacter;
    } catch (e) {
      debugPrint(
          'CharacterAnimationService: Error checking if reload needed: $e');
      return true;
    }
  }

  /// Auto-reload if character changed
  Future<void> autoReloadIfNeeded() async {
    if (await needsReload()) {
      debugPrint(
          'CharacterAnimationService: Character changed, auto-reloading...');
      await reloadAnimationsForCurrentCharacter();
    }
  }

  /// Load a single animation with memory optimization
  Future<SpriteAnimation> _loadTexturePackerAnimation(
      String jsonPath, double stepTime, String characterId) async {
    try {
      debugPrint(
          'CharacterAnimationService: Loading animation from: $jsonPath for character: $characterId');

      // Load JSON first
      debugPrint('CharacterAnimationService: Reading JSON file: $jsonPath');
      final jsonStr = await Flame.assets.readFile(jsonPath);
      debugPrint(
          'CharacterAnimationService: JSON file read successfully, length: ${jsonStr.length}');

      final Map<String, dynamic> data = json.decode(jsonStr);
      final Map<String, dynamic> frames = data['frames'];
      debugPrint(
          'CharacterAnimationService: Parsed JSON, found ${frames.length} frames');

      // Load image with caching per character
      final String imageName = data['meta']['image'];
      debugPrint('CharacterAnimationService: Image name from JSON: $imageName');

      ui.Image image;

      final idleImageKey = '${characterId}_idle_$imageName';
      final walkingImageKey = '${characterId}_walking_$imageName';

      if (jsonPath.contains('idle') &&
          _cachedIdleImages.containsKey(idleImageKey)) {
        image = _cachedIdleImages[idleImageKey]!;
        debugPrint(
            'CharacterAnimationService: Using cached idle image for $characterId');
      } else if (jsonPath.contains('walking') &&
          _cachedWalkingImages.containsKey(walkingImageKey)) {
        image = _cachedWalkingImages[walkingImageKey]!;
        debugPrint(
            'CharacterAnimationService: Using cached walking image for $characterId');
      } else {
        debugPrint('CharacterAnimationService: Loading image: $imageName');
        image = await Flame.images.load(imageName);
        debugPrint(
            'CharacterAnimationService: Image loaded successfully, size: ${image.width}x${image.height}');

        // Cache the image per character
        if (jsonPath.contains('idle')) {
          _cachedIdleImages[idleImageKey] = image;
          debugPrint(
              'CharacterAnimationService: Cached idle image for $characterId');
        } else if (jsonPath.contains('walking')) {
          _cachedWalkingImages[walkingImageKey] = image;
          debugPrint(
              'CharacterAnimationService: Cached walking image for $characterId');
        }
      }

      final List<Sprite> spriteList = [];
      final frameKeys = frames.keys.toList()..sort();

      // Create sprites with reduced memory footdebugPrint
      debugPrint(
          'CharacterAnimationService: Creating ${frameKeys.length} sprites');
      for (final frameKey in frameKeys) {
        final frame = frames[frameKey]['frame'];
        final sprite = Sprite(
          image,
          srcPosition: Vector2(frame['x'].toDouble(), frame['y'].toDouble()),
          srcSize: Vector2(frame['w'].toDouble(), frame['h'].toDouble()),
        );
        spriteList.add(sprite);
      }

      debugPrint(
          'CharacterAnimationService: Loaded ${spriteList.length} frames for $jsonPath (character: $characterId)');
      return SpriteAnimation.spriteList(spriteList, stepTime: stepTime);
    } catch (e, st) {
      debugPrint(
          'CharacterAnimationService: Error loading animation from $jsonPath for character $characterId: $e');
      debugPrint('CharacterAnimationService: Stack trace: $st');
      rethrow;
    }
  }

  /// Get animations - returns cached versions if available, auto-reloads if character changed
  Future<Map<String, SpriteAnimation>> getAnimations() async {
    return getAnimationsForCharacter('current_user');
  }

  /// Get animations for a specific character
  Future<Map<String, SpriteAnimation>> getAnimationsForCharacter(
      String characterId) async {
    // Check if we need to reload due to character change (only for current user)
    if (characterId == 'current_user' && await needsReload()) {
      debugPrint(
          'CharacterAnimationService: Character changed, reloading animations...');
      await reloadAnimationsForCurrentCharacter();
    }

    if (_isLoaded[characterId] ?? false) {
      return {
        'idle': _cachedIdleAnimations[characterId]!,
        'walking': _cachedWalkingAnimations[characterId]!,
      };
    }

    // If not loaded, this is an error for opponent characters
    // They should be preloaded before calling this method
    throw StateError(
        'Animations not loaded for character: $characterId. Call preloadAnimationsForCharacterWithData first.');
  }

  /// Wait for animations to be loaded (useful for UI)
  Future<void> waitForLoad() async {
    await waitForLoadForCharacter('current_user');
  }

  /// Wait for animations to be loaded for a specific character
  Future<void> waitForLoadForCharacter(String characterId) async {
    // Check if we need to reload due to character change (only for current user)
    if (characterId == 'current_user' && await needsReload()) {
      debugPrint(
          'CharacterAnimationService: Character changed during wait, reloading...');
      await reloadAnimationsForCurrentCharacter();
      return;
    }

    if (_isLoaded[characterId] ?? false) return;

    while (_isLoading[characterId] == true) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!(_isLoaded[characterId] ?? false)) {
      if (characterId == 'current_user') {
        await preloadAnimations();
      } else {
        throw StateError(
            'Animations not loaded for character: $characterId. Call preloadAnimationsForCharacterWithData first.');
      }
    }
  }

  /// Get loading progress (0.0 to 1.0)
  double get loadingProgress {
    if (_isLoaded['current_user'] ?? false) return 1.0;
    if (!(_isLoading['current_user'] ?? false)) return 0.0;
    return 0.5;
  }

  /// Clear cache with proper disposal
  void clearCache() {
    clearCacheForCharacter('current_user');
  }

  /// Clear cache for a specific character
  void clearCacheForCharacter(String characterId) {
    // Clear references (SpriteAnimation doesn't have dispose method)
    _cachedIdleAnimations.remove(characterId);
    _cachedWalkingAnimations.remove(characterId);
    _isLoaded[characterId] = false;
    _isLoading[characterId] = false;
    _lastLoadTime.remove(characterId);
    _lastLoadedCharacterId.remove(characterId);

    // Clear associated images
    final keysToRemove = <String>[];
    for (final key in _cachedIdleImages.keys) {
      if (key.startsWith('${characterId}_')) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      _cachedIdleImages.remove(key);
    }

    keysToRemove.clear();
    for (final key in _cachedWalkingImages.keys) {
      if (key.startsWith('${characterId}_')) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      _cachedWalkingImages.remove(key);
    }

    debugPrint(
        'CharacterAnimationService: Cache cleared for character: $characterId');
  }

  /// Check if cache is stale (older than specified duration)
  bool isCacheStale(Duration maxAge) {
    final lastLoad = _lastLoadTime['current_user'];
    if (lastLoad == null) return true;
    return DateTime.now().difference(lastLoad) > maxAge;
  }

  /// Refresh cache if stale
  Future<void> refreshIfStale(Duration maxAge) async {
    if (isCacheStale(maxAge)) {
      debugPrint('CharacterAnimationService: Cache is stale, refreshing...');
      clearCache();
      await preloadAnimations();
    }
  }

  /// Dispose service resources
  void dispose() {
    clearCache();
  }

  /// Force garbage collection and memory cleanup
  void forceMemoryCleanup() {
    clearCache();
    // Force garbage collection if available
    try {
      // This is a best-effort approach to free memory
      debugPrint('CharacterAnimationService: Forcing memory cleanup');
    } catch (e) {
      debugPrint('CharacterAnimationService: Memory cleanup failed: $e');
    }
  }

  /// Check memory usage and cleanup if needed
  void checkMemoryUsage() {
    final lastLoad = _lastLoadTime['current_user'];
    if (lastLoad != null) {
      final age = DateTime.now().difference(lastLoad);
      if (age.inMinutes > 5) {
        debugPrint('CharacterAnimationService: Cache is old, cleaning up...');
        clearCache();
      }
    }
  }

  /// Handle character change event (called when user wears a different character)
  Future<void> onCharacterChanged(String newCharacterId) async {
    debugPrint(
        'CharacterAnimationService: Character changed to: $newCharacterId');

    // Clear cache and reload animations for the new character
    await reloadAnimationsForCurrentCharacter();
  }

  /// Get current character ID that animations are loaded for
  String? getCurrentLoadedCharacterId() {
    return _lastLoadedCharacterId['current_user'];
  }
}

extension _AnimPathNormalization on CharacterAnimationService {
  Map<String, String> _normalizeSpriteSheetPaths(Map<String, dynamic> raw) {
    String normalize(String path) {
      if (path.startsWith('assets/')) {
        path = path.substring(7);
      }
      final idx = path.indexOf('images/');
      if (idx > 0) path = path.substring(idx);
      return path;
    }

    final Map<String, String> result = {};
    if (raw['idle'] is String) result['idle'] = normalize(raw['idle']);
    if (raw['walking'] is String) {
      result['walking'] = normalize(raw['walking']);
    }
    return result;
  }
}
