import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/character_data_service.dart';

/// Test script to verify dynamic GLB loading functionality
class DynamicGlbTest {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final CharacterDataService _characterDataService =
      CharacterDataService();

  /// Test the current user's GLB path
  static Future<void> testCurrentUserGlbPath() async {
    try {
      print('🧪 Testing current user GLB path...');

      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print('❌ User document does not exist');
        return;
      }

      final userData = userDoc.data()!;
      final homeGlbPath = userData['homeGlbPath'] as String?;
      final currentCharacter = userData['currentCharacter'] as String?;

      print('📋 User Data:');
      print('  - currentCharacter: $currentCharacter');
      print('  - homeGlbPath: $homeGlbPath');

      if (homeGlbPath == null) {
        print('❌ homeGlbPath is null');
        return;
      }

      // Verify the path matches the character
      final expectedPath =
          CharacterDataService.characterHomeGlbPaths[currentCharacter];
      if (expectedPath == null) {
        print('❌ No expected path found for character: $currentCharacter');
        return;
      }

      if (homeGlbPath == expectedPath) {
        print(
            '✅ GLB path matches expected path for character: $currentCharacter');
      } else {
        print('❌ GLB path mismatch:');
        print('  - Expected: $expectedPath');
        print('  - Actual: $homeGlbPath');
      }
    } catch (e) {
      print('❌ Error testing current user GLB path: $e');
    }
  }

  /// Test GLB path updates when character changes
  static Future<void> testGlbPathUpdate() async {
    try {
      print('🧪 Testing GLB path update...');

      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      // Test switching to blossom character
      final testCharacter = 'blossom';
      final expectedPath =
          CharacterDataService.characterHomeGlbPaths[testCharacter];

      print('🔄 Switching to character: $testCharacter');
      print('📋 Expected path: $expectedPath');

      // Update the user's current character
      await _firestore.collection('users').doc(user.uid).update({
        'currentCharacter': testCharacter,
        'homeGlbPath': expectedPath,
      });

      // Verify the update
      final updatedDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final updatedData = updatedDoc.data()!;
      final actualPath = updatedData['homeGlbPath'] as String?;
      final actualCharacter = updatedData['currentCharacter'] as String?;

      print('📋 Updated Data:');
      print('  - currentCharacter: $actualCharacter');
      print('  - homeGlbPath: $actualPath');

      if (actualPath == expectedPath && actualCharacter == testCharacter) {
        print('✅ GLB path update successful');
      } else {
        print('❌ GLB path update failed');
      }
    } catch (e) {
      print('❌ Error testing GLB path update: $e');
    }
  }

  /// Test real-time listener functionality
  static Future<void> testRealTimeListener() async {
    try {
      print('🧪 Testing real-time listener...');

      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      bool listenerTriggered = false;
      String? lastPath;

      // Set up real-time listener
      final subscription = _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data()!;
          final path = data['homeGlbPath'] as String?;

          if (path != lastPath) {
            print('🔄 Real-time update detected:');
            print('  - Previous path: $lastPath');
            print('  - New path: $path');
            lastPath = path;
            listenerTriggered = true;
          }
        }
      });

      // Wait a moment for listener to be ready
      await Future.delayed(Duration(milliseconds: 500));

      // Trigger an update
      final testCharacter = 'sun';
      final expectedPath =
          CharacterDataService.characterHomeGlbPaths[testCharacter];

      print('🔄 Triggering update to: $testCharacter');
      await _firestore.collection('users').doc(user.uid).update({
        'currentCharacter': testCharacter,
        'homeGlbPath': expectedPath,
      });

      // Wait for listener to trigger
      await Future.delayed(Duration(seconds: 2));

      // Clean up
      await subscription.cancel();

      if (listenerTriggered) {
        print('✅ Real-time listener working correctly');
      } else {
        print('❌ Real-time listener did not trigger');
      }
    } catch (e) {
      print('❌ Error testing real-time listener: $e');
    }
  }

  /// Run all GLB tests
  static Future<void> runAllTests() async {
    print('🚀 Running all GLB tests...\n');

    await testCurrentUserGlbPath();
    print('');

    await testGlbPathUpdate();
    print('');

    await testRealTimeListener();
    print('');

    print('🏁 All GLB tests completed!');
  }
}
