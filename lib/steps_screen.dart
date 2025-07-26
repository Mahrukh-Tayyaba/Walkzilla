import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'home.dart';
import 'widgets/steps_goal_card.dart';
import 'package:provider/provider.dart';
import 'providers/step_goal_provider.dart';
import 'services/health_service.dart';
import 'package:percent_indicator/percent_indicator.dart';

class StepsScreen extends StatefulWidget {
  final int currentSteps;
  final int goalSteps;

  const StepsScreen({
    super.key,
    required this.currentSteps,
    required this.goalSteps,
  });

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  int _todaySteps = 0;
  int _yesterdaySteps = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStepData();
  }

  Future<void> _fetchStepData() async {
    setState(() => _isLoading = true);
    final healthService = HealthService();
    // Fetch today's steps
    final todaySteps = await healthService.fetchStepsData();
    // Fetch yesterday's steps
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final startOfYesterday =
        DateTime(yesterday.year, yesterday.month, yesterday.day);
    final endOfYesterday = startOfYesterday.add(const Duration(days: 1));
    int yesterdaySteps = 0;
    try {
      yesterdaySteps = await healthService.health
              .getTotalStepsInInterval(startOfYesterday, endOfYesterday) ??
          0;
    } catch (e) {
      yesterdaySteps = 0;
    }
    setState(() {
      _todaySteps = todaySteps;
      _yesterdaySteps = yesterdaySteps;
      _isLoading = false;
    });
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  String _getYearText(int year, int index) {
    // If index is after December (7), it's the next year
    return index > 7 ? (year + 1).toString() : year.toString();
  }

  // Helper function to format step counts
  String _formatSteps(double steps) {
    return NumberFormat('#,###').format(steps.round());
  }

  // Calculate total steps for current day
  double getDayTotal() {
    return _todaySteps.toDouble();
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    // No horizontal drag logic for simulated data
  }

  // Reset offsets when changing periods
  void updatePeriod(String period) {
    // No period change logic for simulated data
  }

  String _getTooltipText() {
    final data = [getDayTotal()]; // Simulated data for tooltip
    final viewDate = DateTime.now();
    final formatter = DateFormat('MMM d');

    if (data.isEmpty) return '';

    if (data.length == 1) {
      return 'TOTAL\n${_formatSteps(data[0])}\n${formatter.format(viewDate)}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Steps',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // No bar selection logic for simulated data
        },
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Steps Progress Ring
              Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : CircularPercentIndicator(
                        radius: 85.0,
                        lineWidth: 10.0,
                        percent: _todaySteps /
                            (widget.goalSteps == 0 ? 1 : widget.goalSteps),
                        center: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.directions_walk,
                              color: Colors.green,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _todaySteps.toString(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Text(
                              'of 10k steps',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        progressColor: Colors.green,
                        backgroundColor: Colors.green.withOpacity(0.2),
                        circularStrokeCap: CircularStrokeCap.round,
                      ),
              ),
              const SizedBox(height: 24),
              // Move Goal Section here
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildGoalSection(),
              ),
              const SizedBox(height: 24),
              // Daily Tip Card (Steps)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildStepsDailyTipCard(),
              ),
              const SizedBox(height: 24),
              // Steps Comparison Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildStepsComparisonRow(),
              ),
              const SizedBox(height: 24),
              // Fun Fact Card (Steps)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildStepsFunFactCard(),
              ),
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
              currentIndex: 1, // Health section selected by default
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

  Widget _buildGoalSection() {
    return StepsGoalCard(
      currentSteps: widget.currentSteps,
      goalSteps: widget.goalSteps,
      isGoalEnabled: true, // Simulated data, so goal is always enabled
      isEditable: true,
      onEdit: _showStepGoalDialog,
      onToggle: (value) {
        // No goal toggle logic for simulated data
      },
    );
  }

  double _calculateTooltipPosition() {
    final chartWidth = MediaQuery.of(context).size.width - 72.0;
    final barsCount = 1; // Simulated data, so only one bar
    final tooltipWidth = 120.0;
    final barWidth = chartWidth / barsCount;

    double position = (0 * barWidth) + (barWidth / 2) - (tooltipWidth / 2);

    if (position < 0) {
      position = 0;
    } else if (position + tooltipWidth > chartWidth) {
      position = chartWidth - tooltipWidth;
    }

    return position;
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

  void _onItemTapped(int index) {
    if (index == 0) {
      // Navigate to Home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
      );
    } else {
      // No state change for other items
    }
  }

  // --- Steps Info Cards ---
  Widget _buildStepsDailyTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // light green
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
                  color: Colors.green.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.lightbulb,
              color: Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Tip',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Take short walking breaks throughout the day to boost your step count!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsComparisonRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
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
              margin:
                  const EdgeInsets.only(left: 8, top: 4, bottom: 4, right: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9), // very light green
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.directions_walk,
                    color: Colors.green,
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
                    '${_todaySteps} steps',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
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
              margin:
                  const EdgeInsets.only(right: 8, top: 4, bottom: 4, left: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7FF), // very light blue
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.directions_walk,
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
                    '${_yesterdaySteps} steps',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsFunFactCard() {
    return Container(
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star_border_rounded,
                    color: Colors.green, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'Fun Fact',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Did you know? Walking 10,000 steps a day can help improve your heart health and mood!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
