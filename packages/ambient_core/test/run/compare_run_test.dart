import 'dart:io';
import 'dart:typed_data';

import 'package:ambient_core/ambient_core.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  group('compareRun', () {
    late Directory runDirectory;
    late Directory storageDirectory;
    late LocalStorageBackend storage;

    setUp(() async {
      runDirectory = await Directory.systemTemp.createTemp(
        'ambient-compare-run-fixtures-',
      );
      storageDirectory = await Directory.systemTemp.createTemp(
        'ambient-compare-run-storage-',
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

    test(
      'first run with no baselines records all snapshots as new and succeeds',
      () async {
        final manifest = await _writeManifest(
          runDirectory,
          entries: [
            _capture(
              id: 'button-primary',
              relativePath: 'captures/button-primary.png',
              pngBytes: _solidPng(
                width: 3,
                height: 2,
                red: 20,
                green: 40,
                blue: 60,
              ),
            ),
            _capture(
              id: 'button-secondary',
              relativePath: 'captures/button-secondary.png',
              pngBytes: _solidPng(
                width: 2,
                height: 2,
                red: 200,
                green: 180,
                blue: 20,
              ),
            ),
          ],
        );

        final runResult = await compareRun(
          manifest: manifest,
          storage: storage,
          options: CompareRunOptions(runDirectoryPath: runDirectory.path),
        );

        expect(
          runResult.snapshots.map((snapshot) => snapshot.verdict),
          everyElement(ComparisonVerdict.newSnapshot),
        );
        expect(runResult.summary.passed, 0);
        expect(runResult.summary.changed, 0);
        expect(runResult.summary.sizeChanged, 0);
        expect(runResult.summary.newSnapshots, 2);
        expect(runResult.summary.total, 2);
        expect(runResult.summary.isSuccessful, isTrue);
        expect(runResult.summary.hasBlockingChanges, isFalse);
        expect(runResult.summary.hasUnacceptedSnapshots, isTrue);
        expect(runResult.probableRenames, isEmpty);
      },
    );

    test('accepting a first run writes baselines and a rerun passes', () async {
      final manifest = await _writeManifest(
        runDirectory,
        entries: [
          _capture(
            id: 'button-primary',
            relativePath: 'captures/button-primary.png',
            pngBytes: _solidPng(
              width: 3,
              height: 2,
              red: 20,
              green: 40,
              blue: 60,
            ),
          ),
          _capture(
            id: 'button-secondary',
            relativePath: 'captures/button-secondary.png',
            pngBytes: _solidPng(
              width: 2,
              height: 2,
              red: 200,
              green: 180,
              blue: 20,
            ),
          ),
        ],
      );

      final firstRun = await compareRun(
        manifest: manifest,
        storage: storage,
        options: CompareRunOptions(runDirectoryPath: runDirectory.path),
      );
      await acceptRun(firstRun, storage: storage);

      final secondRun = await compareRun(
        manifest: manifest,
        storage: storage,
        options: CompareRunOptions(runDirectoryPath: runDirectory.path),
      );

      expect(
        secondRun.snapshots.map((snapshot) => snapshot.verdict),
        everyElement(ComparisonVerdict.pass),
      );
      expect(secondRun.summary.passed, 2);
      expect(secondRun.summary.newSnapshots, 0);
      expect(secondRun.summary.changed, 0);
      expect(secondRun.summary.sizeChanged, 0);
      expect(secondRun.summary.isSuccessful, isTrue);
    });

    test(
      'summary counts each verdict correctly and tracks probable renames',
      () async {
        final previousManifest = await _writeManifest(
          runDirectory,
          entries: [
            _capture(
              id: 'button-pass',
              relativePath: 'previous/button-pass.png',
              pngBytes: _solidPng(
                width: 3,
                height: 2,
                red: 30,
                green: 50,
                blue: 70,
              ),
            ),
            _capture(
              id: 'button-changed',
              relativePath: 'previous/button-changed.png',
              pngBytes: _solidPng(
                width: 3,
                height: 2,
                red: 120,
                green: 140,
                blue: 160,
              ),
            ),
            _capture(
              id: 'button-size',
              relativePath: 'previous/button-size.png',
              pngBytes: _solidPng(
                width: 2,
                height: 2,
                red: 10,
                green: 80,
                blue: 160,
              ),
            ),
            _capture(
              id: 'button-old-name',
              relativePath: 'previous/button-old-name.png',
              pngBytes: _solidPng(
                width: 2,
                height: 3,
                red: 210,
                green: 30,
                blue: 60,
              ),
            ),
          ],
        );

        final acceptedRun = await compareRun(
          manifest: previousManifest,
          storage: storage,
          options: CompareRunOptions(runDirectoryPath: runDirectory.path),
        );
        await acceptRun(acceptedRun, storage: storage);

        final currentManifest = await _writeManifest(
          runDirectory,
          entries: [
            _capture(
              id: 'button-pass',
              relativePath: 'current/button-pass.png',
              pngBytes: _solidPng(
                width: 3,
                height: 2,
                red: 30,
                green: 50,
                blue: 70,
              ),
            ),
            _capture(
              id: 'button-changed',
              relativePath: 'current/button-changed.png',
              pngBytes: _singlePixelChangePng(
                width: 3,
                height: 2,
                baseRed: 120,
                baseGreen: 140,
                baseBlue: 160,
                changedX: 1,
                changedY: 0,
                changedRed: 0,
                changedGreen: 0,
                changedBlue: 0,
              ),
            ),
            _capture(
              id: 'button-size',
              relativePath: 'current/button-size.png',
              pngBytes: _solidPng(
                width: 4,
                height: 2,
                red: 10,
                green: 80,
                blue: 160,
              ),
            ),
            _capture(
              id: 'button-new',
              relativePath: 'current/button-new.png',
              pngBytes: _solidPng(
                width: 2,
                height: 2,
                red: 15,
                green: 25,
                blue: 35,
              ),
            ),
            _capture(
              id: 'button-renamed',
              relativePath: 'current/button-renamed.png',
              pngBytes: _solidPng(
                width: 2,
                height: 3,
                red: 210,
                green: 30,
                blue: 60,
              ),
            ),
          ],
        );

        final runResult = await compareRun(
          manifest: currentManifest,
          storage: storage,
          options: CompareRunOptions(runDirectoryPath: runDirectory.path),
        );

        final snapshotsById = {
          for (final snapshot in runResult.snapshots) snapshot.id: snapshot,
        };
        expect(snapshotsById['button-pass']!.verdict, ComparisonVerdict.pass);
        expect(
          snapshotsById['button-changed']!.verdict,
          ComparisonVerdict.changed,
        );
        expect(
          snapshotsById['button-size']!.verdict,
          ComparisonVerdict.sizeChanged,
        );
        expect(
          snapshotsById['button-new']!.verdict,
          ComparisonVerdict.newSnapshot,
        );
        expect(
          snapshotsById['button-renamed']!.verdict,
          ComparisonVerdict.pass,
        );
        expect(
          snapshotsById['button-renamed']!.baselineId,
          equals('button-old-name'),
        );
        expect(snapshotsById['button-renamed']!.probableRename, isNotNull);

        expect(runResult.summary.passed, 2);
        expect(runResult.summary.changed, 1);
        expect(runResult.summary.sizeChanged, 1);
        expect(runResult.summary.newSnapshots, 1);
        expect(runResult.summary.total, 5);
        expect(runResult.summary.isSuccessful, isFalse);
        expect(runResult.summary.hasBlockingChanges, isTrue);
        expect(runResult.renameDetection.probableRenames, hasLength(1));
        expect(runResult.renameDetection.vanishedEntries, isEmpty);
        expect(
          runResult.renameDetection.newEntries.map((entry) => entry.id),
          orderedEquals(['button-new']),
        );
      },
    );
  });
}

Future<Manifest> _writeManifest(
  Directory runDirectory, {
  required List<_CaptureFixture> entries,
}) async {
  for (final fixture in entries) {
    final file = File.fromUri(runDirectory.uri.resolve(fixture.relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(fixture.pngBytes, flush: true);
  }

  return Manifest(
    manifestVersion: const ManifestVersion(1, 0),
    entries: [
      for (final fixture in entries)
        ManifestEntry(
          id: fixture.id,
          platform: Platform.flutter,
          width: fixture.width,
          height: fixture.height,
          dpr: 1,
          contentHash: sha256.convert(fixture.pngBytes).toString(),
          envFingerprint: 'test-env',
          imagePath: fixture.relativePath,
        ),
    ],
  );
}

_CaptureFixture _capture({
  required String id,
  required String relativePath,
  required Uint8List pngBytes,
}) {
  final decoded = img.decodePng(pngBytes)!;
  return _CaptureFixture(
    id: id,
    relativePath: relativePath,
    pngBytes: pngBytes,
    width: decoded.width,
    height: decoded.height,
  );
}

Uint8List _solidPng({
  required int width,
  required int height,
  required int red,
  required int green,
  required int blue,
}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, red, green, blue, 255);
    }
  }
  return img.PngEncoder().encode(image);
}

Uint8List _singlePixelChangePng({
  required int width,
  required int height,
  required int baseRed,
  required int baseGreen,
  required int baseBlue,
  required int changedX,
  required int changedY,
  required int changedRed,
  required int changedGreen,
  required int changedBlue,
}) {
  final image = img.decodePng(
    _solidPng(
      width: width,
      height: height,
      red: baseRed,
      green: baseGreen,
      blue: baseBlue,
    ),
  )!;
  image.setPixelRgba(
    changedX,
    changedY,
    changedRed,
    changedGreen,
    changedBlue,
    255,
  );
  return img.PngEncoder().encode(image);
}

class _CaptureFixture {
  const _CaptureFixture({
    required this.id,
    required this.relativePath,
    required this.pngBytes,
    required this.width,
    required this.height,
  });

  final String id;
  final String relativePath;
  final Uint8List pngBytes;
  final int width;
  final int height;
}
