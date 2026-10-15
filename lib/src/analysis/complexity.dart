import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Common interface of the complexity calculators consumed by the
/// `complexity` gate.
abstract interface class MetricCalculator {
  /// Display name used in violation messages (`CC` or `cognitive`).
  String get metricName;

  /// Computes the metric of a [MethodDeclaration] or top-level
  /// [FunctionDeclaration].
  int compute(AstNode node);
}

/// The body of a [MethodDeclaration] or top-level [FunctionDeclaration];
/// both complexity calculators share this entry convention.
FunctionBody functionBodyOf(AstNode node) {
  final FunctionBody body;
  switch (node) {
    case MethodDeclaration():
      body = node.body;
    case FunctionDeclaration():
      body = node.functionExpression.body;
    default:
      throw ArgumentError.value(
        node.runtimeType,
        'node',
        'Expected a MethodDeclaration or FunctionDeclaration',
      );
  }
  return body;
}

/// Computes cyclomatic complexity of Dart methods from their AST.
///
/// Counting rules (base value 1, +1 for each):
/// - [IfStatement] (an `if-case` clause adds one more; its `when` guard
///   adds one more again)
/// - [ForStatement] (classic and for-in)
/// - [WhileStatement]
/// - [DoStatement]
/// - [CatchClause]
/// - [SwitchCase], [SwitchPatternCase] and [SwitchDefault] members
///   (a `when` guard on a pattern case adds one more)
/// - [SwitchExpressionCase] members of switch *expressions*
///   (`return switch (x) { ... }`), `when` guards included
/// - [ConditionalExpression] (`?:`)
/// - `&&` and `||` [BinaryExpression] operators
/// - [LogicalOrPattern] and [LogicalAndPattern] patterns (same as the
///   corresponding boolean operators)
///
/// Lambda bodies ([FunctionExpression]) are traversed and their branches
/// count towards the enclosing method. Nested named function declarations
/// ([FunctionDeclaration]) are skipped — they are reported as separate
/// methods only when declared at the top level.
class ComplexityCalculator implements MetricCalculator {
  /// Creates a [ComplexityCalculator].
  ///
  /// When [countLambdas] is false, lambda bodies ([FunctionExpression])
  /// are not traversed, so their branches do not count towards the
  /// enclosing method.
  const ComplexityCalculator({this.countLambdas = true});

  @override
  String get metricName => 'CC';

  /// Whether branches inside lambdas count towards the enclosing method.
  final bool countLambdas;

  /// Returns the cyclomatic complexity of the body of [node], where [node]
  /// is a [MethodDeclaration] or a top-level [FunctionDeclaration].
  @override
  int compute(AstNode node) {
    final visitor = _ComplexityVisitor(countLambdas: countLambdas);
    functionBodyOf(node).accept(visitor);
    return visitor.complexity;
  }
}

class _ComplexityVisitor extends RecursiveAstVisitor<void> {
  _ComplexityVisitor({required this.countLambdas});

  final bool countLambdas;

  int complexity = 1;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (!countLambdas) return;
    super.visitFunctionExpression(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    complexity++;
    super.visitForStatement(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    complexity++;
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    complexity++;
    super.visitDoStatement(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    complexity++;
    super.visitCatchClause(node);
  }

  @override
  void visitSwitchCase(SwitchCase node) {
    complexity++;
    super.visitSwitchCase(node);
  }

  @override
  void visitSwitchDefault(SwitchDefault node) {
    complexity++;
    super.visitSwitchDefault(node);
  }

  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    complexity++;
    if (node.guardedPattern.whenClause != null) complexity++;
    super.visitSwitchPatternCase(node);
  }

  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) {
    complexity++;
    if (node.guardedPattern.whenClause != null) complexity++;
    super.visitSwitchExpressionCase(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    complexity++;
    if (node.caseClause?.guardedPattern.whenClause != null) complexity++;
    super.visitIfStatement(node);
  }

  @override
  void visitLogicalOrPattern(LogicalOrPattern node) {
    complexity++;
    super.visitLogicalOrPattern(node);
  }

  @override
  void visitLogicalAndPattern(LogicalAndPattern node) {
    complexity++;
    super.visitLogicalAndPattern(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    complexity++;
    super.visitConditionalExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final type = node.operator.type;
    if (type == TokenType.AMPERSAND_AMPERSAND || type == TokenType.BAR_BAR) {
      complexity++;
    }
    super.visitBinaryExpression(node);
  }

  // Nested named functions are separate units of code; do not count their
  // branches towards the enclosing method.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {}
}
