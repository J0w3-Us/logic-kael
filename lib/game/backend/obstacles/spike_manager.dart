import 'dart:math';
// ignore_for_file: deprecated_member_use
import 'dart:ui' as ui;
import 'package:flame/components.dart';
// Supabase usage disabled for local testing; load levels from local assets
import 'package:flutter/foundation.dart';
import 'spikes.dart';
import '../scene/scene_loader.dart';
import '../game_api.dart';

class SpikeCreateResult {
  final List<Spike> spikes;
  final List<HomingSpike> homingSpikes;
  SpikeCreateResult(this.spikes, this.homingSpikes);
}

/// Creates spike components (static + homing) given the image and pixel data.
SpikeCreateResult createSpikesForScene({
  Sprite? spikeSprite,
  Vector2? spikeNatural,
  Uint8List? spikePixels,
  required double visibleTop,
  required double groundHeight,
  required double canvasWidth,
  SceneConfig? config,
}) {
  final List<Spike> spikes = [];
  final List<HomingSpike> homing = [];
  // Precompute alpha mask for the spike sprite (1 = opaque, 0 = transparent)
  final int imgW = (spikeNatural?.x ?? 32.0).toInt();
  final int imgH = (spikeNatural?.y ?? 32.0).toInt();
  final Uint8List alphaMask = Uint8List(imgW * imgH);
  if (spikePixels != null && spikePixels.length >= imgW * imgH * 4) {
    for (int y = 0; y < imgH; y++) {
      for (int x = 0; x < imgW; x++) {
        final idx = (y * imgW + x) * 4;
        alphaMask[y * imgW + x] = spikePixels[idx + 3] > 10 ? 1 : 0;
      }
    }
  } else {
    // no pixel data: leave alphaMask as all zeros
  }

  final double playerJumpSpeed = 420.0;
  final double playerGravity = 900.0;
  final double maxJump =
      (playerJumpSpeed * playerJumpSpeed) / (2 * playerGravity);
  final double spikeHeight = (min(
    groundHeight * 0.5,
    maxJump * 0.6,
  )).clamp(20.0, groundHeight);
  final double spikeScale = spikeHeight / (spikeNatural?.y ?? imgH.toDouble());
  final double spikeWidth = (spikeNatural?.x ?? imgW.toDouble()) * spikeScale;

  // Decide positions either from explicit config spikePositions, or by
  // spreading `numSpikes` across the canvas width. Keep a margin on both
  // sides so spikes are not flush to edges.
  final margin = canvasWidth * 0.08;
  final usable = (canvasWidth - margin * 2).clamp(0.0, canvasWidth);
  final positions = <double>[];
  final int numSpikes = config?.spikePositions == null
      ? (config?.numSpikes ?? max(3, (canvasWidth / 240).floor()))
      : config!.spikePositions!.length;

  if (config?.spikePositions != null) {
    // Use provided absolute X positions
    positions.addAll(config!.spikePositions!);
  } else {
    if (numSpikes <= 1) {
      positions.add(margin + usable / 2);
    } else {
      for (int i = 0; i < numSpikes; i++) {
        final t = i / (numSpikes - 1);
        positions.add(margin + t * usable);
      }
    }
  }

  for (int i = 0; i < positions.length; i++) {
    final x = positions[i];
    final bool isLast = i == positions.length - 1;
    final bool makeLastHoming = config?.makeLastHoming ?? true;
    if (isLast && makeLastHoming) {
      final hom = HomingSpike(
        target: null, // will be assigned by caller if needed
        speed: 250.0,
        startDelay: 1.5,
        sprite: spikeSprite,
        position: Vector2(x, visibleTop),
        size: Vector2(spikeWidth, spikeHeight),
        anchor: Anchor.bottomCenter,
      );
      homing.add(hom);
    } else {
      final spike = Spike(
        sprite: spikeSprite,
        position: Vector2(x, visibleTop),
        size: Vector2(spikeWidth, spikeHeight),
        anchor: Anchor.bottomCenter,
        pixels: spikePixels,
        alphaMask: alphaMask,
        naturalSize: spikeNatural ?? Vector2(imgW.toDouble(), imgH.toDouble()),
      );
      spikes.add(spike);
    }
  }

  return SpikeCreateResult(spikes, homing);
}

/// Component that can load level/config from Supabase and instantiate spikes.
class SpikeManager extends Component with HasGameRef {
  SpikeManager();

  /// Load level config from Supabase and spawn obstacles.
  /// Falls back to local scene loader if Supabase fails or returns unexpected data.
  Future<void> loadLevelData(int levelId) async {
    // Try to load level data from backend; if it fails or returns an
    // empty list, fallback to local SceneLoader behavior so the game
    // remains playable during network issues.
    try {
      final levelData = await GameApiClient.loadLevelData(levelId);
      final double visibleTop =
          gameRef.size.y - (gameRef as dynamic).groundHeight;
      final double groundHeight = (gameRef as dynamic).groundHeight;
      final double canvasWidth = gameRef.size.x;

      // Prepare spike sprite/pixels as before
      ui.Image? spikeImage;
      Uint8List? spikePixels;
      Vector2? spikeNatural;
      Sprite? spikeSprite;
      try {
        await gameRef.images.load('pinchos.png');
        spikeImage = gameRef.images.fromCache('pinchos.png');
        final bd = await spikeImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        spikePixels = bd?.buffer.asUint8List();
        spikeNatural = Vector2(
          spikeImage.width.toDouble(),
          spikeImage.height.toDouble(),
        );
        spikeSprite = Sprite(spikeImage);
      } catch (_) {
        spikeImage = null;
        spikePixels = null;
        spikeNatural = null;
        spikeSprite = null;
      }

      if (levelData.isNotEmpty) {
        // Interpret each element as a simple obstacle descriptor.
        for (final item in levelData) {
          try {
            if (item is Map<String, dynamic>) {
              final type = (item['type'] ?? '').toString().toLowerCase();
              final x = (item['x'] is num)
                  ? (item['x'] as num).toDouble()
                  : null;
              final w = (item['width'] is num)
                  ? (item['width'] as num).toDouble()
                  : null;
              final h = (item['height'] is num)
                  ? (item['height'] as num).toDouble()
                  : null;

              if ((type == 'spike' ||
                      type == 'pincho' ||
                      type == 'pincho_oculto') &&
                  x != null) {
                final size = Vector2(
                  (w ?? spikeNatural?.x ?? 32.0).toDouble(),
                  (h ?? spikeNatural?.y ?? 32.0).toDouble(),
                );
                final s = Spike(
                  sprite: spikeSprite,
                  position: Vector2(x, visibleTop),
                  size: size,
                  anchor: Anchor.bottomCenter,
                  pixels: spikePixels ?? Uint8List(0),
                  alphaMask: Uint8List(
                    (spikeNatural?.x ?? 32).toInt() *
                        (spikeNatural?.y ?? 32).toInt(),
                  ),
                  naturalSize: spikeNatural ?? Vector2(32, 32),
                );
                gameRef.add(s);
              } else if ((type == 'homing' || type == 'homing_spike') &&
                  x != null) {
                final hs = HomingSpike(
                  target: null,
                  speed: (item['speed'] is num)
                      ? (item['speed'] as num).toDouble()
                      : 250.0,
                  startDelay: (item['startDelay'] is num)
                      ? (item['startDelay'] as num).toDouble()
                      : 1.5,
                  sprite: spikeSprite,
                  position: Vector2(x, visibleTop),
                  size: Vector2(
                    (w ?? spikeNatural?.x ?? 32.0).toDouble(),
                    (h ?? spikeNatural?.y ?? 32.0).toDouble(),
                  ),
                  anchor: Anchor.bottomCenter,
                );
                hs.target = (gameRef as dynamic).player;
                gameRef.add(hs);
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error instantiating obstacle from level data: $e');
          }
        }
        debugPrint('✅ Nivel cargado desde backend (GameApiClient)');
        return;
      }

      // Fallback: use scene builder logic when backend provided no data
      final res = createSpikesForScene(
        spikeSprite: spikeSprite,
        spikeNatural: spikeNatural,
        spikePixels: spikePixels,
        visibleTop: visibleTop,
        groundHeight: groundHeight,
        canvasWidth: canvasWidth,
        config: null,
      );
      for (final s in res.spikes) {
        gameRef.add(s);
      }
      for (final h in res.homingSpikes) {
        h.target = (gameRef as dynamic).player;
        gameRef.add(h);
      }
      debugPrint('✅ Nivel cargado desde SceneLoader (fallback)');
    } catch (e) {
      debugPrint('⚠️ Error en carga de nivel: $e');
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // If runner_game doesn't call loadLevelData explicitly, ensure we still
    // attempt to load the level config from backend here.
    await loadLevelData(1);
  }
}
