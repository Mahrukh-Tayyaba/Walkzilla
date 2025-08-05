import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StreakProvider extends ChangeNotifier {
  int _currentStreak = 0;
  int _bestStreak = 0;
  Set<DateTime> _goalMetDays = {};

  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  Set<DateTime> get goalMetDays => _goalMetDays;

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
      final List<dynamic> daysList = data['goalMetDays'] ?? [];
      _goalMetDays = daysList.map((d) => DateTime.parse(d as String)).toSet();
      notifyListeners();
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
    Set<DateTime> metDays = {};

    // Calculate current streak from the most recent day
    for (int i = sortedDays.length - 1; i >= 0; i--) {
      DateTime day = sortedDays[i];
      if (dailySteps[day]! >= goalSteps) {
        metDays.add(day);

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
    _goalMetDays = metDays;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'currentStreak': _currentStreak,
      'bestStreak': _bestStreak,
      'goalMetDays': _goalMetDays.map((d) => d.toIso8601String()).toList(),
    });
    notifyListeners();
  }

  // New method to check and update today's streak status
  Future<void> checkAndUpdateTodayStreak(int todaySteps, int goalSteps) async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    // Check if today is already marked
    final todayAlreadyMarked = _goalMetDays.any((date) =>
        date.year == startOfToday.year &&
        date.month == startOfToday.month &&
        date.day == startOfToday.day);

    if (todaySteps >= goalSteps && !todayAlreadyMarked) {
      // Goal met today, add to streak
      _goalMetDays.add(startOfToday);
      await _recalculateStreaks(goalSteps);
    } else if (todaySteps < goalSteps && todayAlreadyMarked) {
      // Goal not met today, remove from streak
      _goalMetDays.removeWhere((date) =>
          date.year == startOfToday.year &&
          date.month == startOfToday.month &&
          date.day == startOfToday.day);
      await _recalculateStreaks(goalSteps);
    }
    // If today's goal is not met and today wasn't marked, we don't need to do anything
    // The streak will continue to show the last completed day
  }

  // Method to manually add a day to the streak (for testing/debugging)
  Future<void> addDayToStreak(DateTime date, [int? goalSteps]) async {
    final startOfDay = DateTime(date.year, date.month, date.day);

    // Check if day is already marked
    final alreadyMarked = _goalMetDays.any((d) =>
        d.year == startOfDay.year &&
        d.month == startOfDay.month &&
        d.day == startOfDay.day);

    if (!alreadyMarked) {
      _goalMetDays.add(startOfDay);
      await _recalculateStreaks(
          goalSteps ?? 10000); // Use provided goal or default
    }
  }

  // Helper method to recalculate streaks after changes
  Future<void> _recalculateStreaks(int goalSteps) async {
    final uid = await _getUserId();
    if (uid == null) return;

    // Convert goal met days to daily steps map
    Map<DateTime, int> dailySteps = {};
    for (final date in _goalMetDays) {
      dailySteps[date] = goalSteps; // Use goal steps as minimum for met days
    }

    // Recalculate streaks
    final sortedDays = dailySteps.keys.toList()..sort();
    int streak = 0;
    int best = 0;

    // Calculate current streak from the most recent day
    if (sortedDays.isNotEmpty) {
      // Start from the most recent day
      DateTime currentDay = sortedDays.last;
      streak = 1;

      // Look backwards for consecutive days
      for (int i = sortedDays.length - 2; i >= 0; i--) {
        final prevDay = sortedDays[i];
        final daysDiff = currentDay.difference(prevDay).inDays;

        if (daysDiff == 1) {
          streak++;
          currentDay = prevDay; // Update current day for next iteration
        } else {
          break; // Streak broken
        }
      }
    }

    // Calculate best streak by looking at all consecutive sequences
    int currentSequence = 0;
    DateTime? prevDay;

    for (final day in sortedDays) {
      if (dailySteps[day]! >= goalSteps) {
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

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'currentStreak': _currentStreak,
      'bestStreak': _bestStreak,
      'goalMetDays': _goalMetDays.map((d) => d.toIso8601String()).toList(),
    });
    notifyListeners();
  }
}
