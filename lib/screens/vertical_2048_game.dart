import 'package:flutter/material.dart';
import 'dart:math';
import '../services/coin_service.dart';

class _BlockPos {
  final int col, row;
  const _BlockPos(this.col, this.row);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BlockPos &&
          runtimeType == other.runtimeType &&
          col == other.col &&
          row == other.row;

  @override
  int get hashCode => col.hashCode ^ row.hashCode;
}

class _MergeAnimation {
  final int fromCol, fromRow, toCol, toRow, value;
  AnimationController controller;
  Animation<double> animation;
  _MergeAnimation({
    required this.fromCol,
    required this.fromRow,
    required this.toCol,
    required this.toRow,
    required this.value,
    required TickerProvider vsync,
  })  : controller = AnimationController(
            duration: const Duration(milliseconds: 300), vsync: vsync),
        animation = CurvedAnimation(
            parent: AnimationController(
                duration: const Duration(milliseconds: 300), vsync: vsync),
            curve: Curves.easeInOutCubic);
}

class Vertical2048Game extends StatefulWidget {
  const Vertical2048Game({super.key});

  @override
  State<Vertical2048Game> createState() => _Vertical2048GameState();
}

class _Vertical2048GameState extends State<Vertical2048Game>
    with TickerProviderStateMixin {
  static const int columns = 5;
  static const int rows = 7;
  static const Color backgroundColor = Color(0xFFF8F1E3);
  static const int targetScore = 2048; // Target score to win
  List<List<int?>> grid =
      List.generate(columns, (_) => List.filled(rows, null));
  int score = 0;
  int? currentBlock;
  int? nextBlock;
  int? draggingColumn;
  double dragOffset = 0;
  bool isGameOver = false;
  bool isGameWon = false;
  final Random random = Random();
  final CoinService _coinService = CoinService();

  // Animation state for falling block
  bool isDropping = false;
  int? droppingCol;
  int? droppingRow;
  AnimationController? dropController;
  Animation<double>? dropAnimation;

  List<_MergeAnimation> mergeAnimations = [];

  @override
  void initState() {
    super.initState();
    currentBlock = _randomBlock();
    nextBlock = _randomBlock();
  }

  @override
  void dispose() {
    dropController?.dispose();
    super.dispose();
  }

  void _generateNextTile() {
    setState(() {
      currentBlock = _randomBlock();
      nextBlock = _randomBlock();
    });
  }

  void _dropBlock(int col) async {
    if (isGameOver || currentBlock == null || isDropping) return;
    int? row = _firstEmptyRow(col);
    int bottomRow = rows - 1;

    // Forced merge at the bottom if column is full and bottom block matches
    if (row == null) {
      if (grid[col][bottomRow] == currentBlock) {
        // Instantly merge at the bottom, no animation
        setState(() {
          grid[col][bottomRow] = grid[col][bottomRow]! * 2;
          score += grid[col][bottomRow]!;
        });
        await _handleMerges(col, bottomRow);
        setState(() {
          currentBlock = nextBlock;
          nextBlock = _randomBlock();
        });
        _checkWinCondition();
        if (_isGameOver()) {
          setState(() {
            isGameOver = true;
          });
        }
        return;
      } else {
        // Column full and no merge possible
        return;
      }
    }

    // 1. Run merges/collapse before animating the drop
    await _handleMerges(col, null);

    // 2. Find the correct available row for the new block
    int? finalRow = _firstEmptyRow(col);
    finalRow ??= 0;

    // 3. Animate the block from below the grid to that row
    setState(() {
      isDropping = true;
      droppingCol = col;
      droppingRow = finalRow;
    });

    dropController?.dispose();
    dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    dropAnimation = Tween<double>(begin: 0.0, end: finalRow.toDouble()).animate(
        CurvedAnimation(parent: dropController!, curve: Curves.easeOut));

    dropController!.forward();
    await Future.delayed(dropController!.duration!);

    // 4. Insert the block into the grid at that row after the animation
    setState(() {
      grid[col][finalRow!] = currentBlock;
      isDropping = false;
      droppingCol = null;
      droppingRow = null;
    });

    // 5. Run merges/collapse for the new block
    await _handleMerges(col, finalRow);

    setState(() {
      currentBlock = nextBlock;
      nextBlock = _randomBlock();
    });

    _checkWinCondition();
    if (_isGameOver()) {
      setState(() {
        isGameOver = true;
      });

      // Show game over dialog when columns are full
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !isGameWon) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Game Over!',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
              content: const Text(
                'All columns are full! You lost.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        _resetGame();
                      },
                      child: const Text(
                        'Play Again',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      child: const Text(
                        'Go Home',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      });
    }
  }

  int? _firstEmptyRow(int col) {
    for (int r = rows - 1; r >= 0; r--) {
      if (grid[col][r] == null) return r;
    }
    return null;
  }

  int _randomBlock() => [2, 4, 8, 16].elementAt(random.nextInt(4));

  Future<void> _handleMerges(int col, int? row) async {
    bool merged = true;
    while (merged) {
      merged = false;
      final visited = List.generate(columns, (_) => List.filled(rows, false));
      List<_BlockPos>? groupToMerge;
      int? valueToMerge;
      // Find the first group to merge
      for (int c = 0; c < columns; c++) {
        for (int r = 0; r < rows; r++) {
          if (grid[c][r] == null || visited[c][r]) continue;
          final group = _findMergeGroup(c, r, grid[c][r]!, visited);
          if (group.length > 1) {
            groupToMerge = group;
            valueToMerge = grid[c][r]!;
            break;
          }
        }
        if (groupToMerge != null) break;
      }
      if (groupToMerge != null && valueToMerge != null) {
        merged = true;
        // Animate all blocks in the group except the merge destination
        final mergeTarget =
            groupToMerge.reduce((a, b) => (a.row > b.row) ? a : b);
        for (final pos in groupToMerge) {
          if (pos.col == mergeTarget.col && pos.row == mergeTarget.row) {
            continue;
          }
          final anim = _MergeAnimation(
            fromCol: pos.col,
            fromRow: pos.row,
            toCol: mergeTarget.col,
            toRow: mergeTarget.row,
            value: valueToMerge,
            vsync: this,
          );
          anim.controller.forward();
          mergeAnimations.add(anim);
        }
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 300));
        for (final anim in mergeAnimations) {
          anim.controller.dispose();
        }
        mergeAnimations.clear();
        setState(() {
          for (final pos in groupToMerge!) {
            grid[pos.col][pos.row] = null;
          }
          // Place merged block at the lowest row in the group
          grid[mergeTarget.col][mergeTarget.row] = valueToMerge! * 2;
          score += valueToMerge * 2;
          _collapseColumns();
        });
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  bool _isGameOver() {
    // All columns full?
    for (int c = 0; c < columns; c++) {
      if (_firstEmptyRow(c) != null) return false;
    }
    // Any possible merges?
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[c][r] == null) continue;
        final value = grid[c][r]!;
        for (final d in [
          [1, 0],
          [-1, 0],
          [0, 1],
          [0, -1]
        ]) {
          int nc = c + d[0], nr = r + d[1];
          if (nc >= 0 && nc < columns && nr >= 0 && nr < rows) {
            if (grid[nc][nr] == value) return false;
          }
        }
      }
    }
    return true;
  }

  Color _tileColor(int value) {
    switch (value) {
      case 2:
        return Colors.pink[100]!;
      case 4:
        return Colors.pink[200]!;
      case 8:
        return Colors.pink[300]!;
      case 16:
        return Colors.purple[200]!;
      case 32:
        return Colors.red[200]!;
      case 64:
        return Colors.deepPurple[200]!;
      case 128:
        return Colors.orange[200]!;
      case 256:
        return Colors.orange[300]!;
      case 512:
        return Colors.orange[400]!;
      case 1024:
        return Colors.yellow[600]!;
      case 2048:
        return Colors.yellow[800]!;
      case 4096:
        return Colors.brown[200]!;
      case 8192:
        return Colors.brown[400]!;
      default:
        return Colors.grey[300]!;
    }
  }

  void _resetGame() {
    setState(() {
      // Reset grid
      grid = List.generate(columns, (_) => List.filled(rows, null));

      // Reset game state
      score = 0;
      isGameOver = false;
      isGameWon = false;
      isDropping = false;
      droppingCol = null;
      droppingRow = null;

      // Generate new blocks
      currentBlock = _randomBlock();
      nextBlock = _randomBlock();

      // Clear animations
      for (final anim in mergeAnimations) {
        anim.controller.dispose();
      }
      mergeAnimations.clear();
    });
  }

  void _checkWinCondition() {
    if (score >= targetScore && !isGameWon) {
      setState(() {
        isGameWon = true;
        isGameOver = true;
      });

      // Award 50 coins when user reaches target score
      _coinService.addCoins(50).then((success) {
        if (success) {
          print('Successfully awarded 50 coins for reaching target score');
        } else {
          print('Failed to award coins for reaching target score');
        }
      });

      // Show win dialog
      Future.delayed(const Duration(milliseconds: 500), () {
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
              content: const Text(
                'You reached the target score and earned 50 coins!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
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

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    const double tileMargin = 4;
    const double columnsToFit = 5;
    const double horizontalPadding = 12.0;
    final double availableWidth = screenWidth - 2 * horizontalPadding;
    final double tileWidth =
        (availableWidth - (tileMargin * 2 * columnsToFit)) / columnsToFit;

    // Calculate available height for the game area (subtract app bar, score, etc.)
    final double topPadding = MediaQuery.of(context).padding.top;
    final double reservedHeight = topPadding +
        16 +
        22 +
        16 +
        24 +
        80; // appbar, score, spacing, next tile, restart, etc.
    final double availableHeight = screenHeight - reservedHeight;
    final double tileHeight = (availableHeight - (rows - 1) * 8) / rows;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title:
            const Text('Merge Puzzle', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Target: $targetScore',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      )),
                  Text('Your Score: $score',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            score >= targetScore ? Colors.green : Colors.black,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double availableHeight = constraints.maxHeight;
                    final double tileHeight =
                        (availableHeight - (rows - 1) * tileMargin) / rows;
                    return Stack(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(columns, (col) {
                            return GestureDetector(
                              onTap: () => _dropBlock(col),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: tileMargin),
                                width: tileWidth,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: List.generate(rows, (row) {
                                    int gridRow = rows - row - 1;
                                    bool isBeingAnimated = mergeAnimations.any(
                                        (anim) =>
                                            anim.fromCol == col &&
                                            anim.fromRow == gridRow);
                                    int? value = (!isBeingAnimated &&
                                            col >= 0 &&
                                            col < grid.length &&
                                            gridRow >= 0 &&
                                            gridRow < grid[col].length)
                                        ? grid[col][gridRow]
                                        : null;
                                    return AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      margin: EdgeInsets.only(
                                        top: 0,
                                        bottom: row != rows - 1
                                            ? tileMargin
                                            : 0, // No margin after last tile
                                      ),
                                      height: tileHeight,
                                      width: tileWidth * 0.92,
                                      decoration: BoxDecoration(
                                        color: value != null
                                            ? _tileColor(value)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: value != null
                                          ? Text(
                                              '$value',
                                              style: TextStyle(
                                                fontSize: tileWidth * 0.38,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    );
                                  }),
                                ),
                              ),
                            );
                          }),
                        ),
                        // Merge animations overlay
                        ...mergeAnimations.map((anim) {
                          final double startLeft =
                              anim.fromCol * (tileWidth + tileMargin * 2) +
                                  tileMargin;
                          final double startTop = (rows - 1 - anim.fromRow) *
                              (tileHeight + tileMargin);
                          final double endLeft =
                              anim.toCol * (tileWidth + tileMargin * 2) +
                                  tileMargin;
                          final double endTop = (rows - 1 - anim.toRow) *
                              (tileHeight + tileMargin);
                          return AnimatedBuilder(
                            animation: anim.controller,
                            builder: (context, child) {
                              final t = anim.controller.value;
                              final left =
                                  startLeft + (endLeft - startLeft) * t;
                              final top = startTop + (endTop - startTop) * t;
                              return Positioned(
                                left: left,
                                top: top,
                                child: Container(
                                  width: tileWidth * 0.92,
                                  height: tileHeight,
                                  decoration: BoxDecoration(
                                    color: _tileColor(anim.value),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${anim.value}',
                                    style: TextStyle(
                                      fontSize: tileWidth * 0.38,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                        // Falling block animation overlay
                        if (isDropping &&
                            droppingCol != null &&
                            droppingRow != null &&
                            dropAnimation != null)
                          AnimatedBuilder(
                            animation: dropAnimation!,
                            builder: (context, child) {
                              final double y = dropAnimation!.value;
                              final double top =
                                  (rows - 1 - y) * (tileHeight + tileMargin);
                              return Positioned(
                                left: droppingCol! *
                                        (tileWidth + tileMargin * 2) +
                                    tileMargin,
                                top: top,
                                child: Container(
                                  width: tileWidth * 0.92,
                                  height: tileHeight,
                                  decoration: BoxDecoration(
                                    color: _tileColor(currentBlock ?? 2),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${currentBlock ?? ""}',
                                    style: TextStyle(
                                      fontSize: tileWidth * 0.38,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Current block (large)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _tileColor(currentBlock ?? 2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${currentBlock ?? ""}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Small gap
                const SizedBox(width: 4),
                // Next block (small, vertically centered)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _tileColor(nextBlock ?? 2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${nextBlock ?? ""}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<_BlockPos> _findMergeGroup(
      int col, int row, int value, List<List<bool>> visited) {
    final group = <_BlockPos>[];
    final stack = <_BlockPos>[_BlockPos(col, row)];
    while (stack.isNotEmpty) {
      final pos = stack.removeLast();
      if (pos.col < 0 || pos.col >= columns || pos.row < 0 || pos.row >= rows) {
        continue;
      }
      if (visited[pos.col][pos.row]) continue;
      if (grid[pos.col][pos.row] != value) continue;
      visited[pos.col][pos.row] = true;
      group.add(pos);
      // Check 4 directions
      stack.add(_BlockPos(pos.col + 1, pos.row));
      stack.add(_BlockPos(pos.col - 1, pos.row));
      stack.add(_BlockPos(pos.col, pos.row + 1));
      stack.add(_BlockPos(pos.col, pos.row - 1));
    }
    return group;
  }

  void _collapseColumns() {
    for (int c = 0; c < columns; c++) {
      List<int?> newCol = List.filled(rows, null);
      int insertRow = rows - 1;
      for (int r = rows - 1; r >= 0; r--) {
        if (grid[c][r] != null) {
          newCol[insertRow] = grid[c][r];
          insertRow--;
        }
      }
      grid[c] = newCol;
    }
  }
}
