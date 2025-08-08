import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({Key? key}) : super(key: key);

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool isDaily = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add timeout mechanism
  bool _hasTimedOut = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          _hasTimedOut = true;
        });
        debugPrint('Leaderboard timeout - showing fallback content');
      }
    });
  }

  void _resetTimeout() {
    _hasTimedOut = false;
    _startTimeoutTimer();
  }

  /// Get start of current week (Monday)
  DateTime _getStartOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return date.subtract(Duration(days: daysFromMonday));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildToggle(),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .orderBy(
                      isDaily
                          ? 'daily_steps.${DateFormat('yyyy-MM-dd').format(DateTime.now())}'
                          : 'weekly_steps',
                      descending: true)
                  .limit(100) // Limit to prevent performance issues
                  .snapshots(),
              builder: (context, snapshot) {
                // Debug logging
                debugPrint(
                    'Leaderboard state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, docs: ${snapshot.data?.docs.length ?? 0}');

                // Handle errors with better error messages
                if (snapshot.hasError) {
                  debugPrint('Leaderboard error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Unable to load leaderboard',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please check your connection and try again',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              // This will trigger a rebuild and retry
                            });
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                // Show loading only on first load with no data
                if (snapshot.connectionState == ConnectionState.waiting &&
                    (!snapshot.hasData || snapshot.data!.docs.isEmpty)) {
                  // Check if we've timed out
                  if (_hasTimedOut) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Taking longer than expected',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please check your connection',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              _resetTimeout();
                              setState(() {});
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading leaderboard...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Handle empty data with helpful message
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.leaderboard_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to start walking!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final currentUserId = _auth.currentUser?.uid;
                final users = snapshot.data!.docs;

                // Reset timeout when data loads successfully
                if (users.isNotEmpty && _hasTimedOut) {
                  _hasTimedOut = false;
                }

                // Show all users (including those with 0 steps)
                final allUsers = users.where((userDoc) {
                  final userData = userDoc.data() as Map<String, dynamic>;
                  final name = userData['username'] ?? '';

                  // Only filter out users with no username
                  return name.isNotEmpty && name != 'Unknown User';
                }).toList();

                if (allUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.leaderboard_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to join the leaderboard!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Convert Firestore data to the format expected by the UI
                final leaderboardData = allUsers.map((userDoc) {
                  final userData = userDoc.data() as Map<String, dynamic>;
                  final userId = userDoc.id;
                  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

                  // Get steps data
                  int steps;
                  if (isDaily) {
                    final rawSteps = ((userData['daily_steps']
                            as Map<String, dynamic>?)?[today] ??
                        0);
                    steps = (rawSteps is int)
                        ? rawSteps
                        : (rawSteps is double)
                            ? rawSteps.toInt()
                            : 0;
                  } else {
                    // Calculate real-time weekly total including today's steps
                    final dailySteps =
                        userData['daily_steps'] as Map<String, dynamic>? ?? {};
                    final startOfWeek = _getStartOfWeek(DateTime.now());

                    int weeklyTotal = 0;
                    // Add all daily steps from this week
                    for (int i = 0; i < 7; i++) {
                      final date = startOfWeek.add(Duration(days: i));
                      final dateKey = DateFormat('yyyy-MM-dd').format(date);
                      final daySteps = (dailySteps[dateKey] ?? 0) as int;
                      weeklyTotal += daySteps;
                    }
                    steps = weeklyTotal;
                  }

                  return {
                    'userId': userId,
                    'name': userData['username'] ?? 'Unknown User',
                    'steps': steps,
                    'image': userData['profileImageUrl'] ??
                        'https://randomuser.me/api/portraits/lego/1.jpg',
                    'isCurrentUser': userId == currentUserId,
                  };
                }).toList();

                // Sort by steps (highest first)
                leaderboardData.sort(
                    (a, b) => (b['steps'] as int).compareTo(a['steps'] as int));

                return Column(
                  children: [
                    leaderboardData.length >= 3
                        ? _buildPodium(leaderboardData)
                        : const Text(
                            'Not enough data to show podium.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: leaderboardData.length > 3
                          ? _buildRankedList(leaderboardData)
                          : const Center(
                              child: Text(
                                'No more data available.',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.05 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => isDaily = true),
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color:
                        isDaily ? const Color(0xFF3B82F6) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Daily',
                    style: TextStyle(
                      color: isDaily ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => isDaily = false),
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color:
                        !isDaily ? const Color(0xFF3B82F6) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Weekly',
                    style: TextStyle(
                      color: !isDaily ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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

  Widget _buildPodium(List<Map<String, dynamic>> data) {
    final podium = [data[1], data[0], data[2]];
    final podiumColors = [
      const Color(0xFFC0C0C0),
      const Color(0xFFFFD700),
      const Color(0xFFCD7F32),
    ];
    final blockColors = [
      const Color(0xFFC0C0C0),
      const Color(0xFFFFD700),
      const Color(0xFFCD7F32),
    ];
    final heights = [110.0, 140.0, 90.0];
    final widths = [110.0, 130.0, 110.0];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final user = podium[i];
        final isCurrentUser = user['isCurrentUser'] as bool? ?? false;

        return Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                if (i == 1) ...[
                  Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      const Positioned(
                        top: -32,
                        child: Icon(Icons.emoji_events,
                            color: Color(0xFFFFD700), size: 36),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isCurrentUser
                                  ? Colors.yellow
                                  : podiumColors[i],
                              width: isCurrentUser ? 6 : 5),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 28,
                            backgroundImage: NetworkImage(user['image'] ?? ''),
                            onBackgroundImageError: (exception, stackTrace) {
                              // Handle image loading error
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ] else ...[
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color:
                              isCurrentUser ? Colors.yellow : podiumColors[i],
                          width: isCurrentUser ? 4 : 3),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(user['image'] ?? ''),
                        onBackgroundImageError: (exception, stackTrace) {
                          // Handle image loading error
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Container(
                  width: widths[i],
                  height: heights[i],
                  decoration: BoxDecoration(
                    color: blockColors[i],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const SizedBox(height: 6),
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          i == 0 ? '2' : (i == 1 ? '1' : '3'),
                          style: TextStyle(
                            color: blockColors[i],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            user['name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '${NumberFormat('#,###').format(user['steps'] ?? 0)} Steps',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRankedList(List<Map<String, dynamic>> data) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      itemCount: data.length - 3,
      itemBuilder: (context, idx) {
        final rank = idx + 4;
        final user = data[idx + 3];
        final isCurrentUser = user['isCurrentUser'] as bool? ?? false;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: isCurrentUser
                  ? Border.all(color: Colors.yellow, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.07 * 255).round()),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '#$rank',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF3B4A6B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundImage: NetworkImage(user['image'] ?? ''),
                    radius: 22,
                    onBackgroundImageError: (exception, stackTrace) {
                      // Handle image loading error
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color(0xFF2B2B2B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        NumberFormat('#,###').format(user['steps'] ?? 0),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1A2B49),
                        ),
                      ),
                      const Text(
                        'Steps',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
