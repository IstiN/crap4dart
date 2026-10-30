import 'package:crap4dart/src/gates/gate_ids.dart';
import 'package:crap4dart/src/gates/gate_runner.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('severity warning downgrades findings to run warnings', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/bang.dart', 'void f(Object? o) => o!.hashCode;\n');
    final result = await GateRunner().run(
      makeContext(
        project,
        ['lib/bang.dart'],
        configYaml: '''
gates:
  non_null_assertion:
    severity: warning
''',
      ),
      only: {GateIds.nonNullAssertion},
    );
    expect(result.passed, isTrue);
    final gate = result.results.single;
    expect(gate.warning, isTrue);
    expect(gate.violations, isNotEmpty);
  });

  test('severity error fails the run', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/bang.dart', 'void f(Object? o) => o!.hashCode;\n');
    final result = await GateRunner().run(
      makeContext(
        project,
        ['lib/bang.dart'],
        configYaml: '''
gates:
  non_null_assertion:
    severity: error
''',
      ),
      only: {GateIds.nonNullAssertion},
    );
    expect(result.passed, isFalse);
    expect(result.results.single.warning, isFalse);
  });

  test('disabled gate is skipped', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    writeFile(project, 'lib/bang.dart', 'void f(Object? o) => o!.hashCode;\n');
    final result = await GateRunner().run(
      makeContext(
        project,
        ['lib/bang.dart'],
        configYaml: '''
gates:
  non_null_assertion:
    enabled: false
''',
      ),
      only: {GateIds.nonNullAssertion},
    );
    final gate = result.results.single;
    expect(gate.skipped, isTrue);
    expect(gate.passed, isTrue);
  });
}
