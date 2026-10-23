import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'gate.dart';
import 'gate_context.dart';

/// The `identical_branches` gate: fails `if`/`else if` chains that test
/// the same condition twice.
///
/// A duplicated condition makes every later branch unreachable — the
/// classic copy-paste-edit bug where one arm was supposed to be edited.
/// Conditions compare by canonical form, so formatting, redundant
/// parentheses and operand order of commutative operators
/// (`==`, `!=`, `&&`, `||`, `+`, `*`, `&`, `|`, `^`) do not hide a
/// duplicate: `a == b` matches `b == a`, and `a && b` matches `b && a`.
///
/// Only conditions of the *same* chain are compared; identical
/// conditions in separate `if` statements or nested branches are legal
/// (the state may change between them). `switch` is excluded — the
/// analyzer already flags duplicate switch cases.
///
/// Default severity is `warning`: reordering is only equivalent when
/// the operands are side-effect free, which pure syntax cannot prove.
class IdenticalBranchesGate implements Gate {
  /// Creates an [IdenticalBranchesGate].
  const IdenticalBranchesGate();

  @override
  String get id => 'identical_branches';

  @override
  Future<GateResult> run(GateContext context) async {
    final violations = <GateViolation>[];
    var chains = 0;
    for (final file in context.files) {
      final parsed = context.parsed(file);
      final scanner = _ChainScanner(parsed.lineInfo);
      parsed.unit.accept(scanner);
      chains += scanner.chains;
      for (final duplicate in scanner.duplicates) {
        violations.add(
          GateViolation(
            file: context.relativePath(file),
            line: duplicate.line,
            message: "duplicate condition in if/else-if chain: "
                "'${duplicate.condition}' (same as line "
                '${duplicate.firstLine})',
          ),
        );
      }
    }
    final summary = violations.isEmpty
        ? '$chains if/else-if chains checked, no duplicate conditions'
        : '${violations.length} duplicate conditions in if/else-if chains';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }
}

/// One duplicated condition inside a chain.
class _DuplicateCondition {
  /// Creates a duplicate record.
  const _DuplicateCondition(this.condition, this.line, this.firstLine);

  /// The condition as written in the source.
  final String condition;

  /// 1-based line of the repeated occurrence (the violation site).
  final int line;

  /// 1-based line of the first occurrence in the chain.
  final int firstLine;
}

/// Walks every `if`/`else if` chain of a compilation unit and collects
/// duplicated conditions. Each chain is visited once, from its head:
/// an `if` that is the `else` branch of another `if` is a chain link,
/// not a head. Nested `if` statements inside bodies start their own
/// chains.
class _ChainScanner extends RecursiveAstVisitor<void> {
  _ChainScanner(this._lineInfo);

  final LineInfo _lineInfo;

  /// Number of chains scanned.
  int chains = 0;

  /// Duplicated conditions, in source order.
  final List<_DuplicateCondition> duplicates = [];

  @override
  void visitIfStatement(IfStatement node) {
    if (_isChainHead(node)) {
      chains++;
      _scanChain(node);
    }
    super.visitIfStatement(node);
  }

  /// Whether [node] starts a chain instead of extending one: its parent
  /// is not an `if` whose `else` branch it is.
  bool _isChainHead(IfStatement node) {
    final parent = node.parent;
    return parent is! IfStatement || parent.elseStatement != node;
  }

  void _scanChain(IfStatement head) {
    final firstLineByKey = <String, int>{};
    Statement? current = head;
    while (current is IfStatement) {
      // `if (x case ...)` decides by pattern match, not by a boolean
      // expression — the matched value alone says nothing, so such
      // links are excluded from the comparison.
      if (current.caseClause == null) {
        // ignore: experimental_member_use
        final condition = current.expression2;
        final key = _canonicalForm(condition);
        final line = _line(condition);
        final firstLine = firstLineByKey[key];
        if (firstLine == null) {
          firstLineByKey[key] = line;
        } else {
          duplicates.add(
            _DuplicateCondition(condition.toSource(), line, firstLine),
          );
        }
      }
      current = current.elseStatement;
    }
  }

  int _line(AstNode node) =>
      _lineInfo.getLocation(node.beginToken.offset).lineNumber;

  /// The canonical form of [node]: whitespace- and parenthesis-
  /// independent, with operands of commutative operators sorted and
  /// same-operator nests of associative operators flattened.
  static String _canonicalForm(AstNode node) {
    final buffer = StringBuffer();
    _writeCanonical(node, buffer);
    return buffer.toString();
  }

  static void _writeCanonical(AstNode node, StringBuffer buffer) {
    final expr = _unwrap(node);
    final binary = _binaryParts(expr);
    if (binary != null) {
      final (op, left, right) = binary;
      _writeBinary(op, left, right, buffer);
      // ignore: experimental_member_use
    } else if (expr is LogicalNot) {
      buffer
        ..write(expr.operator.lexeme)
        ..write('(');
      _writeCanonical(expr.operand, buffer);
      buffer.write(')');
      // ignore: experimental_member_use
    } else if (expr is UnaryOperatorInvocation) {
      buffer
        ..write(expr.operator.lexeme)
        ..write('(');
      _writeCanonical(expr.operand, buffer);
      buffer.write(')');
    } else {
      buffer.write(_tokenText(expr));
    }
  }

  /// The `(operator, left, right)` parts of a binary expression, or
  /// `null`. The analyzer's v2 AST gives `&&`, `||` and every other
  /// binary operator its own node class — but a parenthesized operand
  /// can hold the v1 `BinaryExpression` wrapper instead, so both
  /// shapes are matched here.
  static (String, AstNode, AstNode)? _binaryParts(AstNode node) =>
      switch (node) {
        // ignore: experimental_member_use
        LogicalAnd e => (e.operator.lexeme, e.leftOperand, e.rightOperand),
        // ignore: experimental_member_use
        LogicalOr e => (e.operator.lexeme, e.leftOperand, e.rightOperand),
        // ignore: experimental_member_use
        BinaryOperatorInvocation e => (
            e.operator.lexeme,
            e.leftOperand,
            e.rightOperand,
          ),
        BinaryExpression e => (
            e.operator.lexeme,
            e.leftOperand,
            e.rightOperand,
          ),
        _ => null,
      };

  static void _writeBinary(
    String op,
    AstNode left,
    AstNode right,
    StringBuffer buffer,
  ) {
    final operands = <String>[];
    _flatten(op, left, operands);
    _flatten(op, right, operands);
    if (_commutative.contains(op)) operands.sort();
    buffer
      ..write(op)
      ..write('(')
      ..write(operands.join(','))
      ..write(')');
  }

  /// Collects the canonical operands of an [op] chain. Same-operator
  /// nests are flattened for the associative-commutative operators
  /// (`a && b && c` compares equal regardless of grouping); other
  /// operators keep their tree shape because flattening would merge
  /// semantically different expressions (`a - (b - c)`).
  static void _flatten(String op, AstNode node, List<String> out) {
    final expr = _unwrap(node);
    final binary = _binaryParts(expr);
    if (_flattenable.contains(op) && binary != null) {
      final (childOp, left, right) = binary;
      if (childOp == op) {
        _flatten(op, left, out);
        _flatten(op, right, out);
        return;
      }
    }
    out.add(_canonicalForm(expr));
  }

  /// Operators whose same-operator nests may be flattened.
  static const Set<String> _flattenable = {
    '&&',
    '||',
    '+',
    '*',
    '&',
    '|',
    '^',
  };

  /// Operators whose operand order may be canonicalized (sorted).
  static const Set<String> _commutative = {
    '==',
    '!=',
    '&&',
    '||',
    '+',
    '*',
    '&',
    '|',
    '^',
  };

  static AstNode _unwrap(AstNode node) =>
      node is ParenthesizedExpression ? _unwrap(node.expression) : node;

  /// The tokens of [node] joined without separators: whitespace- and
  /// comment-independent, so `a==b` compares equal to `a == b`.
  static String _tokenText(AstNode node) {
    final buffer = StringBuffer()..write(node.beginToken.lexeme);
    var current = node.beginToken;
    final end = node.endToken;
    while (current.end < end.end) {
      current = current.next ?? end;
      buffer.write(current.lexeme);
    }
    return buffer.toString();
  }
}
