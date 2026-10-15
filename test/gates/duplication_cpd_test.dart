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

  const clonesConfig = 'gates:\n  duplication:\n'
      '    report: clones\n';

  test('report: clones fails per clone group with all locations', () async {
    writeSingleMethod(project, 'lib/a.dart', 'processA');
    writeSingleMethod(project, 'lib/b.dart', 'processB');
    final result = await gate.run(
      makeContext(project, ['lib/a.dart', 'lib/b.dart'],
          configYaml: clonesConfig),
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    final v = result.violations.single;
    expect(v.message, startsWith('clone: '));
    expect(v.message, contains('2 occurrences: '));
    expect(v.message, contains('lib/a.dart:'));
    expect(v.message, contains('lib/b.dart:'));
  });

  test('report: clones passes a project without duplicates', () async {
    writeSingleMethod(project, 'lib/a.dart', 'processA');
    final result = await gate.run(
      makeContext(project, ['lib/a.dart'], configYaml: clonesConfig),
    );
    expect(result.passed, isTrue);
    expect(result.summary, contains('no clones'));
  });
}
