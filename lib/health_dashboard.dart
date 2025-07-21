import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'home.dart';
import 'dart:async';
import 'steps_screen.dart';
import 'calories_screen.dart';
import 'heartrate_screen.dart';
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
  double _heartRate = 0.0;
  bool _isGoalEnabled = true;
  int _selectedIndex = 1;
  int _waterGlasses = 8;
  String _reminderFrequency = 'Every 2 hours';
  bool _notificationsEnabled = true;
  int _currentWaterGlasses = 0;
  final DateTime _lastReminderTime = DateTime.now();
  bool _isReminderActive = false;
  Timer? _reminderTimer;
  bool _isLoading = true;

  // Real data will be fetched from Health Service
  List<Map<String, dynamic>> _weeklyData = [];
  List<Map<String, dynamic>> _heartRateData = [];
  List<Map<String, dynamic>> _caloriesData = [];

  @override
  void initState() {
    super.initState();
    _initializeHealth();
    _setupWaterReminder();
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeHealth() async {
    try {
      bool isAndroid = Theme.of(context).platform == TargetPlatform.android;
      if (isAndroid) {
        bool? healthConnectAvailable = await health.hasPermissions([
          HealthDataType.STEPS,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.HEART_RATE,
        ], permissions: [
          HealthDataAccess.READ,
          HealthDataAccess.READ,
          HealthDataAccess.READ,
        ]);

        if (healthConnectAvailable != true) {
          _showHealthConnectInstallDialog();
          return;
        }
      }

      await fetchHealthData();
    } catch (e) {
      print("Error initializing health: $e");
      // Show error state instead of simulated data
      if (mounted) {
        setState(() {
          _isLoading = false;
          _steps = 0;
          _calories = 0.0;
          _heartRate = 0.0;
        });
      }
    }
  }

  Future<void> fetchHealthData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      print("Starting health data fetch...");
      bool hasPermissions = await _healthService.checkExistingPermissions();

      if (!hasPermissions) {
        print("No health permissions granted");
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _steps = 0;
          _calories = 0.0;
          _heartRate = 0.0;
        });
        return;
      }

      print("Fetching health data from service...");
      final healthData = await _healthService.fetchHealthData();

      if (!mounted) return;

      // Extract data from the nested structure
      final stepsData = healthData['steps'] as Map<String, dynamic>;
      final heartRateData = healthData['heartRate'] as Map<String, dynamic>;
      final caloriesData = healthData['calories'] as Map<String, dynamic>;

      setState(() {
        _steps = stepsData['count'] as int;
        _heartRate = (heartRateData['beatsPerMinute'] as num).toDouble();
        _calories =
            (caloriesData['energy']['inKilocalories'] as num).toDouble();
        _isLoading = false;
      });

      print(
          "Updated UI with health data: Steps: $_steps, Heart Rate: $_heartRate, Calories: $_calories");
    } catch (e) {
      print("Error fetching health data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _steps = 0;
          _calories = 0.0;
          _heartRate = 0.0;
        });
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
                  HealthDataType.HEART_RATE,
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

  void _setupWaterReminder() {
    if (_notificationsEnabled && _isReminderActive) {
      // Cancel any existing timer
      _stopReminder();

      // Calculate reminder interval in hours
      int reminderHours;
      if (_reminderFrequency == 'Every hour') {
        reminderHours = 1;
      } else {
        // Extract number from strings like "Every 2 hours"
        reminderHours = int.parse(_reminderFrequency.split(' ')[1]);
      }

      // Set up periodic timer for water reminder
      _reminderTimer = Timer.periodic(
        Duration(hours: reminderHours),
        (timer) {
          if (_notificationsEnabled && _isReminderActive && mounted) {
            _showWaterReminder();
          } else {
            timer.cancel();
          }
        },
      );
    }
  }

  void _stopReminder() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
    _isReminderActive = false;
    setState(() {});
  }

  void _showWaterReminder() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.water_drop, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Time to drink water!'),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentWaterGlasses++;
                });
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              child: const Text('MARK AS DONE',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showHydrationSetupDialog() {
    int tempWaterGlasses = _waterGlasses;
    String tempReminderFrequency = _reminderFrequency;
    bool tempNotificationsEnabled = _notificationsEnabled;

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
              child: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Hydration Reminder Setup',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
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
                      const SizedBox(height: 8),
                      Text(
                        'Set your daily water intake goal and get reminders throughout the day.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'How many glasses of water do you want to drink today?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (tempWaterGlasses > 1) {
                                setState(() => tempWaterGlasses--);
                              }
                            },
                            color: Colors.blue,
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Icon(Icons.water_drop,
                                  color: Colors.blue[400], size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '$tempWaterGlasses glasses',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setState(() => tempWaterGlasses++);
                            },
                            color: Colors.blue,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Reminder Frequency',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 45,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: tempReminderFrequency,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            items: [
                              'Every hour',
                              'Every 2 hours',
                              'Every 3 hours',
                              'Every 4 hours'
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(
                                    () => tempReminderFrequency = newValue);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Enable Notifications',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Switch.adaptive(
                            value: tempNotificationsEnabled,
                            onChanged: (bool value) {
                              setState(() => tempNotificationsEnabled = value);
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // Save all changes
                            this.setState(() {
                              _waterGlasses = tempWaterGlasses;
                              _reminderFrequency = tempReminderFrequency;
                              _notificationsEnabled = tempNotificationsEnabled;
                              _isReminderActive = tempNotificationsEnabled;
                              _currentWaterGlasses =
                                  0; // Reset current glasses count
                            });

                            // Setup reminder if enabled
                            if (tempNotificationsEnabled) {
                              _setupWaterReminder();
                            } else {
                              _stopReminder();
                            }

                            Navigator.pop(context);

                            // Show confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Water reminder settings saved!'),
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
              ),
            );
          },
        );
      },
    );
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

  void _updateCurrentMetrics() {
    // Get today's data (last item in weekly data)
    final todayData = _weeklyData.last;
    setState(() {
      _steps = todayData['steps'];
      _calories = todayData['calories'];
      _heartRate = todayData['heartRate'].toDouble();
    });
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
                      'Heart Rate',
                      '${_heartRate.toInt()} BPM',
                      Icons.favorite,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDailyStreak(),
              const SizedBox(height: 24),
              _buildGoalSection(),
              const SizedBox(height: 24),
              _buildHydrationReminder(),
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
                child: BarChart(
                  BarChartData(
                    groupsSpace: 6,
                    alignment: BarChartAlignment.spaceEvenly,
                    maxY: 15000,
                    minY: 0,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final now = DateTime.now();
                            final date =
                                now.subtract(Duration(days: 6 - value.toInt()));
                            final dayInitial = DateFormat('E').format(date)[0];
                            return Padding(
                              padding: const EdgeInsets.only(top: 5.0),
                              child: Text(
                                dayInitial,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                          reservedSize: 16,
                        ),
                      ),
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: List.generate(
                      7,
                      (index) => _generateBarGroup(
                        index,
                        _weeklyData[index]['steps'].toDouble(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _generateBarGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: const Color(0xFF2E7D32),
          width: 18,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(3),
          ),
          backDrawRodData: BackgroundBarChartRodData(
            show: false,
            toY: 10000,
            color: Colors.grey[200],
          ),
        ),
      ],
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
                builder: (context) => CaloriesScreen(
                  currentCalories: _calories.toInt(),
                  goalCalories: 500,
                ),
              ),
            );
          } else if (title == 'Heart Rate') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HeartRateScreen(
                  currentBpm: _heartRate.toInt(),
                  lowestBpm: 65,
                  highestBpm: 85,
                  yesterdayBpm: 72,
                ),
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
                      title == 'Heart Rate'
                          ? '${_heartRate.toInt()} BPM'
                          : value,
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

  Widget _buildHydrationReminder() {
    return GestureDetector(
      onTap: _showHydrationSetupDialog,
      child: Container(
        padding: const EdgeInsets.all(16),
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.water_drop,
                color: Colors.blue[400],
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hydration Reminder',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Goal: $_waterGlasses glasses of water',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
