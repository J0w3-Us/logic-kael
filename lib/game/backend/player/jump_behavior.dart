import 'dart:math' as math;
import 'package:flame/components.dart';

/// Lógica de salto: gravedad variable, coyote time y jump buffer.
/// Trabaja sobre la `velocity` compartida por el Player.
class JumpBehavior {
  final Vector2 velocity;

  // Parámetros ajustables
  final double gravity;
  final double jumpSpeed;
  final double shortHopMultiplier;
  final double coyoteTimeMax;
  final double jumpBufferMax;

  // Estados internos
  double _coyoteTimer = 0.0;
  double _jumpBufferTimer = 0.0;
  // Note: we no longer use a "hold to jump" mechanic. Jumps are single-click.

  JumpBehavior(
    this.velocity, {
    this.gravity = 900,
    this.jumpSpeed = -420,
    this.shortHopMultiplier = 0.5,
    this.coyoteTimeMax = 0.12,
    this.jumpBufferMax = 0.12,
  });

  void pressJump() {
    // Backwards-compatible: pressing still buffers the jump if called
    // without context. Prefer calling `attemptJump(owner, groundY)` to
    // make the jump happen immediately when possible.
    _jumpBufferTimer = jumpBufferMax;
  }

  void releaseJump() {
    // No-op for single-click jump behavior (disable hold-to-jump).
  }

  /// Try to make the player jump immediately if on ground or within coyote time.
  /// If not possible, buffer the jump so it triggers when the player lands.
  void attemptJump(PositionComponent owner, double groundY) {
    final bool onGround = owner.position.y + owner.size.y >= groundY;
    if (onGround || _coyoteTimer > 0) {
      velocity.y = jumpSpeed;
      _jumpBufferTimer = 0.0;
      _coyoteTimer = 0.0;
    } else {
      _jumpBufferTimer = jumpBufferMax;
    }
  }

  /// Update vertical: modifica velocity.y y gestiona timers.
  /// `owner` y `groundY` se pasan desde Player para detectar suelo.
  void updateVertical(double dt, PositionComponent owner, double groundY) {
    // aplicar gravedad variable (más clara y con llaves)
    // Always apply the same gravity; no hold-to-extend-jump behaviour.
    velocity.y += gravity * dt;

    // NOTA: no movemos owner.position aquí; Player hará position += velocity * dt

    // comprobar contacto con suelo
    if (owner.position.y + owner.size.y >= groundY) {
      owner.position.y = groundY - owner.size.y;
      velocity.y = 0;
      _coyoteTimer = coyoteTimeMax;
    }

    // evitar que los timers queden negativos
    if (_coyoteTimer > 0) {
      _coyoteTimer = math.max(0.0, _coyoteTimer - dt);
    }
    if (_jumpBufferTimer > 0) {
      _jumpBufferTimer = math.max(0.0, _jumpBufferTimer - dt);
    }

    if (_jumpBufferTimer > 0 && _coyoteTimer > 0) {
      // execute buffered jump
      velocity.y = jumpSpeed;
      _jumpBufferTimer = 0.0;
      _coyoteTimer = 0.0;
    }
  }
}
