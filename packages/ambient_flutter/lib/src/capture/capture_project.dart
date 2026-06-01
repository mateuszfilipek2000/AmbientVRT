import 'dart:convert';
import 'dart:io';

import 'package:ambient_core/ambient_core.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../discovery/generated_workspace.dart';
import '../discovery/preview_scanner.dart';
import '../models/flutter_preview.dart';

Future<List<FlutterPreviewInfo>> discoverFlutterPreviews({
  required String projectPath,
  double dpr = 1.0,
}) async {
  final project = await _loadProjectContext(projectPath);
  final targets = await PreviewScanner(
    projectPath: projectPath,
    packageName: project.packageName,
  ).scan();

  if (targets.isEmpty) {
    return const <FlutterPreviewInfo>[];
  }

  final workspace = await GeneratedWorkspace.create(
    projectPath: projectPath,
    packageName: project.packageName,
    targets: targets,
    mode: GeneratedHarnessMode.discover,
    dpr: dpr,
    outputDirectory: null,
  );
  try {
    await _runFlutterTest(
      projectPath: projectPath,
      testFile: workspace.harnessFile.path,
    );
    return _readPreviewInfos(workspace.metadataFile);
  } finally {
    await workspace.delete();
  }
}

Future<Manifest> captureFlutterPreviews({
  required String projectPath,
  required String outputDirectory,
  double dpr = 1.0,
  String? canonicalEnv,
  List<String> variants = const <String>[],
}) async {
  final project = await _loadProjectContext(projectPath);
  final targets = await PreviewScanner(
    projectPath: projectPath,
    packageName: project.packageName,
  ).scan();
  final previews = await discoverFlutterPreviews(
    projectPath: projectPath,
    dpr: dpr,
  );
  final outDir = Directory(outputDirectory);
  await outDir.create(recursive: true);

  final workspace = await GeneratedWorkspace.create(
    projectPath: projectPath,
    packageName: project.packageName,
    targets: targets,
    mode: GeneratedHarnessMode.capture,
    dpr: dpr,
    outputDirectory: outputDirectory,
  );

  try {
    for (final preview in previews) {
      final rawCapturePath = p.join(
        outputDirectory,
        '${preview.imagePath}.rgba',
      );
      await _runFlutterTest(
        projectPath: projectPath,
        testFile: workspace.harnessFile.path,
        environment: <String, String>{'AMBIENT_PREVIEW_ID': preview.id},
        expectedOutputPath: rawCapturePath,
      );
      _materializePngCapture(preview, outputDirectory);
    }
    final envFingerprint =
        canonicalEnv ?? await _computeFlutterEnvFingerprint(projectPath);
    final entries = <ManifestEntry>[
      for (final preview in previews)
        _manifestEntryForPreview(preview, outputDirectory, envFingerprint),
    ]..sort((left, right) => left.id.compareTo(right.id));

    final manifest = Manifest(
      manifestVersion: ManifestVersion.current,
      entries: entries,
    );
    final manifestFile = File(p.join(outputDirectory, 'manifest.json'));
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
    return manifest;
  } finally {
    await workspace.delete();
  }
}

ManifestEntry _manifestEntryForPreview(
  FlutterPreviewInfo preview,
  String outputDirectory,
  String envFingerprint,
) {
  final captureFile = File(p.join(outputDirectory, preview.imagePath));
  if (!captureFile.existsSync()) {
    throw StateError(
      'Expected capture file ${captureFile.path} was not produced.',
    );
  }

  final bytes = captureFile.readAsBytesSync();
  final decoded = image.decodePng(bytes);
  if (decoded == null) {
    throw StateError('Unable to decode ${captureFile.path} as PNG.');
  }

  return preview.toManifestEntry(
    width: decoded.width,
    height: decoded.height,
    contentHash: sha256.convert(bytes).toString(),
    envFingerprint: envFingerprint,
  );
}

void _materializePngCapture(
  FlutterPreviewInfo preview,
  String outputDirectory,
) {
  final rawCaptureFile = File(
    p.join(outputDirectory, '${preview.imagePath}.rgba'),
  );
  if (!rawCaptureFile.existsSync()) {
    throw StateError(
      'Expected raw capture file ${rawCaptureFile.path} was not produced.',
    );
  }

  final width = ((preview.width ?? 800) * preview.dpr).round();
  final height = ((preview.height ?? 600) * preview.dpr).round();
  final rawBytes = rawCaptureFile.readAsBytesSync();
  final expectedByteLength = width * height * 4;
  if (rawBytes.length != expectedByteLength) {
    throw StateError(
      'Raw capture ${rawCaptureFile.path} has ${rawBytes.length} bytes; '
      'expected $expectedByteLength for ${width}x$height RGBA.',
    );
  }

  final png = image.Image.fromBytes(
    width: width,
    height: height,
    bytes: rawBytes.buffer,
    numChannels: 4,
    order: image.ChannelOrder.rgba,
  );
  final encoder = image.PngEncoder(level: 0, filter: image.PngFilter.none);
  final captureFile = File(p.join(outputDirectory, preview.imagePath));
  captureFile.parent.createSync(recursive: true);
  captureFile.writeAsBytesSync(encoder.encode(png), flush: true);
  rawCaptureFile.deleteSync();
}

Future<String> _computeFlutterEnvFingerprint(String projectPath) async {
  final result = await Process.run('flutter', <String>[
    '--version',
    '--machine',
  ], workingDirectory: projectPath);
  if (result.exitCode != 0) {
    throw StateError(
      'Unable to resolve flutter environment fingerprint.\n${result.stdout}\n${result.stderr}',
    );
  }

  final machineVersion =
      jsonDecode(result.stdout as String) as Map<String, Object?>;
  return [
    machineVersion['frameworkVersion'],
    machineVersion['engineRevision'],
    machineVersion['dartSdkVersion'],
  ].whereType<String>().join('|');
}

List<FlutterPreviewInfo> _readPreviewInfos(File metadataFile) {
  final raw = jsonDecode(metadataFile.readAsStringSync()) as List<Object?>;
  return <FlutterPreviewInfo>[
    for (final entry in raw.cast<Map<String, Object?>>())
      FlutterPreviewInfo.fromJson(entry),
  ];
}

Future<void> _runFlutterTest({
  required String projectPath,
  required String testFile,
  Map<String, String>? environment,
  String? expectedOutputPath,
}) async {
  final relativeTestPath = p.relative(testFile, from: projectPath);
  final packageConfigExists = File(
    p.join(projectPath, '.dart_tool', 'package_config.json'),
  ).existsSync();
  final result = await Process.run(
    'flutter',
    <String>[
      'test',
      if (packageConfigExists) '--no-pub',
      '--concurrency=1',
      relativeTestPath,
    ],
    workingDirectory: projectPath,
    environment: environment,
  );
  final combinedOutput = '${result.stdout}\n${result.stderr}';
  final expectedOutputExists =
      expectedOutputPath != null && File(expectedOutputPath).existsSync();
  if (result.exitCode != 0 && !expectedOutputExists) {
    throw StateError('Generated Flutter harness failed.\n$combinedOutput');
  }
}

Future<_ProjectContext> _loadProjectContext(String projectPath) async {
  final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    throw StateError('No pubspec.yaml found at $projectPath.');
  }

  final pubspec = loadYaml(await pubspecFile.readAsString()) as YamlMap;
  final packageName = pubspec['name'] as String?;
  if (packageName == null || packageName.trim().isEmpty) {
    throw StateError(
      'Project at $projectPath is missing a valid package name.',
    );
  }

  return _ProjectContext(packageName: packageName);
}

class _ProjectContext {
  const _ProjectContext({required this.packageName});

  final String packageName;
}
