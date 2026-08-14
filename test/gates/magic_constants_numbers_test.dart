import 'dart:io';

import 'package:crap4dart/src/gates/magic_constants_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = MagicConstantsGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('honors the exclude globs', () async {
    writeFile(project, 'lib/generated.g.dart', '''
void a() => print('same-value');
void b() => print('same-value');
void c() => print('same-value');
''');
    final result = await gate.run(
      makeContext(project, ['lib/generated.g.dart']),
    );
    expect(result.passed, isTrue);
  });

  test('flags repeated numeric literals', () async {
    writeFile(project, 'lib/numbers.dart', '''
int a() => 1000;
int b() => 1000;
int c() => 1000;
int d() => 7;
''');
    final result = await gate.run(makeContext(project, ['lib/numbers.dart']));
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(3));
    expect(
      result.violations.every((v) => v.message.contains('1000')),
      isTrue,
    );
  });

  test('honors min_duplicates and flag_hex_colors config', () async {
    writeFile(project, 'lib/cfg.dart', '''
void a() => print('same-value');
void b() => print('same-value');
void c() => Container(color: Color(0xFF123456));
''');
    final result = await gate.run(
      makeContext(
        project,
        ['lib/cfg.dart'],
        configYaml: '''
gates:
  magic_constants:
    min_duplicates: 2
    flag_hex_colors: false
''',
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(2));
    expect(
      result.violations.every((v) => v.message.contains('repeats 2 times')),
      isTrue,
    );
  });
}
