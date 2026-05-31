import 'package:args/args.dart';

import '../ambient_cli.dart';
import 'ambient_environment.dart';
import 'cli_exception.dart';
import 'commands/ambient_command.dart';

final class AmbientRunner {
  AmbientRunner({required List<AmbientCommand> commands})
    : _commands = List.unmodifiable(commands),
      _commandsByName = {for (final command in commands) command.name: command},
      _parser = (ArgParser(allowTrailingOptions: false)
        ..addFlag(
          'help',
          abbr: 'h',
          negatable: false,
          help: 'Show usage information.',
        )
        ..addFlag(
          'version',
          negatable: false,
          help: 'Print the AmbientVRT CLI version.',
        )) {
    for (final command in commands) {
      _parser.addCommand(command.name, command.argParser);
    }
  }

  final List<AmbientCommand> _commands;
  final Map<String, AmbientCommand> _commandsByName;
  final ArgParser _parser;

  Future<int> run(
    List<String> arguments,
    AmbientEnvironment environment,
  ) async {
    final ArgResults results;
    try {
      results = _parser.parse(arguments);
    } on FormatException catch (error) {
      throw AmbientUsageException(error.message, usage: usage);
    }

    if (results['version'] as bool) {
      environment.writeOut('ambient $ambientCliVersion');
      return AmbientExitCode.success;
    }

    final selectedCommand = results.command;
    if (selectedCommand != null) {
      final command = _commandsByName[selectedCommand.name];
      if (command == null) {
        throw AmbientUsageException(
          'Unknown command "${selectedCommand.name}".',
          usage: usage,
        );
      }
      if (selectedCommand['help'] as bool) {
        environment.writeOut(command.usage);
        return AmbientExitCode.success;
      }

      return command.run(selectedCommand, environment);
    }

    if (results['help'] as bool) {
      environment.writeOut(usage);
      return AmbientExitCode.success;
    }

    throw AmbientUsageException('Missing command.', usage: usage);
  }

  String get usage {
    final width = _commands.fold<int>(
      0,
      (current, command) =>
          current > command.name.length ? current : command.name.length,
    );
    final buffer = StringBuffer()
      ..writeln('AmbientVRT CLI')
      ..writeln()
      ..writeln('Usage: ambient <command> [arguments]')
      ..writeln()
      ..writeln('Global options:')
      ..writeln('  -h, --help       Show usage information.')
      ..writeln('      --version    Print the AmbientVRT CLI version.')
      ..writeln()
      ..writeln('Commands:');

    for (final command in _commands) {
      final paddedName = command.name.padRight(width);
      buffer.writeln('  $paddedName  ${command.description}');
    }

    return buffer.toString().trimRight();
  }
}
