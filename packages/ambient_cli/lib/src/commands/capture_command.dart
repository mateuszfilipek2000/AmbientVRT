import 'package:args/args.dart';

import '../ambient_environment.dart';
import '../cli_exception.dart';
import 'ambient_command.dart';

final class CaptureCommand extends AmbientCommand {
  @override
  String get name => 'capture';

  @override
  String get description =>
      'Reserved for adapter orchestration; wired in the next task.';

  @override
  String get invocation => 'capture [options]';

  @override
  Future<int> run(ArgResults results, AmbientEnvironment environment) async {
    throw const AmbientCliException(
      '`ambient capture` is reserved for the adapter orchestrator work in T3.2 and is not implemented yet.',
      exitCode: AmbientExitCode.notImplemented,
    );
  }
}
