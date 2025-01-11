import 'package:flutter/material.dart';
import 'signup_screen.dart'; // Import the SignupScreen

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color.fromARGB(255, 255, 253, 243), // Light beige background
      body: Center(
        child: SingleChildScrollView(
          // Added SingleChildScrollView for responsiveness
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize
                  .min, // Ensures the column is only as tall as its children
              children: [
                // Walkzilla logo image
                Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image:
                          AssetImage('assets/images/logo2.png'), // Updated path
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Email TextField
                TextField(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFFFF3E0), // Light orange
                    hintText: 'Your Email',
                    prefixIcon: const Icon(Icons.email, color: Colors.orange),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Password TextField
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFFFF3E0), // Light orange
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock, color: Colors.orange),
                    suffixIcon:
                        const Icon(Icons.visibility, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Login Button
                ElevatedButton(
                  onPressed: () {
                    // Handle login logic
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800), // Orange color
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('LOGIN', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 20),
                // Sign-up prompt
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an Account? ",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
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
                      child: const Text(
                        "Sign up",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
