import 'dart:io';

import '../files/flutter_project.dart';
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

/// Signature of the per-mutant test runner — inject a fake in tests
/// instead of running real test suites.
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
  MutationRunResult(this.outcomes);

  /// Per-site outcomes; every input site appears exactly once.
  final List<({MutationSite site, MutantOutcome outcome})> outcomes;

  /// Mutants killed by the test suite (compile errors included).
  int get killed =>
      outcomes.where((o) => o.outcome == MutantOutcome.killed).length;

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
class MutationEngine {
  /// Creates a [MutationEngine]; [runner] defaults to
  /// [defaultMutantTestRunner] and is injected in tests.
  MutationEngine({MutantTestRunner? runner})
      : _runner = runner ?? defaultMutantTestRunner;

  final MutantTestRunner _runner;

  /// Runs every [site] of the project at [projectRoot], giving each
  /// mutant up to [timeout].
  ///
  /// The first [MutationTestUnavailableException] propagates: the caller
  /// (the gate) converts it into a skipped result.
  Future<MutationRunResult> run({
    required String projectRoot,
    required List<MutationSite> sites,
    required Duration timeout,
  }) async {
    final outcomes = <({MutationSite site, MutantOutcome outcome})>[];
    for (final site in sites) {
      final file = File(site.file);
      final original = file.readAsStringSync();
      file.writeAsStringSync(site.applyTo(original));
      MutantOutcome outcome;
      try {
        outcome = await _runner(projectRoot, timeout);
      } finally {
        // Always restore the file, also after timeouts and errors.
        file.writeAsStringSync(original);
      }
      outcomes.add((site: site, outcome: outcome));
    }
    return MutationRunResult(outcomes);
  }
}

/// The default per-mutant runner: spawns `dart test` (or `flutter test`
/// in Flutter projects) with a kill-on-timeout guard.
Future<MutantOutcome> defaultMutantTestRunner(
  String projectRoot,
  Duration timeout,
) =>
    runMutantTests(projectRoot, timeout);

/// Runs the test suite of [projectRoot] once, killing the process when
/// it outlives [timeout]. [spawn] defaults to [Process.start] and is
/// injected in tests.
Future<MutantOutcome> runMutantTests(
  String projectRoot,
  Duration timeout, {
  MutantProcessSpawner spawn = Process.start,
}) async {
  final isFlutter = isFlutterProject(projectRoot);
  final Process process;
  try {
    process = await spawn(
      isFlutter ? 'flutter' : 'dart',
      const ['test'],
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
