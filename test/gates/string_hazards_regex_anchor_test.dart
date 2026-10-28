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

  test('flags raw pattern ending with escaped dollar', () async {
    final message = await singleViolation(
        project, r"final re = RegExp(r'[0-9a-f]{12}\$');" '\n');
    expect(message, isNotNull);
    expect(message, contains('not the end anchor'));
  });

  test('flags raw pattern starting with escaped caret', () async {
    final message =
        await singleViolation(project, r"final re = RegExp(r'\^abc');" '\n');
    expect(message, isNotNull);
    expect(message, contains('not the start anchor'));
  });

  test('spares raw pattern with plain dollar anchor', () async {
    final message = await singleViolation(
        project, r"final re = RegExp(r'[0-9a-f]{12}$');" '\n');
    expect(message, isNull);
  });

  test('spares raw pattern with plain caret anchor', () async {
    final message =
        await singleViolation(project, r"final re = RegExp(r'^abc');" '\n');
    expect(message, isNull);
  });

  test('spares non-raw pattern with escaped dollar', () async {
    final message = await singleViolation(
        project, r"final re = RegExp('[0-9a-f]{12}\$');" '\n');
    expect(message, isNull);
  });

  test('flags const RegExp invocation too', () async {
    final message = await singleViolation(
        project, r"final re = const RegExp(r'[0-9a-f]{12}\$');" '\n');
    expect(message, isNotNull);
  });

  test('spares raw escaped dollar outside RegExp', () async {
    final message = await singleViolation(project, "const s = r'costs \$';\n");
    expect(message, isNull);
  });

  test('skips non-literal and named non-source arguments', () async {
    final message = await singleViolation(project, r'''
final pattern = r'[0-9]{12}\$';
final a = RegExp(pattern);
final b = RegExp(r'[a-z]$', multiLine: true);
''');
    expect(message, isNull);
  });
}
