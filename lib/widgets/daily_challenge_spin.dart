import 'package:flutter/material.dart';
import 'dart:math' as math;

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
  final List<Map<String, String>> _games = [
    {'line1': 'Flappy', 'line2': 'Dragon'},
    {'line1': 'Match 3', 'line2': 'Puzzle'},
    {'line1': 'Ball', 'line2': 'Shooter'},
    {'line1': 'Flappy', 'line2': 'Dragon'},
    {'line1': 'Match 3', 'line2': 'Puzzle'},
    {'line1': 'Ball', 'line2': 'Shooter'},
    {'line1': 'Flappy', 'line2': 'Dragon'},
    {'line1': 'Match 3', 'line2': 'Puzzle'},
    {'line1': 'Ball', 'line2': 'Shooter'},
  ];

  // Pastel colors
  final List<Color> _pastelColors = [
    const Color(0xFFD72660), // Even Darker Pink
    const Color(0xFF1B9C48), // Even Darker Green
    const Color(0xFF1A4FA0), // Even Darker Blue
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

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    // Keep wheel size consistent
    final double wheelSize =
        math.min(screenSize.width, screenSize.height) * 0.7;
    // Increase popup size to prevent overflow
    final double popupHeight = _showResult ? wheelSize + 260 : wheelSize + 160;
    final double popupWidth = wheelSize + 60;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: popupWidth,
        height: popupHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Spin the wheel!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 0.0),
              child: Text(
                'Spin the wheel to play a fun mini-game and earn extra points!',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Spin Wheel with shadow
            Container(
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
                            colors: _pastelColors,
                            textScale: 0.8, // smaller text
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
                              color: Colors.blue[400],
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
            // Show result at the bottom if spin is done
            if (_showResult && _resultIndex != null) ...[
              const SizedBox(height: 32),
              const Text(
                'You got:',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_games[_resultIndex!]['line1']} ${_games[_resultIndex!]['line2']}',
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<Map<String, String>> segments;
  final List<Color> colors;
  final double textScale;

  WheelPainter({
    required this.segments,
    required this.colors,
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
      final color = colors[i % colors.length];

      // Draw segment
      final paint = Paint()
        ..color = color.withOpacity(0.8)
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
            color: const Color(0xFF2D2D2D),
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
            color: const Color(0xFF2D2D2D),
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
