import 'package:flutter/material.dart';

class StepGoalProvider extends ChangeNotifier {
  int _goalSteps = 10000; // default value

  int get goalSteps => _goalSteps;

  void setGoal(int newGoal) {
    _goalSteps = newGoal;
    notifyListeners();
  }
}
