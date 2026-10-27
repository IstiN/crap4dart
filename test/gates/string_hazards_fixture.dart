import 'dart:io';

import 'package:crap4dart/src/gates/content/string_hazards_gate.dart';
import 'package:crap4dart/src/gates/gate.dart';

import 'gate_test_utils.dart';

/// Shared fixture harness for the string_hazards gate tests.
const stringHazardsGate = StringHazardsGate();

/// Writes [body] to `lib/a.dart` and returns the gate's single violation
/// message, or `null` when the gate passes.
Future<String?> singleViolation(Directory project, String body) async {
  writeFile(project, 'lib/a.dart', body);
  final result = await stringHazardsGate.run(
    makeContext(project, ['lib/a.dart']),
  );
  if (result.passed) return null;
  return result.violations.single.message;
}

/// Runs the gate over [body] and returns its full result.
Future<GateResult> runOn(Directory project, String body) async {
  writeFile(project, 'lib/a.dart', body);
  return stringHazardsGate.run(makeContext(project, ['lib/a.dart']));
}
