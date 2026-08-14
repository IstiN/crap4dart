import '../analysis/complexity.dart';
import '../config/config.dart';
import '../analysis/method_extractor.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `class_size` gate: fails classes with more than
/// `gates.class_size.max_methods` concrete methods (default 25) or a
/// weighted-methods-per-class sum (total cyclomatic complexity of all
/// methods, default 80) above `max_wmc`. Catches god-classes assembled
/// from many small methods that pass `complexity` individually.
class ClassSizeGate implements Gate {
  /// Creates a [ClassSizeGate].
  const ClassSizeGate();

  @override
  String get id => 'class_size';

  @override
  Future<GateResult> run(GateContext context) async {
    final config = context.config.gates.classSize;
    const extractor = MethodExtractor();
    const calculator = ComplexityCalculator();
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      final totals = _classTotals(context, file, extractor, calculator);
      checked += totals.length;
      violations.addAll(_violations(totals, context, file, config));
    }
    final summary = violations.isEmpty
        ? '$checked classes within ${config.maxMethods} methods/'
            'WMC ${config.maxWmc}'
        : '${violations.length} violations in $checked classes over '
            '${config.maxMethods} methods/WMC ${config.maxWmc}';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// Concrete-method count and WMC per class declared in [file].
  Map<String, _ClassTotals> _classTotals(
    GateContext context,
    String file,
    MethodExtractor extractor,
    ComplexityCalculator calculator,
  ) {
    final parsed = context.parsed(file);
    final totals = <String, _ClassTotals>{};
    for (final method
        in extractor.extractWithNodes(parsed.unit, parsed.lineInfo)) {
      final info = method.info;
      if (info.className == topLevelClassName) continue;
      final classTotals = totals.putIfAbsent(
        info.className,
        () => _ClassTotals(firstLine: info.startLine),
      );
      classTotals.methods++;
      classTotals.wmc += calculator.compute(method.node);
      classTotals.lastLine = info.endLine;
    }
    return totals;
  }

  /// Size violations of [totals] against [config].
  List<GateViolation> _violations(
    Map<String, _ClassTotals> totals,
    GateContext context,
    String file,
    ClassSizeGateConfig config,
  ) {
    final violations = <GateViolation>[];
    for (final entry in totals.entries) {
      final classTotals = entry.value;
      final line = classTotals.firstLine;
      final file_ = context.relativePath(file);
      if (classTotals.methods > config.maxMethods) {
        violations.add(
          GateViolation(
            file: file_,
            line: line,
            message: '${entry.key} has ${classTotals.methods} methods '
                '> max ${config.maxMethods}',
          ),
        );
      }
      if (classTotals.wmc > config.maxWmc) {
        violations.add(
          GateViolation(
            file: file_,
            line: line,
            message: '${entry.key} WMC=${classTotals.wmc} '
                '> max ${config.maxWmc}',
          ),
        );
      }
    }
    return violations;
  }
}

class _ClassTotals {
  _ClassTotals({required this.firstLine});

  int methods = 0;
  int wmc = 0;
  final int firstLine;
  int lastLine = 0;
}
