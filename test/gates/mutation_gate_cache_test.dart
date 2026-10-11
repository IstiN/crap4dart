import 'dart:io';

import 'package:crap4dart/src/gates/mutation_cache.dart';
import 'package:crap4dart/src/gates/mutation_engine.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'gate_test_utils.dart';
import 'mutation_gate_fixtures.dart';

late Directory project;

void main() {
  setUp(() {
    project = createTempProject();
    writeFile(project, 'lib/a.dart', mutationFixtureSource);
    writeFile(project, 'test/a_test.dart', 'void main() {}\n');
  });

  tearDown(() => project.deleteSync(recursive: true));
  replayTests();
  configSwitchTests();
}

String cacheFile() => p.join(project.path, mutationCacheFileName);

Future<({bool passed, String summary, int calls, int cached})> runGate(
  MutantTestRunner runner, {
  String? configYaml,
}) async {
  var calls = 0;
  final result = await mutationGateWith((root, timeout) async {
    calls++;
    return runner(root, timeout);
  }).run(
    makeContext(
      project,
      ['lib/a.dart'],
      configYaml: configYaml,
      lcov: mutationFixtureLcovHits(1, 1),
    ),
  );
  final cached =
      RegExp(r'(\d+) cached').firstMatch(result.summary ?? '')?.group(1);
  return (
    passed: result.passed,
    summary: result.summary ?? '',
    calls: calls,
    cached: int.parse(cached ?? '0'),
  );
}

void replayTests() {
  test('second gate run replays cached kills with zero runner calls', () async {
    final first = await runGate(
      (root, timeout) async => MutantOutcome.killed,
      configYaml: 'gates:\n  mutation:\n',
    );
    expect(first.calls, 2);
    expect(first.passed, isTrue);
    expect(first.cached, 0);
    expect(File(cacheFile()).existsSync(), isTrue);

    final second = await runGate(
      (root, timeout) async => MutantOutcome.killed,
      configYaml: 'gates:\n  mutation:\n',
    );
    expect(second.calls, 0, reason: 'killed mutants replay from the cache');
    expect(second.cached, 2);
    expect(second.passed, isTrue);
    expect(second.summary, contains('2 killed'));
    expect(second.summary, contains('2 cached'));
  });

  test('identical verdicts across runs with survivors re-executed', () async {
    var firstCalls = 0;
    final first = await runGate((root, timeout) async {
      firstCalls++;
      return firstCalls == 1 ? MutantOutcome.killed : MutantOutcome.survived;
    },
        configYaml: 'gates:\n  mutation:\n'
            '    min_score: 0.0\n'
            '    max_survivors: 2\n');
    expect(first.calls, 2);
    expect(first.passed, isTrue);

    var calls = 0;
    final second = await runGate((root, timeout) async {
      calls++;
      return MutantOutcome.survived;
    },
        configYaml: 'gates:\n  mutation:\n'
            '    min_score: 0.0\n'
            '    max_survivors: 2\n');
    expect(calls, 1, reason: 'survivors re-run even with matching digests');
    expect(second.cached, 1);
    expect(second.passed, isTrue);
  });
}

void configSwitchTests() {
  test('cache: false disables load, replay and persistence', () async {
    final result = await runGate(
      (root, timeout) async => MutantOutcome.killed,
      configYaml: 'gates:\n  mutation:\n    cache: false\n',
    );
    expect(result.calls, 2);
    expect(result.cached, 0);
    expect(File(cacheFile()).existsSync(), isFalse);
  });

  test('a test_args change wipes the cache (meta guard)', () async {
    await runGate(
      (root, timeout) async => MutantOutcome.killed,
      configYaml: 'gates:\n  mutation:\n',
    );
    final second = await runGate(
      (root, timeout) async => MutantOutcome.killed,
      configYaml: 'gates:\n  mutation:\n'
          "    test_args: ['test', 'test/a_test.dart']\n",
    );
    expect(second.calls, 2);
    expect(second.cached, 0);
  });
}
