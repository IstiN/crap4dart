import 'package:test/test.dart';

import 'gate_test_utils.dart';
import 'identical_branches_fixtures.dart';

void main() {
  test('non-commutative operators are not reordered', () async {
    final result = await runOn('''
String classify(int a, int b) {
  if (a < b) {
    return 'lt';
  } else if (b < a) {
    return 'gt';
  } else if (a - b == 1) {
    return 'next';
  } else if (b - a == 1) {
    return 'prev';
  }
  return 'eq';
}
''');
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('if-case links are skipped: their decision is a pattern', () async {
    final result = await runOn('''
String classify(Object x) {
  if (x case int y) {
    return 'int';
  } else if (x case String s) {
    return 'string';
  }
  return 'other';
}
''');
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('conditions in different methods never compare', () async {
    final result = await runOn('''
String a(int x) {
  if (x == 0) {
    return 'zero';
  }
  return 'other';
}

String b(int x) {
  if (x == 0) {
    return 'zero';
  }
  return 'other';
}
''');
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('violations carry file paths relative to the project root', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/src/deep/a.dart', '''
String classify(int x) {
  if (x == 0) {
    return 'a';
  } else if (x == 0) {
    return 'b';
  }
  return 'c';
}
''');
    final result = await runOnFiles(
      ['${project.path}/lib/src/deep/a.dart'],
      project,
    );
    expect(result.violations.single.file, 'lib/src/deep/a.dart');
  });
}
