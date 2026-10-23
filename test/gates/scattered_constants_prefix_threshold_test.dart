import 'package:path/path.dart' as p;

import 'package:crap4dart/src/config/config_loader.dart';
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
        '    deep_search: true\n',
  }) async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    files.forEach((relative, content) => writeFile(project, relative, content));
    return ScatteredConstantsGate().run(
      makeContext(
        project,
        files.keys.map((f) => p.join(project.path, f)).toList(),
        configYaml: configYaml,
      ),
    );
  }

  test('prefixes obey the same min_files as whole literals', () async {
    // Two files: below min_files, no finding — deep search changes
    // WHAT is matched, not the threshold.
    final two = await runOn({
      'lib/a.dart': "final a = 'gates.loc';\n",
      'lib/b.dart': "final b = 'gates.nesting';\n",
    });
    expect(two.passed, isTrue, reason: two.violations.toString());

    final three = await runOn({
      'lib/a.dart': "final a = 'gates.loc';\n",
      'lib/b.dart': "final b = 'gates.nesting';\n",
      'lib/c.dart': "final c = 'gates.loc.entries';\n",
    });
    expect(three.passed, isFalse);
    expect(three.violations, hasLength(3));
    expect(
      three.violations.map((v) => v.message),
      everyElement(contains("prefix 'gates'")),
    );
  });

  test('prefix_min_files is not a config key', () async {
    expect(
      () => const ConfigLoader().loadString('gates:\n'
          '  scattered_constants:\n'
          '    enabled: true\n'
          '    deep_search: true\n'
          '    prefix_min_files: 2\n'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('deep_search: false is the default', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    final config = const ConfigLoader().loadString(
      'gates:\n  scattered_constants:\n    enabled: true\n',
    );
    expect(config.gates.scatteredConstants.deepSearch, isFalse);
  });
}
