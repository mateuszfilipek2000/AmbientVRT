import 'package:ambient_core/ambient_core.dart';
import 'package:args/args.dart';

import '../ambient_environment.dart';
import '../cli_exception.dart';
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
  String get invocation => 'accept --run-dir <path> [options]';

  @override
  Future<int> run(ArgResults results, AmbientEnvironment environment) async {
    final runDirectoryPath = requireRunDirectory(
      environment: environment,
      runDirectory: results.option('run-dir'),
      usage: usage,
    );
    final branch = results.option('branch');
    final loadedConfig = await loadConfig(
      environment: environment,
      configPath: results.option('config')!,
    );
    final manifest = await loadManifest(
      environment: environment,
      runDirectoryPath: runDirectoryPath,
      manifestPath: results.option('manifest'),
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
  }
}
