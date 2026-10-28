import 'package:test/test.dart';

import 'identical_branches_fixtures.dart';

void main() {
  test('flags a repeated operand in an || chain', () async {
    final result = await runOn('''
bool f(bool a, bool b) {
  return a || a || b;
}
''');
    expect(result.passed, isFalse, reason: result.summary);
    expect(result.violations.single.message, contains('duplicate operand'));
    expect(result.violations.single.message, contains("'||'"));
  });

  test('flags a repeated operand in an && chain', () async {
    final result = await runOn('''
bool f(bool a) {
  return a && a;
}
''');
    expect(result.passed, isFalse, reason: result.summary);
  });

  test('flags a repeated call operand (double invocation)', () async {
    final result = await runOn('''
bool f() {
  return ready() || ready();
}
''');
    expect(result.passed, isFalse, reason: result.summary);
  });

  test('distinct operands are legal', () async {
    final result = await runOn('''
bool f(bool a, bool b, bool c) {
  return a || b || c;
}
''');
    expect(result.passed, isTrue, reason: result.summary);
  });

  test('a nested different-operator chain is not a duplicate', () async {
    final result = await runOn('''
bool f(bool a, bool b) {
  return a && (b || a);
}
''');
    expect(result.passed, isTrue, reason: result.summary);
  });

  test('reordered commutative operands still collapse', () async {
    final result = await runOn('''
bool f(bool a, bool b) {
  return (a && b) || (b && a);
}
''');
    expect(result.passed, isFalse, reason: result.summary);
  });
}
