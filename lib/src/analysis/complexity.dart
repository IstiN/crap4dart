import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Computes cyclomatic complexity of Dart methods from their AST.
///
/// Counting rules (base value 1, +1 for each):
/// - [IfStatement]
/// - [ForStatement] (classic and for-in)
/// - [WhileStatement]
/// - [DoStatement]
/// - [CatchClause]
/// - [SwitchCase], [SwitchPatternCase] and [SwitchDefault] members
/// - [ConditionalExpression] (`?:`)
/// - `&&` and `||` [BinaryExpression] operators
///
/// Lambda bodies ([FunctionExpression]) are traversed and their branches
/// count towards the enclosing method. Nested named function declarations
/// ([FunctionDeclaration]) are skipped — they are reported as separate
/// methods only when declared at the top level.
class ComplexityCalculator {
  /// Creates a [ComplexityCalculator].
  ///
  /// When [countLambdas] is false, lambda bodies ([FunctionExpression])
  /// are not traversed, so their branches do not count towards the
  /// enclosing method.
  const ComplexityCalculator({this.countLambdas = true});

  /// Whether branches inside lambdas count towards the enclosing method.
  final bool countLambdas;

  /// Returns the cyclomatic complexity of the body of [node], where [node]
  /// is a [MethodDeclaration] or a top-level [FunctionDeclaration].
  int compute(AstNode node) {
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
    final visitor = _ComplexityVisitor(countLambdas: countLambdas);
    body.accept(visitor);
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
  void visitIfStatement(IfStatement node) {
    complexity++;
    super.visitIfStatement(node);
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
  void visitSwitchPatternCase(SwitchPatternCase node) {
    complexity++;
    super.visitSwitchPatternCase(node);
  }

  @override
  void visitSwitchDefault(SwitchDefault node) {
    complexity++;
    super.visitSwitchDefault(node);
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
