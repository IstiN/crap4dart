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

  test('flags values loop variables and values index accesses', () async {
    final result = await runOn(project, '''
enum Color {
  red, green;

  static List<String> allLabels() {
    final labels = <String>[];
    for (final c in values) {
      labels.add(c.name);
    }
    labels.add(values[0].name);
    labels.add(Color.values[1].index.toString());
    return labels;
  }
}
''');
    expect(result.violations, hasLength(3));
  });

  test('flags parameters typed with the enclosing enum', () async {
    final message = await singleViolation(project, '''
enum Color {
  red, green;

  static String describe(Color c) => c.name;
}
''');
    expect(message, isNotNull);
    expect(message, contains("contracts on the built-in '.name'"));
    expect(message, contains('final String value'));
  });

  test('flags .index as its own finding', () async {
    final message = await singleViolation(project, '''
enum Color {
  red, green;

  int get position => index;
}
''');
    expect(message, isNotNull);
    expect(message, contains("'.index'"));
  });
}
