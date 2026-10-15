part of 'config.dart';

// The per-gate config classes implement GateConfigFlags with plain
// fields; @override noise on identical flag triplets trips the
// project's own duplication gate.
// ignore_for_file: annotate_overrides

/// File naming gate settings (`file_naming`).
class FileNamingGateConfig implements GateConfigFlags {
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
class PublicDocsGateConfig implements GateConfigFlags {
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

/// Matching knobs of the `duplication` gate: block granularity and the
/// Type-2 clone normalizations.
class DuplicationMatching {
  /// Creates a [DuplicationMatching].
  const DuplicationMatching({
    this.minTokens = 50,
    this.minLines = 5,
    this.ignoreLocals = false,
    this.ignoreLiterals = false,
  });

  /// Minimum number of tokens in a block to be considered for duplication.
  final int minTokens;

  /// Minimum number of lines in a block to be considered for duplication.
  final int minLines;

  /// Whether locally declared identifiers (parameters, local variables,
  /// loop and catch variables, type parameters, local functions, pattern
  /// variables) are consistently renamed before hashing, enabling
  /// detection of renamed (Type-2) clones. Interpolated strings become
  /// opaque under this mode. Off by default.
  final bool ignoreLocals;

  /// Whether string and numeric literals are replaced with type
  /// placeholders before hashing, so clones differing only in literal
  /// values are detected. Off by default.
  final bool ignoreLiterals;
}

/// Code duplication gate settings (`duplication`).
class DuplicationGateConfig implements GateConfigFlags {
  /// Creates a [DuplicationGateConfig].
  const DuplicationGateConfig({
    this.enabled = true,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.threshold = 1.0,
    this.matching = const DuplicationMatching(),
    this.exclude = const [
      _generatedGlob,
      _freezedGlob,
      _mocksGlob,
      _testGlob,
    ],
    this.sources = const [],
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

  /// Block granularity and Type-2 clone normalizations.
  final DuplicationMatching matching;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;

  /// Additional file/directory paths scanned for duplication, resolved
  /// against the project root and unioned with the analyzed source set:
  /// this is what makes cross-module duplication detectable. Directories
  /// are scanned recursively, `.dart` files are taken directly, missing
  /// paths are skipped.
  final List<String> sources;
}
