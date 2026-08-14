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

  test('passes files without magic constants', () async {
    writeFile(project, 'lib/clean.dart', '''
const limit = 42;

void a() => print(limit);
void b() => print('done');
''');
    final result = await gate.run(makeContext(project, ['lib/clean.dart']));
    expect(result.passed, isTrue);
  });

  test('counts adjacent strings as one literal', () async {
    writeFile(project, 'lib/adjacent.dart', '''
void a() => print('long message part one '
    'continued here');
void b() => print('long message part one '
    'continued here');
void c() => print('long message part one '
    'continued here');
''');
    final result = await gate.run(
      makeContext(project, ['lib/adjacent.dart']),
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(3));
  });
}
