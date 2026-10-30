import 'package:test/test.dart';

import 'collapsible_flow_gate_test.dart' show runOn;

void main() {
  test('try/finally shapes that keep the else', () async {
    // body exits, finally falls through -> no flag
    final r4 = await runOn('''
String f4(bool c) {
  if (c) {
    try {
      return 'a';
    } finally {
      log('done');
    }
  } else {
    return 'b';
  }
  return 'x';
}
''');
    expect(r4.passed, isTrue,
        reason: 'non-exiting finally can absorb '
            'the exit — the else must stay');

    // body does not exit -> no flag
    final r5 = await runOn('''
String f5(bool c) {
  if (c) {
    try {
      log('a');
    } finally {
      return 'z';
    }
  } else {
    return 'b';
  }
  return 'x';
}
''');
    expect(r5.passed, isTrue, reason: 'non-exiting body blocks the flag');
  });
}
