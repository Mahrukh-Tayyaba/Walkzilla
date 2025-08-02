import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/character_animation_service.dart';
import 'services/character_data_service.dart';
import 'services/shop_service.dart';
import 'services/user_login_service.dart';

/// Test script to verify dynamic sprite sheet loading
class DynamicAnimationTest {
  static final CharacterAnimationService _animationService =
      CharacterAnimationService();
  static final CharacterDataService _characterDataService =
      CharacterDataService();
  static final ShopService _shopService = ShopService();
  static final UserLoginService _userLoginService = UserLoginService();

  /// Test the complete dynamic animation system
  static Future<void> runAllTests() async {
    print('🎬 Testing Dynamic Animation System...\n');

    try {
      // Test 1: Initial login animation loading
      await testInitialLoginLoading();

      // Test 2: Character switching and animation reloading
      await testCharacterSwitching();

      // Test 3: Buy and wear flow with animation updates
      await testBuyAndWearFlow();

      // Test 4: Animation caching and performance
      await testAnimationCaching();

      print('✅ All dynamic animation tests completed successfully!');
    } catch (error) {
      print('❌ Error during dynamic animation tests: $error');
    }
  }

  /// Test initial login animation loading
  static Future<void> testInitialLoginLoading() async {
    print('🔍 Test 1: Initial Login Animation Loading');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in, skipping test');
        return;
      }

      // Get current character data
      final characterData =
          await _characterDataService.getCurrentUserCharacterData();
      final currentCharacter = characterData['currentCharacter'] as String;
      final spriteSheets = characterData['spriteSheets'] as Map<String, String>;

      print('📊 Current character: $currentCharacter');
      print('📊 Sprite sheets: $spriteSheets');

      // Test login service
      await _userLoginService.onUserLogin();

      // Verify animations are loaded
      final animations = await _animationService.getAnimations();
      final loadedCharacterId = _animationService.getCurrentLoadedCharacterId();

      print('✅ Animations loaded: ${animations.keys.join(', ')}');
      print('✅ Loaded for character: $loadedCharacterId');
      print('✅ Character matches: ${loadedCharacterId == currentCharacter}');

      if (loadedCharacterId != currentCharacter) {
        throw Exception(
            'Character mismatch: expected $currentCharacter, got $loadedCharacterId');
      }

      print('✅ Test 1 passed: Initial login animation loading\n');
    } catch (error) {
      print('❌ Test 1 failed: $error\n');
      rethrow;
    }
  }

  /// Test character switching and animation reloading
  static Future<void> testCharacterSwitching() async {
    print('🔄 Test 2: Character Switching and Animation Reloading');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in, skipping test');
        return;
      }

      // Get current character
      final currentCharacter =
          await _characterDataService.getCurrentCharacter();
      print('📊 Current character: $currentCharacter');

      // Test switching to a different character (if available)
      final ownedCharacters = await _characterDataService.getOwnedCharacters();
      final testCharacter = ownedCharacters.firstWhere(
        (char) => char != currentCharacter,
        orElse: () => currentCharacter,
      );

      if (testCharacter == currentCharacter) {
        print('ℹ️ Only one character owned, testing reload of same character');
      } else {
        print('📊 Testing switch to: $testCharacter');

        // Switch character
        await _characterDataService.updateCurrentCharacter(testCharacter);

        // Verify animation service detects the change
        final needsReload = await _animationService.needsReload();
        print('📊 Needs reload: $needsReload');

        if (!needsReload) {
          throw Exception('Animation service should detect character change');
        }

        // Trigger reload
        await _animationService.reloadAnimationsForCurrentCharacter();
      }

      // Verify animations are loaded for the correct character
      final loadedCharacterId = _animationService.getCurrentLoadedCharacterId();
      final expectedCharacter =
          testCharacter != currentCharacter ? testCharacter : currentCharacter;

      print('✅ Loaded for character: $loadedCharacterId');
      print('✅ Expected character: $expectedCharacter');
      print('✅ Character matches: ${loadedCharacterId == expectedCharacter}');

      if (loadedCharacterId != expectedCharacter) {
        throw Exception(
            'Character mismatch after switch: expected $expectedCharacter, got $loadedCharacterId');
      }

      print('✅ Test 2 passed: Character switching and animation reloading\n');
    } catch (error) {
      print('❌ Test 2 failed: $error\n');
      rethrow;
    }
  }

  /// Test buy and wear flow with animation updates
  static Future<void> testBuyAndWearFlow() async {
    print('🛒 Test 3: Buy and Wear Flow with Animation Updates');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in, skipping test');
        return;
      }

      // Get current character and owned items
      final currentCharacter =
          await _characterDataService.getCurrentCharacter();
      final ownedItems = await _shopService.getOwnedItems();

      print('📊 Current character: $currentCharacter');
      print('📊 Owned items: $ownedItems');

      // Find a character to buy (if we have enough coins)
      final shopItems = await _shopService.getShopItems();
      final affordableItem = shopItems.firstWhere(
        (item) => !ownedItems.contains(item.id) && item.price <= 100,
        orElse: () => shopItems.first,
      );

      if (ownedItems.contains(affordableItem.id)) {
        print('ℹ️ Already own affordable item, testing wear flow only');

        // Test wearing an owned item
        final success = await _shopService.wearItem(affordableItem.id);
        print('📊 Wear success: $success');

        if (!success) {
          throw Exception('Failed to wear owned item');
        }

        // Verify animation reload was triggered
        final loadedCharacterId =
            _animationService.getCurrentLoadedCharacterId();
        print('✅ Loaded for character: $loadedCharacterId');
        print('✅ Expected character: ${affordableItem.id}');
        print('✅ Character matches: ${loadedCharacterId == affordableItem.id}');

        if (loadedCharacterId != affordableItem.id) {
          throw Exception(
              'Character mismatch after wear: expected ${affordableItem.id}, got $loadedCharacterId');
        }
      } else {
        print('📊 Testing buy and wear flow for: ${affordableItem.id}');

        // Buy the item
        final buySuccess = await _shopService.buyItem(affordableItem.id);
        print('📊 Buy success: $buySuccess');

        if (!buySuccess) {
          print(
              'ℹ️ Buy failed (likely insufficient coins), testing wear of existing item');
          // Test wearing an existing item instead
          final existingItem =
              ownedItems.firstWhere((id) => id != currentCharacter);
          final wearSuccess = await _shopService.wearItem(existingItem);
          print('📊 Wear success: $wearSuccess');

          if (!wearSuccess) {
            throw Exception('Failed to wear existing item');
          }
        } else {
          // Wear the newly bought item
          final wearSuccess = await _shopService.wearItem(affordableItem.id);
          print('📊 Wear success: $wearSuccess');

          if (!wearSuccess) {
            throw Exception('Failed to wear newly bought item');
          }
        }
      }

      print('✅ Test 3 passed: Buy and wear flow with animation updates\n');
    } catch (error) {
      print('❌ Test 3 failed: $error\n');
      rethrow;
    }
  }

  /// Test animation caching and performance
  static Future<void> testAnimationCaching() async {
    print('⚡ Test 4: Animation Caching and Performance');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in, skipping test');
        return;
      }

      // Test initial loading
      final startTime = DateTime.now();
      await _animationService.preloadAnimations();
      final initialLoadTime = DateTime.now().difference(startTime);

      print('📊 Initial load time: ${initialLoadTime.inMilliseconds}ms');

      // Test cached loading (should be faster)
      final cachedStartTime = DateTime.now();
      await _animationService.getAnimations();
      final cachedLoadTime = DateTime.now().difference(cachedStartTime);

      print('📊 Cached load time: ${cachedLoadTime.inMilliseconds}ms');

      // Verify caching is working
      if (cachedLoadTime.inMilliseconds >= initialLoadTime.inMilliseconds) {
        print(
            '⚠️ Cached loading not significantly faster than initial loading');
      } else {
        print('✅ Caching is working: cached loading is faster');
      }

      // Test cache status
      final isLoaded = _animationService.isLoaded;
      final isLoading = _animationService.isLoading;
      final lastLoadTime = _animationService.lastLoadTime;

      print('📊 Is loaded: $isLoaded');
      print('📊 Is loading: $isLoading');
      print('📊 Last load time: $lastLoadTime');

      if (!isLoaded) {
        throw Exception('Animations should be loaded after preload');
      }

      if (isLoading) {
        throw Exception('Animations should not be loading after preload');
      }

      // Test cache clearing
      _animationService.clearCache();
      final isLoadedAfterClear = _animationService.isLoaded;

      print('📊 Is loaded after clear: $isLoadedAfterClear');

      if (isLoadedAfterClear) {
        throw Exception('Cache should be cleared');
      }

      print('✅ Test 4 passed: Animation caching and performance\n');
    } catch (error) {
      print('❌ Test 4 failed: $error\n');
      rethrow;
    }
  }

  /// Test specific character animation loading
  static Future<void> testSpecificCharacter(String characterId) async {
    print('🎯 Testing specific character: $characterId');

    try {
      // Load animations for specific character
      await _animationService.preloadAnimationsForCharacter(characterId);

      // Verify animations are loaded
      final animations = await _animationService.getAnimations();
      final loadedCharacterId = _animationService.getCurrentLoadedCharacterId();

      print('✅ Animations loaded: ${animations.keys.join(', ')}');
      print('✅ Loaded for character: $loadedCharacterId');
      print('✅ Character matches: ${loadedCharacterId == characterId}');

      if (loadedCharacterId != characterId) {
        throw Exception(
            'Character mismatch: expected $characterId, got $loadedCharacterId');
      }

      print('✅ Specific character test passed: $characterId');
    } catch (error) {
      print('❌ Specific character test failed for $characterId: $error');
      rethrow;
    }
  }
}
