import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'health_dashboard.dart'; // Import the health dashboard screen
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'notification_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'chat_list_page.dart';
import 'chat_detail_page.dart';
import 'friend_profile_page.dart';
import 'challenges_screen.dart';
import 'services/friend_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final health = Health();
  int _steps = 0; // Step count variable
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    fetchSteps();
  }

  // Function to fetch steps
  Future<void> fetchSteps() async {
    final types = [HealthDataType.STEPS];
    final startDate = DateTime.now().subtract(const Duration(days: 1));
    final endDate = DateTime.now();

    try {
      // Check if we have permissions
      bool? hasPermissions = await health.hasPermissions(types);

      if (hasPermissions == true) {
        // Fetch step data
        List<HealthDataPoint> healthData =
            await health.getHealthAggregateDataFromTypes(
          endDate: endDate,
          startDate: startDate,
          types: types,
        );

        if (!mounted) return;

        // Calculate total steps
        int totalSteps = healthData.fold<int>(
          0,
          (previousValue, element) =>
              previousValue + (element.value as int? ?? 0),
        );

        setState(() {
          _steps = totalSteps;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _steps = 0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      print("Error fetching health data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to fetch step count")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double buttonSpacing = screenSize.width * 0.15; // 15% of screen width

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black, size: 30),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          elevation: 0,
        ),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background circles
            Positioned(
              top: -screenSize.height * 0.1,
              right: -screenSize.width * 0.1,
              child: Container(
                width: screenSize.width * 0.4,
                height: screenSize.width * 0.4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue[100]?.withOpacity(0.3),
                ),
              ),
            ),
            Positioned(
              bottom: -screenSize.height * 0.1,
              left: -screenSize.width * 0.1,
              child: Container(
                width: screenSize.width * 0.5,
                height: screenSize.width * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange[100]?.withOpacity(0.3),
                ),
              ),
            ),
            // Main content
            Column(
              children: [
                // Top row with Steps, Events, and Challenges
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: screenSize.height * 0.02,
                    horizontal: screenSize.width * 0.05,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Daily Challenges Button
                      _buildTopButton(
                        icon: Icons.emoji_events,
                        label: 'Daily\nChallenges',
                        color: Colors.orange,
                        onTap: () => print("Daily Challenges tapped!"),
                        screenSize: screenSize,
                      ),

                      // Steps counter
                      Container(
                        width: screenSize.width * 0.4,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.25),
                              spreadRadius: 2,
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Steps: $_steps',
                            style: const TextStyle(
                              color: Color(0xFF2D2D2D),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Events Button
                      _buildTopButton(
                        icon: Icons.calendar_today,
                        label: 'Events',
                        color: const Color(0xFF9C27B0), // Material Purple
                        onTap: () => print("Events tapped!"),
                        screenSize: screenSize,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Character in the center
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background circle
                    Container(
                      width: screenSize.width * 0.5,
                      height: screenSize.width * 0.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue[50],
                      ),
                    ),
                    // Character container
                    SizedBox(
                      height: screenSize.width * 0.4,
                      width: screenSize.width * 0.4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: screenSize.width * 0.3,
                            width: screenSize.width * 0.3,
                            decoration: BoxDecoration(
                              color: Colors.blue[400],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.sentiment_satisfied_alt,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(height: screenSize.height * 0.01),
                          Container(
                            width: screenSize.width * 0.1,
                            height: screenSize.height * 0.02,
                            decoration: BoxDecoration(
                              color: Colors.blue[400],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Bottom navigation with three buttons
                Padding(
                  padding: EdgeInsets.only(
                    bottom: screenSize.height * 0.04,
                    left: screenSize.width * 0.05,
                    right: screenSize.width * 0.05,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCornerButton(
                        icon: Icons.favorite,
                        label: 'Health',
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const HealthDashboard()),
                          );
                        },
                      ),
                      _buildCornerButton(
                        icon: Icons.people,
                        label: 'Friends',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const FriendsPage()),
                          );
                        },
                      ),
                      _buildCornerButton(
                        icon: Icons.emoji_events,
                        label: 'Challenges',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ChallengesScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(
                  top: 50,
                  bottom: 25,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange[400]!.withOpacity(0.9),
                      Colors.orange[300]!.withOpacity(0.9),
                    ],
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfilePage()),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white.withOpacity(0.9),
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.orange[300],
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Tayyaba Amanat",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "Premium Member",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildDrawerItem(
                icon: Icons.notifications_active_outlined,
                title: "Notifications",
                notificationCount: 2,
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationPage()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.alarm_outlined,
                title: "Reminders",
                color: Colors.purple,
                onTap: () {},
              ),
              _buildDrawerItem(
                icon: Icons.people_outlined,
                title: "Friends",
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FriendsPage()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.chat_bubble_outline,
                title: "Chats",
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ChatListPage()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.settings_outlined,
                title: "Settings",
                color: Colors.grey[700],
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsPage()),
                  );
                },
              ),
              const Spacer(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  color: Colors.grey.withOpacity(0.3),
                  thickness: 1,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCornerButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 85,
        height: 85,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required Size screenSize,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: screenSize.width * 0.22,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    double? iconSize,
    int? notificationCount,
  }) {
    final itemColor = color ?? Colors.grey[700]!;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: itemColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: itemColor,
              size: iconSize ?? 24,
            ),
          ),
          if (notificationCount != null && notificationCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  notificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: itemColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      hoverColor: itemColor.withOpacity(0.05),
    );
  }
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendService _friendService = FriendService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: SafeArea(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Friends',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Search icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search,
                            color: Colors.black, size: 24),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Add friend icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF03A9F4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.person_add,
                            color: Colors.white, size: 26),
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            builder: (context) => _AddFriendDialog(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Tabs
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(icon: Icon(Icons.people), text: 'All Friends'),
                Tab(icon: Icon(Icons.access_time), text: 'Requests'),
                Tab(icon: Icon(Icons.send), text: 'Invites Sent'),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All Friends Tab
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _friendService.getFriends(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _buildEmptyState(
                        icon: Icons.error_outline,
                        title: 'Error Loading Friends',
                        subtitle: 'Please try again later.',
                      );
                    }

                    final friends = snapshot.data ?? [];

                    if (friends.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.people_outline,
                        title: 'No Friends Yet',
                        subtitle:
                            'Add friends to see their activity and compete together!',
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.25),
                                  spreadRadius: 2,
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundImage: friend['profileImage'] !=
                                            null
                                        ? NetworkImage(friend['profileImage'])
                                        : null,
                                    radius: 28,
                                    child: friend['profileImage'] == null
                                        ? const Icon(Icons.person, size: 28)
                                        : null,
                                  ),
                                  if (friend['isOnline'])
                                    Positioned(
                                      bottom: 2,
                                      right: 2,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    friend['displayName'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.local_fire_department,
                                      color: Colors.orange, size: 18),
                                  Text(
                                    ' ${friend['currentStreak']} days',
                                    style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                friend['isOnline'] ? 'Online' : 'Offline',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: friend['isOnline']
                                      ? Colors.green
                                      : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(22)),
                                  ),
                                  builder: (context) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 24, horizontal: 16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 5,
                                            margin: const EdgeInsets.only(
                                                bottom: 20),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                                Icons.account_circle,
                                                color: Colors.lightBlue,
                                                size: 28),
                                            title: const Text('View Profile',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            onTap: () {
                                              Navigator.pop(context);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      FriendProfilePage(
                                                    name: friend['displayName'],
                                                    avatar: friend[
                                                            'profileImage'] ??
                                                        '',
                                                    steps: friend['steps']
                                                        .toString(),
                                                    color: Colors.orange,
                                                    isOnline:
                                                        friend['isOnline'],
                                                    friendUserId:
                                                        friend['userId'],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                                Icons.chat_bubble_outline,
                                                color: Colors.lightBlue,
                                                size: 26),
                                            title: const Text('Chat',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            onTap: () {
                                              Navigator.pop(context);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ChatDetailPage(
                                                    name: friend['displayName'],
                                                    avatar: friend[
                                                            'profileImage'] ??
                                                        '',
                                                    online: friend['isOnline'],
                                                    otherUserId:
                                                        friend['userId'],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                                Icons.emoji_events,
                                                color: Colors.lightBlue,
                                                size: 26),
                                            title: const Text('Challenge',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            onTap: () {
                                              Navigator.pop(context);
                                              // TODO: Navigate to challenge
                                            },
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                // Requests Tab
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _friendService.getFriendRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _buildEmptyState(
                        icon: Icons.error_outline,
                        title: 'Error Loading Requests',
                        subtitle: 'Please try again later.',
                      );
                    }

                    final requests = snapshot.data ?? [];

                    if (requests.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.people_outline,
                        title: 'No Friend Requests',
                        subtitle:
                            'When someone sends you a friend request, it will appear here.',
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return _buildRequestTile(
                          requestId: request['requestId'],
                          avatarUrl: request['profileImage'],
                          name: request['displayName'],
                          level: request['level'],
                          steps: request['currentStreak'],
                        );
                      },
                    );
                  },
                ),
                // Invites Sent Tab
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _friendService.getSentFriendRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return _buildEmptyState(
                        icon: Icons.error_outline,
                        title: 'Error Loading Sent Invites',
                        subtitle: 'Please try again later.',
                      );
                    }

                    final invites = snapshot.data ?? [];

                    if (invites.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.send_outlined,
                        title: 'No Sent Invites',
                        subtitle: 'Your sent friend invites will appear here.',
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: invites.length,
                      itemBuilder: (context, index) {
                        final invite = invites[index];
                        final createdAt = invite['createdAt'] as Timestamp?;
                        final pendingSince = createdAt != null
                            ? _formatTimeAgo(createdAt.toDate())
                            : 'Recently';

                        return _buildInviteSentTile(
                          requestId: invite['requestId'],
                          avatarUrl: invite['profileImage'],
                          name: invite['displayName'],
                          pendingSince: pendingSince,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildRequestTile({
    required String requestId,
    required String? avatarUrl,
    required String name,
    required int level,
    required int steps,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.25),
              spreadRadius: 2,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    radius: 28,
                    child: avatarUrl == null
                        ? const Icon(Icons.person, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final success =
                            await _friendService.acceptFriendRequest(requestId);
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Friend request accepted!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF03A9F4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: const Text('Accept',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final success = await _friendService
                            .declineFriendRequest(requestId);
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Friend request declined'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5F5),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: const Text('Decline',
                          style: TextStyle(color: Colors.black)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteSentTile({
    required String requestId,
    required String? avatarUrl,
    required String name,
    required String pendingSince,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.12),
              spreadRadius: 1,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    radius: 26,
                    child: avatarUrl == null
                        ? const Icon(Icons.person, size: 26)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFF23272F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pending since $pendingSince',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () async {
                    final success =
                        await _friendService.cancelFriendRequest(requestId);
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Friend request cancelled'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F5),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF23272F),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AddFriendDialog extends StatefulWidget {
  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FriendService _friendService = FriendService();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _suggestedUsers = [];
  bool _isSearching = false;
  bool _isLoading = false;
  bool _isLoadingSuggested = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestedUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestedUsers() async {
    setState(() {
      _isLoadingSuggested = true;
    });

    try {
      // Get suggested users (users who are not friends and not already requested)
      final suggested = await _friendService.getSuggestedUsers();
      setState(() {
        _suggestedUsers = suggested.take(5).toList(); // Limit to 5 users
        _isLoadingSuggested = false;
      });
    } catch (e) {
      print('Error loading suggested users: $e');
      setState(() {
        _isLoadingSuggested = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _friendService.searchUsersByUsername(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _sendFriendRequest(String userId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _friendService.sendFriendRequest(userId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Unable to send friend request. User might already be your friend or request already sent.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending friend request: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 26, color: Color(0xFF23272F)),
          onPressed: () => Navigator.of(context).pop(),
          splashRadius: 22,
        ),
        title: const Text(
          'Add Friends',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: Color(0xFF23272F),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child:
                        Icon(Icons.search, color: Color(0xFFB1B1B1), size: 24),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search by username',
                        hintStyle:
                            TextStyle(color: Color(0xFFB1B1B1), fontSize: 17),
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      style: const TextStyle(fontSize: 17),
                      onChanged: (value) {
                        // Debounce search
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted && _searchController.text == value) {
                            _searchUsers(value);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            if (_isSearching)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Search Results',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF23272F),
                ),
              ),
              const SizedBox(height: 12),
              ..._searchResults.map((user) => _buildUserTile(user)).toList(),
            ],

            // Connect with others section
            const SizedBox(height: 32),
            const Text(
              'Connect with others',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF23272F),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'People you might know',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8A8F98),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoadingSuggested)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (_suggestedUsers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No suggestions available',
                    style: TextStyle(
                      color: Color(0xFF8A8F98),
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              ..._suggestedUsers.map((user) => _buildUserTile(user)).toList(),

            const SizedBox(height: 32),

            // Share invite link section
            const Text(
              'OR INVITE FROM',
              style: TextStyle(
                color: Color(0xFF8A8F98),
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 18),
            _InviteOption(
              icon: Icons.share,
              title: 'Share invite link',
              subtitle: 'Share via WhatsApp, SMS, Email',
              iconColor: const Color(0xFF4CAF50),
              onTap: () {},
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: user['profileImage'] != null
              ? NetworkImage(user['profileImage'])
              : null,
          child: user['profileImage'] == null
              ? const Icon(Icons.person, size: 24)
              : null,
        ),
        title: Text(
          user['displayName'],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user['username']}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.local_fire_department,
                    size: 14, color: Colors.orange[400]),
                const SizedBox(width: 4),
                Text(
                  'Level ${user['level']} • ${user['currentStreak']} day streak',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(
                onPressed: () => _sendFriendRequest(user['userId']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF03A9F4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
      ),
    );
  }
}

class _InviteOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _InviteOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF23272F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8A8F98),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
