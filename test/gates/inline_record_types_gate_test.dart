import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/inline_record_types_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  Future<GateResult> runOn(String source) async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/a.dart', source);
    return InlineRecordTypesGate().run(makeContext(project, ['lib/a.dart']));
  }

  test('flags an inline positional record type in a signature', () async {
    final result = await runOn('''
(int, int) point() => (1, 2);
''');
    expect(result.passed, isFalse);
    expect(result.violations.single.message,
        contains('declare the shape as a typedef'));
  });

  test('flags an inline named-only record type too', () async {
    final result = await runOn('''
({int x, int y}) point() => (x: 1, y: 2);
''');
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains("'({int x, int y})'"));
  });

  test('flags records nested in type arguments', () async {
    final result = await runOn('''
Future<Map<String, (int, int)>> load() async => {};
''');
    expect(result.violations.single.message, contains("'(int, int)'"));
  });

  test('record type aliases are the blessed form', () async {
    final result = await runOn('''
typedef Extent = ({int start, int end});

int width(Extent extent) => extent.end - extent.start;
''');
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('a function-type typedef blesses nothing', () async {
    final result = await runOn('''
typedef Use = int Function((int, int) pair);
''');
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains("'(int, int)'"));
  });

  test('plain signatures pass and are counted once', () async {
    final result = await runOn('''
int add(int a, int b) => a + b;

String greet(String name) => 'hi ' + name;
''');
    expect(result.passed, isTrue);
    expect(result.summary, contains('no inline record types'));
  });

  test('named functions and their lambdas are each scanned once', () async {
    final result = await runOn('''
(int, int) top() => (1, 2);

void outer() {
  int inner((int, int) p) => p.\$1;
  final lambda = ((int, int) q) => q.\$2;
  print(inner((1, 2)) + lambda((3, 4)));
}
''');
    // top, inner, lambda — three shapes; a double scan of a named
    // function would report four.
    expect(result.violations, hasLength(3));
  });
}
