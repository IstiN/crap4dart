import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'gate.dart';
import 'gate_context.dart';
import 'gate_ids.dart';

/// The `(operator, left, right)` parts of a binary expression.
typedef _BinaryParts = ({String op, AstNode left, AstNode right});

/// The canonical body key plus the line of the unwrapped statement.
typedef _BodyKey = ({String key, int line});

/// A top-level chain operand: canonical key plus its source node.
typedef _OperandRef = ({String key, AstNode node});

/// The `identical_branches` gate: flags the copy-paste-edit bug family —
/// syntactically identical pieces inside one construct where a second,
/// slightly different piece was intended.
///
/// Five checks, all comparing by canonical form (whitespace-, comment-,
/// parenthesis-independent, operands of commutative operators sorted,
/// same-operator nests flattened): `a == b` matches `b == a`, `a && b`
/// matches `b && a`.
///
/// 1. **Duplicate conditions** in one `if`/`else if` chain — every later
///    branch becomes unreachable.
/// 2. **Duplicate branch bodies** in one chain (`if (a) return x; else
///    if (b) return x;`) — one arm was supposed to be edited. Also
///    covers an `else` equal to its `then`.
/// 3. **Duplicate operands in one boolean chain** (`a || a`, `a && a`)
///    — the operand collapses to itself; `f() || f()` double-calls by
///    accident.
/// 4. **Identical ternary branches** (`c ? x : x`) — the condition is
///    dead.
/// 5. **Duplicate arguments in one call** (`f(w, h, w)`) and
///    **duplicate catch bodies** in one `try` — the wrong-variable /
///    copy-paste-handling bugs. All-identical argument lists
///    (`EdgeInsets.fromLTRB(8, 8, 8, 8)`) and pure-literal repeats are
///    exempt: uniform-value APIs legitimately repeat.
///
/// Only pieces of the *same* construct are compared; identical
/// conditions in separate `if` statements or nested branches are legal
/// (the state may change between them). `switch` is excluded — the
/// analyzer already flags duplicate cases.
///
/// Default severity is `warning`: equivalence assumes side-effect-free
/// operands, which pure syntax cannot prove.
class IdenticalBranchesGate implements Gate {
  /// Creates an [IdenticalBranchesGate].
  const IdenticalBranchesGate();

  @override
  String get id => GateIds.identicalBranches;

  @override
  Future<GateResult> run(GateContext context) async {
    final violations = <GateViolation>[];
    var constructs = 0;
    for (final file in context.files) {
      final parsed = context.parsed(file);
      final scanner = _DuplicationScanner(parsed.lineInfo);
      parsed.unit.accept(scanner);
      constructs += scanner.constructs;
      for (final finding in scanner.findings) {
        violations.add(
          GateViolation(
            file: context.relativePath(file),
            line: finding.line,
            message: finding.message,
          ),
        );
      }
    }
    final summary = violations.isEmpty
        ? '$constructs constructs checked, no identical-branch findings'
        : '${violations.length} identical-branch findings '
            '($constructs constructs checked)';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }
}

/// One finding: a ready-to-render message plus the violation line.
class _Finding {
  /// The violation message.
  final String message;

  /// 1-based line of the repeated occurrence (the violation site).
  final int line;

  /// Creates a finding.
  const _Finding(this.message, this.line);
}

/// Canonical-form builder for expression/statement comparison:
/// whitespace-, comment- and parenthesis-independent; operands of
/// commutative operators sorted; same-operator nests flattened.
abstract final class _Canon {
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

  /// The canonical form of [node]: whitespace- and parenthesis-
  /// independent, with operands of commutative operators sorted and
  /// same-operator nests of associative operators flattened.
  static String _canonicalForm(AstNode node) {
    final buffer = StringBuffer();
    _Canon._writeCanonical(node, buffer);
    return buffer.toString();
  }

  static void _writeCanonical(AstNode node, StringBuffer buffer) {
    final expr = _Canon._unwrap(node);
    final binary = _Canon._binaryParts(expr);
    if (binary != null) {
      _Canon._writeBinary(binary.op, binary.left, binary.right, buffer);
    } else if (
        // ignore: experimental_member_use
        expr is LogicalNot ||
            // ignore: experimental_member_use
            expr is UnaryOperatorInvocation) {
      // Both unary shapes expose the same operator/operand surface;
      // one body keeps them from drifting apart.
      final dynamic unary = expr;
      buffer
        ..write(unary.operator.lexeme as String)
        ..write('(');
      _Canon._writeCanonical(unary.operand as AstNode, buffer);
      buffer.write(')');
    } else {
      buffer.write(_Canon._tokenText(expr));
    }
  }

  /// The `(operator, left, right)` parts of a binary expression, or
  /// `null`. The analyzer's v2 AST gives `&&`, `||` and every other
  /// binary operator its own node class — but a parenthesized operand
  /// can hold the v1 `BinaryExpression` wrapper instead, so both
  /// shapes are matched here.
  static _BinaryParts? _binaryParts(AstNode node) => switch (node) {
        // ignore: experimental_member_use
        LogicalAnd e => (
            op: e.operator.lexeme,
            left: e.leftOperand,
            right: e.rightOperand,
          ),
        // ignore: experimental_member_use
        LogicalOr e => (
            op: e.operator.lexeme,
            left: e.leftOperand,
            right: e.rightOperand,
          ),
        // ignore: experimental_member_use
        BinaryOperatorInvocation e => (
            op: e.operator.lexeme,
            left: e.leftOperand,
            right: e.rightOperand,
          ),
        BinaryExpression e => (
            op: e.operator.lexeme,
            left: e.leftOperand,
            right: e.rightOperand,
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
    _Canon._flatten(op, left, operands);
    _Canon._flatten(op, right, operands);
    if (_Canon._commutative.contains(op)) operands.sort();
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
    final expr = _Canon._unwrap(node);
    final binary = _Canon._binaryParts(expr);
    if (_Canon._flattenable.contains(op) && binary != null) {
      if (binary.op == op) {
        _Canon._flatten(op, binary.left, out);
        _Canon._flatten(op, binary.right, out);
        return;
      }
    }
    out.add(_Canon._canonicalForm(expr));
  }

  static AstNode _unwrap(AstNode node) =>
      node is ParenthesizedExpression ? _Canon._unwrap(node.expression) : node;

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

/// Walks a compilation unit and collects the identical-branch family.
class _DuplicationScanner extends RecursiveAstVisitor<void> {
  final LineInfo _lineInfo;

  /// Number of scanned constructs (chains, calls, tries, ternaries).
  int constructs = 0;

  /// Findings, in source order.
  final List<_Finding> findings = [];

  _DuplicationScanner(this._lineInfo);

  @override
  void visitIfStatement(IfStatement node) {
    if (_isChainHead(node)) {
      constructs++;
      _scanChain(node);
    }
    super.visitIfStatement(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    constructs++;
    final thenKey = _expressionKey(node.thenExpression);
    final elseKey = _expressionKey(node.elseExpression);
    if (thenKey == elseKey) {
      findings.add(
        _Finding(
          'identical then/else branches of conditional expression: '
          "'${_snippet(node.thenExpression)}' — the condition is dead",
          _line(node.thenExpression),
        ),
      );
    }
    super.visitConditionalExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    // Only the outermost link of a same-operator chain checks operand
    // duplicates; the flatten step sees the whole chain. Parenthesized
    // links are transparent: a || (a || b) is one chain.
    var parent = node.parent;
    while (parent is ParenthesizedExpression) {
      parent = parent.parent;
    }
    final isChainLink = parent is BinaryExpression &&
        parent.operator.lexeme == node.operator.lexeme;
    if (!isChainLink) _checkBooleanChain(node);
    super.visitBinaryExpression(node);
  }

  @override
  void visitTryStatement(TryStatement node) {
    constructs++;
    _checkCatchBodies(node);
    super.visitTryStatement(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _checkCallArguments(node.argumentList, node.methodName.name);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName.type.name.lexeme;
    _checkCallArguments(node.argumentList, name);
    super.visitInstanceCreationExpression(node);
  }

  /// Whether [node] starts a chain instead of extending one: its parent
  /// is not an `if` whose `else` branch it is.
  bool _isChainHead(IfStatement node) {
    final parent = node.parent;
    return parent is! IfStatement || parent.elseStatement != node;
  }

  void _scanChain(IfStatement head) {
    final conditionLines = <String, int>{};
    final bodyLines = <String, int>{};
    Statement? current = head;
    while (current is IfStatement) {
      final (:key, :line) = _bodyKey(current.thenStatement);
      _reportRepeat(
        bodyLines,
        key,
        line,
        'duplicate branch body '
        "in if/else-if chain: '${_snippet(current.thenStatement)}'",
      );
      // `if (x case ...)` decides by pattern match, not by a boolean
      // expression — such links are excluded from condition comparison.
      if (current.caseClause == null) {
        // ignore: experimental_member_use
        final condition = current.expression2;
        final conditionLine = _line(condition);
        _reportRepeat(
          conditionLines,
          _expressionKey(condition),
          conditionLine,
          "duplicate condition in if/else-if chain: "
          "'${_snippet(condition)}'",
        );
      }
      final elseStatement = current.elseStatement;
      if (elseStatement != null && elseStatement is! IfStatement) {
        final (:key, :line) = _bodyKey(elseStatement);
        _reportRepeat(
          bodyLines,
          key,
          line,
          "duplicate branch body in if/else-if chain: "
          "'${_snippet(elseStatement)}'",
        );
      }
      current = elseStatement;
    }
  }

  void _checkBooleanChain(BinaryExpression node) {
    final op = node.operator.lexeme;
    if (op != '&&' && op != '||') return;
    constructs++;
    final operands = <String>[];
    _Canon._flatten(op, node.leftOperand, operands);
    _Canon._flatten(op, node.rightOperand, operands);
    final seen = <String>{};
    for (final operand in operands) {
      if (!seen.add(operand)) {
        findings.add(
          _Finding(
            "duplicate operand in '$op' chain: '$operand' repeats — "
            "the chain collapses to the single operand",
            _line(node),
          ),
        );
        return;
      }
    }
    _checkAbsorption(node, op);
  }

  /// Absorption law: an operand of the chain that is also a conjunct
  /// (for `||`) or disjunct (for `&&`) of a sibling operand makes the
  /// sibling's extra terms dead — `a || b && a` collapses to `a`.
  /// Same law both ways: `a && (b || a)` collapses to `a`.
  void _checkAbsorption(BinaryExpression node, String op) {
    final siblings = _chainOperands(op, node);
    final standalone = {for (final sibling in siblings) sibling.key};
    final nestedOp = op == '||' ? '&&' : '||';
    for (final sibling in siblings) {
      for (final conjunct in _chainOperands(nestedOp, sibling.node)) {
        if (conjunct.key == sibling.key) continue;
        if (!standalone.contains(conjunct.key)) continue;
        findings.add(
          _Finding(
            "operand of '$op' is implied by another operand "
            "(absorption): '${_snippet(conjunct.node)}' also appears "
            'standalone — the extra terms are dead',
            _line(conjunct.node),
          ),
        );
        return;
      }
    }
  }

  /// The top-level operands of an [op] chain rooted at [root], as
  /// canonical keys paired with their source nodes. A non-chain root
  /// yields the root itself.
  List<_OperandRef> _chainOperands(String op, AstNode root) {
    final out = <_OperandRef>[];
    void add(AstNode node) {
      final unwrapped = _Canon._unwrap(node);
      final binary = _Canon._binaryParts(unwrapped);
      if (binary != null && binary.op == op) {
        add(binary.left);
        add(binary.right);
      } else {
        out.add((key: _Canon._canonicalForm(unwrapped), node: unwrapped));
      }
    }

    add(root);
    return out;
  }

  void _checkCatchBodies(TryStatement node) {
    final bodyLines = <String, int>{};
    for (final clause in node.catchClauses) {
      final (:key, :line) = _bodyKey(clause.body);
      _reportRepeat(
          bodyLines,
          key,
          line,
          'duplicate catch '
          "body in try statement: '${_snippet(clause.body)}'");
    }
  }

  void _checkCallArguments(ArgumentList arguments, String? callee) {
    if (arguments.arguments.length < 2) return;
    constructs++;
    // Positional slots only: a named argument names its slot, so a
    // repeated value there is self-documenting (a: x, b: x), while a
    // repeated positional value is indistinguishable from a
    // wrong-variable bug.
    final positional = [
      for (final argument in arguments.arguments)
        if (argument is! NamedArgument) argument,
    ];
    if (positional.length < 2) return;
    final keys = [
      for (final argument in positional)
        (key: _expressionKey(argument), node: argument),
    ];
    final allLiteral = keys.every((pair) => _isLiteralExpr(pair.node));
    if (allLiteral) return;
    final seen = <String, int>{};
    for (var i = 0; i < keys.length; i++) {
      final (:key, :node) = keys[i];
      if (_isLiteralExpr(node)) continue;
      final first = seen[key];
      if (first == null) {
        seen[key] = i;
      } else {
        findings.add(
          _Finding(
            "duplicate argument in call to '$callee': "
            "'${_snippet(node)}' (same as argument ${first + 1})",
            _line(node),
          ),
        );
      }
    }
  }

  /// Whether [expr] is a literal (`null`, bool, number or string) —
  /// repeated literals are exempt from the argument check.
  bool _isLiteralExpr(AstNode expr) => switch (_Canon._unwrap(expr)) {
        NullLiteral() || BooleanLiteral() => true,
        StringLiteral() || IntegerLiteral() || DoubleLiteral() => true,
        _ => false,
      };

  void _reportRepeat(
    Map<String, int> seen,
    String key,
    int line,
    String messagePrefix,
  ) {
    final first = seen[key];
    if (first == null) {
      seen[key] = line;
      return;
    }
    findings.add(_Finding('$messagePrefix (same as line $first)', line));
  }

  /// The canonical key of an expression: the commutative/sorted
  /// canonical form.
  String _expressionKey(AstNode node) => _Canon._canonicalForm(node);

  /// The canonical key of a statement body plus the line of the
  /// statement itself: a single-statement block unwraps to its
  /// statement, so `{ return 1; }` equals `return 1;` and the violation
  /// points at the code, not the brace.
  _BodyKey _bodyKey(Statement statement) {
    var node = statement;
    while (node is Block && node.statements.length == 1) {
      node = node.statements.first;
    }
    return (key: _Canon._tokenText(node), line: _line(node));
  }

  String _snippet(AstNode node) {
    final text = node.toSource();
    return text.length > 40 ? '${text.substring(0, 37)}...' : text;
  }

  int _line(AstNode node) =>
      _lineInfo.getLocation(node.beginToken.offset).lineNumber;
}
