import '../config/config.dart';
import '../files/diff_parser.dart';
import 'accessibility_gate.dart';
import 'complexity_gate.dart';
import 'coverage_gate.dart';
import 'duplication_gate.dart';
import 'gate.dart';
import 'gate_context.dart';
import 'golden_gate.dart';
import 'hardcoded_strings_gate.dart';
import 'loc_gate.dart';
import 'method_size_gate.dart';
import 'public_docs_gate.dart';

/// Aggregated outcome of a [GateRunner] run.
class GateRunResult {
  /// Creates a [GateRunResult].
  const GateRunResult(this.results, {this.diffMode = false});

  /// Per-gate results in run order.
  final List<GateResult> results;

  /// Whether the run was filtered to changed lines (diff mode).
  final bool diffMode;

  /// Whether every run gate passed (skipped gates count as passed).
  bool get passed => results.every((r) => r.passed);

  /// Number of gates that failed.
  int get failedCount => results.where((r) => !r.passed).length;

  /// Number of gates that were skipped.
  int get skippedCount => results.where((r) => r.skipped).length;
}

/// Runs the enabled quality gates of a project configuration.
class GateRunner {
  /// Creates a [GateRunner] with [gates] (defaults to all built-in gates
  /// in their fixed order).
  GateRunner({List<Gate>? gates}) : gates = gates ?? defaultGates();

  /// The gates to run, in order.
  final List<Gate> gates;

  /// All built-in gates in their fixed run order.
  static List<Gate> defaultGates() => [
        const LocGate(),
        const CoverageGate(),
        const ComplexityGate(),
        const MethodSizeGate(),
        const DuplicationGate(),
        const PublicDocsGate(),
        const HardcodedStringsGate(),
        const AccessibilityGate(),
        const GoldenGate(),
      ];

  /// Runs every enabled gate against [context].
  ///
  /// When [only] is given, only gates whose id is in [only] run; gates
  /// whose id is in [skip] never run. Gates disabled in the configuration
  /// produce a skipped result.
  ///
  /// When [diff] is given (diff mode), violations are filtered to the
  /// changed lines: violations with a line number survive only when that
  /// line was added/changed; file-level violations (no line) survive only
  /// for files with real changes. Gate summaries are kept as-is.
  Future<GateRunResult> run(
    GateContext context, {
    Set<String>? only,
    Set<String>? skip,
    DiffLineMap? diff,
  }) async {
    final results = <GateResult>[];
    for (final gate in gates) {
      if (only != null && !only.contains(gate.id)) continue;
      if (skip != null && skip.contains(gate.id)) continue;
      if (!_isEnabled(gate.id, context.config.gates)) {
        results.add(GateResult.skip(gate.id, 'disabled in config'));
        continue;
      }
      final result = await gate.run(context);
      results.add(diff == null ? result : _filterByDiff(result, diff));
    }
    return GateRunResult(results, diffMode: diff != null);
  }

  GateResult _filterByDiff(GateResult result, DiffLineMap diff) {
    if (result.passed || result.skipped) return result;
    final kept = [
      for (final violation in result.violations)
        if (_survives(violation, diff)) violation,
    ];
    return GateResult(
      gateId: result.gateId,
      passed: kept.isEmpty,
      violations: kept,
      summary: result.summary,
    );
  }

  bool _survives(GateViolation violation, DiffLineMap diff) {
    final line = violation.line;
    if (line == null) return diff.hasRealChanges(violation.file);
    return diff.linesFor(violation.file).contains(line);
  }

  bool _isEnabled(String id, GatesConfig gates) => switch (id) {
        'loc' => gates.loc.enabled,
        'test_coverage' => gates.testCoverage.enabled,
        'complexity' => gates.complexity.enabled,
        'method_size' => gates.methodSize.enabled,
        'duplication' => gates.duplication.enabled,
        'public_docs' => gates.publicDocs.enabled,
        'hardcoded_strings' => gates.hardcodedStrings.enabled,
        'accessibility' => gates.accessibility.enabled,
        'golden' => gates.golden.enabled,
        _ => false,
      };

  /// Renders [result] as a human readable report. At most [maxViolations]
  /// violations are printed per failed gate; the rest is summarized.
  String render(GateRunResult result, {int maxViolations = 20}) {
    final buffer = StringBuffer();
    for (final gateResult in result.results) {
      buffer.writeln(_renderGate(gateResult, maxViolations, result.diffMode));
    }
    final passed =
        result.results.length - result.failedCount - result.skippedCount;
    buffer.write(
      result.passed
          ? 'Gates: $passed passed, ${result.skippedCount} skipped'
          : 'Gates: $passed passed, ${result.failedCount} failed, '
              '${result.skippedCount} skipped',
    );
    return buffer.toString();
  }

  String _renderGate(GateResult result, int maxViolations, bool diffMode) {
    final buffer = StringBuffer();
    if (result.skipped) {
      buffer.write('[SKIP] ${result.gateId}: ${result.skipReason}');
      return buffer.toString();
    }
    final summary = result.summary == null ? '' : ': ${result.summary}';
    final mode = diffMode ? ' (diff mode)' : '';
    buffer.write(result.passed ? '[PASS] ' : '[FAIL] ');
    buffer.write('${result.gateId}$summary$mode');
    if (!result.passed) {
      final shown = result.violations.take(maxViolations).toList();
      for (final violation in shown) {
        buffer.write('\n  $violation');
      }
      final hidden = result.violations.length - shown.length;
      if (hidden > 0) buffer.write('\n  ... and $hidden more');
    }
    return buffer.toString();
  }
}
