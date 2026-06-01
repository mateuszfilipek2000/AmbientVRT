import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:io' as io show Platform;

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
    late Directory mockAdapterDirectory;
    late String mockAdapterScriptPath;

    setUp(() async {
      workspaceDirectory = await Directory.systemTemp.createTemp(
        'ambient-cli-workspace-',
      );
      runDirectory = Directory.fromUri(workspaceDirectory.uri.resolve('run/'));
      storageDirectory = Directory.fromUri(
        workspaceDirectory.uri.resolve('storage/'),
      );
      mockAdapterDirectory = Directory.fromUri(
        workspaceDirectory.uri.resolve('mock_adapter/'),
      );
      await runDirectory.create(recursive: true);
      await storageDirectory.create(recursive: true);
      await mockAdapterDirectory.create(recursive: true);
      mockAdapterScriptPath = await _writeMockAdapterScript(
        mockAdapterDirectory,
      );
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
      'test flags captures taken outside the configured canonical env',
      () async {
        final configFile = File.fromUri(
          workspaceDirectory.uri.resolve('ambient.config.yaml'),
        );
        await configFile.writeAsString('''adapters:
  - platform: flutter
    projectPath: ./
storage:
  backend: local
  path: ${_yamlQuote(storageDirectory.path)}
compare:
  threshold: 0.1
canonicalEnv: ambient/capture-env@sha256:canonical
''', flush: true);
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

        final stderr = StringBuffer();
        // The fixture stamps `test-env`, which differs from the configured
        // canonicalEnv, so the run must warn (non-blocking: the exit code is
        // still driven by the `new` verdict).
        final exitCode = await runAmbient(
          ['test', '--run-dir', runDirectory.path],
          stdout: StringBuffer(),
          stderr: stderr,
          currentDirectoryPath: workspaceDirectory.path,
        );

        expect(exitCode, AmbientExitCode.comparisonFailed);
        expect(
          stderr.toString(),
          contains('outside the canonical capture-env'),
        );
        expect(stderr.toString(), contains('button-primary'));
      },
    );

    test(
      'test and accept enforce exit codes across new, pass, and changed runs',
      () async {
        await _writeRunDirConfig(workspaceDirectory, storageDirectory.path);
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
      'capture invokes the adapter through the documented subprocess contract',
      () async {
        final captureDirectory = Directory.fromUri(
          workspaceDirectory.uri.resolve('captured-run/'),
        );
        await _writeOrchestratedConfig(
          workspaceDirectory: workspaceDirectory,
          storagePath: storageDirectory.path,
          projectPath: mockAdapterDirectory.path,
          scriptPath: mockAdapterScriptPath,
          scenario: 'baseline',
          variants: const ['light', 'dark'],
          canonicalEnv: 'ambient/mock@sha256:1234',
        );

        final stdout = StringBuffer();
        final stderr = StringBuffer();
        final exitCode = await runAmbient(
          ['capture', '--run-dir', captureDirectory.path],
          stdout: stdout,
          stderr: stderr,
          currentDirectoryPath: workspaceDirectory.path,
        );

        expect(exitCode, AmbientExitCode.success);
        expect(stderr.toString(), isEmpty);
        expect(stdout.toString(), contains(captureDirectory.path));

        final contractFile = File.fromUri(
          captureDirectory.uri.resolve('adapters/0-flutter/contract.json'),
        );
        final contract =
            jsonDecode(await contractFile.readAsString())
                as Map<String, Object?>;
        final mockAdapterRealPath = await Directory(
          mockAdapterDirectory.path,
        ).resolveSymbolicLinks();
        final contractWorkingDirectory = await Directory(
          contract['cwd']! as String,
        ).resolveSymbolicLinks();
        expect(
          contract,
          containsPair(
            'outDir',
            Directory.fromUri(
              captureDirectory.uri.resolve('adapters/0-flutter/'),
            ).path,
          ),
        );
        expect(
          contract,
          containsPair('projectPath', mockAdapterDirectory.path),
        );
        expect(contractWorkingDirectory, mockAdapterRealPath);
        expect(contract['variants'], ['light', 'dark']);
        // The orchestrator does NOT forward the configured canonicalEnv to the
        // adapter: the adapter stamps the *actual* capture env (AMBIENT_CAPTURE_ENV
        // or a toolchain fallback); canonicalEnv is the *expected* value the core
        // checks against (backlog T6.1).
        expect(contract, containsPair('canonicalEnv', isNull));

        final mergedManifest = Manifest.fromJsonString(
          await File.fromUri(
            captureDirectory.uri.resolve('manifest.json'),
          ).readAsString(),
        );
        expect(mergedManifest.entries, hasLength(1));
        expect(
          mergedManifest.entries.single.imagePath,
          'adapters/0-flutter/captures/button-primary.png',
        );
      },
    );

    test(
      'test and accept orchestrate capture, compare, report, and baseline updates',
      () async {
        await _writeOrchestratedConfig(
          workspaceDirectory: workspaceDirectory,
          storagePath: storageDirectory.path,
          projectPath: mockAdapterDirectory.path,
          scriptPath: mockAdapterScriptPath,
          scenario: 'baseline',
        );

        final firstStdout = StringBuffer();
        final firstExitCode = await runAmbient(
          const ['test'],
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
          const ['accept'],
          stdout: StringBuffer(),
          stderr: StringBuffer(),
          currentDirectoryPath: workspaceDirectory.path,
        );
        expect(acceptExitCode, AmbientExitCode.success);

        final secondStdout = StringBuffer();
        final secondExitCode = await runAmbient(
          const ['test'],
          stdout: secondStdout,
          stderr: StringBuffer(),
          currentDirectoryPath: workspaceDirectory.path,
        );
        expect(secondExitCode, AmbientExitCode.success);
        expect(secondStdout.toString(), contains('passed=1'));

        await _writeOrchestratedConfig(
          workspaceDirectory: workspaceDirectory,
          storagePath: storageDirectory.path,
          projectPath: mockAdapterDirectory.path,
          scriptPath: mockAdapterScriptPath,
          scenario: 'changed',
        );

        final changedStdout = StringBuffer();
        final changedExitCode = await runAmbient(
          const ['test'],
          stdout: changedStdout,
          stderr: StringBuffer(),
          currentDirectoryPath: workspaceDirectory.path,
        );
        expect(changedExitCode, AmbientExitCode.comparisonFailed);
        expect(changedStdout.toString(), contains('changed=1'));
      },
    );
  });
}

Future<void> _writeRunDirConfig(
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
  path: ${_yamlQuote(storagePath)}
compare:
  threshold: 0.1
''', flush: true);
}

Future<void> _writeOrchestratedConfig({
  required Directory workspaceDirectory,
  required String storagePath,
  required String projectPath,
  required String scriptPath,
  required String scenario,
  List<String> variants = const [],
  String? canonicalEnv,
}) async {
  final buffer = StringBuffer()
    ..writeln('adapters:')
    ..writeln('  - platform: flutter')
    ..writeln('    projectPath: ${_yamlQuote(projectPath)}')
    ..writeln('    command:')
    ..writeln('      - ${_yamlQuote(io.Platform.resolvedExecutable)}')
    ..writeln('      - ${_yamlQuote(scriptPath)}')
    ..writeln('      - --scenario')
    ..writeln('      - ${_yamlQuote(scenario)}')
    ..writeln('storage:')
    ..writeln('  backend: local')
    ..writeln('  path: ${_yamlQuote(storagePath)}')
    ..writeln('compare:')
    ..writeln('  threshold: 0.1');

  if (variants.isNotEmpty) {
    buffer
      ..writeln('variants:')
      ..writeln(
        variants.map((variant) => '  - ${_yamlQuote(variant)}').join('\n'),
      );
  }
  if (canonicalEnv != null) {
    buffer.writeln('canonicalEnv: ${_yamlQuote(canonicalEnv)}');
  }

  final configFile = File.fromUri(
    workspaceDirectory.uri.resolve('ambient.config.yaml'),
  );
  await configFile.writeAsString(buffer.toString(), flush: true);
}

Future<String> _writeMockAdapterScript(Directory mockAdapterDirectory) async {
  final scriptFile = File.fromUri(
    mockAdapterDirectory.uri.resolve('capture.dart'),
  );
  await scriptFile.writeAsString(_mockAdapterScript, flush: true);
  return scriptFile.path;
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

String _yamlQuote(String value) => "'${value.replaceAll("'", "''")}'";

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

const String _mockAdapterScript = r'''
import 'dart:convert';
import 'dart:io';

const String _baselinePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGMQ0bD5D8IACmMC77ynAhwAAAAASUVORK5CYII=';
const String _baselineHash =
    'cd6522b8f7e796ba59ebf91ae51130db33b19bea49731b4281651c7ed245dd75';
const String _changedPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGMQ0bD5DwIAEhoFdEte7AwAAAAASUVORK5CYII=';
const String _changedHash =
    'f3ae86785d11e9cf20210f09d875007eebbe3779f5b7beb772be14f45bd2e34b';

Future<void> main(List<String> args) async {
  String? outDir;
  String? projectPath;
  String? storybookStaticDir;
  String? canonicalEnv;
  var scenario = 'baseline';
  final variants = <String>[];

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--out-dir':
        outDir = args[++i];
        break;
      case '--project-path':
        projectPath = args[++i];
        break;
      case '--storybook-static-dir':
        storybookStaticDir = args[++i];
        break;
      case '--variant':
        variants.add(args[++i]);
        break;
      case '--canonical-env':
        canonicalEnv = args[++i];
        break;
      case '--scenario':
        scenario = args[++i];
        break;
      default:
        stderr.writeln('Unexpected argument: ${args[i]}');
        exitCode = 64;
        return;
    }
  }

  if (outDir == null) {
    stderr.writeln('Missing required --out-dir.');
    exitCode = 64;
    return;
  }

  String pngBase64;
  String contentHash;
  if (scenario == 'baseline') {
    pngBase64 = _baselinePngBase64;
    contentHash = _baselineHash;
  } else if (scenario == 'changed') {
    pngBase64 = _changedPngBase64;
    contentHash = _changedHash;
  } else {
    stderr.writeln('Unsupported scenario: $scenario');
    exitCode = 64;
    return;
  }

  final outputDirectory = Directory(outDir);
  await outputDirectory.create(recursive: true);

  final imageFile = File.fromUri(
    outputDirectory.uri.resolve('captures/button-primary.png'),
  );
  await imageFile.parent.create(recursive: true);
  await imageFile.writeAsBytes(base64Decode(pngBase64), flush: true);

  final manifest = <String, Object?>{
    'manifestVersion': '1.0',
    'entries': [
      {
        'id': 'button-primary',
        'platform': 'flutter',
        'width': 2,
        'height': 1,
        'dpr': 1,
        'contentHash': contentHash,
        'envFingerprint': canonicalEnv ?? 'mock-env',
        'imagePath': 'captures/button-primary.png',
      },
    ],
  };
  await File.fromUri(
    outputDirectory.uri.resolve('manifest.json'),
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest), flush: true);

  final contract = <String, Object?>{
    'outDir': outputDirectory.path,
    'projectPath': projectPath,
    'storybookStaticDir': storybookStaticDir,
    'variants': variants,
    'canonicalEnv': canonicalEnv,
    'cwd': Directory.current.path,
  };
  await File.fromUri(
    outputDirectory.uri.resolve('contract.json'),
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(contract), flush: true);
}
''';
