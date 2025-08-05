import 'package:flutter/material.dart';
import 'dart:async';

/// Show level up notification overlay
void showLevelUpNotification({
  required BuildContext context,
  required int oldLevel,
  required int newLevel,
  required int reward,
  String? trigger,
  VoidCallback? onDismiss,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.3),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: LevelUpNotification(
        oldLevel: oldLevel,
        newLevel: newLevel,
        reward: reward,
        onDismiss: () {
          Navigator.of(context).pop();
          onDismiss?.call();
        },
      ),
    ),
  );
}

class LevelUpNotification extends StatefulWidget {
  final int oldLevel;
  final int newLevel;
  final int reward;
  final VoidCallback? onDismiss;

  const LevelUpNotification({
    super.key,
    required this.oldLevel,
    required this.newLevel,
    required this.reward,
    this.onDismiss,
  });

  @override
  State<LevelUpNotification> createState() => _LevelUpNotificationState();
}

class _LevelUpNotificationState extends State<LevelUpNotification>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _showReward = false;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _startAnimation();
  }

  void _startAnimation() async {
    // Start scale animation
    await _scaleController.forward();

    // Wait a bit then show reward
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _showReward = true;
      });
    }

    // Start fade animation
    await _fadeController.forward();

    // Auto dismiss after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _fadeController.reverse();
    if (mounted) {
      widget.onDismiss?.call();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _fadeController]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Center(
              child: Container(
                width: 280,
                height: 260,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Stack(
                    children: [
                      // Floating sparkles (minimal)
                      Positioned(
                        top: 2,
                        left: 2,
                        child: _buildSparkle(Colors.yellow, 4, 0),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _buildSparkle(Colors.orange, 4, 500),
                      ),

                      // Close button
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 8,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),

                      // Main content
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),

                          // Header Section with Crown and Sparkles
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: Colors.yellow.shade600,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFF8F00)
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ).createShader(bounds),
                                child: const Text(
                                  'Level up!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              _buildSparkle(Colors.orange.shade400, 10, 300),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Golden Badge Display
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFFA000),
                                  Color(0xFFFF8F00),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFFD700).withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                              border: Border.all(
                                color: const Color(0xFFFFD700).withOpacity(0.8),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${widget.newLevel}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 1,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Reward Strip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9E3),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFFC107).withOpacity(0.2),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                              border: Border.all(
                                color: const Color(0xFFFFC107).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Reward: ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                Text(
                                  '${widget.reward}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Image.asset(
                                  'images/coin.png',
                                  width: 16,
                                  height: 16,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.monetization_on,
                                      color: Color(0xFFFFD700),
                                      size: 16,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Subtext
                          const Text(
                            'Keep moving to unlock more rewards!',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF6B7280),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSparkle(Color color, double size, int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 1000 + delay),
      builder: (context, value, child) {
        return Opacity(
          opacity: (0.5 + 0.5 * value) * (1 - value * 0.3),
          child: Transform.scale(
            scale: 0.8 + 0.2 * value,
            child: Icon(
              Icons.star,
              color: color,
              size: size,
            ),
          ),
        );
      },
    );
  }
}
