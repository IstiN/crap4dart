import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Class name used for top-level functions that have no container.
const String topLevelClassName = '(top-level)';

/// Fallback container name for unnamed extensions.
const String unnamedExtensionName = 'extension';

/// A concrete method or top-level function found in a Dart source file.
class MethodInfo {
  /// Creates a [MethodInfo].
  const MethodInfo({
    required this.className,
    required this.methodName,
    required this.startLine,
    required this.endLine,
    required this.filePath,
  });

  /// Name of the containing class, mixin, enum or extension, or
  /// [topLevelClassName] for top-level functions.
  final String className;

  /// Name of the method or function.
  final String methodName;

  /// First line of the declaration (1-based, excluding doc comments and
  /// annotations).
  final int startLine;

  /// Last line of the declaration (1-based).
  final int endLine;

  /// Path of the source file the method was extracted from.
  final String filePath;

  @override
  String toString() => '$className.$methodName ($filePath:$startLine)';
}

/// A [MethodInfo] together with the AST node it was extracted from.
typedef ExtractedMethod = ({MethodInfo info, AstNode node});

/// Extracts concrete methods and top-level functions from a
/// [CompilationUnit].
///
/// Abstract/bodyless methods and nested function declarations are
/// ignored. Constructors are ignored unless [countConstructors] is set.
class MethodExtractor {
  /// Creates a [MethodExtractor].
  ///
  /// When [countConstructors] is true, constructors with a body — most
  /// notably factory constructors doing validation or mapping work — are
  /// extracted as methods named `<Class>.<name>` (`<Class>.new` for the
  /// unnamed constructor). Bodyless and redirecting constructors are
  /// always skipped: they contain no branches.
  const MethodExtractor({this.countConstructors = false});

  /// Whether constructors with a body are extracted as methods.
  final bool countConstructors;

  /// Extracts all methods from [unit] using [lineInfo] for line numbers.
  ///
  /// [filePath] is recorded on each returned [MethodInfo].
  List<MethodInfo> extract(
    CompilationUnit unit,
    LineInfo lineInfo, {
    String filePath = '',
  }) =>
      extractWithNodes(unit, lineInfo, filePath: filePath)
          .map((e) => e.info)
          .toList();

  /// Like [extract], but also returns the declaration [AstNode] of each
  /// method (a [MethodDeclaration] or a top-level [FunctionDeclaration]),
  /// suitable for cyclomatic complexity computation.
  List<ExtractedMethod> extractWithNodes(
    CompilationUnit unit,
    LineInfo lineInfo, {
    String filePath = '',
  }) {
    final visitor = _MethodVisitor(
      lineInfo,
      filePath,
      countConstructors: countConstructors,
    );
    for (final declaration in unit.declarations) {
      declaration.accept(visitor);
    }
    return visitor.methods;
  }
}

class _MethodVisitor extends RecursiveAstVisitor<void> {
  _MethodVisitor(
    this._lineInfo,
    this._filePath, {
    required this.countConstructors,
  });

  final LineInfo _lineInfo;
  final String _filePath;
  final bool countConstructors;
  final List<ExtractedMethod> methods = [];

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isAbstract || node.body is EmptyFunctionBody) return;
    _add(node.name.lexeme, node, _containerName(node));
    // Do not descend into the body: nested function declarations inside
    // method bodies are not extracted as separate methods.
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is! CompilationUnit) return;
    if (node.functionExpression.body is EmptyFunctionBody) return;
    _add(node.name.lexeme, node, topLevelClassName);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (!countConstructors) return;
    // Bodyless and redirecting constructors (`factory Foo() = _Foo;`)
    // carry no branches of their own.
    if (node.body is EmptyFunctionBody) return;
    _add(node.name?.lexeme ?? 'new', node, _containerName(node));
  }

  String _containerName(AstNode node) {
    final named = node.thisOrAncestorOfType<NamedCompilationUnitMember>();
    if (named != null) return named.name.lexeme;
    final extension = node.thisOrAncestorOfType<ExtensionDeclaration>();
    if (extension != null) {
      return extension.name?.lexeme ?? unnamedExtensionName;
    }
    return topLevelClassName;
  }

  void _add(String name, AnnotatedNode node, String className) {
    final start = node.firstTokenAfterCommentAndMetadata.offset;
    methods.add((
      info: MethodInfo(
        className: className,
        methodName: name,
        startLine: _lineInfo.getLocation(start).lineNumber,
        endLine: _lineInfo.getLocation(node.end).lineNumber,
        filePath: _filePath,
      ),
      node: node,
    ));
  }
}
