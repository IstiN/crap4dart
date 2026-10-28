import 'dart:io';

import 'package:crap4dart/src/gates/mutation/mutation_engine.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';
import 'mutation_gate_fixtures.dart';

void main() {
  late Directory project;

  setUp(() {
    project = createTempProject();
    writeFile(project, 'lib/a.dart', mutationFixtureSource);
    // The gate requires a test directory to exist.
    writeFile(project, 'test/a_test.dart', 'void main() {}\n');
  });

  tearDown(() => project.deleteSync(recursive: true));

  test('skips when there is no coverage data', () async {
    final result = await mutationGateWith(
            (root, timeout, args) async => MutantOutcome.killed)
        .run(makeContext(project, ['lib/a.dart']));
    expect(result.skipped, isTrue);
    expect(result.skipReason, contains('no coverage data'));
  });

  test('skips when the project has no test directory', () async {
    Directory('${project.path}/test').deleteSync(recursive: true);
    final result = await mutationGateWith(
        (root, timeout, args) async => MutantOutcome.killed).run(
      makeContext(project, ['lib/a.dart'], lcov: mutationFixtureLcov()),
    );
    expect(result.skipped, isTrue);
    expect(result.skipReason, contains('no test directory'));
  });

  test('skips when the test command cannot be spawned', () async {
    final result = await mutationGateWith(
      (root, timeout, args) =>
          throw MutationTestUnavailableException('dart not found'),
    ).run(makeContext(project, ['lib/a.dart'], lcov: mutationFixtureLcov()));
    expect(result.skipped, isTrue);
    expect(result.skipReason, contains('dart not found'));
  });
}
