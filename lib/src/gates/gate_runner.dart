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
import 'magic_constants_gate.dart';
import 'method_size_gate.dart';
import 'nesting_gate.dart';
import 'public_docs_gate.dart';
import 'unused_code_gate.dart';
import 'unused_files_gate.dart';
import 'weight_of_class_gate.dart';

/// Gate id constants shared by the enabled/ignorable/severity lookups.
const String _locId = 'loc';
const String _testCoverageId = 'test_coverage';
const String _complexityId = 'complexity';
const String _methodSizeId = 'method_size';
const String _nestingId = 'nesting';
const String _classSizeId = 'class_size';
const String _weightOfClassId = 'weight_of_class';
const String _unusedCodeId = 'unused_code';
const String _unusedFilesId = 'unused_files';
const String _bannedImportsId = 'banned_imports';
const String _duplicationId = 'duplication';
const String _fileNamingId = 'file_naming';
const String _magicConstantsId = 'magic_constants';
const String _publicDocsId = 'public_docs';
const String _hardcodedStringsId = 'hardcoded_strings';
const String _accessibilityId = 'accessibility';
const String _goldenId = 'golden';

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
        const MagicConstantsGate(),
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
        _locId => gates.loc.enabled,
        _testCoverageId => gates.testCoverage.enabled,
        _complexityId => gates.complexity.enabled,
        _methodSizeId => gates.methodSize.enabled,
        _nestingId => gates.nesting.enabled,
        _classSizeId => gates.classSize.enabled,
        _weightOfClassId => gates.weightOfClass.enabled,
        _unusedCodeId => gates.unusedCode.enabled,
        _unusedFilesId => gates.unusedFiles.enabled,
        _bannedImportsId => gates.bannedImports.enabled,
        _duplicationId => gates.duplication.enabled,
        _fileNamingId => gates.fileNaming.enabled,
        _magicConstantsId => gates.magicConstants.enabled,
        _publicDocsId => gates.publicDocs.enabled,
        _hardcodedStringsId => gates.hardcodedStrings.enabled,
        _accessibilityId => gates.accessibility.enabled,
        _goldenId => gates.golden.enabled,
        _ => false,
      };

  bool _isIgnorable(String id, GatesConfig gates) => switch (id) {
        _locId => gates.loc.ignorable,
        _testCoverageId => gates.testCoverage.ignorable,
        _complexityId => gates.complexity.ignorable,
        _methodSizeId => gates.methodSize.ignorable,
        _nestingId => gates.nesting.ignorable,
        _classSizeId => gates.classSize.ignorable,
        _weightOfClassId => gates.weightOfClass.ignorable,
        _unusedCodeId => gates.unusedCode.ignorable,
        _unusedFilesId => gates.unusedFiles.ignorable,
        _bannedImportsId => gates.bannedImports.ignorable,
        _duplicationId => gates.duplication.ignorable,
        _fileNamingId => gates.fileNaming.ignorable,
        _magicConstantsId => gates.magicConstants.ignorable,
        _publicDocsId => gates.publicDocs.ignorable,
        _hardcodedStringsId => gates.hardcodedStrings.ignorable,
        _accessibilityId => gates.accessibility.ignorable,
        _goldenId => gates.golden.ignorable,
        _ => false,
      };

  GateSeverity _severity(String id, GatesConfig gates) => switch (id) {
        _locId => gates.loc.severity,
        _testCoverageId => gates.testCoverage.severity,
        _complexityId => gates.complexity.severity,
        _methodSizeId => gates.methodSize.severity,
        _nestingId => gates.nesting.severity,
        _classSizeId => gates.classSize.severity,
        _weightOfClassId => gates.weightOfClass.severity,
        _unusedCodeId => gates.unusedCode.severity,
        _unusedFilesId => gates.unusedFiles.severity,
        _bannedImportsId => gates.bannedImports.severity,
        _duplicationId => gates.duplication.severity,
        _fileNamingId => gates.fileNaming.severity,
        _magicConstantsId => gates.magicConstants.severity,
        _publicDocsId => gates.publicDocs.severity,
        _hardcodedStringsId => gates.hardcodedStrings.severity,
        _accessibilityId => gates.accessibility.severity,
        _goldenId => gates.golden.severity,
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
