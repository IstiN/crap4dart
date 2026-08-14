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
    writeFile(
      project,
      'lib/entrypoint.dart',
      "import 'a.dart';\n\n/// Runs the app.\nvoid main() => documented();\n",
    );
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  test('aggregates pass/skip across gates', () async {
    final runner = GateRunner();
    final result = await runner.run(
      makeContext(
        project,
        ['lib/a.dart', 'lib/entrypoint.dart'],
        configYaml: '''
coverage:
  required: false
gates:
  golden:
    enabled: false
''',
      ),
    );
    expect(result.passed, isTrue);
    final byId = {for (final r in result.results) r.gateId: r};
    expect(byId['loc']!.skipped, isFalse);
    expect(byId['test_coverage']!.skipped, isTrue);
    expect(byId['golden']!.skipped, isTrue);
    expect(byId['golden']!.skipReason, 'disabled in config');
    expect(byId['hardcoded_strings']!.skipReason, 'not a Flutter project');
  });

  test('fails the run when any gate fails', () async {
    writeFile(project, 'lib/undocumented.dart', '''
void undocumented() {}
''');
    final runner = GateRunner();
    final result = await runner.run(
      makeContext(project, ['lib/undocumented.dart'], configYaml: '''
coverage:
  required: false
'''),
    );
    expect(result.passed, isFalse);
    // public_docs (missing dartdoc) and unused_files (never imported).
    expect(result.failedCount, 2);
  });
}
