import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LeaderboardMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize leaderboard data for all existing users
  Future<void> initializeAllUsersLeaderboardData() async {
    try {
      print('🔄 Starting leaderboard data initialization for all users...');

      final usersSnapshot = await _firestore.collection('users').get();
      int processedCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        try {
          await initializeUserLeaderboardData(userDoc.id);
          processedCount++;
        } catch (e) {
          print('❌ Error initializing data for user ${userDoc.id}: $e');
        }
      }

      print(
          '✅ Successfully initialized leaderboard data for $processedCount users');
    } catch (e) {
      print('❌ Error in bulk leaderboard initialization: $e');
    }
  }

  /// Initialize leaderboard data for a specific user
  Future<void> initializeUserLeaderboardData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ User document not found: $userId');
        return;
      }

      final userData = userDoc.data()!;

      // Check if leaderboard data already exists
      if (userData.containsKey('weekly_steps') &&
          userData.containsKey('daily_steps')) {
        print('✅ User $userId already has leaderboard data');
        return;
      }

      // Initialize leaderboard fields
      final updateData = <String, dynamic>{
        'daily_steps': userData['daily_steps'] ?? {},
        'weekly_steps': userData['weekly_steps'] ?? 0,
        'coins': userData['coins'] ?? 0,
        'last_week_rewarded': userData['last_week_rewarded'] ?? null,
        'last_month_rewarded': userData['last_month_rewarded'] ?? null,
      };

      await _firestore.collection('users').doc(userId).update(updateData);
      print('✅ Initialized leaderboard data for user: $userId');
    } catch (e) {
      print('❌ Error initializing leaderboard data for user $userId: $e');
    }
  }

  /// Migrate existing step data to leaderboard format
  Future<void> migrateExistingStepData() async {
    try {
      print('🔄 Starting step data migration...');

      final usersSnapshot = await _firestore.collection('users').get();
      int migratedCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        try {
          await _migrateUserStepData(userDoc.id);
          migratedCount++;
        } catch (e) {
          print('❌ Error migrating data for user ${userDoc.id}: $e');
        }
      }

      print('✅ Successfully migrated step data for $migratedCount users');
    } catch (e) {
      print('❌ Error in step data migration: $e');
    }
  }

  /// Migrate step data for a specific user
  Future<void> _migrateUserStepData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Check if we have any existing step data to migrate
      int existingSteps = 0;

      // Look for existing step data in various possible fields
      if (userData.containsKey('steps')) {
        existingSteps = userData['steps'] ?? 0;
      } else if (userData.containsKey('daily_steps') &&
          userData['daily_steps'] is Map &&
          userData['daily_steps'][today] != null) {
        existingSteps = userData['daily_steps'][today] ?? 0;
      }

      if (existingSteps > 0) {
        // Update daily steps for today
        await _firestore.collection('users').doc(userId).update({
          'daily_steps.$today': existingSteps,
        });

        print('✅ Migrated $existingSteps steps for user: $userId');
      }
    } catch (e) {
      print('❌ Error migrating step data for user $userId: $e');
    }
  }

  /// Calculate and update weekly/monthly totals for all users
  Future<void> recalculateAllUserTotals() async {
    try {
      print('🔄 Starting total recalculation for all users...');

      final usersSnapshot = await _firestore.collection('users').get();
      int processedCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        try {
          await _recalculateUserTotals(userDoc.id);
          processedCount++;
        } catch (e) {
          print('❌ Error recalculating totals for user ${userDoc.id}: $e');
        }
      }

      print('✅ Successfully recalculated totals for $processedCount users');
    } catch (e) {
      print('❌ Error in total recalculation: $e');
    }
  }

  /// Recalculate weekly totals for a specific user
  Future<void> _recalculateUserTotals(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final dailySteps = userData['daily_steps'] as Map<String, dynamic>? ?? {};

      if (dailySteps.isEmpty) return;

      final now = DateTime.now();
      final startOfWeek = _getStartOfWeek(now);

      int weeklyTotal = 0;

      // Calculate totals from daily steps
      dailySteps.forEach((dateStr, steps) {
        try {
          final date = DateTime.parse(dateStr);
          final stepsInt =
              steps is int ? steps : int.tryParse(steps.toString()) ?? 0;

          if (date.isAfter(startOfWeek)) {
            weeklyTotal += stepsInt;
          }
        } catch (e) {
          print('❌ Error parsing date $dateStr: $e');
        }
      });

      // Update totals
      await _firestore.collection('users').doc(userId).update({
        'weekly_steps': weeklyTotal,
      });

      print('✅ Recalculated totals for user $userId: Weekly=$weeklyTotal');
    } catch (e) {
      print('❌ Error recalculating totals for user $userId: $e');
    }
  }

  /// Get start of current week (Monday)
  DateTime _getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return date.subtract(Duration(days: daysFromMonday));
  }
}
