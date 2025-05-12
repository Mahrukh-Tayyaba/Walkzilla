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
    DateTime? prevDay;
    for (final day in sortedDays) {
      if (dailySteps[day]! >= goalSteps) {
        metDays.add(day);
        if (prevDay == null || day.difference(prevDay).inDays == 1) {
          streak++;
        } else {
          streak = 1;
        }
        if (streak > best) best = streak;
        prevDay = day;
      } else {
        streak = 0;
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
}
