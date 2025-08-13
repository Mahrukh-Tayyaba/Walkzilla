import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'welcome_screen.dart';
import 'onboarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _videoController;
  VoidCallback? _videoListener;
  bool _isVideoInitialized = false;
  bool _hasError = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final controller =
          VideoPlayerController.asset('assets/videos/splash_screen.mp4');
      _videoController = controller;

      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);

      if (!mounted) return;
      setState(() {
        _isVideoInitialized = true;
        _hasError = false;
      });

      // Navigate when the video finishes
      _videoListener = () {
        if (!mounted || _isNavigating) return;
        final value = controller.value;
        if (value.isInitialized &&
            !value.isPlaying &&
            value.position >= value.duration) {
          _navigateToNextScreen();
        }
      };
      controller.addListener(_videoListener!);

      await controller.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isVideoInitialized = false;
      });

      // Fallback: short delay then navigate
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

    try {
      // Check if user is already authenticated
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      if (currentUser != null) {
        // User is already logged in, go to home
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
          );
        }
        return;
      }

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
    } catch (e) {
      print('Error in splash screen navigation: $e');
      // Fallback to welcome screen on error
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_videoController != null && _videoListener != null) {
      _videoController!.removeListener(_videoListener!);
    }
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
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      ),
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
