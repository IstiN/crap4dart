import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/record_size_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  Future<GateResult> runOn(
    String source, {
    String configYaml = 'gates:\n  record_size:\n    enabled: true\n',
  }) async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/a.dart', source);
    return RecordSizeGate().run(
      makeContext(project, ['lib/a.dart'], configYaml: configYaml),
    );
  }

  test('flags an inline record over the default cap of 5', () async {
    final result = await runOn('''
(int, int, int, int, int, int) six() => (1, 2, 3, 4, 5, 6);
''');
    expect(result.passed, isFalse);
    final message = result.violations.single.message;
    expect(message, contains('has 6 fields > max 5'));
    expect(message, contains('transform the record into a class'));
  });

  test('five fields pass', () async {
    final result = await runOn('''
(int, int, int, int, int) five() => (1, 2, 3, 4, 5);
''');
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('named and positional fields count together', () async {
    final result = await runOn('''
(int, int, int, {int x, int y, int z}) mix() =>
    (1, 2, 3, x: 4, y: 5, z: 6);
''');
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('has 6 fields'));
  });

  test('an oversized typedef is flagged at its declaration', () async {
    final result = await runOn('''
typedef Seven =
  (int, int, int, int, int, int, int);

Seven make() => (1, 2, 3, 4, 5, 6, 7);
''');
    expect(result.passed, isFalse);
    final message = result.violations.single.message;
    expect(message, contains('typedef Seven'));
    expect(message, contains('has 7 fields > max 5'));
  });

  test('nested records count towards their own arity', () async {
    final result = await runOn('''
((int, int, int, int, int, int), bool) pair() => ((1, 2, 3, 4, 5, 6), true);
''');
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('has 6 fields'));
  });

  test('max_fields is configurable', () async {
    final result = await runOn(
      '''
(int, int, int) three() => (1, 2, 3);
''',
      configYaml: 'gates:\n'
          '  record_size:\n'
          '    enabled: true\n'
          '    max_fields: 2\n',
    );
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('> max 2'));
  });
}
