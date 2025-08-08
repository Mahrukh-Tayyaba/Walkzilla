import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MonthlyGoal {
  final int year;
  final int month;
  final int goalSteps;
  final DateTime setDate;

  MonthlyGoal({
    required this.year,
    required this.month,
    required this.goalSteps,
    required this.setDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'month': month,
      'goalSteps': goalSteps,
      'setDate': setDate.toIso8601String(),
    };
  }

  factory MonthlyGoal.fromMap(Map<String, dynamic> map) {
    return MonthlyGoal(
      year: map['year'] as int,
      month: map['month'] as int,
      goalSteps: map['goalSteps'] as int,
      setDate: DateTime.parse(map['setDate'] as String),
    );
  }

  String get monthKey => '${year}-${month.toString().padLeft(2, '0')}';
}

class StepGoalProvider extends ChangeNotifier {
  Map<String, MonthlyGoal> _monthlyGoals = {};
  bool _isLoading = false;

  Map<String, MonthlyGoal> get monthlyGoals => _monthlyGoals;
  bool get isLoading => _isLoading;

  // Get current month's goal
  int get goalSteps {
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _monthlyGoals[currentMonthKey]?.goalSteps ?? 10000; // default
  }

  // Get goal for a specific month
  int getGoalForMonth(int year, int month) {
    final monthKey = '${year}-${month.toString().padLeft(2, '0')}';
    return _monthlyGoals[monthKey]?.goalSteps ?? 10000;
  }

  // Check if user has set a goal for current month
  bool get hasCurrentMonthGoal {
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _monthlyGoals.containsKey(currentMonthKey);
  }

  // Get current month key
  String get currentMonthKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // Calculated goals based on step goal
  double get goalCalories => _calculateCaloriesFromSteps(goalSteps);
  double get goalDistance => _calculateDistanceFromSteps(goalSteps);

  StepGoalProvider() {
    _loadGoalsFromFirestore();
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

  Future<void> _loadGoalsFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            // Load monthly goals
            final monthlyGoalsData =
                data['monthlyGoals'] as Map<String, dynamic>?;
            if (monthlyGoalsData != null) {
              _monthlyGoals.clear();
              for (final entry in monthlyGoalsData.entries) {
                final monthKey = entry.key;
                final goalData = entry.value as Map<String, dynamic>;
                _monthlyGoals[monthKey] = MonthlyGoal.fromMap(goalData);
              }
            }

            // Check if we need to migrate from old single goal system
            final oldGoalSteps = data['goalSteps'] as int?;
            final hasMonthlyGoalMetDays = data['monthlyGoalMetDays'] != null;
            final hasOldGoalMetDays = data['goalMetDays'] != null;
            print(
                '🔍 Checking for migration - oldGoalSteps: $oldGoalSteps, monthlyGoals empty: ${_monthlyGoals.isEmpty}, hasMonthlyGoalMetDays: $hasMonthlyGoalMetDays, hasOldGoalMetDays: $hasOldGoalMetDays');

            if (oldGoalSteps != null && _monthlyGoals.isEmpty) {
              print('🔄 Migrating from old goal system to monthly goals...');
              await _migrateFromOldGoalSystem(oldGoalSteps);
            } else if (!hasMonthlyGoalMetDays) {
              print(
                  '🔄 Initializing monthlyGoalMetDays structure for existing user...');
              await _initializeMonthlyGoalMetDaysStructure();
            } else if (hasOldGoalMetDays && !hasMonthlyGoalMetDays) {
              print(
                  '🔄 Migrating old goalMetDays to monthlyGoalMetDays structure...');
              await _migrateOldGoalMetDays(
                  data['goalMetDays'] as List<dynamic>?);
            } else {
              print(
                  '✅ No migration needed - monthly goals and monthlyGoalMetDays already exist');
            }

            notifyListeners();
          }
        }
      }
    } catch (e) {
      print('Error loading goals from Firestore: $e');
    }
  }

  // Migrate from old single goal system to monthly goals
  Future<void> _migrateFromOldGoalSystem(int oldGoalSteps) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final now = DateTime.now();
        final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

        // Create monthly goal for current month
        final monthlyGoal = MonthlyGoal(
          year: now.year,
          month: now.month,
          goalSteps: oldGoalSteps,
          setDate: now,
        );

        _monthlyGoals[monthKey] = monthlyGoal;

        // Save to Firestore and remove old goalSteps field
        final goalsMap = <String, dynamic>{};
        for (final entry in _monthlyGoals.entries) {
          goalsMap[entry.key] = entry.value.toMap();
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'monthlyGoals': goalsMap,
          'goalSteps': FieldValue.delete(), // Remove old field
          'monthlyGoalMetDays.$monthKey':
              <String>[], // Initialize monthly goal met days
        });

        print(
            '✅ Successfully migrated to monthly goals system, removed old goalSteps field, and initialized monthlyGoalMetDays');
      }
    } catch (e) {
      print('Error migrating from old goal system: $e');
    }
  }

  // Set goal for current month
  void setCurrentMonthGoal(int newGoal) {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final monthlyGoal = MonthlyGoal(
      year: now.year,
      month: now.month,
      goalSteps: newGoal,
      setDate: now,
    );

    _monthlyGoals[monthKey] = monthlyGoal;
    notifyListeners();
    _saveGoalsToFirestore();

    // Initialize monthly goal met days structure for this month
    _initializeMonthlyGoalMetDays(monthKey);
  }

  // Initialize monthly goal met days structure for existing users
  Future<void> _initializeMonthlyGoalMetDaysStructure() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final now = DateTime.now();
        final currentMonthKey =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';

        // Initialize the monthlyGoalMetDays structure with current month
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'monthlyGoalMetDays': {
            currentMonthKey:
                <String>[], // Initialize with empty array for current month
          },
        });

        print('✅ Initialized monthlyGoalMetDays structure for existing user');
      }
    } catch (e) {
      print('Error initializing monthlyGoalMetDays structure: $e');
    }
  }

  // Migrate old goalMetDays to monthlyGoalMetDays structure
  Future<void> _migrateOldGoalMetDays(List<dynamic>? oldGoalMetDays) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (oldGoalMetDays != null && oldGoalMetDays.isNotEmpty) {
          // Group old goal met days by month
          final Map<String, List<String>> monthlyGoalMetDays = {};

          for (final dayString in oldGoalMetDays) {
            if (dayString is String) {
              try {
                final day = DateTime.parse(dayString);
                final monthKey =
                    '${day.year}-${day.month.toString().padLeft(2, '0')}';

                monthlyGoalMetDays
                    .putIfAbsent(monthKey, () => [])
                    .add(dayString);
              } catch (e) {
                print('Error parsing date: $dayString');
              }
            }
          }

          // Save the migrated structure
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'monthlyGoalMetDays': monthlyGoalMetDays,
            'goalMetDays': FieldValue.delete(), // Remove old field
          });

          print(
              '✅ Successfully migrated ${oldGoalMetDays.length} goal met days to monthly structure');
        } else {
          // No old goal met days, just initialize empty structure
          await _initializeMonthlyGoalMetDaysStructure();
        }
      }
    } catch (e) {
      print('Error migrating old goal met days: $e');
    }
  }

  // Initialize monthly goal met days structure for a month
  Future<void> _initializeMonthlyGoalMetDays(String monthKey) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check if monthlyGoalMetDays already exists for this month
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final monthlyGoalMetDaysData =
                data['monthlyGoalMetDays'] as Map<String, dynamic>?;

            // If monthlyGoalMetDays doesn't exist or doesn't have this month, initialize it
            if (monthlyGoalMetDaysData == null ||
                !monthlyGoalMetDaysData.containsKey(monthKey)) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                'monthlyGoalMetDays.$monthKey':
                    <String>[], // Initialize with empty array
              });
              print('✅ Initialized monthlyGoalMetDays for month: $monthKey');
            }
          }
        }
      }
    } catch (e) {
      print('Error initializing monthly goal met days: $e');
    }
  }

  // Set goal for a specific month
  void setGoalForMonth(int year, int month, int goalSteps) {
    final monthKey = '${year}-${month.toString().padLeft(2, '0')}';

    final monthlyGoal = MonthlyGoal(
      year: year,
      month: month,
      goalSteps: goalSteps,
      setDate: DateTime.now(),
    );

    _monthlyGoals[monthKey] = monthlyGoal;
    notifyListeners();
    _saveGoalsToFirestore();
  }

  Future<void> _saveGoalsToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final goalsMap = <String, dynamic>{};
        for (final entry in _monthlyGoals.entries) {
          goalsMap[entry.key] = entry.value.toMap();
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'monthlyGoals': goalsMap,
        });
      }
    } catch (e) {
      print('Error saving goals to Firestore: $e');
    }
  }

  Future<void> refreshGoals() async {
    await _loadGoalsFromFirestore();
  }

  // Check if we need to prompt for a new month's goal - MANDATORY
  bool shouldPromptForNewMonthGoal() {
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    print("🔍 shouldPromptForNewMonthGoal() check:");
    print("  - current month key: $currentMonthKey");
    print(
        "  - has goal for current month: ${_monthlyGoals.containsKey(currentMonthKey)}");

    // Check if we have a goal for the current month
    if (_monthlyGoals.containsKey(currentMonthKey)) {
      print("  - result: false (already have goal for this month)");
      return false; // Already have a goal for this month
    }

    // Check if this is a new month (first time opening app this month)
    final lastGoalDate = _getLastGoalSetDate();
    if (lastGoalDate != null) {
      final lastGoalMonth = DateTime(lastGoalDate.year, lastGoalDate.month);
      final currentMonth = DateTime(now.year, now.month);

      print("  - last goal date: $lastGoalDate");
      print("  - last goal month: $lastGoalMonth");
      print("  - current month: $currentMonth");
      print("  - is new month: ${lastGoalMonth.isBefore(currentMonth)}");

      // If last goal was set in a different month, prompt for new goal
      final result = lastGoalMonth.isBefore(currentMonth);
      print("  - result: $result (new month detected)");
      return result;
    }

    // No previous goals, prompt for first goal - MANDATORY
    print("  - result: true (no previous goals)");
    return true;
  }

  // Check if user MUST set a goal (for mandatory enforcement)
  bool mustSetGoal() {
    final hasGoal = hasCurrentMonthGoal;
    final shouldPrompt = shouldPromptForNewMonthGoal();
    final result = !hasGoal || shouldPrompt;

    print("🔍 mustSetGoal() check:");
    print("  - hasCurrentMonthGoal: $hasGoal");
    print("  - shouldPromptForNewMonthGoal: $shouldPrompt");
    print("  - result (mustSetGoal): $result");
    print("  - current month key: $currentMonthKey");
    print("  - monthly goals keys: ${_monthlyGoals.keys.toList()}");
    print(
        "  - monthly goals data: ${_monthlyGoals.map((k, v) => MapEntry(k, '${v.goalSteps} steps set on ${v.setDate}'))}");

    return result;
  }

  // Check if goal is locked for current month (cannot be changed once set)
  bool isGoalLockedForCurrentMonth() {
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // If we have a goal for current month, it's locked
    return _monthlyGoals.containsKey(currentMonthKey);
  }

  // Check if goal can be changed for current month
  bool canChangeGoalForCurrentMonth() {
    return !isGoalLockedForCurrentMonth();
  }

  // Get the goal set date for current month
  DateTime? getGoalSetDateForCurrentMonth() {
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final monthlyGoal = _monthlyGoals[currentMonthKey];
    return monthlyGoal?.setDate;
  }

  // Get the date when the last goal was set
  DateTime? _getLastGoalSetDate() {
    if (_monthlyGoals.isEmpty) return null;

    DateTime? latestDate;
    for (final goal in _monthlyGoals.values) {
      if (latestDate == null || goal.setDate.isAfter(latestDate)) {
        latestDate = goal.setDate;
      }
    }
    return latestDate;
  }
}
