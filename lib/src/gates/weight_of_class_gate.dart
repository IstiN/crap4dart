import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../analysis/dart_parser.dart';
import 'file_visitor.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `weight_of_class` gate: fails classes that reveal more data than
/// behavior — the ratio of public instance fields to public instance
/// members exceeds `gates.weight_of_class.max_weight` (default 0.33).
/// Disabled by default; data/model classes are legitimate.
class WeightOfClassGate implements Gate {
  /// Creates a [WeightOfClassGate].
  const WeightOfClassGate();

  @override
  String get id => 'weight_of_class';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.weightOfClass;
    final (checked, violations) = visitGateFiles(
      context,
      config.exclude,
      (relative, parsed) {
        final visitor = _WeightVisitor(relative, parsed);
        parsed.unit.accept(visitor);
        return (
          visitor.checked,
          visitor.weighted
              .where((c) => c.weight > config.maxWeight)
              .map((c) => c.violation)
              .toList(),
        );
      },
    );
    final max = _format(config.maxWeight);
    final summary = violations.isEmpty
        ? '$checked classes within weight $max'
        : '${violations.length}/$checked classes over weight $max';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  String _format(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

/// A class candidate with its computed data-to-members weight.
class _Weighted {
  _Weighted(this.weight, this.violation);

  final double weight;
  final GateViolation violation;
}

class _WeightVisitor extends RecursiveAstVisitor<void> {
  _WeightVisitor(this._file, this._parsed);

  final String _file;
  final ParsedUnit _parsed;
  final List<_Weighted> weighted = [];
  int checked = 0;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.name.lexeme.startsWith('_')) return;
    final (:fields, :members) = _countMembers(node);
    if (members > 0 && fields > 0) {
      checked++;
      final line = _parsed.lineInfo
          .getLocation(node.firstTokenAfterCommentAndMetadata.offset)
          .lineNumber;
      weighted.add(
        _Weighted(
          fields / members,
          GateViolation(
            file: _file,
            line: line,
            message: '${node.name.lexeme} exposes $fields public fields '
                'of $members public members '
                '(weight=${(fields / members).toStringAsFixed(2)})',
          ),
        ),
      );
    }
  }

  /// Counts public instance fields and public instance members of [node].
  ({int fields, int members}) _countMembers(ClassDeclaration node) {
    var fields = 0;
    var members = 0;
    for (final member in node.members) {
      if (member is FieldDeclaration && !member.isStatic) {
        for (final variable in member.fields.variables) {
          if (!variable.name.lexeme.startsWith('_')) {
            fields++;
            members++;
          }
        }
      } else if (_isPublicInstanceMethod(member)) {
        members++;
      }
    }
    return (fields: fields, members: members);
  }

  /// Whether [member] is a non-static, non-abstract method.
  bool _isPublicInstanceMethod(ClassMember member) =>
      member is MethodDeclaration && !member.isStatic && !member.isAbstract;
}
