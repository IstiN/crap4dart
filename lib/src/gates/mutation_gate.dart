import 'dart:io';

import 'package:path/path.dart' as p;

import '../analysis/method_extractor.dart';
import '../config/config.dart';
import '../coverage/lcov_parser.dart';
import 'gate.dart';
import 'gate_context.dart';
import 'mutation_engine.dart';
import 'mutation_operators.dart';

/// The `mutation` gate: mutation testing adapted from the
/// unclebob/mutator research conclusions.
///
/// Every enabled operator of the declarative table produces mutation
/// sites on the parsed AST (offsets come from analyzer tokens, never
/// regex). Sites in unexecuted methods are `uncovered` and excluded
/// from the score denominator; every covered site is mutated one at a
/// time and the project's test command runs against it — a non-zero
/// exit kills the mutant (compile-error mutants are killed the same
/// way because `dart test` refuses to run), a clean pass means the
/// mutant survived, and a timeout counts as survived because the suite
/// did not kill it deterministically. The gate fails below `min_score`
/// or when more than `max_survivors` mutants survive, and reports one
/// violation per survived mutant so diff mode and baselines work.
class MutationGate implements Gate {
  /// Creates a [MutationGate]; [runner] overrides the per-mutant test
  /// runner (injected in tests, real projects run `dart test`).
  MutationGate({MutantTestRunner? runner})
      : _engine = MutationEngine(runner: runner);

  @override
  String get id => 'mutation';

  final MutationEngine _engine;

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.mutation;
    if (context.lcov == null) {
      return GateResult.skip(id, 'no coverage data');
    }
    if (!Directory(p.join(context.projectRoot, 'test')).existsSync()) {
      return GateResult.skip(id, 'no test directory');
    }
    final scoped = _coveredSites(context, config);
    if (scoped.sites.isEmpty) {
      final summary = scoped.uncovered == 0
          ? 'no mutation sites'
          : 'no covered mutation sites (${scoped.uncovered} uncovered)';
      return GateResult.pass(id, summary: summary);
    }
    final MutationRunResult result;
    try {
      result = await _engine.run(
        projectRoot: context.projectRoot,
        sites: scoped.sites,
        timeout: Duration(seconds: config.execution.timeoutSeconds),
      );
    } on MutationTestUnavailableException catch (e) {
      return GateResult.skip(id, e.message);
    }
    return _verdict(result, scoped.uncovered, config, context);
  }

  /// Detects sites in every analyzed file and keeps the covered ones,
  /// capped at [MutationExecution.maxMutants] (file order, then
  /// offset — the cap is deterministic).
  ({List<MutationSite> sites, int uncovered}) _coveredSites(
    GateContext context,
    MutationGateConfig config,
  ) {
    final detector = MutationSiteDetector(categories: config.operators.toSet());
    final covered = <MutationSite>[];
    var uncovered = 0;
    for (final file in context.files) {
      if (covered.length >= config.execution.maxMutants) break;
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      final parsed = context.parsed(file);
      final fileCoverage = _fileCoverage(context, file);
      final methods = const MethodExtractor()
          .extract(parsed.unit, parsed.lineInfo, filePath: file);
      for (final site in detector.detect(parsed)) {
        if (covered.length >= config.execution.maxMutants) break;
        if (_isCovered(site, fileCoverage, methods)) {
          covered.add(site);
        } else {
          uncovered++;
        }
      }
    }
    return (sites: covered, uncovered: uncovered);
  }

  /// The LCOV entry of [file], matched by its project-relative path.
  FileCoverage? _fileCoverage(GateContext context, String file) {
    final relative = context.relativePath(file);
    for (final coverage in context.lcov!) {
      if (coverage.path == relative) return coverage;
    }
    return null;
  }

  /// Whether [site]'s containing method was executed and the site's
  /// line is not recorded as unexecuted. Sites outside every extracted
  /// method fall back to raw line coverage.
  bool _isCovered(
    MutationSite site,
    FileCoverage? file,
    List<MethodInfo> methods,
  ) {
    if (file == null) return false;
    final method = _containingMethod(methods, site.line);
    if (method == null) {
      final hits = file.lineHits[site.line];
      return hits != null && hits > 0;
    }
    if (!_methodExecuted(method, file)) return false;
    final hits = file.lineHits[site.line];
    return hits == null || hits > 0;
  }

  /// The extracted method whose line range contains [line], or `null`.
  MethodInfo? _containingMethod(List<MethodInfo> methods, int line) {
    for (final candidate in methods) {
      if (line >= candidate.startLine && line <= candidate.endLine) {
        return candidate;
      }
    }
    return null;
  }

  /// Whether any LCOV line inside [method]'s range was executed.
  bool _methodExecuted(MethodInfo method, FileCoverage file) {
    final startLine = method.startLine;
    final endLine = method.endLine;
    var executed = false;
    file.lineHits.forEach((line, hits) {
      if (line >= startLine && line <= endLine && hits > 0) executed = true;
    });
    return executed;
  }

  /// Builds the gate result from the engine outcome.
  GateResult _verdict(
    MutationRunResult result,
    int uncovered,
    MutationGateConfig config,
    GateContext context,
  ) {
    final score = result.score;
    final percent = (score * 100).toStringAsFixed(1);
    final summary =
        'score $percent% (${result.killed} killed, ${result.survived} '
        'survived, $uncovered uncovered)';
    final failed =
        score < config.minScore || result.survived > config.maxSurvivors;
    if (!failed) return GateResult.pass(id, summary: summary);
    final violations = [
      for (final outcome in result.outcomes)
        if (outcome.outcome != MutantOutcome.killed)
          GateViolation(
            file: context.relativePath(outcome.site.file),
            line: outcome.site.line,
            message: _survivorMessage(outcome.site),
          ),
    ];
    final byCategory = result.survivorsByCategory.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    return GateResult.fail(
      id,
      violations,
      summary: '$summary; survivors by category: $byCategory',
    );
  }

  String _survivorMessage(MutationSite site) {
    final method = site.method == null ? '' : ' in ${site.method}';
    return 'survived ${site.category} mutant `${site.original}` -> '
        '`${site.mutant}`$method';
  }
}
