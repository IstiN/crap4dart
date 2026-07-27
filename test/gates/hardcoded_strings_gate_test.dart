import 'dart:io';

import 'package:crap4dart/src/gates/hardcoded_strings_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = HardcodedStringsGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
    makeFlutterProject(project);
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('skips non-Flutter projects', () async {
    final plain = createTempProject();
    addTearDown(() => plain.deleteSync(recursive: true));
    writeFile(plain, 'lib/a.dart', "final t = Text('hello');\n");
    final result = await gate.run(makeContext(plain, ['lib/a.dart']));
    expect(result.skipped, isTrue);
    expect(result.skipReason, 'not a Flutter project');
  });

  test('flags string literals in Text(...)', () async {
    writeFile(project, 'lib/a.dart', '''
Widget build() => Text('Hello world');
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isFalse);
    expect(
      result.violations.single.message,
      contains("hardcoded string 'Hello world' in Text(...)"),
    );
  });

  test('flags checked named parameters', () async {
    writeFile(project, 'lib/a.dart', '''
Widget build() => Tooltip(tooltip: 'Подсказка', child: x);
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isFalse);
    expect(
      result.violations.single.message,
      contains("in parameter 'tooltip'"),
    );
  });

  test('flags interpolated strings with literal letters', () async {
    writeFile(project, 'lib/a.dart', '''
Widget build(String name) => Text('Hello \$name');
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isFalse);
  });

  test('ignores strings without letters', () async {
    writeFile(project, 'lib/a.dart', '''
Widget build() => Text(' ');
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isTrue);
  });
}
