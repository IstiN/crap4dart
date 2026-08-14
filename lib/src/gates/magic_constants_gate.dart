import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../config/config.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `magic_constants` gate: flags magic literals — hex color values
/// used outside named constant declarations, and numeric or string
/// literals that repeat `min_duplicates` times or more in one file.
///
/// Repeated literals and inline colors are a typical AI-refactor
/// artifact: every occurrence should become a named constant instead.
class MagicConstantsGate implements Gate {
  /// Creates a [MagicConstantsGate].
  const MagicConstantsGate();

  @override
  String get id => 'magic_constants';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.magicConstants;
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      checked++;
      final parsed = context.parsed(file);
      final visitor = _MagicLiteralsVisitor(
        parsed.lineInfo,
        config.minLength,
      );
      parsed.unit.accept(visitor);
      final relative = context.relativePath(file);
      violations.addAll(_violations(relative, visitor, config));
    }
    final summary = violations.isEmpty
        ? '$checked files free of magic constants'
        : '${violations.length} magic constant(s) in $checked files';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// Violations for one file from the collected literal occurrences.
  List<GateViolation> _violations(
    String relative,
    _MagicLiteralsVisitor visitor,
    MagicConstantsGateConfig config,
  ) {
    final violations = <GateViolation>[];
    if (config.flagHexColors) {
      for (final occurrence in visitor.hexColors) {
        if (visitor.constantLines.contains(occurrence.line)) continue;
        violations.add(
          GateViolation(
            file: relative,
            line: occurrence.line,
            message: 'hex color outside a constant declaration',
          ),
        );
      }
    }
    for (final entry in visitor.counts.entries) {
      if (entry.value.length < config.minDuplicates) continue;
      for (final occurrence in entry.value) {
        violations.add(
          GateViolation(
            file: relative,
            line: occurrence.line,
            message: 'literal ${entry.key} repeats '
                '${entry.value.length} times — extract a named constant',
          ),
        );
      }
    }
    return violations;
  }
}

/// One literal occurrence with its 1-based line.
class _Occurrence {
  const _Occurrence(this.line);

  final int line;
}

/// Collects hex color literals, literal occurrence counts and the
/// lines that belong to constant declarations.
class _MagicLiteralsVisitor extends RecursiveAstVisitor<void> {
  _MagicLiteralsVisitor(this._lineInfo, this.minLength);

  final LineInfo _lineInfo;
  final int minLength;
  final List<_Occurrence> hexColors = [];
  final Map<String, List<_Occurrence>> counts = {};
  final Set<int> constantLines = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final parent = node.parent;
    final isConst = parent is VariableDeclarationList && parent.isConst;
    if (isConst && node.initializer != null) {
      _markConstantLines(node.initializer!);
    }
    node.initializer?.accept(this);
  }

  /// Records the lines of a constant initializer as hex-color-exempt.
  void _markConstantLines(Expression initializer) {
    constantLines.add(_line(initializer));
    if (initializer is InstanceCreationExpression) {
      for (final argument in initializer.argumentList.arguments) {
        constantLines.add(_line(argument));
      }
    }
    if (initializer is MethodInvocation) {
      for (final argument in initializer.argumentList.arguments) {
        constantLines.add(_line(argument));
      }
    }
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    final lexeme = node.literal.lexeme;
    if (RegExp(r'^0[xX][0-9a-fA-F]{6,8}$').hasMatch(lexeme)) {
      hexColors.add(_Occurrence(_line(node)));
    }
    _count(lexeme, node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _count(node.value, node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    _count(node.stringValue, node);
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    _count(node.literal.lexeme, node);
  }

  /// Counts a literal value when it is eligible for duplication.
  void _count(String? value, AstNode node) {
    if (value == null || value.length < minLength) return;
    counts.putIfAbsent(value, () => []).add(_Occurrence(_line(node)));
  }

  int _line(AstNode node) => _lineInfo.getLocation(node.offset).lineNumber;
}
