import 'package:test/test.dart';

import 'identical_branches_fixtures.dart';

void main() {
  test('flags a partial identifier repeat in one call', () async {
    final result = await runOn('''
int f(int width, int height) {
  return measure(width, height, width);
}
''');
    expect(result.passed, isFalse, reason: result.summary);
    expect(result.violations.single.message, contains("call to 'measure'"));
    expect(result.violations.single.message, contains('same as argument 1'));
  });

  test('named-argument repeats are self-documenting, not flagged', () async {
    final result = await runOn('''
int f(int x, int y) {
  return box(a: x, b: y, c: x);
}
''');
    expect(result.passed, isTrue, reason: result.summary);
  });

  test('all-identical arguments are a uniform value, not a bug', () async {
    final result = await runOn('''
int f(int x) {
  return box(a: x, b: x, c: x);
}
''');
    expect(result.passed, isTrue, reason: result.summary);
  });

  test('literal repeats are exempt (layout code)', () async {
    final result = await runOn('''
int f() {
  return edges(8, 8, 8, 4);
}
''');
    expect(result.passed, isTrue, reason: result.summary);
  });

  test('distinct arguments are legal', () async {
    final result = await runOn('''
int f(int a, int b) {
  return measure(a, b);
}
''');
    expect(result.passed, isTrue, reason: result.summary);
  });
}
