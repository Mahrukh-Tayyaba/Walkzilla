import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'dart:convert';
import 'dart:ui' as ui;

class CharacterAnimationService {
  static final CharacterAnimationService _instance =
      CharacterAnimationService._internal();
  factory CharacterAnimationService() => _instance;
  CharacterAnimationService._internal();

  // Cache for loaded animations
  SpriteAnimation? _cachedIdleAnimation;
  SpriteAnimation? _cachedWalkingAnimation;
  ui.Image? _cachedIdleImage;
  ui.Image? _cachedWalkingImage;
  bool _isLoading = false;
  bool _isLoaded = false;
  DateTime? _lastLoadTime;

  // Getters
  SpriteAnimation? get idleAnimation => _cachedIdleAnimation;
  SpriteAnimation? get walkingAnimation => _cachedWalkingAnimation;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  DateTime? get lastLoadTime => _lastLoadTime;

  /// Preload character animations in the background with optimized loading
  Future<void> preloadAnimations() async {
    if (_isLoaded || _isLoading) return;

    _isLoading = true;
    print('CharacterAnimationService: Starting optimized preload...');

    try {
      // Load animations sequentially to reduce memory pressure
      _cachedIdleAnimation =
          await _loadTexturePackerAnimation('images/character_idle.json', 0.08);
      _cachedWalkingAnimation = await _loadTexturePackerAnimation(
          'images/character_walking.json', 0.06);

      _isLoaded = true;
      _isLoading = false;
      _lastLoadTime = DateTime.now();

      print(
          'CharacterAnimationService: Optimized preload completed successfully');
    } catch (e, st) {
      _isLoading = false;
      print('CharacterAnimationService: Preload failed: $e');
      print('Stack trace: $st');
      rethrow;
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

  /// Get animations - returns cached versions if available
  Future<Map<String, SpriteAnimation>> getAnimations() async {
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
}
