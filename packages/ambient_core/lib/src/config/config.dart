import 'package:yaml/yaml.dart';

import 'adapter.dart';
import 'compare_config.dart';
import 'config_reader.dart';
import 'errors.dart';
import 'storage_config.dart';

/// A parsed `ambient.config.yaml`: the user-authored configuration declaring
/// adapters, baseline storage, compare thresholds, variants, and the canonical
/// capture environment.
///
/// See `schemas/config.schema.json` and `docs/contracts.md`.
class Config {
  /// Creates a config from its sections. [Config.fromYaml] enforces the schema
  /// when parsing user input.
  const Config({
    required this.adapters,
    required this.storage,
    this.compare,
    this.variants = const [],
    this.canonicalEnv,
  });

  /// Parses a config from a YAML (or JSON, a YAML subset) source string.
  ///
  /// Throws [ConfigFormatException] for malformed input or a schema violation,
  /// always pointing at the offending field.
  factory Config.fromYamlString(String source) {
    final Object? decoded;
    try {
      decoded = loadYaml(source);
    } on YamlException catch (e) {
      throw ConfigFormatException('', 'is not valid YAML: ${e.message}');
    }
    return Config.fromYaml(_normalizeYaml(decoded));
  }

  /// Builds a config from already-decoded data (plain maps/lists/scalars).
  ///
  /// Throws [ConfigFormatException] if [data] violates the schema.
  factory Config.fromYaml(Object? data) {
    if (data is! Map) {
      throw ConfigFormatException(
        '',
        'expected the config root to be an object, got ${configTypeName(data)}',
      );
    }
    final root = ConfigReader(data.cast<String, Object?>(), '');
    root.rejectUnknownKeys(const {
      'adapters',
      'storage',
      'compare',
      'variants',
      'canonicalEnv',
    });

    final rawAdapters = root.requireList('adapters', minItems: 1);
    final adapters = <Adapter>[];
    for (var i = 0; i < rawAdapters.length; i++) {
      final item = rawAdapters[i];
      final location = 'adapters[$i]';
      if (item is! Map) {
        throw ConfigFormatException(
          location,
          'expected an object, got ${configTypeName(item)}',
        );
      }
      adapters.add(
        Adapter.fromReader(ConfigReader(item.cast<String, Object?>(), location)),
      );
    }

    final storage = StorageConfig.fromReader(
      ConfigReader(root.requireMap('storage'), root.childLocation('storage')),
    );

    final compareMap = root.optionalMap('compare');
    final compare = compareMap == null
        ? null
        : CompareConfig.fromReader(
            ConfigReader(compareMap, root.childLocation('compare')),
          );

    final variants =
        root.optionalStringList('variants', minItemLength: 1, unique: true) ??
        const <String>[];

    final canonicalEnv = root.optionalString('canonicalEnv', minLength: 1);

    return Config(
      adapters: adapters,
      storage: storage,
      compare: compare,
      variants: variants,
      canonicalEnv: canonicalEnv,
    );
  }

  /// One or more capture adapters to run (at least one).
  final List<Adapter> adapters;

  /// Where baselines live.
  final StorageConfig storage;

  /// Pixel comparison tuning, or `null` when the config omits it.
  final CompareConfig? compare;

  /// Variant names the adapters should produce captures for (e.g. light,
  /// dark). Empty when the config omits them.
  final List<String> variants;

  /// Reference to the canonical capture-env image; `null` when unset.
  final String? canonicalEnv;

  /// Serializes to a JSON/YAML-encodable map, omitting unset/empty sections.
  Map<String, Object?> toJson() => {
    'adapters': [for (final adapter in adapters) adapter.toJson()],
    'storage': storage.toJson(),
    if (compare != null) 'compare': compare!.toJson(),
    if (variants.isNotEmpty) 'variants': [...variants],
    if (canonicalEnv != null) 'canonicalEnv': canonicalEnv,
  };

  @override
  bool operator ==(Object other) =>
      other is Config &&
      _listEquals(other.adapters, adapters) &&
      other.storage == storage &&
      other.compare == compare &&
      _listEquals(other.variants, variants) &&
      other.canonicalEnv == canonicalEnv;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(adapters),
    storage,
    compare,
    Object.hashAll(variants),
    canonicalEnv,
  );

  @override
  String toString() =>
      'Config(adapters: ${adapters.length}, storage: ${storage.backend.wireName})';
}

/// Recursively converts the `yaml` package's [YamlMap]/[YamlList] nodes into
/// plain Dart `Map<String, Object?>`/`List<Object?>`/scalars, so the rest of
/// the parser works against the same shape as decoded JSON.
Object? _normalizeYaml(Object? node) {
  if (node is YamlMap) {
    final result = <String, Object?>{};
    for (final entry in node.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ConfigFormatException(
          '',
          'mapping keys must be strings, got ${configTypeName(key)}',
        );
      }
      result[key] = _normalizeYaml(entry.value);
    }
    return result;
  }
  if (node is YamlList) {
    return [for (final item in node) _normalizeYaml(item)];
  }
  return node;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
