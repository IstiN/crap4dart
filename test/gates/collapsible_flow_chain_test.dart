import 'package:test/test.dart';

import 'collapsible_flow_gate_test.dart' show runOn;

void main() {
  test('flags an else-if after an always-exiting then (chain hint)', () async {
    final result = await runOn('''
String f(int x) {
  if (x < 0) {
    return 'neg';
  } else if (x == 0) {
    return 'zero';
  }
  return 'pos';
}
''');
    expect(result.passed, isFalse);
    final violation = result.violations.single;
    expect(violation.line, 4);
    expect(violation.message, contains('flatten'));
  });

  test('a plain else after a terminal then is flagged, not the chain',
      () async {
    final result = await runOn('''
String f(bool c) {
  if (c) {
    return 'a';
  } else {
    if (c) {
      return 'x';
    }
    return 'y';
  }
}
''');
    expect(result.violations.single.line, 2);
    expect(result.violations.single.message, contains('dedent'));
  });

  test('canonical code produces no findings', () async {
    final result = await runOn('''
String f(int x, bool c) {
  if (x < 0) {
    return 'neg';
  }
  if (c) {
    print('a');
    if (x == 0) {
      print('b');
    }
  }
  return 'done';
}
''');
    expect(result.passed, isTrue, reason: result.summary);
    expect(result.summary, contains('no collapsible flow'));
  });

  test('violations carry the file and line for diff-mode filtering', () async {
    final result = await runOn('''
void f(bool a, bool b) {
  if (a) {
    if (b) {
      print('x');
    }
  }
}
''');
    final violation = result.violations.single;
    expect(violation.file, 'lib/main.dart');
    expect(violation.line, 2);
  });
}
