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

  test('passes when there are no duplicated blocks', () async {
    writeFile(project, 'lib/a.dart', 'void main() { print(1); }\n');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isTrue);
    expect(result.skipped, isFalse);
    expect(result.violations, isEmpty);
  });

  test('fails files with duplicated blocks over the threshold', () async {
    writeDuplicatedFile(project, 'lib/a.dart', 'processA', 'processB');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(result.violations.single.file, 'lib/a.dart');
    expect(result.violations.single.message, contains('% duplicated lines'));
  });

  test('honors the exclude globs', () async {
    writeDuplicatedFile(project, 'test/a_test.dart', 'helperA', 'helperB');
    final result = await gate.run(makeContext(project, ['test/a_test.dart']));
    expect(result.passed, isTrue);
  });
}
