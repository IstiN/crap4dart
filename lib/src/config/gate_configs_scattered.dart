part of 'config.dart';

/// The default `exclude` list shared by the scattered-literal gates.
const List<String> _scatteredExcludeDefaults = [
  _generatedGlob,
  _freezedGlob,
  _mocksGlob,
  _testGlob,
];

/// Config for both scattered-literal gates (`scattered_constants`,
/// `scattered_fragments`): one shape, two independent yaml sections.
///
/// `scattered_constants` reads `min_value` and `scattered_fragments`
/// reads `separators`; a key a section does not list is an
/// unknown-key error — the readers own the yaml surface, the class
/// merely carries both scalars.
class ScatteredGateConfig implements GateConfigFlags {
  /// Creates a [ScatteredGateConfig].
  const ScatteredGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.warning,
    this.ignorable = false,
    this.minFiles = 3,
    this.minLength = 4,
    this.minValue = 100,
    this.separators = '.',
    this.ignore = const [],
    this.exclude = _scatteredExcludeDefaults,
  });

  /// Whether the gate is enabled.
  @override
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  @override
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  @override
  final bool ignorable;

  /// Minimum number of distinct files a literal (or fragment) must
  /// appear in before occurrences are flagged.
  final int minFiles;

  /// Minimum length of a string literal (or fragment) to be
  /// considered.
  final int minLength;

  /// Numbers with magnitude at or below this value are treated as
  /// coincidence and never flagged (whole-value gate).
  final int minValue;

  /// Characters splitting string literals into candidate fragments
  /// (fragments gate).
  final String separators;

  /// Literal values never flagged — whole-literal hits by value,
  /// segment hits by head (numbers match their decimal form). Generic
  /// vocabulary whose extraction adds churn without benefit (`test`,
  /// `dart`, `flutter`, ...) lives here.
  final List<String> ignore;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;
}
