/// Typed model of the `crap4dart.yaml` configuration file.
library;

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
    this.publicDocs = const PublicDocsGateConfig(),
    this.duplication = const DuplicationGateConfig(),
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

  /// Public API documentation gate (`public_docs`).
  final PublicDocsGateConfig publicDocs;

  /// Code duplication gate (`duplication`).
  final DuplicationGateConfig duplication;

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

/// Code duplication gate settings (`duplication`).
class DuplicationGateConfig {
  /// Creates a [DuplicationGateConfig].
  const DuplicationGateConfig({
    this.enabled = true,
    this.threshold = 1.0,
    this.minTokens = 50,
    this.minLines = 5,
    this.exclude = const [
      '**.g.dart',
      '**.freezed.dart',
      '**.mocks.dart',
      'test/**',
    ],
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Maximum allowed duplicated line percentage per file.
  final double threshold;

  /// Minimum number of tokens in a block to be considered for duplication.
  final int minTokens;

  /// Minimum number of lines in a block to be considered for duplication.
  final int minLines;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;
}

/// File size gate settings (`loc`).
class LocGateConfig {
  /// Creates a [LocGateConfig].
  const LocGateConfig({
    this.enabled = true,
    this.maxLines = 800,
    this.exclude = const ['**.g.dart', '**.freezed.dart', '**.mocks.dart'],
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Maximum lines per file.
  final int maxLines;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;
}

/// Minimum test coverage gate settings (`test_coverage`).
class TestCoverageGateConfig {
  /// Creates a [TestCoverageGateConfig].
  const TestCoverageGateConfig({
    this.enabled = true,
    this.minPercent = 80.0,
    this.perFile = false,
    this.dirs = const ['lib'],
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Minimum required coverage percent.
  final double minPercent;

  /// Whether the minimum applies per file instead of to the project total.
  final bool perFile;

  /// Directories whose files count towards the coverage aggregate
  /// (matched as LCOV path prefixes).
  final List<String> dirs;
}

/// Golden test coverage gate settings (`golden`).
class GoldenGateConfig {
  /// Creates a [GoldenGateConfig].
  const GoldenGateConfig({
    this.enabled = true,
    this.minWidgetCoverage = 80.0,
    this.widgetDirs = const ['lib'],
    this.testDirs = const ['test'],
    this.excludeWidgets = const [],
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Minimum percentage of widgets with a matching golden test.
  final double minWidgetCoverage;

  /// Directories scanned for widgets.
  final List<String> widgetDirs;

  /// Directories scanned for golden tests.
  final List<String> testDirs;

  /// Widget class names excluded from the gate.
  final List<String> excludeWidgets;
}

/// Hardcoded strings gate settings (`hardcoded_strings`).
class HardcodedStringsGateConfig {
  /// Creates a [HardcodedStringsGateConfig].
  const HardcodedStringsGateConfig({
    this.enabled = true,
    this.ignoreMarker = 'l10n:ignore',
    this.checkParams = const ['labelText', 'hintText', 'helperText', 'tooltip'],
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Comment marker that suppresses the gate on a line.
  final String ignoreMarker;

  /// Widget parameter names that must not contain hardcoded strings.
  final List<String> checkParams;
}

/// Accessibility gate settings (`accessibility`).
class AccessibilityGateConfig {
  /// Creates an [AccessibilityGateConfig].
  const AccessibilityGateConfig({
    this.enabled = true,
    this.requireLabelFor = const [
      'IconButton',
      'Image',
      'GestureDetector',
      'InkWell',
    ],
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Widget types that must provide a semantics label.
  final List<String> requireLabelFor;
}

/// Cyclomatic complexity gate settings (`complexity`).
class ComplexityGateConfig {
  /// Creates a [ComplexityGateConfig].
  const ComplexityGateConfig({
    this.enabled = true,
    this.maxComplexity = 10,
    this.countLambdas = true,
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Maximum allowed cyclomatic complexity per method.
  final int maxComplexity;

  /// Whether branches inside lambdas count towards the enclosing method's
  /// cyclomatic complexity in this gate.
  final bool countLambdas;
}

/// Method size gate settings (`method_size`).
class MethodSizeGateConfig {
  /// Creates a [MethodSizeGateConfig].
  const MethodSizeGateConfig({
    this.enabled = true,
    this.maxLines = 60,
    this.maxParams = 6,
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Maximum lines per method body.
  final int maxLines;

  /// Maximum number of parameters per method.
  final int maxParams;
}

/// Public API documentation gate settings (`public_docs`).
class PublicDocsGateConfig {
  /// Creates a [PublicDocsGateConfig].
  const PublicDocsGateConfig({
    this.enabled = true,
    this.exclude = const ['test/**'],
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;
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
