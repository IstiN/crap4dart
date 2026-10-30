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

  test('flags this.name and this.index inside instance members', () async {
    final result = await runOn(project, '''
enum Color {
  red, green;

  String get label => this.name;
  int get position => this.index;
}
''');
    expect(result.violations, hasLength(2));
    expect(
      result.violations.every((v) => v.message.contains("'Color'")),
      isTrue,
    );
  });

  test('flags bare name/index as implicit this in instance members', () async {
    final result = await runOn(project, '''
enum Color {
  red, green;

  String get label => name;
}
''');
    expect(result.violations, hasLength(1));
    expect(result.violations.single.line, 4);
  });

  test('flags constant receivers and qualified constant receivers', () async {
    final result = await runOn(project, '''
enum Color {
  red, green;

  static String labelOfRed() => red.name;
  static int indexOfGreen() => Color.green.index;
}
''');
    expect(result.violations, hasLength(2));
  });
}
