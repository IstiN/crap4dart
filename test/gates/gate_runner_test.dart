import 'dart:io';

import 'package:crap4dart/src/gates/gate_runner.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  late Directory project;

  setUp(() {
    project = createTempProject();
    writeFile(project, 'lib/a.dart', '''
/// A documented function.
void documented() {}
''');
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('aggregates pass/skip across gates', () async {
    final runner = GateRunner();
    final result = await runner.run(
      makeContext(project, ['lib/a.dart'], configYaml: '''
coverage:
  required: false
gates:
  golden:
    enabled: false
'''),
    );
    expect(result.passed, isTrue);
    final byId = {for (final r in result.results) r.gateId: r};
    expect(byId['loc']!.skipped, isFalse);
    expect(byId['test_coverage']!.skipped, isTrue);
    expect(byId['golden']!.skipped, isTrue);
    expect(byId['golden']!.skipReason, 'disabled in config');
    expect(byId['hardcoded_strings']!.skipReason, 'not a Flutter project');
  });

  test('--only runs only the selected gates', () async {
    final runner = GateRunner();
    final result = await runner.run(
      makeContext(project, ['lib/a.dart']),
      only: {'loc', 'complexity'},
    );
    expect(result.results.map((r) => r.gateId), ['loc', 'complexity']);
  });

  test('--skip excludes the selected gates', () async {
    final runner = GateRunner();
    final result = await runner.run(
      makeContext(project, ['lib/a.dart'], configYaml: '''
coverage:
  required: false
'''),
      skip: {'public_docs', 'golden'},
    );
    expect(
      result.results.map((r) => r.gateId),
      isNot(contains('public_docs')),
    );
    expect(result.results.map((r) => r.gateId), isNot(contains('golden')));
  });

  test('fails the run when any gate fails', () async {
    writeFile(project, 'lib/undocumented.dart', 'void undocumented() {}\n');
    final runner = GateRunner();
    final result = await runner.run(
      makeContext(project, ['lib/undocumented.dart'], configYaml: '''
coverage:
  required: false
'''),
    );
    expect(result.passed, isFalse);
    expect(result.failedCount, 1);
  });
}
