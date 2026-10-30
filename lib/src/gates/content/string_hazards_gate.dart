import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../analysis/dart_parser.dart';
import '../gate.dart';
import '../gate_context.dart';
import '../gate_ids.dart';

/// The `string_hazards` gate: flags string literals whose escaping or
/// pattern usage contradicts what the author almost certainly meant.
///
/// Three near-zero-FP checks, all from the parsed-unresolved AST:
///
/// 1. **Escaped interpolation** — `\$name` or `\${name}` inside a non-raw
///    string renders as the literal text `$name`. Flagged only when the
///    same identifier is genuinely interpolated elsewhere in the same
///    file (sibling evidence of intent), which keeps deliberate shell
///    escapes out.
/// 2. **Raw regex with an escaped anchor** — a raw string passed to
///    `RegExp(...)` ending with `\$` (or starting with `\^`): in a raw
///    string the backslash survives, so the regex matches a literal
///    dollar/caret where the end/start anchor was almost certainly
///    intended (a plain `$`/`^` is the anchor).
/// 3. **Regex anchors in literal `String` patterns** — `replaceFirst` /
///    `replaceAll` / `replace*Mapped` / `split` treat their `String`
///    pattern as literal text, so a leading `^` or unescaped trailing
///    `$` can never do what a regex anchor does. Flagged when the
///    pattern argument is a string literal carrying such an anchor.
///
/// Deliberate literal dollars/carets (shell code, price patterns) trip
/// the warnings occasionally — that is what warning severity is for.
class StringHazardsGate implements Gate {
  /// Creates a [StringHazardsGate].
  const StringHazardsGate();

  @override
  String get id => GateIds.stringHazards;

  @override
  Future<GateResult> run(GateContext context) async {
    final violations = <GateViolation>[];
    for (final file in context.files) {
      final parsed = context.parsed(file);
      final visitor = _HazardsVisitor(
        context.relativePath(file),
        parsed,
      );
      parsed.unit.accept(visitor);
      violations.addAll(visitor.resolve());
    }
    return violations.isEmpty
        ? GateResult.pass(id, summary: 'no string literal hazards found')
        : GateResult.fail(id, violations);
  }
}

/// An escaped-dollar occurrence awaiting sibling-interpolation evidence.
final class _EscapedDollar {
  /// The identifier (or brace-enclosed identifier) after `\$`.
  final String name;

  /// Source line of the occurrence.
  final int line;

  /// Creates an occurrence record.
  const _EscapedDollar(this.name, this.line);
}

class _HazardsVisitor extends RecursiveAstVisitor<void> {
  static final RegExp _anchorMethods = RegExp(
    r'^(replaceFirst|replaceFirstMapped|replaceAll|replaceAllMapped|split)$',
  );

  static final RegExp _identStart = RegExp(r'^[A-Za-z_]');

  final String _file;

  final ParsedUnit _parsed;

  final List<GateViolation> violations = [];

  final List<_EscapedDollar> _escaped = [];

  final Set<String> _genuineInterpolations = {};

  _HazardsVisitor(this._file, this._parsed);

  /// Emits the escaped-interpolation violations that have sibling
  /// evidence, after the whole file has been visited. One violation per
  /// (line, identifier) pair.
  List<GateViolation> resolve() {
    final seen = <String>{};
    for (final occurrence in _escaped) {
      if (!_genuineInterpolations.contains(occurrence.name)) continue;
      final key = '${occurrence.line}:${occurrence.name}';
      if (!seen.add(key)) continue;
      violations.add(
        GateViolation(
          file: _file,
          line: occurrence.line,
          message: "escaped interpolation '\\\$${occurrence.name}' renders "
              "literal '\$${occurrence.name}'; '\$${occurrence.name}' is "
              'interpolated elsewhere in this file — stray backslash?',
        ),
      );
    }
    return violations;
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (!node.isRaw) _scanEscapedDollars(node.literal.lexeme, _lineOf(node));
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    for (final element in node.elements) {
      if (element is InterpolationString) {
        _scanEscapedDollars(element.contents.lexeme, _lineOf(element));
      }
    }
    for (final element in node.elements) {
      if (element is! InterpolationExpression) continue;
      final root = _rootName(element.expression);
      if (root != null) _genuineInterpolations.add(root);
    }
    super.visitStringInterpolation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == 'RegExp') {
      _checkRawRegExpPattern(node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'RegExp' && node.target == null) {
      _checkRawRegExpPattern(node.argumentList);
    } else if (_anchorMethods.hasMatch(node.methodName.name) &&
        node.target != null) {
      _checkLiteralPatternArgument(node);
    }
    super.visitMethodInvocation(node);
  }

  void _scanEscapedDollars(String lexeme, int line) {
    var i = 0;
    while (i < lexeme.length - 1) {
      if (lexeme.codeUnitAt(i) != 0x5C) {
        i += 1;
        continue;
      }
      final next = lexeme[i + 1];
      if (next == r'\') {
        i += 2;
        continue;
      }
      if (next != r'$') {
        i += 2;
        continue;
      }
      final name = _identifierAfter(lexeme, i + 2);
      if (name != null) _escaped.add(_EscapedDollar(name, line));
      i += 2;
    }
  }

  void _checkRawRegExpPattern(ArgumentList arguments) {
    for (final argument in arguments.arguments) {
      if (argument is NamedArgument && argument.name.lexeme != 'source') {
        continue;
      }
      final literal =
          argument is NamedArgument ? argument.argumentExpression : argument;
      if (literal is! SimpleStringLiteral || !literal.isRaw) continue;
      _checkRawAnchor(literal);
      return;
    }
  }

  void _checkRawAnchor(SimpleStringLiteral literal) {
    final value = literal.value;
    if (value.endsWith(r'\$')) {
      _add(
        literal,
        "raw RegExp pattern ends with '\\\$' — in a raw string that is "
        "a literal '\$' character, not the end anchor; did you mean "
        "'\$'?",
      );
    } else if (value.startsWith(r'\^')) {
      _add(
        literal,
        "raw RegExp pattern starts with '\\^' — in a raw string that is "
        "a literal '^' character, not the start anchor; did you mean "
        "'^'?",
      );
    }
  }

  void _checkLiteralPatternArgument(MethodInvocation node) {
    for (final argument in node.argumentList.arguments) {
      if (argument is NamedArgument) continue;
      if (argument is AdjacentStrings) {
        _checkAnchoredLiteral(argument.strings.first, leading: true);
        _checkAnchoredLiteral(argument.strings.last, trailing: true);
        return;
      }
      if (argument is! SimpleStringLiteral) return;
      _checkAnchoredLiteral(argument, leading: true, trailing: true);
      return;
    }
  }

  void _checkAnchoredLiteral(
    Expression node, {
    bool leading = false,
    bool trailing = false,
  }) {
    if (node is! SimpleStringLiteral) return;
    final value = node.value;
    if (leading && value.startsWith('^')) {
      _add(
        node,
        "literal pattern starts with '^' — String patterns match "
        "literally, so this can only match a literal '^' character; "
        'a RegExp was probably intended',
      );
    }
    if (trailing && node.isRaw) {
      _add(
        node,
        "literal pattern ends with '\$' — String patterns match "
        "literally, so this can only match a literal '\$' character; "
        'a RegExp was probably intended',
      );
    }
  }

  String? _identifierAfter(String lexeme, int index) {
    var start = index;
    if (start < lexeme.length && lexeme[start] == '{') start += 1;
    if (start >= lexeme.length) return null;
    if (!_identStart.hasMatch(lexeme.substring(start, start + 1))) {
      return null;
    }
    var end = start + 1;
    while (end < lexeme.length && _isIdentChar(lexeme.codeUnitAt(end))) {
      end += 1;
    }
    return lexeme.substring(start, end);
  }

  bool _isIdentChar(int unit) =>
      (unit >= 0x41 && unit <= 0x5A) ||
      (unit >= 0x61 && unit <= 0x7A) ||
      (unit >= 0x30 && unit <= 0x39) ||
      unit == 0x5F;

  String? _rootName(Expression expression) {
    var node = _unwrapPrefix(expression);
    while (true) {
      final target = _targetOf(node);
      if (target == null) break;
      node = _unwrapPrefix(target);
    }
    return node is SimpleIdentifier ? node.name : null;
  }

  /// The receiver of a property access or method call, `null` for other
  /// expression shapes.
  Expression? _targetOf(Expression node) => switch (node) {
        PropertyAccess() => node.target,
        MethodInvocation() => node.target,
        _ => null,
      };

  /// Follows `a.b.c` prefix chains down to the root receiver.
  Expression _unwrapPrefix(Expression expression) {
    var node = expression;
    while (node is PrefixedIdentifier) {
      node = node.prefix;
    }
    return node;
  }

  void _add(AstNode node, String message) {
    violations.add(
      GateViolation(file: _file, line: _lineOf(node), message: message),
    );
  }

  int _lineOf(AstNode node) =>
      _parsed.lineInfo.getLocation(node.offset).lineNumber;
}
