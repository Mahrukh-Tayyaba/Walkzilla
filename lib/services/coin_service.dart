import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CoinService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's coin balance
  Future<int> getCurrentUserCoins() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 0;

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (userDoc.exists) {
        return userDoc.data()?['coins'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting user coins: $e');
      return 0;
    }
  }

  /// Stream to listen to coin balance changes
  Stream<int> getCurrentUserCoinsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .map((doc) => doc.data()?['coins'] ?? 0);
  }

  /// Add coins to current user
  Future<bool> addCoins(int amount) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      await _firestore.collection('users').doc(currentUser.uid).update({
        'coins': FieldValue.increment(amount),
      });

      return true;
    } catch (e) {
      print('Error adding coins: $e');
      return false;
    }
  }

  /// Deduct coins from current user
  Future<bool> deductCoins(int amount) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Check if user has enough coins
      final currentCoins = await getCurrentUserCoins();
      if (currentCoins < amount) {
        return false; // Insufficient coins
      }

      await _firestore.collection('users').doc(currentUser.uid).update({
        'coins': FieldValue.increment(-amount),
      });

      return true;
    } catch (e) {
      print('Error deducting coins: $e');
      return false;
    }
  }

  /// Set coins for current user (for admin purposes)
  Future<bool> setCoins(int amount) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Prevent setting negative coins
      if (amount < 0) {
        print('Error: Cannot set coins to negative value: $amount');
        return false;
      }

      await _firestore.collection('users').doc(currentUser.uid).update({
        'coins': amount,
      });

      return true;
    } catch (e) {
      print('Error setting coins: $e');
      return false;
    }
  }

  /// Check if user has enough coins
  Future<bool> hasEnoughCoins(int requiredAmount) async {
    final currentCoins = await getCurrentUserCoins();
    return currentCoins >= requiredAmount;
  }

  /// Get coins for a specific user (for admin/friend purposes)
  Future<int> getUserCoins(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        return userDoc.data()?['coins'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting user coins: $e');
      return 0;
    }
  }

  /// Initialize coins for existing users who don't have coins field
  Future<void> initializeCoinsForExistingUsers() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (userDoc.exists && !userDoc.data()!.containsKey('coins')) {
        // User exists but doesn't have coins field, initialize with 100
        await _firestore.collection('users').doc(currentUser.uid).update({
          'coins': 100,
        });
        print('Initialized coins for existing user: ${currentUser.uid}');
      }
    } catch (e) {
      print('Error initializing coins for existing user: $e');
    }
  }
}
