import 'package:path/path.dart' as p;

import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/scattered_constants_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  Future<GateResult> runOn(
    Map<String, String> files, {
    String configYaml = 'gates:\n  scattered_constants:\n    enabled: true\n',
  }) async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    for (final entry in files.entries) {
      writeFile(project, entry.key, entry.value);
    }
    return ScatteredConstantsGate().run(
      makeContext(
        project,
        files.keys.map((f) => p.join(project.path, f)).toList(),
        configYaml: configYaml,
      ),
    );
  }

  test('flags a double literal present in min_files distinct files', () async {
    final result = await runOn({
      'lib/a.dart': 'final x = 86400.5;\n',
      'lib/b.dart': 'final y = 86400.5;\n',
      'lib/c.dart': 'final z = 86400.5;\n',
    });
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(3));
    expect(
      result.violations.every((v) => v.message.contains('86400.5')),
      isTrue,
      reason: result.violations.toString(),
    );
  });

  test('double literals at or below min_value are coincidence', () async {
    final result = await runOn({
      'lib/a.dart': 'final x = 1.5;\n',
      'lib/b.dart': 'final y = 1.5;\n',
      'lib/c.dart': 'final z = 1.5;\n',
    });
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('ignored double values never flag', () async {
    final result = await runOn(
      {
        'lib/a.dart': 'final x = 99.5;\n',
        'lib/b.dart': 'final y = 99.5;\n',
        'lib/c.dart': 'final z = 99.5;\n',
      },
      configYaml: 'gates:\n'
          '  scattered_constants:\n'
          '    enabled: true\n'
          "    ignore: ['99.5']\n",
    );
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('double constants regress too', () async {
    final result = await runOn({
      'lib/consts.dart': 'const secondsPerDay = 86400.5;\n',
      'lib/other.dart': 'final x = 86400.5;\n',
    });
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(result.violations[0].file, 'lib/other.dart');
    expect(result.violations[0].message, contains('secondsPerDay'));
    expect(result.violations[0].message, contains('duplicates constant'));
  });
}
