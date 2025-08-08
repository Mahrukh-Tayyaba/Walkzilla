import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'providers/step_goal_provider.dart';
import 'providers/streak_provider.dart';
import 'services/health_service.dart';

class StreakSettings {
  final int stepGoal;
  final bool remindersEnabled;
  final TimeOfDay reminderTime;

  StreakSettings({
    required this.stepGoal,
    required this.remindersEnabled,
    required this.reminderTime,
  });

  StreakSettings copyWith({
    int? stepGoal,
    bool? remindersEnabled,
    TimeOfDay? reminderTime,
  }) {
    return StreakSettings(
      stepGoal: stepGoal ?? this.stepGoal,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

class StreakSettingsProvider with ChangeNotifier {
  StreakSettings _settings = StreakSettings(
    stepGoal: 10000,
    remindersEnabled: false,
    reminderTime: const TimeOfDay(hour: 20, minute: 0),
  );

  StreakSettings get settings => _settings;

  void updateSettings(StreakSettings newSettings) {
    _settings = newSettings;
    notifyListeners();
  }
}

class StreaksScreen extends StatefulWidget {
  const StreaksScreen({Key? key}) : super(key: key);

  @override
  State<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends State<StreaksScreen> {
  DateTime _displayedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    // Refresh streak data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndRefreshStreakData();
    });
  }

  Future<void> _loadAndRefreshStreakData() async {
    try {
      final streakProvider = context.read<StreakProvider>();

      // First, ensure streak data is initialized
      await streakProvider.ensureStreakDataInitialized();

      // Then, reload any existing streak data from Firestore
      await streakProvider.reloadStreaks();

      // Finally, refresh with current step data
      await _refreshStreakData();
    } catch (e) {
      debugPrint("❌ Error loading and refreshing streak data: $e");
    }
  }

  Future<void> _refreshStreakData() async {
    try {
      final stepGoalProvider = context.read<StepGoalProvider>();
      final streakProvider = context.read<StreakProvider>();
      final goalSteps = stepGoalProvider.goalSteps;

      // Get today's steps to check if goal is met
      final healthService = HealthService();
      final todaySteps = await healthService.fetchStepsData();

      // Get yesterday's steps to check if it should be marked
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final startOfYesterday =
          DateTime(yesterday.year, yesterday.month, yesterday.day);
      final endOfYesterday = startOfYesterday.add(const Duration(days: 1));

      // Fetch yesterday's steps data
      int yesterdaySteps = 0;
      try {
        // Use the health service to get yesterday's data
        final yesterdayData = await healthService.getStepsForDateRange(
            startOfYesterday, endOfYesterday);
        yesterdaySteps = yesterdayData;
      } catch (e) {
        debugPrint("❌ Could not fetch yesterday's steps: $e");
      }

      debugPrint("🔄 Streaks screen - refreshing streak data");
      debugPrint(
          "📊 Today's steps: $todaySteps, Yesterday's steps: $yesterdaySteps, Goal: $goalSteps");

      // Get the goal set date from StepGoalProvider
      final goalSetDate = stepGoalProvider.getGoalSetDateForCurrentMonth();

      // Use the enhanced method from streak provider
      await streakProvider.checkAndUpdateStreakWithYesterday(
          todaySteps, yesterdaySteps, goalSteps, goalSetDate);

      debugPrint("✅ Streak data refreshed in streaks screen");
    } catch (e) {
      debugPrint("❌ Error refreshing streak data in streaks screen: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final streakProvider = Provider.of<StreakProvider>(context);
    final int currentStreak = streakProvider.currentStreak;
    final int longestStreak = streakProvider.bestStreak;

    // Get goal met days for the displayed month
    final List<DateTime> streakDates = streakProvider
        .getGoalMetDaysForMonth(_displayedMonth.year, _displayedMonth.month)
        .toList();

    // Debug: Print streak dates for displayed month
    debugPrint(
        "📅 Streak dates for ${_displayedMonth.month}/${_displayedMonth.year}: ${streakDates.map((d) => '${d.month}/${d.day}').toList()}");
    debugPrint(
        "🔥 Current streak: $currentStreak, Best streak: $longestStreak");

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'MY STREAKS',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showStreakSettingsDialog(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStreakStat(
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.orange,
                  label: 'Current Streak',
                  value: currentStreak,
                ),
                const SizedBox(width: 16),
                _buildStreakStat(
                  icon: Icons.emoji_events_rounded,
                  color: Colors.amber,
                  label: 'Longest Streak',
                  value: longestStreak,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.04 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: _buildCalendar(_displayedMonth, streakDates),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakStat({
    required IconData icon,
    required Color color,
    required String label,
    required int value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              '$value Days',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(DateTime month, List<DateTime> streakDates) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday % 7; // Sunday = 0
    final totalCells = daysInMonth + firstWeekday;
    final weeks = (totalCells / 7).ceil();
    final today = DateTime.now();
    final todayAtMidnight = DateTime(today.year, today.month, today.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _displayedMonth = DateTime(
                            _displayedMonth.year,
                            _displayedMonth.month - 1,
                          );
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _displayedMonth = DateTime(
                            _displayedMonth.year,
                            _displayedMonth.month + 1,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Show goal for the displayed month
            Builder(
              builder: (context) {
                final stepGoalProvider =
                    Provider.of<StepGoalProvider>(context, listen: false);
                final monthKey =
                    '${month.year}-${month.month.toString().padLeft(2, '0')}';
                final goalForMonth =
                    stepGoalProvider.getGoalForMonth(month.year, month.month);

                if (goalForMonth != 10000) {
                  // If a custom goal is set for this month
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Goal: ${goalForMonth.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} steps',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  );
                } else {
                  return const SizedBox
                      .shrink(); // Don't show anything if no custom goal
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                .map((d) => Text(
                      d,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),
        Column(
          children: List.generate(weeks, (week) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (weekday) {
                final cellIndex = week * 7 + weekday;
                final dayNum = cellIndex - firstWeekday + 1;
                if (cellIndex < firstWeekday || dayNum > daysInMonth) {
                  return const SizedBox(width: 38, height: 38);
                }
                final date = DateTime(month.year, month.month, dayNum);
                final dateAtMidnight =
                    DateTime(date.year, date.month, date.day);
                final isToday = dateAtMidnight == todayAtMidnight;
                final isStreak = streakDates.any((d) =>
                    d.year == date.year &&
                    d.month == date.month &&
                    d.day == date.day);
                return Container(
                  width: 38,
                  height: 38,
                  margin:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  decoration: BoxDecoration(
                    color: isStreak
                        ? Colors.orange
                        : (isToday ? Colors.grey[200] : null),
                    // Flame-like shape for streak days
                    borderRadius: isStreak
                        ? BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(2),
                            bottomLeft: const Radius.circular(2),
                            bottomRight: const Radius.circular(16),
                          )
                        : BorderRadius.circular(8),
                    // Add gradient for streak days
                    gradient: isStreak
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.orange.shade400,
                              Colors.orange.shade600,
                            ],
                          )
                        : null,
                    // Add shadow for streak days
                    boxShadow: isStreak
                        ? [
                            BoxShadow(
                              color:
                                  Colors.orange.withAlpha((0.3 * 255).round()),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        color: isStreak
                            ? Colors.white
                            : (date.weekday == DateTime.sunday
                                ? Colors.red[300]
                                : Colors.black87),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ),
      ],
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text(
            'Clear Streak Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: const Text(
            'This will clear all existing streak data and start fresh. This action cannot be undone. Are you sure?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _runClearData(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runClearData(BuildContext context) async {
    // Store references before async operation
    final streakProvider = context.read<StreakProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Clearing streak data...'),
            ],
          ),
        ),
      );

      // Clear data
      await streakProvider.clearGoalMetDaysAndResetStreaks();

      // Check if widget is still mounted before accessing context
      if (mounted) {
        // Close loading dialog
        navigator.pop();

        // Show success message
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Streak data cleared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Check if widget is still mounted before accessing context
      if (mounted) {
        // Close loading dialog
        navigator.pop();

        // Show error message
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error clearing streak data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMigrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text(
            'Restore Streak History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: const Text(
            'This will analyze your daily step data and restore any missing streak history. This process cannot be undone.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _runMigration(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runMigration(BuildContext context) async {
    // Store references before async operation
    final streakProvider = context.read<StreakProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Restoring streak history...'),
            ],
          ),
        ),
      );

      // Run migration
      await streakProvider.triggerStreakMigration();

      // Check if widget is still mounted before accessing context
      if (mounted) {
        // Close loading dialog
        navigator.pop();

        // Show success message
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Streak history restored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Check if widget is still mounted before accessing context
      if (mounted) {
        // Close loading dialog
        navigator.pop();

        // Show error message
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error restoring streak history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStreakSettingsDialog(BuildContext context) {
    final provider =
        Provider.of<StreakSettingsProvider>(context, listen: false);
    final stepGoalProvider =
        Provider.of<StepGoalProvider>(context, listen: false);
    final settings = provider.settings;

    int stepGoal = stepGoalProvider.goalSteps;
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final hasCurrentGoal = stepGoalProvider.hasCurrentMonthGoal;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, size: 22),
                          onPressed:
                              stepGoalProvider.isGoalLockedForCurrentMonth()
                                  ? null
                                  : () => Navigator.of(context).pop(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Set Your Daily Streak Goal!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set your daily step target to keep your streak alive!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month,
                              color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Setting goal for ${DateFormat('MMMM yyyy').format(now)}',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFF1F1F1), width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE0EDFF),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.star,
                                    color: Color(0xFF2563EB), size: 16),
                              ),
                              const SizedBox(width: 8),
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Text(
                                  'Daily Step Goal',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(32),
                                onTap: stepGoalProvider
                                        .isGoalLockedForCurrentMonth()
                                    ? null
                                    : () {
                                        setState(() {
                                          if (stepGoal > 1000) stepGoal -= 1000;
                                        });
                                      },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: stepGoalProvider
                                            .isGoalLockedForCurrentMonth()
                                        ? Colors.grey.shade200
                                        : const Color(0xFFF3F4F6),
                                  ),
                                  child: Icon(Icons.remove,
                                      size: 18,
                                      color: stepGoalProvider
                                              .isGoalLockedForCurrentMonth()
                                          ? Colors.grey.shade400
                                          : const Color(0xFF6B7280)),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${stepGoal.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} steps',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                      letterSpacing: 1.05,
                                    ),
                                  ),
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(32),
                                onTap: stepGoalProvider
                                        .isGoalLockedForCurrentMonth()
                                    ? null
                                    : () {
                                        setState(() {
                                          stepGoal += 1000;
                                        });
                                      },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: stepGoalProvider
                                            .isGoalLockedForCurrentMonth()
                                        ? Colors.grey.shade200
                                        : const Color(0xFFF3F4F6),
                                  ),
                                  child: Icon(Icons.add,
                                      size: 18,
                                      color: stepGoalProvider
                                              .isGoalLockedForCurrentMonth()
                                          ? Colors.grey.shade400
                                          : const Color(0xFF6B7280)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                stepGoalProvider.isGoalLockedForCurrentMonth()
                                    ? null
                                    : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: stepGoalProvider
                                        .isGoalLockedForCurrentMonth()
                                    ? Colors.grey.shade300
                                    : const Color(0xFFE5E7EB),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: stepGoalProvider
                                        .isGoalLockedForCurrentMonth()
                                    ? Colors.grey.shade400
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: stepGoalProvider
                                    .isGoalLockedForCurrentMonth()
                                ? null
                                : () {
                                    try {
                                      provider.updateSettings(
                                        StreakSettings(
                                          stepGoal: stepGoal,
                                          remindersEnabled:
                                              settings.remindersEnabled,
                                          reminderTime: settings.reminderTime,
                                        ),
                                      );
                                      stepGoalProvider
                                          .setCurrentMonthGoal(stepGoal);
                                      Navigator.of(context).pop();
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(e
                                              .toString()
                                              .replaceAll('Exception: ', '')),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  stepGoalProvider.isGoalLockedForCurrentMonth()
                                      ? Colors.grey
                                      : const Color(0xFF111827),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              stepGoalProvider.isGoalLockedForCurrentMonth()
                                  ? 'Goal Set'
                                  : (hasCurrentGoal
                                      ? 'Update Goal'
                                      : 'Save Goal'),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
