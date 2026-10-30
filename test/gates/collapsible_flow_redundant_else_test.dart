import 'package:test/test.dart';

import 'collapsible_flow_gate_test.dart' show runOn;

void main() {
  test('flags a redundant else after a returning then', () async {
    final result = await runOn('''
String f(bool c) {
  if (c) {
    return 'a';
  } else {
    return 'b';
  }
}
''');
    expect(result.passed, isFalse);
    expect(result.violations.single.line, 2);
    expect(result.violations.single.message, contains('dedent'));
  });

  test('break, continue, throw and rethrow count as exiting', () async {
    for (final body in <String>[
      "if (c) { break; } else { print('x'); }",
      "if (c) { continue; } else { print('x'); }",
      "if (c) { throw StateError('x'); } else { print('x'); }",
      "if (c) { rethrow; } else { print('x'); }",
    ]) {
      final result = await runOn('''
void f(bool c) {
  while (true) {
    $body
  }
}
''');
      expect(
        result.violations.single.message,
        contains('dedent'),
        reason: body,
      );
    }
  });

  test('a block ending in an exiting if-chain counts as exiting', () async {
    final result = await runOn('''
String f(bool c, int x) {
  if (x > 0) {
    if (c) {
      return 'a';
    } else {
      return 'b';
    }
  } else {
    return 'c';
  }
}
''');
    // the inner if-chain (line 3) and the outer if whose then-block
    // ends with it (line 2) are both flagged.
    expect(result.violations, hasLength(2));
    expect(result.violations.map((v) => v.line), [2, 3]);
  });
}
