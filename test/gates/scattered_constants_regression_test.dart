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

  test('a single hardcoded re-introduction flags immediately', () async {
    // The constant exists; one new hardcoded occurrence is a
    // regression — no min_files threshold applies.
    final result = await runOn({
      'lib/consts.dart': 'const secondsPerDay = 86400;\n',
      'lib/other.dart': 'final x = 86400;\n',
    });
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(result.violations[0].file, 'lib/other.dart');
    expect(result.violations[0].message, contains('secondsPerDay'));
    expect(result.violations[0].message, contains('lib/consts.dart:1'));
    expect(result.violations[0].message, contains('duplicates constant'));
  });

  test('the constant declaration itself is never flagged', () async {
    final result = await runOn({
      'lib/consts.dart': 'const secondsPerDay = 86400;\n',
    });
    expect(result.passed, isTrue);
  });

  test('string constants regress too', () async {
    final result = await runOn({
      'lib/consts.dart': "const apiScope = 'profile.read';\n",
      'lib/ui.dart': "final label = 'profile.read';\n",
    });
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(result.violations[0].message, contains('apiScope'));
  });

  test('hardcoded use in the declaring file still flags', () async {
    final result = await runOn({
      'lib/consts.dart': 'const secondsPerDay = 86400;\n'
          'final also = 86400;\n',
    });
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    expect(result.violations[0].line, 2);
  });

  test('interpolated or computed constants do not register', () async {
    final result = await runOn({
      "lib/consts.dart": "const scope = 'profile' + '.read';\n",
      'lib/ui.dart': "final label = 'profile.read';\n",
    });
    expect(result.passed, isTrue);
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
