import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'services/username_service.dart';
import 'services/fcm_notification_service.dart';
import 'services/user_login_service.dart'; // Added import for UserLoginService

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Removed unused field _formKey
  final TextEditingController _nameController = TextEditingController();

  // User data variables
  String _userName = 'User';
  String _userEmail = '';

  bool _isLoading = true;

  // New variables for real user data
  int _userLevel = 1;
  int _userCoins = 0;
  int _challengesWon = 0;
  int _currentStreak = 0;
  String _memberSince = '';
  int _lifetimeSteps = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get user data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _userName = userData['username'] ??
                user.displayName ??
                user.email?.split('@')[0] ??
                'User';
            _userEmail = user.email ?? '';

            _userLevel = userData['level'] ?? 1;
            _userCoins = userData['coins'] ?? 0;
            _challengesWon = userData['challenges_won'] ?? 0;
            _currentStreak = userData['currentStreak'] ?? 0;
            final lifetime = userData['totalLifetimeSteps'];
            _lifetimeSteps = lifetime is int
                ? lifetime
                : (lifetime is num ? lifetime.toInt() : 0);

            // Format member since date
            final createdAt = userData['createdAt'] as Timestamp?;
            if (createdAt != null) {
              final date = createdAt.toDate();
              _memberSince = '${_getMonthName(date.month)} ${date.year}';
            } else {
              _memberSince = 'March 2023';
            }

            _isLoading = false;
          });

          // Initialize controllers with actual user data
          _nameController.text = _userName;
        } else {
          // Fallback to Firebase Auth data
          setState(() {
            _userName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
            _userEmail = user.email ?? '';

            _userLevel = 1;
            _userCoins = 0;
            _challengesWon = 0;
            _currentStreak = 0;
            _memberSince = 'March 2023';
            _isLoading = false;
          });

          // Initialize controllers
          _nameController.text = _userName;
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  @override
  void dispose() {
    _nameController.dispose();

    super.dispose();
  }

  Future<void> _saveProfileChanges() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final oldUsername =
            userDoc.data()?['username']?.toString().toLowerCase() ?? '';
        final newUsername = _nameController.text.trim().toLowerCase();

        // Only update username if it changed
        if (oldUsername != newUsername) {
          // Check if new username is available
          final usernameService = UsernameService();
          final isAvailable =
              await usernameService.isUsernameAvailable(newUsername);
          if (!isAvailable) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Username is already taken.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          // Remove old username from usernames collection
          if (oldUsername.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('usernames')
                .doc(oldUsername)
                .delete();
          }
          // Reserve new username
          await usernameService.reserveUsername(newUsername, user.uid);
        }

        // Update Firestore - only username
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'username': _nameController.text.trim(),
        });

        // Update Firebase Auth displayName
        await user.updateDisplayName(_nameController.text.trim());

        // Update local state
        setState(() {
          _userName = _nameController.text.trim();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving profile changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditProfileDialog() {
    // Reset form data to current values
    _nameController.text = _userName;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          userName: _userName,
          nameController: _nameController,
          onSave: _saveProfileChanges,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF1DC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFF1DC),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Profile',
            style: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF1DC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF1DC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header with Orange Background
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange[300],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              margin: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Level $_userLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.directions_walk,
                      value: _lifetimeSteps.toString(),
                      label: 'Lifetime Steps',
                      color: Colors.blue,
                      backgroundColor: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.monetization_on,
                      value: '$_userCoins',
                      label: 'Coins',
                      color: Colors.orange,
                      backgroundColor: Colors.orange.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.emoji_events,
                      value: '$_challengesWon',
                      label: 'Challenges Won',
                      color: Colors.green,
                      backgroundColor: Colors.green.withOpacity(0.1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.local_fire_department,
                      value: '$_currentStreak',
                      label: 'Daily Streak',
                      color: Colors.purple,
                      backgroundColor: Colors.purple.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Personal Information
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFEF7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                    icon: Icons.email,
                    label: 'Email',
                    value: _userEmail,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    label: 'Member Since',
                    value: _memberSince,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const SizedBox(height: 16),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildActionButton(
                    label: 'Edit Profile',
                    onPressed: _showEditProfileDialog,
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                    hasBorder: false,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    label: 'Log Out',
                    onPressed: () async {
                      // Show confirmation dialog
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Confirm Logout'),
                            content:
                                const Text('Are you sure you want to log out?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Yes, Logout'),
                              ),
                            ],
                          );
                        },
                      );

                      if (shouldLogout != true) return;

                      try {
                        debugPrint('🚪 Profile page logout started');

                        // Call UserLoginService logout cleanup
                        try {
                          final userLoginService = UserLoginService();
                          await userLoginService.onUserLogout();
                          debugPrint(
                              '✅ UserLoginService logout cleanup completed');
                        } catch (e) {
                          debugPrint(
                              '⚠️ UserLoginService logout cleanup error: $e');
                        }

                        // Clear any cached data
                        setState(() {
                          _userName = 'User';
                          _userEmail = '';
                          _userLevel = 1;
                          _userCoins = 0;
                          _challengesWon = 0;
                          _currentStreak = 0;
                          _memberSince = '';
                          _lifetimeSteps = 0;
                        });

                        // Clear token then sign out
                        await FCMNotificationService.clearFCMTokenOnLogout();
                        await FirebaseAuth.instance.signOut();
                        debugPrint('✅ Firebase sign out completed');

                        // The StreamBuilder in main.dart will automatically handle navigation
                        debugPrint('✅ Profile logout completed successfully');
                      } catch (e) {
                        debugPrint('❌ Profile logout error: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Error signing out: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color.withAlpha((0.8 * 255).round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha((0.1 * 255).round()),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                softWrap: true,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color textColor,
    bool hasBorder = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: hasBorder && backgroundColor == Colors.white
                ? BorderSide(color: Colors.grey.withOpacity(0.2), width: 1)
                : BorderSide.none,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class EditProfilePage extends StatefulWidget {
  final String userName;
  final TextEditingController nameController;
  final VoidCallback onSave;

  const EditProfilePage({
    super.key,
    required this.userName,
    required this.nameController,
    required this.onSave,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _showPasswordSection = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1DC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF1DC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.orange[300]!,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.orange,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () {
                              // TODO: Implement image picker
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Profile picture update coming soon!'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange[400],
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap to change photo',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Username Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Username',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: widget.nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter your username',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: Colors.orange[300]!, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Password Change Section
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFEF7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    // Password Section Header
                    ListTile(
                      leading: Icon(
                        Icons.lock_outline,
                        color: Colors.grey[600],
                      ),
                      title: const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        _showPasswordSection
                            ? 'Enter your current and new password'
                            : 'Update your password to keep your account secure',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          _showPasswordSection
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _showPasswordSection = !_showPasswordSection;
                          });
                        },
                      ),
                    ),

                    // Password Fields (shown when expanded)
                    if (_showPasswordSection) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            // Current Password
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: 'Current password',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.orange[300]!, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // New Password
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: 'New password',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.orange[300]!, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Confirm New Password
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: 'Confirm new password',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.orange[300]!, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() {
                            _isLoading = true;
                          });

                          try {
                            // Check if password fields are filled
                            if (_showPasswordSection &&
                                (_currentPasswordController.text.isNotEmpty ||
                                    _newPasswordController.text.isNotEmpty ||
                                    _confirmPasswordController
                                        .text.isNotEmpty)) {
                              // Validate password change
                              if (_currentPasswordController.text.isEmpty ||
                                  _newPasswordController.text.isEmpty ||
                                  _confirmPasswordController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Please fill all password fields'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              if (_newPasswordController.text !=
                                  _confirmPasswordController.text) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('New passwords do not match'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              if (_newPasswordController.text.length < 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Password must be at least 6 characters'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null && user.email != null) {
                                // Re-authenticate user with current password
                                AuthCredential credential =
                                    EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: _currentPasswordController.text,
                                );
                                await user
                                    .reauthenticateWithCredential(credential);

                                // Update password
                                await user.updatePassword(
                                    _newPasswordController.text);

                                // Clear password fields
                                _currentPasswordController.clear();
                                _newPasswordController.clear();
                                _confirmPasswordController.clear();

                                // Hide password section
                                setState(() {
                                  _showPasswordSection = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Password updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }

                            // Save profile changes
                            widget.onSave();
                            Navigator.pop(context);
                          } on FirebaseAuthException catch (e) {
                            String errorMessage =
                                'An error occurred while updating password';

                            switch (e.code) {
                              case 'wrong-password':
                                errorMessage = 'Current password is incorrect';
                                break;
                              case 'weak-password':
                                errorMessage =
                                    'Password is too weak. Please choose a stronger password';
                                break;
                              case 'requires-recent-login':
                                errorMessage =
                                    'Please log in again to change your password';
                                break;
                              case 'too-many-requests':
                                errorMessage =
                                    'Too many attempts. Please try again later';
                                break;
                              default:
                                errorMessage = e.message ?? errorMessage;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMessage),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[400],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
}
