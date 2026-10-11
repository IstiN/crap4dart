import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../analysis/dart_parser.dart';
import '../analysis/method_extractor.dart';
import '../config/config.dart';

/// One row of the declarative mutation operator table: replacing
/// [original] with [mutant] produces one mutant, tagged [category].
/// The categories themselves live in `config.dart`
/// (`mutationOperatorCategories`) so config validation and detection
/// share one source.
class MutationOperator {
  /// Creates a [MutationOperator].
  const MutationOperator(this.category, this.original, this.mutant);

  /// Operator category (one of `mutationOperatorCategories`).
  final String category;

  /// Lexeme the operator token must have to match.
  final String original;

  /// Lexeme written in place of [original] in the mutated file.
  final String mutant;
}

/// Lexemes reused across the table and the detector, kept in named
/// constants so the file stays free of repeated magic literals.
const String _trueLexeme = 'true';
const String _falseLexeme = 'false';
const String _zeroLexeme = '0';
const String _oneLexeme = '1';
const String _unaryCategory = 'unary';
const String _booleanCategory = 'boolean';
const String _constantCategory = 'constant';

/// The declarative operator table, adapted from the unclebob/mutator
/// research conclusions. Binary rows match `BinaryExpression.operator`
/// tokens; the unary row deletes a `!` prefix; literal rows match
/// `BooleanLiteral` and `IntegerLiteral` tokens.
const List<MutationOperator> mutationOperators = [
  MutationOperator('arithmetic', '+', '-'),
  MutationOperator('arithmetic', '-', '+'),
  MutationOperator('arithmetic', '*', '/'),
  MutationOperator('arithmetic', '/', '*'),
  MutationOperator('arithmetic', '/', '~/'),
  MutationOperator('boundary', '>', '>='),
  MutationOperator('boundary', '>=', '>'),
  MutationOperator('boundary', '<', '<='),
  MutationOperator('boundary', '<=', '<'),
  MutationOperator('boundary', '>', '<'),
  MutationOperator('boundary', '<', '>'),
  MutationOperator('boundary', '>=', '<='),
  MutationOperator('boundary', '<=', '>='),
  MutationOperator('equality', '==', '!='),
  MutationOperator('equality', '!=', '=='),
  MutationOperator('logical', '&&', '||'),
  MutationOperator('logical', '||', '&&'),
  MutationOperator('boolean', _trueLexeme, _falseLexeme),
  MutationOperator('boolean', _falseLexeme, _trueLexeme),
  MutationOperator('constant', _zeroLexeme, _oneLexeme),
  MutationOperator('constant', _oneLexeme, _zeroLexeme),
];

/// A single place in a source file where one operator replacement
/// applies. Offsets come from analyzer tokens, never from regex.
class MutationSite {
  /// Creates a [MutationSite].
  const MutationSite({
    required this.file,
    required this.line,
    required this.method,
    required this.category,
    required this.original,
    required this.mutant,
    required this.offset,
    required this.length,
  });

  /// Absolute path of the source file.
  final String file;

  /// 1-based source line of the replaced token.
  final int line;

  /// Containing method (`Class.method` or `(top-level).name`), or
  /// `null` when the site sits outside every extracted method.
  final String? method;

  /// Operator category.
  final String category;

  /// Original lexeme at the site.
  final String original;

  /// Lexeme replacing [original] in the mutant.
  final String mutant;

  /// Character offset of the replaced span in the file content.
  final int offset;

  /// Length of the replaced span in characters.
  final int length;

  /// Returns [content] with this site mutated (used by the engine).
  String applyTo(String content) =>
      content.replaceRange(offset, offset + length, mutant);

  @override
  String toString() => '$file:$line: $original -> $mutant ($category)';
}

/// Detects [MutationSite]s in parsed Dart sources. Sites are found by
/// matching AST nodes against [mutationOperators]; all offsets come
/// from token offsets of the parsed (unresolved) unit.
class MutationSiteDetector {
  /// Creates a [MutationSiteDetector] limited to [categories]
  /// (all categories when omitted).
  MutationSiteDetector({Set<String>? categories})
      : _categories = categories ?? mutationOperatorCategories.toSet();

  final Set<String> _categories;

  /// Finds every mutation site in [parsed], sorted by offset.
  List<MutationSite> detect(ParsedUnit parsed) {
    final methods = const MethodExtractor()
        .extractWithNodes(parsed.unit, parsed.lineInfo, filePath: parsed.path);
    final visitor =
        _SiteVisitor(_categories, parsed.lineInfo, methods, parsed.path);
    parsed.unit.accept(visitor);
    final sites = visitor.sites;
    sites.sort((a, b) => a.offset.compareTo(b.offset));
    return sites;
  }
}

/// AST visitor collecting sites for the enabled operator categories.
class _SiteVisitor extends GeneralizingAstVisitor<void> {
  _SiteVisitor(this._categories, this._lineInfo, this._methods, this._file);

  final Set<String> _categories;
  final LineInfo _lineInfo;
  final List<ExtractedMethod> _methods;
  final String _file;
  final List<MutationSite> sites = [];

  @override
  void visitNode(AstNode node) => node.visitChildren(this);

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final operator = node.operator.lexeme;
    for (final row in mutationOperators) {
      if (row.original != operator) continue;
      if (!_categories.contains(row.category)) continue;
      _add(row.category, row.original, row.mutant, node.operator.offset,
          node.operator.length);
    }
    node.visitChildren(this);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    final operator = node.operator.lexeme;
    if (operator == '!' && _categories.contains(_unaryCategory)) {
      // Delete the `!` prefix: the operand stays.
      _add(_unaryCategory, '!', '', node.operator.offset, 1);
    } else if (operator == '-' && _categories.contains(_constantCategory)) {
      // `-1` becomes `0` (the whole `-1` span is replaced).
      final operand = node.operand;
      if (operand is IntegerLiteral && operand.literal.lexeme == _oneLexeme) {
        _add(_constantCategory, '-1', _zeroLexeme, node.operator.offset,
            operand.end - node.operator.offset);
      }
    }
    node.visitChildren(this);
  }

  @override
  void visitBooleanLiteral(BooleanLiteral node) {
    if (!_categories.contains(_booleanCategory)) return;
    final lexeme = node.literal.lexeme;
    _add(
        _booleanCategory,
        lexeme,
        lexeme == _trueLexeme ? _falseLexeme : _trueLexeme,
        node.literal.offset,
        node.literal.length);
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    if (!_categories.contains(_constantCategory)) return;
    final lexeme = node.literal.lexeme;
    if (lexeme != _zeroLexeme && lexeme != _oneLexeme) return;
    _add(
        _constantCategory,
        lexeme,
        lexeme == _zeroLexeme ? _oneLexeme : _zeroLexeme,
        node.literal.offset,
        node.literal.length);
  }

  void _add(
    String category,
    String original,
    String mutant,
    int offset,
    int length,
  ) {
    sites.add(MutationSite(
      file: _file,
      line: _lineInfo.getLocation(offset).lineNumber,
      method: _methodAt(offset),
      category: category,
      original: original,
      mutant: mutant,
      offset: offset,
      length: length,
    ));
  }

  /// Containing extracted method's display name, or `null`.
  String? _methodAt(int offset) {
    for (final entry in _methods) {
      final node = entry.node;
      if (offset >= node.offset && offset <= node.end) {
        final info = entry.info;
        return '${info.className}.${info.methodName}';
      }
    }
    return null;
  }
}
