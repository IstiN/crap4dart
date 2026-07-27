import '../analysis/complexity.dart';
import '../analysis/method_extractor.dart';
import 'gate.dart';
import 'gate_context.dart';

/// The `complexity` gate: fails methods whose cyclomatic complexity
/// exceeds `gates.complexity.max_complexity`.
class ComplexityGate implements Gate {
  /// Creates a [ComplexityGate].
  const ComplexityGate();

  @override
  String get id => 'complexity';

  @override
  Future<GateResult> run(GateContext context) async {
    final gateConfig = context.config.gates.complexity;
    final maxComplexity = gateConfig.maxComplexity;
    const extractor = MethodExtractor();
    final calculator =
        ComplexityCalculator(countLambdas: gateConfig.countLambdas);
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      final parsed = context.parsed(file);
      for (final method
          in extractor.extractWithNodes(parsed.unit, parsed.lineInfo)) {
        checked++;
        final complexity = calculator.compute(method.node);
        if (complexity > maxComplexity) {
          final info = method.info;
          violations.add(
            GateViolation(
              file: context.relativePath(file),
              line: info.startLine,
              message: '${info.className}.${info.methodName} '
                  'CC=$complexity > max $maxComplexity',
            ),
          );
        }
      }
    }
    final summary = violations.isEmpty
        ? '$checked methods within CC $maxComplexity'
        : '${violations.length}/$checked methods over CC $maxComplexity';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }
}
