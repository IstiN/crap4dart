import 'dart:io';

import '../files/flutter_project.dart';
import 'mutation_cache.dart';
import 'mutation_operators.dart';

/// Outcome of running the test suite against a single mutant.
enum MutantOutcome {
  /// The test command exited non-zero: some test failed (or the project
  /// no longer compiles — a compile-error mutant is killed the same
  /// way, because `dart test` refuses to run).
  killed,

  /// The test command exited zero: no test noticed the mutant.
  survived,

  /// The test command did not finish within the timeout. A timeout means
  /// the suite did not kill the mutant deterministically, so it counts
  /// as `survived` (mirrors the mutator research conclusion).
  timeout,
}

/// One row of a [MutationRunResult.outcomes] list: the [site], its
/// [outcome], and whether the kill was replayed from the cache instead
/// of executed.
typedef MutantOutcomeRecord = ({
  MutationSite site,
  MutantOutcome outcome,
  bool fromCache
});

/// Signature of the per-mutant test runner — inject a fake in tests
/// instead of running real test suites. The test invocation arguments
/// (`test_args`) are bound when the engine is created, not per call.
typedef MutantTestRunner = Future<MutantOutcome> Function(
  String projectRoot,
  Duration timeout,
);

/// Thrown when the test command cannot be spawned at all; the gate
/// turns this into a skipped result.
class MutationTestUnavailableException implements Exception {
  /// Creates a [MutationTestUnavailableException] with a [message].
  const MutationTestUnavailableException(this.message);

  /// Human readable reason (e.g. "dart not found on PATH").
  final String message;

  @override
  String toString() => message;
}

/// Signature of a process spawn — matches the relevant part of
/// [Process.start] so tests can inject a fake process.
typedef MutantProcessSpawner = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

/// The result of running every mutant of one engine invocation.
class MutationRunResult {
  /// Creates a [MutationRunResult].
  MutationRunResult(this.outcomes, {this.integrityViolations = const []});

  /// Per-site outcomes; every input site appears exactly once.
  final List<MutantOutcomeRecord> outcomes;

  /// Files that did NOT match their pre-run snapshot after the loop and
  /// had to be re-restored by the end-of-run integrity check. Non-empty
  /// means the per-site restore was defeated somehow (external edit,
  /// killed process) — the tree is healed, but the run must be treated
  /// as suspect.
  final List<String> integrityViolations;

  /// Mutants killed by the test suite (compile errors included).
  int get killed =>
      outcomes.where((o) => o.outcome == MutantOutcome.killed).length;

  /// Kills replayed from the digest cache instead of re-executed.
  int get fromCacheCount => outcomes.where((o) => o.fromCache).length;

  /// Mutants the suite noticed nothing about, timeouts included.
  int get survived =>
      outcomes.where((o) => o.outcome != MutantOutcome.killed).length;

  /// Mutation score: killed / (killed + survived); `1.0` when no mutant
  /// was executed.
  double get score =>
      killed + survived == 0 ? 1.0 : killed / (killed + survived);

  /// Survived mutants grouped by operator category (for the report).
  Map<String, int> get survivorsByCategory {
    final counts = <String, int>{};
    for (final outcome in outcomes) {
      if (outcome.outcome == MutantOutcome.killed) continue;
      counts.update(outcome.site.category, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}

/// Applies single-token mutations one at a time and runs the project's
/// test command against each mutant, restoring the file afterwards.
///
/// With a [MutationCacheSession], mutants of unchanged methods whose
/// previous outcome was `killed` are replayed from the cache (counted
/// killed, marked `fromCache`); survivors are always re-executed. The
/// merged cache is persisted after the run.
class MutationEngine {
  /// Creates a [MutationEngine]; [runner] overrides the per-mutant
  /// test runner (injected in tests); without it the suite runs as
  /// `dart <testArgs>` (or `flutter <testArgs>`) per mutant.
  MutationEngine({MutantTestRunner? runner}) : _injected = runner;

  final MutantTestRunner? _injected;

  /// Runs every [site] of the project at [projectRoot], giving each
  /// mutant up to [timeout].
  ///
  /// The first [MutationTestUnavailableException] propagates: the caller
  /// (the gate) converts it into a skipped result.
  Future<MutationRunResult> run({
    required String projectRoot,
    required List<MutationSite> sites,
    required Duration timeout,
    List<String> testArgs = const ['test'],
    MutationCacheSession? caching,
  }) async {
    final runner = _injected ??
        (root, duration) => runMutantTests(root, duration, testArgs: testArgs);
    final outcomes = <MutantOutcomeRecord>[];
    final fresh = <String, ({String digest, List<CachedOutcome> outcomes})>{};
    // Safety net: snapshot every file about to be mutated so the end of
    // the run can prove the tree is byte-identical to the start. A
    // real fa_llm run once ended with a leftover mutant on disk despite
    // the per-site finally-restore; silent tree corruption must become
    // a loud, self-healing error instead.
    final originals = _snapshotOriginals(sites);
    var integrityViolations = const <String>[];
    try {
      for (final site in sites) {
        final method = caching?.siteMethods[site];
        final replayed =
            method == null ? null : caching!.cache.replayKill(method, site);
        if (method != null && replayed != null) {
          outcomes.add(
              (site: site, outcome: MutantOutcome.killed, fromCache: true));
          _accumulate(fresh, method, replayed);
          continue;
        }
        final outcome = await _executeSite(site, projectRoot, timeout, runner);
        outcomes.add((site: site, outcome: outcome, fromCache: false));
        if (method != null) {
          _accumulate(fresh, method, _cached(site, outcome, method));
        }
      }
    } finally {
      // End-of-run integrity check: restore any file that does not match
      // its snapshot, even when the loop died mid-mutant.
      integrityViolations = _verifyIntegrity(originals);
    }
    _persist(caching, fresh);
    return MutationRunResult(outcomes,
        integrityViolations: integrityViolations);
  }

  /// Snapshots the current content of every file [sites] touch.
  Map<String, String> _snapshotOriginals(List<MutationSite> sites) {
    final originals = <String, String>{};
    for (final site in sites) {
      originals.putIfAbsent(
          site.file, () => File(site.file).readAsStringSync());
    }
    return originals;
  }

  /// Restores any file whose on-disk content drifted from its snapshot;
  /// returns the paths that had to be re-restored (empty when healthy).
  List<String> _verifyIntegrity(Map<String, String> originals) {
    final violations = <String>[];
    for (final entry in originals.entries) {
      final file = File(entry.key);
      final current = file.readAsStringSync();
      if (current != entry.value) {
        file.writeAsStringSync(entry.value);
        violations.add(entry.key);
      }
    }
    return violations;
  }

  Future<MutantOutcome> _executeSite(
    MutationSite site,
    String projectRoot,
    Duration timeout,
    MutantTestRunner runner,
  ) async {
    final file = File(site.file);
    final original = file.readAsStringSync();
    file.writeAsStringSync(site.applyTo(original));
    try {
      return await runner(projectRoot, timeout);
    } finally {
      // Always restore the file, also after timeouts and errors.
      file.writeAsStringSync(original);
    }
  }

  void _accumulate(
    Map<String, ({String digest, List<CachedOutcome> outcomes})> fresh,
    MethodRef method,
    CachedOutcome outcome,
  ) {
    final entry = fresh.putIfAbsent(
        method.key, () => (digest: method.digest, outcomes: []));
    entry.outcomes.add(outcome);
  }

  CachedOutcome _cached(
          MutationSite site, MutantOutcome outcome, MethodRef method) =>
      CachedOutcome(
        offset: site.offset - method.start,
        line: site.line,
        category: site.category,
        original: site.original,
        mutant: site.mutant,
        status: outcome.name,
      );

  void _persist(
    MutationCacheSession? caching,
    Map<String, ({String digest, List<CachedOutcome> outcomes})> fresh,
  ) {
    if (caching == null) return;
    caching.cache.mergeRun(fresh, caching.liveKeys);
    caching.cache.save(caching.cacheFile);
  }
}

/// Runs the test suite of [projectRoot] once, killing the process when
/// it outlives [timeout]. [testArgs] is the full argument list of the
/// test invocation (default `['test']`). [spawn] defaults to
/// [Process.start] and is injected in tests.
Future<MutantOutcome> runMutantTests(
  String projectRoot,
  Duration timeout, {
  List<String> testArgs = const ['test'],
  MutantProcessSpawner spawn = Process.start,
}) async {
  final isFlutter = isFlutterProject(projectRoot);
  final Process process;
  try {
    process = await spawn(
      isFlutter ? 'flutter' : 'dart',
      testArgs,
      workingDirectory: projectRoot,
    );
  } on ProcessException catch (e) {
    throw MutationTestUnavailableException(
      '${isFlutter ? 'flutter' : 'dart'} not found on PATH: ${e.message}',
    );
  }
  // Drain the output so the child never blocks on a full pipe.
  process.stdout.listen((_) {});
  process.stderr.listen((_) {});
  var timedOut = false;
  final code = await process.exitCode.timeout(
    timeout,
    onTimeout: () {
      timedOut = true;
      process.kill(ProcessSignal.sigkill);
      return -1;
    },
  );
  if (timedOut) return MutantOutcome.timeout;
  return code == 0 ? MutantOutcome.survived : MutantOutcome.killed;
}
