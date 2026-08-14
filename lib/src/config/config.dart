/// Typed model of the `crap4dart.yaml` configuration file.
library;

part 'gate_configs.dart';
part 'threshold_entries.dart';

/// Severity of a gate violation.
///
/// `error` violations fail the run (exit code 2); `warning` violations
/// are reported but do not fail it.
enum GateSeverity {
  /// Violations fail the run.
  error,

  /// Violations are reported but do not fail the run.
  warning;

  /// Parses a config string ('error' or 'warning').
  static GateSeverity parse(String value) => switch (value) {
        'error' => GateSeverity.error,
        'warning' => GateSeverity.warning,
        _ => throw ArgumentError('unknown gate severity "$value"'),
      };
}

/// Root configuration of crap4dart.
class Crap4DartConfig {
  /// Creates a [Crap4DartConfig].
  const Crap4DartConfig({
    this.crap = const CrapConfig(),
    this.coverage = const CoverageConfig(),
    this.gates = const GatesConfig(),
    this.profile = const ProfileConfig(),
    this.sources = const ['lib', 'bin'],
    this.exclude = const [],
  });

  /// CRAP analysis settings.
  final CrapConfig crap;

  /// Coverage input settings.
  final CoverageConfig coverage;

  /// Quality gate settings.
  final GatesConfig gates;

  /// CPU profiling settings.
  final ProfileConfig profile;

  /// Directories scanned for Dart sources in the default (all-files) mode
  /// of `analyze` and `check`.
  final List<String> sources;

  /// Glob patterns excluded from analysis in every file selection mode
  /// (matched against project-relative paths).
  final List<String> exclude;

  /// The default configuration used when no config file is present.
  factory Crap4DartConfig.defaults() => const Crap4DartConfig();
}

/// Settings of the CRAP analysis itself.
class CrapConfig {
  /// Creates a [CrapConfig].
  const CrapConfig({
    this.enabled = true,
    this.threshold = 8.0,
    this.runTests = false,
    this.countLambdas = true,
  });

  /// Whether CRAP analysis is enabled.
  final bool enabled;

  /// Maximum allowed CRAP score.
  final double threshold;

  /// Whether to run the test suite to generate coverage before analyzing.
  final bool runTests;

  /// Whether branches inside lambdas count towards the enclosing method's
  /// cyclomatic complexity in CRAP analysis.
  final bool countLambdas;
}

/// Settings describing the coverage input.
class CoverageConfig {
  /// Creates a [CoverageConfig].
  const CoverageConfig({
    this.lcovPath = 'coverage/lcov.info',
    this.runTests = false,
    this.required = true,
    this.branchCoverage = true,
  });

  /// Path to the LCOV coverage file, relative to the project root.
  final String lcovPath;

  /// Whether to run the test suite to generate coverage before analyzing.
  final bool runTests;

  /// Whether missing coverage data is an error instead of N/A.
  final bool required;

  /// Whether branch coverage is reported in addition to line coverage.
  final bool branchCoverage;
}

/// Settings of all quality gates.
class GatesConfig {
  /// Creates a [GatesConfig].
  const GatesConfig({
    this.loc = const LocGateConfig(),
    this.testCoverage = const TestCoverageGateConfig(),
    this.complexity = const ComplexityGateConfig(),
    this.methodSize = const MethodSizeGateConfig(),
    this.nesting = const NestingGateConfig(),
    this.classSize = const ClassSizeGateConfig(),
    this.weightOfClass = const WeightOfClassGateConfig(),
    this.unusedCode = const UnusedCodeGateConfig(),
    this.unusedFiles = const UnusedFilesGateConfig(),
    this.bannedImports = const BannedImportsGateConfig(),
    this.publicDocs = const PublicDocsGateConfig(),
    this.duplication = const DuplicationGateConfig(),
    this.fileNaming = const FileNamingGateConfig(),
    this.flutter = const FlutterGatesConfig(),
  });

  /// File size gate (`loc`).
  final LocGateConfig loc;

  /// Minimum test coverage gate (`test_coverage`).
  final TestCoverageGateConfig testCoverage;

  /// Cyclomatic complexity gate (`complexity`).
  final ComplexityGateConfig complexity;

  /// Method size gate (`method_size`).
  final MethodSizeGateConfig methodSize;

  /// Maximum nesting level gate (`nesting`).
  final NestingGateConfig nesting;

  /// Class size gate (`class_size`).
  final ClassSizeGateConfig classSize;

  /// Weight of class gate (`weight_of_class`).
  final WeightOfClassGateConfig weightOfClass;

  /// Unused private code gate (`unused_code`).
  final UnusedCodeGateConfig unusedCode;

  /// Unused files gate (`unused_files`).
  final UnusedFilesGateConfig unusedFiles;

  /// Banned imports gate (`banned_imports`).
  final BannedImportsGateConfig bannedImports;

  /// Public API documentation gate (`public_docs`).
  final PublicDocsGateConfig publicDocs;

  /// Code duplication gate (`duplication`).
  final DuplicationGateConfig duplication;

  /// File naming gate (`file_naming`).
  final FileNamingGateConfig fileNaming;

  /// Flutter-specific gates grouped together.
  final FlutterGatesConfig flutter;

  /// Golden test coverage gate (`golden`).
  GoldenGateConfig get golden => flutter.golden;

  /// Hardcoded strings gate (`hardcoded_strings`).
  HardcodedStringsGateConfig get hardcodedStrings => flutter.hardcodedStrings;

  /// Accessibility gate (`accessibility`).
  AccessibilityGateConfig get accessibility => flutter.accessibility;
}

/// Flutter-specific quality gates.
class FlutterGatesConfig {
  /// Creates a [FlutterGatesConfig].
  const FlutterGatesConfig({
    this.golden = const GoldenGateConfig(),
    this.hardcodedStrings = const HardcodedStringsGateConfig(),
    this.accessibility = const AccessibilityGateConfig(),
  });

  /// Golden test coverage gate (`golden`).
  final GoldenGateConfig golden;

  /// Hardcoded strings gate (`hardcoded_strings`).
  final HardcodedStringsGateConfig hardcodedStrings;

  /// Accessibility gate (`accessibility`).
  final AccessibilityGateConfig accessibility;
}

/// CPU profiling settings (`profile` command).
class ProfileConfig {
  /// Creates a [ProfileConfig].
  const ProfileConfig({
    this.enabled = true,
    this.thresholdMs,
    this.top,
  });

  /// Whether profiling is enabled.
  final bool enabled;

  /// Warn on methods whose total time exceeds this value (milliseconds),
  /// or `null` to disable the threshold check.
  final double? thresholdMs;

  /// Maximum number of methods shown in the report (sorted by total time),
  /// or `null` to show all methods.
  final int? top;
}
