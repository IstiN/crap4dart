part of 'config.dart';

/// A per-path threshold override of a numeric gate (`entries`).
class PathEntry {
  /// Creates a [PathEntry] over [paths] globs.
  const PathEntry({required this.paths});

  /// Glob patterns (project-relative) this entry applies to.
  final List<String> paths;
}

/// Per-path override of the `loc` gate threshold.
class LocPathEntry extends PathEntry {
  /// Creates a [LocPathEntry].
  const LocPathEntry({required this.maxLines, required super.paths});

  /// Maximum lines per file for the matching paths.
  final int maxLines;
}

/// Per-path override of the `complexity` gate threshold.
class ComplexityPathEntry extends PathEntry {
  /// Creates a [ComplexityPathEntry].
  const ComplexityPathEntry(
      {required this.maxComplexity, required super.paths});

  /// Maximum cyclomatic complexity for the matching paths.
  final int maxComplexity;
}

/// Per-path override of the `method_size` gate thresholds.
class MethodSizePathEntry extends PathEntry {
  /// Creates a [MethodSizePathEntry]; at least one threshold must be set.
  const MethodSizePathEntry(
      {this.maxLines, this.maxParams, required super.paths});

  /// Maximum lines per method body, or `null` to keep the gate default.
  final int? maxLines;

  /// Maximum parameters per method, or `null` to keep the gate default.
  final int? maxParams;
}
