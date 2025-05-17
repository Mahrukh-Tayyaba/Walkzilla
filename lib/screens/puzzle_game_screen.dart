import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../home.dart';

class PuzzleGameScreen extends StatefulWidget {
  const PuzzleGameScreen({super.key});

  @override
  State<PuzzleGameScreen> createState() => _PuzzleGameScreenState();
}

class _PuzzleGameScreenState extends State<PuzzleGameScreen> {
  late List<int> _tiles;
  late int _emptyTileIndex;
  int _moves = 0;
  bool _isGameWon = false;
  int _seconds = 0;
  Timer? _timer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    _timer?.cancel();
    _moves = 0;
    _isGameWon = false;
    _seconds = 0;
    _started = false;
    do {
      _tiles = List.generate(8, (index) => index + 1);
      _tiles.add(0); // Add empty tile
      _emptyTileIndex = 8;
      _shuffleTiles();
    } while (_isSolved()); // Ensure not solved at start
    setState(() {});
  }

  bool _isSolved() {
    for (int i = 0; i < 8; i++) {
      if (_tiles[i] != i + 1) return false;
    }
    return _tiles[8] == 0;
  }

  bool _isTileInCorrectPosition(int index) {
    return _tiles[index] == index + 1;
  }

  void _shuffleTiles() {
    final random = Random();
    for (int i = 0; i < 1000; i++) {
      final possibleMoves = _getPossibleMoves();
      if (possibleMoves.isNotEmpty) {
        final move = possibleMoves[random.nextInt(possibleMoves.length)];
        // Swap tiles directly, do not call _moveTile (which calls _checkWin)
        final temp = _tiles[move];
        _tiles[move] = _tiles[_emptyTileIndex];
        _tiles[_emptyTileIndex] = temp;
        _emptyTileIndex = move;
      }
    }
    // Ensure the puzzle is solvable
    if (!_isSolvable()) {
      _shuffleTiles();
    }
  }

  bool _isSolvable() {
    int inversions = 0;
    for (int i = 0; i < _tiles.length - 1; i++) {
      for (int j = i + 1; j < _tiles.length; j++) {
        if (_tiles[i] != 0 && _tiles[j] != 0 && _tiles[i] > _tiles[j]) {
          inversions++;
        }
      }
    }
    return inversions % 2 == 0;
  }

  List<int> _getPossibleMoves() {
    List<int> moves = [];
    final row = _emptyTileIndex ~/ 3;
    final col = _emptyTileIndex % 3;

    if (row > 0) moves.add(_emptyTileIndex - 3); // Up
    if (row < 2) moves.add(_emptyTileIndex + 3); // Down
    if (col > 0) moves.add(_emptyTileIndex - 1); // Left
    if (col < 2) moves.add(_emptyTileIndex + 1); // Right

    return moves;
  }

  void _moveTile(int index, {bool countMove = true}) {
    if (_getPossibleMoves().contains(index) && !_isGameWon) {
      setState(() {
        final temp = _tiles[index];
        _tiles[index] = _tiles[_emptyTileIndex];
        _tiles[_emptyTileIndex] = temp;
        _emptyTileIndex = index;
        if (countMove) {
          _moves++;
          if (!_started) {
            _started = true;
            _startTimer();
          }
        }
        _checkWin();
      });
    }
  }

  void _checkWin() {
    for (int i = 0; i < 8; i++) {
      if (_tiles[i] != i + 1) return;
    }
    if (_tiles[8] == 0) {
      setState(() {
        _isGameWon = true;
      });
      _timer?.cancel();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Congratulations!',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
              content: Text(
                'You earned $_points points!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _points == 10 ? Colors.orange : Colors.blueGrey,
                ),
                textAlign: TextAlign.center,
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text('Go to Home',
                        style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        }
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _points => _seconds <= 300 ? 10 : 5;

  String _formatTime() {
    if (_seconds < 60) {
      return '${_seconds}s';
    }
    final minutes = _seconds ~/ 60;
    final remainingSeconds = _seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final double gridSize = MediaQuery.of(context).size.width * 0.6;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('8 Puzzle', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: SizedBox(
                width: gridSize,
                height: gridSize,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    final isEmpty = _tiles[index] == 0;
                    final isMovable = _getPossibleMoves().contains(index);
                    return GestureDetector(
                      onTap: () => _moveTile(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        decoration: BoxDecoration(
                          color:
                              isEmpty ? const Color(0xFFF5F5F5) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isEmpty
                                ? const Color(0xFFE0E0E0)
                                : (_isTileInCorrectPosition(index)
                                    ? const Color(
                                        0xFF61A4AD) // correct position
                                    : const Color(0xFF3A4256)),
                            width: 3,
                          ),
                          boxShadow: isEmpty
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(1, 2),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: isEmpty
                              ? null
                              : Text(
                                  _tiles[index].toString(),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: (_isTileInCorrectPosition(index))
                                        ? const Color(0xFF61A4AD)
                                        : const Color(0xFF3A4256),
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _initializeGame,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFF28500), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'RESET',
                          style: TextStyle(
                            color: Color(0xFFF28500),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFF3A4256), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        minimumSize: const Size(0, 48),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'TIME: ${_formatTime()}',
                          style: const TextStyle(
                            color: Color(0xFF3A4256),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFF3A4256), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        minimumSize: const Size(0, 48),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'MOVES: $_moves',
                          style: const TextStyle(
                            color: Color(0xFF3A4256),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
