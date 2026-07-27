import 'dart:convert';

import '../crap/crap_report.dart';
import '../gates/gate.dart';
import '../gates/gate_runner.dart';

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
