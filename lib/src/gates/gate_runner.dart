import '../config/config.dart';
import '../files/diff_parser.dart';
import 'accessibility_gate.dart';
import 'banned_imports_gate.dart';
import 'broken_goldens_gate.dart';
import 'class_size_gate.dart';
import 'complexity_gate.dart';
import 'coverage_gate.dart';
import 'duplication_gate.dart';
import 'external_gate.dart';
import 'file_naming_gate.dart';
import 'folder_structure_gate.dart';
import 'gate.dart';
import 'gate_context.dart';
import 'golden_gate.dart';
import 'hardcoded_strings_gate.dart';
import 'ignore_filter.dart';
import 'loc_gate.dart';
import 'magic_constants_gate.dart';
import 'method_size_gate.dart';
import 'mutation_gate.dart';
import 'named_record_shapes_gate.dart';
import 'nesting_gate.dart';
import 'public_docs_gate.dart';
import 'similarity_gate.dart';
import 'test_assertions_gate.dart';
import 'unused_code_gate.dart';
import 'unused_files_gate.dart';
import 'weight_of_class_gate.dart';

/// Gate id constants shared by the enabled/ignorable/severity lookups.
const String _locId = 'loc';
const String _testCoverageId = 'test_coverage';
const String _complexityId = 'complexity';
const String _methodSizeId = 'method_size';
const String _nestingId = 'nesting';
const String _namedRecordShapesId = 'named_record_shapes';
const String _classSizeId = 'class_size';
const String _weightOfClassId = 'weight_of_class';
const String _unusedCodeId = 'unused_code';
const String _unusedFilesId = 'unused_files';
const String _bannedImportsId = 'banned_imports';
const String _duplicationId = 'duplication';
const String _fileNamingId = 'file_naming';
const String _magicConstantsId = 'magic_constants';
const String _brokenGoldensId = 'broken_goldens';
const String _testAssertionsId = 'test_assertions';
const String _folderStructureId = 'folder_structure';
const String _externalId = 'external';
const String _publicDocsId = 'public_docs';
const String _hardcodedStringsId = 'hardcoded_strings';
const String _accessibilityId = 'accessibility';
const String _goldenId = 'golden';
const String _mutationId = 'mutation';
const String _similarityId = 'similarity';

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
        const NamedRecordShapesGate(),
        const ClassSizeGate(),
        const DuplicationGate(),
        const FileNamingGate(),
        const MagicConstantsGate(),
        const BrokenGoldensGate(),
        const TestAssertionsGate(),
        const FolderStructureGate(),
        const ExternalGate(),
        const BrokenGoldensGate(),
        const TestAssertionsGate(),
        const FolderStructureGate(),
        const ExternalGate(),
        const UnusedCodeGate(),
        const UnusedFilesGate(),
        const BannedImportsGate(),
        const PublicDocsGate(),
        const HardcodedStringsGate(),
        const AccessibilityGate(),
        const GoldenGate(),
        const WeightOfClassGate(),
        MutationGate(),
        const SimilarityGate(),
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

  /// Lookup table from gate id to its configuration, built per run from
  /// [gates]. Replaces what used to be three 22-case switch chains —
  /// switch-expression cases now count towards cyclomatic complexity,
  /// and a table keeps the dispatch flat.
  Map<String, GateConfigFlags> _flagTable(GatesConfig gates) => {
        _locId: gates.loc,
        _testCoverageId: gates.testCoverage,
        _complexityId: gates.complexity,
        _methodSizeId: gates.methodSize,
        _nestingId: gates.nesting,
        _namedRecordShapesId: gates.namedRecordShapes,
        _classSizeId: gates.classSize,
        _weightOfClassId: gates.weightOfClass,
        _unusedCodeId: gates.unusedCode,
        _unusedFilesId: gates.unusedFiles,
        _bannedImportsId: gates.bannedImports,
        _duplicationId: gates.duplication,
        _fileNamingId: gates.fileNaming,
        _magicConstantsId: gates.magicConstants,
        _brokenGoldensId: gates.brokenGoldens,
        _testAssertionsId: gates.testAssertions,
        _folderStructureId: gates.folderStructure,
        _externalId: gates.external,
        _publicDocsId: gates.publicDocs,
        _hardcodedStringsId: gates.hardcodedStrings,
        _accessibilityId: gates.accessibility,
        _goldenId: gates.golden,
        _mutationId: gates.mutation,
        _similarityId: gates.similarity,
      };

  bool _isEnabled(String id, GatesConfig gates) =>
      _flagTable(gates)[id]?.enabled ?? false;

  bool _isIgnorable(String id, GatesConfig gates) =>
      _flagTable(gates)[id]?.ignorable ?? false;

  GateSeverity _severity(String id, GatesConfig gates) =>
      _flagTable(gates)[id]?.severity ?? GateSeverity.error;

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
