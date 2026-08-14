import 'gate_context.dart';

/// A single violation reported by a quality gate.
class GateViolation {
  /// Creates a [GateViolation].
  const GateViolation({required this.file, this.line, required this.message});

  /// File the violation belongs to (may be a non-Dart artifact path).
  final String file;

  /// 1-based line number, or `null` when not applicable.
  final int? line;

  /// Human readable description of the violation.
  final String message;

  @override
  String toString() =>
      line == null ? '$file: $message' : '$file:$line: $message';
}

/// The outcome of running a single quality gate.
class GateResult {
  /// Creates a [GateResult].
  const GateResult({
    required this.gateId,
    required this.passed,
    this.violations = const [],
    this.summary,
    this.skipped = false,
    this.skipReason,
    this.warning = false,
  });

  /// A passing result with an optional [summary].
  factory GateResult.pass(String gateId, {String? summary}) =>
      GateResult(gateId: gateId, passed: true, summary: summary);

  /// A failing result with [violations] and an optional [summary].
  factory GateResult.fail(
    String gateId,
    List<GateViolation> violations, {
    String? summary,
  }) =>
      GateResult(
        gateId: gateId,
        passed: false,
        violations: violations,
        summary: summary,
      );

  /// A skipped result with a [reason] (e.g. "not a Flutter project").
  factory GateResult.skip(String gateId, String reason) => GateResult(
        gateId: gateId,
        passed: true,
        skipped: true,
        skipReason: reason,
      );

  /// A downgraded result: violations are kept and reported, but the run
  /// is not failed (severity `warning`).
  factory GateResult.warn(
    String gateId,
    List<GateViolation> violations, {
    String? summary,
  }) =>
      GateResult(
        gateId: gateId,
        passed: true,
        violations: violations,
        summary: summary,
        warning: true,
      );

  /// Identifier of the gate that produced this result.
  final String gateId;

  /// Whether the gate passed (skipped and warning results count as
  /// passed for the run outcome).
  final bool passed;

  /// Reported violations; empty when [passed] is true.
  final List<GateViolation> violations;

  /// Optional one-line summary, e.g. "coverage 83.5% >= 80.0%".
  final String? summary;

  /// Whether the gate was skipped instead of run.
  final bool skipped;

  /// Reason for skipping, when [skipped] is true.
  final String? skipReason;

  /// Whether violations were downgraded to warnings (severity
  /// `warning`): reported but not failing the run.
  final bool warning;
}

/// A quality gate: a single check over the project sources.
abstract class Gate {
  /// Unique gate identifier (matches the config key under `gates`).
  String get id;

  /// Runs the gate against [context] and returns the result.
  Future<GateResult> run(GateContext context);
}
