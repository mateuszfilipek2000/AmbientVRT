import 'package:args/args.dart';

import '../ambient_environment.dart';
import '../cli_exception.dart';
import '../orchestrator/capture_orchestrator.dart';
import 'ambient_command.dart';
import 'run_command_support.dart';

final class CaptureCommand extends AmbientCommand {
  CaptureCommand() : super() {
    argParser
      ..addOption(
        'config',
        defaultsTo: defaultConfigPath,
        help: 'Path to ambient.config.yaml.',
      )
      ..addOption(
        'run-dir',
        help: 'Directory where adapters should emit manifest.json and PNGs.',
      );
  }

  @override
  String get name => 'capture';

  @override
  String get description =>
      'Run the configured capture adapters and emit a run directory.';

  @override
  String get invocation => 'capture [options]';

  @override
  Future<int> run(ArgResults results, AmbientEnvironment environment) async {
    final loadedConfig = await loadConfig(
      environment: environment,
      configPath: results.option('config')!,
    );
    final runDirectoryPath = results.option('run-dir');
    final captureRun = await captureConfiguredAdapters(
      loadedConfig: loadedConfig,
      environment: environment,
      runDirectoryPath: runDirectoryPath == null
          ? null
          : environment.resolveFromCurrentDirectory(runDirectoryPath),
    );
    environment.writeOut(
      'Captured ${captureRun.manifest.entries.length} snapshot(s).',
    );
    environment.writeOut('Run directory: ${captureRun.runDirectoryPath}');
    environment.writeOut(
      'Manifest: ${environment.resolveFromDirectory(captureRun.runDirectoryPath, defaultManifestFileName)}',
    );
    return AmbientExitCode.success;
  }
}
