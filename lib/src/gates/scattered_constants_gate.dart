import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'gate_ids.dart';
import '../config/config.dart';
import 'gate.dart';
import 'gate_context.dart';
import 'literal_locations.dart';

/// The `scattered_constants` gate: flags hardcoded literals that appear
/// in at least `min_files` distinct files.
///
/// `ignore` accepts two entry kinds: plain values (never flagged as
/// whole literals or prefix heads) and file-path globs (any entry
/// containing a `/`; literals inside matching files are exempt).
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
/// Unlike the in-file `magic_constants` gate, literals inside
/// constant declarations are NOT exempt: N files each declaring their
/// own local const with the same value is precisely the scatter this
/// gate exists to catch — the fact should live in one shared constant
/// every file imports. (Protocol positions stay exempt: map keys,
/// index expressions and case labels are access vocabulary, not
/// constants; the shared values behind them should be referenced by
/// name, which removes the literal entirely.)
///
/// False-positive controls: string literals shorter than `min_length`
/// and numbers with magnitude at or below `min_value` are treated as
/// coincidence (0, 1, 10, 100 happen everywhere); directive URIs are
/// structural references; values listed in `ignore` are never
/// flagged — repositories in fast development can exempt generic
/// vocabulary (`'test'`, `'dart'`, `'flutter'`) whose extraction
/// adds churn without benefit.
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
  String get id => GateIds.scatteredConstants;

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.scatteredConstants;
    // Plain entries match literal values and prefix heads; entries
    // with a `/` are file-path globs and exempt the files themselves
    // (a crypto package full of magic numbers, a fast-moving test
    // tree, ...).
    final ignoreValues = <String>{};
    final ignorePaths = <String>[];
    for (final entry in config.ignore) {
      if (entry.contains('/')) {
        ignorePaths.add(entry);
      } else {
        ignoreValues.add(entry);
      }
    }
    var checked = 0;
    final literals = <String, _ScatteredLiteral>{};
    for (final file in context.files) {
      if (context.matchesAnyGlob(file, config.exclude) ||
          context.matchesAnyGlob(file, ignorePaths)) {
        continue;
      }
      checked++;
      final parsed = context.parsed(file);
      final collector = _LiteralCollector(
        parsed.lineInfo,
        minLength: config.minLength,
        minValue: config.minValue,
        deepSearch: config.deepSearch,
        ignoreValues: ignoreValues,
      );
      parsed.unit.accept(collector);
      final relative = context.relativePath(file);
      for (final hit in collector.hits) {
        literals
            .putIfAbsent(hit.key, () => _ScatteredLiteral(hit.key, hit.display))
            .add(relative, hit.line);
      }
    }
    final violations = [
      for (final literal in literals.values) ..._violationsFor(literal, config),
    ];
    final summary = violations.isEmpty
        ? '$checked files scanned, no literals repeat across files'
        : '${violations.length} scattered-literal occurrences';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }
}

/// Violations for one scattered literal, or nothing when its file
/// count is under its kind's threshold.
List<GateViolation> _violationsFor(
  _ScatteredLiteral literal,
  ScatteredConstantsGateConfig config,
) {
  if (literal.files.length < config.minFiles) return const [];
  final advice = literal.isPrefix
      ? 'declare one shared prefix constant and compose every '
          "occurrence from it ('<prefixConstant>.<rest>')"
      : 'extract a shared constant and reference it from every site';
  final scope = '${literal.files.length} files (${literal.sites.length} '
      'occurrences)';
  return [
    for (final site in literal.sites)
      GateViolation(
        file: site.file,
        line: site.line,
        message: 'literal ${literal.display} repeats in $scope — '
            '$advice; verify all occurrences mean the same thing first',
      ),
  ];
}

/// One literal value tracked across the corpus.
class _ScatteredLiteral {
  /// Creates a tracker for a literal with canonical [key] rendered as
  /// [display].
  _ScatteredLiteral(this.key, this.display);

  /// Canonical key; the `p:` namespace marks prefix candidates.
  final String key;

  /// Whether this is a dot-segment prefix candidate.
  bool get isPrefix => key.startsWith('p:');

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
/// at least [minValue]. Constant-declaration literals count too —
/// across files, a local const per file is itself the scatter.
class _LiteralCollector extends RecursiveAstVisitor<void> {
  _LiteralCollector(
    this._lineInfo, {
    required this.minLength,
    required this.minValue,
    required this.deepSearch,
    required this.ignoreValues,
  });

  final LineInfo _lineInfo;
  final int minLength;
  final int minValue;

  /// Whether dot-segment prefixes of dotted string literals count as
  /// candidates (partial-reuse detection).
  final bool deepSearch;

  /// Literal values never flagged: whole-literal hits by value,
  /// prefix hits by head. Generic vocabulary whose extraction adds
  /// churn without benefit lives here.
  final Set<String> ignoreValues;

  final List<_Hit> hits = [];

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    final value = node.value;
    if (value == null || value.abs() <= minValue) return;
    if (ignoreValues.contains('$value')) return;
    hits.add(_Hit('i:$value', '$value', _line(node)));
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    final value = node.value;
    if (value.abs() <= minValue) return;
    if (ignoreValues.contains('$value')) return;
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
    if (ignoreValues.contains(value)) return;
    hits.add(_Hit('s:$value', _display(value), _line(node)));
    if (deepSearch) _collectPrefixes(value, node);
  }

  /// Emits the dot-segment prefixes of [value] as prefix candidates:
  /// the reusable head of a structured literal.
  void _collectPrefixes(String value, AstNode node) {
    var index = value.indexOf('.');
    while (index > 0) {
      final prefix = value.substring(0, index);
      if (prefix.length >= minLength && !ignoreValues.contains(prefix)) {
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

  int _line(AstNode node) => _lineInfo.getLocation(node.offset).lineNumber;
}
