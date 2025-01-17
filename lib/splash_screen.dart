import 'package:flutter/material.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToWelcomeScreen();
  }

  void _navigateToWelcomeScreen() async {
    await Future.delayed(const Duration(seconds: 5)); // Set splash duration
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: Stack(
        children: [
          // Ground (GIF) at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/gifs/ground.gif',
              height: 150, // Adjust height as needed
              width: MediaQuery.of(context).size.width,
              fit: BoxFit.cover, // Make the GIF span the full width
            ),
          ),

          // Dino Image (centered above ground)
          Positioned(
            bottom: 60, // Positioned above the ground
            left: MediaQuery.of(context).size.width / 2 -
                160, // Center horizontally
            child: Image.asset(
              'assets/images/dino.png',
              height: 300,
              width: 300,
            ),
          ),

          // Walkzilla Logo (GIF) at the top
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/gifs/logo.gif',
              height: 200,
              width: 600,
              fit: BoxFit.contain,
            ),
          ),

          // Tagline (GIF) below the logo
          Positioned(
            top: 220,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/gifs/tagline.gif',
              height: 100,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
