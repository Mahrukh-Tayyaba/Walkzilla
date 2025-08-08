import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/step_goal_provider.dart';

class StepsGoalCard extends StatefulWidget {
  final int currentSteps;
  final int goalSteps;
  final bool isGoalEnabled;
  final bool isEditable;
  final VoidCallback? onEdit;
  final ValueChanged<bool>? onToggle;

  const StepsGoalCard({
    Key? key,
    required this.currentSteps,
    required this.goalSteps,
    this.isGoalEnabled = true,
    this.isEditable = false,
    this.onEdit,
    this.onToggle,
  }) : super(key: key);

  @override
  State<StepsGoalCard> createState() => _StepsGoalCardState();
}

class _StepsGoalCardState extends State<StepsGoalCard> {
  bool _hasShownGoalDialog = false;
  String _currentMonthKey = '';

  @override
  void initState() {
    super.initState();
    _updateCurrentMonthKey();
    // Check for goal on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowGoalDialog();
    });
  }

  @override
  void didUpdateWidget(StepsGoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if month changed
    final newMonthKey = _getCurrentMonthKey();
    if (newMonthKey != _currentMonthKey) {
      _currentMonthKey = newMonthKey;
      _hasShownGoalDialog = false; // Reset flag for new month
      _checkAndShowGoalDialog();
    }
  }

  String _getCurrentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  void _updateCurrentMonthKey() {
    _currentMonthKey = _getCurrentMonthKey();
  }

  void _checkAndShowGoalDialog() {
    if (_hasShownGoalDialog) return;

    final stepGoalProvider = context.read<StepGoalProvider>();
    print("🔍 StepsGoalCard: Checking if must set goal...");

    // MANDATORY goal setting - user must set goal if missing
    if (stepGoalProvider.mustSetGoal()) {
      print("🔍 StepsGoalCard: Must set goal - showing dialog");
      _hasShownGoalDialog = true;
      _showMonthlyGoalDialog();
    } else {
      print("🔍 StepsGoalCard: No need to set goal");
    }
  }

  // Force show goal dialog (for mandatory goal setting)
  void _forceShowGoalDialog() {
    _hasShownGoalDialog = true;
    _showMonthlyGoalDialog();
  }

  void _showMonthlyGoalDialog() {
    final stepGoalProvider = context.read<StepGoalProvider>();
    final now = DateTime.now();
    final hasCurrentGoal = stepGoalProvider.hasCurrentMonthGoal;
    int tempGoalSteps = hasCurrentGoal ? stepGoalProvider.goalSteps : 10000;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
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
                          'Set Your Monthly Step Goal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
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
                    const SizedBox(height: 16),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
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
                          stepGoalProvider.setCurrentMonthGoal(tempGoalSteps);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(hasCurrentGoal
                                  ? 'Monthly goal updated!'
                                  : 'Monthly goal set successfully!'),
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
                        child: Text(
                          hasCurrentGoal ? 'Update Goal' : 'Set Goal',
                          style: const TextStyle(
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
    final progress = widget.currentSteps / widget.goalSteps;
    final remainingSteps = widget.goalSteps - widget.currentSteps;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.03 * 255).round()),
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
            ],
          ),
          if (widget.isGoalEnabled) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    '${widget.goalSteps} Steps per day',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
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
                          color: Colors.blue.withAlpha((0.2 * 255).round()),
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
                  'Today: ${NumberFormat('#,###').format(widget.currentSteps)} steps',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                widget.currentSteps >= widget.goalSteps
                    ? const Text(
                        'Goal completed',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      )
                    : Text(
                        '${NumberFormat('#,###').format(remainingSteps)} steps to go',
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
}
