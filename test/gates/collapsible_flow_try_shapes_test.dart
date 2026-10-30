import 'package:test/test.dart';

import 'collapsible_flow_gate_test.dart' show runOn;

void main() {
  test('try/finally exit shapes', () async {
    // body exits, no finally -> flag
    final r1 = await runOn('''
String f1(bool c) {
  if (c) {
    try {
      return 'a';
    } on Object {
      rethrow;
    }
  } else {
    return 'b';
  }
}
''');
    expect(r1.passed, isFalse, reason: 'try without finally, body exits');

    // body exits, empty finally -> still flag
    final r2 = await runOn('''
String f2(bool c) {
  if (c) {
    try {
      return 'a';
    } finally {}
  } else {
    return 'b';
  }
}
''');
    expect(r2.passed, isFalse, reason: 'empty finally keeps the flow');

    // body exits, finally exits -> flag
    final r3 = await runOn('''
String f3(bool c) {
  if (c) {
    try {
      return 'a';
    } finally {
      return 'z';
    }
  } else {
    return 'b';
  }
}
''');
    expect(r3.passed, isFalse, reason: 'exiting finally keeps the flow');
  });
}
