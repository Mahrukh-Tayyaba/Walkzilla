import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'health_dashboard.dart'; // Import the health dashboard screen
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final health = Health();
  int _steps = 0; // Step count variable
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;

  Future<void> _showPermissionDialog() async {
    if (!mounted) return;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Health Data Access Required'),
          content: const Text(
            'Walkzilla needs access to your step count data to track your daily activity. '
            'Please grant the necessary permissions to continue.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _isLoading = false);
              },
            ),
            TextButton(
              child: const Text('Grant Permission'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _requestHealthPermissions();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestHealthPermissions() async {
    setState(() => _isLoading = true);
    final types = [HealthDataType.STEPS];

    try {
      // First check if we have permission
      bool? hasPermissions =
          await health.hasPermissions([HealthDataType.STEPS]);

      // If we don't have permissions, show the dialog
      if (hasPermissions == null || !hasPermissions) {
        if (!mounted) return;
        await _showPermissionDialog();
        return;
      }

      bool permissionsGranted =
          await health.requestAuthorization([HealthDataType.STEPS]);

      if (permissionsGranted) {
        await fetchSteps();
      } else {
        if (!mounted) return;
        // Show dialog again if permissions not granted
        await _showPermissionDialog();
      }
    } catch (e) {
      if (!mounted) return;
      print("Permission error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error requesting permissions: ${e.toString()}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _requestHealthPermissions(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Delay the permission request slightly to ensure the context is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      _requestHealthPermissions();
    });
  }

  Future<void> fetchSteps() async {
    final types = [HealthDataType.STEPS];

    // Set start date to beginning of today
    final startDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final endDate = DateTime.now();

    try {
      // Check permissions before fetching
      bool? hasPermissions = await health.hasPermissions(types);
      if (hasPermissions == null || !hasPermissions) {
        await _requestHealthPermissions();
        return;
      }

      // Fetch step data
      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: types,
      );

      if (!mounted) return;

      // Calculate total steps
      int totalSteps = healthData.fold<int>(
        0,
        (previousValue, element) =>
            previousValue +
            (element.value as NumericHealthValue).numericValue.toInt(),
      );

      setState(() {
        _steps = totalSteps;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      print("Error fetching health data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Unable to fetch step count"),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => fetchSteps(),
          ),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  // Add a method to refresh steps periodically
  void _startStepRefresh() {
    // Refresh steps every 5 minutes
    Future.delayed(const Duration(minutes: 5), () {
      if (mounted) {
        fetchSteps();
        _startStepRefresh(); // Schedule next refresh
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
                              : Text(
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
                        onTap: () => print("Friends tapped!"),
                      ),
                      _buildCornerButton(
                        icon: Icons.shopping_bag,
                        label: 'Shop',
                        color: Colors.purple,
                        onTap: () => print("Shop tapped!"),
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
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue[400]!.withOpacity(0.9),
                      Colors.blue[300]!.withOpacity(0.9),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: Icon(
                        Icons.person,
                        size: 45,
                        color: Colors.blue[300],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Dummy MCC",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Group: dairy, User Type: ChillingPlant",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildDrawerItem(
                icon: Icons.home_outlined,
                title: "Home",
                onTap: () => Navigator.pop(context),
              ),
              _buildDrawerItem(
                icon: Icons.history_outlined,
                title: "Order History",
                onTap: () {},
              ),
              _buildDrawerItem(
                icon: Icons.payment_outlined,
                title: "Payment History",
                onTap: () {},
              ),
              _buildDrawerItem(
                icon: Icons.settings_outlined,
                title: "Settings",
                onTap: () {},
              ),
              _buildDrawerItem(
                icon: Icons.system_update_outlined,
                title: "Update",
                onTap: () {},
              ),
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
  }) {
    final itemColor = color ?? Colors.grey[700]!;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: itemColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: itemColor,
          size: 24,
        ),
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
