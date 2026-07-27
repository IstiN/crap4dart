import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// Finds Dart source files to analyze.
class SourceFinder {
  /// Creates a [SourceFinder].
  const SourceFinder();

  /// Glob patterns excluded from default source discovery.
  static const List<String> defaultExcludes = [
    '**.g.dart',
    '**.freezed.dart',
    '**.mocks.dart',
    '.dart_tool/**',
  ];

  /// Directories scanned when no explicit paths are given. Only existing
  /// directories are scanned.
  static const List<String> defaultRoots = ['lib', 'bin'];

  /// Returns all `.dart` files under [roots] (default: [defaultRoots]) of
  /// [rootDir], excluding [defaultExcludes]. Non-existing roots are
  /// silently skipped.
  List<String> findDefaultSources(
    String rootDir, {
    List<String> roots = defaultRoots,
  }) {
    final result = <String>{};
    for (final root in roots) {
      final dir = Directory(p.join(rootDir, root));
      if (!dir.existsSync()) continue;
      result.addAll(_findUnder(dir.path));
    }
    final sorted = result.toList()..sort();
    return sorted;
  }

  /// Expands explicit [paths]: files are taken directly, directories are
  /// scanned recursively for `.dart` files (excluding [defaultExcludes]).
  ///
  /// Returns a sorted, de-duplicated list. Throws a [FileSystemException]
  /// for paths that do not exist.
  List<String> expandPaths(List<String> paths) {
    final result = <String>{};
    for (final path in paths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.file) {
        if (path.endsWith('.dart') && !isExcluded(p.normalize(path))) {
          result.add(path);
        }
      } else if (type == FileSystemEntityType.directory) {
        result.addAll(_findUnder(path));
      } else {
        throw FileSystemException('No such file or directory', path);
      }
    }
    final sorted = result.toList()..sort();
    return sorted;
  }

  /// Whether [path] matches any of the [defaultExcludes] patterns.
  static bool isExcluded(String path) {
    final segments = p.split(path);
    if (segments.contains('.dart_tool')) return true;
    final baseName = p.basename(path);
    return baseName.endsWith('.g.dart') ||
        baseName.endsWith('.freezed.dart') ||
        baseName.endsWith('.mocks.dart');
  }

  /// Filters out [files] matching any of [patterns]: glob patterns matched
  /// against the path relative to [rootDir] (absolute paths are
  /// relativized first).
  List<String> filterByGlobs(
    String rootDir,
    List<String> files,
    List<String> patterns,
  ) {
    if (patterns.isEmpty) return files;
    final globs = [for (final pattern in patterns) Glob(pattern)];
    return [
      for (final file in files)
        if (!globs.any((g) => g.matches(_relative(rootDir, file)))) file,
    ];
  }

  String _relative(String rootDir, String path) =>
      p.isAbsolute(path) ? p.relative(path, from: rootDir) : path;

  List<String> _findUnder(String dir) => [
        for (final entity in Directory(dir).listSync(recursive: true))
          if (entity is File &&
              entity.path.endsWith('.dart') &&
              !isExcluded(p.normalize(entity.path)))
            entity.path,
      ];
}
