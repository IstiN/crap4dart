import 'package:analyzer/dart/ast/ast.dart';

import 'gate.dart';
import 'gate_context.dart';
import 'literal_locations.dart';

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
/// Whole-literal matching alone misses *partial* reuse: `'gates.loc'`,
/// `'gates.nesting'`, ... share the structured head `'gates'` without
/// any two literals being equal. With `deep_search` enabled the gate
/// also counts dot-segment prefixes of dotted string literals
/// (`'gates.loc.entries'` yields the candidates `'gates'` and
/// `'gates.loc'`) and flags prefixes repeating across `min_files`
/// files — the fix is a shared prefix constant composed with the
/// variable remainder. Off by default: prefix matching has a wider FP
/// surface, opt in deliberately.
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
        deepSearch: config.deepSearch,
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
class _LiteralCollector extends ExemptingLiteralVisitor {
  _LiteralCollector(
    super.lineInfo, {
    required this.minLength,
    required this.minValue,
    required this.deepSearch,
  });

  final int minLength;
  final int minValue;

  /// Whether dot-segment prefixes of dotted string literals count as
  /// candidates (partial-reuse detection).
  final bool deepSearch;

  final List<_Hit> hits = [];

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
    _collectString(node.value, node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    final value = node.stringValue;
    if (value == null) return;
    _collectString(value, node);
  }

  void _collectString(String value, AstNode node) {
    if (value.length < minLength) return;
    hits.add(_Hit('s:$value', _display(value), _line(node)));
    if (deepSearch) _collectPrefixes(value, node);
  }

  /// Emits the dot-segment prefixes of [value] as prefix candidates:
  /// the reusable head of a structured literal.
  void _collectPrefixes(String value, AstNode node) {
    var index = value.indexOf('.');
    while (index > 0) {
      final prefix = value.substring(0, index);
      if (prefix.length >= minLength) {
        hits.add(
          _Hit('p:$prefix', "prefix '$prefix'", _line(node)),
        );
      }
      index = value.indexOf('.', index + 1);
    }
  }

  /// String literals render quoted and truncated in messages.
  static String _display(String value) =>
      value.length > 40 ? "'${value.substring(0, 40)}…'" : "'$value'";

  int _line(AstNode node) => lineInfo.getLocation(node.offset).lineNumber;
}
