import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../analysis/dart_parser.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `public_docs` gate: requires dartdoc comments on the public API.
///
/// Checks public classes, mixins, enums, extension types, named extensions,
/// top-level functions and variables, and public methods/fields declared
/// inside them. Members annotated with `@override` and members of private
/// containers are exempt, as are files matching `gates.public_docs.exclude`
/// (default: `test/**`).
class PublicDocsGate implements Gate {
  /// Creates a [PublicDocsGate].
  const PublicDocsGate();

  @override
  String get id => 'public_docs';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.publicDocs;
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      if (context.matchesAnyGlob(file, config.exclude)) continue;
      final parsed = context.parsed(file);
      final visitor = _DocsVisitor(context.relativePath(file), parsed);
      parsed.unit.accept(visitor);
      checked += visitor.checked;
      violations.addAll(visitor.violations);
    }
    final summary = violations.isEmpty
        ? '$checked public declarations documented'
        : '${violations.length}/$checked public declarations missing dartdoc';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }
}

class _DocsVisitor extends RecursiveAstVisitor<void> {
  _DocsVisitor(this._file, this._parsed);

  final String _file;
  final ParsedUnit _parsed;
  final List<GateViolation> violations = [];
  int checked = 0;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _checkNamed(node, node.name.lexeme, 'class');
    super.visitClassDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _checkNamed(node, node.name.lexeme, 'mixin');
    super.visitMixinDeclaration(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _checkNamed(node, node.name.lexeme, 'enum');
    super.visitEnumDeclaration(node);
  }

  @override
  // ignore: experimental_member_use
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    // ignore: experimental_member_use
    _checkNamed(node, node.name.lexeme, 'extension type');
    // ignore: experimental_member_use
    super.visitExtensionTypeDeclaration(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final name = node.name?.lexeme;
    if (name != null) _checkNamed(node, name, 'extension');
    node.members.accept(this);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is CompilationUnit) {
      _checkNamed(node, node.name.lexeme, 'function');
    }
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      if (_isPublic(variable.name.lexeme)) {
        _check(node, variable.name.lexeme, 'variable');
        break;
      }
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (_isPublic(node.name.lexeme) &&
        _enclosingIsPublic(node) &&
        !_hasOverride(node)) {
      _check(node, node.name.lexeme, 'method');
    }
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.parent is! CompilationUnit &&
        _enclosingIsPublic(node) &&
        !_hasOverride(node)) {
      for (final variable in node.fields.variables) {
        if (_isPublic(variable.name.lexeme)) {
          _check(node, variable.name.lexeme, 'field');
          break;
        }
      }
    }
  }

  // Constructors are not part of the documented public API surface.
  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {}

  bool _isPublic(String name) => !name.startsWith('_');

  // Members of private containers are not public API.
  bool _enclosingIsPublic(AstNode node) {
    final named = node.thisOrAncestorOfType<NamedCompilationUnitMember>();
    if (named != null) return _isPublic(named.name.lexeme);
    final extension = node.thisOrAncestorOfType<ExtensionDeclaration>();
    if (extension != null) {
      final name = extension.name?.lexeme;
      return name != null && _isPublic(name);
    }
    return true;
  }

  bool _hasOverride(AnnotatedNode node) => node.metadata.any(
        (a) => a.name.name == 'override',
      );

  void _checkNamed(CompilationUnitMember node, String name, String kind) {
    if (_isPublic(name)) _check(node, name, kind);
  }

  void _check(AnnotatedNode node, String name, String kind) {
    checked++;
    if (node.documentationComment == null) {
      final line = _parsed.lineInfo
          .getLocation(node.firstTokenAfterCommentAndMetadata.offset)
          .lineNumber;
      violations.add(
        GateViolation(
          file: _file,
          line: line,
          message: 'missing dartdoc on $kind "$name"',
        ),
      );
    }
  }
}
