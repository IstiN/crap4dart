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

  test('record values stay legal: literals, locals, destructuring', () async {
    final result = await runOn('''
int sum() {
  final r = (1, 2);
  final (a, b) = r;
  final map = <(int, int), String>{(1, 2): 'x'};
  return a + b + r.\$1 + map.values.length;
}
''');
    expect(
      result.violations.map((v) => v.message),
      everyElement(contains('positional record field access')),
      reason: 'only r.\$1 may fire, never the literal or the pattern',
    );
  });

  test('named-only signatures pass once behind typedefs', () async {
    final result = await runOn('''
typedef Extent = ({int start, int end});

int width(Extent extent) => extent.end - extent.start;
''');
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('plain signatures without records pass', () async {
    final result = await runOn('''
int add(int a, int b) => a + b;

String greet(String name) => 'hi ' + name;

class C {
  C(this.value);
  final int value;
  int get doubled => value * 2;
  static List<String> names() => const ['x'];
}
''');
    expect(result.passed, isTrue, reason: result.violations.toString());
    expect(result.summary, contains('no anonymous record shapes'));
  });

  test('named functions are scanned once, not twice', () async {
    final result = await runOn('''
(int, int) point() => (1, 2);
''');
    expect(result.violations, hasLength(1));
  });

  test('nested functions and lambdas are scanned', () async {
    final result = await runOn('''
void outer() {
  int inner((int, int) p) => p.\$1;
  final lambda = ((int, int) q) => q.\$2;
  print(inner((1, 2)) + lambda((3, 4)));
}
''');
    final shapeCount = result.violations
        .where((v) => v.message.contains('positional record type'))
        .length;
    expect(shapeCount, 2, reason: result.violations.toString());
  });
}
