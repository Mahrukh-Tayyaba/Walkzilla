import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'health_dashboard.dart'; // Import the health dashboard screen

import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_page.dart';
import 'profile_page.dart';

import 'chat_list_page.dart';
import 'chat_detail_page.dart';
import 'challenges_screen.dart';
import 'streaks_screen.dart';
import 'services/friend_service.dart';
// import 'utils/user_avatar_helper.dart'; // Commented out until file exists

import 'dart:async'; // Added for Timer

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final health = Health();
  int _steps = 0; // Step count variable

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
      debugPrint("Error fetching health data: $e");
      // Unable to fetch step count
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF6E9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          backgroundColor: const Color(0xFFFFF6E9),
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
                  color: Colors.blue[100]?.withAlpha((0.3 * 255).round()),
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
                  color: Colors.orange[100]?.withAlpha((0.3 * 255).round()),
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
                        onTap: () => debugPrint("Daily Challenges tapped!"),
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
                              color:
                                  Colors.grey.withAlpha((0.25 * 255).round()),
                              spreadRadius: 2.0,
                              blurRadius: 18.0,
                              offset: const Offset(0, 6.0),
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
                        onTap: () => debugPrint("Events tapped!"),
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
                              borderRadius: BorderRadius.circular(20.0),
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
                              borderRadius: BorderRadius.circular(10.0),
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
            color: Colors.white.withAlpha((0.95 * 255).round()),
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
                      Colors.orange[400]!.withAlpha((0.9 * 255).round()),
                      Colors.orange[300]!.withAlpha((0.9 * 255).round()),
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
                          backgroundColor:
                              Colors.white.withAlpha((0.9 * 255).round()),
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
                                color:
                                    Colors.white.withAlpha((0.2 * 255).round()),
                                borderRadius: BorderRadius.circular(20.0),
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
                icon: Icons.people_outlined,
                title: "Friends",
                color: const Color(0xFFDC143C).withOpacity(0.7),
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
                icon: Icons.local_fire_department,
                title: "Streaks",
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const StreaksScreen()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.chat_bubble_outline,
                title: "Chats",
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ChatListPage()),
                  );
                },
              ),
              const Spacer(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  color: Colors.grey.withAlpha((0.3 * 255).round()),
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
        width: 85.0,
        height: 85.0,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.7 * 255).round()),
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withAlpha((0.1 * 255).round()),
              spreadRadius: 2.0,
              blurRadius: 8.0,
              offset: const Offset(0, 2.0),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: ShapeDecoration(
                color: color.withAlpha((0.05 * 255).round()),
                shape: const CircleBorder(),
              ),
              child: Icon(icon, color: color, size: 30.0),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withAlpha((0.8 * 255).round()),
                fontSize: 12.0,
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
          color: Colors.white.withAlpha((0.7 * 255).round()),
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(15.0),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withAlpha((0.1 * 255).round()),
              spreadRadius: 2.0,
              blurRadius: 8.0,
              offset: const Offset(0, 2.0),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: ShapeDecoration(
                color: color.withAlpha((0.05 * 255).round()),
                shape: const CircleBorder(),
              ),
              child: Icon(icon, color: color, size: 24.0),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withAlpha((0.8 * 255).round()),
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
              color: itemColor.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(10.0),
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
      hoverColor: itemColor.withAlpha((0.05 * 255).round()),
    );
  }
}

class FriendsPage extends StatefulWidget {
  final int initialTab;
  const FriendsPage({super.key, this.initialTab = 0});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendService _friendService = FriendService();

  // Cache data to avoid unnecessary API calls
  List<Map<String, dynamic>> _cachedFriends = [];
  List<Map<String, dynamic>> _cachedRequests = [];
  List<Map<String, dynamic>> _cachedInvites = [];

  // Loading states
  bool _isLoadingFriends = true;
  bool _isLoadingRequests = true;
  bool _isLoadingInvites = true;

  // Error states
  String? _friendsError;
  String? _requestsError;
  String? _invitesError;

  @override
  void initState() {
    super.initState();
    final int initial = (widget.initialTab >= 0 && widget.initialTab <= 2)
        ? widget.initialTab
        : 0;
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: initial);

    // Load data immediately
    _loadInitialData();

    // Listen to tab changes to refresh data if needed
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _refreshTabData(_tabController.index);
      }
    });
  }

  void _refreshTabData(int tabIndex) {
    // Only refresh if data is empty and not currently loading
    switch (tabIndex) {
      case 0: // Friends tab
        if (_cachedFriends.isEmpty && !_isLoadingFriends) {
          _loadFriends();
        }
        break;
      case 1: // Requests tab
        if (_cachedRequests.isEmpty && !_isLoadingRequests) {
          _loadRequests();
        }
        break;
      case 2: // Invites tab
        if (_cachedInvites.isEmpty && !_isLoadingInvites) {
          _loadInvites();
        }
        break;
    }
  }

  Future<void> _loadInitialData() async {
    // Load all data concurrently
    await Future.wait([
      _loadFriends(),
      _loadRequests(),
      _loadInvites(),
    ]);
  }

  Future<void> _loadFriends() async {
    try {
      setState(() {
        _isLoadingFriends = true;
        _friendsError = null;
      });

      final friends = await _friendService.getFriends().first;
      if (mounted) {
        setState(() {
          _cachedFriends = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _friendsError = e.toString();
          _isLoadingFriends = false;
        });
      }
    }
  }

  Future<void> _loadRequests() async {
    try {
      setState(() {
        _isLoadingRequests = true;
        _requestsError = null;
      });

      final requests = await _friendService.getFriendRequests().first;
      if (mounted) {
        setState(() {
          _cachedRequests = requests;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _requestsError = e.toString();
          _isLoadingRequests = false;
        });
      }
    }
  }

  Future<void> _loadInvites() async {
    try {
      setState(() {
        _isLoadingInvites = true;
        _invitesError = null;
      });

      final invites = await _friendService.getSentFriendRequests().first;
      if (mounted) {
        setState(() {
          _cachedInvites = invites;
          _isLoadingInvites = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _invitesError = e.toString();
          _isLoadingInvites = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  // Handle friend request actions efficiently
  Future<void> _handleFriendRequestAction(
      String requestId, bool isAccept) async {
    try {
      bool success;
      if (isAccept) {
        success = await _friendService.acceptFriendRequest(requestId);
        if (success) {
          // Move from requests to friends
          final request = _cachedRequests.firstWhere(
            (req) => req['requestId'] == requestId,
            orElse: () => <String, dynamic>{},
          );
          if (request.isNotEmpty) {
            setState(() {
              _cachedRequests
                  .removeWhere((req) => req['requestId'] == requestId);
              _cachedFriends.add(request);
            });
          }
        }
      } else {
        success = await _friendService.declineFriendRequest(requestId);
        if (success) {
          // Remove from requests
          setState(() {
            _cachedRequests.removeWhere((req) => req['requestId'] == requestId);
          });
        }
      }
    } catch (e) {
      debugPrint('Error handling friend request: $e');
    }
  }

  Future<void> _handleCancelInvite(String requestId) async {
    try {
      final success = await _friendService.cancelFriendRequest(requestId);
      if (success) {
        setState(() {
          _cachedInvites
              .removeWhere((invite) => invite['requestId'] == requestId);
        });
      }
    } catch (e) {
      debugPrint('Error canceling invite: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6E9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: SafeArea(
          child: Container(
            color: const Color(0xFFFFF6E9),
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
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                // Add friend icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFed3e57),
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
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            // Tabs
            Material(
              color: const Color(0xFFFFF6E9),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFFed3e57),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFFed3e57),
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
                  Stack(
                    children: [
                      _buildFriendsTab(),
                      if (_isLoadingFriends && _cachedFriends.isNotEmpty)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFed3e57)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Requests Tab
                  Stack(
                    children: [
                      _buildRequestsTab(),
                      if (_isLoadingRequests && _cachedRequests.isNotEmpty)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFed3e57)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Invites Sent Tab
                  Stack(
                    children: [
                      _buildInvitesTab(),
                      if (_isLoadingInvites && _cachedInvites.isNotEmpty)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFed3e57)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_isLoadingFriends && _cachedFriends.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFed3e57)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading friends...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_friendsError != null && _cachedFriends.isEmpty) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        title: 'Error Loading Friends',
        subtitle: 'Please try again later.',
        onRetry: _loadFriends,
      );
    }

    if (_cachedFriends.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Friends Yet',
        subtitle: 'Add friends to see their activity and compete together!',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      itemCount: _cachedFriends.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F2)),
      itemBuilder: (context, index) {
        final friend = _cachedFriends[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          ),
          child: InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.chat_bubble_outline,
                              color: Color(0xFFed3e57), size: 26),
                          title: const Text('Chat',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w500)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailPage(
                                  name: friend['displayName'],
                                  avatar: friend['profileImage'] ?? '',
                                  otherUserId: friend['userId'],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  );
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _buildAvatar(
                    userId: friend['userId'] ?? '',
                    displayName: friend['displayName'] ?? 'Unknown',
                    profileImage: friend['profileImage'],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend['displayName'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${(friend['displayName'] ?? 'unknown').toLowerCase().replaceAll(' ', '')}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method to build avatar (temporary replacement for UserAvatarHelper)
  Widget _buildAvatar({
    required String userId,
    required String displayName,
    String? profileImage,
  }) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: const Color(0xFFed3e57), // Crimson Rose color
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoadingRequests && _cachedRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFed3e57)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading requests...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_requestsError != null && _cachedRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        title: 'Error Loading Requests',
        subtitle: 'Please try again later.',
        onRetry: _loadRequests,
      );
    }

    if (_cachedRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No Friend Requests',
        subtitle:
            'When someone sends you a friend request, it will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      itemCount: _cachedRequests.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F2)),
      itemBuilder: (context, index) {
        final request = _cachedRequests[index];
        return _buildRequestTile(
          requestId: request['requestId'],
          avatarUrl: request['profileImage'],
          name: request['displayName'],
          level: request['level'],
          steps: request['currentStreak'],
        );
      },
    );
  }

  Widget _buildInvitesTab() {
    if (_isLoadingInvites && _cachedInvites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFed3e57)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading invites...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_invitesError != null && _cachedInvites.isEmpty) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        title: 'Error Loading Sent Invites',
        subtitle: 'Please try again later.',
        onRetry: _loadInvites,
      );
    }

    if (_cachedInvites.isEmpty) {
      return _buildEmptyState(
        icon: Icons.send_outlined,
        title: 'No Sent Invites',
        subtitle: 'Your sent friend invites will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      itemCount: _cachedInvites.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F2)),
      itemBuilder: (context, index) {
        final invite = _cachedInvites[index];
        final createdAt = invite['createdAt'] as Timestamp?;
        final pendingSince =
            createdAt != null ? _formatTimeAgo(createdAt.toDate()) : 'Recently';

        return _buildInviteSentTile(
          requestId: invite['requestId'],
          avatarUrl: invite['profileImage'],
          name: invite['displayName'],
          pendingSince: pendingSince,
        );
      },
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAvatar(
                  userId: name.hashCode.toString(),
                  displayName: name ?? 'Unknown',
                  profileImage: avatarUrl,
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
                    onPressed: () =>
                        _handleFriendRequestAction(requestId, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFed3e57),
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
                    onPressed: () =>
                        _handleFriendRequestAction(requestId, false),
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
    );
  }

  Widget _buildInviteSentTile({
    required String requestId,
    required String? avatarUrl,
    required String name,
    required String pendingSince,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(
                  userId: name.hashCode.toString(),
                  displayName: name ?? 'Unknown',
                  profileImage: avatarUrl,
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
                onPressed: () => _handleCancelInvite(requestId),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F5F5),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF23272F),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onRetry,
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
          if (onRetry != null) const SizedBox(height: 20),
          if (onRetry != null)
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFed3e57),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white),
              ),
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

  // Debounce timer for search
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSuggestedUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Helper method to build avatar (temporary replacement for UserAvatarHelper)
  Widget _buildAvatar({
    required String userId,
    required String displayName,
    String? profileImage,
  }) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: const Color(0xFFed3e57), // Crimson Rose color
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _loadSuggestedUsers() async {
    if (!mounted) return;

    setState(() {
      _isLoadingSuggested = true;
    });

    try {
      // Get suggested users (users who are not friends and not already requested)
      final suggested = await _friendService.getSuggestedUsers();
      if (mounted) {
        setState(() {
          _suggestedUsers = suggested.take(5).toList(); // Limit to 5 users
          _isLoadingSuggested = false;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error loading suggested users: $e');
        setState(() {
          _isLoadingSuggested = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Set a new timer for debounced search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _searchController.text == query) {
        _searchUsers(query);
      }
    });
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _friendService.searchUsersByUsername(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _sendFriendRequest(String userId) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _friendService.sendFriendRequest(userId);
      if (success && mounted) {
        // Friend request sent successfully
        // Update the UI to show the request was sent
        setState(() {
          // Remove from search results and suggested users
          _searchResults.removeWhere((user) => user['userId'] == userId);
          _suggestedUsers.removeWhere((user) => user['userId'] == userId);
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        // Unable to send friend request
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to send friend request. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Error sending friend request
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
      backgroundColor: const Color(0xFFFFF6E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF6E9),
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
                color: const Color(0xFFFFFEF7),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
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
                      onChanged: _onSearchChanged,
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            _buildAvatar(
              userId: user['userId'] ?? '',
              displayName: user['displayName'] ?? 'Unknown',
              profileImage: user['profileImage'],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['displayName'] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user['username'] ?? 'unknown'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ElevatedButton(
                    onPressed: () => _sendFriendRequest(user['userId']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFed3e57),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
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
          ],
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
        color: const Color(0xFFFFFEF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10.0),
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
