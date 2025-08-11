import 'package:firebase_auth/firebase_auth.dart';
import 'character_animation_service.dart';
import 'character_data_service.dart';

class UserLoginService {
  static final UserLoginService _instance = UserLoginService._internal();
  factory UserLoginService() => _instance;
  UserLoginService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CharacterAnimationService _animationService =
      CharacterAnimationService();
  final CharacterDataService _characterDataService = CharacterDataService();

  /// Handle user login and initialize character animations
  Future<void> onUserLogin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('UserLoginService: No user logged in');
        return;
      }

      print('UserLoginService: User logged in: ${user.uid}');

      // Get current character data
      final characterData =
          await _characterDataService.getCurrentUserCharacterData();
      final currentCharacter = characterData['currentCharacter'] as String;

      print('UserLoginService: Current character: $currentCharacter');

      // Load animations for the current character
      await _animationService.preloadAnimationsForCharacter(currentCharacter);

      print('UserLoginService: Character animations loaded successfully');
    } catch (e) {
      print('UserLoginService: Error during login initialization: $e');
    }
  }

  /// Handle user logout and cleanup
  Future<void> onUserLogout() async {
    try {
      print('UserLoginService: User logged out, cleaning up animations...');

      // Clear animation cache with error handling
      try {
        _animationService.clearCache();
        print('UserLoginService: Animation cache cleared successfully');
      } catch (e) {
        print('UserLoginService: Error clearing animation cache: $e');
        // Try force memory cleanup as fallback
        try {
          _animationService.forceMemoryCleanup();
          print('UserLoginService: Force memory cleanup completed');
        } catch (fallbackError) {
          print(
              'UserLoginService: Force memory cleanup also failed: $fallbackError');
        }
      }

      print('UserLoginService: Cleanup completed');
    } catch (e) {
      print('UserLoginService: Error during logout cleanup: $e');
      // Don't rethrow - we want logout to continue even if cleanup fails
    }
  }

  /// Check if user is logged in and animations are loaded
  Future<bool> isUserReady() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check if animations are loaded for current character
      final currentCharacter =
          await _characterDataService.getCurrentCharacter();
      return _animationService.isLoadedForCharacter(currentCharacter);
    } catch (e) {
      print('UserLoginService: Error checking user readiness: $e');
      return false;
    }
  }

  /// Force reload animations for current user
  Future<void> reloadCurrentUserAnimations() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('UserLoginService: Reloading animations for current user...');
      await _animationService.reloadAnimationsForCurrentCharacter();
      print('UserLoginService: Animations reloaded successfully');
    } catch (e) {
      print('UserLoginService: Error reloading animations: $e');
    }
  }
}
