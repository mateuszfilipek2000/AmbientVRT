import 'dart:io';

import 'package:ambient_core/ambient_core.dart';

import '../ambient_environment.dart';
import '../cli_exception.dart';
import '../commands/run_command_support.dart';

const String _flutterDefaultCaptureCommand = 'ambient-flutter-capture';
const String _reactNativeDefaultCaptureCommand = 'ambient-rn-capture';

final class OrchestratedCaptureRun {
  const OrchestratedCaptureRun({
    required this.runDirectoryPath,
    required this.manifest,
  });

  final String runDirectoryPath;
  final Manifest manifest;
}

final class _CapturedAdapterManifest {
  const _CapturedAdapterManifest({
    required this.adapterLabel,
    required this.runDirectoryPath,
    required this.manifest,
  });

  final String adapterLabel;
  final String runDirectoryPath;
  final Manifest manifest;
}

Future<OrchestratedCaptureRun> captureConfiguredAdapters({
  required LoadedConfig loadedConfig,
  required AmbientEnvironment environment,
  String? runDirectoryPath,
}) async {
  final createdTemporaryRootDirectory = runDirectoryPath == null;
  final rootDirectory = createdTemporaryRootDirectory
      ? await Directory.systemTemp.createTemp('ambient-capture-run-')
      : Directory(runDirectoryPath);
  await rootDirectory.create(recursive: true);

  try {
    final capturedManifests = <_CapturedAdapterManifest>[];
    for (var i = 0; i < loadedConfig.config.adapters.length; i++) {
      final adapter = loadedConfig.config.adapters[i];
      final adapterLabel = _adapterLabel(adapter, i);
      final adapterRunDirectory = Directory.fromUri(
        rootDirectory.uri.resolve('adapters/$i-${adapter.platform.wireName}/'),
      );
      await adapterRunDirectory.create(recursive: true);

      await _invokeAdapter(
        adapter: adapter,
        adapterLabel: adapterLabel,
        adapterRunDirectoryPath: adapterRunDirectory.path,
        loadedConfig: loadedConfig,
        environment: environment,
        rootRunDirectoryPath: rootDirectory.path,
      );

      capturedManifests.add(
        _CapturedAdapterManifest(
          adapterLabel: adapterLabel,
          runDirectoryPath: adapterRunDirectory.path,
          manifest: await _loadAdapterManifest(
            adapterLabel: adapterLabel,
            adapterRunDirectoryPath: adapterRunDirectory.path,
          ),
        ),
      );
    }

    final mergedManifest = _mergeAdapterManifests(
      rootRunDirectoryPath: rootDirectory.path,
      capturedManifests: capturedManifests,
    );
    await File.fromUri(
      rootDirectory.uri.resolve(defaultManifestFileName),
    ).writeAsString(mergedManifest.toJsonString(), flush: true);

    return OrchestratedCaptureRun(
      runDirectoryPath: rootDirectory.path,
      manifest: mergedManifest,
    );
  } catch (_) {
    if (createdTemporaryRootDirectory && await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
    rethrow;
  }
}

Future<void> _invokeAdapter({
  required Adapter adapter,
  required String adapterLabel,
  required String adapterRunDirectoryPath,
  required LoadedConfig loadedConfig,
  required AmbientEnvironment environment,
  required String rootRunDirectoryPath,
}) async {
  final command = adapter.command ?? _defaultCommandFor(adapter.platform);
  final resolvedProjectPath = adapter.projectPath == null
      ? null
      : environment.resolveFromDirectory(
          loadedConfig.directoryPath,
          adapter.projectPath!,
        );
  final resolvedStorybookStaticDir = adapter.storybookStaticDir == null
      ? null
      : environment.resolveFromDirectory(
          loadedConfig.directoryPath,
          adapter.storybookStaticDir!,
        );
  final workingDirectoryPath = switch (adapter.platform) {
    Platform.flutter => resolvedProjectPath!,
    Platform.reactNative => loadedConfig.directoryPath,
  };
  final arguments = [
    ...command.skip(1),
    '--out-dir',
    adapterRunDirectoryPath,
    if (resolvedProjectPath != null) ...['--project-path', resolvedProjectPath],
    if (resolvedStorybookStaticDir != null) ...[
      '--storybook-static-dir',
      resolvedStorybookStaticDir,
    ],
    for (final variant in loadedConfig.config.variants) ...[
      '--variant',
      variant,
    ],
    if (loadedConfig.config.canonicalEnv case final canonicalEnv?) ...[
      '--canonical-env',
      canonicalEnv,
    ],
  ];

  ProcessResult result;
  try {
    result = await Process.run(
      command.first,
      arguments,
      workingDirectory: workingDirectoryPath,
      runInShell: false,
    );
  } on ProcessException catch (error) {
    throw AmbientCliException(
      'Failed to start $adapterLabel capture adapter (${_displayCommand(command, arguments)}).\n'
      'Run directory: $rootRunDirectoryPath\n'
      '${error.message}',
    );
  }

  final stdout = _trimOutput(result.stdout);
  final stderr = _trimOutput(result.stderr);
  if (result.exitCode != 0) {
    final details = <String>[
      'Capture adapter $adapterLabel failed with exit code ${result.exitCode}.',
      'Command: ${_displayCommand(command, arguments)}',
      'Run directory: $rootRunDirectoryPath',
      if (stdout.isNotEmpty) 'stdout:\n$stdout',
      if (stderr.isNotEmpty) 'stderr:\n$stderr',
    ];
    throw AmbientCliException(details.join('\n\n'));
  }
}

Future<Manifest> _loadAdapterManifest({
  required String adapterLabel,
  required String adapterRunDirectoryPath,
}) async {
  final manifestFile = File.fromUri(
    Directory(adapterRunDirectoryPath).uri.resolve(defaultManifestFileName),
  );
  if (!await manifestFile.exists()) {
    throw AmbientCliException(
      'Capture adapter $adapterLabel did not write ${manifestFile.path}.',
    );
  }

  try {
    final manifest = Manifest.fromJsonString(await manifestFile.readAsString());
    final adapterRunDirectory = Directory(adapterRunDirectoryPath);
    for (final entry in manifest.entries) {
      final imageFile = File.fromUri(
        adapterRunDirectory.uri.resolve(entry.imagePath),
      );
      if (!await imageFile.exists()) {
        throw AmbientCliException(
          'Capture adapter $adapterLabel referenced missing image '
          '"${entry.imagePath}" in ${manifestFile.path}.',
        );
      }
    }
    return manifest;
  } on ManifestFormatException catch (error) {
    throw AmbientCliException(
      'Capture adapter $adapterLabel wrote an invalid manifest at '
      '"${manifestFile.path}": $error',
    );
  }
}

Manifest _mergeAdapterManifests({
  required String rootRunDirectoryPath,
  required List<_CapturedAdapterManifest> capturedManifests,
}) {
  if (capturedManifests.isEmpty) {
    return Manifest(
      manifestVersion: const ManifestVersion(1, 0),
      entries: const [],
    );
  }

  final expectedVersion = capturedManifests.first.manifest.manifestVersion;
  final mergedEntries = <ManifestEntry>[];
  final ownerBySnapshotId = <String, String>{};
  final rootDirectory = Directory(rootRunDirectoryPath);

  for (final capturedManifest in capturedManifests) {
    if (capturedManifest.manifest.manifestVersion != expectedVersion) {
      throw AmbientCliException(
        'Capture adapter ${capturedManifest.adapterLabel} emitted '
        'manifestVersion ${capturedManifest.manifest.manifestVersion}, but '
        '${capturedManifests.first.adapterLabel} emitted $expectedVersion.',
      );
    }

    final adapterRunDirectory = Directory(capturedManifest.runDirectoryPath);
    for (final entry in capturedManifest.manifest.entries) {
      final previousOwner = ownerBySnapshotId[entry.id];
      if (previousOwner != null) {
        throw AmbientCliException(
          'Duplicate snapshot ID "${entry.id}" was emitted by adapters '
          '$previousOwner and ${capturedManifest.adapterLabel}.',
        );
      }
      ownerBySnapshotId[entry.id] = capturedManifest.adapterLabel;

      final absoluteImageUri = adapterRunDirectory.absolute.uri.resolve(
        entry.imagePath,
      );
      final rootPathPrefix = rootDirectory.absolute.uri.path;
      if (!absoluteImageUri.path.startsWith(rootPathPrefix)) {
        throw AmbientCliException(
          'Capture adapter ${capturedManifest.adapterLabel} wrote imagePath '
          '"${entry.imagePath}" outside the run directory.',
        );
      }
      final relativeImagePath = absoluteImageUri.path.substring(
        rootPathPrefix.length,
      );
      mergedEntries.add(
        ManifestEntry(
          id: entry.id,
          platform: entry.platform,
          variant: entry.variant,
          width: entry.width,
          height: entry.height,
          dpr: entry.dpr,
          contentHash: entry.contentHash,
          envFingerprint: entry.envFingerprint,
          imagePath: relativeImagePath,
        ),
      );
    }
  }

  return Manifest(manifestVersion: expectedVersion, entries: mergedEntries);
}

List<String> _defaultCommandFor(Platform platform) {
  return switch (platform) {
    Platform.flutter => const [_flutterDefaultCaptureCommand],
    Platform.reactNative => const [_reactNativeDefaultCaptureCommand],
  };
}

String _adapterLabel(Adapter adapter, int index) =>
    'adapter #${index + 1} (${adapter.platform.wireName})';

String _displayCommand(List<String> command, List<String> arguments) =>
    [...command, ...arguments].map(_quoteForDisplay).join(' ');

String _quoteForDisplay(String token) {
  if (token.isEmpty || token.contains(' ')) {
    return '"${token.replaceAll('"', '\\"')}"';
  }
  return token;
}

String _trimOutput(Object? output) => output?.toString().trim() ?? '';
