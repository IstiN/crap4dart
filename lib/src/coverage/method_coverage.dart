import '../analysis/method_extractor.dart';
import 'lcov_parser.dart';

/// Computes per-method coverage from [FileCoverage] line and branch data.
class MethodCoverageCalculator {
  /// Creates a [MethodCoverageCalculator].
  const MethodCoverageCalculator();

  /// Line coverage of [method] as a fraction in `0.0..1.0`.
  ///
  /// Only lines with `DA` records inside `[method.startLine, method.endLine]`
  /// are considered; lines with hits > 0 count as covered. Returns `null`
  /// when no `DA` records fall inside the method's range (coverage N/A).
  double? lineCoverage(MethodInfo method, FileCoverage file) {
    var total = 0;
    var covered = 0;
    for (final entry in file.lineHits.entries) {
      final line = entry.key;
      if (line < method.startLine || line > method.endLine) continue;
      total++;
      if (entry.value > 0) covered++;
    }
    if (total == 0) return null;
    return covered / total;
  }

  /// Branch coverage of [method] as a fraction in `0.0..1.0`.
  ///
  /// Only `BRDA` records inside the method's line range are considered;
  /// a branch counts as covered when it was taken at least once. Returns
  /// `null` when no `BRDA` records fall inside the method's range.
  double? branchCoverage(MethodInfo method, FileCoverage file) {
    var total = 0;
    var covered = 0;
    for (final branch in file.branches) {
      if (branch.line < method.startLine || branch.line > method.endLine) {
        continue;
      }
      total++;
      if (branch.isCovered) covered++;
    }
    if (total == 0) return null;
    return covered / total;
  }
}
