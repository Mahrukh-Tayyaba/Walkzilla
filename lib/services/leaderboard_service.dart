import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _leaderboardHistoryCollection =>
      _firestore.collection('leaderboard_history');

  /// Get current user's leaderboard data
  Future<Map<String, dynamic>?> getCurrentUserLeaderboardData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _usersCollection.doc(user.uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting current user leaderboard data: $e');
      return null;
    }
  }

  /// Get daily leaderboard data
  Future<List<Map<String, dynamic>>> getDailyLeaderboard() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final querySnapshot = await _usersCollection
          .orderBy('daily_steps.$today', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final dailySteps = data['daily_steps'] as Map<String, dynamic>? ?? {};
        return {
          'userId': doc.id,
          'name': data['username'] ?? 'Unknown User',
          'steps': dailySteps[today] ?? 0,
          'image': data['profileImageUrl'],
          'rank': 0, // Will be set in the UI
        };
      }).toList();
    } catch (e) {
      print('Error getting daily leaderboard: $e');
      return [];
    }
  }

  /// Get weekly leaderboard data
  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard() async {
    try {
      final startOfWeek = _getStartOfWeek(DateTime.now());

      final querySnapshot = await _usersCollection
          .orderBy('weekly_steps', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final dailySteps = data['daily_steps'] as Map<String, dynamic>? ?? {};

        // Calculate real-time weekly total including today's current steps
        int weeklyTotal = 0;

        // Add all daily steps from this week
        for (int i = 0; i < 7; i++) {
          final date = startOfWeek.add(Duration(days: i));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final daySteps = (dailySteps[dateKey] ?? 0) as int;
          weeklyTotal += daySteps;
        }

        return {
          'userId': doc.id,
          'name': data['username'] ?? 'Unknown User',
          'steps': weeklyTotal,
          'image': data['profileImageUrl'],
          'rank': 0, // Will be set in the UI
        };
      }).toList();
    } catch (e) {
      print('Error getting weekly leaderboard: $e');
      return [];
    }
  }

  /// Update user's daily steps
  Future<void> updateDailySteps(String userId, int steps) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await _usersCollection.doc(userId).update({
        'daily_steps.$today': steps,
      });
    } catch (e) {
      print('Error updating daily steps: $e');
    }
  }

  /// Update user's weekly steps
  Future<void> updateWeeklySteps(String userId, int steps) async {
    try {
      final now = DateTime.now();
      final startOfWeek = _getStartOfWeek(now);
      final today = DateFormat('yyyy-MM-dd').format(now);

      // Get current user data
      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final dailySteps = userData['daily_steps'] as Map<String, dynamic>? ?? {};

      // Calculate complete weekly total correctly (Monday to Sunday)
      int weeklyTotal = 0;

      // Sum all daily steps from this week (Monday to Sunday)
      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);

        // Use today's new steps if it's today, otherwise use stored daily steps
        if (dateKey == today) {
          weeklyTotal += steps;
        } else {
          final daySteps = (dailySteps[dateKey] ?? 0) as int;
          weeklyTotal += daySteps;
        }
      }

      // Update the database with complete weekly total
      await _usersCollection.doc(userId).update({
        'daily_steps.$today': steps,
        'weekly_steps': weeklyTotal,
      });

      print(
          'Updated weekly steps for user $userId: $weeklyTotal (including today: $steps)');
    } catch (e) {
      print('Error updating weekly steps: $e');
    }
  }

  /// Get start of current week (Monday)
  DateTime _getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return date.subtract(Duration(days: daysFromMonday));
  }

  /// Get current user's rank in weekly leaderboard
  Future<int> getCurrentUserWeeklyRank() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return -1;

      final userData = await getCurrentUserLeaderboardData();
      if (userData == null) return -1;

      final weeklySteps = userData['weekly_steps'] ?? 0;

      final querySnapshot = await _usersCollection
          .where('weekly_steps', isGreaterThan: weeklySteps)
          .get();

      return querySnapshot.docs.length + 1;
    } catch (e) {
      print('Error getting weekly rank: $e');
      return -1;
    }
  }

  /// Check if user has received weekly rewards
  Future<bool> hasReceivedWeeklyRewards() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userData = await getCurrentUserLeaderboardData();
      if (userData == null) return false;

      final lastWeekRewarded = userData['last_week_rewarded'];
      if (lastWeekRewarded == null) return false;

      final lastRewardedDate = DateTime.parse(lastWeekRewarded);
      final startOfCurrentWeek = _getStartOfWeek(DateTime.now());

      return lastRewardedDate.isAfter(startOfCurrentWeek);
    } catch (e) {
      print('Error checking weekly rewards: $e');
      return false;
    }
  }

  /// Check if a specific reward has been shown to the user
  Future<bool> hasRewardBeenShown(String rewardType, String date) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userData = await getCurrentUserLeaderboardData();
      if (userData == null) return false;

      final shownRewards =
          userData['shown_rewards'] as Map<String, dynamic>? ?? {};
      final rewardKey = '${rewardType}_$date';

      return shownRewards.containsKey(rewardKey);
    } catch (e) {
      print('Error checking if reward has been shown: $e');
      return false;
    }
  }

  /// Mark a reward as shown for the current user
  Future<void> markRewardAsShown(
    String rewardType,
    String date, {
    int? rank,
    int? steps,
    int? reward,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final rewardKey = '${rewardType}_$date';
      final updateData = <String, dynamic>{
        'shown_at': FieldValue.serverTimestamp(),
        'date': date,
      };

      if (rank != null) updateData['rank'] = rank;
      if (steps != null) updateData['steps'] = steps;
      if (reward != null) updateData['reward'] = reward;

      await _usersCollection.doc(user.uid).update({
        'shown_rewards.$rewardKey': updateData,
      });

      print(
          'Marked $rewardType reward for $date as shown for user ${user.uid}');
    } catch (e) {
      print('Error marking reward as shown: $e');
    }
  }

  /// Get leaderboard history
  Future<List<Map<String, dynamic>>> getLeaderboardHistory(String type) async {
    try {
      final querySnapshot = await _leaderboardHistoryCollection
          .where('type', isEqualTo: type)
          .orderBy('date', descending: true)
          .limit(5)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'date': data['date'],
          'type': data['type'],
          'winners': data['winners'] ?? [],
        };
      }).toList();
    } catch (e) {
      print('Error getting leaderboard history: $e');
      return [];
    }
  }

  /// Stream for real-time daily leaderboard updates
  Stream<List<Map<String, dynamic>>> getDailyLeaderboardStream() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _usersCollection
        .orderBy('daily_steps.$today', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final dailySteps = data['daily_steps'] as Map<String, dynamic>? ?? {};
        return {
          'userId': doc.id,
          'name': data['username'] ?? 'Unknown User',
          'steps': dailySteps[today] ?? 0,
          'image': data['profileImageUrl'],
          'rank': 0,
        };
      }).toList();
    });
  }

  /// Stream for real-time weekly leaderboard updates
  Stream<List<Map<String, dynamic>>> getWeeklyLeaderboardStream() {
    final startOfWeek = _getStartOfWeek(DateTime.now());

    return _usersCollection
        .orderBy('weekly_steps', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final dailySteps = data['daily_steps'] as Map<String, dynamic>? ?? {};

        // Calculate real-time weekly total including today's current steps
        int weeklyTotal = 0;

        // Add all daily steps from this week
        for (int i = 0; i < 7; i++) {
          final date = startOfWeek.add(Duration(days: i));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final daySteps = (dailySteps[dateKey] ?? 0) as int;
          weeklyTotal += daySteps;
        }

        return {
          'userId': doc.id,
          'name': data['username'] ?? 'Unknown User',
          'steps': weeklyTotal,
          'image': data['profileImageUrl'],
          'rank': 0,
        };
      }).toList();
    });
  }

  /// Reset weekly data for new week (call this on Monday)
  Future<void> resetWeeklyDataForNewWeek() async {
    try {
      print('🔄 Resetting weekly data for new week...');

      final querySnapshot = await _usersCollection.get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.update({
          'weekly_steps': 0,
          'last_week_rewarded': null,
        });
      }

      print('✅ Weekly data reset for new week');
    } catch (e) {
      print('❌ Error resetting weekly data: $e');
    }
  }

  /// Fix weekly steps for all users (call this to recalculate weekly totals)
  Future<void> fixWeeklyStepsForAllUsers() async {
    try {
      print('🔧 Fixing weekly steps for all users...');

      final startOfWeek = _getStartOfWeek(DateTime.now());
      final querySnapshot = await _usersCollection.get();

      for (var doc in querySnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final dailySteps =
            userData['daily_steps'] as Map<String, dynamic>? ?? {};

        // Calculate weekly total correctly (Monday to Sunday)
        int weeklyTotal = 0;
        for (int i = 0; i < 7; i++) {
          final date = startOfWeek.add(Duration(days: i));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final daySteps = (dailySteps[dateKey] ?? 0) as int;
          weeklyTotal += daySteps;
        }

        // Update weekly steps
        await doc.reference.update({
          'weekly_steps': weeklyTotal,
        });

        print(
            '🔧 Fixed weekly steps for ${userData['username'] ?? doc.id}: $weeklyTotal (Monday to Sunday)');
      }

      print('✅ Weekly steps fixed for all users');
    } catch (e) {
      print('❌ Error fixing weekly steps: $e');
    }
  }
}
