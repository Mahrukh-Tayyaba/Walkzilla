import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/health_service.dart';
import 'home.dart';

class DailyGoalSelectionScreen extends StatefulWidget {
  const DailyGoalSelectionScreen({super.key});

  @override
  State<DailyGoalSelectionScreen> createState() =>
      _DailyGoalSelectionScreenState();
}

class _DailyGoalSelectionScreenState extends State<DailyGoalSelectionScreen> {
  int? _selectedGoal;
  bool _isLoading = false;

  final List<int> _goalOptions = [5000, 7500, 10000];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F4),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFF7F4F4),
              const Color(0xFFFEB14C).withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Logo
                Image.asset(
                  'assets/images/logo2.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 40),

                // Title
                Text(
                  'Choose your daily goals',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Goal Options
                Expanded(
                  child: Column(
                    children: _goalOptions
                        .map((goal) => _buildGoalOption(goal))
                        .toList(),
                  ),
                ),

                // Instructional text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'You can change your goals at any time in your profile',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 30),

                // Continue Button
                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFEB14C),
                        const Color(0xFFFF9A0E),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFEB14C).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _selectedGoal != null && !_isLoading
                        ? _continueToApp
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Continue',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalOption(int goal) {
    final isSelected = _selectedGoal == goal;
    final formattedGoal = goal.toString().replaceAllMapped(
          RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"),
          (Match m) => "${m[1]},",
        );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGoal = goal;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFEB14C) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isSelected ? const Color(0xFFFEB14C) : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Step icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFFFEB14C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.directions_walk,
                  color: isSelected
                      ? const Color(0xFFFEB14C)
                      : const Color(0xFFFEB14C),
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // Goal text
              Expanded(
                child: Text(
                  '$formattedGoal steps',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),

              // Selection indicator
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xFFFEB14C),
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continueToApp() async {
    if (_selectedGoal == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Save the selected goal to Firestore under monthlyGoals[YYYY-MM].goalSteps
        final now = DateTime.now();
        final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'monthlyGoals': {
            monthKey: {
              'goalSteps': _selectedGoal,
              'month': now.month,
              'year': now.year,
              'setDate': now.toIso8601String(),
            }
          }
        }, SetOptions(merge: true));

        // Request health permissions
        final healthService = HealthService();
        bool permissionsGranted =
            await healthService.requestHealthPermissions(context);

        if (permissionsGranted) {
          // Update the permissions status in Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'hasHealthPermissions': true,
          });
        }

        if (mounted) {
          // Navigate to home screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('Error saving daily goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving goal: $e'),
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
}
