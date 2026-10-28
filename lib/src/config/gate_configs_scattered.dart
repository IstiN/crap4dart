part of 'config.dart';

/// The default `exclude` list shared by the scattered-literal gates.
const List<String> _scatteredExcludeDefaults = [
  kGeneratedGlob,
  kFreezedGlob,
  kMocksGlob,
  kTestGlob,
];

/// Config of the `scattered_constants` gate.
class ScatteredGateConfig implements GateConfigFlags {
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

  /// Literal values never flagged — whole-literal hits by value,
  /// segment hits by head (numbers match their decimal form). Generic
  /// vocabulary whose extraction adds churn without benefit (`test`,
  /// `dart`, `flutter`, ...) lives here.
  final List<String> ignore;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;

  /// Whether pure value aliases — `const _x = kY;` declarations whose
  /// initializer is another constant's identifier — are flagged. A
  /// private alias adds a name without information; reference the
  /// shared constant directly. Public declarations are exempt:
  /// re-export shims are a deliberate API shape.
  final bool flagAliases;

  /// Creates a [ScatteredGateConfig].
  const ScatteredGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.warning,
    this.ignorable = false,
    this.minFiles = 3,
    this.minLength = 4,
    this.minValue = 100,
    this.ignore = const [],
    this.exclude = _scatteredExcludeDefaults,
    this.flagAliases = true,
  });
}
