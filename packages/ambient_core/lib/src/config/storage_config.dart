import 'config_reader.dart';
import 'errors.dart';

/// Where baselines are stored.
///
/// Wire values match `config.schema.json`'s `storage.backend` enum exactly.
enum StorageBackend {
  /// Baselines on the local filesystem under [StorageConfig.path].
  local('local'),

  /// Baselines in an S3-compatible object store.
  s3('s3');

  const StorageBackend(this.wireName);

  /// The string form used in the config (e.g. `local`).
  final String wireName;

  /// Lookup table from [wireName] to the enum value, for deserialization.
  static final Map<String, StorageBackend> byWireName = {
    for (final backend in StorageBackend.values) backend.wireName: backend,
  };
}

/// Baseline storage configuration.
///
/// Mirrors the `storage` definition in `config.schema.json`. [path] is required
/// when [backend] is [StorageBackend.local].
class StorageConfig {
  /// Creates a storage config. [StorageConfig.fromReader] enforces that a
  /// local backend supplies a [path].
  const StorageConfig({required this.backend, this.path});

  /// Reads storage config from a config object via [reader].
  factory StorageConfig.fromReader(ConfigReader reader) {
    reader.rejectUnknownKeys(const {'backend', 'path'});

    final backend = reader.requireEnum('backend', StorageBackend.byWireName);
    final path = reader.optionalString('path', minLength: 1);

    if (backend == StorageBackend.local && path == null) {
      throw ConfigFormatException(
        reader.childLocation('path'),
        'is required when storage backend is "local"',
      );
    }

    return StorageConfig(backend: backend, path: path);
  }

  /// Which backend stores baselines.
  final StorageBackend backend;

  /// Directory for the local backend's baselines; `null` for other backends.
  final String? path;

  /// Serializes to a JSON/YAML-encodable map, omitting an unset [path].
  Map<String, Object?> toJson() => {
    'backend': backend.wireName,
    if (path != null) 'path': path,
  };

  @override
  bool operator ==(Object other) =>
      other is StorageConfig && other.backend == backend && other.path == path;

  @override
  int get hashCode => Object.hash(backend, path);

  @override
  String toString() => 'StorageConfig(backend: ${backend.wireName})';
}
