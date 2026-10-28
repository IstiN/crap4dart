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

  test('ignored string values never flag', () async {
    final result = await runOn({
      'lib/a.dart': "final a = 'test';\nfinal b = 'dart';\n",
      'lib/b.dart': "final a = 'test';\nfinal b = 'dart';\n",
      'lib/c.dart': "final a = 'test';\nfinal b = 'dart';\n",
    });
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('unlisted literals still flag alongside ignored ones', () async {
    final result = await runOn({
      'lib/a.dart': "final a = 'test';\nfinal b = 'real-fact-value';\n",
      'lib/b.dart': "final a = 'test';\nfinal b = 'real-fact-value';\n",
      'lib/c.dart': "final a = 'test';\nfinal b = 'real-fact-value';\n",
    });
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(3));
    expect(
      result.violations.map((v) => v.message),
      everyElement(contains("'real-fact-value'")),
    );
  });

  test('ignored heads silence deep-search prefix candidates', () async {
    final result = await runOn({
      'lib/a.dart': "final a = 'gates.loc';\n",
      'lib/b.dart': "final b = 'gates.nesting';\n",
      'lib/c.dart': "final c = 'gates.loc.entries';\n",
    });
    expect(result.passed, isTrue, reason: result.violations.toString());
  });

  test('empty ignore list keeps the default behavior', () async {
    final result = await runOn(
      {
        'lib/a.dart': "final a = 'test';\n",
        'lib/b.dart': "final a = 'test';\n",
        'lib/c.dart': "final a = 'test';\n",
      },
      configYaml: 'gates:\n  scattered_constants:\n    enabled: true\n',
    );
    expect(result.passed, isFalse);
  });
}
