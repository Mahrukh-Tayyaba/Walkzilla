import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'home.dart';
import 'dart:async';

class HealthDashboard extends StatefulWidget {
  const HealthDashboard({super.key});

  @override
  State<HealthDashboard> createState() => _HealthDashboardState();
}

class _HealthDashboardState extends State<HealthDashboard> {
  final Health health = Health();
  int _steps = 0;
  double _calories = 0.0;
  double _heartRate = 0.0;
  bool _isGoalEnabled = true;
  int _goalSteps = 15000;
  int _selectedIndex = 1; // Health section selected by default
  int _waterGlasses = 8;
  String _reminderFrequency = 'Every 2 hours';
  bool _notificationsEnabled = true;
  int _currentWaterGlasses = 0;
  DateTime _lastReminderTime = DateTime.now();
  bool _isReminderActive = false;
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    fetchHealthData();
    _setupWaterReminder();
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchHealthData() async {
    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.HEART_RATE
    ];
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final startDate = midnight;
    final endDate = now;

    try {
      bool permissionsGranted = await health.requestAuthorization(types);

      if (permissionsGranted) {
        // Get steps specifically
        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          startTime: startDate,
          endTime: endDate,
          types: types,
        );

        int totalSteps = 0;
        double totalCalories = 0.0;
        double heartRate = 0.0;

        for (var data in healthData) {
          if (data.type == HealthDataType.STEPS) {
            totalSteps += (data.value as double).toInt();
          } else if (data.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
            totalCalories += data.value as double;
          } else if (data.type == HealthDataType.HEART_RATE) {
            heartRate = data.value as double;
          }
        }

        if (mounted) {
          setState(() {
            _steps = totalSteps;
            _calories = totalCalories;
            _heartRate = heartRate;
          });
        }
      } else {
        print("Permissions not granted");
      }
    } catch (e) {
      print("Error fetching health data: $e");
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
                          'Hydration Reminder Setup',
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
                    const SizedBox(height: 8),
                    Text(
                      'Set your daily water intake goal and get reminders throughout the day.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Reminder Frequency',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
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
                              setState(() => tempReminderFrequency = newValue);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                              content:
                                  const Text('Water reminder settings saved!'),
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

  void _showStepGoalDialog() {
    int tempGoalSteps = _goalSteps;

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
                          this.setState(() {
                            _goalSteps = tempGoalSteps;
                          });
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
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: CircleAvatar(
                backgroundColor: Colors.grey[200],
                radius: 18,
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.black54,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
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
                          Colors.orange)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildMetricCard(
                          'Heart Rate',
                          '${_heartRate.toInt()} BPM',
                          Icons.favorite,
                          Colors.red)),
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
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_walk, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Steps',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$_steps',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 100,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 10000,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        return Text(
                          days[value.toInt()],
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12),
                        );
                      },
                      reservedSize: 22,
                    ),
                  ),
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barGroups: [
                  _generateBarGroup(0, 5000),
                  _generateBarGroup(1, 6000),
                  _generateBarGroup(2, 7500),
                  _generateBarGroup(3, 5500),
                  _generateBarGroup(4, 8000),
                  _generateBarGroup(5, 7000),
                  _generateBarGroup(6, _steps.toDouble()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _generateBarGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: Colors.green,
          width: 12,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 10000,
            color: Colors.grey[200],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyStreak() {
    return Container(
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
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final isCompleted = index < 3;
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
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: isCompleted ? Colors.white : Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
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
        ],
      ),
    );
  }

  Widget _buildGoalSection() {
    final progress = _steps / _goalSteps;
    final remainingSteps = _goalSteps - _steps;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.blue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Goal',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: _isGoalEnabled,
                  onChanged: (value) => setState(() => _isGoalEnabled = value),
                  activeColor: Colors.green,
                ),
              ),
            ],
          ),
          if (_isGoalEnabled) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _showStepGoalDialog,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_goalSteps.toString()} Steps per day',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Colors.blue[400],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Stack(
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.blue[400],
                      borderRadius: BorderRadius.circular(2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today: ${_steps.toString()} steps',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  '${remainingSteps.toString()} steps to go',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
