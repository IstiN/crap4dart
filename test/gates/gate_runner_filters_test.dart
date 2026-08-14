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
}
