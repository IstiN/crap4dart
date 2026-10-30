import 'package:path/path.dart' as p;

import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/scattered_constants_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  Future<GateResult> runOn(
    Map<String, String> files, {
    String configYaml = 'gates:\n'
        '  scattered_constants:\n'
        '    enabled: true\n'
        "    ignore: [test, dart, flutter]\n",
  }) async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    files.forEach((relative, content) => writeFile(project, relative, content));
    return const ScatteredConstantsGate().run(
      makeContext(
        project,
        files.keys.map((f) => p.join(project.path, f)).toList(),
        configYaml: configYaml,
      ),
    );
  }

  test('entries with a slash are file-path globs, not values', () async {
    final result = await runOn(
      {
        'lib/a.dart': "final a = 'crypto-magic-constant';\n",
        'lib/b.dart': "final b = 'crypto-magic-constant';\n",
        'lib/c.dart': "final c = 'crypto-magic-constant';\n",
        'src/crypto/d.dart': "final d = 'crypto-magic-constant';\n",
        'src/crypto/e.dart': "final e = 'crypto-magic-constant';\n",
      },
      configYaml: 'gates:\n'
          '  scattered_constants:\n'
          '    enabled: true\n'
          "    ignore: ['src/crypto/**']\n"
          '    exclude: []\n',
    );
    // The crypto files are exempt; the lib/ occurrences still report.
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(3));
    expect(
      result.violations.map((v) => v.file),
      everyElement(startsWith('lib/')),
    );
  });
  test('a plain word does not act as a folder glob', () async {
    final result = await runOn(
      {
        'lib/a.dart': "final a = 'some-fact';\n",
        'lib/b.dart': "final b = 'some-fact';\n",
        'test/c_test.dart': "final c = 'some-fact';\n",
      },
      configYaml: 'gates:\n'
          '  scattered_constants:\n'
          '    enabled: true\n'
          '    ignore: [test]\n'
          '    exclude: []\n',
    );
    // `test` silences the WORD, not the test/ folder: the folder file
    // still counts, so all three occurrences report. (Had `test`
    // exempted the folder, 2 files would stay under min_files.)
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(3));
  });
  test('ignore matches numbers by decimal form', () async {
    final result = await runOn(
      {
        'lib/a.dart': 'final x = 86400;\n',
        'lib/b.dart': 'final y = 86400;\n',
        'lib/c.dart': 'final z = 86400;\n',
      },
      configYaml: 'gates:\n'
          '  scattered_constants:\n'
          '    enabled: true\n'
          '    ignore: [86400]\n',
    );
    expect(result.passed, isTrue, reason: result.violations.toString());
  });
}
