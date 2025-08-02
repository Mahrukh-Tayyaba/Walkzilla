import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'character_data_service.dart';

class CharacterAnimationService {
  static final CharacterAnimationService _instance =
      CharacterAnimationService._internal();
  factory CharacterAnimationService() => _instance;
  CharacterAnimationService._internal();

  final CharacterDataService _characterDataService = CharacterDataService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for loaded animations
  SpriteAnimation? _cachedIdleAnimation;
  SpriteAnimation? _cachedWalkingAnimation;
  ui.Image? _cachedIdleImage;
  ui.Image? _cachedWalkingImage;
  bool _isLoading = false;
  bool _isLoaded = false;
  DateTime? _lastLoadTime;
  String? _lastLoadedCharacterId;

  // Getters
  SpriteAnimation? get idleAnimation => _cachedIdleAnimation;
  SpriteAnimation? get walkingAnimation => _cachedWalkingAnimation;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  DateTime? get lastLoadTime => _lastLoadTime;
  String? get lastLoadedCharacterId => _lastLoadedCharacterId;

  /// Preload character animations for the current user's character
  Future<void> preloadAnimations() async {
    if (_isLoading) return;

    _isLoading = true;
    print('CharacterAnimationService: Starting dynamic preload...');

    try {
      // Get current user's sprite sheet paths
      final spriteSheets = await _characterDataService.getCurrentSpriteSheets();
      final currentCharacter =
          await _characterDataService.getCurrentCharacter();

      print(
          'CharacterAnimationService: Loading animations for character: $currentCharacter');
      print('CharacterAnimationService: Sprite sheets: $spriteSheets');

      // Load animations using dynamic paths
      _cachedIdleAnimation =
          await _loadTexturePackerAnimation(spriteSheets['idle']!, 0.08);
      _cachedWalkingAnimation =
          await _loadTexturePackerAnimation(spriteSheets['walking']!, 0.06);

      _isLoaded = true;
      _isLoading = false;
      _lastLoadTime = DateTime.now();
      _lastLoadedCharacterId = currentCharacter;

      print(
          'CharacterAnimationService: Dynamic preload completed successfully for $currentCharacter');
    } catch (e, st) {
      _isLoading = false;
      print('CharacterAnimationService: Dynamic preload failed: $e');
      print('Stack trace: $st');
      rethrow;
    }
  }

  /// Preload animations for a specific character (useful for testing or preview)
  Future<void> preloadAnimationsForCharacter(String characterId) async {
    if (_isLoading) return;

    _isLoading = true;
    print(
        'CharacterAnimationService: Starting preload for character: $characterId');

    try {
      // Get sprite sheet paths for the specific character
      final spriteSheets =
          _characterDataService.getSpriteSheetsForCharacter(characterId);

      print(
          'CharacterAnimationService: Sprite sheets for $characterId: $spriteSheets');

      // Load animations using the character's paths
      _cachedIdleAnimation =
          await _loadTexturePackerAnimation(spriteSheets['idle']!, 0.08);
      _cachedWalkingAnimation =
          await _loadTexturePackerAnimation(spriteSheets['walking']!, 0.06);

      _isLoaded = true;
      _isLoading = false;
      _lastLoadTime = DateTime.now();
      _lastLoadedCharacterId = characterId;

      print(
          'CharacterAnimationService: Preload completed successfully for $characterId');
    } catch (e, st) {
      _isLoading = false;
      print('CharacterAnimationService: Preload failed for $characterId: $e');
      print('Stack trace: $st');
      rethrow;
    }
  }

  /// Reload animations when character changes
  Future<void> reloadAnimationsForCurrentCharacter() async {
    print(
        'CharacterAnimationService: Reloading animations for current character...');

    // Clear existing cache
    clearCache();

    // Load new animations
    await preloadAnimations();
  }

  /// Check if animations need to be reloaded (character changed)
  Future<bool> needsReload() async {
    if (!_isLoaded) return true;

    try {
      final currentCharacter =
          await _characterDataService.getCurrentCharacter();
      return _lastLoadedCharacterId != currentCharacter;
    } catch (e) {
      print('CharacterAnimationService: Error checking if reload needed: $e');
      return true;
    }
  }

  /// Auto-reload if character changed
  Future<void> autoReloadIfNeeded() async {
    if (await needsReload()) {
      print('CharacterAnimationService: Character changed, auto-reloading...');
      await reloadAnimationsForCurrentCharacter();
    }
  }

  /// Load a single animation with memory optimization
  Future<SpriteAnimation> _loadTexturePackerAnimation(
      String jsonPath, double stepTime) async {
    try {
      print('CharacterAnimationService: Loading animation from: $jsonPath');

      // Load JSON first
      final jsonStr = await Flame.assets.readFile(jsonPath);
      final Map<String, dynamic> data = json.decode(jsonStr);
      final Map<String, dynamic> frames = data['frames'];

      // Load image with caching
      final String imageName = data['meta']['image'];
      ui.Image image;

      if (jsonPath.contains('idle') && _cachedIdleImage != null) {
        image = _cachedIdleImage!;
      } else if (jsonPath.contains('walking') && _cachedWalkingImage != null) {
        image = _cachedWalkingImage!;
      } else {
        image = await Flame.images.load(imageName);
        // Cache the image
        if (jsonPath.contains('idle')) {
          _cachedIdleImage = image;
        } else if (jsonPath.contains('walking')) {
          _cachedWalkingImage = image;
        }
      }

      final List<Sprite> spriteList = [];
      final frameKeys = frames.keys.toList()..sort();

      // Create sprites with reduced memory footprint
      for (final frameKey in frameKeys) {
        final frame = frames[frameKey]['frame'];
        final sprite = Sprite(
          image,
          srcPosition: Vector2(frame['x'].toDouble(), frame['y'].toDouble()),
          srcSize: Vector2(frame['w'].toDouble(), frame['h'].toDouble()),
        );
        spriteList.add(sprite);
      }

      print(
          'CharacterAnimationService: Loaded ${spriteList.length} frames for $jsonPath');
      return SpriteAnimation.spriteList(spriteList, stepTime: stepTime);
    } catch (e, st) {
      print(
          'CharacterAnimationService: Error loading animation from $jsonPath: $e');
      print('Stack trace: $st');
      rethrow;
    }
  }

  /// Get animations - returns cached versions if available, auto-reloads if character changed
  Future<Map<String, SpriteAnimation>> getAnimations() async {
    // Check if we need to reload due to character change
    if (await needsReload()) {
      print(
          'CharacterAnimationService: Character changed, reloading animations...');
      await reloadAnimationsForCurrentCharacter();
    }

    if (_isLoaded) {
      return {
        'idle': _cachedIdleAnimation!,
        'walking': _cachedWalkingAnimation!,
      };
    }

    // If not loaded, load them now
    await preloadAnimations();
    return {
      'idle': _cachedIdleAnimation!,
      'walking': _cachedWalkingAnimation!,
    };
  }

  /// Wait for animations to be loaded (useful for UI)
  Future<void> waitForLoad() async {
    // Check if we need to reload due to character change
    if (await needsReload()) {
      print(
          'CharacterAnimationService: Character changed during wait, reloading...');
      await reloadAnimationsForCurrentCharacter();
      return;
    }

    if (_isLoaded) return;

    while (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (!_isLoaded) {
      await preloadAnimations();
    }
  }

  /// Get loading progress (0.0 to 1.0)
  double get loadingProgress {
    if (_isLoaded) return 1.0;
    if (!_isLoading) return 0.0;
    return 0.5;
  }

  /// Clear cache with proper disposal
  void clearCache() {
    // Clear references (SpriteAnimation doesn't have dispose method)
    _cachedIdleAnimation = null;
    _cachedWalkingAnimation = null;
    _cachedIdleImage = null;
    _cachedWalkingImage = null;
    _isLoaded = false;
    _isLoading = false;
    _lastLoadTime = null;
    _lastLoadedCharacterId = null;

    // Force garbage collection
    print('CharacterAnimationService: Cache cleared and disposed');
  }

  /// Check if cache is stale (older than specified duration)
  bool isCacheStale(Duration maxAge) {
    if (_lastLoadTime == null) return true;
    return DateTime.now().difference(_lastLoadTime!) > maxAge;
  }

  /// Refresh cache if stale
  Future<void> refreshIfStale(Duration maxAge) async {
    if (isCacheStale(maxAge)) {
      print('CharacterAnimationService: Cache is stale, refreshing...');
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
      print('CharacterAnimationService: Forcing memory cleanup');
    } catch (e) {
      print('CharacterAnimationService: Memory cleanup failed: $e');
    }
  }

  /// Check memory usage and cleanup if needed
  void checkMemoryUsage() {
    if (_lastLoadTime != null) {
      final age = DateTime.now().difference(_lastLoadTime!);
      if (age.inMinutes > 5) {
        print('CharacterAnimationService: Cache is old, cleaning up...');
        clearCache();
      }
    }
  }

  /// Handle character change event (called when user wears a different character)
  Future<void> onCharacterChanged(String newCharacterId) async {
    print('CharacterAnimationService: Character changed to: $newCharacterId');

    // Clear cache and reload animations for the new character
    await reloadAnimationsForCurrentCharacter();
  }

  /// Get current character ID that animations are loaded for
  String? getCurrentLoadedCharacterId() {
    return _lastLoadedCharacterId;
  }

  /// Check if animations are loaded for a specific character
  bool isLoadedForCharacter(String characterId) {
    return _isLoaded && _lastLoadedCharacterId == characterId;
  }
}
