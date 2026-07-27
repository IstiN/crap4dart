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

  test('checks class methods and skips abstract ones', () async {
    writeFile(project, 'lib/a.dart', '''
abstract class A {
  void abstractMethod();
  void concrete() {
    var a = 1;
    var b = 2;
    var c = 3;
    var d = 4;
    print(a + b + c + d);
  }
}
''');
    final result = await gate.run(
      makeContext(project, ['lib/a.dart'], configYaml: config),
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(
      result.violations.single.message,
      contains('concrete has 7 lines > max 5'),
    );
  });

  test('constructors are checked only for parameters', () async {
    writeFile(project, 'lib/a.dart', '''
class A {
  A(int a, int b, int c, int d, int e, int f, int g)
      : x = a + b + c + d + e + f + g;
  final int x;
}
''');
    final result = await gate.run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml:
            'gates:\n  method_size:\n    max_lines: 1\n    max_params: 6\n',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(result.violations.single.message, contains('7 params > max 6'));
  });
}
