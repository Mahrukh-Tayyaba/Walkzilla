import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Add this package for custom fonts.
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color.fromARGB(255, 255, 253, 243), // Light beige background
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top Spacer
          const Spacer(),
          // Logo and Subtitle
          Column(
            children: [
              // Walkzilla Logo (GIF) - Doubled size
              Image.asset(
                'assets/gifs/logo.gif',
                height: 600, // Logo size
                width: 600,
              ),
              // Subtitle
              Text(
                "The Couch Potato’s Worst Nightmare",
                textAlign: TextAlign.center,
                style: GoogleFonts.leagueGothic(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: [
                // Login Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA726), // Orange color
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'LOGIN',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 15),
                // Signup Button
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignupScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black87),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'SIGN UP',
                    style: TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
