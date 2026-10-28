import 'package:crap4dart/src/gates/gate.dart';
import 'package:crap4dart/src/gates/scattered_constants_gate.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  Future<GateResult> runOn(
    Map<String, String> files, {
    String? configYaml,
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

  test('a private pure value alias is flagged', () async {
    final result = await runOn({
      'lib/a.dart': "const String kName = 'crap4dart';\n"
          "const String _appName = kName;\n"
          'void main() => print(_appName);\n',
    });
    expect(result.passed, isFalse, reason: '${result.violations}');
    final v = result.violations.single;
    expect(v.line, 2);
    expect(v.message, contains('alias `_appName` adds no information'));
    expect(v.message, contains('reference `kName` directly'));
  });

  test('a public alias is exempt (re-export shims are deliberate)', () async {
    final result = await runOn({
      'lib/a.dart': "const String kName = 'crap4dart';\n"
          'const String appName = kName;\n'
          'void main() => print(appName);\n',
    });
    expect(result.violations, isEmpty, reason: '${result.violations}');
  });

  test('aliases: false disables the rule', () async {
    final result = await runOn(
      {
        'lib/a.dart': "const String kName = 'crap4dart';\n"
            "const String _appName = kName;\n"
            'void main() => print(_appName);\n',
      },
      configYaml: 'gates:\n'
          '  scattered_constants:\n'
          '    aliases: false\n',
    );
    expect(result.violations, isEmpty, reason: '${result.violations}');
  });

  test('computed initializers are not aliases', () async {
    final result = await runOn({
      'lib/a.dart': "const String kName = 'crap4dart';\n"
          "final String appName = kName + '!';\n"
          'void main() => print(appName);\n',
    });
    expect(result.violations, isEmpty, reason: '${result.violations}');
  });
}
