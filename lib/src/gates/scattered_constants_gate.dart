import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'gate.dart';
import 'literal_locations.dart';
import 'gate_context.dart';

/// The `scattered_constants` gate: flags hardcoded literals that appear
/// in at least `min_files` distinct files.
///
/// The per-file counterpart `magic_constants` counts in-file repeats
/// only, so a literal used once per file in K files is invisible to
/// every existing gate — the classic "change `86400` in every service"
/// hazard: one business fact hardcoded in N places. This gate counts
/// distinct files per literal value across the scanned corpus and
/// flags one violation per occurrence (file + line, so diff mode,
/// baseline and ignore markers work unchanged).
///
/// The fix is extraction to a shared named constant and reuse — but
/// the message only asks to *verify* that all occurrences mean the
/// same thing: the gate highlights, intent stays human (the same value
/// is sometimes coincidence).
///
/// False-positive controls mirror `magic_constants`: string literals
/// shorter than `min_length` and numbers with magnitude at or below
/// `min_value` are treated as coincidence (0, 1, 10, 100 happen
/// everywhere); map keys, index expressions and switch-case labels are
/// protocol identifiers, not constants; literals inside constant
/// declarations are already extracted.
///
/// Default severity is `warning`: scattering is a design signal, not a
/// bug.
class ScatteredConstantsGate implements Gate {
  /// Creates a [ScatteredConstantsGate].
  const ScatteredConstantsGate();

  @override
  String get id => 'scattered_constants';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.scatteredConstants;
    var checked = 0;
    final literals = <String, _ScatteredLiteral>{};
    for (final file in context.files) {
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      checked++;
      final parsed = context.parsed(file);
      final collector = _LiteralCollector(
        parsed.lineInfo,
        minLength: config.minLength,
        minValue: config.minValue,
      );
      parsed.unit.accept(collector);
      final relative = context.relativePath(file);
      for (final hit in collector.hits) {
        if (collector.exemptLines.contains(hit.line)) continue;
        literals
            .putIfAbsent(hit.key, () => _ScatteredLiteral(hit.display))
            .add(relative, hit.line);
      }
    }
    final violations = <GateViolation>[];
    for (final literal in literals.values) {
      if (literal.files.length < config.minFiles) continue;
      for (final site in literal.sites) {
        violations.add(
          GateViolation(
            file: site.file,
            line: site.line,
            message: 'literal ${literal.display} appears in '
                '${literal.files.length} files — extract a shared '
                'constant and verify all occurrences mean the same '
                'thing',
          ),
        );
      }
    }
    final summary = violations.isEmpty
        ? '$checked files scanned, no literals repeat across files'
        : '${literals.values.where((l) => l.files.length >= config.minFiles).length} '
            'literals scattered over ${config.minFiles}+ files '
            '(${violations.length} occurrences)';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }
}

/// One literal value tracked across the corpus.
class _ScatteredLiteral {
  /// Creates a tracker for the literal rendered as [display].
  _ScatteredLiteral(this.display);

  /// Human readable form for messages.
  final String display;

  /// Distinct files containing the literal.
  final Set<String> files = {};

  /// Every occurrence, in scan order.
  final List<_Site> sites = [];

  /// Records one occurrence.
  void add(String file, int line) {
    files.add(file);
    sites.add(_Site(file, line));
  }
}

/// One occurrence site of a scattered literal.
class _Site {
  const _Site(this.file, this.line);

  final String file;
  final int line;
}

/// A collected literal occurrence: canonical key plus display form and
/// line.
class _Hit {
  const _Hit(this.key, this.display, this.line);

  final String key;
  final String display;
  final int line;
}

/// Collects literal occurrences eligible for cross-file comparison:
/// strings of at least [minLength] characters and numbers of magnitude
/// at least [minValue]. Literals inside constant declarations are
/// collected but land in [exemptLines] — they are already extracted.
class _LiteralCollector extends RecursiveAstVisitor<void> {
  _LiteralCollector(
    this._lineInfo, {
    required this.minLength,
    required this.minValue,
  });

  final LineInfo _lineInfo;
  final int minLength;
  final int minValue;

  final List<_Hit> hits = [];
  final Set<int> exemptLines = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final parent = node.parent;
    final isConst = parent is VariableDeclarationList && parent.isConst;
    if (isConst && node.initializer != null) {
      _markConstantLines(node.initializer!);
    }
    node.initializer?.accept(this);
  }

  /// Marks every literal line inside a const initializer as exempt.
  void _markConstantLines(Expression initializer) {
    markExemptLines(exemptLines, _lineInfo, initializer);
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    final value = node.value;
    if (value == null || value.abs() <= minValue) return;
    hits.add(_Hit('i:$value', '$value', _line(node)));
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    final value = node.value;
    if (value.abs() <= minValue) return;
    hits.add(_Hit('d:$value', '$value', _line(node)));
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    // Map keys, index expressions and case labels are protocol
    // identifiers, not magic constants — same rule as magic_constants.
    if (isProtocolIdentifier(node)) return;
    final value = node.value;
    if (value.length < minLength) return;
    hits.add(_Hit('s:$value', _display(value), _line(node)));
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    final value = node.stringValue;
    if (value == null || value.length < minLength) return;
    hits.add(_Hit('s:$value', _display(value), _line(node)));
  }

  /// String literals render quoted and truncated in messages.
  static String _display(String value) =>
      value.length > 40 ? "'${value.substring(0, 40)}…'" : "'$value'";

  int _line(AstNode node) => _lineInfo.getLocation(node.offset).lineNumber;
}
