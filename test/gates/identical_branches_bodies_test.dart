import 'package:test/test.dart';

import 'identical_branches_fixtures.dart';

void main() {
  test('flags identical then-bodies across an else-if chain', () async {
    final result = await runOn('''
String f(bool a, bool b) {
  if (a) {
    return 'x';
  } else if (b) {
    return 'x';
  }
  return 'y';
}
''');
    expect(result.passed, isFalse, reason: result.summary);
    expect(result.violations.single.line, 5);
    expect(result.violations.single.message, contains('duplicate branch body'));
    expect(result.violations.single.message, contains('same as line 3'));
  });

  test('flags an else body equal to its then body', () async {
    final result = await runOn('''
String f(bool a) {
  if (a) {
    return 'x';
  } else {
    return 'x';
  }
  return 'y';
}
''');
    expect(result.passed, isFalse, reason: result.summary);
    expect(result.violations.single.message, contains('duplicate branch body'));
  });

  test('a single-statement block equals the naked statement', () async {
    final result = await runOn('''
String f(bool a, bool b) {
  if (a) return 'x';
  else if (b) { return 'x'; }
  return 'y';
}
''');
    expect(result.passed, isFalse, reason: result.summary);
  });

  test('identical bodies in separate ifs are legal', () async {
    final result = await runOn('''
String f(bool a, bool b) {
  if (a) {
    return 'x';
  }
  if (b) {
    return 'x';
  }
  return 'y';
}
''');
    expect(result.passed, isTrue, reason: result.summary);
  });
}
