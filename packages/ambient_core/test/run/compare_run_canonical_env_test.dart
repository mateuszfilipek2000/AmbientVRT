import 'dart:io';
import 'dart:typed_data';

import 'package:ambient_core/ambient_core.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  group('compareRun canonical-env enforcement', () {
    late Directory runDirectory;
    late Directory storageDirectory;
    late LocalStorageBackend storage;

    setUp(() async {
      runDirectory = await Directory.systemTemp.createTemp(
        'ambient-canonical-env-run-',
      );
      storageDirectory = await Directory.systemTemp.createTemp(
        'ambient-canonical-env-storage-',
      );
      storage = LocalStorageBackend(directoryPath: storageDirectory.path);
    });

    tearDown(() async {
      if (await runDirectory.exists()) {
        await runDirectory.delete(recursive: true);
      }
      if (await storageDirectory.exists()) {
        await storageDirectory.delete(recursive: true);
      }
    });

    test('no canonicalEnv configured means nothing is flagged', () async {
      final manifest = await _writeManifest(runDirectory, [
        _entry(id: 'a', envFingerprint: 'whatever'),
        _entry(id: 'b', envFingerprint: 'something-else'),
      ]);

      final result = await compareRun(
        manifest: manifest,
        storage: storage,
        options: CompareRunOptions(runDirectoryPath: runDirectory.path),
      );

      expect(result.canonicalEnv, isNull);
      expect(result.hasNonCanonicalCaptures, isFalse);
      expect(result.nonCanonicalCaptures, isEmpty);
      expect(
        result.snapshots.map((s) => s.isCanonicalEnv),
        everyElement(isTrue),
      );
    });

    test('captures matching the canonical env are not flagged', () async {
      const canonical = 'ambient/capture-env@sha256:cafef00d';
      final manifest = await _writeManifest(runDirectory, [
        _entry(id: 'a', envFingerprint: canonical),
        _entry(id: 'b', envFingerprint: canonical),
      ]);

      final result = await compareRun(
        manifest: manifest,
        storage: storage,
        options: CompareRunOptions(
          runDirectoryPath: runDirectory.path,
          canonicalEnv: canonical,
        ),
      );

      expect(result.canonicalEnv, canonical);
      expect(result.hasNonCanonicalCaptures, isFalse);
      expect(result.nonCanonicalCaptures, isEmpty);
    });

    test('a non-canonical fingerprint is flagged in the run result', () async {
      const canonical = 'ambient/capture-env@sha256:cafef00d';
      final manifest = await _writeManifest(runDirectory, [
        _entry(id: 'canonical-one', envFingerprint: canonical),
        _entry(id: 'rogue', envFingerprint: 'flutter:3.44.0|local-laptop'),
      ]);

      final result = await compareRun(
        manifest: manifest,
        storage: storage,
        options: CompareRunOptions(
          runDirectoryPath: runDirectory.path,
          canonicalEnv: canonical,
        ),
      );

      expect(result.hasNonCanonicalCaptures, isTrue);
      expect(
        result.nonCanonicalCaptures.map((s) => s.id),
        equals(['rogue']),
      );
      // The flag is non-blocking: it does not change verdicts (these are new).
      expect(result.summary.hasBlockingChanges, isFalse);
    });
  });
}

Future<Manifest> _writeManifest(
  Directory runDirectory,
  List<_Fixture> fixtures,
) async {
  final entries = <ManifestEntry>[];
  for (final fixture in fixtures) {
    final bytes = _solidPng();
    final file = File.fromUri(runDirectory.uri.resolve(fixture.relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    entries.add(
      ManifestEntry(
        id: fixture.id,
        platform: Platform.flutter,
        width: 2,
        height: 2,
        dpr: 1,
        contentHash: sha256.convert(bytes).toString(),
        envFingerprint: fixture.envFingerprint,
        imagePath: fixture.relativePath,
      ),
    );
  }
  return Manifest(manifestVersion: const ManifestVersion(1, 0), entries: entries);
}

_Fixture _entry({required String id, required String envFingerprint}) =>
    _Fixture(
      id: id,
      relativePath: 'captures/$id.png',
      envFingerprint: envFingerprint,
    );

Uint8List _solidPng() {
  final image = img.Image(width: 2, height: 2, numChannels: 4);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, 10, 20, 30, 255);
    }
  }
  return img.PngEncoder().encode(image);
}

class _Fixture {
  const _Fixture({
    required this.id,
    required this.relativePath,
    required this.envFingerprint,
  });

  final String id;
  final String relativePath;
  final String envFingerprint;
}
