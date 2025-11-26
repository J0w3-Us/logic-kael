/// Minimal scene configuration holder for level-driven spike placement.
class SceneConfig {
  /// Desired explicit X positions for spikes (in world coordinates). If
  /// provided, these positions take precedence over `numSpikes`.
  final List<double>? spikePositions;

  /// Fallback number of spikes to generate when `spikePositions` is null.
  final int numSpikes;

  /// Whether the last spike should be a homing spike.
  final bool makeLastHoming;

  const SceneConfig({
    this.spikePositions,
    this.numSpikes = 3,
    this.makeLastHoming = true,
  });

  /// Convenience: build a default config based on canvas width so older
  /// code paths can keep working.
  factory SceneConfig.defaultForCanvas(double canvasWidth) {
    final estimated = (canvasWidth / 240).floor();
    final n = estimated < 3 ? 3 : estimated;
    return SceneConfig(numSpikes: n, makeLastHoming: true);
  }
}

/// Placeholder loader: in the future this can read JSON from assets or a
/// remote service. For now it provides a synchronous default factory.
class SceneLoader {
  static SceneConfig loadForLevel(int level, double canvasWidth) {
    // TODO: load from assets per-level configuration. For now return
    // a default config based on canvas width.
    return SceneConfig.defaultForCanvas(canvasWidth);
  }
}
