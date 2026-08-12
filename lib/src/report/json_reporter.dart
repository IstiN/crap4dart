import 'dart:convert';

import '../crap/crap_report.dart';
import '../gates/gate.dart';
import '../gates/gate_runner.dart';
import '../profile/profile_reporter.dart';

/// Renders analyze and check results as JSON for machine consumption.
///
/// The output contains only structured data: missing coverage or CRAP
/// values are JSON `null` (never the console placeholder "N/A"), and the
/// method order matches the console report (CRAP descending, N/A last).
class JsonReporter {
  /// Creates a [JsonReporter].
  const JsonReporter();

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Renders the `analyze` report from [report] (already computed metrics)
  /// evaluated against [threshold]. When [diffBase] is given (diff mode),
  /// it is recorded in the output.
  String renderAnalyze(
    CrapReport report, {
    required double threshold,
    String? diffBase,
  }) {
    final maxCrap = report.maxCrap;
    return _encoder.convert({
      'command': 'analyze',
      'threshold': threshold,
      'maxCrap': maxCrap,
      'passed': maxCrap <= threshold,
      if (diffBase != null) ...{'diffMode': true, 'diffBase': diffBase},
      'methods': [
        for (final m in report.sorted)
          {
            'file': m.method.filePath,
            'line': m.method.startLine,
            'class': m.method.className,
            'method': m.method.methodName,
            'complexity': m.complexity,
            'lineCoverage': m.coverage,
            'branchCoverage': m.branchCoverage,
            'crap': m.crap,
          },
      ],
    });
  }

  /// Renders the `check` report from the aggregated [result].
  String renderCheck(GateRunResult result) {
    return _encoder.convert({
      'command': 'check',
      'passed': result.passed,
      'gates': [for (final r in result.results) _gateJson(r)],
    });
  }

  /// Renders the `profile` report from [report], optionally limited to [top]
  /// entries and flagged against [thresholdMs].
  String renderProfile(
    ProfileReport report, {
    double? thresholdMs,
    int? top,
  }) {
    final sorted = report.sorted;
    final shown = top != null && top > 0 ? sorted.take(top).toList() : sorted;
    final totalMicros = report.totalMicros;
    final passed = thresholdMs == null ||
        sorted.every((p) => p.timing.totalMillis <= thresholdMs);
    return _encoder.convert({
      'command': 'profile',
      'totalMicros': totalMicros,
      if (thresholdMs != null) 'thresholdMs': thresholdMs,
      'passed': passed,
      'methods': [
        for (final p in shown)
          {
            'file': p.method.filePath,
            'line': p.method.startLine,
            'class': p.method.className,
            'method': p.method.methodName,
            'calls': p.timing.calls,
            'totalMicros': p.timing.totalMicros,
            'minMicros': p.timing.minMicros,
            'maxMicros': p.timing.maxMicros,
            'meanMicros': p.timing.meanMicros,
          },
      ],
    });
  }

  Map<String, Object?> _gateJson(GateResult r) {
    if (r.skipped) {
      return {'id': r.gateId, 'status': 'skipped', 'reason': r.skipReason};
    }
    return {
      'id': r.gateId,
      'status': r.passed ? 'passed' : 'failed',
      'summary': r.summary,
      'violations': [
        for (final v in r.violations)
          {'file': v.file, 'line': v.line, 'message': v.message},
      ],
    };
  }
}
