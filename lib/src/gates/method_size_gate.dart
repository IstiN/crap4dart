import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../analysis/dart_parser.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `method_size` gate: fails methods longer than
/// `gates.method_size.max_lines` or with more than
/// `gates.method_size.max_params` parameters.
///
/// Constructors are checked only for parameter count; top-level functions
/// are checked like methods.
class MethodSizeGate implements Gate {
  /// Creates a [MethodSizeGate].
  const MethodSizeGate();

  @override
  String get id => 'method_size';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.methodSize;
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      final parsed = context.parsed(file);
      final visitor = _SizeVisitor(
        context.relativePath(file),
        parsed,
        config.maxLines,
        config.maxParams,
      );
      parsed.unit.accept(visitor);
      checked += visitor.checked;
      violations.addAll(visitor.violations);
    }
    final summary = violations.isEmpty
        ? '$checked methods within ${config.maxLines} lines/'
            '${config.maxParams} params'
        : '${violations.length} violations in $checked methods over '
            '${config.maxLines} lines/${config.maxParams} params';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }
}

class _SizeVisitor extends RecursiveAstVisitor<void> {
  _SizeVisitor(this._file, this._parsed, this._maxLines, this._maxParams);

  final String _file;
  final ParsedUnit _parsed;
  final int _maxLines;
  final int _maxParams;
  final List<GateViolation> violations = [];
  int checked = 0;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!node.isAbstract && node.body is! EmptyFunctionBody) {
      checked++;
      _checkSize(node, node.name.lexeme, node.parameters);
    }
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is! CompilationUnit) return;
    if (node.functionExpression.body is EmptyFunctionBody) return;
    checked++;
    _checkSize(node, node.name.lexeme, node.functionExpression.parameters);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    // Constructors are checked only for parameter count.
    checked++;
    final name = node.name?.lexeme ?? node.returnType.name;
    _checkParams(node, name, node.parameters);
  }

  int _startLine(AnnotatedNode node) => _parsed.lineInfo
      .getLocation(node.firstTokenAfterCommentAndMetadata.offset)
      .lineNumber;

  void _checkSize(
    AnnotatedNode node,
    String name,
    FormalParameterList? parameters,
  ) {
    final startLine = _startLine(node);
    final endLine = _parsed.lineInfo.getLocation(node.end).lineNumber;
    final lines = endLine - startLine + 1;
    if (lines > _maxLines) {
      violations.add(
        GateViolation(
          file: _file,
          line: startLine,
          message: '$name has $lines lines > max $_maxLines',
        ),
      );
    }
    _checkParams(node, name, parameters);
  }

  void _checkParams(
    AnnotatedNode node,
    String name,
    FormalParameterList? params,
  ) {
    final count = params?.parameters.length ?? 0;
    if (count > _maxParams) {
      violations.add(
        GateViolation(
          file: _file,
          line: _startLine(node),
          message: '$name has $count params > max $_maxParams',
        ),
      );
    }
  }
}
