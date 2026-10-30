import 'dart:io';

import 'package:crap4dart/src/gates/mutation/mutation_engine.dart';
import 'package:crap4dart/src/gates/mutation/mutation_operators.dart';
import 'package:test/test.dart';

MutationSite site(String file, {String mutant = 'X', int offset = 0}) =>
    MutationSite(
      file: file,
      line: 1,
      method: null,
      category: 'arithmetic',
      original: 'a',
      mutant: mutant,
      offset: offset,
      length: 1,
    );

late Directory dir;
late String file;

void main() {
  setUp(() {
    dir = Directory.systemTemp.createTempSync('crap4dart_mutation_scope_');
    file = '${dir.path}/a.txt';
    File(file).writeAsStringSync('a + b');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  confirmationTests();
  resolutionTests();
}

void confirmationTests() {
  scopedSurvivorTests();
  timeoutTests();
}

void scopedSurvivorTests() {
  test('scoped survivor is re-confirmed against the full invocation', () async {
    final invocations = <List<String>>[];
    final engine = MutationEngine(runner: (root, timeout, args) async {
      invocations.add(List.of(args));
      // The scoped run misses the mutant; the full invocation kills it.
      return args.length > 1 ? MutantOutcome.survived : MutantOutcome.killed;
    });
    final result = await engine.run(
      projectRoot: dir.path,
      sites: [site(file)],
      timeout: const Duration(seconds: 5),
      testArgs: const ['test'],
      testArgsFor: (s) => ['test', 'test/a_test.dart'],
    );
    expect(invocations, [
      ['test', 'test/a_test.dart'],
      ['test'],
    ]);
    expect(result.killed, 1);
    expect(result.survived, 0);
    expect(result.scopedCount, 1);
    expect(result.confirmedCount, 1);
    expect(File(file).readAsStringSync(), 'a + b');
  });

  test('scoped kill is final: monotone, no confirmation run', () async {
    final invocations = <List<String>>[];
    final engine = MutationEngine(runner: (root, timeout, args) async {
      invocations.add(List.of(args));
      return MutantOutcome.killed;
    });
    final result = await engine.run(
      projectRoot: dir.path,
      sites: [site(file)],
      timeout: const Duration(seconds: 5),
      testArgs: const ['test'],
      testArgsFor: (s) => ['test', 'test/a_test.dart'],
    );
    expect(invocations, [
      ['test', 'test/a_test.dart'],
    ]);
    expect(result.killed, 1);
    expect(result.scopedCount, 0);
    expect(result.confirmedCount, 0);
  });

  test('scoped survivor confirmed survived stays survived', () async {
    var calls = 0;
    final engine = MutationEngine(runner: (root, timeout, args) async {
      calls++;
      return MutantOutcome.survived;
    });
    final result = await engine.run(
      projectRoot: dir.path,
      sites: [site(file)],
      timeout: const Duration(seconds: 5),
      testArgs: const ['test'],
      testArgsFor: (s) => ['test', 'test/a_test.dart'],
    );
    expect(calls, 2);
    expect(result.survived, 1);
    expect(result.confirmedCount, 0);
  });
}

void timeoutTests() {
  test('scoped timeout is confirmed like any scoped survivor', () async {
    final engine = MutationEngine(
      runner: (root, timeout, args) async =>
          args.length > 1 ? MutantOutcome.timeout : MutantOutcome.killed,
    );
    final result = await engine.run(
      projectRoot: dir.path,
      sites: [site(file)],
      timeout: const Duration(seconds: 5),
      testArgs: const ['test'],
      testArgsFor: (s) => ['test', 'test/a_test.dart'],
    );
    expect(result.killed, 1);
    expect(result.scopedCount, 1);
    expect(result.confirmedCount, 1);
  });
}

void resolutionTests() {
  test('sites without a scoped resolution run the full invocation', () async {
    final invocations = <List<String>>[];
    final engine = MutationEngine(runner: (root, timeout, args) async {
      invocations.add(List.of(args));
      return MutantOutcome.killed;
    });
    final result = await engine.run(
      projectRoot: dir.path,
      sites: [site(file)],
      timeout: const Duration(seconds: 5),
      testArgs: const ['test', 'test/scoped'],
      testArgsFor: (s) => null, // no candidate test file
    );
    expect(invocations, [
      ['test', 'test/scoped'],
    ]);
    expect(result.killed, 1);
    expect(result.scopedCount, 0);
  });
}
