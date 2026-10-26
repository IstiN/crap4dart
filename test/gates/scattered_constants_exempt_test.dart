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

  test('duplicate local consts regress against the first declaration',
      () async {
    // The first const declaration is the fact's home; the other
    // local consts are unlinked re-definitions flagged immediately —
    // they name the constant to reference.
    final result = await runOn({
      'lib/a.dart': 'const secondsPerDay = 86400;\n',
      'lib/b.dart': 'const day = 86400;\n',
      'lib/c.dart': 'const daySeconds = 86400;\n',
    });
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(2));
    expect(result.violations[0].file, 'lib/b.dart');
    expect(result.violations[0].message, contains('secondsPerDay'));
    expect(result.violations[0].message, contains('duplicates constant'));
  });

  test('small numbers and short strings are coincidence', () async {
    final result = await runOn({
      'lib/a.dart': "final a = 100;\nfinal b = 'ok';\n",
      'lib/b.dart': "final a = 100;\nfinal b = 'ok';\n",
      'lib/c.dart': "final a = 100;\nfinal b = 'ok';\n",
    });
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('map keys and index expressions are protocol identifiers', () async {
    final result = await runOn({
      'lib/a.dart':
          "final m = {'session-key': 1};\nfinal x = m2['session-key'];",
      'lib/b.dart':
          "final m = {'session-key': 2};\nfinal x = m2['session-key'];",
      'lib/c.dart':
          "final m = {'session-key': 3};\nfinal x = m2['session-key'];",
    });
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('import and part directives are never flagged', () async {
    final result = await runOn({
      'lib/a.dart': "import 'dart:io';\npart 'p.dart';\n",
      'lib/b.dart': "import 'dart:io';\npart 'p.dart';\n",
      'lib/c.dart': "part of 'a.dart';\n",
    });
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('excluded paths do not count towards the file total', () async {
    final result = await runOn({
      'lib/a.dart': 'final x = 86400;\n',
      'lib/b.dart': 'final y = 86400;\n',
      'test/c_test.dart': 'final z = 86400;\n',
    });
    // test/** excluded by default — only two files remain.
    expect(result.passed, isTrue, reason: result.violations.toString());
  });
}
