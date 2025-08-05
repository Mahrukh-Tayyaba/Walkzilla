import 'package:shared_preferences/shared_preferences.dart';

class MilestoneHelper {
  static const List<int> milestones = [
    500,
    1000,
    2000,
    4000,
    6000,
    8000,
    10000,
    15000,
    20000,
    25000
  ];

  static Future<int?> getCurrentMilestone(int stepCount) async {
    for (int milestone in milestones) {
      // Only show milestone if step count is within 50 steps of the milestone
      // This prevents showing milestones that are way past the current step count
      if (stepCount >= milestone && stepCount <= milestone + 50) {
        // Check if this milestone has already been shown
        bool alreadyShown = await isShown(milestone);
        if (!alreadyShown) {
          return milestone;
        }
      }
    }
    return null;
  }

  /// Check if a milestone should be visible based on current step count
  /// This prevents showing milestones that are out of range
  static bool isMilestoneInRange(int milestone, int stepCount) {
    // Only show milestone if step count is within 50 steps of the milestone
    bool inRange = stepCount >= milestone && stepCount <= milestone + 50;
    print(
        '🔍 MILESTONE RANGE CHECK: $milestone milestone, $stepCount steps, inRange: $inRange');
    return inRange;
  }

  static Future<bool> isShown(int milestone) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('milestone_$milestone') ?? false;
  }

  static Future<void> markAsShown(int milestone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('milestone_$milestone', true);
  }

  static Future<void> resetMilestones() async {
    final prefs = await SharedPreferences.getInstance();
    for (int milestone in milestones) {
      await prefs.remove('milestone_$milestone');
    }
  }

  /// Reset milestones for a new day
  static Future<void> resetMilestonesForNewDay() async {
    final prefs = await SharedPreferences.getInstance();
    for (int milestone in milestones) {
      await prefs.remove('milestone_$milestone');
    }
    print('🔄 All milestone states reset for new day');
  }

  /// Reset a specific milestone for testing
  static Future<void> resetSpecificMilestone(int milestone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('milestone_$milestone');
    print('🔄 Reset milestone $milestone for testing');
  }

  static Future<List<int>> getShownMilestones() async {
    final prefs = await SharedPreferences.getInstance();
    List<int> shownMilestones = [];

    for (int milestone in milestones) {
      bool isShown = prefs.getBool('milestone_$milestone') ?? false;
      if (isShown) {
        shownMilestones.add(milestone);
      }
    }

    return shownMilestones;
  }
}
