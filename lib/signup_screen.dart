import 'package:flutter/material.dart';
import 'login_screen.dart'; // Import the LoginScreen
import 'package:firebase_auth/firebase_auth.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false; // Updated toggle state

  Future<void> _signup(BuildContext context) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup successful!")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
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
      backgroundColor: const Color(0xFFD9D9D9), // Light grey background
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              // Walkzilla Image
              Container(
                width: 150,
                height: 250,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/logo2.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 0), // Minimal spacing below logo

              // Email TextField
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color.fromARGB(255, 255, 255, 255),
                  hintText: 'Your Email',
                  prefixIcon: const Icon(Icons.person, color: Colors.orange),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Password TextField
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible, // Toggle visibility
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color.fromARGB(255, 255, 255, 255), // White
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock, color: Colors.orange),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible =
                            !_isPasswordVisible; // Toggle state
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Signup Button (Full Width)
              ElevatedButton(
                onPressed: () => _signup(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800), // Orange color
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'SIGN UP',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 20),

              // Sign-in Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Already have an Account? ",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                    child: const Text(
                      "Log in",
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Divider with OR
              Row(
                children: const [
                  Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      "OR",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 20),

              // Social Media Icons (Black)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.facebook,
                        color: Colors.black, size: 40),
                    onPressed: () {
                      // Handle Facebook signup
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon:
                        const Icon(Icons.email, color: Colors.black, size: 40),
                    onPressed: () {
                      // Handle Email signup
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.g_translate,
                        color: Colors.black, size: 40),
                    onPressed: () {
                      // Handle Google signup
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
