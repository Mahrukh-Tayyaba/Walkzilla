import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_screen.dart';
import 'home.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'forgot_password_screen.dart';
import 'email_verification_screen.dart';
import 'services/health_service.dart';
import 'services/username_service.dart';
import 'services/duo_challenge_service.dart';
import 'services/coin_service.dart';
import 'services/user_login_service.dart';
import 'services/leveling_migration_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'main.dart' show navigatorKey;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HealthService _healthService = HealthService();
  final UsernameService _usernameService = UsernameService();
  final CoinService _coinService = CoinService();
  final UserLoginService _userLoginService = UserLoginService();

  bool _isPasswordVisible = false; // Toggle password visibility
  bool _isLoading = false; // Show loading indicator

  @override
  void initState() {
    super.initState();
    // Remove the automatic auth state check on login screen
    // _checkAuthState();
  }

  // Removed unused method _checkAuthState

  Future<void> _handleSuccessfulLogin(UserCredential userCredential) async {
    try {
      // Check if email is verified for non-Google users
      bool isGoogleUser = userCredential.user!.providerData
          .any((provider) => provider.providerId == 'google.com');

      if (!userCredential.user!.emailVerified && !isGoogleUser) {
        // User is not verified and not a Google user, redirect to verification screen
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(
                email: userCredential.user!.email!,
                password: _passwordController.text.trim(),
                username: userCredential.user!.displayName ?? 'user',
                userCredential: userCredential,
              ),
            ),
            (route) => false,
          );
        }
        return;
      }

      // Get the user's document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      // Check if this is a new user
      bool isNewUser = !userDoc.exists;

      if (isNewUser) {
        // Generate username for new user
        String username;
        try {
          final displayName = userCredential.user!.displayName ?? 'user';
          final suggestions = await _usernameService
              .getUsernameSuggestionsFromName(displayName);
          username = suggestions.isNotEmpty
              ? suggestions.first
              : 'user_${DateTime.now().millisecondsSinceEpoch}';
        } catch (e) {
          // Fallback username
          username = 'user_${DateTime.now().millisecondsSinceEpoch}';
        }

        // Reserve the username
        await _usernameService.reserveUsername(
            username, userCredential.user!.uid);

        // Create user document with generated username
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'username': username.toLowerCase(),
          'displayName': userCredential.user!.displayName ?? username,
          'email': userCredential.user!.email,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'hasHealthPermissions': false,
          'profileImage': userCredential.user!.photoURL,
          'level': 1,
          'currentStreak': 0,
          'totalLifetimeSteps': 0,
          'coins': 100, // Initial coins for new users
          'isOnline': false,
          'lastActive': FieldValue.serverTimestamp(),
          'owned_items': ['MyCharacter'],
          'currentCharacter': 'MyCharacter',
          'homeGlbPath': 'assets/web/home/MyCharacter_home.glb',
          'spriteSheets': {
            'idle': 'images/sprite_sheets/MyCharacter_idle.json',
            'walking': 'images/sprite_sheets/MyCharacter_walking.json',
          },
          'shown_rewards': {},
          'levelUpHistory': [],
          'achievedMilestones': [],
          'lastLevelUpdate': FieldValue.serverTimestamp(),
          'challenges_won': 0,
        });
      } else {
        // Update existing user's last login and online status
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
          'lastLogin': FieldValue.serverTimestamp(),
          'isOnline': true,
          'lastActive': FieldValue.serverTimestamp(),
        });

        // Initialize coins for existing users who don't have coins field
        await _coinService.initializeCoinsForExistingUsers();

        // Initialize leveling data for existing users who don't have leveling fields
        await LevelingMigrationService.initializeCurrentUserLevelingData();
      }

      // Save FCM token if not already present or if changed
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        final userData = userDoc.data();
        if (userData == null || userData['fcmToken'] != fcmToken) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .update({'fcmToken': fcmToken});
        }
      }

      if (!mounted) return;

      // Check and request health permissions before navigation
      final bool hasHealthPermissions = userDoc.exists
          ? (userDoc.data()?['hasHealthPermissions'] ?? false)
          : false;

      if (!hasHealthPermissions) {
        bool permissionsGranted =
            await _healthService.requestHealthPermissions(context);

        if (permissionsGranted) {
          // Update the permissions status in Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .update({
            'hasHealthPermissions': true,
          });
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "Some features may be limited without health data access."),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }

      // Check for existing duo challenge invites before navigation
      final duoChallengeService =
          DuoChallengeService(navigatorKey: navigatorKey);
      await duoChallengeService.checkForExistingInvites();

      // Initialize character animations for the logged-in user
      await _userLoginService.onUserLogin();

      // Navigate to home screen after permissions are handled
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error in handling successful login: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Error setting up health permissions. Some features may be limited."),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _login(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      await _handleSuccessfulLogin(userCredential);
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      // Debug: Print the actual error code
      print('Firebase Auth Error Code: ${e.code}');
      print('Firebase Auth Error Message: ${e.message}');

      // Show generic message for authentication failures to prevent user enumeration
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        errorMessage = 'Wrong username or password.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        errorMessage =
            'Too many failed login attempts. Please try again later.';
      } else if (e.code == 'user-not-verified') {
        errorMessage = 'Please verify your email address before logging in.';
      } else {
        errorMessage = 'An error occurred during login.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $errorMessage")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      setState(() => _isLoading = true);

      // Initialize Google Sign In
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Sign out first to ensure a fresh sign-in attempt
      await googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      // If user cancels the sign-in flow
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      try {
        // Get auth details from request
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Create credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in with Firebase
        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);

        // Google Sign In users are automatically email verified
        // No need to manually verify their email

        if (!mounted) return;
        await _handleSuccessfulLogin(userCredential);
      } catch (e) {
        print('Error during Google Sign In: $e');
        if (!mounted) return;
        await googleSignIn.signOut(); // Sign out from Google
        await FirebaseAuth.instance.signOut(); // Sign out from Firebase
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sign in with Google. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error in Google Sign In: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to sign in with Google. Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword(BuildContext context) async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email address")),
      );
      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  // Logo
                  Image.asset(
                    'assets/images/logo2.png',
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 40),

                  // Username TextField with enhanced styling
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofocus: false,
                      enableInteractiveSelection: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 18.0, horizontal: 16.0),
                        hintText: 'Enter your Email',
                        hintStyle: GoogleFonts.poppins(
                          color: const Color.fromARGB(255, 76, 73, 73),
                          fontSize: 14,
                        ),
                        prefixIcon:
                            const Icon(Icons.email, color: Color(0xFFFEB14C)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFFEB14C),
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        final emailRegex =
                            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password TextField with enhanced styling
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      enableInteractiveSelection: true,
                      onFieldSubmitted: (_) => _login(context),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 18.0, horizontal: 16.0),
                        hintText: 'Enter your Password',
                        hintStyle: GoogleFonts.poppins(
                          color: const Color.fromARGB(255, 76, 73, 73),
                          fontSize: 14,
                        ),
                        prefixIcon:
                            const Icon(Icons.lock, color: Color(0xFFFEB14C)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: const Color(0xFFFEB14C),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFFEB14C),
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Forgot Password with enhanced styling
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFEB14C),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Login Button with enhanced styling
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEB14C), Color(0xFFFF9A0E)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFEB14C).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _login(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'LOGIN',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Or Login with text with enhanced styling
                  Row(
                    children: [
                      Expanded(
                          child: Divider(color: Colors.grey.withOpacity(0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Or Login with',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Divider(color: Colors.grey.withOpacity(0.3))),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Social Login Buttons with enhanced styling
                  _buildSocialButton(
                    'assets/images/google-logo-icon.png',
                    onTap: _isLoading ? null : signInWithGoogle,
                  ),

                  const SizedBox(height: 20),

                  // Sign up text with enhanced styling
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Sign up!",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFFFEB14C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(String imagePath, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey[200] : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              imagePath,
              height: 24,
              color: onTap == null ? Colors.grey[400] : null,
            ),
            const SizedBox(width: 8),
            Text(
              'Continue with Google',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: onTap == null ? Colors.grey[400] : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
