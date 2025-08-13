import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final String _todayKey;
  late final String _monthKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayKey = DateFormat('yyyy-MM-dd').format(now);
    _monthKey = DateFormat('yyyy-MM').format(now);
  }

  Future<_TodayNotificationData> _fetchNotificationData(String uid) async {
    // Keys
    final todayKey = _todayKey;
    final monthKey = _monthKey;

    // Fetch user doc
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    final dailySteps = (userData['daily_steps'] as Map<String, dynamic>? ?? {});
    final stepsToday = (dailySteps[todayKey] ?? 0) as int;

    final monthlyGoals =
        (userData['monthlyGoals'] as Map<String, dynamic>? ?? {});
    final monthObj = (monthlyGoals[monthKey] as Map<String, dynamic>? ?? {});
    final goalSteps = (monthObj['goalSteps'] ?? 10000) as int;

    final goalCompleted = stepsToday >= goalSteps;

    // Daily top-3 rank
    final dailyTopSnap = await _firestore
        .collection('users')
        .orderBy('daily_steps.$todayKey', descending: true)
        .limit(3)
        .get();
    final dailyIndex = dailyTopSnap.docs.indexWhere((d) => d.id == uid);
    final int? dailyRank = dailyIndex == -1 ? null : dailyIndex + 1;

    // Weekly top-3 rank
    final weeklyTopSnap = await _firestore
        .collection('users')
        .orderBy('weekly_steps', descending: true)
        .limit(3)
        .get();
    final weeklyIndex = weeklyTopSnap.docs.indexWhere((d) => d.id == uid);
    final int? weeklyRank = weeklyIndex == -1 ? null : weeklyIndex + 1;

    return _TodayNotificationData(
      goalCompleted: goalCompleted,
      goalSteps: goalSteps,
      dailyTop3Rank: dailyRank,
      weeklyTop3Rank: weeklyRank,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF6E9),
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user == null
          ? const Center(child: Text('No notifications'))
          : FutureBuilder<_TodayNotificationData>(
              future: _fetchNotificationData(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  return const Center(
                      child: Text('No notifications for today'));
                }

                final data = snapshot.data!;

                final List<Widget> items = [];

                if (data.goalCompleted) {
                  items.add(
                    _buildNotificationItem(
                      icon: Icons.emoji_events,
                      title: 'Daily Challenge Completed',
                      message:
                          "You've completed your goal of ${data.goalSteps} steps",
                      time: 'Today',
                      color: Colors.orange,
                      isUnread: true,
                    ),
                  );
                }

                if (data.dailyTop3Rank != null) {
                  if (items.isNotEmpty) items.add(const SizedBox(height: 16));
                  items.add(
                    _buildNotificationItem(
                      icon: Icons.leaderboard,
                      title: 'Daily Leaderboard',
                      message: 'You are #${data.dailyTop3Rank} today',
                      time: 'Today',
                      color: Colors.blue,
                      isUnread: true,
                    ),
                  );
                }

                if (data.weeklyTop3Rank != null) {
                  if (items.isNotEmpty) items.add(const SizedBox(height: 16));
                  items.add(
                    _buildNotificationItem(
                      icon: Icons.leaderboard,
                      title: 'Weekly Leaderboard',
                      message: 'You are #${data.weeklyTop3Rank} this week',
                      time: 'Today',
                      color: Colors.purple,
                      isUnread: true,
                    ),
                  );
                }

                if (items.isEmpty) {
                  return const Center(
                      child: Text('No notifications for today'));
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: items,
                );
              },
            ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String message,
    required String time,
    required Color color,
    required bool isUnread,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (isUnread)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                    color: isUnread ? Colors.black : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: isUnread ? Colors.grey[800] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnread ? Colors.blue[400] : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayNotificationData {
  final bool goalCompleted;
  final int goalSteps;
  final int? dailyTop3Rank;
  final int? weeklyTop3Rank;

  _TodayNotificationData({
    required this.goalCompleted,
    required this.goalSteps,
    required this.dailyTop3Rank,
    required this.weeklyTop3Rank,
  });
}
