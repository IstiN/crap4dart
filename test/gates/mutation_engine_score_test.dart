import 'dart:io';

import 'package:crap4dart/src/gates/mutation_engine.dart';
import 'package:crap4dart/src/gates/mutation_operators.dart';
import 'package:test/test.dart';

MutationSite site(String file, {String category = 'arithmetic'}) =>
    MutationSite(
      file: file,
      line: 1,
      method: null,
      category: category,
      original: 'a',
      mutant: 'X',
      offset: 0,
      length: 1,
    );

void main() {
  late Directory dir;
  late String file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('crap4dart_mutation_score_');
    file = '${dir.path}/a.txt';
    File(file).writeAsStringSync('a');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<MutationRunResult> runWith(MutantOutcome outcome) =>
      MutationEngine(runner: (root, timeout) async => outcome).run(
        projectRoot: dir.path,
        sites: [site(file), site(file)],
        timeout: const Duration(seconds: 5),
      );

  test('non-zero exit maps to killed, zero to survived', () async {
    var call = 0;
    final outcomes = [MutantOutcome.killed, MutantOutcome.survived];
    final engine = MutationEngine(
      runner: (root, timeout) async => outcomes[call++],
    );
    final result = await engine.run(
      projectRoot: dir.path,
      sites: [site(file), site(file)],
      timeout: const Duration(seconds: 5),
    );
    expect(result.killed, 1);
    expect(result.survived, 1);
    expect(result.score, 0.5);
  });

  test('timeout counts as survived in the score', () async {
    final result = await runWith(MutantOutcome.timeout);
    expect(result.survived, 2);
    expect(result.score, 0.0);
    expect(result.survivorsByCategory, {'arithmetic': 2});
  });

  test('survivors are grouped by category', () async {
    final engine = MutationEngine(
      runner: (root, timeout) async => MutantOutcome.survived,
    );
    final result = await engine.run(
      projectRoot: dir.path,
      sites: [site(file), site(file), site(file, category: 'boundary')],
      timeout: const Duration(seconds: 5),
    );
    expect(result.survivorsByCategory, {'arithmetic': 2, 'boundary': 1});
  });

  test('passes the project root and timeout to the runner', () async {
    Duration? seenTimeout;
    String? seenRoot;
    final engine = MutationEngine(runner: (root, timeout) async {
      seenRoot = root;
      seenTimeout = timeout;
      return MutantOutcome.killed;
    });
    await engine.run(
      projectRoot: dir.path,
      sites: [site(file)],
      timeout: const Duration(seconds: 42),
    );
    expect(seenRoot, dir.path);
    expect(seenTimeout, const Duration(seconds: 42));
  });
}
