import 'dart:io';

import 'package:crap4dart/src/gates/complexity_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = ComplexityGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  const config = 'gates:\n  complexity:\n    max_complexity: 2\n';

  test('passes methods within the limit', () async {
    writeFile(project, 'lib/a.dart', '''
int add(int a, int b) => a + b;
''');
    final result = await gate.run(
      makeContext(project, ['lib/a.dart'], configYaml: config),
    );
    expect(result.passed, isTrue);
  });

  test('fails methods above the limit', () async {
    writeFile(project, 'lib/a.dart', '''
class A {
  int f(int x) {
    if (x > 0) return 1;
    if (x < 0) return -1;
    return 0;
  }
}
''');
    final result = await gate.run(
      makeContext(project, ['lib/a.dart'], configYaml: config),
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(result.violations.single.line, 2);
    expect(
      result.violations.single.message,
      contains('A.f CC=3 > max 2'),
    );
  });
}
