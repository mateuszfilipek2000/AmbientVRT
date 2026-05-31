import 'config_reader.dart';

/// Pixel-comparison tuning.
///
/// Mirrors the `compare` definition in `config.schema.json`. All fields are
/// optional; an absent `compare` section in the config yields no
/// [CompareConfig] at all.
class CompareConfig {
  /// Creates a compare config from an optional global [threshold] and any
  /// [perSnapshot] overrides.
  const CompareConfig({this.threshold, this.perSnapshot = const {}});

  /// Reads compare config from a config object via [reader].
  factory CompareConfig.fromReader(ConfigReader reader) {
    reader.rejectUnknownKeys(const {'threshold', 'perSnapshot'});
    return CompareConfig(
      threshold: reader.optionalNumberInRange('threshold', min: 0, max: 1),
      perSnapshot:
          reader.optionalNumberMap('perSnapshot', min: 0, max: 1) ??
          const <String, double>{},
    );
  }

  /// Global pixelmatch threshold (0..1); `null` falls back to the engine
  /// default.
  final double? threshold;

  /// Per-snapshot threshold overrides, keyed by snapshot id.
  final Map<String, double> perSnapshot;

  /// Serializes to a JSON/YAML-encodable map, omitting unset/empty fields.
  Map<String, Object?> toJson() => {
    if (threshold != null) 'threshold': threshold,
    if (perSnapshot.isNotEmpty) 'perSnapshot': {...perSnapshot},
  };

  @override
  bool operator ==(Object other) =>
      other is CompareConfig &&
      other.threshold == threshold &&
      _mapEquals(other.perSnapshot, perSnapshot);

  @override
  int get hashCode => Object.hash(
    threshold,
    Object.hashAllUnordered([
      for (final entry in perSnapshot.entries) Object.hash(entry.key, entry.value),
    ]),
  );

  @override
  String toString() =>
      'CompareConfig(threshold: $threshold, perSnapshot: ${perSnapshot.length})';
}

bool _mapEquals(Map<String, double> a, Map<String, double> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}
