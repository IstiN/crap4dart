import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../analysis/dart_parser.dart';
import '../config/config.dart';
import '../coverage/lcov_parser.dart';
import '../files/flutter_project.dart' as files_flutter;

/// Shared input for all quality gates: project root, config, target files,
/// optional coverage data and a memoized AST cache.
class GateContext {
  /// Creates a [GateContext].
  GateContext({
    required this.projectRoot,
    required this.config,
    required this.files,
    this.lcov,
    this.partialSelection = false,
  });

  /// Absolute path of the project root.
  final String projectRoot;

  /// The loaded crap4dart configuration.
  final Crap4DartConfig config;

  /// Dart files targeted by this run (mode: all / changed / staged).
  final List<String> files;

  /// Parsed LCOV coverage, or `null` when no coverage file was found.
  final List<FileCoverage>? lcov;

  /// Whether [files] is a partial selection (`--changed`, `--staged` or
  /// `--diff`) rather than the full source set. Whole-project gates
  /// (unused_code, unused_files) skip themselves in partial runs: their
  /// verdicts need every file's imports and references.
  final bool partialSelection;

  final Map<String, ParsedUnit> _astCache = {};
  final Map<String, List<String>> _linesCache = {};
  String? _packageName;

  /// The `name:` of the project's pubspec.yaml, or `null` when absent.
  String? get packageName => _packageName ??= _readPackageName(
        p.join(projectRoot, 'pubspec.yaml'),
      );

  String? _readPackageName(String pubspecPath) {
    try {
      final content = File(pubspecPath).readAsStringSync();
      final match = RegExp(
        r'^name:\s*(.+)$',
        multiLine: true,
      ).firstMatch(content);
      return match?.group(1)?.trim();
    } on FileSystemException {
      return null;
    }
  }

  /// The lines of the file at [path], read and cached on first access;
  /// empty for unreadable files.
  List<String> _lines(String path) => _linesCache.putIfAbsent(path, () {
        try {
          return File(path).readAsStringSync().split('\n');
        } on FileSystemException {
          return const [];
        }
      });

  /// 1-based [lineNumber] of the file at [path], or `null` when out of
  /// range or the file is unreadable.
  String? line(String path, int lineNumber) {
    final lines = _lines(path);
    if (lines.isEmpty) return null;
    return lineNumber >= 1 && lineNumber <= lines.length
        ? lines[lineNumber - 1]
        : null;
  }

  /// Whether the file at [path] has at least [lineNumber] lines.
  bool hasLine(String path, int lineNumber) => line(path, lineNumber) != null;

  /// Returns the parsed AST of the Dart file at [path], parsing and caching
  /// it on first access. AST gates share this cache because parsing is
  /// expensive.
  ParsedUnit parsed(String path) => _astCache.putIfAbsent(
        path,
        () => DartParser().parse(
          content: File(path).readAsStringSync(),
          path: path,
        ),
      );

  /// [path] made relative to [projectRoot] when possible.
  String relativePath(String path) =>
      p.isAbsolute(path) ? p.relative(path, from: projectRoot) : path;

  /// Whether the project is a Flutter project (its pubspec depends on the
  /// `flutter` package).
  bool get isFlutterProject => isFlutterProjectAt(projectRoot);

  /// Whether any of [patterns] (globs) matches [path], which is first made
  /// relative to [projectRoot].
  bool matchesAnyGlob(String path, List<String> patterns) {
    final relative = relativePath(path);
    return patterns.any((pattern) => Glob(pattern).matches(relative));
  }

  /// Whether the pubspec at [root] declares a `flutter` dependency.
  static bool isFlutterProjectAt(String root) =>
      files_flutter.isFlutterProject(root);
}
