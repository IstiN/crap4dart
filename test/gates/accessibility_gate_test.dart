import 'dart:io';

import 'package:crap4dart/src/gates/accessibility_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = AccessibilityGate();

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
    writeFile(plain, 'lib/a.dart', 'final b = IconButton();\n');
    final result = await gate.run(makeContext(plain, ['lib/a.dart']));
    expect(result.skipped, isTrue);
  });

  test('flags IconButton without tooltip', () async {
    writeFile(project, 'lib/a.dart', '''
Widget build() => IconButton(icon: Icon(Icons.add), onPressed: () {});
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isFalse);
    expect(
      result.violations.single.message,
      contains("IconButton missing 'tooltip'"),
    );
  });

  test('passes IconButton with tooltip', () async {
    writeFile(project, 'lib/a.dart', '''
Widget build() => IconButton(
  icon: Icon(Icons.add),
  tooltip: 'Add item',
  onPressed: () {},
);
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isTrue);
  });

  test('flags Image without semanticLabel', () async {
    writeFile(project, 'lib/a.dart', '''
Widget build() => Image.asset('a.png');
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isFalse);
    expect(
      result.violations.single.message,
      contains("Image missing 'semanticLabel'"),
    );
  });

  test('passes GestureDetector wrapped in Semantics', () async {
    writeFile(project, 'lib/a.dart', '''
Widget build() => Semantics(
  label: 'Tap area',
  child: GestureDetector(onTap: () {}, child: x),
);
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isTrue);
  });

  test('flags InkWell without label or Semantics wrapper', () async {
    writeFile(project, 'lib/a.dart', '''
Widget build() => InkWell(onTap: () {}, child: x);
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('InkWell'));
  });
}
