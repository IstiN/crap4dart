import 'dart:math' as math;

/// Computes the CRAP (Change Risk Anti-Patterns) score.
///
/// `CRAP = CC^2 * (1 - coverage)^3 + CC`
///
/// where `CC` is the cyclomatic complexity of a method and `coverage` is
/// its line coverage fraction in `0.0..1.0`.
///
/// Returns `null` when [coverage] is `null` (coverage N/A).
double? crapScore(int complexity, double? coverage) {
  if (coverage == null) return null;
  final uncovered = 1 - coverage;
  return complexity * complexity * math.pow(uncovered, 3).toDouble() +
      complexity;
}
