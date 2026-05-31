import 'package:args/args.dart';

import '../ambient_environment.dart';

abstract base class AmbientCommand {
  AmbientCommand() : argParser = ArgParser(allowTrailingOptions: false) {
    argParser.addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    );
  }

  final ArgParser argParser;

  String get name;

  String get description;

  String get invocation;

  String get usage {
    final buffer = StringBuffer()
      ..writeln('Usage: ambient $invocation')
      ..writeln()
      ..writeln(description)
      ..writeln()
      ..writeln('Options:')
      ..write(argParser.usage);

    return buffer.toString().trimRight();
  }

  Future<int> run(ArgResults results, AmbientEnvironment environment);
}
