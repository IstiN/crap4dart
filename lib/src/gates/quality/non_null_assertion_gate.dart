import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../gate.dart';
import '../gate_context.dart';
import '../gate_ids.dart';

/// The `non_null_assertion` gate: flags every non-null assertion — the
/// postfix `!` operator (`x!`) and the null-assert pattern
/// (`case var x!`).
///
/// A bang crashes on null where the null-safe alternatives carry the
/// same intent with a readable check:
///
/// - expressions: `?.` with `??` (or `??=` / a plain null check on a
///   local variable). The common check-then-bang ternary
///   `E != null ? E!.m() : fallback` collapses to `E?.m() ?? fallback`
///   — single receiver evaluation, no bang. Getters and record fields
///   do not promote after a null check, so for those the collapse is
///   the *only* bang-free form.
/// - patterns: a null-check pattern (`case var x?`) skips null values
///   instead of crashing on them.
///
/// The compiled output is identical — `!` only trades a readable check
/// for a runtime crash on unexpected null. Zero thresholds: any `!` is
/// a finding. Existing codebases adopt via baseline
/// (`check --save-baseline`) or `severity: warning`; decode boundaries
/// (`json['x']!`-heavy files) are the canonical per-path candidates.
///
/// Independently validated by DCM's `avoid-non-null-assertion`.
class NonNullAssertionGate implements Gate {
  /// Creates a [NonNullAssertionGate].
  const NonNullAssertionGate();

  @override
  String get id => GateIds.nonNullAssertion;

  @override
  Future<GateResult> run(GateContext context) async {
    final violations = <GateViolation>[];
    for (final file in context.files) {
      final parsed = context.parsed(file);
      parsed.unit.accept(
        _BangScanner(
          context.relativePath(file),
          parsed.lineInfo,
          violations,
        ),
      );
    }
    return violations.isEmpty
        ? GateResult.pass(id, summary: 'no non-null assertions')
        : GateResult.fail(
            id,
            violations,
            summary: '${violations.length} non-null assertions',
          );
  }
}

/// Collects postfix `!` expressions and null-assert patterns, reporting
/// each occurrence at the line of its `!` token.
class _BangScanner extends RecursiveAstVisitor<void> {
  final String _file;

  final LineInfo _lineInfo;

  final List<GateViolation> _violations;

  _BangScanner(this._file, this._lineInfo, this._violations);

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (node.operator.lexeme == '!') {
      _flag(
        node.operator,
        'non-null assertion (`!`) — a null value crashes here; '
        'use `?.`/`??` or a null check on a local variable',
      );
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitNullAssertPattern(NullAssertPattern node) {
    _flag(
      node.operator,
      'null-assert pattern (`!`) — a null value crashes here; '
      'use a null-check pattern (`?`) to skip nulls, or match the '
      'non-null shape explicitly',
    );
    super.visitNullAssertPattern(node);
  }

  void _flag(Token operator, String message) {
    _violations.add(
      GateViolation(
        file: _file,
        line: _lineInfo.getLocation(operator.offset).lineNumber,
        message: message,
      ),
    );
  }
}
