part of 'config.dart';

/// A per-path threshold override of a numeric gate (`entries`).
class PathEntry {
  /// Glob patterns (project-relative) this entry applies to.
  final List<String> paths;

  /// Creates a [PathEntry] over [paths] globs.
  const PathEntry({required this.paths});
}

/// Per-path override of the `loc` gate threshold.
class LocPathEntry extends PathEntry {
  /// Maximum lines per file for the matching paths.
  final int maxLines;

  /// Creates a [LocPathEntry].
  const LocPathEntry({required this.maxLines, required super.paths});
}

/// Per-path override of the `complexity` gate threshold.
class ComplexityPathEntry extends PathEntry {
  /// Maximum cyclomatic complexity for the matching paths.
  final int maxComplexity;

  /// Creates a [ComplexityPathEntry].
  const ComplexityPathEntry(
      {required this.maxComplexity, required super.paths});
}

/// Per-path override of the `method_size` gate thresholds.
class MethodSizePathEntry extends PathEntry {
  /// Maximum lines per method body, or `null` to keep the gate default.
  final int? maxLines;

  /// Maximum parameters per method, or `null` to keep the gate default.
  final int? maxParams;

  /// Creates a [MethodSizePathEntry]; at least one threshold must be set.
  const MethodSizePathEntry(
      {this.maxLines, this.maxParams, required super.paths});
}
