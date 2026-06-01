import 'dart:io';

import 'package:ambient_core/ambient_core.dart';

import '../ambient_environment.dart';
import '../cli_exception.dart';

const String defaultConfigPath = 'ambient.config.yaml';
const String defaultManifestFileName = 'manifest.json';
const String defaultReportDirectory = '.ambient/report';

final class LoadedConfig {
  const LoadedConfig({
    required this.path,
    required this.directoryPath,
    required this.config,
  });

  final String path;
  final String directoryPath;
  final Config config;
}

Future<LoadedConfig> loadConfig({
  required AmbientEnvironment environment,
  required String configPath,
}) async {
  final resolvedPath = environment.resolveFromCurrentDirectory(configPath);
  final file = File(resolvedPath);
  if (!await file.exists()) {
    throw AmbientCliException(
      'Config file not found at "$resolvedPath".',
      exitCode: AmbientExitCode.config,
    );
  }

  try {
    return LoadedConfig(
      path: resolvedPath,
      directoryPath: file.parent.path,
      config: Config.fromYamlString(await file.readAsString()),
    );
  } on ConfigFormatException catch (error) {
    throw AmbientCliException(
      'Invalid config at "$resolvedPath": $error',
      exitCode: AmbientExitCode.config,
    );
  }
}

Future<Manifest> loadManifest({
  required AmbientEnvironment environment,
  required String runDirectoryPath,
  String? manifestPath,
}) async {
  final resolvedManifestPath = manifestPath == null
      ? environment.resolveFromDirectory(
          runDirectoryPath,
          defaultManifestFileName,
        )
      : environment.resolveFromDirectory(runDirectoryPath, manifestPath);
  final file = File(resolvedManifestPath);
  if (!await file.exists()) {
    throw AmbientCliException(
      'Manifest file not found at "$resolvedManifestPath".',
      exitCode: AmbientExitCode.config,
    );
  }

  try {
    return Manifest.fromJsonString(await file.readAsString());
  } on ManifestFormatException catch (error) {
    throw AmbientCliException(
      'Invalid manifest at "$resolvedManifestPath": $error',
      exitCode: AmbientExitCode.config,
    );
  }
}

BaselineStorage createStorage({
  required LoadedConfig loadedConfig,
  required AmbientEnvironment environment,
  String? defaultBranch,
}) {
  switch (loadedConfig.config.storage.backend) {
    case StorageBackend.local:
      return LocalStorageBackend(
        directoryPath: environment.resolveFromDirectory(
          loadedConfig.directoryPath,
          loadedConfig.config.storage.path!,
        ),
        defaultBranch: defaultBranch,
      );
    case StorageBackend.s3:
      throw const AmbientCliException(
        'The "s3" storage backend is not implemented yet.',
        exitCode: AmbientExitCode.notImplemented,
      );
  }
}

CompareOptions buildCompareOptions(Config config) {
  final compare = config.compare;
  if (compare == null || compare.threshold == null) {
    if (compare != null && compare.perSnapshot.isNotEmpty) {
      throw const AmbientCliException(
        'compare.perSnapshot overrides are not wired through the CLI yet.',
        exitCode: AmbientExitCode.notImplemented,
      );
    }
    return const CompareOptions();
  }
  if (compare.perSnapshot.isNotEmpty) {
    throw const AmbientCliException(
      'compare.perSnapshot overrides are not wired through the CLI yet.',
      exitCode: AmbientExitCode.notImplemented,
    );
  }

  return CompareOptions(threshold: compare.threshold!);
}

String requireRunDirectory({
  required AmbientEnvironment environment,
  required String? runDirectory,
  required String usage,
}) {
  if (runDirectory == null || runDirectory.isEmpty) {
    throw AmbientUsageException(
      'Missing required option --run-dir.',
      usage: usage,
    );
  }

  return environment.resolveFromCurrentDirectory(runDirectory);
}

String formatSummary(CompareRunSummary summary) {
  return 'passed=${summary.passed}, changed=${summary.changed}, '
      'new=${summary.newSnapshots}, size-changed=${summary.sizeChanged}';
}

/// Emits a non-blocking warning listing any snapshots captured outside the
/// configured canonical capture-env (backlog T6.1). No-op when the config
/// declares no `canonicalEnv` or every capture is canonical.
void warnOnNonCanonicalCaptures({
  required AmbientEnvironment environment,
  required CompareRunResult runResult,
}) {
  if (!runResult.hasNonCanonicalCaptures) {
    return;
  }
  final ids = [
    for (final snapshot in runResult.nonCanonicalCaptures) snapshot.id,
  ]..sort();
  final expected = runResult.canonicalEnv;
  environment.writeErr(
    'Warning: ${ids.length} snapshot(s) were captured outside the canonical '
    'capture-env${expected == null ? '' : ' ($expected)'}. '
    'Their pixels may not be reproducible: ${ids.join(', ')}.',
  );
}
