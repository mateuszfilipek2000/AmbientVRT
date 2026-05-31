import 'dart:io';
import 'dart:typed_data';

import 'package:ambient_cli/ambient_cli.dart';
import 'package:ambient_core/ambient_core.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  group('runAmbient', () {
    late Directory workspaceDirectory;
    late Directory runDirectory;
    late Directory storageDirectory;

    setUp(() async {
      workspaceDirectory = await Directory.systemTemp.createTemp(
        'ambient-cli-workspace-',
      );
      runDirectory = Directory.fromUri(workspaceDirectory.uri.resolve('run/'));
      storageDirectory = Directory.fromUri(
        workspaceDirectory.uri.resolve('storage/'),
      );
      await runDirectory.create(recursive: true);
      await storageDirectory.create(recursive: true);
    });

    tearDown(() async {
      if (await workspaceDirectory.exists()) {
        await workspaceDirectory.delete(recursive: true);
      }
    });

    test('top-level help lists the task commands', () async {
      final stdout = StringBuffer();
      final stderr = StringBuffer();

      final exitCode = await runAmbient(
        const ['--help'],
        stdout: stdout,
        stderr: stderr,
        currentDirectoryPath: workspaceDirectory.path,
      );

      expect(exitCode, AmbientExitCode.success);
      expect(stderr.toString(), isEmpty);
      expect(
        stdout.toString(),
        contains('Usage: ambient <command> [arguments]'),
      );
      expect(stdout.toString(), contains('init'));
      expect(stdout.toString(), contains('test'));
      expect(stdout.toString(), contains('capture'));
      expect(stdout.toString(), contains('accept'));
    });

    test('init scaffolds a valid ambient.config.yaml', () async {
      final stdout = StringBuffer();

      final exitCode = await runAmbient(
        const ['init'],
        stdout: stdout,
        stderr: StringBuffer(),
        currentDirectoryPath: workspaceDirectory.path,
      );

      final configFile = File.fromUri(
        workspaceDirectory.uri.resolve('ambient.config.yaml'),
      );
      expect(exitCode, AmbientExitCode.success);
      expect(await configFile.exists(), isTrue);

      final parsedConfig = Config.fromYamlString(
        await configFile.readAsString(),
      );
      expect(parsedConfig.storage.backend, StorageBackend.local);
      expect(parsedConfig.storage.path, '.ambient/baselines');
      expect(parsedConfig.adapters, hasLength(2));
      expect(stdout.toString(), contains('ambient.config.yaml'));
    });

    test(
      'test and accept enforce exit codes across new, pass, and changed runs',
      () async {
        await _writeConfig(workspaceDirectory, storageDirectory.path);
        await _writeRunFixture(
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
          ],
        );

        final firstStdout = StringBuffer();
        final firstExitCode = await runAmbient(
          ['test', '--run-dir', runDirectory.path],
          stdout: firstStdout,
          stderr: StringBuffer(),
          currentDirectoryPath: workspaceDirectory.path,
        );
        expect(firstExitCode, AmbientExitCode.comparisonFailed);
        expect(firstStdout.toString(), contains('new=1'));
        expect(
          await File.fromUri(
            workspaceDirectory.uri.resolve('.ambient/report/report.html'),
          ).exists(),
          isTrue,
        );

        final acceptExitCode = await runAmbient(
          ['accept', '--run-dir', runDirectory.path],
          stdout: StringBuffer(),
          stderr: StringBuffer(),
          currentDirectoryPath: workspaceDirectory.path,
        );
        expect(acceptExitCode, AmbientExitCode.success);

        final secondStdout = StringBuffer();
        final secondExitCode = await runAmbient(
          ['test', '--run-dir', runDirectory.path],
          stdout: secondStdout,
          stderr: StringBuffer(),
          currentDirectoryPath: workspaceDirectory.path,
        );
        expect(secondExitCode, AmbientExitCode.success);
        expect(secondStdout.toString(), contains('passed=1'));

        await _writeRunFixture(
          runDirectory,
          entries: [
            _capture(
              id: 'button-primary',
              relativePath: 'captures/button-primary.png',
              pngBytes: _singlePixelChangePng(
                width: 3,
                height: 2,
                baseRed: 20,
                baseGreen: 40,
                baseBlue: 60,
                changedX: 1,
                changedY: 0,
                changedRed: 255,
                changedGreen: 255,
                changedBlue: 255,
              ),
            ),
          ],
        );

        final changedStdout = StringBuffer();
        final changedExitCode = await runAmbient(
          ['test', '--run-dir', runDirectory.path],
          stdout: changedStdout,
          stderr: StringBuffer(),
          currentDirectoryPath: workspaceDirectory.path,
        );
        expect(changedExitCode, AmbientExitCode.comparisonFailed);
        expect(changedStdout.toString(), contains('changed=1'));
      },
    );

    test(
      'capture reports the deferred orchestrator implementation clearly',
      () async {
        final stderr = StringBuffer();

        final exitCode = await runAmbient(
          const ['capture'],
          stdout: StringBuffer(),
          stderr: stderr,
          currentDirectoryPath: workspaceDirectory.path,
        );

        expect(exitCode, AmbientExitCode.notImplemented);
        expect(stderr.toString(), contains('T3.2'));
      },
    );
  });
}

Future<void> _writeConfig(
  Directory workspaceDirectory,
  String storagePath,
) async {
  final configFile = File.fromUri(
    workspaceDirectory.uri.resolve('ambient.config.yaml'),
  );
  await configFile.writeAsString('''adapters:
  - platform: flutter
    projectPath: ./
storage:
  backend: local
  path: $storagePath
compare:
  threshold: 0.1
''', flush: true);
}

Future<void> _writeRunFixture(
  Directory runDirectory, {
  required List<_CaptureFixture> entries,
}) async {
  for (final fixture in entries) {
    final file = File.fromUri(runDirectory.uri.resolve(fixture.relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(fixture.pngBytes, flush: true);
  }

  final manifest = Manifest(
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
  await File.fromUri(
    runDirectory.uri.resolve('manifest.json'),
  ).writeAsString(manifest.toJsonString(), flush: true);
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
  final image = img.Image(width: width, height: height);
  final color = img.ColorRgb8(red, green, blue);
  img.fill(image, color: color);
  return Uint8List.fromList(img.encodePng(image));
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
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(baseRed, baseGreen, baseBlue));
  image.setPixel(
    changedX,
    changedY,
    img.ColorRgb8(changedRed, changedGreen, changedBlue),
  );
  return Uint8List.fromList(img.encodePng(image));
}

final class _CaptureFixture {
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
