import 'package:crap4dart/src/gates/gate_runner.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  test('severity warning reports violations but passes the run', () async {
    final project = createTempProject();
    addTearDown(() => project.deleteSync(recursive: true));
    final filler = List.filled(120, '// filler\n').join();
    writeFile(project, 'lib/big.dart', filler);
    final result = await GateRunner().run(
      makeContext(
        project,
        ['lib/big.dart'],
        configYaml: '''
coverage:
  required: false
gates:
  loc:
    max_lines: 100
    severity: warning
''',
      ),
      only: {'loc'},
    );
    expect(result.passed, isTrue);
    final loc = result.results.singleWhere((r) => r.gateId == 'loc');
    expect(loc.warning, isTrue);
    expect(loc.violations, isNotEmpty);
  });
}
