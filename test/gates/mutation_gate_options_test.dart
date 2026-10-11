import 'dart:io';

import 'package:crap4dart/src/gates/mutation_engine.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';
import 'mutation_gate_fixtures.dart';

void main() {
  late Directory project;

  setUp(() {
    project = createTempProject();
    writeFile(project, 'lib/a.dart', mutationFixtureSource);
    writeFile(project, 'test/a_test.dart', 'void main() {}\n');
  });

  tearDown(() => project.deleteSync(recursive: true));

  test('honors the exclude globs', () async {
    var calls = 0;
    await mutationGateWith((root, timeout) async {
      calls++;
      return MutantOutcome.killed;
    }).run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: 'gates:\n  mutation:\n    exclude: [lib/a.dart]\n',
        lcov: mutationFixtureLcov(),
      ),
    );
    expect(calls, 0);
  });

  test('restricts sites to the configured operator categories', () async {
    var calls = 0;
    await mutationGateWith((root, timeout) async {
      calls++;
      return MutantOutcome.survived;
    }).run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: 'gates:\n  mutation:\n    operators: [constant]\n',
        lcov: mutationFixtureLcov(),
      ),
    );
    // `constant` leaves the `+` site undetected; `zero` is uncovered,
    // so no mutant runs at all.
    expect(calls, 0);
  });
}
