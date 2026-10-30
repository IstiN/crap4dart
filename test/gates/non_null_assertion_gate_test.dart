import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/quality/non_null_assertion_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

Future<GateResult> runOn(String source) async {
  final root = createTempProject();
  addTearDown(() => root.deleteSync(recursive: true));
  writeFile(root, 'lib/main.dart', source);
  final context = makeContext(root, ['lib/main.dart']);
  return const NonNullAssertionGate().run(context);
}

void main() {
  test('flags a postfix bang on a variable', () async {
    final result = await runOn('''
void f(Object? o) {
  var s = o!.toString();
  print(s);
}
''');
    expect(result.passed, isFalse);
    expect(result.violations.single.line, 2);
    expect(result.violations.single.message, contains('non-null assertion'));
    expect(result.violations.single.message, contains('?.'));
    expect(result.summary, contains('1 non-null assertions'));
  });

  test('flags a bang on an index access', () async {
    final result = await runOn('''
void f(Map<String, int> m) {
  var v = m['k']!;
  print(v);
}
''');
    expect(result.passed, isFalse);
    expect(result.violations.single.line, 2);
  });

  test('flags every bang in a chain separately', () async {
    final result = await runOn('''
int len(String? a, Map<String, String> m) {
  return a!.length + m['k']!.length;
}
''');
    expect(result.passed, isFalse);
    expect(result.violations.length, 2);
    expect(result.summary, contains('2 non-null assertions'));
  });

  test('flags a null-assert pattern in a switch case', () async {
    final result = await runOn('''
void f(Object? o) {
  switch (o) {
    case var z!:
      print(z);
    default:
      break;
  }
}
''');
    expect(result.passed, isFalse);
    expect(result.violations.single.line, 3);
    expect(result.violations.single.message, contains('null-assert pattern'));
    expect(result.violations.single.message, contains('null-check'));
  });

  test('reports a pass summary when no bang exists', () async {
    final result = await runOn('''
void f(int a) {
  print(a);
}
''');
    expect(result.passed, isTrue);
    expect(result.summary, contains('no non-null assertions'));
  });
}
