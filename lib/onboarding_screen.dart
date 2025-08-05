import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Meet Walkzilla",
      description:
          "Your friendly walking companion to keep you motivated every day",
      iconType: OnboardingIconType.dino,
      iconColor: Color(0xFF4CAF50),
      backgroundColor: Color(0xFF4CAF50),
    ),
    OnboardingPage(
      title: "Track Your Steps",
      description: "Monitor your daily steps and build healthy walking habits",
      iconType: OnboardingIconType.trex,
      iconColor: Color(0xFF2196F3),
      backgroundColor: Color(0xFF2196F3),
    ),
    OnboardingPage(
      title: "Challenge Friends",
      description: "Connect with friends and compete in fun walking challenges",
      iconType: OnboardingIconType.bone,
      iconColor: Color(0xFF9C27B0),
      backgroundColor: Color(0xFF9C27B0),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnboardingCompleted', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top section with progress indicators and skip button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Progress indicators
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: EdgeInsets.only(right: 8),
                        width: index == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? Color(0xFF424242)
                              : Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Skip button
                  GestureDetector(
                    onTap: _skipOnboarding,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFF9C4),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Color(0xFF424242),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Bottom navigation
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF424242),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Stack(
      children: [
        // Background decorative elements
        Positioned(
          left: -50,
          top: 100,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: page.backgroundColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: -30,
          bottom: 150,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: page.backgroundColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Main content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with background
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      page.backgroundColor,
                      page.backgroundColor.withOpacity(0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: page.backgroundColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: _buildIcon(page.iconType, Colors.white),
              ),

              SizedBox(height: 40),

              // Title
              Text(
                page.title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF424242),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 16),

              // Description
              Text(
                page.description,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF757575),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(OnboardingIconType iconType, Color color) {
    switch (iconType) {
      case OnboardingIconType.dino:
        return _buildDinoIcon(color);
      case OnboardingIconType.trex:
        return _buildTrexIcon(color);
      case OnboardingIconType.bone:
        return _buildBoneIcon(color);
    }
  }

  Widget _buildDinoIcon(Color color) {
    return CustomPaint(
      size: Size(120, 120),
      painter: DinoPainter(color),
    );
  }

  Widget _buildTrexIcon(Color color) {
    return CustomPaint(
      size: Size(120, 120),
      painter: TrexPainter(color),
    );
  }

  Widget _buildBoneIcon(Color color) {
    return CustomPaint(
      size: Size(120, 120),
      painter: BonePainter(color),
    );
  }
}

class DinoPainter extends CustomPainter {
  final Color color;

  DinoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw a simple dinosaur shape
    final path = Path();
    path.moveTo(size.width * 0.3, size.height * 0.7);
    path.lineTo(size.width * 0.2, size.height * 0.6);
    path.lineTo(size.width * 0.15, size.height * 0.5);
    path.lineTo(size.width * 0.2, size.height * 0.4);
    path.lineTo(size.width * 0.3, size.height * 0.3);
    path.lineTo(size.width * 0.5, size.height * 0.25);
    path.lineTo(size.width * 0.7, size.height * 0.3);
    path.lineTo(size.width * 0.8, size.height * 0.4);
    path.lineTo(size.width * 0.85, size.height * 0.5);
    path.lineTo(size.width * 0.8, size.height * 0.6);
    path.lineTo(size.width * 0.7, size.height * 0.7);
    path.close();

    canvas.drawPath(path, paint);

    // Draw eyes
    final eyePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.35),
      size.width * 0.03,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.45, size.height * 0.35),
      size.width * 0.03,
      eyePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TrexPainter extends CustomPainter {
  final Color color;

  TrexPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw a T-Rex shape
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.6);
    path.lineTo(size.width * 0.15, size.height * 0.5);
    path.lineTo(size.width * 0.2, size.height * 0.4);
    path.lineTo(size.width * 0.3, size.height * 0.35);
    path.lineTo(size.width * 0.5, size.height * 0.3);
    path.lineTo(size.width * 0.7, size.height * 0.35);
    path.lineTo(size.width * 0.8, size.height * 0.4);
    path.lineTo(size.width * 0.85, size.height * 0.5);
    path.lineTo(size.width * 0.8, size.height * 0.6);
    path.lineTo(size.width * 0.7, size.height * 0.65);
    path.lineTo(size.width * 0.5, size.height * 0.7);
    path.lineTo(size.width * 0.3, size.height * 0.65);
    path.close();

    canvas.drawPath(path, paint);

    // Draw eyes
    final eyePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.4),
      size.width * 0.02,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.45, size.height * 0.4),
      size.width * 0.02,
      eyePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BonePainter extends CustomPainter {
  final Color color;

  BonePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw bone shape
    final path = Path();
    path.moveTo(size.width * 0.3, size.height * 0.4);
    path.lineTo(size.width * 0.4, size.height * 0.35);
    path.lineTo(size.width * 0.45, size.height * 0.4);
    path.lineTo(size.width * 0.55, size.height * 0.4);
    path.lineTo(size.width * 0.6, size.height * 0.35);
    path.lineTo(size.width * 0.7, size.height * 0.4);
    path.lineTo(size.width * 0.7, size.height * 0.6);
    path.lineTo(size.width * 0.6, size.height * 0.65);
    path.lineTo(size.width * 0.55, size.height * 0.6);
    path.lineTo(size.width * 0.45, size.height * 0.6);
    path.lineTo(size.width * 0.4, size.height * 0.65);
    path.lineTo(size.width * 0.3, size.height * 0.6);
    path.close();

    canvas.drawPath(path, paint);

    // Add shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path.shift(Offset(2, 2)), shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum OnboardingIconType {
  dino,
  trex,
  bone,
}

class OnboardingPage {
  final String title;
  final String description;
  final OnboardingIconType iconType;
  final Color iconColor;
  final Color backgroundColor;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.iconType,
    required this.iconColor,
    required this.backgroundColor,
  });
}
