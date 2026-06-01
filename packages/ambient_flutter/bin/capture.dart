import 'dart:io';

import 'package:args/args.dart';

// Import the capture entrypoint directly (not the package barrel) so this
// executable stays free of any Flutter import and runs under a plain Dart VM —
// the Flutter code only runs inside the generated `flutter test` harness.
import 'package:ambient_flutter/src/capture/capture_project.dart';

/// Flutter capture adapter, conforming to the AmbientVRT capture subprocess
/// contract (see `docs/contracts.md`): the orchestrator appends `--out-dir`,
/// `--project-path`, `--variant` (repeated), and `--canonical-env`.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('out-dir', mandatory: true)
    ..addOption('project-path', mandatory: true)
    ..addOption('canonical-env')
    ..addMultiOption('variant')
    ..addOption('dpr', defaultsTo: '1.0');

  try {
    final args = parser.parse(arguments);
    final projectPath = args['project-path']! as String;
    final outputDirectory = args['out-dir']! as String;
    final canonicalEnv = args['canonical-env'] as String?;
    final variants = (args['variant'] as List<String>).toList(growable: false);
    final dpr = double.parse(args['dpr']! as String);

    final manifest = await captureFlutterPreviews(
      projectPath: projectPath,
      outputDirectory: outputDirectory,
      canonicalEnv: canonicalEnv,
      variants: variants,
      dpr: dpr,
    );
    stdout.writeln('Captured ${manifest.entries.length} Flutter previews.');
  } on ArgParserException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
