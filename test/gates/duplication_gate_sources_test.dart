import 'dart:io';

import 'package:crap4dart/src/gates/duplication_gate.dart';
import 'package:test/test.dart';

import 'duplication_gate_fixtures.dart';
import 'gate_test_utils.dart';

void main() {
  const gate = DuplicationGate();

  late Directory project;

  setUp(() => project = createTempProject());

  tearDown(() => project.deleteSync(recursive: true));

  test('per-gate sources pull in files outside the analyzed source set',
      () async {
    // Cross-module setup: `extra/` is NOT part of the analyzed source set
    // (only lib/a.dart is), but the gate's sources add it to the scan.
    writeSingleMethod(project, 'lib/a.dart', 'processA');
    writeSingleMethod(project, 'extra/b.dart', 'processB');
    final result = await gate.run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: '''
gates:
  duplication:
    enabled: true
    sources: [extra]
''',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations.map((v) => v.file), contains('extra/b.dart'));
  });

  test('without per-gate sources the extra module stays unseen', () async {
    writeSingleMethod(project, 'lib/a.dart', 'processA');
    writeSingleMethod(project, 'extra/b.dart', 'processB');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isTrue);
  });

  test('per-gate sources accept a direct .dart file path', () async {
    writeSingleMethod(project, 'lib/a.dart', 'processA');
    writeSingleMethod(project, 'extra/b.dart', 'processB');
    final result = await gate.run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: '''
gates:
  duplication:
    enabled: true
    sources: [extra/b.dart]
''',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations.map((v) => v.file), contains('extra/b.dart'));
  });

  test('per-gate sources skip missing paths silently', () async {
    writeSingleMethod(project, 'lib/a.dart', 'processA');
    final result = await gate.run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: '''
gates:
  duplication:
    enabled: true
    sources: [does_not_exist]
''',
      ),
    );
    expect(result.passed, isTrue);
  });
}
