import 'dart:convert';

import '../crap/crap_report.dart';
import '../gates/gate.dart';
import '../gates/gate_runner.dart';
import '../profile/profile_reporter.dart';

/// JSON keys shared across the report shapes.
const String _commandKey = 'command';
const String _passedKey = 'passed';
const String _fileKey = 'file';
const String _lineKey = 'line';

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
      _commandKey: 'analyze',
      'threshold': threshold,
      'maxCrap': maxCrap,
      _passedKey: maxCrap <= threshold,
      if (diffBase != null) ...{'diffMode': true, 'diffBase': diffBase},
      'methods': [
        for (final m in report.sorted)
          {
            _fileKey: m.method.filePath,
            _lineKey: m.method.startLine,
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
      _commandKey: 'check',
      _passedKey: result.passed,
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
      _commandKey: 'profile',
      'totalMicros': totalMicros,
      if (thresholdMs != null) 'thresholdMs': thresholdMs,
      _passedKey: passed,
      'methods': [
        for (final p in shown)
          {
            _fileKey: p.method.filePath,
            _lineKey: p.method.startLine,
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
          {_fileKey: v.file, _lineKey: v.line, 'message': v.message},
      ],
    };
  }
}
