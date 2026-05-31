/// The `ambient` CLI: command parsing and orchestration over [ambient_core].
library;

import 'dart:io' as io;

import 'package:ambient_core/ambient_core.dart';

import 'src/ambient_environment.dart';
import 'src/ambient_runner.dart';
import 'src/cli_exception.dart';
import 'src/commands/accept_command.dart';
import 'src/commands/capture_command.dart';
import 'src/commands/init_command.dart';
import 'src/commands/test_command.dart';

export 'src/cli_exception.dart' show AmbientCliException, AmbientExitCode;

/// Marker for the CLI package version, kept in step with the core.
const String ambientCliVersion = ambientCoreVersion;

/// Runs the AmbientVRT CLI with injectable output and working-directory
/// dependencies so the executable stays easy to test.
Future<int> runAmbient(
  List<String> arguments, {
  StringSink? stdout,
  StringSink? stderr,
  String? currentDirectoryPath,
}) async {
  final environment = AmbientEnvironment.system(
    stdout: stdout,
    stderr: stderr,
    currentDirectoryPath: currentDirectoryPath,
  );
  final runner = AmbientRunner(
    commands: [InitCommand(), TestCommand(), CaptureCommand(), AcceptCommand()],
  );

  try {
    return await runner.run(arguments, environment);
  } on AmbientCliException catch (error) {
    environment.writeErr(error.toString());
    return error.exitCode;
  } on io.FileSystemException catch (error) {
    environment.writeErr(error.message);
    return AmbientExitCode.software;
  } catch (error) {
    environment.writeErr(error.toString());
    return AmbientExitCode.software;
  }
}
