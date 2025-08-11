import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../screens/puzzle_game_screen.dart';
import '../screens/flappy_dragon_game.dart';
import '../screens/vertical_2048_game.dart';

class DailyChallengeSpin extends StatefulWidget {
  const DailyChallengeSpin({super.key});

  @override
  State<DailyChallengeSpin> createState() => _DailyChallengeSpinState();
}

class _DailyChallengeSpinState extends State<DailyChallengeSpin>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Tween<double>? _spinTween;
  bool _isSpinning = false;
  bool _showResult = false;
  int? _resultIndex;
  final List<Map<String, dynamic>> _games = [
    {'line1': 'Flappy', 'line2': 'Dragon', 'color': const Color(0xFFFFF176)},
    {'line1': '8', 'line2': 'Puzzle', 'color': const Color(0xFFFFAB91)},
    {'line1': 'Merge', 'line2': 'Puzzle', 'color': const Color(0xFF90CAF9)},
    {'line1': 'Flappy', 'line2': 'Dragon', 'color': const Color(0xFFFFF176)},
    {'line1': '8', 'line2': 'Puzzle', 'color': const Color(0xFFFFAB91)},
    {'line1': 'Merge', 'line2': 'Puzzle', 'color': const Color(0xFF90CAF9)},
    {'line1': 'Flappy', 'line2': 'Dragon', 'color': const Color(0xFFFFF176)},
    {'line1': '8', 'line2': 'Puzzle', 'color': const Color(0xFFFFAB91)},
    {'line1': 'Merge', 'line2': 'Puzzle', 'color': const Color(0xFF90CAF9)},
  ];

  double _currentAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isSpinning = false;
          _currentAngle = _spinTween?.end ?? 0.0;
          // Calculate the result index
          final int segmentCount = _games.length;
          final double segmentAngle = 2 * math.pi / segmentCount;
          double normalized = (_currentAngle % (2 * math.pi));
          int index = segmentCount - (normalized / segmentAngle).round();
          if (index == segmentCount) index = 0;
          _resultIndex = index;
          _showResult = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startSpin() {
    if (_isSpinning) return;
    setState(() {
      _isSpinning = true;
      _showResult = false;
      _resultIndex = null;
    });
    final random = math.Random();
    final int segmentCount = _games.length;
    int targetSegment = random.nextInt(segmentCount);
    // Avoid repeating the previous result
    if (_resultIndex != null && segmentCount > 1) {
      while (targetSegment == _resultIndex) {
        targetSegment = random.nextInt(segmentCount);
      }
    }
    final int fullSpins = 4 + random.nextInt(2); // 4-5 full spins
    final double segmentAngle = 2 * math.pi / segmentCount;
    final double targetAngle = (segmentCount - targetSegment) * segmentAngle;
    final double totalAngle = (2 * math.pi * fullSpins) + targetAngle;
    _spinTween =
        Tween<double>(begin: _currentAngle, end: _currentAngle + totalAngle);
    _controller.duration = Duration(milliseconds: 3500 + random.nextInt(1200));
    _controller.reset();
    _controller.forward();
  }

  void _navigateToGame() {
    if (_resultIndex == null) return;

    // Determine the game based on the selected segment
    final selectedGame = _games[_resultIndex!];
    final gameName = selectedGame['line2']?.toLowerCase();
    final gameType = selectedGame['line1']?.toLowerCase();

    if (gameName == 'dragon') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FlappyDragonGame()),
      );
    } else if (gameName == 'puzzle' && gameType == '8') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PuzzleGameScreen()),
      );
    } else if (gameName == 'puzzle' && gameType == 'merge') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Vertical2048Game()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double wheelSize = math.min(
      screenSize.width * 0.85,
      screenSize.height * 0.5,
    );
    // Padding values
    final double initialTopPadding = screenSize.height * 0.18;
    final double resultTopPadding = screenSize.height * 0.05;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF1DC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF1DC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Daily Challenge',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Headline and subtitle at the top, only before spinning
            if (!_showResult) ...[
              const Padding(
                padding: EdgeInsets.only(top: 40.0, left: 0, right: 0),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Spin the wheel!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'to play a fun mini-game and earn extra points!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // AnimatedAlign for the wheel
            AnimatedAlign(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOutBack,
              alignment: _showResult ? Alignment.topCenter : Alignment.center,
              child: Padding(
                padding: EdgeInsets.only(
                  top: _showResult ? 40.0 : 0.0,
                ),
                child: Container(
                  width: wheelSize,
                  height: wheelSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Wheel
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          final double angle = _spinTween == null
                              ? _currentAngle
                              : _spinTween!.evaluate(_animation);
                          return Transform.rotate(
                            angle: angle,
                            child: CustomPaint(
                              size: Size(wheelSize, wheelSize),
                              painter: WheelPainter(
                                segments: _games,
                                textScale: 0.8,
                              ),
                            ),
                          );
                        },
                      ),
                      // White triangle pointer above the center circle
                      Positioned(
                        top: (wheelSize / 2) - 48,
                        child: CustomPaint(
                          size: const Size(36, 28),
                          painter: WhiteTrianglePointerPainter(),
                        ),
                      ),
                      // Center Button (white circle)
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _startSpin,
                            customBorder: const CircleBorder(),
                            child: Center(
                              child: Text(
                                'SPIN',
                                style: TextStyle(
                                  color: const Color(0xFF3B82F6),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Show result at the bottom if spin is done
            if (_showResult && _resultIndex != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'You got:',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_games[_resultIndex!]['line1']} ${_games[_resultIndex!]['line2']}',
                        style: TextStyle(
                          fontSize: 32,
                          color: _games[_resultIndex!]['color'],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: SizedBox(
                          width: 200,
                          child: ElevatedButton(
                            onPressed: _navigateToGame,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _games[_resultIndex!]['color'],
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Play Now',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> segments;
  final double textScale;

  WheelPainter({
    required this.segments,
    this.textScale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * math.pi / segments.length;

    // Draw segments
    for (var i = 0; i < segments.length; i++) {
      final startAngle = i * segmentAngle;
      final color = segments[i]['color'];

      // Draw segment
      final paint = Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      // Draw segment border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        borderPaint,
      );

      // Draw text
      final textPainter1 = TextPainter(
        text: TextSpan(
          text: segments[i]['line1'],
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14 * textScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      final textPainter2 = TextPainter(
        text: TextSpan(
          text: segments[i]['line2'],
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14 * textScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter1.layout();
      textPainter2.layout();

      // Position text in the middle of the segment
      final textAngle = startAngle + segmentAngle / 2;
      final textRadius = radius * 0.7;
      final textX = center.dx + textRadius * math.cos(textAngle);
      final textY = center.dy + textRadius * math.sin(textAngle);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + math.pi / 2);

      // Draw first line
      textPainter1.paint(
        canvas,
        Offset(-textPainter1.width / 2, -textPainter1.height - 2),
      );

      // Draw second line
      textPainter2.paint(
        canvas,
        Offset(-textPainter2.width / 2, 2),
      );

      canvas.restore();
    }

    // Draw center circle
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.1, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WhiteTrianglePointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

    final Path path = Path();
    path.moveTo(size.width / 2, 0); // Top center
    path.lineTo(0, size.height); // Bottom left
    path.lineTo(size.width, size.height); // Bottom right
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
