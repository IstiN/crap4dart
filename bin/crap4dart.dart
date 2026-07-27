import 'dart:io';

import 'package:crap4dart/src/cli/runner.dart';

/// Entry point of the crap4dart executable.
Future<void> main(List<String> args) async {
  final code = await Crap4DartRunner().run(args);
  if (code != 0) exitCode = code;
}
