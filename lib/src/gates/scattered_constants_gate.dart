import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../config/config.dart';
import 'gate.dart';
import 'gate_ids.dart';
import 'gate_context.dart';
import 'literal_locations.dart';

/// The `scattered_constants` gate: flags hardcoded literals that
/// either duplicate an existing named constant (immediately, at any
/// occurrence count) or appear in at least `min_files` distinct files
/// with no constant to reference yet.
///
/// The two finding kinds are deliberately different:
///
/// - **Constant regression** — a named constant for the value already
///   exists somewhere in the corpus. The fact has a home; every
///   hardcoded re-introduction (a literal, or a duplicate local
///   `const` in another file) is flagged on sight, even a single
///   occurrence. Waiting for `min_files` would let the scatter regrow
///   before the gate speaks again.
/// - **Scattered literal** — no constant exists yet and the value
///   reached `min_files` distinct files. The classic "change `86400`
///   in every service" hazard: one business fact hardcoded in N
///   places.
///
/// The fix is extraction to a shared named constant and reuse — but
/// the scattered message only asks to *verify* that all occurrences
/// mean the same thing: the gate highlights, intent stays human (the
/// same value is sometimes coincidence). The regression message names
/// the constant and its declaration site to reference.
///
/// The per-file counterpart `magic_constants` counts in-file repeats
/// only, so a literal used once per file in K files is invisible to
/// every existing gate. Unlike that gate, literals inside constant
/// declarations are NOT exempt here: N files each declaring their own
/// local const with the same value is precisely the scatter this gate
/// exists to catch (and once one shared constant exists, the local
/// copies are regressions). Protocol positions stay exempt: map keys,
/// index expressions and case labels are access vocabulary, not
/// constants.
///
/// False-positive controls: string literals shorter than `min_length`
/// and numbers with magnitude at or below `min_value` are treated as
/// coincidence (0, 1, 10, 100 happen everywhere); directive URIs are
/// structural references; values listed in `ignore` are never
/// flagged — repositories can exempt generic vocabulary whose
/// extraction adds churn without benefit.
///
/// Default severity is `warning`: scattering is a design signal, not
/// a bug.
class ScatteredConstantsGate implements Gate {
  /// Creates a [ScatteredConstantsGate].
  const ScatteredConstantsGate();

  @override
  String get id => GateIds.scatteredConstants;

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.scatteredConstants;
    // Plain entries match literal values; entries with a `/` are
    // file-path globs and exempt the files themselves (a crypto
    // package full of magic numbers, a fast-moving test tree, ...).
    final ignore = IgnoreConfig.partition(config.ignore);
    var checked = 0;
    final literals = <String, _ScatteredLiteral>{};
    final constants = <String, List<NamedConstant>>{};
    final aliases = <_PureAlias>[];
    for (final scanned in context.parsedCorpus(
      config.exclude,
      ignore.pathGlobs,
    )) {
      final parsed = scanned.parsed;
      final relative = scanned.relativePath;
      checked++;
      parsed.unit.accept(_ConstantCollector(
        relative,
        parsed.lineInfo,
        constants,
        aliases: aliases,
        minValue: config.minValue,
        ignoreValues: ignore.values,
      ));
      final collector = _LiteralCollector(
        parsed.lineInfo,
        minLength: config.minLength,
        minValue: config.minValue,
        ignoreValues: ignore.values,
      );
      parsed.unit.accept(collector);
      for (final hit in collector.hits) {
        literals
            .putIfAbsent(hit.key, () => _ScatteredLiteral(hit.key, hit.display))
            .add(relative, hit.line, isConstDecl: hit.isConstDecl);
      }
    }
    final violations = [
      for (final literal in literals.values)
        ..._violationsFor(literal, config, constants[literal.key]),
    ];
    final aliasViolations = !config.flagAliases
        ? const <GateViolation>[]
        : [
            for (final alias in aliases)
              if (alias.name.startsWith('_'))
                GateViolation(
                  file: alias.file,
                  line: alias.line,
                  message: 'alias `${alias.name}` adds no information — '
                      'reference `${alias.target}` directly',
                ),
          ];
    final all = [...violations, ...aliasViolations];
    final regressions =
        violations.where((v) => v.message.contains('duplicates')).length;
    final scattered = violations.length - regressions;
    final summary = all.isEmpty
        ? '$checked files scanned, no literals repeat across files'
        : '$regressions hardcoded re-uses of existing constants, '
            '$scattered scattered-literal occurrences'
            '${aliasViolations.isEmpty ? '' : ', '
                '${aliasViolations.length} pure aliases'}';
    return all.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, all, summary: summary);
  }
}

/// A pure value alias: a const declaration whose initializer is
/// another constant's identifier — `const _x = kY;`. Only private
/// declarations are flagged; public re-export shims are deliberate.
class _PureAlias {
  const _PureAlias(this.name, this.target, this.file, this.line);

  final String name;
  final String target;
  final String file;
  final int line;
}

/// Violations for one literal value: constant regressions first (any
/// occurrence count), scattered sites when no constant exists and the
/// file count reached the threshold.
List<GateViolation> _violationsFor(
  _ScatteredLiteral literal,
  ScatteredGateConfig config,
  List<NamedConstant>? constants,
) {
  final shared =
      constants == null || constants.isEmpty ? null : constants.first;
  if (shared != null) {
    return [
      for (final site in literal.sites)
        if (!(site.isConstDecl &&
            site.file == shared.file &&
            site.line == shared.line))
          GateViolation(
            file: site.file,
            line: site.line,
            message: 'hardcoded ${literal.display} duplicates constant '
                '`${shared.name}` (${shared.file}:${shared.line}) — '
                'reference the constant instead of repeating the '
                'literal',
          ),
    ];
  }
  if (literal.files.length < config.minFiles) return const [];
  final scope = '${literal.files.length} files (${literal.sites.length} '
      'occurrences)';
  return [
    for (final site in literal.sites)
      GateViolation(
        file: site.file,
        line: site.line,
        message: 'literal ${literal.display} repeats in $scope — '
            'extract a shared constant and reference it from every '
            'site; verify all occurrences mean the same thing first',
      ),
  ];
}

/// A named constant in the corpus: the declaration every hardcoded
/// occurrence of the same value should reference.
class NamedConstant {
  /// Creates a record of a const declaration.
  const NamedConstant(this.name, this.file, this.line);

  /// Declared identifier.
  final String name;

  /// Declaring file (project-relative).
  final String file;

  /// 1-based declaration line.
  final int line;
}

/// One literal value tracked across the corpus.
class _ScatteredLiteral extends LiteralSites {
  /// Creates a tracker for a literal with canonical [key] rendered as
  /// [display].
  _ScatteredLiteral(this.key, this.display);

  /// Canonical key.
  final String key;

  /// Human readable form for messages.
  final String display;
}

/// A collected literal occurrence: canonical key plus display form,
/// line, and whether the site is itself a constant-declaration
/// initializer (such sites are the good case — a named extraction —
/// or a duplicate local const, never protocol vocabulary).
class _Hit {
  const _Hit(this.key, this.display, this.line, {required this.isConstDecl});

  final String key;
  final String display;
  final int line;
  final bool isConstDecl;
}

/// Collects the corpus-wide registry of named constants: `const`
/// declarations (top-level, static or instance fields) whose
/// initializer is a plain string, int or double literal.
class _ConstantCollector extends RecursiveAstVisitor<void> {
  _ConstantCollector(
    this._file,
    this._lineInfo,
    this._constants, {
    required List<_PureAlias> aliases,
    required int minValue,
    required Set<String> ignoreValues,
  })  : _aliases = aliases,
        _minValue = minValue,
        _ignoreValues = ignoreValues;

  final String _file;
  final LineInfo _lineInfo;
  final Map<String, List<NamedConstant>> _constants;

  /// Numbers at or below this magnitude are coincidence — they leave
  /// the corpus, so small-int constants (exit codes, pixel codes,
  /// versions) never collide with each other. Mirrors the literal
  /// side's [ScatteredConstantsConfig.minValue] doctrine.
  final int _minValue;

  /// Values never flagged are also never corpus entries — an ignored
  /// value cannot be the canonical twin that flags someone else.
  final Set<String> _ignoreValues;

  /// Pure value aliases discovered in the same pass.
  final List<_PureAlias> _aliases;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final parent = node.parent;
    final isConst = parent is VariableDeclarationList && parent.isConst;
    final initializer = node.initializer;
    if (isConst && initializer != null) {
      if (initializer is SimpleIdentifier) {
        _aliases.add(_PureAlias(
          node.name.lexeme,
          initializer.name,
          _file,
          _lineInfo.getLocation(node.offset).lineNumber,
        ));
      }
      final key = _literalKey(initializer);
      if (key != null && !_coincidence(initializer, key)) {
        _constants.putIfAbsent(key, () => []).add(NamedConstant(
              node.name.lexeme,
              _file,
              _lineInfo.getLocation(node.offset).lineNumber,
            ));
      }
    }
    super.visitVariableDeclaration(node);
  }

  /// Whether the initializer is a coincidental value that must not
  /// seed the corpus: small numbers (see [_minValue]) and values the
  /// configuration ignores.
  bool _coincidence(Expression initializer, String key) {
    final numeric = switch (initializer) {
      IntegerLiteral(:final value) => value?.abs(),
      DoubleLiteral(:final value) => value.abs().toInt(),
      _ => null,
    };
    if (numeric != null && numeric <= _minValue) return true;
    final bare =
        key.startsWith('s:') || key.startsWith('i:') || key.startsWith('d:')
            ? key.substring(2)
            : key;
    return _ignoreValues.contains(bare);
  }

  /// The canonical literal key of a plain constant initializer, or
  /// `null` for interpolated strings and computed values.
  String? _literalKey(Expression initializer) {
    final string = stringValueOf(initializer);
    if (string != null) return 's:$string';
    if (initializer is IntegerLiteral) {
      final value = initializer.value;
      if (value != null) return 'i:$value';
    }
    if (initializer is DoubleLiteral) return 'd:${initializer.value}';
    return null;
  }
}

/// Collects literal occurrences eligible for cross-file comparison:
/// strings of at least [minLength] characters and numbers of magnitude
/// at least [minValue]. Constant-declaration literals count too —
/// across files, a local const per file is itself the scatter, and
/// once a shared constant exists the local copies are regressions.
class _LiteralCollector extends RecursiveAstVisitor<void> {
  _LiteralCollector(
    this._lineInfo, {
    required this.minLength,
    required this.minValue,
    required this.ignoreValues,
  });

  final LineInfo _lineInfo;
  final int minLength;
  final int minValue;

  /// Literal values never flagged: whole-literal hits by value.
  /// Generic vocabulary whose extraction adds churn without benefit
  /// lives here.
  final Set<String> ignoreValues;

  final List<_Hit> hits = [];

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final parent = node.parent;
    final isConst = parent is VariableDeclarationList && parent.isConst;
    if (isConst) {
      _collectConstInitializer(node);
    } else {
      node.initializer?.accept(this);
    }
  }

  /// Collects the plain-literal initializer of a const declaration as
  /// one const-decl hit; nested literals (list/map entries) descend
  /// as ordinary hits.
  void _collectConstInitializer(VariableDeclaration node) {
    final initializer = node.initializer;
    if (initializer == null) return;
    final string = stringValueOf(initializer);
    if (string != null) {
      if (!ignoreValues.contains(string)) {
        _addString(string, initializer, isConstDecl: true);
      }
      return;
    }
    if (initializer is IntegerLiteral) {
      final value = initializer.value;
      if (value == null || value.abs() <= minValue) return;
      if (ignoreValues.contains('$value')) return;
      _addNumber('$value', 'i:$value', _line(initializer), isConstDecl: true);
      return;
    }
    if (initializer is DoubleLiteral) {
      if (initializer.value.abs() <= minValue) return;
      final display = '${initializer.value}';
      if (ignoreValues.contains(display)) return;
      _addNumber(display, 'd:$display', _line(initializer), isConstDecl: true);
      return;
    }
    initializer.accept(this);
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    final value = node.value;
    if (value == null || value.abs() <= minValue) return;
    if (ignoreValues.contains('$value')) return;
    _addNumber('$value', 'i:$value', _line(node), isConstDecl: false);
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    if (node.value.abs() <= minValue) return;
    if (ignoreValues.contains('${node.value}')) return;
    _addNumber('${node.value}', 'd:${node.value}', _line(node),
        isConstDecl: false);
  }

  void _addNumber(String display, String key, int line,
      {required bool isConstDecl}) {
    hits.add(_Hit(key, display, line, isConstDecl: isConstDecl));
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    // Map keys, index expressions and case labels are protocol
    // identifiers, not magic constants — same rule as magic_constants.
    if (isProtocolIdentifier(node)) return;
    _addString(node.value, node, isConstDecl: false);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    final value = stringValueOf(node);
    if (value == null) return;
    _addString(value, node, isConstDecl: false);
  }

  void _addString(String value, AstNode node, {required bool isConstDecl}) {
    if (value.length < minLength) return;
    if (ignoreValues.contains(value)) return;
    hits.add(_Hit('s:$value', _display(value), _line(node),
        isConstDecl: isConstDecl));
  }

  /// String literals render quoted and truncated in messages.
  static String _display(String value) =>
      value.length > 40 ? "'${value.substring(0, 40)}…'" : "'$value'";

  int _line(AstNode node) => _lineInfo.getLocation(node.offset).lineNumber;
}
