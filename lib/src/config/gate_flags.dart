part of 'config.dart';

/// Which complexity metric the `complexity` gate applies `max_complexity`
/// to.
enum ComplexityMetric {
  /// Classic cyclomatic complexity — a path count; also feeds the CRAP
  /// score of the `analyze` command regardless of this setting.
  cyclomatic,

  /// SonarSource-style cognitive complexity — flow breaks weighted by
  /// their nesting depth; flat `else if` chains stay cheap.
  cognitive;

  /// Parses a `metric:` config value, `null` when unrecognized.
  static ComplexityMetric? tryParse(String value) {
    for (final metric in values) {
      if (metric.name == value) return metric;
    }
    return null;
  }
}

/// The three flags every gate configuration carries. Implementing this
/// interface lets [GateRunner] dispatch by gate id through one lookup
/// table instead of per-field switch chains.
abstract interface class GateConfigFlags {
  /// Whether the gate is enabled.
  bool get enabled;

  /// Whether `// crap:ignore` comments may suppress its violations.
  bool get ignorable;

  /// Whether violations fail the run or are reported as warnings.
  GateSeverity get severity;
}
