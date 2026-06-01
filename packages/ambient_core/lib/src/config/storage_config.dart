import 'config_reader.dart';
import 'errors.dart';
import 's3_storage_config.dart';

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
/// when [backend] is [StorageBackend.local]; [s3] is required when [backend] is
/// [StorageBackend.s3].
class StorageConfig {
  /// Creates a storage config. [StorageConfig.fromReader] enforces that each
  /// backend supplies the section it needs.
  const StorageConfig({required this.backend, this.path, this.s3});

  /// Reads storage config from a config object via [reader].
  factory StorageConfig.fromReader(ConfigReader reader) {
    reader.rejectUnknownKeys(const {'backend', 'path', 's3'});

    final backend = reader.requireEnum('backend', StorageBackend.byWireName);
    final path = reader.optionalString('path', minLength: 1);

    if (backend == StorageBackend.local && path == null) {
      throw ConfigFormatException(
        reader.childLocation('path'),
        'is required when storage backend is "local"',
      );
    }

    final s3Map = reader.optionalMap('s3');
    if (backend == StorageBackend.s3 && s3Map == null) {
      throw ConfigFormatException(
        reader.childLocation('s3'),
        'is required when storage backend is "s3"',
      );
    }
    final s3 = s3Map == null
        ? null
        : S3StorageConfig.fromReader(
            ConfigReader(s3Map, reader.childLocation('s3')),
          );

    return StorageConfig(backend: backend, path: path, s3: s3);
  }

  /// Which backend stores baselines.
  final StorageBackend backend;

  /// Directory for the local backend's baselines; `null` for other backends.
  final String? path;

  /// Connection settings for the s3 backend; `null` for other backends.
  final S3StorageConfig? s3;

  /// Serializes to a JSON/YAML-encodable map, omitting unset sections.
  Map<String, Object?> toJson() => {
    'backend': backend.wireName,
    if (path != null) 'path': path,
    if (s3 != null) 's3': s3!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is StorageConfig &&
      other.backend == backend &&
      other.path == path &&
      other.s3 == s3;

  @override
  int get hashCode => Object.hash(backend, path, s3);

  @override
  String toString() => 'StorageConfig(backend: ${backend.wireName})';
}
