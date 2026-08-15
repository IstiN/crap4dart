part of 'config.dart';

/// Default exclude globs for generated files, shared by gate defaults.
const String _generatedGlob = '**.g.dart';
const String _freezedGlob = '**.freezed.dart';
const String _mocksGlob = '**.mocks.dart';

/// Default glob excluding test sources from generated-code gates.
const String _testGlob = 'test/**';

/// File size gate settings (`loc`).
class LocGateConfig {
  /// Creates a [LocGateConfig].
  const LocGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.maxLines = 800,
    this.entries = const [],
    this.exclude = const [_generatedGlob, _freezedGlob, _mocksGlob],
  });

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
}

/// Minimum test coverage gate settings (`test_coverage`).
class TestCoverageGateConfig {
  /// Creates a [TestCoverageGateConfig].
  const TestCoverageGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.minPercent = 80.0,
    this.perFile = false,
    this.dirs = const ['lib'],
  });

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
}

/// Golden test coverage gate settings (`golden`).
class GoldenGateConfig {
  /// Creates a [GoldenGateConfig].
  const GoldenGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.minWidgetCoverage = 80.0,
    this.widgetDirs = const ['lib'],
    this.testDirs = const ['test'],
    this.excludeWidgets = const [],
  });

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
}

/// Hardcoded strings gate settings (`hardcoded_strings`).
class HardcodedStringsGateConfig {
  /// Creates a [HardcodedStringsGateConfig].
  const HardcodedStringsGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.ignoreMarker = 'l10n:ignore',
    this.checkParams = const ['labelText', 'hintText', 'helperText', 'tooltip'],
  });

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
}

/// Accessibility gate settings (`accessibility`).
class AccessibilityGateConfig {
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

  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Widget types that must provide a semantics label.
  final List<String> requireLabelFor;
}

/// Cyclomatic complexity gate settings (`complexity`).
class ComplexityGateConfig {
  /// Creates a [ComplexityGateConfig].
  const ComplexityGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.maxComplexity = 10,
    this.entries = const [],
    this.countLambdas = true,
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Maximum allowed cyclomatic complexity per method.
  final int maxComplexity;

  /// Per-path threshold overrides; the first entry whose `paths` glob
  /// matches the file wins.
  final List<ComplexityPathEntry> entries;

  /// Whether branches inside lambdas count towards the enclosing method's
  /// cyclomatic complexity in this gate.
  final bool countLambdas;
}

/// Method size gate settings (`method_size`).
class MethodSizeGateConfig {
  /// Creates a [MethodSizeGateConfig].
  const MethodSizeGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.maxLines = 60,
    this.maxParams = 6,
    this.entries = const [],
  });

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
}

/// Maximum nesting level gate settings (`nesting`).
class NestingGateConfig {
  /// Creates a [NestingGateConfig].
  const NestingGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.maxNesting = 5,
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Maximum number of nested blocks inside a method body.
  final int maxNesting;
}

/// Class size gate settings (`class_size`).
class ClassSizeGateConfig {
  /// Creates a [ClassSizeGateConfig].
  const ClassSizeGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.maxMethods = 25,
    this.maxWmc = 80,
  });

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
}

/// Weight of class gate settings (`weight_of_class`).
class WeightOfClassGateConfig {
  /// Creates a [WeightOfClassGateConfig].
  const WeightOfClassGateConfig({
    this.enabled = false,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.maxWeight = 0.33,
    this.exclude = const [_generatedGlob, _freezedGlob, _mocksGlob],
  });

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
}

/// One architectural rule of the `banned_imports` gate.
class BannedImportRule {
  /// Creates a [BannedImportRule].
  const BannedImportRule({
    required this.from,
    required this.forbid,
    this.message,
  });

  /// Glob the importing file must match for the rule to apply.
  final String from;

  /// Globs matched against import URIs (and their project-relative
  /// resolved paths for relative/package imports).
  final List<String> forbid;

  /// Optional explanation appended to violations.
  final String? message;
}

/// Banned imports gate settings (`banned_imports`).
class BannedImportsGateConfig {
  /// Creates a [BannedImportsGateConfig].
  const BannedImportsGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.rules = const [],
  });

  /// Whether the gate is enabled. With no rules the gate always passes.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Architectural rules; each maps a source glob to forbidden imports.
  final List<BannedImportRule> rules;
}

/// Unused private code gate settings (`unused_code`).
class UnusedCodeGateConfig {
  /// Creates an [UnusedCodeGateConfig].
  const UnusedCodeGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.exclude = const [
      _generatedGlob,
      _freezedGlob,
      _mocksGlob,
      'bin/**',
    ],
  });

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
}

/// Unused files gate settings (`unused_files`).
class UnusedFilesGateConfig {
  /// Creates an [UnusedFilesGateConfig].
  const UnusedFilesGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.dirs = const ['lib'],
    this.exclude = const [
      _generatedGlob,
      _freezedGlob,
      _mocksGlob,
    ],
  });

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
}

/// Magic constants gate settings (`magic_constants`).
class MagicConstantsGateConfig {
  /// Creates a [MagicConstantsGateConfig].
  const MagicConstantsGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.flagHexColors = true,
    this.minDuplicates = 3,
    this.minLength = 4,
    this.exclude = const [
      _generatedGlob,
      _freezedGlob,
      _mocksGlob,
      _testGlob,
    ],
  });

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
}

/// File naming gate settings (`file_naming`).
class FileNamingGateConfig {
  /// Creates a [FileNamingGateConfig].
  const FileNamingGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.exclude = const [
      _generatedGlob,
      _freezedGlob,
      _mocksGlob,
      _testGlob,
    ],
    this.allow = defaultAllowedStems,
  });

  /// Stems (file names without the `.dart` extension) accepted despite
  /// ending in digits — technical terms where the digits carry meaning.
  static const List<String> defaultAllowedStems = [
    'aes128',
    'aes192',
    'aes256',
    'arm32',
    'arm64',
    'base32',
    'base64',
    'crc8',
    'crc16',
    'crc32',
    'f16',
    'f32',
    'f64',
    'h264',
    'h265',
    'http2',
    'http3',
    'i18n',
    'i2c',
    'int8',
    'int16',
    'int32',
    'int64',
    'ipv4',
    'ipv6',
    'l10n',
    'a11y',
    'md5',
    'oauth1',
    'oauth2',
    'sha1',
    'sha256',
    'sha384',
    'sha512',
    'uint8',
    'uint16',
    'uint32',
    'uint64',
    'utf8',
    'utf16',
    'utf32',
    'w3c',
    'webgl2',
    'x509',
    'x86',
    'x64',
  ];

  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;

  /// Extra file name stems (without extension) allowed to end in digits,
  /// matched case-insensitively against the whole stem.
  final List<String> allow;
}

/// Public API documentation gate settings (`public_docs`).
class PublicDocsGateConfig {
  /// Creates a [PublicDocsGateConfig].
  const PublicDocsGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.exclude = const [_testGlob],
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;
}

/// Code duplication gate settings (`duplication`).
class DuplicationGateConfig {
  /// Creates a [DuplicationGateConfig].
  const DuplicationGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.threshold = 1.0,
    this.minTokens = 50,
    this.minLines = 5,
    this.exclude = const [
      _generatedGlob,
      _freezedGlob,
      _mocksGlob,
      _testGlob,
    ],
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Maximum allowed duplicated line percentage per file.
  final double threshold;

  /// Minimum number of tokens in a block to be considered for duplication.
  final int minTokens;

  /// Minimum number of lines in a block to be considered for duplication.
  final int minLines;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;
}
