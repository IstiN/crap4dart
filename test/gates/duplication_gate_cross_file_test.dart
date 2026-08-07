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

  test('fails duplicated blocks across different files', () async {
    writeSingleMethod(project, 'lib/a.dart', 'processA');
    writeSingleMethod(project, 'lib/b.dart', 'processB');
    final result =
        await gate.run(makeContext(project, ['lib/a.dart', 'lib/b.dart']));
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(2));
    final files = result.violations.map((v) => v.file).toSet();
    expect(files, contains('lib/a.dart'));
    expect(files, contains('lib/b.dart'));
  });
}
