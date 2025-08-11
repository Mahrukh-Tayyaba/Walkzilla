import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'home.dart';
import 'dart:async';
import 'steps_screen.dart';
import 'calories_screen.dart';
import 'distance_screen.dart';
import 'services/health_service.dart';
import 'widgets/steps_goal_card.dart';
import 'package:provider/provider.dart';
import 'providers/step_goal_provider.dart';
import 'streaks_screen.dart';
import 'providers/streak_provider.dart';

class HealthDashboard extends StatefulWidget {
  const HealthDashboard({super.key});

  @override
  State<HealthDashboard> createState() => _HealthDashboardState();
}

class _HealthDashboardState extends State<HealthDashboard> {
  final HealthService _healthService = HealthService();
  final Health health = Health();
  int _steps = 0;
  double _calories = 0.0;
  double _distance = 0.0;

  bool _isGoalEnabled = true;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    // Load data in background without blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHealth();
      _loadAndRefreshStreakData();
    });

    // Set up periodic refresh for real-time updates (every 30 seconds)
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshDashboardData();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeHealth() async {
    try {
      await fetchHealthData();
    } catch (e) {
      // Show error state instead of simulated data
      if (mounted) {
        setState(() {
          _steps = 0;
          _calories = 0.0;
          _distance = 0.0;
        });
      }
    }
  }

  // Convert steps to calories using the same formula as calories screen
  double _calculateCaloriesFromSteps(int steps) {
    return steps * 0.04; // Same formula: steps × 0.04
  }

  Future<void> fetchHealthData() async {
    if (!mounted) return;

    try {
      // Check permissions using the same method as calories screen
      bool hasPermissions =
          await _healthService.checkHealthConnectPermissions();

      if (!hasPermissions) {
        bool granted = await _healthService.requestHealthConnectPermissions();

        if (!granted) {
          if (mounted) {
            setState(() {
              _steps = 0;
              _calories = 0.0;
              _distance = 0.0;
            });
          }
          return;
        }
      }

      // Use the hybrid approach same as home.dart for real-time updated data
      int todaySteps = await _healthService.fetchHybridRealTimeSteps();

      double calculatedCalories = _calculateCaloriesFromSteps(todaySteps);

      // Fetch today's distance using the same method as distance_screen.dart
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      double todayDistance = 0.0;
      try {
        todayDistance = await _healthService.fetchDistance(
          start: startOfToday,
          end: now,
        );
      } catch (distanceError) {
        todayDistance = 0.0;
      }

      if (mounted) {
        setState(() {
          _steps = todaySteps;
          _calories = calculatedCalories;
          _distance = todayDistance; // Store in meters
        });
      }

      // Update streak system based on today's steps and goal
      await _updateStreakIfNeeded(todaySteps);
    } catch (e) {
      if (mounted) {
        setState(() {
          _steps = 0;
          _calories = 0.0;
          _distance = 0.0;
        });

        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Failed to load health data. Please check permissions.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => fetchHealthData(),
            ),
          ),
        );
      }
    }
  }

  // New method to update streak based on today's steps using hybrid data
  Future<void> _updateStreakIfNeeded(int todaySteps) async {
    try {
      final stepGoalProvider = context.read<StepGoalProvider>();
      final streakProvider = context.read<StreakProvider>();
      final goalSteps = stepGoalProvider.goalSteps;

      // Get the goal set date from StepGoalProvider
      final goalSetDate = stepGoalProvider.getGoalSetDateForCurrentMonth();

      // Also fetch yesterday's steps so we can correctly attribute streaks
      // to the right day and avoid off-by-one errors when the goal is met.
      final now = DateTime.now();
      final startOfYesterday = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
      final endOfYesterday = startOfYesterday.add(const Duration(days: 1));
      int yesterdaySteps = 0;
      try {
        yesterdaySteps = await _healthService.getStepsForDateRange(
            startOfYesterday, endOfYesterday);
      } catch (_) {
        yesterdaySteps = 0;
      }

      // Use the enhanced method that checks both yesterday and today
      await streakProvider.checkAndUpdateStreakWithYesterday(
          todaySteps, yesterdaySteps, goalSteps, goalSetDate);
    } catch (e) {
      // Error handling for streak update
    }
  }

  // Method to refresh dashboard data with hybrid approach
  Future<void> _refreshDashboardData() async {
    if (!mounted) return;

    try {
      // Use hybrid approach for real-time updated steps
      final todaySteps = await _healthService.fetchHybridRealTimeSteps();
      final calculatedCalories = _calculateCaloriesFromSteps(todaySteps);

      // Fetch distance
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      double todayDistance = 0.0;
      try {
        todayDistance = await _healthService.fetchDistance(
          start: startOfToday,
          end: now,
        );
      } catch (e) {
        // Distance fetch failed during refresh
      }

      if (mounted) {
        setState(() {
          _steps = todaySteps;
          _calories = calculatedCalories;
          _distance = todayDistance;
        });
      }

      // Update streak with fresh data
      await _updateStreakIfNeeded(todaySteps);
    } catch (e) {
      // Error refreshing dashboard data
    }
  }

  // Method to load and refresh streak data
  Future<void> _loadAndRefreshStreakData() async {
    try {
      final streakProvider = context.read<StreakProvider>();

      // First, reload any existing streak data from Firestore
      await streakProvider.reloadStreaks();

      // Then refresh with current step data
      await _refreshStreakData();
    } catch (e) {
      // Error loading and refreshing streak data
    }
  }

  // New method to refresh streak data
  Future<void> _refreshStreakData() async {
    try {
      final stepGoalProvider = context.read<StepGoalProvider>();
      final streakProvider = context.read<StreakProvider>();
      final goalSteps = stepGoalProvider.goalSteps;

      // Get today's steps to check if goal is met using hybrid approach
      final todaySteps = await _healthService.fetchHybridRealTimeSteps();

      // Get the goal set date from StepGoalProvider
      final goalSetDate = stepGoalProvider.getGoalSetDateForCurrentMonth();

      // Fetch yesterday too and use enhanced method for correctness
      final now = DateTime.now();
      final startOfYesterday = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
      final endOfYesterday = startOfYesterday.add(const Duration(days: 1));
      int yesterdaySteps = 0;
      try {
        yesterdaySteps = await _healthService.getStepsForDateRange(
            startOfYesterday, endOfYesterday);
      } catch (_) {
        yesterdaySteps = 0;
      }

      await streakProvider.checkAndUpdateStreakWithYesterday(
          todaySteps, yesterdaySteps, goalSteps, goalSetDate);
    } catch (e) {
      // Error refreshing streak data
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      // Navigate to Home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _showMonthlyGoalDialog() {
    final stepGoalProvider = context.read<StepGoalProvider>();
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final hasCurrentGoal = stepGoalProvider.hasCurrentMonthGoal;
    int tempGoalSteps = hasCurrentGoal ? stepGoalProvider.goalSteps : 10000;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Set Step Goal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month,
                              color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Setting goal for ${DateFormat('MMMM yyyy').format(now)}',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            if (tempGoalSteps > 1000) {
                              setState(() => tempGoalSteps -= 1000);
                            }
                          },
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${tempGoalSteps.toString()} steps',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setState(() => tempGoalSteps += 1000);
                          },
                          color: Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            stepGoalProvider.setCurrentMonthGoal(tempGoalSteps);
                            Navigator.pop(context);

                            // Update streak after goal change
                            await _updateStreakIfNeeded(_steps);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Monthly step goal set!'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    e.toString().replaceAll('Exception: ', '')),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          hasCurrentGoal ? 'Update Goal' : 'Set Goal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1DC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF1DC),
        // elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Dashboard',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshDashboardData();
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateSelector(),
                const SizedBox(height: 20),
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStepsCard(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Calories',
                        '${_calories.toInt()} kcal',
                        Icons.bolt_rounded,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'Distance',
                        '${_distance.toStringAsFixed(0)} M',
                        Icons.route,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDailyStreak(),
                const SizedBox(height: 20),
                _buildGoalSection(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final dates =
        List.generate(7, (index) => now.subtract(Duration(days: 6 - index)));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: dates.map((date) {
            final isSelected = date.day == now.day;
            final dayName = DateFormat('E').format(date);
            final dayNum = date.day.toString();

            return Flexible(
              child: Container(
                height: 60,
                constraints: BoxConstraints(
                  minWidth: isSelected ? 44 : 42,
                ),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFFED3E57) : Colors.transparent,
                  borderRadius: BorderRadius.circular(isSelected ? 8 : 12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayNum,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStepsCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StepsScreen(
              currentSteps: _steps,
              goalSteps: context.watch<StepGoalProvider>().goalSteps,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEF7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E7043).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.directions_walk,
                            color: const Color(0xFF1E7043), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Steps',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_steps steps',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Text(
                    'Today',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 80,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    // Generate some sample data for the bars
                    final barHeights = [
                      0.4,
                      0.8,
                      0.6,
                      0.3,
                      0.7,
                      0.5,
                      0.9
                    ]; // Relative heights
                    final height = 60 * barHeights[index]; // Max height 60

                    return Container(
                      width: 20,
                      height: height,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E7043),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (title == 'Calories') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CaloriesScreen(),
              ),
            );
          } else if (title == 'Distance') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DistanceScreen(),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 30),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyStreak() {
    final streak = context.watch<StreakProvider>().currentStreak;
    final goalMetDays = context.watch<StreakProvider>().goalMetDays;
    final today = DateTime.now();
    final weekDates =
        List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StreaksScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEF7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFED3E57).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: const Color(0xFFED3E57),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Daily Streak',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '$streak',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFED3E57),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: const Color(0xFFED3E57),
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                final date = weekDates[index];
                final isCompleted = goalMetDays.any((d) =>
                    d.year == date.year &&
                    d.month == date.month &&
                    d.day == date.day);
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                return Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFFED3E57)
                            : Colors.grey[100],
                        shape: BoxShape.circle,
                        boxShadow: isCompleted
                            ? [
                                BoxShadow(
                                  color:
                                      const Color(0xFFED3E57).withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                        border: isToday
                            ? Border.all(
                                color: Colors.black.withOpacity(0.15), width: 2)
                            : null,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: isCompleted ? Colors.white : Colors.grey[300],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('E').format(date)[0],
                      style: TextStyle(
                        color: isCompleted
                            ? const Color(0xFFED3E57)
                            : const Color.fromRGBO(189, 189, 189, 1),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSection() {
    final goalSteps = context.watch<StepGoalProvider>().goalSteps;
    return StepsGoalCard(
      currentSteps: _steps,
      goalSteps: goalSteps,
      isGoalEnabled: _isGoalEnabled,
      isEditable: true,
      onToggle: (value) => setState(() => _isGoalEnabled = value),
    );
  }
}
