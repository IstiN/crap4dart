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

  test('two constants with the same value name the first declared', () async {
    final result = await runOn({
      'lib/first.dart': 'const secondsPerDay = 86400;\n',
      'lib/second.dart': 'const dayLength = 86400;\n',
      'lib/third.dart': 'final x = 86400;\n',
    });
    expect(result.passed, isFalse);
    final messages = result.violations.map((v) => v.message).toSet();
    expect(messages, hasLength(1));
    expect(messages.first, contains('secondsPerDay'));
    expect(messages.first, isNot(contains('dayLength')));
  });

  test('ignored values never regress', () async {
    final result = await runOn(
      {
        'lib/consts.dart': 'const token = ' '86400;\n',
        'lib/other.dart': 'final x = 86400;\n',
      },
      configYaml: 'gates:\n'
          '  scattered_constants:\n'
          '    enabled: true\n'
          "    ignore: ['86400']\n",
    );
    expect(result.passed, isTrue);
  });
  test('min_files still governs when no constant exists', () async {
    final result = await runOn({
      'lib/a.dart': 'final x = 86400;\n',
      'lib/b.dart': 'final y = 86400;\n',
    });
    expect(result.passed, isTrue);
  });
}
