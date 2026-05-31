import 'dart:io';

import 'package:ambient_cli/ambient_cli.dart';

Future<void> main(List<String> arguments) async {
  exit(await runAmbient(arguments));
}
