import '../common/constants.dart';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../analysis/method_extractor.dart';
import '../config/config.dart';
import '../coverage/lcov_parser.dart';
import 'gate.dart';
import 'gate_context.dart';
import 'mutation_cache.dart';
import 'mutation_engine.dart';
import 'mutation_operators.dart';

/// The result of scanning the scope for covered mutation sites, plus
/// the cache identities needed for digest-incremental replay.
typedef MutationScan = ({
  List<MutationSite> sites,
  int uncovered,
  Map<MutationSite, MethodRef> siteMethods,
  Set<String> liveKeys,
});

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
///
/// Digest-incremental cache: mutants of methods whose exact source span
/// is unchanged since the last run and that were previously killed are
/// replayed from `.crap-mutation-cache.json` (counted killed, reported
/// as `cached`); survivors are always re-executed because the test
/// suite may have improved.
///
/// Execution scoping: in a diff run (`--diff` / `--diff-base`) only
/// sites whose containing method intersects the changed lines are
/// executed — the rest are not mutants of this change. With
/// `scope_tests` enabled, each mutant's invocation is narrowed to the
/// derived test file(s) of the mutated file (a scoped kill is monotone
/// and cached; a scoped survivor is re-confirmed against the full
/// invocation before it counts).
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
    if (!Directory(p.join(context.projectRoot, kTest)).existsSync()) {
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
        testArgs: config.execution.testArgs,
        testArgsFor: config.execution.testScope
            ? (site) =>
                _scopedTestArgs(context, site) ?? config.execution.testArgs
            : null,
        caching: _openCache(context, config, scoped),
      );
    } on MutationTestUnavailableException catch (e) {
      return GateResult.skip(id, e.message);
    }
    return _verdict(result, scoped.uncovered, config, context);
  }

  /// Opens the digest cache when `cache` is enabled: loads the file at
  /// the project root (a fresh empty cache on any mismatch) and binds
  /// it to the scan's site identities.
  MutationCacheSession? _openCache(
    GateContext context,
    MutationGateConfig config,
    MutationScan scoped,
  ) {
    if (!config.execution.cache) return null;
    final cacheFile = p.join(context.projectRoot, mutationCacheFileName);
    // scope_tests is deliberately NOT part of the meta guard: a scoped
    // kill is monotone (the scoped invocation is a subset of the full
    // suite), so cached kills stay valid no matter how the invocation
    // was scoped.
    final cache = MutationCache.load(
      path: cacheFile,
      meta: MutationCacheMeta.current(
        operators: config.operators,
        testArgs: config.execution.testArgs,
      ),
    );
    return MutationCacheSession(
      cache: cache,
      cacheFile: cacheFile,
      siteMethods: scoped.siteMethods,
      liveKeys: scoped.liveKeys,
    );
  }

  /// Detects sites in every analyzed file and keeps the covered ones,
  /// capped at [MutationExecution.maxMutants] (file order, then
  /// offset — the cap is deterministic). In a diff run only sites whose
  /// containing method intersects the changed lines are kept at all;
  /// everything outside the diff is not a mutant of this change and is
  /// neither executed nor counted.
  MutationScan _coveredSites(
    GateContext context,
    MutationGateConfig config,
  ) {
    final detector = MutationSiteDetector(categories: config.operators.toSet());
    final covered = <MutationSite>[];
    final siteMethods = <MutationSite, MethodRef>{};
    final liveKeys = <String>{};
    var uncovered = 0;
    for (final file in context.files) {
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      uncovered += _scanFile(
          file, context, config, detector, covered, siteMethods, liveKeys);
    }
    return (
      sites: covered,
      uncovered: uncovered,
      siteMethods: siteMethods,
      liveKeys: liveKeys
    );
  }

  /// Derives the scoped test invocation for [site] from the project
  /// layout convention: `lib/…` mirrored under `test/` with and
  /// without a `src/` segment (`lib/src/foo/bar.dart` →
  /// `test/src/foo/bar_test.dart`, `test/foo/bar_test.dart`). Returns
  /// `null` when no candidate test file exists — the caller falls back
  /// to the full invocation.
  List<String>? _scopedTestArgs(GateContext context, MutationSite site) {
    final relative = context.relativePath(site.file);
    const libPrefix = 'lib/';
    if (!relative.startsWith(libPrefix)) return null;
    final base = p.withoutExtension(relative.substring(libPrefix.length));
    final candidates = <String>{
      'test/${base}_test.dart',
      if (base.startsWith('src/')) 'test/${base.substring(4)}_test.dart',
    };
    final existing = [
      for (final candidate in candidates)
        if (File(p.join(context.projectRoot, candidate)).existsSync())
          candidate,
    ];
    return existing.isEmpty ? null : [kTest, ...existing];
  }

  /// Whether [site]'s containing method intersects the diff. Falls back
  /// to the site's own line when it sits outside every method.
  bool _inDiff(
    GateContext context,
    String file,
    MutationSite site,
    List<ExtractedMethod> methods,
  ) {
    final diff = context.diff;
    if (diff == null) return true;
    final relative = context.relativePath(file);
    final method = _containingMethod(
        [for (final candidate in methods) candidate.info], site.line);
    if (method != null) {
      return diff.intersects(relative, method.startLine, method.endLine);
    }
    return diff.intersects(relative, site.line, site.line);
  }

  /// Scans one file: records every method's cache identity (live keys),
  /// then keeps the covered sites up to the mutant cap.
  int _scanFile(
    String file,
    GateContext context,
    MutationGateConfig config,
    MutationSiteDetector detector,
    List<MutationSite> covered,
    Map<MutationSite, MethodRef> siteMethods,
    Set<String> liveKeys,
  ) {
    final parsed = context.parsed(file);
    final content = File(file).readAsStringSync();
    final methods = const MethodExtractor()
        .extractWithNodes(parsed.unit, parsed.lineInfo, filePath: file);
    _collectLiveKeys(context, file, content, methods, liveKeys);
    final fileCoverage = _fileCoverage(context, file);
    var uncovered = 0;
    for (final site in detector.detect(parsed)) {
      if (!_inDiff(context, file, site, methods)) continue;
      if (covered.length >= config.execution.maxMutants) break;
      if (_isCovered(
          site, fileCoverage, [for (final method in methods) method.info])) {
        covered.add(site);
        final ref = _methodRef(methods, content, context, file, site);
        if (ref != null) siteMethods[site] = ref;
      } else {
        uncovered++;
      }
    }
    return uncovered;
  }

  /// Adds a cache identity for every extracted method of [file].
  void _collectLiveKeys(
    GateContext context,
    String file,
    String content,
    List<ExtractedMethod> methods,
    Set<String> liveKeys,
  ) {
    for (final method in methods) {
      final key =
          MutationCache.methodsKey(context.relativePath(file), method.info);
      liveKeys.add(key);
    }
  }

  /// The cache identity of the method containing [site]: the stable
  /// methods key plus the FNV digest of the method's exact source span.
  MethodRef? _methodRef(
    List<ExtractedMethod> methods,
    String content,
    GateContext context,
    String file,
    MutationSite site,
  ) {
    for (final method in methods) {
      final node = method.node;
      if (site.offset < node.offset || site.offset > node.end) continue;
      return (
        key: MutationCache.methodsKey(context.relativePath(file), method.info),
        digest: fnv1a64Hex(content.substring(node.offset, node.end)),
        start: node.offset,
      );
    }
    return null;
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
    var summary =
        'score $percent% (${result.killed} killed, ${result.survived} '
        'survived, $uncovered uncovered, ${result.fromCacheCount} cached)';
    if (result.scopedCount > 0) {
      summary = '$summary; test-scoped ${result.scopedCount} '
          '(${result.confirmedCount} re-confirmed killed)';
    }
    if (result.integrityViolations.isNotEmpty) {
      // The tree was healed, but the run is not trustworthy.
      summary = '$summary; INTEGRITY: re-restored after run: '
          '${result.integrityViolations.map(context.relativePath).join(', ')}';
      stderr.writeln(
        'crap4dart mutation: working tree did not restore cleanly '
        '(${result.integrityViolations.length} file(s) re-restored). '
        'Treat this run as suspect and re-run.',
      );
    }
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
