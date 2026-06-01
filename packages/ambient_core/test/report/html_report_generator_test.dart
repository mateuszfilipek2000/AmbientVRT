import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ambient_core/ambient_core.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  group('generateHtmlReport', () {
    late Directory runDirectory;
    late Directory reportDirectory;
    late Directory storageDirectory;
    late LocalStorageBackend storage;

    setUp(() async {
      runDirectory = await Directory.systemTemp.createTemp(
        'ambient-report-run-fixtures-',
      );
      reportDirectory = await Directory.systemTemp.createTemp(
        'ambient-report-output-',
      );
      storageDirectory = await Directory.systemTemp.createTemp(
        'ambient-report-storage-',
      );
      storage = LocalStorageBackend(directoryPath: storageDirectory.path);
    });

    tearDown(() async {
      if (await runDirectory.exists()) {
        await runDirectory.delete(recursive: true);
      }
      if (await reportDirectory.exists()) {
        await reportDirectory.delete(recursive: true);
      }
      if (await storageDirectory.exists()) {
        await storageDirectory.delete(recursive: true);
      }
    });

    test(
      'writes a standalone report with expected sections counts and relative assets',
      () async {
        final runResult = await _createMixedRunResult(
          runDirectory: runDirectory,
          storage: storage,
        );

        final output = await generateHtmlReport(
          runResult: runResult,
          outputDirectoryPath: reportDirectory.path,
        );

        final html = await File(output.reportPath).readAsString();
        expect(html, contains('<h1 class="sr-only">AmbientVRT Report</h1>'));
        expect(html, contains('Visual regression report'));
        // Summary counts are exposed as data-attributes on the summary block.
        expect(html, contains('data-total="5"'));
        expect(html, contains('data-changed="1"'));
        expect(html, contains('data-new="1"'));
        expect(html, contains('data-size-changed="1"'));
        expect(html, contains('data-passed="2"'));
        expect(html, contains('button-changed'));
        expect(html, contains('button-new'));
        expect(html, contains('button-size'));
        expect(html, contains('button-renamed'));
        expect(html, contains('Probable rename from button-old-name'));
        // The changed snapshot surfaces its mismatch percentage.
        expect(html, contains('mismatch'));
        expect(html, isNot(contains(reportDirectory.path)));

        final assetSources = RegExp(
          r'<img[^>]+src="([^"]+)"',
        ).allMatches(html).map((match) => match.group(1)!).toList();

        expect(assetSources, hasLength(6));
        for (final src in assetSources) {
          expect(src, startsWith('assets/'));
          expect(Uri.parse(src).hasScheme, isFalse);
          expect(src, isNot(startsWith('/')));

          final assetFile = File.fromUri(
            File(output.reportPath).parent.uri.resolve(src),
          );
          expect(await assetFile.exists(), isTrue);
        }
      },
    );

    test(
      'renders a placeholder when a changed snapshot has no diff image',
      () async {
        final baselinePng = _solidPng(
          width: 2,
          height: 2,
          red: 20,
          green: 40,
          blue: 60,
        );
        final candidatePng = _solidPng(
          width: 2,
          height: 2,
          red: 30,
          green: 50,
          blue: 70,
        );
        final entry = _manifestEntry(
          id: 'diff-missing',
          imagePath: 'current/diff-missing.png',
          pngBytes: candidatePng,
        );
        final baselineEntry = _manifestEntry(
          id: 'diff-missing',
          imagePath: 'baseline/diff-missing.png',
          pngBytes: baselinePng,
        );
        final snapshot = SnapshotRunResult(
          entry: entry,
          baselineEntry: baselineEntry,
          baselinePng: baselinePng,
          candidatePng: candidatePng,
          candidateImagePath: entry.imagePath,
          comparison: const ComparisonResult(
            verdict: ComparisonVerdict.changed,
            baselineSize: ImageSize(width: 2, height: 2),
            candidateSize: ImageSize(width: 2, height: 2),
            changedPixels: 1,
            totalPixels: 4,
          ),
        );
        final runResult = CompareRunResult(
          manifest: Manifest(
            manifestVersion: const ManifestVersion(1, 0),
            entries: [entry],
          ),
          snapshots: [snapshot],
          summary: CompareRunSummary.fromSnapshots([snapshot]),
        );

        final output = await generateHtmlReport(
          runResult: runResult,
          outputDirectoryPath: reportDirectory.path,
        );

        final html = await File(output.reportPath).readAsString();
        expect(html, contains('Diff unavailable'));
        expect(html, isNot(contains('diff.png')));
        expect(
          await File.fromUri(
            File(output.reportPath).parent.uri.resolve(
              'assets/changed/${sha256.convert(utf8.encode('changed:diff-missing'))}/baseline.png',
            ),
          ).exists(),
          isTrue,
        );
      },
    );
  });
}

Future<CompareRunResult> _createMixedRunResult({
  required Directory runDirectory,
  required LocalStorageBackend storage,
}) async {
  final previousManifest = await _writeManifest(
    runDirectory,
    entries: [
      _capture(
        id: 'button-pass',
        relativePath: 'previous/button-pass.png',
        pngBytes: _solidPng(width: 3, height: 2, red: 30, green: 50, blue: 70),
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
        pngBytes: _solidPng(width: 2, height: 2, red: 10, green: 80, blue: 160),
      ),
      _capture(
        id: 'button-old-name',
        relativePath: 'previous/button-old-name.png',
        pngBytes: _solidPng(width: 2, height: 3, red: 210, green: 30, blue: 60),
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
        pngBytes: _solidPng(width: 3, height: 2, red: 30, green: 50, blue: 70),
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
        pngBytes: _solidPng(width: 4, height: 2, red: 10, green: 80, blue: 160),
      ),
      _capture(
        id: 'button-new',
        relativePath: 'current/button-new.png',
        pngBytes: _solidPng(width: 2, height: 2, red: 15, green: 25, blue: 35),
      ),
      _capture(
        id: 'button-renamed',
        relativePath: 'current/button-renamed.png',
        pngBytes: _solidPng(width: 2, height: 3, red: 210, green: 30, blue: 60),
      ),
    ],
  );

  return compareRun(
    manifest: currentManifest,
    storage: storage,
    options: CompareRunOptions(runDirectoryPath: runDirectory.path),
  );
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
        _manifestEntry(
          id: fixture.id,
          imagePath: fixture.relativePath,
          pngBytes: fixture.pngBytes,
          width: fixture.width,
          height: fixture.height,
        ),
    ],
  );
}

ManifestEntry _manifestEntry({
  required String id,
  required String imagePath,
  required Uint8List pngBytes,
  int? width,
  int? height,
}) {
  final decoded = img.decodePng(pngBytes)!;
  return ManifestEntry(
    id: id,
    platform: Platform.flutter,
    width: width ?? decoded.width,
    height: height ?? decoded.height,
    dpr: 1,
    contentHash: sha256.convert(pngBytes).toString(),
    envFingerprint: 'test-env',
    imagePath: imagePath,
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
