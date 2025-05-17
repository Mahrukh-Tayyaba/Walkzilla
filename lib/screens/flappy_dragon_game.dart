import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class FlappyDragonGame extends StatefulWidget {
  const FlappyDragonGame({super.key});

  @override
  State<FlappyDragonGame> createState() => _FlappyDragonGameState();
}

class _FlappyDragonGameState extends State<FlappyDragonGame>
    with SingleTickerProviderStateMixin {
  // Game constants
  static const double dragonSize = 110.0;
  static const double gravity = 0.2;
  static const double jumpStrength = -5.0;
  static const double pillarWidth = 140.0;
  static const double gapHeight = dragonSize * 3.0; // Much wider gap
  static const double pillarSpeed = 2.5; // Slower pipes
  static const int numPillars = 2;

  // Game state
  double dragonY = 0;
  double dragonVelocity = 0;
  bool gameStarted = false;
  bool gameOver = false;
  bool timeUp = false; // Track if the game ended due to timer
  int score = 0;

  Timer? _gameLoopTimer;
  Timer? _endTimer; // Timer for 2-minute limit
  double _gameAreaHeight = 0.0;
  double _appBarHeight = 0.0;
  bool _initialLayoutDone = false;

  // Pillar state
  late List<double> pillarX; // X positions
  late List<double> gapY; // Y position of the gap's top
  Random rand = Random();

  @override
  void initState() {
    super.initState();
    pillarX = List.generate(numPillars, (i) => 0.0);
    gapY = List.generate(numPillars, (i) => 0.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _initialLayoutDone && !gameStarted && !gameOver) {
        dragonY = _gameAreaHeight / 2 - dragonSize / 2;
        setState(() {});
      }
    });
  }

  void _calculateDimensions(BuildContext context, BoxConstraints constraints) {
    if (!_initialLayoutDone) {
      final anAppBar = AppBar(title: const Text(''));
      _appBarHeight = anAppBar.preferredSize.height;
      _gameAreaHeight = constraints.maxHeight;
      double screenWidth = MediaQuery.of(context).size.width;
      for (int i = 0; i < numPillars; i++) {
        pillarX[i] = screenWidth +
            300 +
            i * (screenWidth / numPillars + 150); // Delay first pipe
        gapY[i] = _randomGapY();
      }
      dragonY = _gameAreaHeight / 2 - dragonSize / 2;
      _initialLayoutDone = true;
      debugPrint('Game area height: [32m[1m[4m[7m[5m[3m[9m[0m');
      debugPrint('Initial dragonY: $dragonY');
    }
  }

  double _randomGapY() {
    // Ensure the gap stays within the screen
    if (_gameAreaHeight == 0) return 100;
    double minGapY = 60;
    double maxGapY = _gameAreaHeight - gapHeight - 60;
    if (maxGapY < minGapY) {
      // If the gap is too large for the screen, center it
      return (_gameAreaHeight - gapHeight) / 2;
    }
    return minGapY + rand.nextDouble() * (maxGapY - minGapY);
  }

  void _startGameLoop() {
    if (!_initialLayoutDone) return;
    // Prevent starting if game is over or time is up
    if (gameOver || timeUp) return;
    setState(() {
      gameStarted = true;
      gameOver = false;
      timeUp = false;
      dragonVelocity = -1.0; // Start with a slower gentle fall
      dragonY = _gameAreaHeight / 2 - dragonSize / 2;
      score = 0;
      double screenWidth = MediaQuery.of(context).size.width;
      for (int i = 0; i < numPillars; i++) {
        pillarX[i] = screenWidth +
            300 +
            i * (screenWidth / numPillars + 150); // Delay first pipe
        gapY[i] = _randomGapY();
      }
    });
    // Gravity ramp-up
    double currentGravity = 0.0;
    Timer? gravityTimer;
    gravityTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (currentGravity < gravity) {
        currentGravity += 0.02;
        if (currentGravity > gravity) currentGravity = gravity;
      } else {
        gravityTimer?.cancel();
      }
    });
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (!gameOver && !timeUp) {
          // Dragon physics
          dragonVelocity += currentGravity;
          dragonY += dragonVelocity;
          // Pillar movement
          double screenWidth = MediaQuery.of(context).size.width;
          for (int i = 0; i < numPillars; i++) {
            pillarX[i] -= pillarSpeed;
            // If pillar goes off screen, reset it to the right
            if (pillarX[i] < -pillarWidth) {
              pillarX[i] = screenWidth + pillarWidth;
              gapY[i] = _randomGapY();
            }
          }
          // Collision detection
          for (int i = 0; i < numPillars; i++) {
            if (_pillarHitsDragon(i)) {
              _endGame();
              return;
            }
            // Score: if dragon just passed a pillar
            if (pillarX[i] + pillarWidth < screenWidth / 4 &&
                pillarX[i] + pillarWidth + pillarSpeed >= screenWidth / 4) {
              score++;
            }
          }
          // Boundaries
          final gameAreaBottom = _gameAreaHeight - dragonSize;
          if (dragonY >= gameAreaBottom) {
            dragonY = gameAreaBottom;
            _endGame();
          }
          if (dragonY < 0) {
            dragonY = 0;
            dragonVelocity = 0;
          }
        } else {
          timer.cancel();
        }
      });
    });
    // Start 2-minute timer
    _endTimer?.cancel();
    _endTimer = Timer(const Duration(minutes: 2), () {
      if (mounted && gameStarted && !gameOver) {
        setState(() {
          timeUp = true;
          gameStarted = false;
        });
        _gameLoopTimer?.cancel();
      }
    });
  }

  bool _pillarHitsDragon(int i) {
    const double dragonPadding = 18.0; // Shrink collision box for forgiveness
    double dragonLeft = MediaQuery.of(context).size.width / 4 + dragonPadding;
    double dragonRight =
        MediaQuery.of(context).size.width / 4 + dragonSize - dragonPadding;
    double dragonTop = dragonY + dragonPadding;
    double dragonBottom = dragonY + dragonSize - dragonPadding;
    double pillarLeft = pillarX[i];
    double pillarRight = pillarX[i] + pillarWidth;
    // Check horizontal overlap
    bool horizontal = dragonRight > pillarLeft && dragonLeft < pillarRight;
    // Check vertical overlap (top pillar)
    bool verticalTop = dragonTop < gapY[i];
    // Check vertical overlap (bottom pillar)
    bool verticalBottom = dragonBottom > gapY[i] + gapHeight;
    if (horizontal && (verticalTop || verticalBottom)) {
      return true;
    }
    return false;
  }

  void _jump() {
    if (!_initialLayoutDone) return;
    // Prevent restarting if game is over or time is up
    if (gameOver || timeUp) return;
    if (!gameStarted) {
      _startGameLoop();
    } else {
      setState(() {
        dragonVelocity = jumpStrength;
      });
    }
  }

  void _endGame() {
    setState(() {
      gameOver = true;
      gameStarted = false;
    });
    _gameLoopTimer?.cancel();
    _endTimer?.cancel();
  }

  void _resetGame() {
    if (!_initialLayoutDone) {
      dragonY = MediaQuery.of(context).size.height / 3;
      setState(() {
        gameStarted = false;
        gameOver = false;
      });
      return;
    }
    setState(() {
      dragonY = _gameAreaHeight / 2 - dragonSize / 2;
      dragonVelocity = 0;
      gameStarted = false;
      gameOver = false;
      score = 0;
      double screenWidth = MediaQuery.of(context).size.width;
      for (int i = 0; i < numPillars; i++) {
        pillarX[i] = screenWidth + i * (screenWidth / numPillars + 150);
        gapY[i] = _randomGapY();
      }
    });
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _endTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final appBar = AppBar(
      title: const Text('Flappy Dragon'),
    );
    return Scaffold(
      appBar: appBar,
      body: LayoutBuilder(
        builder:
            (BuildContext layoutBuilderContext, BoxConstraints constraints) {
          _calculateDimensions(layoutBuilderContext, constraints);
          return GestureDetector(
            onTap: _jump,
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFFF8F1E3),
                  width: double.infinity,
                  height: double.infinity,
                ),
                // Pillars
                if (_initialLayoutDone)
                  ...List.generate(numPillars, (i) {
                    return Stack(
                      children: [
                        // Top pillar
                        Positioned(
                          left: pillarX[i],
                          top: 0,
                          child: Image.asset(
                            'assets/images/pipe.png',
                            width: pillarWidth,
                            height: gapY[i],
                            fit: BoxFit.fill,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: pillarWidth,
                              height: gapY[i],
                              color: Colors.brown,
                              child: const Center(
                                  child: Text('No Pipe',
                                      style: TextStyle(color: Colors.white))),
                            ),
                          ),
                        ),
                        // Bottom pillar
                        Positioned(
                          left: pillarX[i],
                          top: gapY[i] + gapHeight,
                          child: Transform.rotate(
                            angle: 3.14159, // 180 degrees in radians
                            child: Image.asset(
                              'assets/images/pipe.png',
                              width: pillarWidth,
                              height: _gameAreaHeight - (gapY[i] + gapHeight),
                              fit: BoxFit.fill,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: pillarWidth,
                                height: _gameAreaHeight - (gapY[i] + gapHeight),
                                color: Colors.brown,
                                child: const Center(
                                    child: Text('No Pipe',
                                        style: TextStyle(color: Colors.white))),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                // Dragon
                if (_initialLayoutDone)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 0),
                    top: dragonY,
                    left: screenWidth / 4,
                    child: Image.asset(
                      'assets/images/dragon.png',
                      width: dragonSize,
                      height: dragonSize,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: dragonSize,
                        height: dragonSize,
                        color: Colors.green,
                        child: const Center(
                            child: Text('No Dragon',
                                style: TextStyle(color: Colors.white))),
                      ),
                    ),
                  ),
                // Score
                if (_initialLayoutDone)
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        ' $score',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black,
                              offset: Offset(4, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Tap to Start
                if (!gameStarted && !gameOver && _initialLayoutDone)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.22,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'Tap to Start',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                // Game Over
                if (gameOver && _initialLayoutDone)
                  Center(
                    child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ]),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Game Over',
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Score: $score',
                              style: const TextStyle(
                                  fontSize: 22, color: Colors.black87),
                            ),
                          ],
                        )),
                  ),
                // The End popup
                if (timeUp && _initialLayoutDone)
                  Center(
                    child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ]),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'The End',
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orangeAccent),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Score: $score',
                              style: const TextStyle(
                                  fontSize: 22, color: Colors.black87),
                            ),
                          ],
                        )),
                  ),
                if (!_initialLayoutDone)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          );
        },
      ),
    );
  }
}
