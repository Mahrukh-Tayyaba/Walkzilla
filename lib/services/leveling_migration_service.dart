import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'leveling_service.dart';

class LevelingMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize leveling data for all existing users
  static Future<void> initializeAllUsersLevelingData() async {
    try {
      print('🔄 Starting leveling data initialization for all users...');

      final usersSnapshot = await _firestore.collection('users').get();
      int processedCount = 0;
      int skippedCount = 0;

      for (var doc in usersSnapshot.docs) {
        final userData = doc.data();

        // Skip if already has leveling data
        if (userData['totalLifetimeSteps'] != null) {
          skippedCount++;
          continue;
        }

        try {
          await _initializeUserLevelingData(doc.id, userData);
          processedCount++;

          // Add small delay to avoid overwhelming Firestore
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('❌ Error initializing leveling data for user ${doc.id}: $e');
        }
      }

      print('✅ Leveling data initialization completed!');
      print('📊 Processed: $processedCount users');
      print('📊 Skipped: $skippedCount users (already had data)');
    } catch (e) {
      print('❌ Error during leveling data initialization: $e');
    }
  }

  /// Initialize leveling data for a specific user
  static Future<void> _initializeUserLevelingData(
      String userId, Map<String, dynamic> userData) async {
    try {
      // Calculate total lifetime steps from daily steps
      Map<String, dynamic> dailySteps = userData['daily_steps'] ?? {};
      int totalLifetimeSteps = 0;

      for (var steps in dailySteps.values) {
        if (steps is int) {
          totalLifetimeSteps += steps;
        } else if (steps is num) {
          totalLifetimeSteps += steps.toInt();
        }
      }

      int currentStreak = userData['currentStreak'] ?? 0;
      // For migration, start with base level only
      int level = LevelingService.calculateBaseLevel(totalLifetimeSteps);

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'totalLifetimeSteps': totalLifetimeSteps,
        'level': level,
        'achievedMilestones': [], // Initialize empty for existing users
        'lastLevelUpdate': FieldValue.serverTimestamp(),
        'levelUpHistory': [],
        'challenges_won': userData['challenges_won'] ?? 0,
      });

      print(
          '✅ Initialized leveling data for user $userId: Level $level, $totalLifetimeSteps steps');
    } catch (e) {
      print('❌ Error initializing leveling data for user $userId: $e');
      rethrow;
    }
  }

  /// Initialize leveling data for current user only
  static Future<void> initializeCurrentUserLevelingData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No current user found');
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print('❌ User document not found');
        return;
      }

      final userData = userDoc.data()!;

      // Skip if already has leveling data
      if (userData['totalLifetimeSteps'] != null) {
        print('ℹ️ User already has leveling data initialized');
        return;
      }

      await _initializeUserLevelingData(user.uid, userData);
    } catch (e) {
      print('❌ Error initializing current user leveling data: $e');
    }
  }

  /// Recalculate leveling data for all users (useful for updates)
  static Future<void> recalculateAllUsersLevelingData() async {
    try {
      print('🔄 Starting leveling data recalculation for all users...');

      final usersSnapshot = await _firestore.collection('users').get();
      int processedCount = 0;

      for (var doc in usersSnapshot.docs) {
        final userData = doc.data();

        try {
          // Calculate total lifetime steps from daily steps
          Map<String, dynamic> dailySteps = userData['daily_steps'] ?? {};
          int totalLifetimeSteps = 0;

          for (var steps in dailySteps.values) {
            if (steps is int) {
              totalLifetimeSteps += steps;
            } else if (steps is num) {
              totalLifetimeSteps += steps.toInt();
            }
          }

          int currentStreak = userData['currentStreak'] ?? 0;
          // For migration, start with base level only
          int level = LevelingService.calculateBaseLevel(totalLifetimeSteps);

          // Update user document
          await _firestore.collection('users').doc(doc.id).update({
            'totalLifetimeSteps': totalLifetimeSteps,
            'level': level,
            'achievedMilestones': [], // Initialize empty for existing users
            'lastLevelUpdate': FieldValue.serverTimestamp(),
            'challenges_won': userData['challenges_won'] ?? 0,
          });

          processedCount++;

          // Add small delay to avoid overwhelming Firestore
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('❌ Error recalculating leveling data for user ${doc.id}: $e');
        }
      }

      print('✅ Leveling data recalculation completed!');
      print('📊 Processed: $processedCount users');
    } catch (e) {
      print('❌ Error during leveling data recalculation: $e');
    }
  }

  /// Create sample leveling data for testing
  static Future<void> createSampleLevelingData() async {
    try {
      print('🔄 Creating sample leveling data...');

      final usersSnapshot = await _firestore.collection('users').limit(5).get();

      for (var doc in usersSnapshot.docs) {
        final userData = doc.data();

        // Skip if already has leveling data
        if (userData['totalLifetimeSteps'] != null) continue;

        // Create sample daily steps data
        Map<String, dynamic> sampleDailySteps = {};
        final now = DateTime.now();

        // Generate 30 days of sample data
        for (int i = 0; i < 30; i++) {
          final date = now.subtract(Duration(days: i));
          final dateKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

          // Random steps between 5000 and 15000
          final randomSteps =
              5000 + (DateTime.now().millisecondsSinceEpoch % 10000);
          sampleDailySteps[dateKey] = randomSteps;
        }

        // Calculate total and level
        int totalLifetimeSteps = 0;
        for (var steps in sampleDailySteps.values) {
          totalLifetimeSteps += steps as int;
        }

        int currentStreak = 7; // Sample streak
        int level = LevelingService.calculateTotalLevel(
            totalLifetimeSteps, currentStreak);

        // Update user document
        await _firestore.collection('users').doc(doc.id).update({
          'daily_steps': sampleDailySteps,
          'totalLifetimeSteps': totalLifetimeSteps,
          'currentStreak': currentStreak,
          'level': level,
          'lastLevelUpdate': FieldValue.serverTimestamp(),
          'levelUpHistory': [],
        });

        print(
            '✅ Created sample data for user ${doc.id}: Level $level, $totalLifetimeSteps steps');
      }

      print('✅ Sample leveling data creation completed!');
    } catch (e) {
      print('❌ Error creating sample leveling data: $e');
    }
  }

  /// Initialize challenges_won field for all existing users
  static Future<void> initializeChallengesWonForAllUsers() async {
    try {
      print('🔄 Starting challenges_won initialization for all users...');

      final usersSnapshot = await _firestore.collection('users').get();
      int processedCount = 0;
      int skippedCount = 0;

      for (var doc in usersSnapshot.docs) {
        final userData = doc.data();

        // Skip if already has challenges_won field
        if (userData['challenges_won'] != null) {
          skippedCount++;
          continue;
        }

        try {
          await _firestore.collection('users').doc(doc.id).update({
            'challenges_won': 0,
          });
          processedCount++;

          // Add small delay to avoid overwhelming Firestore
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('❌ Error initializing challenges_won for user ${doc.id}: $e');
        }
      }

      print('✅ Challenges_won initialization completed!');
      print('📊 Processed: $processedCount users');
      print('📊 Skipped: $skippedCount users (already had field)');
    } catch (e) {
      print('❌ Error during challenges_won initialization: $e');
    }
  }
}
