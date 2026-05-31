import 'dart:io';

import 'package:ambient_core/ambient_core.dart';
import 'package:args/args.dart';

import '../ambient_environment.dart';
import '../cli_exception.dart';
import '../orchestrator/capture_orchestrator.dart';
import 'ambient_command.dart';
import 'run_command_support.dart';

final class AcceptCommand extends AmbientCommand {
  AcceptCommand() : super() {
    argParser
      ..addOption(
        'run-dir',
        help: 'Directory containing manifest.json and captured PNGs.',
      )
      ..addOption(
        'manifest',
        help: 'Manifest path relative to --run-dir. Defaults to manifest.json.',
      )
      ..addOption(
        'config',
        defaultsTo: defaultConfigPath,
        help: 'Path to ambient.config.yaml.',
      )
      ..addMultiOption(
        'id',
        help: 'Limit acceptance to the specified snapshot ID(s).',
      )
      ..addOption('branch', help: 'Baseline branch namespace to write to.');
  }

  @override
  String get name => 'accept';

  @override
  String get description => 'Accept current captures as blessed baselines.';

  @override
  String get invocation => 'accept [options]';

  @override
  Future<int> run(ArgResults results, AmbientEnvironment environment) async {
    final branch = results.option('branch');
    final requestedRunDirectory = results.option('run-dir');
    final manifestPath = results.option('manifest');
    if (requestedRunDirectory == null && manifestPath != null) {
      throw AmbientUsageException(
        '--manifest can only be used together with --run-dir.',
        usage: usage,
      );
    }
    final loadedConfig = await loadConfig(
      environment: environment,
      configPath: results.option('config')!,
    );
    final orchestratedRunDirectory = requestedRunDirectory == null
        ? await captureConfiguredAdapters(
            loadedConfig: loadedConfig,
            environment: environment,
          )
        : null;
    final runDirectoryPath =
        orchestratedRunDirectory?.runDirectoryPath ??
        environment.resolveFromCurrentDirectory(requestedRunDirectory!);
    final manifest =
        orchestratedRunDirectory?.manifest ??
        await loadManifest(
          environment: environment,
          runDirectoryPath: runDirectoryPath,
          manifestPath: manifestPath,
        );
    final storage = createStorage(
      loadedConfig: loadedConfig,
      environment: environment,
      branch: branch,
    );
    final runResult = await compareRun(
      manifest: manifest,
      storage: storage,
      options: CompareRunOptions(
        runDirectoryPath: runDirectoryPath,
        compareOptions: buildCompareOptions(loadedConfig.config),
        branch: branch,
      ),
    );
    final ids = results.multiOption('id');
    final idsToAccept = ids.isEmpty ? null : ids.toSet();

    final deleteCapturedRunDirectory = orchestratedRunDirectory != null;
    try {
      await acceptRun(
        runResult,
        storage: storage,
        ids: idsToAccept,
        branch: branch,
      );

      environment.writeOut(
        'Accepted ${idsToAccept?.length ?? runResult.snapshots.length} snapshot(s).',
      );
      return AmbientExitCode.success;
    } finally {
      if (deleteCapturedRunDirectory) {
        await Directory(runDirectoryPath).delete(recursive: true);
      }
    }
  }
}
