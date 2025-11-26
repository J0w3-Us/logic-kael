import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'player/player.dart';
import 'obstacles/spikes.dart';
import 'obstacles/spike_manager.dart';
// Supabase calls disabled for local testing
import 'scene/scene_builder.dart';
import 'scene/scene_loader.dart';
import 'game_api.dart';
import 'collision_utils.dart';

class RunnerGame extends FlameGame with TapCallbacks implements GameApi {
  @override
  GameState gameState = GameState.intro;
  Player? player;
  @override
  double groundHeight = 120.0;
  ui.Image? _groundImage;
  ui.Image? _spikeImage;
  Uint8List? _spikePixels;
  ui.Image? _doorImage;
  late SpikeManager spikeManager;
  // Supabase disabled for local testing; we always use local level data
  // These are read dynamically by `Player` (outside this file).
  // ignore: unused_field
  Uint8List? _doorPixels;
  // ignore: unused_field
  Vector2? _doorNaturalSize;
  // ignore: unused_field
  Rect? _doorRect;
  int? _groundTopTrim;
  final List<Component> _groundComponents = [];
  final List<Component> _spikeComponents = [];
  final List<Component> _homingSpikes = [];
  final double _playerStartX = 100.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Load ground/map image. If it fails, don't throw: provide a simple
    // fallback ground so the game can continue in local testing.
    try {
      // Try a couple of candidate names to accommodate different asset names
      final mapCandidates = ['map.png', 'Map.png'];
      ui.Image? gimg;
      for (final k in mapCandidates) {
        try {
          await images.load(k);
          gimg = images.fromCache(k);
          if (gimg != null) break;
        } catch (_) {
          // try next
        }
      }
      if (gimg != null) {
        _groundImage = gimg;
        _groundTopTrim = await _computeTopNonTransparent(_groundImage!);
      } else {
        _groundImage = null;
        _groundTopTrim = 0;
        debugPrint('⚠️ Could not load any map image from candidates');
        groundHeight = 120.0;
      }
    } catch (e) {
      debugPrint('⚠️ Could not load map image: $e');
      _groundImage = null;
      _groundTopTrim = 0;
      groundHeight = 120.0;
    }

    try {
      final spikeCandidates = ['pinchos.png', 'spikes.png'];
      ui.Image? sImg;
      for (final k in spikeCandidates) {
        try {
          await images.load(k);
          sImg = images.fromCache(k);
          if (sImg != null) break;
        } catch (_) {}
      }
      if (sImg != null) {
        _spikeImage = sImg;
        final bd = await _spikeImage!.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        _spikePixels = bd?.buffer.asUint8List();
      } else {
        _spikeImage = null;
      }
    } catch (_) {
      _spikeImage = null;
    }

    try {
      final doorCandidates = ['puerta.png', 'door.png'];
      ui.Image? dImg;
      for (final k in doorCandidates) {
        try {
          await images.load(k);
          dImg = images.fromCache(k);
          if (dImg != null) break;
        } catch (_) {}
      }
      if (dImg != null) {
        _doorImage = dImg;
        final bd2 = await _doorImage!.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        _doorPixels = bd2?.buffer.asUint8List();
      } else {
        _doorImage = null;
        _doorPixels = null;
      }
    } catch (_) {
      _doorImage = null;
      _doorPixels = null;
    }

    // Instantiate SpikeManager and load local level data.
    spikeManager = SpikeManager();
    add(spikeManager);
    await spikeManager.loadLevelData(1);

    if (size != Vector2.zero()) {
      _buildScene(size);
    }
    // Start in intro state, wait for a tap to begin
    gameState = GameState.intro;
  }

  Future<int> _computeTopNonTransparent(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return 0;
    final data = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    for (int y = 0; y < height; y++) {
      final rowStart = y * width * 4;
      for (int x = 0; x < width; x++) {
        final alpha = data[rowStart + x * 4 + 3];
        if (alpha > 10) {
          return y;
        }
      }
    }
    return 0;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _buildScene(size);
  }

  void _buildScene(Vector2 canvasSize) {
    // Clear previous ground/homing spike components
    for (final c in _groundComponents) {
      remove(c);
    }
    _groundComponents.clear();

    for (final c in _homingSpikes) {
      remove(c);
    }
    _homingSpikes.clear();

    double visibleTop;
    // If we have a ground image, build detailed ground parts. Otherwise
    // create a simple fallback ground rectangle so the scene can start.
    if (_groundImage != null) {
      final scene = buildGroundParts(
        _groundImage!,
        canvasSize,
        _groundTopTrim ?? 0,
      );
      for (final c in scene.components) {
        add(c);
        _groundComponents.add(c);
      }
      groundHeight = scene.groundHeight;
      visibleTop = scene.visibleTop;
    } else {
      // Simple fallback ground: a rectangle at the bottom of the screen.
      final fallbackHeight = groundHeight <= 0 ? 120.0 : groundHeight;
      final groundRect = RectangleComponent(
        position: Vector2(0, canvasSize.y - fallbackHeight),
        size: Vector2(canvasSize.x, fallbackHeight),
        paint: ui.Paint()..color = const ui.Color(0xFF7B4F1E),
      )..anchor = Anchor.topLeft;
      add(groundRect);
      _groundComponents.add(groundRect);
      groundHeight = fallbackHeight;
      visibleTop = canvasSize.y - groundHeight;
    }

    _doorRect = null;
    if (_doorImage != null) {
      final doorNatural = Vector2(
        _doorImage!.width.toDouble(),
        _doorImage!.height.toDouble(),
      );
      _doorNaturalSize = doorNatural;
      final doorHeight = min(doorNatural.y, groundHeight * 1.5);
      final doorScale = doorHeight / doorNatural.y;
      final doorWidth = doorNatural.x * doorScale;
      final doorComponent = SpriteComponent(
        sprite: Sprite(_doorImage!),
        position: Vector2(canvasSize.x, visibleTop),
        size: Vector2(doorWidth, doorHeight),
        anchor: Anchor.bottomRight,
      )..priority = 1;
      add(doorComponent);
      final doorLeft = canvasSize.x - doorWidth;
      _doorRect = Rect.fromLTWH(
        doorLeft,
        visibleTop - doorHeight,
        doorWidth,
        doorHeight,
      );
    }

    if (player != null) {
      remove(player!);
    }
    player = Player(size: Vector2(50, 50));
    player!.position = Vector2(_playerStartX, visibleTop - player!.size.y);
    add(player!);

    // SpikeManager will populate spikes from local assets if needed.
  }

  void addPinchos(double visibleTop) {
    // Remove previous spikes
    for (final c in _spikeComponents) {
      remove(c);
    }
    _spikeComponents.clear();
    for (final c in _homingSpikes) {
      remove(c);
    }
    _homingSpikes.clear();

    if (_spikeImage != null && _spikePixels != null) {
      final spikeSprite = Sprite(_spikeImage!);
      final spikeNatural = Vector2(
        _spikeImage!.width.toDouble(),
        _spikeImage!.height.toDouble(),
      );
      // Load a scene config (for now a default based on canvas width).
      // In the future this can load per-level configs from assets.
      final config = SceneLoader.loadForLevel(1, size.x);
      final result = createSpikesForScene(
        spikeSprite: spikeSprite,
        spikeNatural: spikeNatural,
        spikePixels: _spikePixels!,
        visibleTop: visibleTop,
        groundHeight: groundHeight,
        canvasWidth: size.x,
        config: config,
      );

      for (final s in result.spikes) {
        s.priority = 0;
        add(s);
        _spikeComponents.add(s);
      }
      for (final h in result.homingSpikes) {
        // assign target now that player exists
        h.target = player;
        h.priority = 0;
        add(h);
        _homingSpikes.add(h);
      }
    }
  }

  @override
  void onPlayerDied() {
    if (gameState == GameState.playing) {
      gameState = GameState.gameOver;
      overlays.add('GameOver');
      pauseEngine();
      // Report death to backend (best-effort) via GameApiClient.
      () async {
        try {
          await GameApiClient.recordDeath();
        } catch (e) {
          debugPrint('⚠️ GameApiClient.recordDeath failed: $e');
        }
      }();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameState == GameState.intro) {
      startGame();
    }
    // Do not trigger jumps from generic taps on the game area. Jump should
    // only be triggered via the dedicated jump button to avoid accidental
    // jumps when touching the screen.
  }

  @override
  void onTapUp(TapUpEvent event) {
    // No-op: jump release is handled by the jump button overlay only.
  }

  void startGame() {
    gameState = GameState.playing;
    overlays.remove('intro');
    resumeEngine();
  }

  void resetGame() {
    // Eliminar overlays
    overlays.remove('GameOver');
    overlays.remove('win');

    // Reiniciar estado y reconstruir la escena
    gameState = GameState.playing;
    _buildScene(size);
    if (player != null) {
      player!.invulnerable = 1.0; // Dar un segundo de invulnerabilidad
    }
    resumeEngine();
  }

  void onLevelComplete() {
    if (gameState == GameState.playing) {
      gameState = GameState.won;
      pauseEngine();
      overlays.add('win');
      // Notify backend about level completion (best-effort)
      () async {
        try {
          final res = await GameApiClient.completeLevel(1);
          debugPrint('✅ completeLevel RPC result: $res');
        } catch (e) {
          debugPrint('⚠️ completeLevel RPC failed: $e');
        }
      }();
    }
  }

  void moveLeftStart() {
    if (gameState == GameState.playing) player?.moveLeft = true;
  }

  void moveRightStart() {
    if (gameState == GameState.playing) player?.moveRight = true;
  }

  void moveStop() {
    player?.moveLeft = false;
    player?.moveRight = false;
  }

  void jump() {
    if (gameState == GameState.playing) player?.jump();
  }

  // Input helpers for low-latency pointer forwarding from Flutter widgets.
  void pressJumpImmediate() {
    if (gameState == GameState.playing) player?.pressJump();
    // Start latency timer for this jump input
    _lastPointerDownWatch = Stopwatch()..start();
    _waitingForJumpLatency = true;
  }

  void releaseJumpImmediate() {
    if (gameState == GameState.playing) player?.releaseJump();
  }

  // Latency measurement helpers
  Stopwatch? _lastPointerDownWatch;
  bool _waitingForJumpLatency = false;

  @override
  void update(double dt) {
    super.update(dt);

    // Centralizar detección de colisiones aquí: si el jugador toca un pincho => morir
    if (player == null || !player!.isMounted) return;

    if (player!.invulnerable <= 0 && gameState == GameState.playing) {
      final playerRect = Rect.fromLTWH(
        player!.position.x,
        player!.position.y,
        player!.size.x,
        player!.size.y,
      );
      for (final c in _spikeComponents) {
        if (c is Spike) {
          if (checkPixelPerfectCollision(playerRect, c)) {
            onPlayerDied();
            return;
          }
        }
      }

      if (_doorRect != null) {
        if (playerRect.overlaps(_doorRect!)) {
          if (_doorPixels != null && _doorNaturalSize != null) {
            if (checkPixelPerfectDoorCollision(
              playerRect,
              _doorRect!,
              _doorNaturalSize!,
              _doorPixels!,
            )) {
              onLevelComplete();
            }
          } else {
            onLevelComplete();
          }
        }
      }
    }

    // Latency measurement: if we were waiting for a jump to be applied,
    // consider it occurred when player's vertical velocity becomes negative.
    if (_waitingForJumpLatency && player!.velocity.y < 0) {
      final elapsed = _lastPointerDownWatch?.elapsedMilliseconds ?? -1;
      debugPrint('Jump latency: ${elapsed}ms');
      _lastPointerDownWatch?.stop();
      _waitingForJumpLatency = false;
    }
    // Timeout: if too long without jump, reset the waiting flag
    if (_waitingForJumpLatency &&
        _lastPointerDownWatch != null &&
        _lastPointerDownWatch!.elapsedMilliseconds > 1000) {
      debugPrint('Jump latency: timeout >1000ms');
      _lastPointerDownWatch?.stop();
      _waitingForJumpLatency = false;
    }
  }

  // Collision helpers have been moved to `collision_utils.dart`.
}
