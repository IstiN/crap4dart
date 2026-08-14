import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'gate.dart';
import 'gate_context.dart';

/// The `unused_code` gate: flags private declarations with no references
/// anywhere in the analyzed sources — top-level `_functions`, `_classes`
/// and private class members (`_fields`, `_methods`, `_getters`).
///
/// Works on unresolved ASTs: references are counted lexically as simple
/// identifiers, which keeps the check conservative enough for a gate.
class UnusedCodeGate implements Gate {
  /// Creates an [UnusedCodeGate].
  const UnusedCodeGate();

  @override
  String get id => 'unused_code';

  @override
  Future<GateResult> run(GateContext context) async {
    if (context.partialSelection) {
      return GateResult.skip(
        'unused_code',
        'not meaningful for a partial selection',
      );
    }
    final config = context.config.gates.unusedCode;
    final declarations = <_Declaration>[];
    final used = <String>{};
    for (final file in context.files) {
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      final parsed = context.parsed(file);
      final relative = context.relativePath(file);
      final visitor = _DeclarationVisitor(relative, parsed.lineInfo);
      parsed.unit.accept(visitor);
      declarations.addAll(visitor.declarations);
      used.addAll(visitor.references);
    }
    final violations = <GateViolation>[];
    var checked = 0;
    for (final declaration in declarations) {
      checked++;
      if (!used.contains(declaration.name)) {
        violations.add(declaration.violation);
      }
    }
    final summary = violations.isEmpty
        ? '$checked private declarations used'
        : '${violations.length}/$checked private declarations unused';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }
}

class _Declaration {
  _Declaration(this.name, this.violation);

  final String name;
  final GateViolation violation;
}

/// Collects private declarations and identifier references of a unit.
class _DeclarationVisitor extends RecursiveAstVisitor<void> {
  _DeclarationVisitor(this._file, this._lineInfo);

  final String _file;
  final LineInfo _lineInfo;
  final List<_Declaration> declarations = [];
  final Set<String> references = {};

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final name = node.name.lexeme;
    if (name.startsWith('_')) {
      _declare(name, node);
    } else {
      // Public classes' private members are candidates.
      for (final member in node.members) {
        member.accept(this);
      }
    }
    // References inside any class still count.
    node.accept(_RefVisitor(references));
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final name = node.name.lexeme;
    final isPrivate = name.startsWith('_');
    final inPrivateContainer = node
            .thisOrAncestorOfType<ClassDeclaration>()
            ?.name
            .lexeme
            .startsWith('_') ??
        true;
    if (isPrivate && !inPrivateContainer) {
      _declare(name, node);
      references.remove(name);
    }
    node.accept(_RefVisitor(references));
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final inPrivateContainer = node
            .thisOrAncestorOfType<ClassDeclaration>()
            ?.name
            .lexeme
            .startsWith('_') ??
        true;
    if (!inPrivateContainer) {
      for (final variable in node.fields.variables) {
        if (variable.name.lexeme.startsWith('_')) {
          _declare(variable.name.lexeme, node);
        }
      }
    }
    node.accept(_RefVisitor(references));
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is! CompilationUnit) return;
    if (node.name.lexeme.startsWith('_')) {
      _declare(node.name.lexeme, node);
    }
    node.accept(_RefVisitor(references));
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    references.add(node.name);
    super.visitSimpleIdentifier(node);
  }

  void _declare(String name, AnnotatedNode node) {
    final line = _lineInfo
        .getLocation(node.firstTokenAfterCommentAndMetadata.offset)
        .lineNumber;
    declarations.add(
      _Declaration(
        name,
        GateViolation(
          file: _file,
          line: line,
          message: '$name is never referenced',
        ),
      ),
    );
  }
}

/// Counts every simple identifier as a potential reference.
class _RefVisitor extends RecursiveAstVisitor<void> {
  _RefVisitor(this.references);

  final Set<String> references;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    references.add(node.name);
  }
}
