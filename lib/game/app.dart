import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'backend/runner_game.dart';
import 'backend/game_api.dart';

/// `GameScreen` is a Widget wrapper around the RunnerGame + input Listener.
/// Use this widget with `Navigator.push(...)` from the Home UI when starting
/// the actual game. This replaces the previous `main()` entry that launched
/// the game directly.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final RunnerGame runner;
  late final GlobalKey leftKey;
  late final GlobalKey rightKey;
  late final GlobalKey jumpKey;
  late final ValueNotifier<int> leftPressCount;
  late final ValueNotifier<int> rightPressCount;
  late final ValueNotifier<int> jumpPressCount;

  final Map<int, String> pointerToControl = <int, String>{};
  final Map<String, Set<int>> controlPointers = {
    'left': <int>{},
    'right': <int>{},
    'jump': <int>{},
  };

  @override
  void initState() {
    super.initState();
    // Ensure landscape mode when entering the game
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    runner = RunnerGame();
    leftKey = GlobalKey();
    rightKey = GlobalKey();
    jumpKey = GlobalKey();
    leftPressCount = ValueNotifier<int>(0);
    rightPressCount = ValueNotifier<int>(0);
    jumpPressCount = ValueNotifier<int>(0);
  }

  void startControl(String control) {
    if (runner.gameState != GameState.playing) return;
    switch (control) {
      case 'left':
        runner.moveLeftStart();
        break;
      case 'right':
        runner.moveRightStart();
        break;
      case 'jump':
        runner.pressJumpImmediate();
        break;
    }
  }

  void stopControl(String control) {
    if (runner.gameState != GameState.playing) return;
    switch (control) {
      case 'left':
      case 'right':
        runner.moveStop();
        break;
      case 'jump':
        runner.releaseJumpImmediate();
        break;
    }
  }

  @override
  void dispose() {
    leftPressCount.dispose();
    rightPressCount.dispose();
    jumpPressCount.dispose();
    runner.pauseEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (ev) {
          if (runner.gameState == GameState.intro) {
            runner.startGame();
            return;
          }
          String? hit;
          final jumpObj = jumpKey.currentContext?.findRenderObject();
          if (jumpObj is RenderBox) {
            final jumpRect = jumpObj.localToGlobal(Offset.zero) & jumpObj.size;
            if (jumpRect.contains(ev.position)) hit = 'jump';
          }
          if (hit == null) {
            final leftObj = leftKey.currentContext?.findRenderObject();
            if (leftObj is RenderBox) {
              final leftRect =
                  leftObj.localToGlobal(Offset.zero) & leftObj.size;
              if (leftRect.contains(ev.position)) hit = 'left';
            }
          }
          if (hit == null) {
            final rightObj = rightKey.currentContext?.findRenderObject();
            if (rightObj is RenderBox) {
              final rightRect =
                  rightObj.localToGlobal(Offset.zero) & rightObj.size;
              if (rightRect.contains(ev.position)) hit = 'right';
            }
          }

          if (hit != null) {
            pointerToControl[ev.pointer] = hit;
            final set = controlPointers[hit]!;
            set.add(ev.pointer);
            if (set.length == 1) startControl(hit);
            if (hit == 'left') leftPressCount.value = set.length;
            if (hit == 'right') rightPressCount.value = set.length;
            if (hit == 'jump') jumpPressCount.value = set.length;
          }
        },
        onPointerMove: (ev) {
          final previous = pointerToControl[ev.pointer];
          String? now;
          final jumpObj = jumpKey.currentContext?.findRenderObject();
          if (jumpObj is RenderBox) {
            final jumpRect = jumpObj.localToGlobal(Offset.zero) & jumpObj.size;
            if (jumpRect.contains(ev.position)) now = 'jump';
          }
          if (now == null) {
            final leftObj = leftKey.currentContext?.findRenderObject();
            if (leftObj is RenderBox) {
              final leftRect =
                  leftObj.localToGlobal(Offset.zero) & leftObj.size;
              if (leftRect.contains(ev.position)) now = 'left';
            }
          }
          if (now == null) {
            final rightObj = rightKey.currentContext?.findRenderObject();
            if (rightObj is RenderBox) {
              final rightRect =
                  rightObj.localToGlobal(Offset.zero) & rightObj.size;
              if (rightRect.contains(ev.position)) now = 'right';
            }
          }

          if (previous == now) return;
          if (previous != null) {
            final prevSet = controlPointers[previous]!;
            prevSet.remove(ev.pointer);
            if (prevSet.isEmpty) stopControl(previous);
            pointerToControl.remove(ev.pointer);
            if (previous == 'left') leftPressCount.value = prevSet.length;
            if (previous == 'right') rightPressCount.value = prevSet.length;
            if (previous == 'jump') jumpPressCount.value = prevSet.length;
          }
          if (now != null) {
            pointerToControl[ev.pointer] = now;
            final nowSet = controlPointers[now]!;
            nowSet.add(ev.pointer);
            if (nowSet.length == 1) startControl(now);
            if (now == 'left') leftPressCount.value = nowSet.length;
            if (now == 'right') rightPressCount.value = nowSet.length;
            if (now == 'jump') jumpPressCount.value = nowSet.length;
          }
        },
        onPointerUp: (ev) {
          final control = pointerToControl.remove(ev.pointer);
          if (control != null) {
            final set = controlPointers[control]!;
            set.remove(ev.pointer);
            if (set.isEmpty) stopControl(control);
            if (control == 'left') leftPressCount.value = set.length;
            if (control == 'right') rightPressCount.value = set.length;
            if (control == 'jump') jumpPressCount.value = set.length;
          }
        },
        onPointerCancel: (ev) {
          final control = pointerToControl.remove(ev.pointer);
          if (control != null) {
            final set = controlPointers[control]!;
            set.remove(ev.pointer);
            if (set.isEmpty) stopControl(control);
            if (control == 'left') leftPressCount.value = set.length;
            if (control == 'right') rightPressCount.value = set.length;
            if (control == 'jump') jumpPressCount.value = set.length;
          }
        },
        child: GameWidget(
          game: runner,
          overlayBuilderMap: {
            'Controls': (context, game) {
              return SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 20,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ValueListenableBuilder<int>(
                              valueListenable: leftPressCount,
                              builder: (ctx, count, child) {
                                return Container(
                                  key: leftKey,
                                  width: 80,
                                  height: 80,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: count > 0
                                        ? Colors.blueAccent.withValues(
                                            alpha: 0.75,
                                          )
                                        : Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_left,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                            ValueListenableBuilder<int>(
                              valueListenable: rightPressCount,
                              builder: (ctx, count, child) {
                                return Container(
                                  key: rightKey,
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: count > 0
                                        ? Colors.blueAccent.withAlpha(
                                            (0.75 * 255).round(),
                                          )
                                        : Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_right,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: jumpPressCount,
                          builder: (ctx, count, child) {
                            return Container(
                              key: jumpKey,
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: count > 0
                                    ? Colors.blueAccent.withAlpha(
                                        (0.75 * 255).round(),
                                      )
                                    : Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_upward,
                                color: Colors.white,
                                size: 36,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            'LevelComplete': (context, game) {
              final RunnerGame g = game as RunnerGame;
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Has ganado',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          g.resetGame();
                        },
                        child: const Text('Volver a jugar'),
                      ),
                    ],
                  ),
                ),
              );
            },
            'GameOver': (context, game) {
              final RunnerGame g = game as RunnerGame;
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Game Over',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          g.resetGame();
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            },
          },
          initialActiveOverlays: const ['Controls'],
        ),
      ),
    );
  }
}
