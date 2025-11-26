// ignore_for_file: deprecated_member_use
import 'package:flame/components.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../game_api.dart';

class Spike extends PositionComponent {
  final Uint8List pixels;
  // Precomputed alpha mask: 1 for opaque, 0 for transparent, length = imgW * imgH
  final Uint8List alphaMask;
  final Vector2 naturalSize;
  final Sprite? sprite;

  Spike({
    this.sprite,
    Vector2? position,
    Vector2? size,
    Anchor? anchor,
    Uint8List? pixels,
    required this.alphaMask,
    required this.naturalSize,
  }) : pixels = pixels ?? Uint8List(0),
       super(
         position: position ?? Vector2.zero(),
         size: size ?? Vector2.zero(),
         anchor: anchor ?? Anchor.topLeft,
       );

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (sprite != null) {
      sprite!.render(canvas, size: size);
    } else {
      final paint = ui.Paint()..color = const ui.Color(0xFF8B0000);
      canvas.drawRect(ui.Offset.zero & size.toSize(), paint);
    }
  }
}

/// HomingSpike no depende en tiempo de compilación de RunnerGame/Player,
/// usamos tipos dinámicos para evitar import circular. Se asume que
/// `target` expone `position`, `size`, `toRect()` y (opcional) `invulnerable`.
class HomingSpike extends PositionComponent with HasGameRef {
  // `target` must be mutable so caller can assign the player after
  // constructing the spike (avoids circular import issues).
  dynamic target;
  final double speed;
  final double startDelay;
  double _timeSinceSpawn = 0.0;
  bool _isMoving = false;
  double? _targetX;
  final Sprite? sprite;

  HomingSpike({
    this.target,
    required this.speed,
    this.startDelay = 0.0,
    this.sprite,
    Vector2? position,
    Vector2? size,
    Anchor? anchor,
  }) : super(
         position: position ?? Vector2.zero(),
         size: size ?? Vector2.zero(),
         anchor: anchor ?? Anchor.topLeft,
       );

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    if (sprite != null) {
      sprite!.render(canvas, size: size);
    } else {
      final paint = ui.Paint()..color = const ui.Color(0xFF333333);
      canvas.drawRect(ui.Offset.zero & size.toSize(), paint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Use the typed GameApi when available.
    if (gameRef is GameApi) {
      final GameApi gr = gameRef as GameApi;
      if (gr.gameState != GameState.playing) return;
    } else {
      return;
    }

    if (target == null) return;

    if (!_isMoving) {
      _timeSinceSpawn += dt;
      if (_timeSinceSpawn >= startDelay) {
        _isMoving = true;
        // assume caller assigned a valid target (player) with position/size
        _targetX = target.position.x + target.size.x / 2;
      } else {
        return;
      }
    }

    if (_targetX != null) {
      final directionX = (_targetX! - position.x).sign;
      position.x += directionX * speed * dt;

      if ((directionX > 0 && position.x >= _targetX!) ||
          (directionX < 0 && position.x <= _targetX!)) {
        position.x = _targetX!;
        _targetX = null;
      }
    }

    if (toRect().overlaps((target as dynamic).toRect())) {
      final inv = (target as dynamic).invulnerable ?? 0;
      if (inv <= 0) {
        if (gameRef is GameApi) {
          (gameRef as GameApi).onPlayerDied();
        }
        removeFromParent();
      }
    }
  }
}
