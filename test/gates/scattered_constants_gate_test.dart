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
    return const ScatteredConstantsGate().run(
      makeContext(
        project,
        files.keys.map((f) => p.join(project.path, f)).toList(),
        configYaml: configYaml,
      ),
    );
  }

  test('flags a literal present in min_files distinct files', () async {
    final result = await runOn({
      'lib/a.dart': 'final x = 86400;\n',
      'lib/b.dart': 'final y = 86400;\n',
      'lib/c.dart': 'final z = 86400;\n',
    });
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(3));
    expect(
      result.violations.map((v) => v.file),
      everyElement(contains('lib/')),
    );
    expect(result.violations.every((v) => v.line != null), isTrue);
    expect(result.summary, contains('scattered'));
  });

  test('counts distinct files, not occurrences', () async {
    final result = await runOn({
      'lib/a.dart': 'final x = 86400;\nfinal y = 86400;\n',
      'lib/b.dart': 'final z = 86400;\n',
    });
    // Two files only — occurrences total 3, files 2 < min_files 3.
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('min_files is configurable', () async {
    final result = await runOn(
      {
        'lib/a.dart': "final x = 'shared-secret-value';\n",
        'lib/b.dart': "final y = 'shared-secret-value';\n",
      },
      configYaml: 'gates:\n'
          '  scattered_constants:\n'
          '    enabled: true\n'
          '    min_files: 2\n',
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(2));
  });

  test('digit separators compare by value', () async {
    final result = await runOn({
      'lib/a.dart': 'final x = 86400;\n',
      'lib/b.dart': 'final y = 86_400;\n',
      'lib/c.dart': 'final z = 86400;\n',
    });
    expect(result.passed, isFalse);
  });

  test('a literal inside a const initializer counts with its file', () async {
    final result = await runOn({
      'lib/a.dart': "const option = 'console-or-json-choice';\n",
      'lib/b.dart': "final x = 'console-or-json-choice';\n",
      'lib/c.dart': "final y = 'console-or-json-choice';\n",
    });
    expect(result.passed, isFalse);
  });
}
