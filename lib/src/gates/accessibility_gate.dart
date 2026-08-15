import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../analysis/dart_parser.dart';
import 'gate.dart';
import 'gate_context.dart';

/// Default label parameter when a widget has no dedicated mapping.
const String _semanticsLabelParam = 'semanticsLabel';

/// The `accessibility` gate: requires semantics labels on interactive
/// widgets listed in `gates.accessibility.require_label_for`.
///
/// Label requirements: `IconButton` → `tooltip`, `Image` → `semanticLabel`,
/// `GestureDetector`/`InkWell` → `semanticsLabel` (or a wrapping
/// `Semantics` widget). Skipped for non-Flutter projects.
class AccessibilityGate implements Gate {
  /// Creates an [AccessibilityGate].
  const AccessibilityGate();

  /// Maps widget type to the named parameter that provides its label.
  static const Map<String, String> labelParams = {
    'IconButton': 'tooltip',
    'Image': 'semanticLabel',
    'GestureDetector': _semanticsLabelParam,
    'InkWell': _semanticsLabelParam,
  };

  @override
  String get id => 'accessibility';

  @override
  Future<GateResult> run(GateContext context) async {
    if (!context.isFlutterProject) {
      return GateResult.skip(id, 'not a Flutter project');
    }
    final widgets = context.config.gates.accessibility.requireLabelFor;
    final violations = <GateViolation>[];
    for (final file in context.files) {
      final parsed = context.parsed(file);
      final visitor = _A11yVisitor(context.relativePath(file), parsed, widgets);
      parsed.unit.accept(visitor);
      violations.addAll(visitor.violations);
    }
    return violations.isEmpty
        ? GateResult.pass(id, summary: '${widgets.length} widget types checked')
        : GateResult.fail(id, violations);
  }
}

class _A11yVisitor extends RecursiveAstVisitor<void> {
  _A11yVisitor(this._file, this._parsed, this._widgets);

  final String _file;
  final ParsedUnit _parsed;
  final List<String> _widgets;
  final List<GateViolation> violations = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Named constructor calls like Image.asset(...) arrive as a
    // MethodInvocation with the class name as the target.
    final target = node.target;
    if (target is SimpleIdentifier && _widgets.contains(target.name)) {
      _check(node, target.name, node.argumentList);
    } else {
      _check(node, node.methodName.name, node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(node, node.constructorName.type.name2.lexeme, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  void _check(AstNode node, String name, ArgumentList arguments) {
    if (!_widgets.contains(name)) return;
    final labelParam =
        AccessibilityGate.labelParams[name] ?? _semanticsLabelParam;
    final hasLabel = arguments.arguments.any(
      (a) => a is NamedExpression && a.name.label.name == labelParam,
    );
    if (hasLabel) return;
    if (labelParam == _semanticsLabelParam && _wrappedInSemantics(node)) return;
    violations.add(
      GateViolation(
        file: _file,
        line: _parsed.lineInfo.getLocation(node.offset).lineNumber,
        message: "$name missing '$labelParam' for accessibility",
      ),
    );
  }

  bool _wrappedInSemantics(AstNode node) =>
      node.thisOrAncestorMatching<AstNode>(_isSemanticsWidget) != null;

  bool _isSemanticsWidget(AstNode node) {
    if (node is MethodInvocation) return node.methodName.name == 'Semantics';
    if (node is InstanceCreationExpression) {
      return node.constructorName.type.name2.lexeme == 'Semantics';
    }
    return false;
  }
}
