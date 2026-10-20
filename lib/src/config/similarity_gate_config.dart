// part-file of config.dart — reuses its imports
part of 'config.dart';

// The per-gate config classes implement GateConfigFlags with plain
// fields; @override noise on identical flag triplets trips the
// project's own duplication gate.
// ignore_for_file: annotate_overrides

/// Similarity gate settings (`similarity`): file-level near-duplicate
/// detection over any text corpus (markdown docs, source files).
///
/// Opt-in (disabled by default): corpora differ wildly, so a project
/// first runs `crap4dart similarity` ad hoc, tunes the thresholds, then
/// enables the gate — typically with a baseline capturing the current
/// state so only *new* near-duplicates fail the run.
class SimilarityGateConfig implements GateConfigFlags {
  /// Creates a [SimilarityGateConfig].
  const SimilarityGateConfig({
    this.enabled = false,
    this.severity = GateSeverity.error,
    this.ignorable = false,
    this.dirs = const ['.'],
    this.include = const ['**/*.md'],
    this.minShingles = 50,
    this.jaccard = 0.8,
    this.containment = 0.95,
    this.exclude = const [
      '.git/**',
      '.dart_tool/**',
      'build/**',
      'coverage/**',
      'node_modules/**',
    ],
  });

  /// Whether the gate is enabled.
  final bool enabled;

  /// Whether violations fail the run or are reported as warnings.
  final GateSeverity severity;

  /// Whether `// crap:ignore` comments may suppress violations of this
  /// gate. Disabled by default — suppression must be opted into.
  final bool ignorable;

  /// Directories recursively scanned for text files.
  final List<String> dirs;

  /// Glob patterns of files to analyze (project-relative paths).
  final List<String> include;

  /// Files with fewer shingles than this are skipped — tiny files
  /// carry no reliable similarity signal.
  final int minShingles;

  /// The Jaccard threshold: pairs at or above it are reported.
  final double jaccard;

  /// The containment threshold: pairs at or above it are reported even
  /// when Jaccard is low (a small file largely copied into a big one).
  final double containment;

  /// Glob patterns excluded from the gate.
  final List<String> exclude;
}
