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

  test('short fragments never fire (const a = a inside loc.a)', () async {
    final result = await runOn({
      'lib/const.dart': "const a = 'a';\n",
      'lib/x.dart': "final x = 'loc.a';\n",
    });
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('min_length raises the fragment floor', () async {
    final result = await runOn(
      {
        'lib/const.dart': "const gatesPrefix = 'gates';\n",
        'lib/a.dart': "final a = 'gates.loc.entries';\n",
      },
      configYaml: 'gates:\n'
          '  scattered_fragments:\n'
          '    enabled: true\n'
          '    min_length: 10\n',
    );
    expect(result.passed, isTrue, reason: result.violations.toString());
  });
  test('ignored values are out of scope', () async {
    final result = await runOn(
      {
        'lib/const.dart': "const gatesPrefix = 'gates';\n",
        'lib/a.dart': "final a = 'gates.loc.entries';\n",
      },
      configYaml: 'gates:\n'
          '  scattered_fragments:\n'
          '    enabled: true\n'
          '    ignore: [gates]\n',
    );
    expect(result.passed, isTrue, reason: result.violations.toString());
  });
  test('separators are configurable', () async {
    final result = await runOn(
      {
        'lib/a.dart': "final a = 'api/users_list';\n",
        'lib/b.dart': "final b = 'api/orders_list';\n",
      },
      configYaml: 'gates:\n'
          '  scattered_fragments:\n'
          '    enabled: true\n'
          '    min_files: 2\n'
          "    separators: '/_'\n",
    );
    // Segments: api, users, list, orders — 'api' and 'list' repeat.
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(4));
    expect(
      result.violations.map((v) => v.message),
      everyElement(contains('repeats in 2 files')),
    );
  });
}
