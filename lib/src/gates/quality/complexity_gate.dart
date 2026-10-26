import 'package:glob/glob.dart';

import '../../analysis/cognitive.dart';
import '../../analysis/complexity.dart';
import '../../analysis/method_extractor.dart';
import '../../config/config.dart';
import '../gate.dart';
import '../gate_context.dart';
import '../gate_ids.dart';

/// One `entries` rule: a path glob and the complexity limit it sets.
typedef _ComplexityEntry = ({Glob glob, int maxComplexity});

/// The `complexity` gate: fails methods whose complexity exceeds
/// `gates.complexity.max_complexity`. `gates.complexity.metric` selects
/// the metric — `cyclomatic` (default) or `cognitive` (SonarSource-style,
/// nesting-weighted). Per-path overrides may relax or tighten the
/// threshold via `entries`.
class ComplexityGate implements Gate {
  /// Creates a [ComplexityGate].
  const ComplexityGate();

  @override
  String get id => GateIds.complexity;

  @override
  Future<GateResult> run(GateContext context) async {
    final gateConfig = context.config.gates.complexity;
    final globs = [
      for (final entry in gateConfig.entries)
        for (final path in entry.paths)
          (glob: Glob(path), maxComplexity: entry.maxComplexity),
    ];
    const extractor = MethodExtractor();
    final MetricCalculator calculator = switch (gateConfig.metric) {
      ComplexityMetric.cyclomatic =>
        ComplexityCalculator(countLambdas: gateConfig.countLambdas),
      ComplexityMetric.cognitive =>
        CognitiveCalculator(countLambdas: gateConfig.countLambdas),
    };
    final violations = <GateViolation>[];
    var checked = 0;
    for (final file in context.files) {
      final relative = context.relativePath(file);
      final maxComplexity = _limitFor(
        relative,
        gateConfig.maxComplexity,
        globs,
      );
      final parsed = context.parsed(file);
      final methods = extractor.extractWithNodes(parsed.unit, parsed.lineInfo);
      checked += methods.length;
      violations.addAll(
        _violations(methods, calculator, relative, maxComplexity),
      );
    }
    final summary = violations.isEmpty
        ? '$checked methods within their ${gateConfig.metric.name} limit'
        : '${violations.length}/$checked methods over their '
            '${gateConfig.metric.name} limit';
    return violations.isEmpty
        ? GateResult.pass(id, summary: summary)
        : GateResult.fail(id, violations, summary: summary);
  }

  /// Complexity violations of [methods] over [maxComplexity].
  List<GateViolation> _violations(
    List<ExtractedMethod> methods,
    MetricCalculator calculator,
    String relative,
    int maxComplexity,
  ) {
    final violations = <GateViolation>[];
    for (final method in methods) {
      final complexity = calculator.compute(method.node);
      if (complexity <= maxComplexity) continue;
      final info = method.info;
      violations.add(
        GateViolation(
          file: relative,
          line: info.startLine,
          message: '${info.className}.${info.methodName} '
              '${calculator.metricName}=$complexity > max $maxComplexity',
        ),
      );
    }
    return violations;
  }

  /// The effective threshold for [relative]: the first matching entry,
  /// or [defaultMax].
  int _limitFor(
    String relative,
    int defaultMax,
    List<_ComplexityEntry> globs,
  ) {
    for (final entry in globs) {
      if (entry.glob.matches(relative)) return entry.maxComplexity;
    }
    return defaultMax;
  }
}
