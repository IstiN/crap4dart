/// Shared literal-scanning rules of `magic_constants` and
/// `scattered_constants`: which occurrences are exempt (constant
/// declarations) and which are protocol identifiers instead of
/// constants.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Marks every literal line reachable from a const initializer as
/// exempt — everything inside a const declaration is by definition a
/// named constant already.
void markExemptLines(
  Set<int> lines,
  LineInfo lineInfo,
  Expression initializer,
) {
  initializer.accept(_ExemptMarker(
      lines, (node) => lineInfo.getLocation(node.offset).lineNumber));
}

/// Whether [node] sits in a position that makes its literal a
/// protocol identifier rather than a magic constant: import/export/
/// part URIs, map keys, index expressions and case labels.
bool isProtocolIdentifier(AstNode node) {
  var child = node;
  var parent = node.parent;
  while (parent != null) {
    // Directive URIs are structural references, not constants.
    if (parent is Directive) return true;
    if (parent is MapLiteralEntry && parent.key == child) return true;
    // `expr['name']` — a protocol field access, not a constant.
    if (parent is IndexExpression && parent.index == child) return true;
    // Case labels match protocol values, not constants.
    if (parent is CaseClause ||
        parent is SwitchPatternCase ||
        parent is SwitchCase) {
      return true;
    }
    if (parent is InterpolationElement || parent is ArgumentList) break;
    child = parent;
    parent = parent.parent;
  }
  return false;
}

class _ExemptMarker extends RecursiveAstVisitor<void> {
  _ExemptMarker(this.lines, this.lineTo);

  final Set<int> lines;
  final int Function(AstNode) lineTo;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) =>
      lines.add(lineTo(node));

  @override
  void visitIntegerLiteral(IntegerLiteral node) => lines.add(lineTo(node));

  @override
  void visitDoubleLiteral(DoubleLiteral node) => lines.add(lineTo(node));

  @override
  void visitAdjacentStrings(AdjacentStrings node) => lines.add(lineTo(node));
}

/// Base visitor for the literal gates: descends a compilation unit,
/// keeping every literal line that belongs to a constant declaration
/// in [exemptLines] — such literals are already named constants.
abstract class ExemptingLiteralVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor over [lineInfo].
  ExemptingLiteralVisitor(this.lineInfo);

  /// Line info of the scanned file.
  final LineInfo lineInfo;

  /// 1-based lines of literals inside constant declarations.
  final Set<int> exemptLines = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final parent = node.parent;
    final isConst = parent is VariableDeclarationList && parent.isConst;
    if (isConst && node.initializer != null) {
      markExemptLines(exemptLines, lineInfo, node.initializer!);
    }
    node.initializer?.accept(this);
  }
}
