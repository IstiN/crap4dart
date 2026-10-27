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

  test('flags escaped dollar with sibling interpolation', () async {
    final message = await singleViolation(project, r'''
void f(String name) {
  print('hello \$name, bye \$name!');
  g('$name');
}
''');
    expect(message, isNotNull);
    expect(message, contains(r"escaped interpolation '\$name'"));
  });

  test('flags escaped brace form with sibling interpolation', () async {
    final message = await singleViolation(project, r'''
void f(String name) {
  print('\${name} escaped');
  print('${name} real');
}
''');
    expect(message, isNotNull);
  });

  test('spares dollars without sibling evidence or ident suffix', () async {
    expect(
      await singleViolation(
        project,
        "void f() { run('export HOME=\\\$HOME && echo ok'); }\n",
      ),
      isNull,
    );
    expect(
      await singleViolation(
        project,
        "void f() { print('costs \\\$100 and ends \\\$'); }\n",
      ),
      isNull,
    );
  });

  test('spares raw strings entirely', () async {
    final message = await singleViolation(project, r'''
void f(String name) {
  print(r'hello \$name');
  print('$name');
}
''');
    expect(message, isNull);
  });

  test('escaped backslash hides a real interpolation', () async {
    final message = await singleViolation(project, r'''
void f(String name) {
  print('C:\\$name');
  print('$name');
}
''');
    expect(message, isNull);
  });

  test('serves each occurrence line once', () async {
    final result = await runOn(project, r'''
void f(String name) {
  print('\$name');
  print('\$name and \$name');
  print('$name');
}
''');
    expect(result.violations, hasLength(2));
  });
}
