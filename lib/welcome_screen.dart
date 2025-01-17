import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Add this package for custom fonts.
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9), // Light gray background
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Walkzilla Logo (GIF)
          const SizedBox(height: 70),
          Image.asset(
            'assets/gifs/logo.gif', // Replace with the actual path to your GIF

            fit: BoxFit.contain,
          ),
          const SizedBox(height: 10),
          Text(
            "The Couch Potato’s Worst Nightmare",
            textAlign: TextAlign.center,
            style: GoogleFonts.leagueGothic(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 0, 0, 0),
            ),
          ),

          const SizedBox(height: 80), // Spacing between subtitle and buttons

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

                const SizedBox(height: 15), // Spacing between buttons

                // Signup Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignupScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, // White background
                    foregroundColor: Colors.black, // Black text color
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(25), // Rounded corners
                    ),
                  ),
                  child: const Text(
                    'SIGN UP',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40), // Bottom spacing
        ],
      ),
    );
  }
}
