import 'dart:io';

import 'package:crap4dart/src/config/config_loader.dart';
import 'package:crap4dart/src/files/diff_parser.dart';
import 'package:crap4dart/src/gates/gate_context.dart';
import 'package:crap4dart/src/gates/mutation_engine.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'gate_test_utils.dart';
import 'mutation_gate_fixtures.dart';

late Directory project;

/// Gate-level scoping tests: diff-scoped execution and `scope_tests`.
void main() {
  setUp(() {
    project = createTempProject();
    writeFile(project, 'lib/a.dart', mutationFixtureSource);
    writeFile(project, 'test/a_test.dart', 'void main() {}\n');
  });

  tearDown(() => project.deleteSync(recursive: true));

  diffScopeTests();
  testScopeTests();
}

GateContext diffContext(Set<int> changedLines) => GateContext(
      projectRoot: project.path,
      config: const ConfigLoader().loadString('gates:\n  mutation:\n'),
      files: [p.join(project.path, 'lib/a.dart')],
      lcov: mutationFixtureLcovHits(1, 1),
      diff: DiffLineMap(
        projectRoot: project.path,
        addedLines: {'lib/a.dart': changedLines},
      ),
    );

void diffScopeTests() {
  test('diff run executes only sites whose method intersects the diff',
      () async {
    final executed = <int>[];
    final gate = mutationGateWith((root, timeout, args) async {
      // Record the mutated content: `a - b` is add (line 3),
      // `return 1` is zero (line 8).
      final content = File(p.join(root, 'lib/a.dart')).readAsStringSync();
      executed.add(content.contains('a - b') ? 3 : 8);
      return MutantOutcome.killed;
    });
    // Only zero()'s lines changed.
    final result = await gate.run(diffContext({8}));
    expect(executed, [8]);
    expect(result.passed, isTrue);
    expect(result.summary, contains('1 killed'));
  });

  test('diff run on add() executes only add sites', () async {
    final executed = <int>[];
    final gate = mutationGateWith((root, timeout, args) async {
      final content = File(p.join(root, 'lib/a.dart')).readAsStringSync();
      executed.add(content.contains('a - b') ? 3 : 8);
      return MutantOutcome.killed;
    });
    final result = await gate.run(diffContext({3}));
    expect(executed, [3]);
    expect(result.passed, isTrue);
  });

  test('diff without the file passes without executing anything', () async {
    var calls = 0;
    final gate = mutationGateWith((root, timeout, args) async {
      calls++;
      return MutantOutcome.killed;
    });
    final context = GateContext(
      projectRoot: project.path,
      config: const ConfigLoader().loadString('gates:\n  mutation:\n'),
      files: [p.join(project.path, 'lib/a.dart')],
      lcov: mutationFixtureLcovHits(1, 1),
      diff: DiffLineMap(projectRoot: project.path, addedLines: {
        'lib/other.dart': {1},
      }),
    );
    final result = await gate.run(context);
    expect(calls, 0);
    expect(result.passed, isTrue);
    expect(result.summary, contains('no mutation sites'));
  });
}

void testScopeTests() {
  test('scope_tests narrows the invocation to the derived test file', () async {
    final invocations = <List<String>>[];
    final gate = mutationGateWith((root, timeout, args) async {
      invocations.add(List.of(args));
      // The scoped test file misses the mutant; the full run kills it.
      return args.length > 1 ? MutantOutcome.survived : MutantOutcome.killed;
    });
    final context = GateContext(
      projectRoot: project.path,
      config: const ConfigLoader().loadString(
        'gates:\n  mutation:\n    scope_tests: true\n',
      ),
      files: [p.join(project.path, 'lib/a.dart')],
      lcov: mutationFixtureLcovHits(1, 1),
    );
    final result = await gate.run(context);
    // add's site and zero's site are both scoped to test/a_test.dart
    // and survive there; both are re-confirmed against the full
    // invocation and killed.
    expect(invocations, [
      ['test', 'test/a_test.dart'],
      ['test', 'test/a_test.dart'],
      ['test'],
      ['test'],
    ]);
    expect(result.passed, isTrue);
    expect(result.summary, contains('test-scoped 2 (2 re-confirmed killed)'));
  });

  test('scope_tests falls back to test_args when no candidate exists',
      () async {
    final invocations = <List<String>>[];
    final gate = mutationGateWith((root, timeout, args) async {
      invocations.add(List.of(args));
      return MutantOutcome.killed;
    });
    final context = GateContext(
      projectRoot: project.path,
      config: const ConfigLoader().loadString(
        'gates:\n  mutation:\n'
        '    scope_tests: true\n'
        "    test_args: ['test', 'test/full']\n",
      ),
      files: [p.join(project.path, 'lib/a.dart')],
      lcov: mutationFixtureLcovHits(1, 1),
    );
    // test/a_test.dart EXISTS and covers lib/a.dart, so it is used —
    // remove it to force the fallback path.
    File(p.join(project.path, 'test/a_test.dart')).deleteSync();
    final result = await gate.run(context);
    expect(invocations, [
      ['test', 'test/full'],
      ['test', 'test/full'],
    ]);
    expect(result.summary, isNot(contains('test-scoped')));
  });
}
