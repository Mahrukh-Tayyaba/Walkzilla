import 'package:flutter/material.dart';
// import 'package:health/health.dart';
import 'health_dashboard.dart'; // Import the health dashboard screen
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'services/health_service.dart';
import 'services/character_animation_service.dart';
import 'widgets/daily_challenge_spin.dart';
import 'challenges_screen.dart';
import 'notification_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'friends_page.dart';
import 'chat_list_page.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'solo_mode.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final HealthService _healthService = HealthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _steps = 0;
  double _calories = 0.0;
  double _heartRate = 0.0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String _userName = 'User'; // Default name
  String _userEmail = '';
  bool _isUserDataLoading = true; // Add loading state for user data
  int _coins = 280; // Example coin count, replace with your logic

  @override
  void initState() {
    super.initState();
    _fetchHealthData();
    _startHealthDataRefresh();
    _loadUserData();
    _startCharacterPreloading();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isUserDataLoading = true;
      });

      final user = _auth.currentUser;
      if (user != null) {
        print("Loading user data for: ${user.uid}");
        print("User email: ${user.email}");

        // Get user data from Firestore (username is stored here)
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final username = userData['username'] ?? '';
          print("Username from Firestore: $username");

          setState(() {
            _userName = username.isNotEmpty ? username : 'User';
            _userEmail = user.email ?? '';
            _isUserDataLoading = false;
          });
        } else {
          print("No user document found in Firestore");
          setState(() {
            _userName = 'User';
            _userEmail = user.email ?? '';
            _isUserDataLoading = false;
          });
        }
      } else {
        print("No user logged in");
        setState(() {
          _isUserDataLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isUserDataLoading = false;
      });
    }
  }

  Future<void> _fetchHealthData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      print("Starting health data fetch...");
      // First check if we have permissions
      bool hasPermissions = await _healthService.checkExistingPermissions();

      print("Health permissions status: $hasPermissions");

      if (!hasPermissions) {
        print("No health permissions granted");
        if (!mounted) return;
        setState(() {
          _steps = 0;
          _heartRate = 0.0;
          _calories = 0.0;
          _isLoading = false;
        });
        return;
      }

      print("Fetching health data from service...");
      final healthData = await _healthService.fetchHealthData();

      if (!mounted) return;

      // Extract data from the nested structure
      final stepsData = healthData['steps'] as Map<String, dynamic>;
      final heartRateData = healthData['heartRate'] as Map<String, dynamic>;
      final caloriesData = healthData['calories'] as Map<String, dynamic>;

      setState(() {
        _steps = stepsData['count'] as int;
        _heartRate = (heartRateData['beatsPerMinute'] as num).toDouble();
        _calories =
            (caloriesData['energy']['inKilocalories'] as num).toDouble();
        _isLoading = false;
      });

      print(
          "Updated UI with health data: Steps: $_steps, Heart Rate: $_heartRate, Calories: $_calories");
    } catch (e) {
      print("Error fetching health data: $e");
      if (mounted) {
        setState(() {
          _steps = 0;
          _heartRate = 0.0;
          _calories = 0.0;
          _isLoading = false;
        });
      }
    }
  }

  void _startHealthDataRefresh() {
    // Refresh health data every 5 minutes
    Future.delayed(const Duration(minutes: 5), () {
      if (mounted) {
        _fetchHealthData();
        _startHealthDataRefresh(); // Schedule next refresh
      }
    });
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;

      // Clear the navigation stack and go to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  /// Start preloading character animations in the background
  void _startCharacterPreloading() {
    // Start preloading animations in the background
    CharacterAnimationService().preloadAnimations().catchError((error) {
      print('Failed to preload character animations: $error');
    });
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
          actions: [
            Padding(
              padding:
                  const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
              child: _buildCoinDisplay(),
            ),
          ],
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
                      Expanded(
                        child: _buildTopButton(
                          icon: Icons.emoji_events,
                          label: 'Daily\nChallenges',
                          color: Colors.orange,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const DailyChallengeSpin()),
                            );
                          },
                          screenSize: screenSize,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Steps counter
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 2,
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Steps: $_steps',
                                      style: TextStyle(
                                        color: const Color(0xFF2D2D2D),
                                        fontSize: screenSize.width *
                                            0.045, // smaller font
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Shop Button
                      Expanded(
                        child: _buildTopButton(
                          icon: Icons.shopping_bag,
                          label: 'Shop',
                          color: Colors.purple,
                          onTap: () => print("Shop tapped!"),
                          screenSize: screenSize,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // 3D Character in the center
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background circle
                    Container(
                      width: screenSize.width * 0.8,
                      height: screenSize.width * 0.8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue[50],
                      ),
                    ),
                    // 3D ModelViewer widget with lazy loading
                    SizedBox(
                      height: screenSize.width * 0.9,
                      width: screenSize.width * 0.9,
                      child: FutureBuilder(
                        future: Future.delayed(
                            const Duration(seconds: 2)), // Delay loading
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return const ModelViewer(
                            src: 'assets/web/MyCharacter.glb',
                            alt: "A 3D model of MyCharacter",
                            autoRotate: false,
                            cameraControls: true,
                            backgroundColor: Colors.transparent,
                            cameraOrbit: "0deg 75deg 100%",
                            minCameraOrbit: "-180deg 75deg 100%",
                            maxCameraOrbit: "180deg 75deg 100%",
                            interactionPrompt: InteractionPrompt.none,
                            disableTap: true,
                            autoPlay: true,
                          );
                        },
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
                      // Events Button (Moved from original position)
                      _buildCornerButton(
                        icon: Icons.directions_walk,
                        label: 'Solo Mode',
                        color: const Color(0xFF9C27B0), // Material Purple
                        onTap: () {
                          // Ensure animations are preloaded before navigating
                          CharacterAnimationService().preloadAnimations();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SoloMode()),
                          );
                        },
                      ),
                      _buildCornerButton(
                        icon: Icons.emoji_events,
                        label: 'Challenges',
                        color: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ChallengesScreen()),
                          );
                        },
                      ),
                      // Health Button (Moved from original position)
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
                    ).then((_) {
                      // Add a small delay to ensure Firebase Auth update is complete
                      Future.delayed(const Duration(milliseconds: 500), () {
                        // Refresh user data when returning from profile page
                        _loadUserData();
                      });
                    });
                  },
                  onLongPress: () {
                    // Manual refresh on long press
                    _loadUserData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Refreshing user data...'),
                        duration: Duration(seconds: 1),
                      ),
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
                            _isUserDataLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    _userName,
                                    style: const TextStyle(
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
                                "Beginner",
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
              _buildDrawerItem(
                icon: Icons.logout_outlined,
                title: "Logout",
                color: Colors.red[400]!,
                onTap: _logout,
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
                fontSize: 10, // smaller font
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
    return AspectRatio(
      aspectRatio: 1.1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
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
                child: Icon(icon,
                    color: color,
                    size: screenSize.width * 0.05), // smaller icon
              ),
              const SizedBox(height: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color.withOpacity(0.8),
                      fontSize: screenSize.width * 0.025, // smaller font
                      fontWeight: FontWeight.w600,
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
          fontSize: 14, // smaller font
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

  Widget _buildCoinDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: const Color(0xFFF5E9B9), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Coin image
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/coin.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$_coins',
            style: const TextStyle(
              color: Color(0xFF222222),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
