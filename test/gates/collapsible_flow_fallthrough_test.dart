import 'package:test/test.dart';

import 'collapsible_flow_gate_test.dart' show runOn;

void main() {
  test('an if without else never counts as exiting (fall-through)', () async {
    final result = await runOn('''
String f(bool c) {
  if (c) {
    print('work');
  } else {
    return 'b';
  }
  return 'c';
}
''');
    expect(result.passed, isTrue,
        reason: 'the then-branch does not '
            'exit — plain statement, no return/break/continue/throw');
  });

  test('the source_instrumenter trap: inner bare if blocks the flag', () async {
    final result = await runOn('''
String f(Object node) {
  if (node is String) {
    final s = node;
    if (s.isEmpty) return '';
  } else {
    return 'other';
  }
  return 'x';
}
''');
    expect(result.passed, isTrue,
        reason: 'the then-branch ends with '
            'an if without else — control falls through when s is not empty');
  });
}
