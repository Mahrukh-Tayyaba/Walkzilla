import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'services/health_service.dart';
import 'package:health/health.dart';

class CaloriesScreen extends StatefulWidget {
  const CaloriesScreen({
    super.key,
  });

  @override
  State<CaloriesScreen> createState() => _CaloriesScreenState();
}

class _CaloriesScreenState extends State<CaloriesScreen> {
  double _currentCalories = 0.0;
  double _yesterdayCalories = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCaloriesData();
  }

  // Convert steps to calories using the standard formula
  double _calculateCaloriesFromSteps(int steps) {
    // Standard formula: Calories Burned = Number of Steps × Calories per Step
    // Calories per step = 0.04 (standard walking calorie burn)
    return steps * 0.04;
  }

  Future<void> _fetchCaloriesData() async {
    setState(() => _isLoading = true);

    try {
      final healthService = HealthService();
      final now = DateTime.now();

      // Get today's start and end times
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = now;

      // Get yesterday's start and end times
      final yesterday = now.subtract(const Duration(days: 1));
      final startOfYesterday =
          DateTime(yesterday.year, yesterday.month, yesterday.day);
      final endOfYesterday = startOfYesterday.add(const Duration(days: 1));

      print("📅 Date ranges:");
      print(
          "  Today: ${startOfToday.toIso8601String()} to ${endOfToday.toIso8601String()}");
      print(
          "  Yesterday: ${startOfYesterday.toIso8601String()} to ${endOfYesterday.toIso8601String()}");

      // Fetch today's steps and convert to calories
      double todayCalories = 0.0;
      try {
        print("🔄 Fetching today's steps...");
        int todaySteps = await healthService.health.getTotalStepsInInterval(
              startOfToday,
              endOfToday,
            ) ??
            0;

        print("📊 Today's steps: $todaySteps");
        todayCalories = _calculateCaloriesFromSteps(todaySteps);
        print("✅ Today's calculated calories: $todayCalories kcal");
      } catch (e) {
        print("❌ Error fetching today's steps: $e");
        todayCalories = 0.0;
      }

      // Fetch yesterday's steps and convert to calories
      double yesterdayCalories = 0.0;
      try {
        print("🔄 Fetching yesterday's steps...");
        int yesterdaySteps = await healthService.health.getTotalStepsInInterval(
              startOfYesterday,
              endOfYesterday,
            ) ??
            0;

        print("📊 Yesterday's steps: $yesterdaySteps");
        yesterdayCalories = _calculateCaloriesFromSteps(yesterdaySteps);
        print("✅ Yesterday's calculated calories: $yesterdayCalories kcal");
      } catch (e) {
        print("❌ Error fetching yesterday's steps: $e");
        yesterdayCalories = 0.0;
      }

      if (mounted) {
        setState(() {
          _currentCalories = todayCalories;
          _yesterdayCalories = yesterdayCalories;
          _isLoading = false;
        });
      }

      print(
          "✅ Calories data calculated - Today: $todayCalories kcal, Yesterday: $yesterdayCalories kcal");
    } catch (e) {
      print("❌ Error calculating calories data: $e");
      if (mounted) {
        setState(() {
          _currentCalories = 0.0;
          _yesterdayCalories = 0.0;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('calories_screen_scaffold'),
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        key: const Key('calories_screen_appbar'),
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Active Calories',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _fetchCaloriesData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        key: const Key('calories_screen_scrollview'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 20.0),
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Fetching calories data...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircularPercentIndicator(
                        key: const Key('calories_circular_indicator'),
                        radius: 85.0,
                        lineWidth: 10.0,
                        percent:
                            _currentCalories / 500, // Default goal of 500 kcal
                        center: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: Colors.orange,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentCalories.toStringAsFixed(0),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'of 500 kcal',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        progressColor: Colors.orange,
                        backgroundColor: Colors.orange.withOpacity(0.2),
                        circularStrokeCap: CircularStrokeCap.round,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      key: const Key('mini_challenge_card'),
                      title: 'Mini Challenge of the Day',
                      icon: Icons.flag_outlined,
                      iconColor: Colors.orange,
                      content: _currentCalories >= 200
                          ? 'Challenge completed! 🎉'
                          : 'Burn 200 kcal today!',
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      key: const Key('daily_tip_card'),
                      title: 'Daily Tip',
                      icon: Icons.lightbulb,
                      iconColor: Colors.orange,
                      content:
                          'Small bursts of activity like a brisk walk or dancing can boost your calorie burn!',
                    ),
                    const SizedBox(height: 24),
                    Container(
                      key: const Key('calories_comparison_row'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Row(
                        children: [
                          // Today
                          Expanded(
                            child: Container(
                              key: const Key('today_calories_container'),
                              margin: const EdgeInsets.only(
                                  left: 8, top: 4, bottom: 4, right: 4),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 0),
                              decoration: BoxDecoration(
                                color: const Color(
                                    0xFFFFF6ED), // very light orange
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_outlined,
                                    color: Colors.orange,
                                    size: 18,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Today',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 0),
                                  Text(
                                    '${_currentCalories.toStringAsFixed(0)} kcal',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Yesterday
                          Expanded(
                            child: Container(
                              key: const Key('yesterday_calories_container'),
                              margin: const EdgeInsets.only(
                                  right: 8, top: 4, bottom: 4, left: 4),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 0),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFF2F7FF), // very light blue
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_outlined,
                                    color: Colors.blue,
                                    size: 18,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Yesterday',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 0),
                                  Text(
                                    _yesterdayCalories > 0
                                        ? '${_yesterdayCalories.toStringAsFixed(0)} kcal'
                                        : 'No data',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _yesterdayCalories > 0
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildInfoCard(
                      key: const Key('fun_fact_card'),
                      title: 'Fun Fact',
                      icon: Icons.star_border_rounded,
                      iconColor: Colors.amber,
                      content:
                          'Did you know? Active calories are burned during exercise and daily activities!',
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String content,
    Key? key,
  }) {
    if (key == const Key('daily_tip_card')) {
      // Custom style for daily tip card
      return Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0), // light orange
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lightbulb,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (key == const Key('mini_challenge_card')) {
      // Custom style for mini challenge card
      return Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
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
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0), // light orange
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Mini Challenge',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Burn 200 kcal today!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (_currentCalories / 200)
                    .clamp(0.0, 1.0), // Example progress
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today: ${_currentCalories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  '${(200 - _currentCalories).clamp(0, 200).toStringAsFixed(0)} kcal to go',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                key: Key('{key.toString()}_icon_container'),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
