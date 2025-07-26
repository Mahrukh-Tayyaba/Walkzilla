import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StepGoalProvider extends ChangeNotifier {
  int _goalSteps = 10000; // default value
  bool _isLoading = false;

  int get goalSteps => _goalSteps;
  bool get isLoading => _isLoading;

  // Calculated goals based on step goal
  double get goalCalories => _calculateCaloriesFromSteps(_goalSteps);
  double get goalDistance => _calculateDistanceFromSteps(_goalSteps);

  StepGoalProvider() {
    _loadGoalFromFirestore();
  }

  // Calculate calories from steps (same formula as used in calories_screen.dart)
  double _calculateCaloriesFromSteps(int steps) {
    // Standard formula: Calories Burned = Number of Steps × Calories per Step
    // Calories per step = 0.04 (standard walking calorie burn)
    return steps * 0.04;
  }

  // Calculate distance from steps
  double _calculateDistanceFromSteps(int steps) {
    // Average step length is approximately 0.762 meters (30 inches)
    // This gives us distance in meters
    double distanceInMeters = steps * 0.762;
    // Convert to kilometers for display
    return distanceInMeters / 1000.0;
  }

  // Get mini challenge goals (40% of main goal for mini challenges)
  double get miniChallengeCalories => goalCalories * 0.4;
  double get miniChallengeDistance => goalDistance * 0.4;

  Future<void> _loadGoalFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['dailyStepGoal'] != null) {
            _goalSteps = data['dailyStepGoal'] as int;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      print('Error loading goal from Firestore: $e');
    }
  }

  void setGoal(int newGoal) {
    _goalSteps = newGoal;
    notifyListeners();
    _saveGoalToFirestore(newGoal);
  }

  Future<void> _saveGoalToFirestore(int goal) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'dailyStepGoal': goal,
        });
      }
    } catch (e) {
      print('Error saving goal to Firestore: $e');
    }
  }

  Future<void> refreshGoal() async {
    await _loadGoalFromFirestore();
  }
}
