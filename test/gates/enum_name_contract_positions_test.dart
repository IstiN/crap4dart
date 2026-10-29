import 'dart:io';

import 'package:test/test.dart';

import 'gate_test_utils.dart';
import 'enum_name_contract_fixture.dart';

void main() {
  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('property-name and method-call positions are not reads', () async {
    final result = await runOn(project, '''
enum Color {
  red, green;

  void touch(Other other) {
    other.name = 'x';
    other.name();
  }
}

class Other {
  String name = '';
  void name() {}
}
''');
    expect(result.violations, isEmpty);
  });

  test('assignments to bare name are skipped', () async {
    final message = await singleViolation(project, '''
String name = 'x';

enum Color {
  red, green;

  void setIt() {
    name = 'x';
  }
}
''');
    expect(message, isNull);
  });

  test('non-enum receivers are not flagged', () async {
    final message = await singleViolation(project, '''
enum Color {
  red, green;

  static String describe(Token token) => token.name;
}

class Token {
  final String name;
  Token(this.name);
}
''');
    expect(message, isNull);
  });

  test('enum bodies with no members are handled', () async {
    final result = await runOn(project, 'enum Color { red, green }\n');
    expect(result.passed, isTrue, reason: '${result.violations}');
  });
}
