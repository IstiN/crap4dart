
import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/record_named_fields_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  Future<GateResult> runOn(String source) async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/a.dart', source);
    return RecordNamedFieldsGate().run(makeContext(project, ['lib/a.dart']));
  }

  test('flags positional record fields in a signature', () async {
    final result = await runOn('''
(int, int) point() => (1, 2);
''');
    expect(result.passed, isFalse);
    final message = result.violations.single.message;
    expect(message, contains("'(int, int)'"));
    expect(message, contains('2 unnamed field(s)'));
  });

  test('flags .\$N positional field access', () async {
    final result = await runOn('''
int first((int x, int y) p) => p.\$1;
''');
    expect(result.violations.single.message, contains("'.\$1'"));
  });

  test('record values stay legal: only the access is flagged', () async {
    final result = await runOn('''
int sum() {
  final r = (1, 2);
  final (a, b) = r;
  final map = <(int, int), String>{(1, 2): 'x'};
  return a + b + r.\$1 + map.values.length;
}
''');
    expect(result.violations, hasLength(1));
    expect(result.violations.single.message, contains("'.\$1'"));
  });

  test('typedef internals are blessed; usages are not', () async {
    final result = await runOn('''
typedef Pair = (int, int);

Pair swap(Pair p) => (p.\$2, p.\$1);
''');
    expect(result.violations, hasLength(2));
    for (final v in result.violations) {
      expect(v.message, contains('positional record field access'));
    }
  });

  test("named-only inline records are another gate's concern", () async {
    final result = await runOn('''
({int x, int y}) point() => (x: 1, y: 2);
''');
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('plain signatures pass', () async {
    final result = await runOn('''
int add(int a, int b) => a + b;

class C {
  C(this.value);
  final int value;
}
''');
    expect(result.passed, isTrue);
    expect(result.summary, contains('record fields named'));
  });
}
