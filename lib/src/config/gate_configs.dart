part of 'config.dart';

// The per-gate config classes implement GateConfigFlags with plain
// fields; @override noise on identical flag triplets trips the
// project's own duplication gate.
// ignore_for_file: annotate_overrides

/// Default exclude globs for generated files, shared by gate defaults.

/// Default glob excluding test sources from generated-code gates.
const String kTestGlob = 'test/**';

/// File size gate settings (`loc`).
class LocGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Maximum lines per file.
  final int maxLines;

  /// Per-path threshold overrides; the first entry whose `paths` glob
  /// matches the file wins.
  final List<LocPathEntry> entries;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;

  /// Creates a [LocGateConfig].
  const LocGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.maxLines = 800,
    this.entries = const [],
    this.exclude = const [kGeneratedGlob, kFreezedGlob, kMocksGlob],
  });
}

/// Minimum test coverage gate settings (`test_coverage`).
class TestCoverageGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Minimum required coverage percent.
  final double minPercent;

  /// Whether the minimum applies per file instead of to the project total.
  final bool perFile;

  /// Directories whose files count towards the coverage aggregate
  /// (matched as LCOV path prefixes).
  final List<String> dirs;

  /// Creates a [TestCoverageGateConfig].
  const TestCoverageGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.minPercent = 80.0,
    this.perFile = false,
    this.dirs = const ['lib'],
  });
}

/// Golden test coverage gate settings (`golden`).
class GoldenGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Minimum percentage of widgets with a matching golden test.
  final double minWidgetCoverage;

  /// Directories scanned for widgets.
  final List<String> widgetDirs;

  /// Directories scanned for golden tests.
  final List<String> testDirs;

  /// Widget class names excluded from the gate.
  final List<String> excludeWidgets;

  /// Creates a [GoldenGateConfig].
  const GoldenGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.minWidgetCoverage = 80.0,
    this.widgetDirs = const ['lib'],
    this.testDirs = const [kTest],
    this.excludeWidgets = const [],
  });
}

/// Hardcoded strings gate settings (`hardcoded_strings`).
class HardcodedStringsGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Comment marker that suppresses the gate on a line.
  final String ignoreMarker;

  /// Widget parameter names that must not contain hardcoded strings.
  final List<String> checkParams;

  /// Creates a [HardcodedStringsGateConfig].
  const HardcodedStringsGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.ignoreMarker = 'l10n:ignore',
    this.checkParams = const ['labelText', 'hintText', 'helperText', 'tooltip'],
  });
}

/// Accessibility gate settings (`accessibility`).
class AccessibilityGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Widget types that must provide a semantics label.
  final List<String> requireLabelFor;

  /// Creates an [AccessibilityGateConfig].
  const AccessibilityGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.requireLabelFor = const [
      'IconButton',
      'Image',
      'GestureDetector',
      'InkWell',
    ],
  });
}

/// Cyclomatic complexity gate settings (`complexity`).
class ComplexityGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Maximum allowed complexity per method under [metric].
  final int maxComplexity;

  /// Which complexity metric `max_complexity` applies to.
  final ComplexityMetric metric;

  /// Per-path threshold overrides; the first entry whose `paths` glob
  /// matches the file wins.
  final List<ComplexityPathEntry> entries;

  /// Whether branches inside lambdas count towards the enclosing method's
  /// cyclomatic complexity in this gate.
  final bool countLambdas;

  /// Creates a [ComplexityGateConfig].
  const ComplexityGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.maxComplexity = 10,
    this.entries = const [],
    this.countLambdas = true,
    this.metric = ComplexityMetric.cyclomatic,
  });
}

/// Method size gate settings (`method_size`).
class MethodSizeGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Maximum lines per method body.
  final int maxLines;

  /// Maximum number of parameters per method.
  final int maxParams;

  /// Per-path threshold overrides; the first entry whose `paths` glob
  /// matches the file wins. Unset thresholds keep the gate defaults.
  final List<MethodSizePathEntry> entries;

  /// Creates a [MethodSizeGateConfig].
  const MethodSizeGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.maxLines = 60,
    this.maxParams = 6,
    this.entries = const [],
  });
}

/// Maximum nesting level gate settings (`nesting`).
class NestingGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Maximum number of nested blocks inside a method body.
  final int maxNesting;

  /// Creates a [NestingGateConfig].
  const NestingGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.maxNesting = 5,
  });
}

/// Record named fields gate settings (`record_named_fields`).
class RecordNamedFieldsGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Creates a [RecordNamedFieldsGateConfig].
  const RecordNamedFieldsGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.warning,
    this.ignorable = false,
  });
}

/// Inline record types gate settings (`inline_record_types`).
class InlineRecordTypesGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Creates an [InlineRecordTypesGateConfig].
  const InlineRecordTypesGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.warning,
    this.ignorable = false,
  });
}

/// Record size gate settings (`record_size`).
class RecordSizeGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Maximum number of fields (positional plus named) a record type
  /// may have before it should be transformed into a class.
  final int maxFields;

  /// Creates a [RecordSizeGateConfig].
  const RecordSizeGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.warning,
    this.ignorable = false,
    this.maxFields = 5,
  });
}

/// Class size gate settings (`class_size`).
class ClassSizeGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Maximum number of concrete methods per class.
  final int maxMethods;

  /// Maximum weighted methods per class (sum of cyclomatic complexities).
  final int maxWmc;

  /// Creates a [ClassSizeGateConfig].
  const ClassSizeGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.maxMethods = 25,
    this.maxWmc = 80,
  });
}

/// Weight of class gate settings (`weight_of_class`).
class WeightOfClassGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled (off by default: data/model classes are
  /// legitimate and would be noisy).
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Maximum allowed ratio of public fields to public members; classes
  /// revealing more data than behavior exceed it.
  final double maxWeight;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;

  /// Creates a [WeightOfClassGateConfig].
  const WeightOfClassGateConfig({
    this.enabled = false,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.maxWeight = 0.33,
    this.exclude = const [kGeneratedGlob, kFreezedGlob, kMocksGlob],
  });
}

/// One architectural rule of the `banned_imports` gate.
class BannedImportRule {
  /// Glob the importing file must match for the rule to apply.
  final String from;

  /// Globs matched against import URIs (and their project-relative
  /// resolved paths for relative/package imports).
  final List<String> forbid;

  /// Optional explanation appended to violations.
  final String? message;

  /// Creates a [BannedImportRule].
  const BannedImportRule({
    required this.from,
    required this.forbid,
    this.message,
  });
}

/// Banned imports gate settings (`banned_imports`).
class BannedImportsGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled. With no rules the gate always passes.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Architectural rules; each maps a source glob to forbidden imports.
  final List<BannedImportRule> rules;

  /// Creates a [BannedImportsGateConfig].
  const BannedImportsGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.rules = const [],
  });
}

/// Unused private code gate settings (`unused_code`).
class UnusedCodeGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Glob patterns excluded from the gate (declarations and references in
  /// excluded files are ignored entirely).
  final List<String> exclude;

  /// Creates an [UnusedCodeGateConfig].
  const UnusedCodeGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.exclude = const [
      kGeneratedGlob,
      kFreezedGlob,
      kMocksGlob,
      'bin/**',
    ],
  });
}

/// Unused files gate settings (`unused_files`).
class UnusedFilesGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Directories scanned for unused files. Files containing a `main()`
  /// and `part of` files are never reported.
  final List<String> dirs;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;

  /// Creates an [UnusedFilesGateConfig].
  const UnusedFilesGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.dirs = const ['lib'],
    this.exclude = const [
      kGeneratedGlob,
      kFreezedGlob,
      kMocksGlob,
    ],
  });
}

/// Broken goldens gate settings (`broken_goldens`).
class BrokenGoldensGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Directories recursively scanned for golden PNG files.
  final List<String> dirs;

  /// Minimum number of alternating yellow/black pixels that counts as
  /// an overflow stripe pattern.
  final int minStripeRun;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;

  /// Creates a [BrokenGoldensGateConfig].
  const BrokenGoldensGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.dirs = const [kTest],
    this.minStripeRun = 8,
    this.exclude = const [],
  });
}

/// Test assertions gate settings (`test_assertions`).
class TestAssertionsGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Minimum number of assertion calls a `test()`/`testWidgets()` body
  /// must contain.
  final int minAssertions;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;

  /// Creates a [TestAssertionsGateConfig].
  const TestAssertionsGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.minAssertions = 1,
    this.exclude = const [],
  });
}

/// Folder structure gate settings (`folder_structure`).
class FolderStructureGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Directories checked for loose-file sprawl — literal paths or
  /// glob patterns (`lib/src/*`, `packages/**`) expanding to every
  /// matching directory. Ignored when `config` is present.
  final List<String> dirs;

  /// Maximum number of logical `.dart` units allowed directly in
  /// each listed directory before the sprawl is flagged. Generated
  /// siblings of one source file (`foo.dart`, `foo.g.dart`) are one
  /// unit; files in subdirectories never count — a directory's own
  /// tidiness is judged on its own contents. Ignored when `config`
  /// is present.
  final int maxLooseFiles;

  /// Per-pattern caps — the `config` key
  /// (`{lib/src: 3, 'lib/src/**': 30}`). When present it takes
  /// precedence: each matching directory is checked against its
  /// pattern's cap (a directory matched by several patterns uses the
  /// first pattern's), and [dirs]/[maxLooseFiles] are not consulted.
  /// Empty — the default — means the classic list form applies.
  final Map<String, int> caps;

  /// Glob patterns excluded from the gate — matching files don't
  /// count.
  final List<String> exclude;

  /// Creates a [FolderStructureGateConfig].
  const FolderStructureGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.dirs = const ['lib'],
    this.maxLooseFiles = 0,
    this.caps = const {},
    this.exclude = const [],
  });
}

/// Magic constants gate settings (`magic_constants`).
class MagicConstantsGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Whether hardcoded hex color literals (`0xAARRGGBB`, `0xRRGGBB`)
  /// outside named constant declarations are flagged.
  final bool flagHexColors;

  /// How many times the same numeric or string literal must repeat in
  /// a file before every occurrence is flagged.
  final int minDuplicates;

  /// Minimum length of a string literal to be considered for the
  /// duplicate check.
  final int minLength;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;

  /// Creates a [MagicConstantsGateConfig].
  const MagicConstantsGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.flagHexColors = true,
    this.minDuplicates = 3,
    this.minLength = 4,
    this.exclude = const [
      kGeneratedGlob,
      kFreezedGlob,
      kMocksGlob,
      kTestGlob,
    ],
  });
}

/// Common shape of the two scattered-literal gate configs
/// (`scattered_constants`, `scattered_fragments`); `_readCommon`
/// builds it and the subclass `withBase` constructors consume it.

/// One external-tool rule of the `external` gate.
class ExternalToolRule {
  /// Rule id used in violations (`external.<id>` in the output).
  final String id;

  /// Executable to run (resolved on PATH).
  final String executable;

  /// Arguments passed to the executable. The placeholder `{report}` is
  /// replaced with the temporary report path when [reportPath] is set.
  final List<String> arguments;

  /// Path of the Checkstyle XML report to parse after the run. When
  /// `null`, `{report}` defaults to a temp file appended to
  /// [arguments] is not used and the tool's own configured output
  /// location is read.
  final String? reportPath;

  /// Creates an [ExternalToolRule].
  const ExternalToolRule({
    required this.id,
    required this.executable,
    required this.arguments,
    this.reportPath,
  });
}

/// External tools gate settings (`external`).
class ExternalGateConfig implements GateConfigFlags {
  /// Whether the gate is enabled. With no rules the gate passes.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// External tools to run; each produces a Checkstyle XML report.
  final List<ExternalToolRule> rules;

  /// Creates an [ExternalGateConfig].
  const ExternalGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.rules = const [],
  });
}
