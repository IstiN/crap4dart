import '../common/constants.dart';
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
/// are resolved per site by the engine ([MutationEngine.run]'s
/// `testArgsFor`) and passed to every call.
typedef MutantTestRunner = Future<MutantOutcome> Function(
  String projectRoot,
  Duration timeout,
  List<String> testArgs,
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
  MutationRunResult(
    this.outcomes, {
    this.integrityViolations = const [],
    this.scopedCount = 0,
    this.confirmedCount = 0,
  });

  /// Per-site outcomes; every input site appears exactly once.
  final List<MutantOutcomeRecord> outcomes;

  /// Files that did NOT match their pre-run snapshot after the loop and
  /// had to be re-restored by the end-of-run integrity check. Non-empty
  /// means the per-site restore was defeated somehow (external edit,
  /// killed process) — the tree is healed, but the run must be treated
  /// as suspect.
  final List<String> integrityViolations;

  /// Sites executed with test arguments other than the full invocation
  /// (test-scoping); see [MutationEngine.run]'s `testArgsFor`.
  final int scopedCount;

  /// Scoped sites whose first (scoped) run survived but whose
  /// confirmation run against the full invocation killed the mutant.
  /// Scoped survival is not trustworthy on its own — a scoped run may
  /// omit the killing test — so survivors are re-confirmed; only these
  /// two counters tell how much scoping actually saved.
  final int confirmedCount;

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

/// Shared state of one [MutationEngine.run] invocation, bundling the
/// invocation context with the mutable run accumulators so the loop
/// helpers stay within the method-size limits.
class _RunState {
  /// Creates a [_RunState] for one run.
  _RunState({
    required this.projectRoot,
    required this.timeout,
    required this.runner,
    required this.testArgs,
    required this.caching,
  });

  /// Project root of the test invocations.
  final String projectRoot;

  /// Per-mutant timeout.
  final Duration timeout;

  /// The per-mutant test runner (injected or the real process spawn).
  final MutantTestRunner runner;

  /// The full test invocation argument list.
  final List<String> testArgs;

  /// The cache session, or `null` when caching is disabled.
  final MutationCacheSession? caching;

  /// Per-site outcomes; every input site appears exactly once.
  final outcomes = <MutantOutcomeRecord>[];

  /// Indices into [outcomes] whose scoped first run survived and that
  /// still owe a confirmation run against [testArgs].
  final scopedSurvivors = <int>[];

  /// Fresh per-method outcomes to merge into the cache after the run.
  final fresh = <String, _FreshOutcomes>{};
}

/// Fresh per-method outcomes of one mutation run (see
/// MutationCache.mergeRun).
typedef _FreshOutcomes = ({String digest, List<CachedOutcome> outcomes});

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
  /// `dart <args...>` (or `flutter <args...>`) per mutant.
  MutationEngine({MutantTestRunner? runner}) : _injected = runner;

  final MutantTestRunner? _injected;

  /// Runs every [site] of the project at [projectRoot], giving each
  /// mutant up to [timeout].
  ///
  /// [testArgs] is the full test invocation (default `['test']`).
  /// [testArgsFor] may resolve narrower per-site arguments (test
  /// scoping): a scoped invocation is a SUBSET of the full suite, so a
  /// scoped kill is monotone — the full suite kills that mutant too —
  /// and is cached as a regular kill. Scoped survival is NOT monotone
  /// (the scoped run may omit the killing test), so every scoped
  /// survivor is re-executed once against [testArgs] before the outcome
  /// is final (counted in [MutationRunResult.confirmedCount] when the
  /// confirmation kills it).
  ///
  /// The first [MutationTestUnavailableException] propagates: the caller
  /// (the gate) converts it into a skipped result.
  Future<MutationRunResult> run({
    required String projectRoot,
    required List<MutationSite> sites,
    required Duration timeout,
    List<String> testArgs = const [kTest],
    List<String>? Function(MutationSite site)? testArgsFor,
    MutationCacheSession? caching,
  }) async {
    final runner = _injected ??
        (root, duration, args) =>
            runMutantTests(root, duration, testArgs: args);
    // Safety net: snapshot every file about to be mutated so the end of
    // the run can prove the tree is byte-identical to the start. A
    // real fa_llm run once ended with a leftover mutant on disk despite
    // the per-site finally-restore; silent tree corruption must become
    // a loud, self-healing error instead.
    final originals = _snapshotOriginals(sites);
    final state = _RunState(
      projectRoot: projectRoot,
      timeout: timeout,
      runner: runner,
      testArgs: testArgs,
      caching: caching,
    );
    var integrityViolations = const <String>[];
    var confirmedCount = 0;
    try {
      await _executeAll(sites, testArgsFor, state);
      confirmedCount = await _confirmScoped(state);
    } finally {
      // End-of-run integrity check: restore any file that does not match
      // its snapshot, even when the loop died mid-mutant.
      integrityViolations = _verifyIntegrity(originals);
    }
    _persist(caching, state.fresh);
    return MutationRunResult(
      state.outcomes,
      integrityViolations: integrityViolations,
      scopedCount: state.scopedSurvivors.length,
      confirmedCount: confirmedCount,
    );
  }

  /// Runs every site once: cache replays, scoped or full executions.
  /// Scoped survivors are deferred (indices in [state.scopedSurvivors])
  /// for [_confirmScoped]; everything else is accumulated into
  /// [state.fresh].
  Future<void> _executeAll(
    List<MutationSite> sites,
    List<String>? Function(MutationSite site)? testArgsFor,
    _RunState state,
  ) async {
    for (final site in sites) {
      final method = state.caching?.siteMethods[site];
      final replayed =
          method == null ? null : state.caching!.cache.replayKill(method, site);
      if (method != null && replayed != null) {
        state.outcomes
            .add((site: site, outcome: MutantOutcome.killed, fromCache: true));
        _accumulate(state.fresh, method, replayed);
        continue;
      }
      final scopedArgs = testArgsFor?.call(site);
      final outcome = await _executeSite(
        site,
        state.projectRoot,
        state.timeout,
        state.runner,
        scopedArgs ?? state.testArgs,
      );
      state.outcomes.add((site: site, outcome: outcome, fromCache: false));
      if (scopedArgs != null && outcome != MutantOutcome.killed) {
        // Scoped survival is unverified: confirm against the full
        // invocation before caching or reporting the outcome.
        state.scopedSurvivors.add(state.outcomes.length - 1);
      } else if (method != null) {
        _accumulate(state.fresh, method, _cached(site, outcome, method));
      }
    }
  }

  /// Re-runs every deferred scoped survivor against the full
  /// invocation; returns how many confirmations killed the mutant.
  Future<int> _confirmScoped(_RunState state) async {
    var confirmedCount = 0;
    for (final index in state.scopedSurvivors) {
      final record = state.outcomes[index];
      final outcome = await _executeSite(record.site, state.projectRoot,
          state.timeout, state.runner, state.testArgs);
      state.outcomes[index] =
          (site: record.site, outcome: outcome, fromCache: false);
      if (outcome == MutantOutcome.killed) confirmedCount++;
      final method = state.caching?.siteMethods[record.site];
      if (method != null) {
        _accumulate(state.fresh, method, _cached(record.site, outcome, method));
      }
    }
    return confirmedCount;
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
    List<String> testArgs,
  ) async {
    final file = File(site.file);
    final original = file.readAsStringSync();
    file.writeAsStringSync(site.applyTo(original));
    try {
      return await runner(projectRoot, timeout, testArgs);
    } finally {
      // Always restore the file, also after timeouts and errors.
      file.writeAsStringSync(original);
    }
  }

  void _accumulate(
    Map<String, _FreshOutcomes> fresh,
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
    Map<String, FreshOutcomes> fresh,
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
  List<String> testArgs = const [kTest],
  MutantProcessSpawner spawn = Process.start,
}) async {
  final isFlutter = isFlutterProject(projectRoot);
  final Process process;
  try {
    process = await spawn(
      isFlutter ? kFlutter : kDart,
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
