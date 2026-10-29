import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/quality/collapsible_flow_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

Future<GateResult> runOn(String source) async {
  final root = createTempProject();
  addTearDown(() => root.deleteSync(recursive: true));
  writeFile(root, 'lib/main.dart', source);
  final context = makeContext(root, ['lib/main.dart']);
  return const CollapsibleFlowGate().run(context);
}

void main() {
  test('flags a collapsible if inside a then-block', () async {
    final result = await runOn('''
void f(bool a, bool b) {
  if (a) {
    if (b) {
      print('x');
    }
  }
}
''');
    expect(result.passed, isFalse);
    expect(result.violations.single.line, 2);
    expect(result.violations.single.message, contains('&&'));
    expect(result.summary, contains('1 collapsible-flow findings'));
  });

  test('flags an unbraced nested if', () async {
    final result = await runOn('''
void f(bool a, bool b) {
  if (a) if (b) print('x');
}
''');
    expect(result.passed, isFalse);
    expect(result.violations.single.line, 2);
  });
}
