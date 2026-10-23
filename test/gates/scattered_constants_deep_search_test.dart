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

  test('deep search flags a shared dot-segment prefix', () async {
    final result = await runOn({
      'lib/a.dart': "final a = 'gates.loc';\n",
      'lib/b.dart': "final b = 'gates.nesting';\n",
      'lib/c.dart': "final c = 'gates.loc.entries';\n",
    });
    expect(result.passed, isFalse);
    // One violation per occurrence of the shared prefix.
    expect(result.violations, hasLength(3));
    expect(
      result.violations.map((v) => v.message),
      everyElement(contains("prefix 'gates'")),
    );
  });

  test('whole-literal equality is not required', () async {
    final result = await runOn({
      'lib/a.dart': "final a = 'toolchain.build.debug';\n",
      'lib/b.dart': "final b = 'toolchain.build.release';\n",
      'lib/c.dart': "final c = 'toolchain.test';\n",
    });
    expect(result.passed, isFalse);
    expect(
      result.violations.map((v) => v.message),
      everyElement(contains("prefix 'toolchain'")),
    );
  });

  test('deep search off keeps partial reuse invisible', () async {
    final result = await runOn(
      {
        'lib/a.dart': "final a = 'gates.loc';\n",
        'lib/b.dart': "final b = 'gates.nesting';\n",
        'lib/c.dart': "final c = 'gates.loc.entries';\n",
      },
      configYaml: 'gates:\n  scattered_constants:\n    enabled: true\n',
    );
    expect(result.passed, isTrue, reason: result.violations.toString());
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
