import 'package:flutter/material.dart';
import 'login_screen.dart'; // Import the LoginScreen

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color.fromARGB(255, 255, 253, 243), // Light beige background
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80), // Add some top padding
              // Walkzilla Image
              Container(
                width: 150, // Consistent width with LoginScreen
                height: 150, // Consistent height with LoginScreen
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/logo2.png'), // Logo image
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 30), // Same spacing as in LoginScreen

              // Email Input
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person, color: Colors.orange),
                  hintText: 'Your Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFFF3E0), // Match LoginScreen
                ),
              ),
              const SizedBox(height: 20),

              // Password Input
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock, color: Colors.orange),
                  suffixIcon: const Icon(Icons.visibility, color: Colors.grey),
                  hintText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFFF3E0), // Match LoginScreen
                ),
              ),
              const SizedBox(height: 20),

              // Signup Button
              ElevatedButton(
                onPressed: () {
                  // Handle signup logic here
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800), // Orange color
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'SIGN UP',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),

              // Sign In Text
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
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
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

              // Social Media Icons
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
