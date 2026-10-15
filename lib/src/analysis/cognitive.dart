import 'complexity.dart' show MetricCalculator, functionBodyOf;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Computes the cognitive complexity of Dart methods from their AST,
/// following the SonarSource definition (white paper "Cognitive
/// Complexity", v1.2) as closely as the Dart grammar allows.
///
/// Increments:
/// - **Basic** `+1` for each break in the linear flow: `if`, `else if`,
///   `else`, `for`, `while`, `do`, `catch`, every `switch` statement and
///   switch-expression member (`case`/pattern/`default`), the conditional
///   expression (`?:`), and each *sequence* of identical `&&`/`||`
///   operators (`a && b && c` is one sequence → +1, `a && b || c` is two
///   sequences → +2).
/// - **Nesting** `+N` (on top of the basic increment) for the structural
///   constructs above — everything except `&&`/`||` — when they appear
///   inside another structural construct at depth `N`.
/// - An `else if` chain is flat: each chained `if` increments once at the
///   depth of its originating `if`, so `if (...) else if (...) else if
///   (...)` scores 3 regardless of chain length, while
///   `if (...) else { if (...) }` keeps paying the nesting penalty.
///
/// Nesting depth is increased by `if` branches (then and bare `else`),
/// loop bodies, `catch` bodies, `switch` members, conditional branches,
/// and lambda bodies (lambdas themselves do not increment — like nested
/// methods in the SonarSource definition). Nested named function
/// declarations are skipped entirely, mirroring
/// [ComplexityCalculator].
///
/// Unlike cyclomatic complexity, the score starts at 0 and is not a path
/// count; it is designed to track how hard a method is to *read*, which
/// is why flat guard chains stay cheap and nested ones do not.
class CognitiveCalculator implements MetricCalculator {
  /// Creates a [CognitiveCalculator].
  ///
  /// When [countLambdas] is false, lambda bodies ([FunctionExpression])
  /// are not traversed, so their branches do not count towards the
  /// enclosing method.
  const CognitiveCalculator({this.countLambdas = true});

  @override
  String get metricName => 'cognitive';

  /// Whether branches inside lambdas count towards the enclosing method.
  final bool countLambdas;

  /// Returns the cognitive complexity of the body of [node], where [node]
  /// is a [MethodDeclaration] or a top-level [FunctionDeclaration].
  @override
  int compute(AstNode node) {
    final visitor = _CognitiveVisitor(countLambdas: countLambdas);
    functionBodyOf(node).accept(visitor);
    return visitor.score;
  }
}

class _CognitiveVisitor extends RecursiveAstVisitor<void> {
  _CognitiveVisitor({required this.countLambdas});

  final bool countLambdas;

  int _depth = 0;
  int score = 0;

  /// Visits [visit] with the nesting depth increased by one.
  void _deeper(void Function() visit) {
    _depth++;
    visit();
    _depth--;
  }

  /// The basic-plus-nesting increment for a structural construct.
  int get _increment => 1 + _depth;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (!countLambdas) return;
    // Lambdas nest like nested methods: deeper increments inside, no
    // increment for the lambda itself.
    _deeper(() => super.visitFunctionExpression(node));
  }

  // Nested named functions are separate units of code; do not count their
  // branches towards the enclosing method.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {}

  @override
  void visitIfStatement(IfStatement node) {
    score += _increment;
    _deeper(() => node.thenStatement.accept(this));
    final elseClause = node.elseStatement;
    if (elseClause is IfStatement) {
      // `else if` chain: one flat increment at this if's depth.
      elseClause.accept(this);
    } else if (elseClause != null) {
      score += _increment;
      _deeper(() => elseClause.accept(this));
    }
  }

  @override
  void visitForStatement(ForStatement node) {
    score += _increment;
    _deeper(() => super.visitForStatement(node));
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    score += _increment;
    _deeper(() => super.visitWhileStatement(node));
  }

  @override
  void visitDoStatement(DoStatement node) {
    score += _increment;
    _deeper(() => super.visitDoStatement(node));
  }

  @override
  void visitCatchClause(CatchClause node) {
    score += _increment;
    _deeper(() => super.visitCatchClause(node));
  }

  @override
  void visitSwitchCase(SwitchCase node) {
    score += _increment;
    _deeper(() => super.visitSwitchCase(node));
  }

  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    score += _increment;
    _deeper(() => super.visitSwitchPatternCase(node));
  }

  @override
  void visitSwitchDefault(SwitchDefault node) {
    score += _increment;
    _deeper(() => super.visitSwitchDefault(node));
  }

  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) {
    score += _increment;
    _deeper(() => super.visitSwitchExpressionCase(node));
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    score += _increment;
    _deeper(() => super.visitConditionalExpression(node));
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final type = node.operator.type;
    if (type == TokenType.AMPERSAND_AMPERSAND || type == TokenType.BAR_BAR) {
      // Only the root of a same-operator sequence increments.
      final parent = node.parent;
      final sameSequence =
          parent is BinaryExpression && parent.operator.type == type;
      if (!sameSequence) score++;
    }
    super.visitBinaryExpression(node);
  }
}
