import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'duo_challenge_invite_screen.dart';
import 'zombie_run_invite_screen.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with TickerProviderStateMixin {
  late AnimationController _zombieController;
  late AnimationController _duelController;
  late Animation<double> _zombieScale;
  late Animation<double> _duelScale;
  late Animation<double> _zombieRotation;
  late Animation<double> _duelRotation;

  @override
  void initState() {
    super.initState();
    _zombieController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _duelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _zombieScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _zombieController, curve: Curves.easeInOut),
    );
    _duelScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _duelController, curve: Curves.easeInOut),
    );
    _zombieRotation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(parent: _zombieController, curve: Curves.easeInOut),
    );
    _duelRotation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(parent: _duelController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _zombieController.dispose();
    _duelController.dispose();
    super.dispose();
  }

  void _handleZombieRun() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ZombieRunInviteScreen()),
    );
  }

  void _handleStepDuel() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Step Duel Challenge!'),
        backgroundColor: const Color(0xFFE91E63),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DuoChallengeInviteScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F8FA), Colors.white, Color(0xFFE3F2FD)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Header
                const Text(
                  'Choose Challenge',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                    shadows: [
                      Shadow(
                        offset: Offset(4, 4),
                        color: Colors.white,
                        blurRadius: 0,
                      ),
                      Shadow(
                        offset: Offset(-1, -1),
                        color: Colors.white,
                        blurRadius: 0,
                      ),
                      Shadow(
                        offset: Offset(1, -1),
                        color: Colors.white,
                        blurRadius: 0,
                      ),
                      Shadow(
                        offset: Offset(-1, 1),
                        color: Colors.white,
                        blurRadius: 0,
                      ),
                      Shadow(
                        offset: Offset(1, 1),
                        color: Colors.white,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Pick your adventure and start your fitness journey!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1A1A).withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 0),
                // Challenge Cards
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Zombie Run Card
                        SizedBox(
                          width: 220,
                          height: 250,
                          child: _ChallengeCard(
                            title: 'Zombie Run',
                            icon: const Icon(
                              FontAwesomeIcons.skull,
                              color: Colors.white,
                              size: 45,
                            ),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFE8F5E8),
                                Color(0xFFF0F8F0),
                                Color(0xFFE3F2FD),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            circleGradient: const LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shadowColor: const Color(0xFF4CAF50),
                            accentColor: const Color(0xFF4CAF50),
                            scaleAnimation: _zombieScale,
                            rotationAnimation: _zombieRotation,
                            onTap: _handleZombieRun,
                            onTapDown: () => _zombieController.forward(),
                            onTapUp: () => _zombieController.reverse(),
                            onTapCancel: () => _zombieController.reverse(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Step Duel Card
                        SizedBox(
                          width: 220,
                          height: 250,
                          child: _ChallengeCard(
                            title: 'Step Duel',
                            icon: const Icon(
                              FontAwesomeIcons.khanda,
                              color: Colors.white,
                              size: 45,
                            ),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFF3E5F5),
                                Color(0xFFF8F0FF),
                                Color(0xFFE1F5FE),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            circleGradient: const LinearGradient(
                              colors: [Color(0xFFE91E63), Color(0xFFF06292)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shadowColor: const Color(0xFFE91E63),
                            accentColor: const Color(0xFFE91E63),
                            scaleAnimation: _duelScale,
                            rotationAnimation: _duelRotation,
                            onTap: _handleStepDuel,
                            onTapDown: () => _duelController.forward(),
                            onTapUp: () => _duelController.reverse(),
                            onTapCancel: () => _duelController.reverse(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatefulWidget {
  final String title;
  final Widget icon;
  final LinearGradient gradient;
  final LinearGradient circleGradient;
  final Color shadowColor;
  final Color accentColor;
  final Animation<double> scaleAnimation;
  final Animation<double> rotationAnimation;
  final VoidCallback onTap;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  const _ChallengeCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.circleGradient,
    required this.shadowColor,
    required this.accentColor,
    required this.scaleAnimation,
    required this.rotationAnimation,
    required this.onTap,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.scaleAnimation,
        widget.rotationAnimation,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: widget.scaleAnimation.value,
          child: Transform.rotate(
            angle: widget.rotationAnimation.value,
            child: GestureDetector(
              onTap: widget.onTap,
              onTapDown: (_) => widget.onTapDown(),
              onTapUp: (_) => widget.onTapUp(),
              onTapCancel: () => widget.onTapCancel(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: widget.accentColor.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.shadowColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon Circle
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: widget.circleGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.shadowColor.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: widget.icon,
                      ),
                      const SizedBox(height: 12),
                      // Title
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Decorative elements
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _pulseAnimation.value,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF2196F3),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _pulseAnimation.value,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFE91E63),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _pulseAnimation.value,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                              );
                            },
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
}
