import 'package:crap4dart/src/coverage/lcov_parser.dart';
import 'package:crap4dart/src/gates/mutation/mutation_engine.dart';
import 'package:crap4dart/src/gates/mutation/mutation_gate.dart';

/// Fixture source: `add` is on executable line 3, `zero` on line 8
/// (Dart drops the newline right after `'''`).
const mutationFixtureSource = '''
/// Doc.
int add(int a, int b) {
  return a + b;
}

/// Doc.
int zero() {
  return 0;
}
''';

/// A gate whose per-mutant test runner is injected.
MutationGate mutationGateWith(MutantTestRunner runner) =>
    MutationGate(runner: runner);

/// LCOV for [mutationFixtureSource] where `add` is covered and `zero`
/// is unexecuted unless [zeroCovered].
List<FileCoverage> mutationFixtureLcov({bool zeroCovered = false}) =>
    const LcovParser().parse(
      'SF:lib/a.dart\n'
      'DA:3,1\n'
      'DA:8,${zeroCovered ? 1 : 0}\n'
      'end_of_record\n',
    );

/// LCOV with explicit hit records for both fixture methods.
List<FileCoverage> mutationFixtureLcovHits(int addHits, int zeroHits) =>
    const LcovParser().parse(
      'SF:lib/a.dart\nDA:3,$addHits\nDA:8,$zeroHits\nend_of_record\n',
    );
