import 'package:test/test.dart';

import 'identical_branches_fixtures.dart';

void main() {
  test('flags identical ternary branches', () async {
    final result = await runOn('''
int f(bool c, int x) {
  return c ? x : x;
}
''');
    expect(result.passed, isFalse, reason: result.summary);
    expect(
      result.violations.single.message,
      contains('identical then/else branches'),
    );
  });

  test('different ternary branches are legal', () async {
    final result = await runOn('''
int f(bool c, int x, int y) {
  return c ? x : y;
}
''');
    expect(result.passed, isTrue, reason: result.summary);
  });

  test('identical nested ternary branches are flagged too', () async {
    final result = await runOn('''
int f(bool c, bool d, int x, int y) {
  return c ? (d ? x : y) : (d ? x : y);
}
''');
    expect(result.passed, isFalse, reason: result.summary);
  });
}
