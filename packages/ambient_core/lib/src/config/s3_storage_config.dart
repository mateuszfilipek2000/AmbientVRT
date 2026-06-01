import 'config_reader.dart';

/// Connection settings for the S3-compatible storage backend.
///
/// Mirrors the `storage.s3` definition in `config.schema.json`. Credentials are
/// intentionally *not* part of this model: they are read at runtime from the
/// environment variables named by [accessKeyEnv]/[secretKeyEnv], so secrets
/// never live in a checked-in config file.
class S3StorageConfig {
  /// Creates an S3 storage config.
  const S3StorageConfig({
    required this.endpoint,
    required this.bucket,
    this.port,
    this.useSSL = true,
    this.region,
    this.prefix,
    this.pathStyle,
    this.accessKeyEnv = defaultAccessKeyEnv,
    this.secretKeyEnv = defaultSecretKeyEnv,
  });

  /// Reads S3 config from a config object via [reader].
  factory S3StorageConfig.fromReader(ConfigReader reader) {
    reader.rejectUnknownKeys(const {
      'endpoint',
      'bucket',
      'port',
      'useSSL',
      'region',
      'prefix',
      'pathStyle',
      'accessKeyEnv',
      'secretKeyEnv',
    });

    return S3StorageConfig(
      endpoint: reader.requireString('endpoint', minLength: 1),
      bucket: reader.requireString('bucket', minLength: 1),
      port: reader.optionalInt('port', min: 1, max: 65535),
      useSSL: reader.optionalBool('useSSL') ?? true,
      region: reader.optionalString('region', minLength: 1),
      prefix: reader.optionalString('prefix', minLength: 1),
      pathStyle: reader.optionalBool('pathStyle'),
      accessKeyEnv:
          reader.optionalString('accessKeyEnv', minLength: 1) ??
          defaultAccessKeyEnv,
      secretKeyEnv:
          reader.optionalString('secretKeyEnv', minLength: 1) ??
          defaultSecretKeyEnv,
    );
  }

  /// Default env var the access key is read from.
  static const String defaultAccessKeyEnv = 'AMBIENT_S3_ACCESS_KEY';

  /// Default env var the secret key is read from.
  static const String defaultSecretKeyEnv = 'AMBIENT_S3_SECRET_KEY';

  /// Host name or IP of the S3 endpoint (e.g. `minio.lan`, `s3.amazonaws.com`).
  final String endpoint;

  /// Bucket baselines are stored in.
  final String bucket;

  /// TCP port; `null` lets the client imply it from [useSSL] (443/80).
  final int? port;

  /// Whether to connect over HTTPS. Defaults to `true`.
  final bool useSSL;

  /// Optional region override (e.g. `us-east-1`).
  final String? region;

  /// Optional key prefix rooting every object under a bucket sub-path.
  final String? prefix;

  /// Force path-style addressing; `null` lets the client decide (path style is
  /// used automatically for non-AWS endpoints like MinIO).
  final bool? pathStyle;

  /// Name of the environment variable holding the access key.
  final String accessKeyEnv;

  /// Name of the environment variable holding the secret key.
  final String secretKeyEnv;

  /// Serializes to a JSON/YAML-encodable map, omitting unset fields.
  Map<String, Object?> toJson() => {
    'endpoint': endpoint,
    'bucket': bucket,
    if (port != null) 'port': port,
    'useSSL': useSSL,
    if (region != null) 'region': region,
    if (prefix != null) 'prefix': prefix,
    if (pathStyle != null) 'pathStyle': pathStyle,
    if (accessKeyEnv != defaultAccessKeyEnv) 'accessKeyEnv': accessKeyEnv,
    if (secretKeyEnv != defaultSecretKeyEnv) 'secretKeyEnv': secretKeyEnv,
  };

  @override
  bool operator ==(Object other) =>
      other is S3StorageConfig &&
      other.endpoint == endpoint &&
      other.bucket == bucket &&
      other.port == port &&
      other.useSSL == useSSL &&
      other.region == region &&
      other.prefix == prefix &&
      other.pathStyle == pathStyle &&
      other.accessKeyEnv == accessKeyEnv &&
      other.secretKeyEnv == secretKeyEnv;

  @override
  int get hashCode => Object.hash(
    endpoint,
    bucket,
    port,
    useSSL,
    region,
    prefix,
    pathStyle,
    accessKeyEnv,
    secretKeyEnv,
  );

  @override
  String toString() =>
      'S3StorageConfig(endpoint: $endpoint, bucket: $bucket, '
      'useSSL: $useSSL)';
}
