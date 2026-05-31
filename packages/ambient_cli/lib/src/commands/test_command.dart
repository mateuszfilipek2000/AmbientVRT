import 'package:ambient_core/ambient_core.dart';
import 'package:args/args.dart';

import '../ambient_environment.dart';
import '../cli_exception.dart';
import 'ambient_command.dart';
import 'run_command_support.dart';

final class TestCommand extends AmbientCommand {
  TestCommand() : super() {
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
      ..addOption(
        'report-dir',
        defaultsTo: defaultReportDirectory,
        help: 'Directory where report.html and assets are written.',
      )
      ..addOption(
        'branch',
        help: 'Baseline branch namespace to compare against.',
      );
  }

  @override
  String get name => 'test';

  @override
  String get description =>
      'Compare a captured manifest against accepted baselines and emit a report.';

  @override
  String get invocation => 'test --run-dir <path> [options]';

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
    final compareOptions = buildCompareOptions(loadedConfig.config);
    final reportDirectoryPath = environment.resolveFromCurrentDirectory(
      results.option('report-dir')!,
    );

    final runResult = await compareRun(
      manifest: manifest,
      storage: storage,
      options: CompareRunOptions(
        runDirectoryPath: runDirectoryPath,
        compareOptions: compareOptions,
        branch: branch,
      ),
    );
    final report = await generateHtmlReport(
      runResult: runResult,
      outputDirectoryPath: reportDirectoryPath,
    );

    environment.writeOut('Summary: ${formatSummary(runResult.summary)}');
    environment.writeOut('Report: ${report.reportPath}');
    if (runResult.probableRenames.isNotEmpty) {
      environment.writeOut(
        'Probable renames: ${runResult.probableRenames.length}',
      );
    }

    if (runResult.summary.hasBlockingChanges ||
        runResult.summary.hasUnacceptedSnapshots) {
      return AmbientExitCode.comparisonFailed;
    }

    return AmbientExitCode.success;
  }
}
