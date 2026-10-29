import 'package:test/test.dart';

import 'collapsible_flow_gate_test.dart' show runOn;

void main() {
  test('does not merge when the outer condition is a pattern', () async {
    final result = await runOn('''
void f(Object message) {
  if (message case String text) {
    if (text.isEmpty) {
      print('empty');
    }
  }
}
''');
    expect(result.passed, isTrue);
  });

  test('does not merge when the inner if has an else', () async {
    final result = await runOn('''
void f(bool a, bool b) {
  if (a) {
    if (b) {
      print('x');
    } else {
      print('y');
    }
  }
}
''');
    expect(result.passed, isTrue);
  });

  test('does not merge when the outer if has an else', () async {
    final result = await runOn('''
void f(bool a, bool b) {
  if (a) {
    if (b) {
      print('x');
    }
  } else {
    print('z');
  }
}
''');
    expect(result.passed, isTrue);
  });

  test('does not merge when the then-block has extra statements', () async {
    final result = await runOn('''
void f(bool a, bool b) {
  if (a) {
    print('before');
    if (b) {
      print('x');
    }
  }
}
''');
    expect(result.passed, isTrue);
  });
}
