import '../config/config.dart';
import '../files/diff_parser.dart';
import 'accessibility_gate.dart';
import 'banned_imports_gate.dart';
import 'class_size_gate.dart';
import 'complexity_gate.dart';
import 'coverage_gate.dart';
import 'duplication_gate.dart';
import 'file_naming_gate.dart';
import 'gate.dart';
import 'gate_context.dart';
import 'golden_gate.dart';
import 'hardcoded_strings_gate.dart';
import 'ignore_filter.dart';
import 'loc_gate.dart';
import 'method_size_gate.dart';
import 'nesting_gate.dart';
import 'public_docs_gate.dart';
import 'unused_code_gate.dart';
import 'unused_files_gate.dart';
import 'weight_of_class_gate.dart';

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
        const NestingGate(),
        const ClassSizeGate(),
        const DuplicationGate(),
        const FileNamingGate(),
        const UnusedCodeGate(),
        const UnusedFilesGate(),
        const BannedImportsGate(),
        const PublicDocsGate(),
        const HardcodedStringsGate(),
        const AccessibilityGate(),
        const GoldenGate(),
        const WeightOfClassGate(),
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
      final postprocessed = _downgradeToWarning(
        _applyIgnores(result, context, gate.id),
        context,
        gate.id,
      );
      results.add(
        diff == null ? postprocessed : _filterByDiff(postprocessed, diff),
      );
    }
    return GateRunResult(results, diffMode: diff != null);
  }

  /// Applies `// crap:ignore` suppression when the gate opts into it via
  /// `ignorable: true` (off by default).
  GateResult _applyIgnores(
    GateResult result,
    GateContext context,
    String gateId,
  ) {
    if (result.passed || !_isIgnorable(gateId, context.config.gates)) {
      return result;
    }
    return filterIgnored(result, context);
  }

  /// Converts failed results of `severity: warning` gates into warning
  /// results: violations are reported but do not fail the run.
  GateResult _downgradeToWarning(
    GateResult result,
    GateContext context,
    String gateId,
  ) {
    if (result.passed || result.skipped) return result;
    if (_severity(gateId, context.config.gates) != GateSeverity.warning) {
      return result;
    }
    return GateResult.warn(
      result.gateId,
      result.violations,
      summary: result.summary,
    );
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
        'nesting' => gates.nesting.enabled,
        'class_size' => gates.classSize.enabled,
        'weight_of_class' => gates.weightOfClass.enabled,
        'unused_code' => gates.unusedCode.enabled,
        'unused_files' => gates.unusedFiles.enabled,
        'banned_imports' => gates.bannedImports.enabled,
        'duplication' => gates.duplication.enabled,
        'file_naming' => gates.fileNaming.enabled,
        'public_docs' => gates.publicDocs.enabled,
        'hardcoded_strings' => gates.hardcodedStrings.enabled,
        'accessibility' => gates.accessibility.enabled,
        'golden' => gates.golden.enabled,
        _ => false,
      };

  bool _isIgnorable(String id, GatesConfig gates) => switch (id) {
        'loc' => gates.loc.ignorable,
        'test_coverage' => gates.testCoverage.ignorable,
        'complexity' => gates.complexity.ignorable,
        'method_size' => gates.methodSize.ignorable,
        'nesting' => gates.nesting.ignorable,
        'class_size' => gates.classSize.ignorable,
        'weight_of_class' => gates.weightOfClass.ignorable,
        'unused_code' => gates.unusedCode.ignorable,
        'unused_files' => gates.unusedFiles.ignorable,
        'banned_imports' => gates.bannedImports.ignorable,
        'duplication' => gates.duplication.ignorable,
        'file_naming' => gates.fileNaming.ignorable,
        'public_docs' => gates.publicDocs.ignorable,
        'hardcoded_strings' => gates.hardcodedStrings.ignorable,
        'accessibility' => gates.accessibility.ignorable,
        'golden' => gates.golden.ignorable,
        _ => false,
      };

  GateSeverity _severity(String id, GatesConfig gates) => switch (id) {
        'loc' => gates.loc.severity,
        'test_coverage' => gates.testCoverage.severity,
        'complexity' => gates.complexity.severity,
        'method_size' => gates.methodSize.severity,
        'nesting' => gates.nesting.severity,
        'class_size' => gates.classSize.severity,
        'weight_of_class' => gates.weightOfClass.severity,
        'unused_code' => gates.unusedCode.severity,
        'unused_files' => gates.unusedFiles.severity,
        'banned_imports' => gates.bannedImports.severity,
        'duplication' => gates.duplication.severity,
        'file_naming' => gates.fileNaming.severity,
        'public_docs' => gates.publicDocs.severity,
        'hardcoded_strings' => gates.hardcodedStrings.severity,
        'accessibility' => gates.accessibility.severity,
        'golden' => gates.golden.severity,
        _ => GateSeverity.error,
      };

  /// Renders [result] as a human readable report. At most [maxViolations]
  /// violations are printed per failed gate; the rest is summarized.
  String render(GateRunResult result, {int maxViolations = 20}) {
    final buffer = StringBuffer();
    for (final gateResult in result.results) {
      buffer.writeln(_renderGate(gateResult, maxViolations, result.diffMode));
    }
    final passed = result.results
        .where((r) => r.passed && !r.skipped && !r.warning)
        .length;
    final warnings = result.results.where((r) => r.warning).length;
    final skipped = result.skippedCount;
    buffer.write(
      result.passed
          ? 'Gates: $passed passed, $warnings warned, $skipped skipped'
          : 'Gates: $passed passed, ${result.failedCount} failed, '
              '$warnings warned, $skipped skipped',
    );
    return buffer.toString();
  }

  String _renderGate(GateResult result, int maxViolations, bool diffMode) {
    if (result.skipped) {
      return '[SKIP] ${result.gateId}: ${result.skipReason}';
    }
    final summary = result.summary == null ? '' : ': ${result.summary}';
    final mode = diffMode ? ' (diff mode)' : '';
    final buffer = StringBuffer(
      '${_status(result)} ${result.gateId}$summary$mode',
    );
    if (!result.passed || result.warning) {
      _writeViolations(buffer, result, maxViolations);
    }
    return buffer.toString();
  }

  String _status(GateResult result) {
    if (result.warning) return '[WARN]';
    return result.passed ? '[PASS]' : '[FAIL]';
  }

  void _writeViolations(
    StringBuffer buffer,
    GateResult result,
    int maxViolations,
  ) {
    final shown = result.violations.take(maxViolations).toList();
    for (final violation in shown) {
      buffer.write('\n  $violation');
    }
    final hidden = result.violations.length - shown.length;
    if (hidden > 0) buffer.write('\n  ... and $hidden more');
  }
}
