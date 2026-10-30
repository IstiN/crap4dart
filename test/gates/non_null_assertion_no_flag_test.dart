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
  test('does not flag the != comparison operator', () async {
    final result = await runOn('''
bool f(Object? o) {
  return o != null;
}
''');
    expect(result.passed, isTrue);
    expect(result.violations, isEmpty);
  });

  test('does not flag null-aware access or the ?? operator', () async {
    final result = await runOn('''
void f(Object? o, int fallback) {
  print(o?.toString());
  print(o?.hashCode ?? fallback);
}
''');
    expect(result.passed, isTrue);
  });

  test('does not flag the logical-not prefix operator', () async {
    final result = await runOn('''
void f(bool flag) {
  if (!flag) print('no');
}
''');
    expect(result.passed, isTrue);
  });

  test('does not flag other postfix operators', () async {
    final result = await runOn('''
void f(int i) {
  var a = i++;
  var b = i--;
  print(a + b);
}
''');
    expect(result.passed, isTrue);
  });

  test('does not flag the null-check pattern', () async {
    final result = await runOn('''
void f(Object? o) {
  switch (o) {
    case var z?:
      print(z);
    default:
      break;
  }
}
''');
    expect(result.passed, isTrue);
  });

  test('does not flag a bang inside a string literal', () async {
    final result = await runOn(r'''
void f() {
  print('wow!');
  print('$a! is not ${'bang!'} here');
}
''');
    expect(result.passed, isTrue);
  });
}
