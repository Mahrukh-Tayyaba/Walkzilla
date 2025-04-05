import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home.dart'; // Import the HomeScreen
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

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
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _signup(BuildContext context) async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    try {
      // Create authentication record
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Create user profile in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'profileImage': null,
        'bio': '',
        'steps': 0,
        'distance': 0.0,
        'calories': 0,
        'weeklyGoal': 0,
        'monthlyGoal': 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup successful!")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = "An error occurred";
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $errorMessage")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
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

      // Create/Update user profile in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'username': googleUser.displayName,
        'email': googleUser.email,
        'photoURL': googleUser.photoUrl,
        'lastLogin': FieldValue.serverTimestamp(),
        'profileImage': googleUser.photoUrl,
        'bio': '',
        'steps': 0,
        'distance': 0.0,
        'calories': 0,
        'weeklyGoal': 0,
        'monthlyGoal': 0,
      }, SetOptions(merge: true)); // merge: true will update existing documents

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
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
      body: SingleChildScrollView(
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
              TextFormField(
                controller: _usernameController,
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
                      const Icon(Icons.person, color: Color(0xFF5C5A5A)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Email TextField
              TextFormField(
                controller: _emailController,
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
                  prefixIcon: const Icon(Icons.email, color: Color(0xFF5C5A5A)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Password TextField
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
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
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF5C5A5A)),
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
                      color: const Color(0xFF5C5A5A),
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
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Confirm Password TextField
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
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
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF5C5A5A)),
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
                      color: const Color(0xFF5C5A5A),
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Signup Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      offset: const Offset(0, 2),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => _signup(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEB14C),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'SIGNUP',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Or Login with text
              Text(
                'Or Login with',
                style: GoogleFonts.poppins(
                  color: const Color.fromARGB(255, 76, 73, 73),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),

              // Social Login Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google Button
                  GestureDetector(
                    onTap: signInWithGoogle,
                    child: Container(
                      width: 120,
                      height: 55,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F4F4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDADADA)),
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/google-logo-icon.png',
                          height: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Apple Button
                  Container(
                    width: 120,
                    height: 55,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F4F4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDADADA)),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/apple-Icon.png',
                        height: 24,
                      ),
                    ),
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
                      color: const Color.fromARGB(255, 76, 73, 73),
                      fontSize: 16,
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
                        fontSize: 16,
                        color: const Color(0xFFFEB14C),
                        fontWeight: FontWeight.w500,
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
    );
  }
}
