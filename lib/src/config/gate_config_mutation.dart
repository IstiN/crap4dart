part of 'config.dart';

/// Operator categories of the `mutation` gate, in stable order. The
/// `gates.mutation.operators` key accepts any subset of these names;
/// anything else is a strict config error.
const List<String> mutationOperatorCategories = [
  'arithmetic',
  'boundary',
  'equality',
  'logical',
  'boolean',
  'constant',
  'unary',
];

/// Performance knobs of the `mutation` gate.
class MutationExecution {
  /// Creates a [MutationExecution].
  const MutationExecution({
    this.timeoutSeconds = 60,
    this.maxMutants = 500,
    this.cache = true,
    this.testArgs = const ['test'],
  });

  /// Per-mutant timeout in seconds; a timed-out mutant counts as
  /// survived (the suite did not kill it deterministically).
  final int timeoutSeconds;

  /// Performance safety cap: at most this many covered sites are
  /// executed, chosen deterministically by file order and offset.
  final int maxMutants;

  /// Digest-incremental cache: killed mutants of unchanged methods are
  /// replayed from `.crap-mutation-cache.json` instead of re-executed.
  final bool cache;

  /// Full argument list of the per-mutant test invocation
  /// (`dart <testArgs...>` / `flutter <testArgs...>`); defaults to
  /// `['test']`. Scoping the suite is the consumer's responsibility: a
  /// mutant is killed only if the scoped suite would kill it.
  final List<String> testArgs;
}

/// Mutation testing gate settings (`mutation`).
class MutationGateConfig {
  /// Creates a [MutationGateConfig].
  const MutationGateConfig({
    this.enabled = false,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.minScore = 0.8,
    this.maxSurvivors = 0,
    this.execution = const MutationExecution(),
    this.operators = mutationOperatorCategories,
    this.exclude = const [
      _generatedGlob,
      _freezedGlob,
      _mocksGlob,
      _testGlob,
    ],
  });

  /// Whether the gate is enabled (off by default: mutation testing runs
  /// the project's test suite once per mutant, which is expensive).
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Minimum required mutation score: killed / (killed + survived);
  /// uncovered sites are excluded from the denominator.
  final double minScore;

  /// Maximum number of survived mutants tolerated even when the score
  /// meets [minScore] (each surviving mutant is a missing assertion).
  final int maxSurvivors;

  /// Per-mutant timeout and the executed-mutant cap.
  final MutationExecution execution;

  /// Enabled operator categories (subset of `arithmetic`, `boundary`,
  /// `equality`, `logical`, `boolean`, `constant`, `unary`); all
  /// categories are enabled by default.
  final List<String> operators;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;
}
