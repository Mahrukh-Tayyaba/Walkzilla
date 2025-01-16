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
      MaterialPageRoute(builder: (context) => WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Ground (GIF 3) at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/gifs/ground.gif',
              height: 200,
              width: 500,
            ),
          ),

          // Dino Image (centered above ground)
          Positioned(
            bottom: 120,
            child: Image.asset(
              'assets/images/dino.png',
              height: 250,
            ),
          ),

          // Walkzilla Logo (GIF 1) at the top
          Positioned(
            top: 100,
            child: Image.asset(
              'assets/gifs/logo.gif',
              height: 200,
              width: 500,
              fit: BoxFit.contain,
            ),
          ),

          // Tagline (GIF 2) below the logo
          Positioned(
            top: 320,
            child: Image.asset(
              'assets/gifs/tagline.gif',
              height: 50,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
