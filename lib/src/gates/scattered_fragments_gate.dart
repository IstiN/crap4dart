import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import '../config/config.dart';
import 'gate.dart';
import 'gate_context.dart';
import 'literal_locations.dart';

/// The `scattered_fragments` gate: deep search over literal fragments
/// — partial reuse the whole-value `scattered_constants` gate cannot
/// see. Two kinds of findings:
///
/// 1. **Repeated segments.** String literals are split on
///    [ScatteredFragmentsGateConfig.separators]; a segment of at
///    least `min_length` characters appearing in `min_files` distinct
///    files flags per occurrence. (`'gates.loc'`, `'gates.nesting'`,
///    ... share the head `'gates'` — the fix is one shared prefix
///    constant composed into every occurrence.)
/// 2. **Existing-constant candidates.** Every named string constant
///    in the corpus contributes its value and its separator segments
///    as known fragments; a hardcoded literal containing such a
///    fragment flags as a replacement candidate — the message names
///    the constant to reuse or compose from.
///
/// Findings are candidates, not verdicts: the gate highlights, intent
/// stays human. The false-positive floor is `min_length` on the
/// fragment (`const a = 'a'` inside `'loc.a'` never fires). Numbers
/// are out of scope (substring arithmetic is noise); map keys, index
/// expressions, case labels and directive URIs stay exempt; values in
/// `ignore` are never flagged (values by value, path globs with a
/// `/` exempt files).
class ScatteredFragmentsGate implements Gate {
  /// Creates a [ScatteredFragmentsGate].
  const ScatteredFragmentsGate();

  @override
  String get id => 'scattered_fragments';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.scatteredFragments;
    final ignore = IgnoreConfig.partition(config.ignore);
    final ignoreValues = ignore.values;
    final separators = config.separators.split('').toSet();
    var checked = 0;
    final constants = <String, _NamedConstant>{};
    final hardcoded = <String, _HardcodedValue>{};
    for (final scanned in context.parsedCorpus(
      config.exclude,
      ignore.pathGlobs,
    )) {
      final parsed = scanned.parsed;
      final relative = scanned.relativePath;
      checked++;
      final collector = _FragmentCollector(
        parsed.lineInfo,
        minLength: config.minLength,
        separators: separators,
        ignoreValues: ignore.values,
      );
      parsed.unit.accept(collector);
      collector.constValues.forEach((value, name) {
        constants.putIfAbsent(value, () => _NamedConstant(value, name));
      });
      for (final hit in collector.hardcodedHits) {
        hardcoded
            .putIfAbsent(hit.value, () => _HardcodedValue(hit.value))
            .add(relative, hit.line);
      }
    }
    final violations =
        _violations(config, separators, constants, hardcoded, ignoreValues);
    final summary = violations.isEmpty
        ? '$checked files scanned, no literal fragments to reconsider'
        : '${violations.length} fragment-reuse candidates';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  List<GateViolation> _violations(
    ScatteredGateConfig config,
    Set<String> separators,
    Map<String, _NamedConstant> constants,
    Map<String, _HardcodedValue> hardcoded,
    Set<String> ignoreValues,
  ) {
    // Known fragments: every named constant's value and segments.
    final fragmentOwners = <String, _NamedConstant>{};
    constants.forEach((value, constant) {
      for (final fragment in _fragmentsOf(value, separators, config)) {
        fragmentOwners.putIfAbsent(fragment, () => constant);
      }
    });
    final violations = <GateViolation>[];
    final segmentFiles = <String, Set<String>>{};
    final segmentSites = <String, List<LiteralSite>>{};
    hardcoded.forEach((value, sites) {
      for (final site in sites.sites) {
        final file = site.file;
        final line = site.line;
        // Existing-constant candidates.
        fragmentOwners.forEach((fragment, constant) {
          if (!value.contains(fragment)) return;
          final equal = value == fragment;
          violations.add(
            GateViolation(
              file: file,
              line: line,
              message: equal
                  ? "hardcoded '$value' duplicates constant "
                      "'${constant.name}' — reference the constant "
                      'instead; verify the match is real'
                  : "hardcoded '$value' contains fragment '$fragment' of "
                      "constant '${constant.name}' — reuse or compose "
                      'from the constant instead; verify the match is '
                      'real',
            ),
          );
        });
        // Repeated segments.
        for (final segment in _segmentsOf(value, separators)) {
          if (ignoreValues.contains(segment)) continue;
          segmentFiles.putIfAbsent(segment, () => {}).add(file);
          segmentSites
              .putIfAbsent(segment, () => [])
              .add((file: file, line: line));
        }
      }
    });
    segmentFiles.forEach((segment, files) {
      if (files.length < config.minFiles) return;
      for (final site in segmentSites[segment]!) {
        final file = site.file;
        final line = site.line;
        violations.add(
          GateViolation(
            file: file,
            line: line,
            message: "literal segment '$segment' repeats in "
                '${files.length} files — declare a shared constant for '
                'the segment and compose every occurrence from it; '
                'verify the reuse is real',
          ),
        );
      }
    });
    return violations;
  }

  /// The value itself plus its separator segments, each at least
  /// `min_length` characters long.
  static List<String> _fragmentsOf(
    String value,
    Set<String> separators,
    ScatteredGateConfig config,
  ) {
    final fragments = <String>[
      if (value.length >= config.minLength) value,
      ..._segmentsOf(value, separators)
          .where((s) => s.length >= config.minLength),
    ];
    return fragments.toSet().toList();
  }

  /// Separator-delimited segments of [value].
  static List<String> _segmentsOf(String value, Set<String> separators) {
    final segments = <String>[];
    final current = StringBuffer();
    for (final char in value.split('')) {
      if (separators.contains(char)) {
        if (current.isNotEmpty) segments.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) segments.add(current.toString());
    return segments;
  }
}

/// A named string constant discovered in the corpus.
class _NamedConstant {
  /// Creates a descriptor for the constant named [name].
  const _NamedConstant(this.value, this.name);

  /// The constant's string value.
  final String value;

  /// The constant's declared name.
  final String name;
}

/// A hardcoded string value tracked across the corpus.
class _HardcodedValue extends LiteralSites {
  /// Creates a tracker for [value].
  _HardcodedValue(this.value);

  /// The literal's value.
  final String value;
}

/// Collects named string constants and hardcoded string literals.
class _FragmentCollector extends ExemptingLiteralVisitor {
  _FragmentCollector(
    super.lineInfo, {
    required this.minLength,
    required this.separators,
    required this.ignoreValues,
  });

  LineInfo get _lineInfo => lineInfo;
  final int minLength;
  final Set<String> separators;
  final Set<String> ignoreValues;

  /// Named string constants: value -> first declared name.
  final Map<String, String> constValues = {};

  /// Hardcoded string literals, in scan order.
  final List<_SiteWithValue> hardcodedHits = [];

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    super.visitVariableDeclaration(node);
    final parent = node.parent;
    final isConst = parent is VariableDeclarationList && parent.isConst;
    final initializer = node.initializer;
    if (!isConst || initializer == null) return;
    final value = stringValueOf(initializer);
    if (value == null ||
        value.length < minLength ||
        ignoreValues.contains(value)) {
      return;
    }
    constValues.putIfAbsent(value, () => node.name.lexeme);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (isProtocolIdentifier(node)) return;
    _collectHardcoded(node.value, node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    final value = stringValueOf(node);
    if (value == null) return;
    _collectHardcoded(value, node);
  }

  void _collectHardcoded(String value, AstNode node) {
    if (value.length < minLength) return;
    if (ignoreValues.contains(value)) return;
    if (exemptLines.contains(_line(node))) return;
    hardcodedHits.add(_SiteWithValue(value, _line(node)));
  }

  int _line(AstNode node) => _lineInfo.getLocation(node.offset).lineNumber;
}

/// A hardcoded literal with its line.
class _SiteWithValue {
  /// Creates an entry.
  const _SiteWithValue(this.value, this.line);

  /// The literal's value.
  final String value;

  /// 1-based line.
  final int line;
}
