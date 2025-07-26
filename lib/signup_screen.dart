import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home.dart'; // Import the HomeScreen
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'services/health_service.dart'; // Add this import
import 'services/username_service.dart'; // Add username service
import 'services/duo_challenge_service.dart';
import 'main.dart' show navigatorKey;
import 'email_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  SignupScreenState createState() => SignupScreenState();
}

class SignupScreenState extends State<SignupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final HealthService _healthService = HealthService(); // Add this
  final UsernameService _usernameService =
      UsernameService(); // Add username service
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  List<String> _usernameSuggestions = [];
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    // Add listener to check username availability
    _usernameController.addListener(_checkUsernameAvailability);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_checkUsernameAvailability);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Check username availability with debouncing
  Future<void> _checkUsernameAvailability() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameError = null;
      });
      return;
    }

    // Validate username format first
    if (!_usernameService.isValidUsername(username)) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameError =
            'Username must be 3-20 characters, letters and numbers only';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    // Add a small delay to avoid too many requests
    await Future.delayed(const Duration(milliseconds: 500));

    // Check if the username has changed during the delay
    if (_usernameController.text.trim() != username) {
      return; // User has typed more, ignore this result
    }

    try {
      print('Checking availability for username: "$username"');
      final isAvailable = await _usernameService.isUsernameAvailable(username);
      print('Username "$username" availability result: $isAvailable');

      // Double-check that the username hasn't changed while we were checking
      if (mounted && _usernameController.text.trim() == username) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = isAvailable;
          _usernameError = isAvailable ? null : 'Username is already taken';
        });
      }
    } catch (e) {
      print('Error checking username availability: $e');
      if (mounted && _usernameController.text.trim() == username) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = false;
          if (e.toString().contains('permission-denied')) {
            _usernameError =
                'Unable to check username availability. Please try again.';
          } else {
            _usernameError = 'Error checking username availability';
          }
        });
      }
    }
  }

  // Generate username suggestions
  Future<void> _generateUsernameSuggestions() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    try {
      final suggestions = await _usernameService.suggestUsernames(username);
      setState(() {
        _usernameSuggestions = suggestions;
      });
    } catch (e) {
      print('Error generating username suggestions: $e');
    }
  }

  // Auto-generate username from email
  Future<void> _autoGenerateUsername() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    // Extract name from email (before @)
    final emailName = email.split('@').first;

    try {
      final suggestions =
          await _usernameService.getUsernameSuggestionsFromName(emailName);
      if (suggestions.isNotEmpty) {
        setState(() {
          _usernameController.text = suggestions.first;
          _usernameSuggestions = suggestions;
        });
        _checkUsernameAvailability();
      }
    } catch (e) {
      print('Error auto-generating username: $e');
    }
  }

  Future<void> _signup(BuildContext context) async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || username.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All fields are required")),
        );
      }
      return;
    }

    // Validate username format
    if (!_usernameService.isValidUsername(username)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Username must be 3-20 characters, letters and numbers only")),
        );
      }
      return;
    }

    // Check if username is available
    if (!_isUsernameAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please choose an available username")),
        );
      }
      return;
    }

    if (password != _confirmPasswordController.text) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Passwords do not match")),
        );
      }
      return;
    }

    if (password.length < 6) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Password must be at least 6 characters")),
        );
      }
      return;
    }

    try {
      // Check if email is already registered
      final methods =
          await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      print('Sign-in methods for $email: $methods');

      if (methods.isNotEmpty) {
        if (methods.contains('google.com')) {
          // Google account exists
          if (context.mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "This email is registered with Google. Please use Google Sign-In."),
              ),
            );
          }
          return;
        } else if (methods.contains('password')) {
          // Email/password account exists, check if it's verified
          try {
            // Try to sign in to check verification status
            final signInResult =
                await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );

            if (signInResult.user!.emailVerified) {
              // Account exists and is verified
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("An account already exists for that email."),
                  ),
                );
              }
              return;
            } else {
              // Account exists but is not verified, redirect to verification
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmailVerificationScreen(
                      email: email,
                      password: password,
                      username: username,
                      userCredential: signInResult,
                    ),
                  ),
                );
              }
              return;
            }
          } catch (signInError) {
            // Wrong password or other sign-in error
            if (context.mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      "An account already exists with this email. Please use the login screen instead."),
                ),
              );
            }
            return;
          }
        }
      }

      // Create new authentication record
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Reserve the username
      final usernameReserved = await _usernameService.reserveUsername(
        username,
        userCredential.user!.uid,
      );

      if (!usernameReserved) {
        // If username reservation fails, delete the auth account and show error
        await userCredential.user!.delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    "Username is no longer available. Please try another one.")),
          );
        }
        return;
      }

      // Navigate to email verification screen
      if (mounted) {
        // Clear any lingering error messages before navigation
        ScaffoldMessenger.of(context).clearSnackBars();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(
              email: email,
              password: password,
              username: username,
              userCredential: userCredential,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception: ${e.code} - ${e.message}');
      String errorMessage = "An error occurred during signup";
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'Email/password accounts are not enabled.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Please check your internet connection.';
      }
      // Note: email-already-in-use is handled upfront in the signup logic
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Check if this is a new user
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      bool isNewUser = !userDoc.exists;

      if (isNewUser) {
        // Generate username suggestions for new user
        List<String> suggestions = [];
        try {
          suggestions = await _usernameService
              .getUsernameSuggestionsFromName(googleUser.displayName ?? 'user');
        } catch (e) {
          // Fallback suggestion
          suggestions = [];
        }
        // Always add a fallback unique username
        suggestions.add('user_${DateTime.now().millisecondsSinceEpoch}');

        String? uniqueUsername;
        for (final suggestion in suggestions) {
          final available =
              await _usernameService.isUsernameAvailable(suggestion);
          if (available) {
            // Reserve the username in the usernames collection
            final reserved = await _usernameService.reserveUsername(
                suggestion, userCredential.user!.uid);
            if (reserved) {
              uniqueUsername = suggestion;
              break;
            }
          }
        }
        // If for some reason none are available, fallback to a timestamp username
        uniqueUsername ??= 'user_${DateTime.now().millisecondsSinceEpoch}';
        // Ensure fallback is reserved
        await _usernameService.reserveUsername(
            uniqueUsername, userCredential.user!.uid);

        // Create user profile in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'username': uniqueUsername.toLowerCase(),
          'displayName': googleUser.displayName ?? uniqueUsername,
          'email': googleUser.email,
          'photoURL': googleUser.photoUrl,
          'lastLogin': FieldValue.serverTimestamp(),
          'profileImage': googleUser.photoUrl,
          'hasHealthPermissions': false,
          'level': 1,
          'currentStreak': 0,
          'coins': 100, // Initial coins for new users
          'isOnline': false,
          'lastActive': FieldValue.serverTimestamp(),
          'characterSpriteSheets': {
            'idle': 'images/character_idle.json',
            'walking': 'images/character_walking.json'
          },
          'shown_rewards': {},
        });
      } else {
        // Update existing user's last login
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
          'lastLogin': FieldValue.serverTimestamp(),
          'isOnline': true,
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      // Check for existing duo challenge invites before navigation
      final duoChallengeService =
          DuoChallengeService(navigatorKey: navigatorKey);
      await duoChallengeService.checkForExistingInvites();

      // Navigate to home screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
        (route) => false,
      );

      // After navigation, check and request health permissions if needed
      if (mounted && isNewUser) {
        // Small delay to ensure navigation is complete
        await Future.delayed(const Duration(milliseconds: 500));

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
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
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Logo
                Image.asset(
                  'assets/images/logo2.png',
                  height: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),

                // Username TextField
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
                    controller: _usernameController,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    enableInteractiveSelection: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 15.0, horizontal: 12.0),
                      hintText: 'Enter your Username',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 76, 73, 73),
                        fontSize: 14,
                      ),
                      prefixIcon:
                          const Icon(Icons.person, color: Color(0xFFFEB14C)),
                      suffixIcon: _usernameController.text.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isCheckingUsername)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Color(0xFFFEB14C)),
                                      ),
                                    ),
                                  )
                                else if (_isUsernameAvailable)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  )
                                else if (_usernameError != null)
                                  const Icon(
                                    Icons.error,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.auto_awesome,
                                      color: Color(0xFFFEB14C)),
                                  onPressed: _generateUsernameSuggestions,
                                  tooltip: 'Generate suggestions',
                                ),
                              ],
                            )
                          : IconButton(
                              icon: const Icon(Icons.auto_awesome,
                                  color: Color(0xFFFEB14C)),
                              onPressed: _autoGenerateUsername,
                              tooltip: 'Auto-generate from email',
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
                  ),
                ),

                // Username validation message
                if (_usernameError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _usernameError!,
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Username suggestions
                if (_usernameSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFFFEB14C).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suggested usernames:',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFEB14C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _usernameSuggestions.map((suggestion) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _usernameController.text = suggestion;
                                  _usernameSuggestions.clear();
                                });
                                _checkUsernameAvailability();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEB14C)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFFEB14C)
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  suggestion,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFFFEB14C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Email TextField
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
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enableInteractiveSelection: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 15.0, horizontal: 12.0),
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
                  ),
                ),
                const SizedBox(height: 8),

                // Password TextField
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
                    textInputAction: TextInputAction.next,
                    enableInteractiveSelection: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 15.0, horizontal: 12.0),
                      hintText: 'Enter your Password',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 76, 73, 73),
                        fontSize: 14,
                      ),
                      prefixIcon:
                          const Icon(Icons.lock, color: Color(0xFFFEB14C)),
                      suffixIcon: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
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
                  ),
                ),
                const SizedBox(height: 8),

                // Confirm Password TextField
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
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    enableInteractiveSelection: true,
                    onFieldSubmitted: (_) => _signup(context),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 15.0, horizontal: 12.0),
                      hintText: 'Confirm Password',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 76, 73, 73),
                        fontSize: 14,
                      ),
                      prefixIcon:
                          const Icon(Icons.lock, color: Color(0xFFFEB14C)),
                      suffixIcon: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: const Color(0xFFFEB14C),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
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
                  ),
                ),
                const SizedBox(height: 16),

                // Signup Button
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
                        color: const Color(0xFFFEB14C).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _signup(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'SIGNUP',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Or Login with text
                Row(
                  children: [
                    Expanded(
                        child:
                            Divider(color: Colors.grey.withValues(alpha: 0.3))),
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
                        child:
                            Divider(color: Colors.grey.withValues(alpha: 0.3))),
                  ],
                ),
                const SizedBox(height: 12),

                // Social Login Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialButton(
                      'assets/images/google-logo-icon.png',
                      onTap: signInWithGoogle,
                    ),
                    const SizedBox(width: 16),
                    _buildSocialButton(
                      'assets/images/apple-Icon.png',
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Already have an account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: GoogleFonts.poppins(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "login!",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFFFEB14C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
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
        width: 120,
        height: 55,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey[200] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            imagePath,
            height: 24,
            color: onTap == null ? Colors.grey[400] : null,
          ),
        ),
      ),
    );
  }
}
