import 'dart:io';

import 'package:ambient_core/ambient_core.dart';
import 'package:args/args.dart';

import '../ambient_environment.dart';
import '../cli_exception.dart';
import 'ambient_command.dart';

final class InitCommand extends AmbientCommand {
  InitCommand() : super() {
    argParser
      ..addOption(
        'output',
        defaultsTo: _defaultConfigFileName,
        help: 'Path to the config file to scaffold.',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Overwrite the target file if it already exists.',
      );
  }

  @override
  String get name => 'init';

  @override
  String get description => 'Scaffold an ambient.config.yaml file.';

  @override
  String get invocation => 'init [options]';

  @override
  Future<int> run(ArgResults results, AmbientEnvironment environment) async {
    final outputPath = environment.resolveFromCurrentDirectory(
      results.option('output')!,
    );
    final file = File(outputPath);
    final shouldForce = results.flag('force');

    if (!shouldForce && await file.exists()) {
      throw AmbientCliException(
        'Refusing to overwrite existing config at "$outputPath". Re-run with --force to replace it.',
        exitCode: AmbientExitCode.config,
      );
    }

    Config.fromYamlString(_defaultConfigTemplate);
    await file.parent.create(recursive: true);
    await file.writeAsString(_defaultConfigTemplate, flush: true);

    environment.writeOut('Wrote ${file.path}');
    return AmbientExitCode.success;
  }
}

const String _defaultConfigFileName = 'ambient.config.yaml';

const String _defaultConfigTemplate = '''adapters:
  - platform: flutter
    projectPath: ./
    # command: [ambient-flutter-capture]
  - platform: react-native
    storybookStaticDir: ./storybook-static
    # command: [ambient-rn-capture]
storage:
  backend: local
  path: .ambient/baselines
compare:
  threshold: 0.1
  perSnapshot: {}
variants: [light, dark]
canonicalEnv: ambient/capture-env@sha256:<digest>
''';
