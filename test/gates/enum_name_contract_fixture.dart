import 'dart:io';

import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/quality/enum_name_contract_gate.dart';

import 'gate_test_utils.dart';

/// Shared fixture harness for the enum_name_contract gate tests.
const enumNameContractGate = EnumNameContractGate();

/// Writes [body] to `lib/a.dart` and returns the gate's single violation
/// message, or `null` when the gate passes.
Future<String?> singleViolation(Directory project, String body) async {
  final result = await runOn(project, body);
  if (result.passed) return null;
  return result.violations.single.message;
}

/// Runs the gate over [body] and returns its full result.
Future<GateResult> runOn(Directory project, String body) async {
  writeFile(project, 'lib/a.dart', body);
  return enumNameContractGate.run(makeContext(project, ['lib/a.dart']));
}
