import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../gate.dart';
import '../gate_context.dart';
import '../gate_ids.dart';

/// A finding ready to become a violation: message plus 1-based line.
typedef _Finding = ({String message, int line});

/// The `collapsible_flow` gate: flags control-flow nesting that a
/// semantics-preserving mechanical rewrite can flatten.
///
/// Three checks:
///
/// 1. **Collapsible if** — `if (a) { if (b) X }` with no `else` on
///    either level merges into `if (a && b) X`. Short-circuit `&&`
///    preserves evaluation order, so the merge is always equivalent
///    (including `await`ed or side-effecting conditions). Pattern
///    conditions (`if (x case P)`) are never merged — a pattern cannot
///    be expressed as a `&&` operand.
/// 2. **Redundant else** — `if (c) { return X; } else { Y }` where the
///    then-branch *always exits* (`return`, `break`, `continue`,
///    `throw`, `rethrow`, a block ending in one of those, an if-chain
///    whose every branch exits, or a try whose body and non-empty
///    finally exit): the `else` is redundant — dedent its body. An
///    inner `if` *without* an `else` never counts as exiting: control
///    falls through when its condition is false, so dedenting would
///    change behavior.
/// 3. **Chain after terminal then** — an `else if` following an
///    always-exiting then-branch. The whole chain wants a guard
///    sequence or a dispatch table; that rewrite is not mechanical, so
///    this check only points at it (no fix-shaped message).
///
/// Every finding is correct code — this gate trades flatness, not
/// bugs. Default severity is therefore `warning`. Independently
/// validated by DCM's `avoid-collapsible-if` and `avoid-redundant-else`.
class CollapsibleFlowGate implements Gate {
  /// Creates a [CollapsibleFlowGate].
  const CollapsibleFlowGate();

  @override
  String get id => GateIds.collapsibleFlow;

  @override
  Future<GateResult> run(GateContext context) async {
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      final parsed = context.parsed(file);
      final scanner = _Scanner(parsed.lineInfo);
      parsed.unit.accept(scanner);
      checked += scanner.constructs;
      for (final (message: message, line: line) in scanner.findings) {
        violations.add(
          GateViolation(
            file: context.relativePath(file),
            line: line,
            message: message,
          ),
        );
      }
    }
    final summary = violations.isEmpty
        ? '$checked if statements checked, no collapsible flow'
        : '${violations.length} collapsible-flow findings '
            '($checked if statements checked)';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }
}

class _Scanner extends RecursiveAstVisitor<void> {
  final LineInfo lineInfo;

  final findings = <_Finding>[];

  var constructs = 0;

  _Scanner(this.lineInfo);

  @override
  void visitIfStatement(IfStatement node) {
    constructs++;
    _checkCollapsibleIf(node);
    _checkRedundantElse(node);
    super.visitIfStatement(node);
  }

  void _add(AstNode node, String message) {
    findings.add(
      (
        message: message,
        line: lineInfo.getLocation(node.offset).lineNumber,
      ),
    );
  }

  /// Check 1: `if (a) { if (b) X }` — no `else`, no pattern condition
  /// on either level, the then-branch contains only the inner if.
  void _checkCollapsibleIf(IfStatement node) {
    if (node.elseStatement != null || node.caseClause != null) return;
    final inner = _singleInnerIf(node.thenStatement);
    if (inner == null) return;
    if (inner.elseStatement != null || inner.caseClause != null) return;
    _add(
      node,
      'nested if can be merged into a single condition with `&&`',
    );
  }

  /// The single inner `if` of a collapsible then-branch: either an
  /// unbraced if, or a block whose only statement is an if. `null`
  /// when the branch has any other shape.
  IfStatement? _singleInnerIf(Statement then) {
    if (then is IfStatement) return then;
    if (then is Block && then.statements.length == 1) {
      final only = then.statements.first;
      return only is IfStatement ? only : null;
    }
    return null;
  }

  /// Checks 2 and 3: an always-exiting then-branch makes a plain
  /// `else` redundant (dedent) and turns an `else if` into a chain
  /// flattening hint.
  void _checkRedundantElse(IfStatement node) {
    final elseStatement = node.elseStatement;
    if (elseStatement == null) return;
    if (!_alwaysExits(node.thenStatement)) return;
    if (elseStatement is IfStatement) {
      _add(
        elseStatement,
        'else-if follows an always-exiting then branch — flatten the '
        'chain into guard clauses or a dispatch table',
      );
    } else {
      _add(
        node,
        'redundant else after an always-exiting then branch — '
        'dedent the else body',
      );
    }
  }
}

/// Whether [statement] always exits its enclosing construct (the
/// enclosing `if`/loop/switch/function). Conservative: an `if` without
/// an `else` falls through and never counts; `switch` bodies are not
/// analyzed (case fall-through), so a trailing `switch` never counts.
bool _alwaysExits(Statement? statement) {
  if (statement == null) return false;
  if (_isJump(statement)) return true;
  if (statement is ExpressionStatement) return _exitsByExpression(statement);
  if (statement is Block) return _exitsAsBlock(statement);
  if (statement is IfStatement) return _exitsAsIf(statement);
  if (statement is TryStatement) return _exitsAsTry(statement);
  return false;
}

/// `return`, `break` and `continue` leave their construct in every
/// case.
bool _isJump(Statement statement) =>
    statement is ReturnStatement ||
    statement is BreakStatement ||
    statement is ContinueStatement;

/// `throw e;` and `rethrow;` exit; any other expression statement does
/// not.
bool _exitsByExpression(ExpressionStatement statement) {
  final expression = statement.expression;
  return expression is ThrowExpression || expression is RethrowExpression;
}

/// A block exits when it is non-empty and its last statement exits.
bool _exitsAsBlock(Block statement) {
  final statements = statement.statements;
  return statements.isNotEmpty && _alwaysExits(statements.last);
}

/// An if exits only when both branches exist and both exit — a bare
/// `if` falls through when its condition is false.
bool _exitsAsIf(IfStatement statement) {
  return statement.elseStatement != null &&
      _alwaysExits(statement.thenStatement) &&
      _alwaysExits(statement.elseStatement);
}

/// A try exits when its body exits and its non-empty finally exits
/// (an empty finally does not change the flow).
bool _exitsAsTry(TryStatement statement) {
  final finallyBlock = statement.finallyBlock;
  if (!_alwaysExits(statement.body)) return false;
  return finallyBlock == null ||
      finallyBlock.statements.isEmpty ||
      _alwaysExits(finallyBlock.statements.last);
}
