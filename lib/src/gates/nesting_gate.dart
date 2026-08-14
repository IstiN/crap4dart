import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../analysis/method_extractor.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `nesting` gate: fails methods whose maximum control-flow nesting
/// level exceeds `gates.nesting.max_nesting` (default 5).
///
/// Every nested control-flow statement (`if`, `for`, `while`, `do`,
/// `switch`, `try`/`catch`) adds one level. Deep nesting is a typical
/// artifact of dodging the complexity gate with early returns.
class NestingGate implements Gate {
  /// Creates a [NestingGate].
  const NestingGate();

  @override
  String get id => 'nesting';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.nesting;
    const extractor = MethodExtractor();
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      final parsed = context.parsed(file);
      for (final method
          in extractor.extractWithNodes(parsed.unit, parsed.lineInfo)) {
        checked++;
        final violation = _violation(
          context,
          file,
          method,
          config.maxNesting,
        );
        if (violation != null) violations.add(violation);
      }
    }
    final summary = violations.isEmpty
        ? '$checked methods within nesting ${config.maxNesting}'
        : '${violations.length}/$checked methods nested deeper than '
            '${config.maxNesting}';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// The nesting violation of [method], or `null` when within [maxNesting].
  GateViolation? _violation(
    GateContext context,
    String file,
    ExtractedMethod method,
    int maxNesting,
  ) {
    final visitor = _NestingVisitor();
    method.node.accept(visitor);
    if (visitor.maxDepth <= maxNesting) return null;
    final info = method.info;
    return GateViolation(
      file: context.relativePath(file),
      line: info.startLine,
      message: '${info.className}.${info.methodName} '
          'nesting=${visitor.maxDepth} > max $maxNesting',
    );
  }
}

/// Computes the maximum control-flow nesting depth of the visited
/// function; nested `if`/`for`/`while`/`do`/`switch`/`try`/`catch`
/// each add one level.
class _NestingVisitor extends RecursiveAstVisitor<void> {
  int _depth = 0;
  int maxDepth = 0;

  @override
  void visitIfStatement(IfStatement node) =>
      _nested(() => super.visitIfStatement(node));

  @override
  void visitForStatement(ForStatement node) =>
      _nested(() => super.visitForStatement(node));

  @override
  void visitWhileStatement(WhileStatement node) =>
      _nested(() => super.visitWhileStatement(node));

  @override
  void visitDoStatement(DoStatement node) =>
      _nested(() => super.visitDoStatement(node));

  @override
  void visitSwitchStatement(SwitchStatement node) =>
      _nested(() => super.visitSwitchStatement(node));

  @override
  void visitTryStatement(TryStatement node) =>
      _nested(() => super.visitTryStatement(node));

  @override
  void visitCatchClause(CatchClause node) =>
      _nested(() => super.visitCatchClause(node));

  void _nested(void Function() visit) {
    _depth++;
    if (_depth > maxDepth) maxDepth = _depth;
    visit();
    _depth--;
  }
}
