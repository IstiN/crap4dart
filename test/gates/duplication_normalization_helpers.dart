import 'dart:io';

import 'package:crap4dart/src/gates/duplication_gate.dart';
import 'package:crap4dart/src/gates/gate.dart';

import 'gate_test_utils.dart';

const _gate = DuplicationGate();

/// Runs the duplication gate over two files with the given contents.
Future<GateResult> runPair(
  Directory project,
  String contentA,
  String contentB, {
  bool? ignoreLocals,
  bool? ignoreLiterals,
}) {
  writeFile(project, 'lib/a.dart', contentA);
  writeFile(project, 'lib/b.dart', contentB);
  return _gate.run(makeContext(
    project,
    ['lib/a.dart', 'lib/b.dart'],
    configYaml: duplicationYaml(
        ignoreLocals: ignoreLocals, ignoreLiterals: ignoreLiterals),
  ));
}

/// Builds a `gates.duplication` YAML section.
String duplicationYaml(
    {bool? ignoreLocals, bool? ignoreLiterals, bool? badKey}) {
  final buffer = StringBuffer('gates:\n  duplication:\n');
  if (ignoreLocals != null) buffer.writeln('    ignore_locals: $ignoreLocals');
  if (ignoreLiterals != null) {
    buffer.writeln('    ignore_literals: $ignoreLiterals');
  }
  if (badKey != null) buffer.writeln('    ignore_localss: $badKey');
  return buffer.toString();
}
