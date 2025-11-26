// ignore_for_file: deprecated_member_use
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
// sprite elements are available via components.dart
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
// flutter material not required in this component
import 'movement_behavior.dart';
import 'jump_behavior.dart';
import '../game_api.dart';
import '../obstacles/spikes.dart';
// dart:math not required here

/// Player component moved to its own file. Uses dynamic access to gameRef
/// to avoid circular imports with RunnerGame.
enum PlayerState { idle, run, jumping, hit }

/// Player implemented as a SpriteAnimationGroupComponent using the provided
/// Kaelen sprite sheet (72x64 tiles). Integrates MovementBehavior and
/// JumpBehavior and notifies the game on death via `onPlayerDied`.
class Player extends SpriteAnimationGroupComponent<PlayerState>
    with HasGameRef, CollisionCallbacks {
  Vector2 velocity = Vector2.zero();
  bool moveLeft = false;
  bool moveRight = false;
  double invulnerable = 0.0;

  late final MovementBehavior movement;
  late final JumpBehavior jumpBehavior;
  bool _hasAnimations = false;

  // Sprite tile size (pixels)
  static final Vector2 _frameSize = Vector2(72.0, 64.0);

  Player({Vector2? position, Vector2? size})
    : super(
        position: position ?? Vector2.zero(),
        size: size ?? Vector2(_frameSize.x, _frameSize.y),
      );

  Future<SpriteAnimation> _createAnim(
    ui.Image image,
    Vector2 texturePosition,
    int amount,
    double stepTime, {
    bool loop = true,
  }) async {
    final data = SpriteAnimationData.sequenced(
      amount: amount,
      stepTime: stepTime,
      textureSize: _frameSize,
      texturePosition: texturePosition,
      loop: loop,
    );
    return SpriteAnimation.fromFrameData(image, data);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.topLeft;
    movement = MovementBehavior(velocity);
    jumpBehavior = JumpBehavior(velocity);

    // Load the sprite sheet image. Prefer the exact path declared in
    // `pubspec.yaml` via `rootBundle` (avoids Flame's `assets/images/`
    // prefix confusion). If that fails, try a couple of Flame image keys.
    ui.Image? image;
    try {
      final bd = await rootBundle.load('assets/snippet/Kaelen.png');
      final bytes = bd.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      // ignore: avoid_print
      print(
        'Kaelen sprite loaded via rootBundle: ${image.width}x${image.height}',
      );
    } catch (_) {
      // rootBundle load failed — try Flame's Images with safe keys.
      final candidates = <String>['snippet/Kaelen.png', 'Kaelen.png'];
      for (final key in candidates) {
        try {
          image = await gameRef.images.load(key);
          // ignore: avoid_print
          print(
            'Kaelen sprite loaded via Images.load with key: $key -> ${image.width}x${image.height}',
          );
          break;
        } catch (_) {
          // try the next key
        }
      }
    }

    if (image == null) {
      // If we still couldn't load the image, log a clear error and continue
      // without animations. We'll mark `_hasAnimations` false so update()
      // doesn't attempt to switch animation keys (which would assert).
      // ignore: avoid_print
      print(
        '❌ Kaelen sprite could not be loaded. Checked: assets/snippet/Kaelen.png, snippet/Kaelen.png, Kaelen.png',
      );
      animations = <PlayerState, SpriteAnimation>{};
      _hasAnimations = false;
      add(RectangleHitbox());
      priority = 10;
      return;
    }

    // Build animations into a local mutable map to avoid modifying an
    // unmodifiable map returned/used by the base class.
    final Map<PlayerState, SpriteAnimation> newAnims =
        <PlayerState, SpriteAnimation>{};
    try {
      newAnims[PlayerState.idle] = await _createAnim(
        image,
        Vector2(0, 0), // row 0
        13,
        0.1,
        loop: true,
      );

      // Run: row 2 -> y = 128
      newAnims[PlayerState.run] = await _createAnim(
        image,
        Vector2(0, 128),
        10,
        0.08,
        loop: true,
      );

      // Jump: row 3 -> y = 192
      newAnims[PlayerState.jumping] = await _createAnim(
        image,
        Vector2(0, 192),
        13,
        0.08,
        loop: true,
      );

      // Hit / Death: row 5 -> y = 320, no loop
      newAnims[PlayerState.hit] = await _createAnim(
        image,
        Vector2(0, 320),
        10,
        0.1,
        loop: false,
      );

      // Assign the prepared mutable map to the component in one step.
      animations = newAnims;
      _hasAnimations = true;
      // Set the initial animation state now that animations exist.
      current = PlayerState.idle;
    } catch (e) {
      // If animation creation fails, fall back to no-animations mode.
      // ignore: avoid_print
      print('❌ Failed to create Player animations: $e');
      animations = <PlayerState, SpriteAnimation>{};
      _hasAnimations = false;
      add(RectangleHitbox());
      priority = 10;
      return;
    }

    // Add a rectangle hitbox for collisions
    add(RectangleHitbox());

    // Ensure the component is rendered above ground by giving it a higher
    // priority. Do not override if another system sets priority explicitly.
    priority = 10;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final GameApi gr = gameRef as GameApi;

    final isPlaying = gr.gameState == GameState.playing;
    if (!isPlaying) {
      // Stop horizontal inputs while not playing but continue to run
      // animation-state logic so the intro idle animation is visible.
      movement.moveLeft = false;
      movement.moveRight = false;
      movement.updateHorizontal(dt);
    } else {
      movement.moveLeft = moveLeft;
      movement.moveRight = moveRight;
      movement.updateHorizontal(dt);
    }

    final double groundY = gr.size.y - gr.groundHeight;
    jumpBehavior.updateVertical(dt, this, groundY);

    position += velocity * dt;

    if (position.x < 0) {
      position.x = 0;
      if (velocity.x < 0) velocity.x = 0;
    }
    final double gameW = gr.size.x;
    if (position.x + size.x > gameW) {
      position.x = gameW - size.x;
      if (velocity.x > 0) velocity.x = 0;
    }

    if (invulnerable > 0) {
      invulnerable -= dt;
      if (invulnerable < 0) invulnerable = 0;
    }

    // If currently in hit state, keep it until external reset
    if (current == PlayerState.hit) return;

    // Update visual state according to velocity. Only switch `current` if
    // animations were successfully created and the desired key exists.
    PlayerState desired;
    if (velocity.y < 0) {
      desired = PlayerState.jumping;
    } else if (velocity.x.abs() > 20) {
      desired = PlayerState.run;
    } else {
      desired = PlayerState.idle;
    }

    if (_hasAnimations &&
        animations != null &&
        animations!.containsKey(desired)) {
      current = desired;
    }
  }

  void pressJump() => jumpBehavior.pressJump();
  void releaseJump() => jumpBehavior.releaseJump();
  void jump() => pressJump();

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Spike || other is HomingSpike) {
      // mark hit animation and notify game. Only set `current` if animations
      // were loaded to avoid assertion from the base class.
      if (_hasAnimations &&
          animations != null &&
          animations!.containsKey(PlayerState.hit)) {
        current = PlayerState.hit;
      }
      if (gameRef is GameApi) {
        (gameRef as GameApi).onPlayerDied();
      }
    }
  }
}
