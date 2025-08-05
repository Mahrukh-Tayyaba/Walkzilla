import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../services/leveling_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LevelDisplayWidget extends StatefulWidget {
  const LevelDisplayWidget({super.key});

  @override
  State<LevelDisplayWidget> createState() => _LevelDisplayWidgetState();
}

class _LevelDisplayWidgetState extends State<LevelDisplayWidget> {
  Map<String, dynamic>? _levelInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLevelInfo();
  }

  Future<void> _loadLevelInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final levelInfo = await LevelingService.getUserLevelInfo(user.uid);
        if (mounted) {
          setState(() {
            _levelInfo = levelInfo;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading level info: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_levelInfo == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Unable to load level information'),
        ),
      );
    }

    final currentLevel = _levelInfo!['currentLevel'] as int;
    final baseLevel = _levelInfo!['baseLevel'] as int;
    final monthlyStreakBonus = _levelInfo!['monthlyStreakBonus'] as int;
    final progress = _levelInfo!['progress'] as int;
    final required = _levelInfo!['required'] as int;
    final progressPercentage = _levelInfo!['progressPercentage'] as double;
    final totalLifetimeSteps = _levelInfo!['totalLifetimeSteps'] as int;
    final currentStreak = _levelInfo!['currentStreak'] as int;
    final daysUntilNextMonth = _levelInfo!['daysUntilNextMonth'] as int;
    final monthlyProgressPercentage =
        _levelInfo!['monthlyProgressPercentage'] as double;
    final currentMonthStreak = _levelInfo!['currentMonthStreak'] as int;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Level $currentLevel',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+$monthlyStreakBonus',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Base Level: $baseLevel | Monthly Streak: +$monthlyStreakBonus',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            LinearPercentIndicator(
              width: MediaQuery.of(context).size.width - 64,
              lineHeight: 8.0,
              percent: progressPercentage / 100,
              backgroundColor: Colors.grey[300],
              progressColor: Colors.blue,
              barRadius: const Radius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$progress / $required steps',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '${progressPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  'Total Steps',
                  '${totalLifetimeSteps.toString()}',
                  Icons.directions_walk,
                ),
                _buildStatItem(
                  'Current Streak',
                  '$currentStreak days',
                  Icons.local_fire_department,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
