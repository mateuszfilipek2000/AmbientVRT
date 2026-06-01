import 'dart:convert';
import 'dart:typed_data';

import 'package:minio/minio.dart' as minio;

import '../manifest/manifest.dart';
import 'baseline_storage.dart';

/// S3-compatible [BaselineStorage] backed by any AWS-S3-API object store.
///
/// Validated against MinIO via the shared backend contract suite (backlog
/// T6.3). The on-bucket key layout mirrors [LocalStorageBackend]'s directory
/// layout so the two backends behave identically:
///
/// - root namespace (the default branch, or no branch): `<prefix><id>.png`
/// - other branches: `<prefix>branches/<branch>/<id>.png`
/// - accepted-manifest sidecar: `<prefix>[branches/<branch>/].accepted-manifest.json`
///
/// `<id>` and `<branch>` are percent-encoded so a snapshot id's own slashes
/// never create extra key segments; that keeps a non-recursive list of a
/// namespace returning exactly its own baselines and nothing from nested
/// branch namespaces.
final class S3StorageBackend implements BaselineStorage {
  /// Wraps an already-configured [client] targeting [bucket].
  ///
  /// [keyPrefix] optionally roots every key under a sub-path of the bucket.
  /// [defaultBranch], when set, is stored in the root namespace rather than a
  /// `branches/` sub-path, matching [LocalStorageBackend].
  S3StorageBackend({
    required minio.Minio client,
    required String bucket,
    String? keyPrefix,
    String? defaultBranch,
  }) : _client = client,
       _bucket = bucket,
       _keyPrefix = _normalizePrefix(keyPrefix),
       _defaultBranch = _normalizeBranch(defaultBranch);
  // ignore_for_file: prefer_initializing_formals — `client`/`bucket` are passed
  // through unchanged, but keeping them as named params (not `this._client`)
  // keeps the public constructor's parameter list readable alongside the
  // normalized `keyPrefix`/`defaultBranch`.

  /// Builds a backend by constructing the underlying [minio.Minio] client from
  /// connection settings and credentials.
  factory S3StorageBackend.connect({
    required String endpoint,
    required String accessKey,
    required String secretKey,
    required String bucket,
    int? port,
    bool useSSL = true,
    String? region,
    bool? pathStyle,
    String? sessionToken,
    String? keyPrefix,
    String? defaultBranch,
  }) {
    return S3StorageBackend(
      client: minio.Minio(
        endPoint: endpoint,
        port: port,
        useSSL: useSSL,
        accessKey: accessKey,
        secretKey: secretKey,
        region: region,
        pathStyle: pathStyle,
        sessionToken: sessionToken,
      ),
      bucket: bucket,
      keyPrefix: keyPrefix,
      defaultBranch: defaultBranch,
    );
  }

  final minio.Minio _client;
  final String _bucket;
  final String _keyPrefix;
  final String? _defaultBranch;

  /// Creates the target bucket if it does not already exist.
  ///
  /// Callers must ensure the bucket exists before the first write; the CLI
  /// expects it provisioned out of band, but tests and tooling can call this.
  Future<void> ensureBucket() async {
    if (await _client.bucketExists(_bucket)) {
      return;
    }
    await _client.makeBucket(_bucket, _client.region);
  }

  @override
  Future<Uint8List?> getBaseline(String id, {String? branch}) =>
      _getBytes(_keyForId(id, branch: branch));

  @override
  Future<void> putBaseline(
    String id,
    Uint8List pngBytes, {
    String? branch,
  }) => _putBytes(_keyForId(id, branch: branch), pngBytes);

  @override
  Future<List<String>> listBaselines({String? branch}) async {
    final prefix = _prefixForBranch(branch);
    final result = await _client.listAllObjects(
      _bucket,
      prefix: prefix,
      // Non-recursive so nested branch namespaces surface as common prefixes
      // (excluded) rather than as objects in this namespace's listing.
      recursive: false,
    );

    final ids = <String>[];
    for (final object in result.objects) {
      final key = object.key;
      if (key == null || !key.startsWith(prefix)) {
        continue;
      }
      final name = key.substring(prefix.length);
      // Skip anything that is not a direct `<id>.png` child of this namespace.
      if (name.contains('/') || !name.endsWith(_baselineExtension)) {
        continue;
      }
      final encodedId = name.substring(
        0,
        name.length - _baselineExtension.length,
      );
      ids.add(Uri.decodeComponent(encodedId));
    }

    ids.sort();
    return ids;
  }

  @override
  Future<Manifest?> getAcceptedManifest({String? branch}) async {
    final bytes = await _getBytes(_acceptedManifestKey(branch: branch));
    if (bytes == null) {
      return null;
    }
    return Manifest.fromJsonString(utf8.decode(bytes));
  }

  @override
  Future<void> putAcceptedManifest(Manifest manifest, {String? branch}) {
    final bytes = Uint8List.fromList(utf8.encode(manifest.toJsonString()));
    return _putBytes(_acceptedManifestKey(branch: branch), bytes);
  }

  Future<Uint8List?> _getBytes(String key) async {
    try {
      final stream = await _client.getObject(_bucket, key);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } on minio.MinioS3Error catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> _putBytes(String key, Uint8List bytes) async {
    await _client.putObject(
      _bucket,
      key,
      Stream<Uint8List>.value(bytes),
      size: bytes.length,
    );
  }

  String _keyForId(String id, {String? branch}) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Baseline ID must not be empty.');
    }
    return '${_prefixForBranch(branch)}'
        '${Uri.encodeComponent(id)}$_baselineExtension';
  }

  String _acceptedManifestKey({String? branch}) =>
      '${_prefixForBranch(branch)}$_acceptedManifestFileName';

  String _prefixForBranch(String? branch) {
    final normalizedBranch = _normalizeBranch(branch);
    if (normalizedBranch == null || normalizedBranch == _defaultBranch) {
      return _keyPrefix;
    }
    return '${_keyPrefix}branches/${Uri.encodeComponent(normalizedBranch)}/';
  }
}

String? _normalizeBranch(String? branch) {
  if (branch == null) {
    return null;
  }
  final trimmed = branch.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _normalizePrefix(String? prefix) {
  if (prefix == null) {
    return '';
  }
  var normalized = prefix.trim();
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized.isEmpty) {
    return '';
  }
  return normalized.endsWith('/') ? normalized : '$normalized/';
}

const String _baselineExtension = '.png';
const String _acceptedManifestFileName = '.accepted-manifest.json';
