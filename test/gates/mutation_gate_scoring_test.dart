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
    writeFile(project, 'test/a_test.dart', 'void main() {}\n');
  });

  tearDown(() => project.deleteSync(recursive: true));

  test('uncovered sites are excluded from the score denominator', () async {
    // Only `zero` is covered (one site); `add` is unexecuted.
    final result = await mutationGateWith(
        (root, timeout, args) async => MutantOutcome.survived).run(
      makeContext(project, ['lib/a.dart'], lcov: mutationFixtureLcovHits(0, 1)),
    );
    expect(result.passed, isFalse);
    expect(result.summary, contains('score 0.0%'));
    expect(result.summary, contains('1 survived'));
    expect(result.summary, contains('1 uncovered'));
    expect(result.violations.single.line, 8);
  });

  test('max_survivors fails the gate even above min_score', () async {
    final result = await mutationGateWith(
        (root, timeout, args) async => MutantOutcome.survived).run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: 'gates:\n'
            '  mutation:\n'
            '    min_score: 0.0\n'
            '    max_survivors: 0\n',
        lcov: mutationFixtureLcovHits(1, 1),
      ),
    );
    expect(result.passed, isFalse);
    expect(result.violations, hasLength(2));
  });

  test('low min_score passes with a lone survivor', () async {
    var call = 0;
    final result = await mutationGateWith((root, timeout, args) async =>
        ++call == 1 ? MutantOutcome.killed : MutantOutcome.survived).run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: 'gates:\n'
            '  mutation:\n'
            '    min_score: 0.4\n'
            '    max_survivors: 1\n',
        lcov: mutationFixtureLcovHits(1, 1),
      ),
    );
    expect(result.passed, isTrue);
  });

  test('caps executed mutants at max_mutants', () async {
    var calls = 0;
    final result = await mutationGateWith((root, timeout, args) async {
      calls++;
      return MutantOutcome.killed;
    }).run(
      makeContext(
        project,
        ['lib/a.dart'],
        configYaml: 'gates:\n  mutation:\n    max_mutants: 1\n',
        lcov: mutationFixtureLcovHits(1, 1),
      ),
    );
    expect(calls, 1);
    expect(result.passed, isTrue);
    expect(result.summary, contains('1 killed'));
  });
}
