import 'dart:io';

import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/identical_branches_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

/// Runs the identical-branches gate over [source], written to
/// `lib/a.dart` of a fresh temp project (torn down with the test).
Future<GateResult> runOn(String source) async {
  final project = createTempProject();
  addTearDown(() => project.deleteSync(recursive: true));
  writeFile(project, 'lib/a.dart', source);
  return const IdenticalBranchesGate()
      .run(makeContext(project, ['lib/a.dart']));
}

/// Runs the identical-branches gate over the given absolute file paths
/// of a fresh temp project (torn down with the test).
Future<GateResult> runOnFiles(List<String> absolutePaths, Directory root) {
  return const IdenticalBranchesGate().run(makeContext(root, absolutePaths));
}
