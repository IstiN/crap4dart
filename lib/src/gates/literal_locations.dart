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
    if (_isProtocolPosition(parent, child)) return true;
    if (_stopsProtocolWalk(parent)) break;
    child = parent;
    parent = parent.parent;
  }
  return false;
}

/// Directive URIs (structural references) and case labels (protocol
/// values) are protocol vocabulary wherever they appear on the
/// ancestor path.
bool _isDirectiveOrCaseLabel(AstNode parent) =>
    parent is Directive ||
    parent is CaseClause ||
    parent is SwitchPatternCase ||
    parent is SwitchCase;

/// Map keys and index targets (`expr['name']`) are access vocabulary,
/// not constants — [child] must sit in the key/index position itself.
bool _isKeyOrIndex(AstNode parent, AstNode child) =>
    parent is MapLiteralEntry && parent.key == child ||
    parent is IndexExpression && parent.index == child;

/// Whether [parent] puts a literal in a protocol-identifier position.
bool _isProtocolPosition(AstNode parent, AstNode child) =>
    _isDirectiveOrCaseLabel(parent) || _isKeyOrIndex(parent, child);

/// The ancestor walk stops at interpolation elements and argument
/// lists: above them the literal belongs to an expression, not to the
/// enclosing protocol position.
bool _stopsProtocolWalk(AstNode parent) =>
    parent is InterpolationElement || parent is ArgumentList;

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

/// The `ignore` config partitioned by entry kind: plain entries match
/// literal values and prefix heads; entries containing a `/` are
/// file-path globs and exempt the files themselves.
class IgnoreConfig {
  /// Creates a partition for the given [ignore] entries.
  const IgnoreConfig(this.values, this.pathGlobs);

  /// Value entries (no separator).
  final Set<String> values;

  /// File-path glob entries (containing a `/`).
  final List<String> pathGlobs;

  /// Partitions [ignore] by whether the entry contains a `/`.
  factory IgnoreConfig.partition(Iterable<String> ignore) {
    final values = <String>{};
    final paths = <String>[];
    for (final entry in ignore) {
      if (entry.contains('/')) {
        paths.add(entry);
      } else {
        values.add(entry);
      }
    }
    return IgnoreConfig(values, paths);
  }
}

/// One occurrence of a literal: file, 1-based line, and whether the
/// site is itself a constant-declaration initializer.
typedef LiteralSite = ({String file, int line, bool isConstDecl});

/// Occurrence sites of one literal value across the corpus.
class LiteralSites {
  /// Records one occurrence.
  void add(String file, int line, {bool isConstDecl = false}) =>
      _sites.add((file: file, line: line, isConstDecl: isConstDecl));

  /// Every occurrence, in scan order.
  List<LiteralSite> get sites => _sites;

  /// Distinct files containing the value.
  Set<String> get files => _sites.map((s) => s.file).toSet();

  final List<LiteralSite> _sites = [];
}

/// The value of a plain (non-interpolated) string expression, `null`
/// for interpolations and other expression kinds.
String? stringValueOf(Expression initializer) {
  if (initializer is SimpleStringLiteral) return initializer.value;
  if (initializer is AdjacentStrings) return initializer.stringValue;
  return null;
}
