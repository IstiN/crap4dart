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

  test('passes when every covered mutant is killed', () async {
    final result = await mutationGateWith(
        (root, timeout, args) async => MutantOutcome.killed).run(
      makeContext(project, ['lib/a.dart'], lcov: mutationFixtureLcov()),
    );
    expect(result.passed, isTrue);
    expect(result.violations, isEmpty);
    expect(result.summary, contains('score 100.0%'));
    expect(result.summary, contains('1 uncovered'));
  });

  test('fails with one violation per survived mutant', () async {
    final result = await mutationGateWith(
        (root, timeout, args) async => MutantOutcome.survived).run(
      makeContext(project, ['lib/a.dart'], lcov: mutationFixtureLcov()),
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
    final violation = result.violations.single;
    expect(violation.file, 'lib/a.dart');
    expect(violation.line, 3);
    expect(violation.message, contains('survived arithmetic mutant'));
    expect(violation.message, contains('`+` -> `-`'));
    expect(violation.message, contains('(top-level).add'));
    expect(result.summary, contains('score 0.0%'));
    expect(result.summary, contains('arithmetic=1'));
  });

  test('timeouts count as survived', () async {
    final result = await mutationGateWith(
        (root, timeout, args) async => MutantOutcome.timeout).run(
      makeContext(project, ['lib/a.dart'], lcov: mutationFixtureLcov()),
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(1));
  });

  test('compile-error mutants are killed by the non-zero test exit', () async {
    // The runner contract maps any non-zero `dart test` exit —
    // including compilation failure — to `killed`.
    final result = await mutationGateWith(
        (root, timeout, args) async => MutantOutcome.killed).run(
      makeContext(project, ['lib/a.dart'], lcov: mutationFixtureLcov()),
    );
    expect(result.passed, isTrue);
  });

  test('passes with no covered sites when everything is uncovered', () async {
    final result = await mutationGateWith(
        (root, timeout, args) async => MutantOutcome.survived).run(
      makeContext(
        project,
        ['lib/a.dart'],
        lcov: mutationFixtureLcovHits(0, 0),
      ),
    );
    expect(result.passed, isTrue);
    expect(result.summary, contains('no covered mutation sites'));
  });
}
