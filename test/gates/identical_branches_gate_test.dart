import 'package:test/test.dart';

import 'identical_branches_fixtures.dart';

void main() {
  test('flags an exact duplicate condition in an else-if chain', () async {
    final result = await runOn('''
String classify(int x) {
  if (x < 0) {
    return 'neg';
  } else if (x == 0) {
    return 'zero';
  } else if (x == 0) {
    return 'zero again';
  }
  return 'other';
}
''');
    expect(result.passed, isFalse);
    final violation = result.violations.single;
    expect(violation.line, 6);
    expect(violation.message, contains("'x == 0'"));
    expect(violation.message, contains('same as line 4'));
    expect(result.summary, contains('1 duplicate conditions'));
  });

  test('two repeats of the same condition produce two violations', () async {
    final result = await runOn('''
String classify(int x) {
  if (x == 0) {
    return 'a';
  } else if (x == 0) {
    return 'b';
  } else if (x == 0) {
    return 'c';
  }
  return 'd';
}
''');
    expect(result.violations, hasLength(2));
    expect(result.violations.map((v) => v.line), [4, 6]);
  });

  test('detects operand-reordered duplicates of commutative operators',
      () async {
    final result = await runOn('''
bool check(int a, int b, bool x, bool y) {
  if (a == b && x) {
    return y;
  } else if (x && (a == b)) {
    return false;
  }
  return true;
}
''');
    expect(result.passed, isFalse, reason: result.summary);
    expect(result.violations.single.line, 4);
  });

  test('formatting and whitespace do not hide a duplicate', () async {
    final result = await runOn('''
String classify(int x) {
  if (x==0) {
    return 'a';
  } else if (x  ==  0) {
    return 'b';
  }
  return 'c';
}
''');
    expect(result.passed, isFalse, reason: result.summary);
  });
}
