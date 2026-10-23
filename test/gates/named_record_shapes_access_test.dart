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

  test('flags .\$N field access anywhere (kind c)', () async {
    final result = await runOn('''
int firstOf((int, int) r) => r.\$1;
''');
    // the record type in the signature + the .\$1 access
    expect(result.violations, hasLength(2));
    expect(
      result.violations.any((v) => v.message.contains("'.\$1'")),
      isTrue,
      reason: result.violations.toString(),
    );
  });
  test('flags .\$N on optional chains and complex receivers', () async {
    final result = await runOn('''
String show((double, double)? metrics) => metrics == null
    ? 'none'
    : '(jaccard ' + metrics!.\$1.toString() + ')';
''');
    expect(
      result.violations.any((v) => v.message.contains("'.\$1'")),
      isTrue,
      reason: result.violations.toString(),
    );
  });
  test('a function-type typedef does not bless an inline record', () async {
    final result = await runOn('''
typedef Use = int Function((int, int) pair);
typedef Loader = Future<(int, int)> Function();
''');
    expect(result.violations, hasLength(2));
    expect(
      result.violations.map((v) => v.line),
      [1, 2],
      reason: result.violations.toString(),
    );
  });
}
