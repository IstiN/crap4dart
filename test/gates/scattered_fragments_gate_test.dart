import 'package:path/path.dart' as p;

import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/scattered_fragments_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  Future<GateResult> runOn(
    Map<String, String> files, {
    String configYaml = 'gates:\n'
        '  scattered_fragments:\n'
        '    enabled: true\n',
  }) async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    files.forEach((relative, content) => writeFile(project, relative, content));
    return ScatteredFragmentsGate().run(
      makeContext(
        project,
        files.keys.map((f) => p.join(project.path, f)).toList(),
        configYaml: configYaml,
      ),
    );
  }

  test('repeated separator segments flag from min_files files', () async {
    final result = await runOn(
      {
        'lib/a.dart': "final a = 'gates.loc';\n",
        'lib/b.dart': "final b = 'gates.nesting';\n",
      },
      configYaml: 'gates:\n'
          '  scattered_fragments:\n'
          '    enabled: true\n'
          '    min_files: 2\n',
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(2));
    expect(
      result.violations.map((v) => v.message),
      everyElement(contains("segment 'gates' repeats in 2 files")),
    );
  });

  test('hardcoded value containing a named constant is a candidate', () async {
    final result = await runOn({
      'lib/const.dart': "const gatesPrefix = 'gates';\n",
      'lib/a.dart': "final a = 'gates.loc.entries';\n",
      'lib/b.dart': "final b = 'gates.nesting';\n",
    });
    expect(result.passed, isFalse);
    expect(
      result.violations.map((v) => v.message),
      everyElement(
          contains("contains fragment 'gates' of constant 'gatesPrefix'")),
    );
  });

  test('hardcoded value equal to a constant suggests referencing', () async {
    final result = await runOn({
      'lib/const.dart': "const jsonFormat = 'json_format_value';\n",
      'lib/a.dart': "final a = 'json_format_value';\n",
    });
    expect(result.passed, isFalse);
    expect(
      result.violations.single.message,
      contains("duplicates constant 'jsonFormat'"),
    );
  });
}
