import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'welcome_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasError = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    // Skip video for now to prevent emulator crashes
    if (mounted) {
      setState(() {
        _hasError = true;
      });

      // Navigate after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isNavigating) {
          _navigateToNextScreen();
        }
      });
    }
  }

  void _navigateToNextScreen() async {
    if (_isNavigating) return;
    _isNavigating = true;

    // Check if onboarding has been completed
    final prefs = await SharedPreferences.getInstance();
    final isOnboardingCompleted =
        prefs.getBool('isOnboardingCompleted') ?? false;

    Widget nextScreen;
    if (isOnboardingCompleted) {
      nextScreen = const WelcomeScreen();
    } else {
      nextScreen = const OnboardingScreen();
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _hasError || !_isVideoInitialized
            ? _buildFallbackUI()
            : _buildVideoUI(),
      ),
    );
  }

  Widget _buildVideoUI() {
    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: VideoPlayer(_videoController!),
    );
  }

  Widget _buildFallbackUI() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFEB14C)),
      ),
    );
  }
}
