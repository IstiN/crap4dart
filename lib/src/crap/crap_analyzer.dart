import 'dart:io';

import 'package:path/path.dart' as p;

import '../analysis/complexity.dart';
import '../analysis/dart_parser.dart';
import '../analysis/method_extractor.dart';
import '../coverage/lcov_parser.dart';
import '../coverage/method_coverage.dart';
import 'crap_score.dart';

/// Full metric set for a single method.
class MethodMetrics {
  /// Creates a [MethodMetrics].
  const MethodMetrics({
    required this.method,
    required this.complexity,
    required this.coverage,
    required this.branchCoverage,
    required this.crap,
  });

  /// The analyzed method.
  final MethodInfo method;

  /// Cyclomatic complexity of the method.
  final int complexity;

  /// Line coverage fraction in `0.0..1.0`, or `null` when N/A.
  final double? coverage;

  /// Branch coverage fraction in `0.0..1.0`, or `null` when N/A.
  final double? branchCoverage;

  /// CRAP score, or `null` when [coverage] is `null`.
  final double? crap;
}

/// Combines parsing, complexity and coverage into per-method CRAP metrics.
class CrapAnalyzer {
  /// Creates a [CrapAnalyzer].
  const CrapAnalyzer();

  /// Analyzes the Dart source files at [filePaths].
  ///
  /// When [lcovPath] is given and the file exists, coverage from it is
  /// attributed to methods; otherwise coverage and CRAP are `null`.
  /// [projectRoot] is used to match LCOV `SF` paths against analyzed files.
  /// [countLambdas] controls whether lambda branches count towards the
  /// enclosing method's complexity.
  List<MethodMetrics> analyze(
    List<String> filePaths, {
    String? lcovPath,
    String? projectRoot,
    bool countLambdas = true,
  }) {
    final coverageByFile = _loadCoverage(lcovPath, projectRoot);
    final parser = DartParser();
    const extractor = MethodExtractor();
    final complexityCalculator =
        ComplexityCalculator(countLambdas: countLambdas);
    const coverageCalculator = MethodCoverageCalculator();

    final results = <MethodMetrics>[];
    for (final filePath in filePaths) {
      final content = File(filePath).readAsStringSync();
      final parsed = parser.parse(content: content, path: filePath);
      final methods = extractor.extractWithNodes(
        parsed.unit,
        parsed.lineInfo,
        filePath: filePath,
      );
      final fileCoverage = _coverageFor(coverageByFile, filePath, projectRoot);
      for (final extracted in methods) {
        final method = extracted.info;
        final complexity = complexityCalculator.compute(extracted.node);
        final coverage = fileCoverage == null
            ? null
            : coverageCalculator.lineCoverage(method, fileCoverage);
        final branchCoverage = fileCoverage == null
            ? null
            : coverageCalculator.branchCoverage(method, fileCoverage);
        results.add(
          MethodMetrics(
            method: method,
            complexity: complexity,
            coverage: coverage,
            branchCoverage: branchCoverage,
            crap: crapScore(complexity, coverage),
          ),
        );
      }
    }
    return results;
  }

  Map<String, FileCoverage> _loadCoverage(String? lcovPath, String? root) {
    if (lcovPath == null) return {};
    final file = File(lcovPath);
    if (!file.existsSync()) return {};
    final parser = LcovParser(projectRoot: root);
    return {
      for (final f in parser.parse(file.readAsStringSync()))
        // Ignore entries that are not project-relative (absolute paths or
        // paths escaping the root, e.g. dependency sources from the pub
        // cache): they must never be attributed to project files.
        if (_isProjectRelative(f.path)) f.path: f,
    };
  }

  bool _isProjectRelative(String path) =>
      !p.isAbsolute(path) && !path.startsWith('..');

  FileCoverage? _coverageFor(
    Map<String, FileCoverage> coverageByFile,
    String filePath,
    String? projectRoot,
  ) {
    if (coverageByFile.isEmpty) return null;
    final path = p.normalize(filePath);
    final direct = coverageByFile[path];
    if (direct != null) return direct;
    if (p.isAbsolute(path)) {
      final root = projectRoot ?? Directory.current.path;
      final relative = p.relative(path, from: root);
      final fromRoot = coverageByFile[relative];
      if (fromRoot != null) return fromRoot;
    }
    // Fall back to suffix matching (e.g. LCOV stores "lib/foo.dart" while
    // the analyzed path is absolute, or vice versa).
    for (final entry in coverageByFile.entries) {
      if (path.endsWith(entry.key) || entry.key.endsWith(path)) {
        return entry.value;
      }
    }
    return null;
  }
}
