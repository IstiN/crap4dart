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

  test('ignores lines marked with the ignore marker', () async {
    writeFile(project, 'lib/a.dart', '''
Widget build() => Column(children: [
  // l10n:ignore
  Text('Hello'),
  Text('World'), // l10n:ignore
]);
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isTrue);
  });

  test('ignores files with the ignore-file marker', () async {
    writeFile(project, 'lib/a.dart', '''
// l10n:ignore-file
Widget build() => Text('Hello');
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isTrue);
  });

  test('flags l10n keys missing from app_en.arb', () async {
    writeFile(project, 'lib/l10n/app_en.arb', '{"appTitle": "App"}');
    writeFile(project, 'lib/a.dart', '''
String title() => l10n.appTitle;
String missing() => l10n.noSuchKey;
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(
      result.violations.single.message,
      contains("l10n key 'noSuchKey' missing from app_en.arb"),
    );
  });

  test('checks null-aware l10n property access against the arb', () async {
    writeFile(project, 'lib/l10n/app_en.arb', '{"appTitle": "App"}');
    writeFile(project, 'lib/a.dart', '''
String? title() => l10n?.appTitle;
String? missing() => l10n?.noSuchKey;
String? other() => obj?.whatever;
''');
    final result = await gate.run(makeContext(project, ['lib/a.dart']));
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(
      result.violations.single.message,
      contains("l10n key 'noSuchKey' missing from app_en.arb"),
    );
  });
}
