import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../analysis/dart_parser.dart';
import '../config/config.dart';
import '../coverage/lcov_parser.dart';

/// Shared input for all quality gates: project root, config, target files,
/// optional coverage data and a memoized AST cache.
class GateContext {
  /// Creates a [GateContext].
  GateContext({
    required this.projectRoot,
    required this.config,
    required this.files,
    this.lcov,
  });

  /// Absolute path of the project root.
  final String projectRoot;

  /// The loaded crap4dart configuration.
  final Crap4DartConfig config;

  /// Dart files targeted by this run (mode: all / changed / staged).
  final List<String> files;

  /// Parsed LCOV coverage, or `null` when no coverage file was found.
  final List<FileCoverage>? lcov;

  final Map<String, ParsedUnit> _astCache = {};

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
  static bool isFlutterProjectAt(String root) {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    final doc = loadYaml(pubspec.readAsStringSync());
    if (doc is! YamlMap) return false;
    for (final section in const ['dependencies', 'dev_dependencies']) {
      final deps = doc[section];
      if (deps is YamlMap && deps.containsKey('flutter')) return true;
    }
    return false;
  }
}
