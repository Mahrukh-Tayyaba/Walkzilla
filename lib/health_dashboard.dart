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
    print("🚀 Health Dashboard initState called");
    // Load data in background without blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHealth();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeHealth() async {
    print("🔧 _initializeHealth called");
    try {
      // Skip the redundant permission check since fetchHealthData() handles it
      // and the individual screens are working, so permissions should be fine
      print("🔄 Proceeding directly to fetchHealthData()");
      await fetchHealthData();
    } catch (e) {
      print("Error initializing health: $e");
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
      print("🏥 Starting health data fetch for dashboard...");

      // Check permissions using the same method as calories screen
      bool hasPermissions =
          await _healthService.checkHealthConnectPermissions();
      print("🔐 Health Connect permissions status: $hasPermissions");

      if (!hasPermissions) {
        print("❌ No Health Connect permissions, requesting them...");
        bool granted = await _healthService.requestHealthConnectPermissions();
        print("🔐 Permission request result: $granted");

        if (!granted) {
          print("❌ Health Connect permissions not granted");
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

      print("🔄 Fetching today's steps for dashboard...");

      // Use the same method as steps_screen.dart
      int todaySteps = await _healthService.fetchStepsData();

      double calculatedCalories = _calculateCaloriesFromSteps(todaySteps);

      // Fetch today's distance using the same method as distance_screen.dart
      print("🔄 Fetching today's distance for dashboard...");
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      double todayDistance = 0.0;
      try {
        todayDistance = await _healthService.fetchDistance(
          start: startOfToday,
          end: now,
        );
        print("📏 Dashboard - Distance fetch successful: $todayDistance");
      } catch (distanceError) {
        print("❌ Dashboard - Distance fetch failed: $distanceError");
        todayDistance = 0.0;
      }

      print("📊 Dashboard - Today's steps: $todaySteps");
      print("🔥 Dashboard - Calculated calories: $calculatedCalories kcal");
      print("📏 Dashboard - Raw distance: $todayDistance");
      print("📏 Dashboard - Distance: ${todayDistance.toStringAsFixed(0)} m");

      if (mounted) {
        setState(() {
          _steps = todaySteps;
          _calories = calculatedCalories;
          _distance = todayDistance; // Store in meters
        });
      }

      print("✅ Dashboard updated - Steps: $_steps, Calories: $_calories");
    } catch (e) {
      print("❌ Error fetching health data for dashboard: $e");
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

  void _showHealthConnectInstallDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Health Connect Required'),
          content: const Text(
            'This app requires Health Connect to track your health data. '
            'Please install Health Connect from the Play Store to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // Open device settings since there's no direct method to open Health Connect settings
                await health.requestAuthorization([
                  HealthDataType.STEPS,
                  HealthDataType.ACTIVE_ENERGY_BURNED,
                  HealthDataType.DISTANCE_DELTA,
                ]);
              },
              child: const Text('Grant Access'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionRequestDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Health Permissions Required'),
          content: const Text(
            'This app needs access to your health data to track your activities. '
            'Please grant the necessary permissions to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await fetchHealthData();
              },
              child: const Text('Grant Permissions'),
            ),
          ],
        );
      },
    );
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

  void _showStepGoalDialog() {
    final stepGoalProvider = context.read<StepGoalProvider>();
    int tempGoalSteps = stepGoalProvider.goalSteps;
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
                        onPressed: () {
                          stepGoalProvider.setGoal(tempGoalSteps);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Step goal updated!'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Set Goal',
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateSelector(),
              const SizedBox(height: 24),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildStepsCard(),
              const SizedBox(height: 16),
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
                      Icons.directions_walk,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDailyStreak(),
              const SizedBox(height: 24),
              _buildGoalSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.blue[400],
              unselectedItemColor: Colors.grey[400],
              selectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_outline_rounded),
                  activeIcon: Icon(Icons.favorite_rounded),
                  label: 'Health',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.group_outlined),
                  activeIcon: Icon(Icons.group_rounded),
                  label: 'Friends',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
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
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: dates.map((date) {
          final isSelected = date.day == now.day;
          final dayName = DateFormat('E').format(date);
          final dayNum = date.day.toString();

          return Container(
            width: 45,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.orange : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dayNum,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
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
                          color: const Color(0xFF2E7D32).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.directions_walk,
                            color: Color(0xFF2E7D32), size: 18),
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
                        color: const Color(0xFF2E7D32),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.orange,
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
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.orange,
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
                        color: isCompleted ? Colors.orange : Colors.grey[100],
                        shape: BoxShape.circle,
                        boxShadow: isCompleted
                            ? [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.2),
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
                        color: isCompleted ? Colors.orange : Colors.grey[400],
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
      onEdit: _showStepGoalDialog,
      onToggle: (value) => setState(() => _isGoalEnabled = value),
    );
  }
}
