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

  test('a declared name member shadows the built-in', () async {
    final message = await singleViolation(project, '''
enum Color {
  red, green;

  final String name;
  const Color(this.name);

  String get label => this.name;
  static String ofRed() => red.name;
}
''');
    expect(message, isNull);
  });

  test('a declared index member shadows the built-in', () async {
    final message = await singleViolation(project, '''
enum Color {
  red, green;

  final int index;
  const Color(this.index);
}
''');
    expect(message, isNull);
  });

  test('static members do not treat bare name as implicit this', () async {
    final message = await singleViolation(project, '''
String name = 'x';

enum Color {
  red, green;

  static String topName() => name;
}
''');
    expect(message, isNull);
  });

  test('locals shadow the implicit this', () async {
    final message = await singleViolation(project, '''
enum Color {
  red, green;

  String localName() {
    final name = 'x';
    return name;
  }
}
''');
    expect(message, isNull);
  });

  test('parameters shadow the implicit this', () async {
    final message = await singleViolation(project, '''
enum Color {
  red, green;

  String echo(String name) => name;
}
''');
    expect(message, isNull);
  });
}
