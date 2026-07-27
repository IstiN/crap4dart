import 'dart:io';

import 'package:crap4dart/src/gates/method_size_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = MethodSizeGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  const config =
      'gates:\n  method_size:\n    max_lines: 5\n    max_params: 3\n';

  test('passes small methods', () async {
    writeFile(project, 'lib/a.dart', '''
int add(int a, int b) => a + b;
''');
    final result = await gate.run(
      makeContext(project, ['lib/a.dart'], configYaml: config),
    );
    expect(result.passed, isTrue);
  });

  test('fails methods longer than max_lines', () async {
    writeFile(project, 'lib/a.dart', '''
void big() {
  var a = 1;
  var b = 2;
  var c = 3;
  var d = 4;
  print(a + b + c + d);
}
''');
    final result = await gate.run(
      makeContext(project, ['lib/a.dart'], configYaml: config),
    );
    expect(result.passed, isFalse);
    expect(
      result.violations.single.message,
      contains('big has 7 lines > max 5'),
    );
  });

  test('fails signatures with more than max_params', () async {
    writeFile(project, 'lib/a.dart', '''
int f(int a, int b, int c, int d) => a + b + c + d;
''');
    final result = await gate.run(
      makeContext(project, ['lib/a.dart'], configYaml: config),
    );
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('4 params > max 3'));
  });
}
