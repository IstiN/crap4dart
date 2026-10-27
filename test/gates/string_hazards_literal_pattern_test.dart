import 'dart:io';

import 'package:test/test.dart';

import 'gate_test_utils.dart';
import 'string_hazards_fixture.dart';

void main() {
  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('flags leading caret in replaceFirst', () async {
    final message = await singleViolation(
        project, "final x = path.replaceFirst('^~/', '/');\n");
    expect(message, isNotNull);
    expect(message, contains("starts with '^'"));
  });

  test('flags trailing dollar in replaceAll', () async {
    final message = await singleViolation(
        project, r"final x = s.replaceAll(r'abc$', '');" '\n');
    expect(message, isNotNull);
    expect(message, contains(r"ends with '$'"));
  });

  test('flags mapped variants and split', () async {
    final result = await runOn(project, r'''
final a = s.replaceFirstMapped('^a', (m) => m[0]!);
final b = s.replaceAllMapped(r'a$', (m) => m[0]!);
final c = s.split('^');
''');
    expect(result.violations, hasLength(3));
  });

  test('spares escaped trailing dollar', () async {
    final message = await singleViolation(
        project, r"final x = s.replaceFirst('\$', '');" '\n');
    expect(message, isNull);
  });

  test('spares patterns without anchors', () async {
    final message = await singleViolation(
        project, "final x = s.replaceFirst('abc', 'x');\n");
    expect(message, isNull);
  });

  test('spares non-literal pattern arguments', () async {
    final message = await singleViolation(project, r'''
final pattern = '^abc';
final x = s.replaceFirst(pattern, '');
''');
    expect(message, isNull);
  });

  test('checks only the outer parts of adjacent strings', () async {
    final result = await runOn(project, r'''
final x = s.replaceFirst(r'^a' 'b' 'c', '');
final y = s.replaceFirst('a' r'b$' 'c', '');
''');
    expect(result.violations, hasLength(1));
    expect(result.violations.single.line, 1);
  });

  test('ignores bare calls without a target', () async {
    final message = await singleViolation(project, 'void f() { split(x); }\n');
    expect(message, isNull);
  });
}
