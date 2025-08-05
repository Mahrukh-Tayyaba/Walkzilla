import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LevelingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Level requirements based on total lifetime steps
  static const Map<int, int> _levelRequirements = {
    1: 0, // Starting level
    2: 15000, // 15k steps
    3: 30000, // 30k steps
    4: 45000, // 45k steps
    5: 60000, // 60k steps
    6: 75000, // 75k steps
    7: 90000, // 90k steps
    8: 105000, // 105k steps
    9: 120000, // 120k steps
    10: 135000, // 135k steps
    // Continue pattern for higher levels
  };

  // Streak milestones that trigger level ups
  static const List<int> _streakMilestones = [7, 14, 30];

  // Monthly level up based on streak consistency
  static const int _monthlyStreakRequirement = 30; // 30 days = 1 month

  /// Calculate base level from total lifetime steps
  static int calculateBaseLevel(int totalLifetimeSteps) {
    int level = 1;

    // Calculate level based on total steps
    if (totalLifetimeSteps >= 135000) {
      // For levels 11+, use formula: level = 10 + ((steps - 135000) / 20000) + 1
      level = 10 + ((totalLifetimeSteps - 135000) ~/ 20000) + 1;
    } else {
      // For levels 1-10, use predefined requirements
      for (int i = 10; i >= 1; i--) {
        if (totalLifetimeSteps >= _levelRequirements[i]!) {
          level = i;
          break;
        }
      }
    }

    return level;
  }

  /// Calculate monthly streak bonus levels
  static int calculateMonthlyStreakBonus(int currentStreak) {
    // User gets +1 level for every complete month (30 days) of streak
    return currentStreak ~/ _monthlyStreakRequirement;
  }

  /// Check if user reached a streak milestone
  static bool hasReachedStreakMilestone(int currentStreak, int milestone) {
    return _streakMilestones.contains(milestone) && currentStreak >= milestone;
  }

  /// Get next streak milestone
  static int? getNextStreakMilestone(int currentStreak) {
    for (int milestone in _streakMilestones) {
      if (currentStreak < milestone) {
        return milestone;
      }
    }
    return null;
  }

  /// Calculate total level (base + monthly streak bonus)
  static int calculateTotalLevel(int totalLifetimeSteps, int currentStreak) {
    int baseLevel = calculateBaseLevel(totalLifetimeSteps);
    int monthlyStreakBonus = calculateMonthlyStreakBonus(currentStreak);

    return baseLevel + monthlyStreakBonus;
  }

  /// Get level progress information
  static Map<String, dynamic> getLevelProgress(
      int totalLifetimeSteps, int currentStreak) {
    int baseLevel = calculateBaseLevel(totalLifetimeSteps);
    int monthlyStreakBonus = calculateMonthlyStreakBonus(currentStreak);

    // For display purposes, show the theoretical total level
    int theoreticalTotalLevel = baseLevel + monthlyStreakBonus;

    // But the actual current level is stored separately in the database
    // This will be updated by the actual level progression

    // Calculate progress to next level
    int nextLevelSteps = _getNextLevelRequirement(totalLifetimeSteps);
    int currentLevelSteps = _getCurrentLevelRequirement(totalLifetimeSteps);
    int progress = totalLifetimeSteps - currentLevelSteps;
    int required = nextLevelSteps - currentLevelSteps;
    double progressPercentage =
        required > 0 ? (progress / required) * 100 : 100.0;

    // Calculate progress to next monthly streak level
    int currentMonthStreak = currentStreak ~/ _monthlyStreakRequirement;
    int nextMonthStreak = currentMonthStreak + 1;
    int daysUntilNextMonth =
        (nextMonthStreak * _monthlyStreakRequirement) - currentStreak;
    double monthlyProgressPercentage = daysUntilNextMonth > 0
        ? ((_monthlyStreakRequirement - daysUntilNextMonth) /
                _monthlyStreakRequirement) *
            100
        : 100.0;

    return {
      'currentLevel': theoreticalTotalLevel, // For display
      'baseLevel': baseLevel,
      'monthlyStreakBonus': monthlyStreakBonus,
      'progress': progress,
      'required': required,
      'progressPercentage': progressPercentage,
      'totalLifetimeSteps': totalLifetimeSteps,
      'currentStreak': currentStreak,
      'nextStreakMilestone': getNextStreakMilestone(currentStreak),
      'daysUntilNextMonth': daysUntilNextMonth,
      'monthlyProgressPercentage': monthlyProgressPercentage,
      'currentMonthStreak': currentMonthStreak,
    };
  }

  /// Get steps required for next level
  static int _getNextLevelRequirement(int totalLifetimeSteps) {
    int currentLevel = calculateBaseLevel(totalLifetimeSteps);

    if (currentLevel < 10) {
      // For levels 1-9, use predefined requirements
      return _levelRequirements[currentLevel + 1]!;
    } else {
      // For levels 10+, use formula
      return 135000 + ((currentLevel - 10) * 20000);
    }
  }

  /// Get steps required for current level
  static int _getCurrentLevelRequirement(int totalLifetimeSteps) {
    int currentLevel = calculateBaseLevel(totalLifetimeSteps);

    if (currentLevel <= 10) {
      return _levelRequirements[currentLevel]!;
    } else {
      return 135000 + ((currentLevel - 11) * 20000);
    }
  }

  /// Update user's total lifetime steps and check for level up
  static Future<Map<String, dynamic>?> updateUserLevel(
      String userId, int newDailySteps) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      int currentTotalSteps = userData['totalLifetimeSteps'] ?? 0;
      int currentStreak = userData['currentStreak'] ?? 0;
      int currentLevel = userData['level'] ?? 1;

      // Calculate new total lifetime steps
      int newTotalSteps = currentTotalSteps + newDailySteps;

      // Calculate new level with step progression only
      int newBaseLevel = calculateBaseLevel(newTotalSteps);
      int currentBaseLevel = calculateBaseLevel(currentTotalSteps);

      // Check if base level increased
      bool baseLevelIncreased = newBaseLevel > currentBaseLevel;

      // Only increase by one level at a time
      int newLevel = currentLevel;
      if (baseLevelIncreased) {
        newLevel = currentLevel + 1;
      }

      // Check if user leveled up
      bool leveledUp = newLevel > currentLevel;

      // Calculate rewards
      int levelReward = leveledUp ? _calculateLevelReward(newLevel) : 0;

      // Update user document
      await userRef.update({
        'totalLifetimeSteps': newTotalSteps,
        'level': newLevel,
        'lastLevelUpdate': FieldValue.serverTimestamp(),
      });

      // Add coins if leveled up
      if (leveledUp && levelReward > 0) {
        int currentCoins = userData['coins'] ?? 0;
        await userRef.update({
          'coins': currentCoins + levelReward,
        });
      }

      return {
        'leveledUp': leveledUp,
        'oldLevel': currentLevel,
        'newLevel': newLevel,
        'reward': levelReward,
        'totalLifetimeSteps': newTotalSteps,
        'progress': getLevelProgress(newTotalSteps, currentStreak),
        'trigger': baseLevelIncreased ? 'step_progression' : 'none',
      };
    } catch (e) {
      print('Error updating user level: $e');
      return null;
    }
  }

  /// Calculate coin reward for leveling up
  static int _calculateLevelReward(int level) {
    if (level <= 10) return 50;
    if (level <= 25) return 75;
    if (level <= 50) return 100;
    if (level <= 100) return 150;
    return 200; // Level 101+
  }

  /// Get user's level information
  static Future<Map<String, dynamic>?> getUserLevelInfo(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      int totalLifetimeSteps = userData['totalLifetimeSteps'] ?? 0;
      int currentStreak = userData['currentStreak'] ?? 0;

      return getLevelProgress(totalLifetimeSteps, currentStreak);
    } catch (e) {
      print('Error getting user level info: $e');
      return null;
    }
  }

  /// Check and handle streak milestone and monthly level up
  static Future<Map<String, dynamic>?> checkStreakLevelUp(
      String userId, int newStreak) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      int currentLevel = userData['level'] ?? 1;
      int previousStreak = userData['currentStreak'] ?? 0;

      // Get achieved milestones (initialize if not exists)
      List<int> achievedMilestones =
          List<int>.from(userData['achievedMilestones'] ?? []);

      // Check for streak milestone level up first (only for first-time achievements)
      int? reachedMilestone;
      for (int milestone in _streakMilestones) {
        if (newStreak >= milestone &&
            previousStreak < milestone &&
            !achievedMilestones.contains(milestone)) {
          reachedMilestone = milestone;
          break;
        }
      }

      if (reachedMilestone != null) {
        // Increase level by one for reaching streak milestone
        int newLevel = currentLevel + 1;
        int levelReward = _calculateLevelReward(newLevel);

        // Add milestone to achieved list
        achievedMilestones.add(reachedMilestone);

        // Update user document
        await userRef.update({
          'level': newLevel,
          'achievedMilestones': achievedMilestones,
          'lastLevelUpdate': FieldValue.serverTimestamp(),
        });

        // Add coins
        int currentCoins = userData['coins'] ?? 0;
        await userRef.update({
          'coins': currentCoins + levelReward,
        });

        return {
          'leveledUp': true,
          'oldLevel': currentLevel,
          'newLevel': newLevel,
          'reward': levelReward,
          'trigger': 'streak_milestone',
          'milestone': reachedMilestone,
          'streakDays': newStreak,
        };
      }

      // Check for monthly streak level up
      int previousMonthlyStreak = previousStreak ~/ _monthlyStreakRequirement;
      int newMonthlyStreak = newStreak ~/ _monthlyStreakRequirement;

      // Check if user completed a new month of streak
      if (newMonthlyStreak > previousMonthlyStreak) {
        // Increase level by one for completing a month
        int newLevel = currentLevel + 1;
        int levelReward = _calculateLevelReward(newLevel);

        // Update user document
        await userRef.update({
          'level': newLevel,
          'lastLevelUpdate': FieldValue.serverTimestamp(),
        });

        // Add coins
        int currentCoins = userData['coins'] ?? 0;
        await userRef.update({
          'coins': currentCoins + levelReward,
        });

        return {
          'leveledUp': true,
          'oldLevel': currentLevel,
          'newLevel': newLevel,
          'reward': levelReward,
          'trigger': 'monthly_streak',
          'completedMonths': newMonthlyStreak,
          'streakDays': newStreak,
        };
      }

      return {
        'leveledUp': false,
        'trigger': 'no_streak_level_up',
      };
    } catch (e) {
      print('Error checking streak level up: $e');
      return null;
    }
  }

  /// Initialize leveling data for existing users
  static Future<void> initializeLevelingData() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();

      for (var doc in usersSnapshot.docs) {
        final userData = doc.data();

        // Skip if already has leveling data
        if (userData['totalLifetimeSteps'] != null) continue;

        // Calculate total lifetime steps from daily steps
        Map<String, dynamic> dailySteps = userData['daily_steps'] ?? {};
        int totalLifetimeSteps = 0;

        for (var steps in dailySteps.values) {
          totalLifetimeSteps += steps as int;
        }

        int currentStreak = userData['currentStreak'] ?? 0;
        int level = calculateTotalLevel(totalLifetimeSteps, currentStreak);

        // Update user document
        await doc.reference.update({
          'totalLifetimeSteps': totalLifetimeSteps,
          'level': level,
          'lastLevelUpdate': FieldValue.serverTimestamp(),
        });

        print(
            'Initialized leveling data for user ${doc.id}: Level $level, $totalLifetimeSteps steps');
      }
    } catch (e) {
      print('Error initializing leveling data: $e');
    }
  }
}
