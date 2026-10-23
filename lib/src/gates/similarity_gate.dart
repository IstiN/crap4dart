import 'dart:io';

import '../similarity/similarity_analyzer.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `similarity` gate: flags files whose content is near-duplicate
/// of other files — copied docs that drifted apart, twin templates
/// differing by a heading, stale snapshot copies, generated files
/// duplicating their sources.
///
/// Unlike the `duplication` gate (token-level clone blocks inside Dart
/// code), this is file-level over any text: each violation says "this
/// file is (mostly) a copy of that file", which is a structural
/// problem — reuse, generation or deletion — not an extract-method
/// refactor.
class SimilarityGate implements Gate {
  /// Creates a [SimilarityGate].
  const SimilarityGate();

  @override
  String get id => 'similarity';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.similarity;
    final report = const SimilarityAnalyzer().analyze(
      Directory(context.projectRoot),
      dirs: config.dirs,
      include: config.include,
      exclude: config.exclude,
      jaccardThreshold: config.jaccard,
      containmentThreshold: config.containment,
      minShingles: config.minShingles,
    );
    if (report.clean) {
      return GateResult.pass(
        id,
        summary: '${report.scanned} files scanned, '
            'no similar files (jaccard ${config.jaccard}, '
            'containment ${config.containment})',
      );
    }
    final violations = [
      for (final path in report.clusteredPaths)
        _violation(path, report, context),
    ];
    final summary = '${violations.length} files in '
        '${report.clusters.length} similar-file clusters '
        '(${report.scanned} scanned)';
    return GateResult.fail(id, violations, summary: summary);
  }

  /// The violation for one clustered [path].
  GateViolation _violation(
    String path,
    SimilarityReport report,
    GateContext context,
  ) {
    final cluster = report.clusters.firstWhere((c) => c.files.contains(path));
    final others = cluster.files.where((f) => f != path).take(2).toList();
    final more = cluster.files.length - others.length - 1;
    final metrics = report.metricsFor(path);
    return GateViolation(
      file: context.relativePath('${context.projectRoot}/$path'),
      message: 'similar to ${others.join(', ')}'
          '${more > 0 ? ' (+$more more)' : ''} — near-duplicate content '
          '(jaccard ${metrics?.jaccard.toStringAsFixed(2)}, '
          'containment ${metrics?.containment.toStringAsFixed(2)}); reuse the shared '
          'source, generate one of them, or delete the stale copy',
    );
  }
}
