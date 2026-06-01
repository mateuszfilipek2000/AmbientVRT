@TestOn('vm')
library;

import 'dart:io' as io;

import 'package:ambient_core/ambient_core.dart';
import 'package:minio/minio.dart' as minio;
import 'package:test/test.dart';

import 'baseline_storage_contract.dart';

/// Runs the shared backend contract suite against a live S3-compatible store
/// (MinIO). It is skipped unless `AMBIENT_S3_TEST_ENDPOINT` (and credentials)
/// are set, so `dart test` stays green without a server; CI provisions a MinIO
/// service container and supplies these variables (backlog T6.3).
void main() {
  final settings = _S3TestSettings.fromEnvironment();
  if (settings == null) {
    test(
      'S3StorageBackend contract',
      () {},
      skip:
          'Set AMBIENT_S3_TEST_ENDPOINT, AMBIENT_S3_TEST_ACCESS_KEY, '
          'AMBIENT_S3_TEST_SECRET_KEY and AMBIENT_S3_TEST_BUCKET to run the '
          'S3 backend contract tests against MinIO.',
    );
    return;
  }

  final client = minio.Minio(
    endPoint: settings.endpoint,
    port: settings.port,
    useSSL: settings.useSSL,
    accessKey: settings.accessKey,
    secretKey: settings.secretKey,
    region: settings.region,
  );

  var counter = 0;
  String? activePrefix;

  setUpAll(() async {
    if (!await client.bucketExists(settings.bucket)) {
      await client.makeBucket(settings.bucket, settings.region);
    }
  });

  defineBaselineStorageContractTests(
    name: 'S3StorageBackend',
    createStorage: () async {
      // A fresh key prefix per test isolates the (shared) bucket between cases.
      activePrefix =
          'ambient-contract-test/'
          '${DateTime.now().microsecondsSinceEpoch}-${counter++}/';
      return S3StorageBackend(
        client: client,
        bucket: settings.bucket,
        keyPrefix: activePrefix,
      );
    },
    cleanup: () async {
      final prefix = activePrefix;
      if (prefix == null) {
        return;
      }
      final listed = await client.listAllObjects(
        settings.bucket,
        prefix: prefix,
        recursive: true,
      );
      final keys = [
        for (final object in listed.objects)
          if (object.key != null) object.key!,
      ];
      if (keys.isNotEmpty) {
        await client.removeObjects(settings.bucket, keys);
      }
    },
  );
}

class _S3TestSettings {
  _S3TestSettings({
    required this.endpoint,
    required this.bucket,
    required this.accessKey,
    required this.secretKey,
    this.port,
    this.useSSL = false,
    this.region,
  });

  static _S3TestSettings? fromEnvironment() {
    final env = io.Platform.environment;
    final endpoint = env['AMBIENT_S3_TEST_ENDPOINT'];
    final accessKey = env['AMBIENT_S3_TEST_ACCESS_KEY'];
    final secretKey = env['AMBIENT_S3_TEST_SECRET_KEY'];
    final bucket = env['AMBIENT_S3_TEST_BUCKET'];
    if (endpoint == null ||
        accessKey == null ||
        secretKey == null ||
        bucket == null) {
      return null;
    }

    final port = env['AMBIENT_S3_TEST_PORT'];
    return _S3TestSettings(
      endpoint: endpoint,
      bucket: bucket,
      accessKey: accessKey,
      secretKey: secretKey,
      port: port == null ? null : int.parse(port),
      useSSL: env['AMBIENT_S3_TEST_USE_SSL'] == 'true',
      region: env['AMBIENT_S3_TEST_REGION'],
    );
  }

  final String endpoint;
  final String bucket;
  final String accessKey;
  final String secretKey;
  final int? port;
  final bool useSSL;
  final String? region;
}
