import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/named_record_shapes_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  Future<GateResult> runOn(String source) async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/a.dart', source);
    return NamedRecordShapesGate().run(makeContext(project, ['lib/a.dart']));
  }

  test('flags an inline positional record type in a signature', () async {
    final result = await runOn('''
typedef Use = int Function((int, int) pair);
''');
    expect(result.passed, isFalse);
    final violation = result.violations.single;
    expect(violation.line, 1);
    expect(violation.message, contains("'(int, int)'"));
    expect(violation.message, contains('positional field(s)'));
    expect(violation.message, contains('typedef'));
  });

  test('flags a positional record return type and parameter', () async {
    final result = await runOn('''
(int, int) first((int a, int b) pair) => pair;
''');
    expect(result.violations, hasLength(2));
    expect(
      result.violations.map((v) => v.line),
      [1, 1],
      reason: result.violations.toString(),
    );
  });

  test('flags an inline named-only record type (kind a)', () async {
    final result = await runOn('''
({int x, int y}) make() => (x: 1, y: 2);
''');
    expect(result.violations.single.message, contains('inline record type'));
    expect(result.violations.single.message, isNot(contains('positional')));
  });

  test('flags record types nested in type arguments', () async {
    final result = await runOn('''
Future<Map<String, (int, int)>> load() async => {};
''');
    expect(result.violations.single.message, contains("'(int, int)'"));
  });

  test('record type aliases are the blessed form: not scanned', () async {
    final result = await runOn('''
typedef Pair = (int, int);
typedef Tagged = ({String tag, int n});

Pair swap(Pair p) => (p.\$2, p.\$1);
''');
    // only the .\$N accesses are flagged — the typedef internals are not
    expect(result.violations.map((v) => v.message),
        everyElement(contains("positional record field access")));
  });
}
