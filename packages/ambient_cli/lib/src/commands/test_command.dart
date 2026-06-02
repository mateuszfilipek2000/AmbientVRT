import 'dart:io';

import 'package:ambient_core/ambient_core.dart';
import 'package:args/args.dart';

import '../ambient_environment.dart';
import '../branch_context.dart';
import '../cli_exception.dart';
import '../orchestrator/capture_orchestrator.dart';
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
  String get invocation => 'test [options]';

  @override
  Future<int> run(ArgResults results, AmbientEnvironment environment) async {
    final resolvedBranches = await resolveBaselineBranchContext(
      environment: environment,
      requestedCompareBranch: results.option('branch'),
    );
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
      defaultBranch: resolvedBranches.defaultBranch,
    );
    final compareOptions = buildCompareOptions(loadedConfig.config);
    final reportDirectoryPath = environment.resolveFromCurrentDirectory(
      results.option('report-dir')!,
    );

    final deleteCapturedRunDirectory = orchestratedRunDirectory != null;
    try {
      final runResult = await compareRun(
        manifest: manifest,
        storage: storage,
        options: CompareRunOptions(
          runDirectoryPath: runDirectoryPath,
          compareOptions: compareOptions,
          branch: resolvedBranches.compareBranch,
          canonicalEnv: loadedConfig.config.canonicalEnv,
        ),
      );
      final report = await generateHtmlReport(
        runResult: runResult,
        outputDirectoryPath: reportDirectoryPath,
      );
      // Markdown twin of the report, for the CI Action's PR comment. Written
      // next to report.html so the uploaded artifact carries both.
      final summaryPath = environment.resolveFromDirectory(
        reportDirectoryPath,
        'summary.md',
      );
      await File(summaryPath).writeAsString(buildMarkdownSummary(runResult));

      environment.writeOut('Summary: ${formatSummary(runResult.summary)}');
      environment.writeOut('Report: ${report.reportPath}');
      if (runResult.probableRenames.isNotEmpty) {
        environment.writeOut(
          'Probable renames: ${runResult.probableRenames.length}',
        );
      }
      warnOnNonCanonicalCaptures(
        environment: environment,
        runResult: runResult,
      );

      if (runResult.summary.hasBlockingChanges ||
          runResult.summary.hasUnacceptedSnapshots) {
        return AmbientExitCode.comparisonFailed;
      }

      return AmbientExitCode.success;
    } finally {
      if (deleteCapturedRunDirectory) {
        await Directory(runDirectoryPath).delete(recursive: true);
      }
    }
  }
}
