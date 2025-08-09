import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StreakProvider extends ChangeNotifier {
  int _currentStreak = 0;
  int _bestStreak = 0;
  Map<String, Set<DateTime>> _monthlyGoalMetDays =
      {}; // monthKey -> Set of dates

  // Compute current streak from goal-met days to ensure UI is always correct
  // even if stored values get temporarily out of sync.
  int get currentStreak {
    final Set<DateTime> metDays = {};
    for (final monthDays in _monthlyGoalMetDays.values) {
      for (final d in monthDays) {
        metDays.add(DateTime(d.year, d.month, d.day));
      }
    }
    if (metDays.isEmpty) return 0;
    // Find the most recent met day
    DateTime latest = metDays.first;
    for (final d in metDays) {
      if (d.isAfter(latest)) latest = d;
    }
    int run = 1;
    DateTime cursor = latest;
    while (true) {
      final prev = cursor.subtract(const Duration(days: 1));
      if (metDays.contains(prev)) {
        run += 1;
        cursor = prev;
      } else {
        break;
      }
    }
    return run;
  }

  // Compute best streak dynamically from stored goal-met days
  int get bestStreak {
    final List<DateTime> days = _monthlyGoalMetDays.values
        .expand((s) => s.map((d) => DateTime(d.year, d.month, d.day)))
        .toList()
      ..sort();
    if (days.isEmpty) return 0;
    int best = 1;
    int run = 1;
    for (int i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        run += 1;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best;
  }

  // Get all goal met days (for backward compatibility)
  Set<DateTime> get goalMetDays {
    Set<DateTime> allDays = {};
    for (final monthDays in _monthlyGoalMetDays.values) {
      allDays.addAll(monthDays);
    }
    return allDays;
  }

  // Get goal met days for a specific month
  Set<DateTime> getGoalMetDaysForMonth(int year, int month) {
    final monthKey = '${year}-${month.toString().padLeft(2, '0')}';
    return _monthlyGoalMetDays[monthKey] ?? {};
  }

  // Get goal met days for current month
  Set<DateTime> get currentMonthGoalMetDays {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _monthlyGoalMetDays[monthKey] ?? {};
  }

  StreakProvider() {
    _loadStreaks();
  }

  Future<String?> _getUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<void> _loadStreaks() async {
    final uid = await _getUserId();
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      _currentStreak = data['currentStreak'] ?? 0;
      _bestStreak = data['bestStreak'] ?? 0;

      // Load monthly goal met days
      final monthlyGoalMetDaysData =
          data['monthlyGoalMetDays'] as Map<String, dynamic>?;
      if (monthlyGoalMetDaysData != null) {
        _monthlyGoalMetDays.clear();
        for (final entry in monthlyGoalMetDaysData.entries) {
          final monthKey = entry.key;
          final daysList = entry.value as List<dynamic>? ?? [];
          _monthlyGoalMetDays[monthKey] = daysList
              .whereType<String>()
              .map((d) {
                try {
                  // Support both yyyy-MM-dd and full ISO formats
                  if (d.length == 10) {
                    final parts = d.split('-');
                    final y = int.parse(parts[0]);
                    final m = int.parse(parts[1]);
                    final day = int.parse(parts[2]);
                    return DateTime(y, m, day);
                  }
                  final parsed = DateTime.parse(d);
                  return DateTime(parsed.year, parsed.month, parsed.day);
                } catch (_) {
                  return null;
                }
              })
              .whereType<DateTime>()
              .toSet();
        }
      } else {
        // Legacy support: load old goalMetDays format
        final List<dynamic> daysList = data['goalMetDays'] ?? [];
        final legacyDays =
            daysList.map((d) => DateTime.parse(d as String)).toSet();
        if (legacyDays.isNotEmpty) {
          // Group legacy days by month
          for (final day in legacyDays) {
            final monthKey =
                '${day.year}-${day.month.toString().padLeft(2, '0')}';
            _monthlyGoalMetDays.putIfAbsent(monthKey, () => {}).add(day);
          }
        }
      }

      print("📅 Loaded streak data from Firestore:");
      print("   Current streak: $_currentStreak");
      print("   Best streak: $_bestStreak");
      print("   Monthly goal met days: ${_monthlyGoalMetDays.keys.toList()}");

      notifyListeners();

      // Check if migration is needed after loading existing data
      await checkAndRunMigrationIfNeeded();
    } else {
      print("❌ No streak data found in Firestore for user: $uid");
    }
  }

  // Public method to reload streak data
  Future<void> reloadStreaks() async {
    print("🔄 Reloading streak data...");
    await _loadStreaks();
  }

  // Public method to manually trigger streak migration
  Future<void> triggerStreakMigration() async {
    print("🔄 Manual streak migration triggered...");
    await migrateStreakHistoryFromDailySteps();
  }

  // Method to clear all goal met days and reset streaks (for fresh start)
  Future<void> clearGoalMetDaysAndResetStreaks() async {
    final uid = await _getUserId();
    if (uid == null) return;

    try {
      print("🗑️ Clearing all goal met days and resetting streaks...");

      // Clear local data
      _monthlyGoalMetDays.clear();
      _currentStreak = 0;
      _bestStreak = 0;

      // Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'currentStreak': 0,
        'bestStreak': 0,
        'monthlyGoalMetDays': {},
      });

      print("✅ Goal met days cleared and streaks reset successfully");
      notifyListeners();
    } catch (e) {
      print("❌ Error clearing goal met days: $e");
    }
  }

  // Method to ensure streak data is initialized
  Future<void> ensureStreakDataInitialized() async {
    final uid = await _getUserId();
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists || !doc.data()!.containsKey('currentStreak')) {
      print("🆕 Initializing streak data for new user...");
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'currentStreak': 0,
        'bestStreak': 0,
        'goalMetDays': [],
      });
      await _loadStreaks();
    }
  }

  Future<void> updateStreaks(
      Map<DateTime, int> dailySteps, int goalSteps) async {
    final uid = await _getUserId();
    if (uid == null) return;

    // Sort days
    final sortedDays = dailySteps.keys.toList()..sort();
    int streak = 0;
    int best = 0;
    Map<String, Set<DateTime>> monthlyMetDays = {};

    // Calculate current streak from the most recent day
    for (int i = sortedDays.length - 1; i >= 0; i--) {
      DateTime day = sortedDays[i];
      if (dailySteps[day]! >= goalSteps) {
        // Add to monthly structure
        final monthKey = '${day.year}-${day.month.toString().padLeft(2, '0')}';
        monthlyMetDays.putIfAbsent(monthKey, () => {}).add(day);

        // Check if this day continues the streak
        if (i == sortedDays.length - 1) {
          // This is the most recent day, start counting
          streak = 1;

          // Look backwards for consecutive days
          for (int j = i - 1; j >= 0; j--) {
            final prevDay = sortedDays[j];
            final daysDiff = day.difference(prevDay).inDays;

            if (dailySteps[prevDay]! >= goalSteps && daysDiff == 1) {
              streak++;
              day = prevDay; // Update day for next iteration
            } else {
              break; // Streak broken
            }
          }
        }
        break; // We've found the most recent day and calculated the streak
      }
    }

    // Calculate best streak by looking at all consecutive sequences
    int currentSequence = 0;
    DateTime? prevDay;

    for (final day in sortedDays) {
      if (dailySteps[day]! >= goalSteps) {
        // Add to monthly structure
        final monthKey = '${day.year}-${day.month.toString().padLeft(2, '0')}';
        monthlyMetDays.putIfAbsent(monthKey, () => {}).add(day);

        if (prevDay == null || day.difference(prevDay).inDays == 1) {
          currentSequence++;
        } else {
          // Gap found, reset sequence
          currentSequence = 1;
        }
        if (currentSequence > best) {
          best = currentSequence;
        }
        prevDay = day;
      } else {
        // Goal not met, reset sequence
        currentSequence = 0;
        prevDay = null;
      }
    }

    _currentStreak = streak;
    _bestStreak = best;
    _monthlyGoalMetDays = monthlyMetDays;

    // Convert monthly goal met days to Firestore format
    final monthlyGoalMetDaysMap = <String, List<String>>{};
    for (final entry in _monthlyGoalMetDays.entries) {
      monthlyGoalMetDaysMap[entry.key] =
          entry.value.map((d) => d.toIso8601String()).toList();
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'currentStreak': _currentStreak,
      'bestStreak': _bestStreak,
      'monthlyGoalMetDays': monthlyGoalMetDaysMap,
    });
    notifyListeners();
  }

  // New method to check and update today's streak status
  Future<void> checkAndUpdateTodayStreak(int todaySteps, int goalSteps,
      [DateTime? goalSetDate]) async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final todayMonthKey =
        '${startOfToday.year}-${startOfToday.month.toString().padLeft(2, '0')}';

    // Check if today is already marked
    final todayMonthDays = _monthlyGoalMetDays[todayMonthKey] ?? {};
    final todayAlreadyMarked = todayMonthDays.any((date) =>
        date.year == startOfToday.year &&
        date.month == startOfToday.month &&
        date.day == startOfToday.day);

    // Yesterday handling removed in this method (handled in checkAndUpdateStreakWithYesterday)

    bool changed = false;

    // Handle today's streak status - only add, never remove
    if (todaySteps >= goalSteps && !todayAlreadyMarked) {
      // Goal met today, add to streak
      _monthlyGoalMetDays
          .putIfAbsent(todayMonthKey, () => {})
          .add(startOfToday);
      print("✅ Added today to streak: $startOfToday");
      changed = true;
    }

    // Do NOT auto-add yesterday here. Yesterday should only be added via
    // checkAndUpdateStreakWithYesterday() which validates actual yesterday steps.

    // Only recalculate streaks if we made changes, otherwise just notify listeners
    if (changed) {
      await _recalculateStreaks(goalSteps);
    } else {
      notifyListeners();
    }
  }

  // Removed unused goal/goalSetDate helpers to keep provider focused on
  // monthlyGoalMetDays as the sole source of truth.

  // Enhanced method to check and update streak with yesterday's data
  Future<void> checkAndUpdateStreakWithYesterday(
      int todaySteps, int yesterdaySteps, int goalSteps,
      [DateTime? goalSetDate]) async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final yesterday = startOfToday.subtract(const Duration(days: 1));
    final todayMonthKey =
        '${startOfToday.year}-${startOfToday.month.toString().padLeft(2, '0')}';
    final yesterdayMonthKey =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}';

    // Use provided goal set date or default to today
    final startOfGoalSetDate = goalSetDate != null
        ? DateTime(goalSetDate.year, goalSetDate.month, goalSetDate.day)
        : startOfToday; // If no goal set date provided, use today

    // Check if today is already marked
    final todayMonthDays = _monthlyGoalMetDays[todayMonthKey] ?? {};
    final todayAlreadyMarked = todayMonthDays.any((date) =>
        date.year == startOfToday.year &&
        date.month == startOfToday.month &&
        date.day == startOfToday.day);

    // Check if yesterday is already marked
    final yesterdayMonthDays = _monthlyGoalMetDays[yesterdayMonthKey] ?? {};
    final yesterdayAlreadyMarked = yesterdayMonthDays.any((date) =>
        date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day);

    bool changed = false;

    // Handle yesterday's streak status - only add if met and allowed by goal set date
    if (yesterdaySteps >= goalSteps &&
        !yesterdayAlreadyMarked &&
        yesterday
            .isAfter(startOfGoalSetDate.subtract(const Duration(days: 1)))) {
      // Goal met yesterday, add to streak
      _monthlyGoalMetDays
          .putIfAbsent(yesterdayMonthKey, () => {})
          .add(yesterday);
      print("✅ Added yesterday to streak: $yesterday");
      changed = true;
    }

    // Handle today's streak status - only add, never remove
    if (todaySteps >= goalSteps && !todayAlreadyMarked) {
      // Goal met today, add to streak
      _monthlyGoalMetDays
          .putIfAbsent(todayMonthKey, () => {})
          .add(startOfToday);
      print("✅ Added today to streak: $startOfToday");
      changed = true;
    }

    // Only recalculate streaks if we made changes, otherwise just notify listeners
    if (changed) {
      await _recalculateStreaks(goalSteps);
    } else {
      notifyListeners();
    }
  }

  // Method to manually add a day to the streak (for testing/debugging)
  Future<void> addDayToStreak(DateTime date, [int? goalSteps]) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final monthKey =
        '${startOfDay.year}-${startOfDay.month.toString().padLeft(2, '0')}';

    // Check if day is already marked
    final monthDays = _monthlyGoalMetDays[monthKey] ?? {};
    final alreadyMarked = monthDays.any((d) =>
        d.year == startOfDay.year &&
        d.month == startOfDay.month &&
        d.day == startOfDay.day);

    if (!alreadyMarked) {
      _monthlyGoalMetDays.putIfAbsent(monthKey, () => {}).add(startOfDay);
      await _recalculateStreaks(
          goalSteps ?? 10000); // Use provided goal or default
    }
  }

  // Migration method to reconstruct streak history from daily steps data
  Future<void> migrateStreakHistoryFromDailySteps([int? goalSteps]) async {
    final uid = await _getUserId();
    if (uid == null) return;

    try {
      print("🔄 Starting streak history migration...");

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) {
        print("❌ User document not found for migration");
        return;
      }

      final data = doc.data() ?? {};
      final dailyStepsData = data['dailySteps'] as Map<String, dynamic>?;

      if (dailyStepsData == null || dailyStepsData.isEmpty) {
        print("❌ No daily steps data found for migration");
        return;
      }

      // Get goal from monthly goals or use provided goal
      int targetGoal = goalSteps ?? 10000;
      if (goalSteps == null) {
        final monthlyGoalsData = data['monthlyGoals'] as Map<String, dynamic>?;
        if (monthlyGoalsData != null && monthlyGoalsData.isNotEmpty) {
          // Use the most recent month's goal
          final sortedKeys = monthlyGoalsData.keys.toList()..sort();
          if (sortedKeys.isNotEmpty) {
            final latestMonthData =
                monthlyGoalsData[sortedKeys.last] as Map<String, dynamic>;
            targetGoal = latestMonthData['goalSteps'] as int? ?? 10000;
          }
        }
      }
      print("🎯 Migration goal steps: $targetGoal");

      // Convert daily steps data to DateTime keys
      Map<DateTime, int> dailySteps = {};
      for (final entry in dailyStepsData.entries) {
        try {
          final date = DateTime.parse(entry.key);
          final steps = entry.value as int? ?? 0;
          dailySteps[date] = steps;
        } catch (e) {
          print("⚠️ Skipping invalid date format: ${entry.key}");
        }
      }

      if (dailySteps.isEmpty) {
        print("❌ No valid daily steps data found");
        return;
      }

      print("📊 Found ${dailySteps.length} days of step data");

      // Find all days where goal was met
      Map<String, Set<DateTime>> reconstructedMonthlyGoalMetDays = {};
      for (final entry in dailySteps.entries) {
        final date = entry.key;
        final steps = entry.value;
        final monthKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';

        print(
            "📊 Checking ${date.toString().split(' ')[0]}: $steps steps vs goal $targetGoal");

        if (steps >= targetGoal) {
          // Normalize to start of day
          final startOfDay = DateTime(date.year, date.month, date.day);
          reconstructedMonthlyGoalMetDays
              .putIfAbsent(monthKey, () => {})
              .add(startOfDay);
          print("✅ Added ${date.toString().split(' ')[0]} to goal met days");
        } else {
          print(
              "❌ ${date.toString().split(' ')[0]} did not meet goal ($steps < $targetGoal)");
        }
      }

      final totalReconstructedDays = reconstructedMonthlyGoalMetDays.values
          .map((days) => days.length)
          .fold(0, (sum, count) => sum + count);
      print(
          "✅ Reconstructed $totalReconstructedDays goal-met days across ${reconstructedMonthlyGoalMetDays.length} months");

      // Replace existing goal met days with reconstructed data (fixes incorrect entries)
      final originalCount = _monthlyGoalMetDays.values
          .map((days) => days.length)
          .fold(0, (sum, count) => sum + count);
      _monthlyGoalMetDays.clear();
      _monthlyGoalMetDays.addAll(reconstructedMonthlyGoalMetDays);
      final newCount = _monthlyGoalMetDays.values
          .map((days) => days.length)
          .fold(0, (sum, count) => sum + count);

      print(
          "📈 Replaced $originalCount existing days with $newCount correct goal-met days");

      // Always recalculate streaks after migration to ensure accuracy
      await _recalculateStreaks(targetGoal);
      print("✅ Streak migration completed successfully");
    } catch (e) {
      print("❌ Error during streak migration: $e");
    }
  }

  // Method to check if migration is needed and run it
  Future<void> checkAndRunMigrationIfNeeded() async {
    final uid = await _getUserId();
    if (uid == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final dailyStepsData = data['dailySteps'] as Map<String, dynamic>?;
      final hasGoalMetDays = data['goalMetDays'] != null;

      // If user has daily steps data but few or no goal met days, run migration
      final totalGoalMetDays = _monthlyGoalMetDays.values
          .map((days) => days.length)
          .fold(0, (sum, count) => sum + count);
      if (dailyStepsData != null &&
          dailyStepsData.isNotEmpty &&
          (!hasGoalMetDays || totalGoalMetDays < 3)) {
        print(
            "🔄 Detected potential missing streak data, running migration...");
        await migrateStreakHistoryFromDailySteps();
      }
    } catch (e) {
      print("❌ Error checking migration status: $e");
    }
  }

  // Helper method to recalculate streaks after changes using ONLY
  // monthlyGoalMetDays as the source of truth.
  // - currentStreak is anchored at today (0 if today not met)
  // - bestStreak is the longest historical consecutive sequence
  Future<void> _recalculateStreaks(int goalSteps) async {
    final uid = await _getUserId();
    if (uid == null) return;

    // Flatten to a set for O(1) lookups and a sorted list for best-streak scan
    final Set<DateTime> metDays = {};
    for (final monthDays in _monthlyGoalMetDays.values) {
      metDays.addAll(monthDays.map((d) => DateTime(d.year, d.month, d.day)));
    }

    final List<DateTime> sortedDays = metDays.toList()..sort();

    // Current streak = most recent consecutive run (may end yesterday)
    int streak = 0;
    if (sortedDays.isNotEmpty) {
      DateTime cursor = sortedDays.last; // most recent met day
      streak = 1;
      for (int i = sortedDays.length - 2; i >= 0; i--) {
        final prev = sortedDays[i];
        if (cursor.difference(prev).inDays == 1) {
          streak += 1;
          cursor = prev;
        } else {
          break;
        }
      }
    }

    // Best streak across history (longest consecutive block)
    int best = 0;
    int run = 0;
    DateTime? last;
    for (final day in sortedDays) {
      if (last == null) {
        run = 1;
      } else if (day.difference(last).inDays == 1) {
        run += 1;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      last = day;
    }

    _currentStreak = streak;
    _bestStreak = best;

    print("💾 Saving streak data to Firestore:");
    print("   Current streak: $_currentStreak");
    print("   Best streak: $_bestStreak");
    print("   Monthly goal met days: ${_monthlyGoalMetDays.keys.toList()}");

    // Convert monthly goal met days to Firestore format using yyyy-MM-dd
    final DateFormat dateOnly = DateFormat('yyyy-MM-dd');
    final monthlyGoalMetDaysMap = <String, List<String>>{};
    for (final entry in _monthlyGoalMetDays.entries) {
      monthlyGoalMetDaysMap[entry.key] = entry.value
          .map((d) => dateOnly.format(DateTime(d.year, d.month, d.day)))
          .toList();
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'currentStreak': _currentStreak,
      'bestStreak': _bestStreak,
      'monthlyGoalMetDays': monthlyGoalMetDaysMap,
    });

    print("✅ Streak data saved to Firestore successfully");
    notifyListeners();
  }
}
