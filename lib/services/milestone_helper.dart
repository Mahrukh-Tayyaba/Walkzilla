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
