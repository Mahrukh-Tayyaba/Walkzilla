import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/shop_service.dart';

/// Test script to verify shop wear functionality
class ShopWearTest {
  static final ShopService _shopService = ShopService();

  /// Test wearing a specific item
  static Future<void> testWearItem(String itemId) async {
    try {
      print('🧪 Testing wear item: $itemId');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      print('👤 User: ${user.email} (${user.uid})');

      // Get current state before wearing
      final beforeWear = await _shopService.getCurrentWornItem();
      print('📋 Before wearing: $beforeWear');

      // Try to wear the item
      final success = await _shopService.wearItem(itemId);
      print('🔄 Wear result: $success');

      if (success) {
        // Wait a moment for Firestore to update
        await Future.delayed(Duration(seconds: 2));

        // Get state after wearing
        final afterWear = await _shopService.getCurrentWornItem();
        print('📋 After wearing: $afterWear');

        // Verify the change
        if (afterWear == itemId) {
          print('✅ Wear item test passed!');
        } else {
          print('❌ Wear item test failed!');
          print('  - Expected: $itemId');
          print('  - Actual: $afterWear');
        }

        // Check Firestore directly
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final firestoreCharacter = userData['currentCharacter'] as String?;
          final firestoreGlbPath = userData['homeGlbPath'] as String?;
          
          print('📋 Firestore Data:');
          print('  - currentCharacter: $firestoreCharacter');
          print('  - homeGlbPath: $firestoreGlbPath');
          
          if (firestoreCharacter == itemId) {
            print('✅ Firestore update successful');
          } else {
            print('❌ Firestore update failed');
          }
        }
      } else {
        print('❌ Failed to wear item: $itemId');
      }

    } catch (e) {
      print('❌ Error testing wear item: $e');
    }
  }

  /// Test wearing blueStar specifically
  static Future<void> testWearBlueStar() async {
    await testWearItem('blueStar');
  }

  /// Test wearing blossom specifically
  static Future<void> testWearBlossom() async {
    await testWearItem('blossom');
  }

  /// Test wearing sun specifically
  static Future<void> testWearSun() async {
    await testWearItem('sun');
  }

  /// Run all wear tests
  static Future<void> runAllTests() async {
    print('🚀 Running all shop wear tests...\n');
    
    await testWearBlossom();
    print('');
    
    await testWearSun();
    print('');
    
    await testWearBlueStar();
    print('');
    
    print('🏁 All shop wear tests completed!');
  }
} 