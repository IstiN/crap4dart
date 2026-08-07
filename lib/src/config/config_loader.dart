import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'config.dart';

/// Error raised for malformed or invalid `crap4dart.yaml` content.
class ConfigException implements Exception {
  /// Creates a [ConfigException].
  const ConfigException(this.path, this.key, this.message);

  /// Path of the config file that failed to load.
  final String path;

  /// The offending key (dot-separated for nested keys).
  final String key;

  /// Human readable description of the problem.
  final String message;

  @override
  String toString() => 'Invalid config "$path": $key: $message';
}

/// Loads `crap4dart.yaml` with strict validation and per-key defaults.
class ConfigLoader {
  /// Creates a [ConfigLoader].
  const ConfigLoader();

  /// Default config file name looked up in the project root.
  static const String configFileName = 'crap4dart.yaml';

  /// Known gate identifiers under the `gates` key.
  static const Set<String> knownGates = {
    'loc',
    'test_coverage',
    'golden',
    'hardcoded_strings',
    'accessibility',
    'complexity',
    'method_size',
    'public_docs',
    'duplication',
  };

  /// Loads the configuration for the project at [projectRoot].
  ///
  /// When [configPath] is given, that file is loaded and must exist.
  /// Otherwise `<projectRoot>/crap4dart.yaml` is used when present; a
  /// missing file is not an error and yields [Crap4DartConfig.defaults].
  ///
  /// Throws a [ConfigException] on unknown keys or wrongly typed values.
  Crap4DartConfig load(String projectRoot, {String? configPath}) {
    final path = configPath ?? p.join(projectRoot, configFileName);
    final file = File(path);
    if (!file.existsSync()) {
      if (configPath != null) {
        throw ConfigException(path, path, 'config file not found');
      }
      return Crap4DartConfig.defaults();
    }
    return loadString(file.readAsStringSync(), path: path);
  }

  /// Parses and validates config [content] (used with [path] in errors).
  Crap4DartConfig loadString(String content, {String path = configFileName}) {
    final Object? doc;
    try {
      doc = loadYaml(content);
    } on YamlException catch (e) {
      throw ConfigException(path, path, 'invalid YAML: ${e.message}');
    }
    if (doc == null) return Crap4DartConfig.defaults();
    final root = _asMap(doc, path, '(root)');
    _checkKeys(
      root,
      const {'crap', 'coverage', 'gates', 'sources', 'exclude'},
      path,
      '',
    );
    final defaults = Crap4DartConfig.defaults();
    return Crap4DartConfig(
      crap: _readCrap(root['crap'], defaults.crap, path),
      coverage: _readCoverage(root['coverage'], defaults.coverage, path),
      gates: _readGates(root['gates'], defaults.gates, path),
      sources: _readSources(root['sources'], defaults.sources, path),
      exclude: _strList(root, 'exclude', defaults.exclude, path, ''),
    );
  }

  List<String> _readSources(Object? node, List<String> base, String path) {
    if (node == null) return base;
    if (node is! YamlList) {
      throw ConfigException(path, 'sources', 'expected a list of strings');
    }
    final sources = <String>[];
    for (final entry in node.nodes) {
      final value = entry is YamlScalar ? entry.value : null;
      if (value is! String || value.isEmpty) {
        throw ConfigException(
          path,
          'sources',
          'expected a list of non-empty strings',
        );
      }
      sources.add(value);
    }
    return sources;
  }

  CrapConfig _readCrap(Object? node, CrapConfig base, String path) {
    if (node == null) return base;
    final map = _asMap(node, path, 'crap');
    _checkKeys(
      map,
      const {'enabled', 'threshold', 'run_tests', 'count_lambdas'},
      path,
      'crap',
    );
    return CrapConfig(
      enabled: _bool(map, 'enabled', base.enabled, path, 'crap'),
      threshold: _num(map, 'threshold', base.threshold, path, 'crap'),
      runTests: _bool(map, 'run_tests', base.runTests, path, 'crap'),
      countLambdas:
          _bool(map, 'count_lambdas', base.countLambdas, path, 'crap'),
    );
  }

  CoverageConfig _readCoverage(Object? node, CoverageConfig base, String path) {
    if (node == null) return base;
    final map = _asMap(node, path, 'coverage');
    _checkKeys(
      map,
      const {'lcov_path', 'run_tests', 'required', 'branch_coverage'},
      path,
      'coverage',
    );
    return CoverageConfig(
      lcovPath: _str(map, 'lcov_path', base.lcovPath, path, 'coverage'),
      runTests: _bool(map, 'run_tests', base.runTests, path, 'coverage'),
      required: _bool(map, 'required', base.required, path, 'coverage'),
      branchCoverage:
          _bool(map, 'branch_coverage', base.branchCoverage, path, 'coverage'),
    );
  }

  GatesConfig _readGates(Object? node, GatesConfig base, String path) {
    if (node == null) return base;
    final map = _asMap(node, path, 'gates');
    for (final key in map.keys) {
      if (!knownGates.contains(key)) {
        throw ConfigException(path, 'gates.$key', 'unknown gate id');
      }
    }
    return GatesConfig(
      loc: _readLoc(map['loc'], base.loc, path),
      testCoverage: _readTestCoverage(
        map['test_coverage'],
        base.testCoverage,
        path,
      ),
      complexity: _readComplexity(map['complexity'], base.complexity, path),
      methodSize: _readMethodSize(map['method_size'], base.methodSize, path),
      publicDocs: _readPublicDocs(map['public_docs'], base.publicDocs, path),
      duplication: _readDuplication(map['duplication'], base.duplication, path),
      flutter: FlutterGatesConfig(
        golden: _readGolden(map['golden'], base.flutter.golden, path),
        hardcodedStrings: _readHardcodedStrings(
          map['hardcoded_strings'],
          base.flutter.hardcodedStrings,
          path,
        ),
        accessibility: _readAccessibility(
            map['accessibility'], base.flutter.accessibility, path),
      ),
    );
  }

  LocGateConfig _readLoc(Object? node, LocGateConfig base, String path) {
    return _readGateConfig(
      node,
      base,
      path,
      'gates.loc',
      const {'enabled', 'max_lines', 'exclude'},
      (map, base, path, ctx) => LocGateConfig(
        enabled: _bool(map, 'enabled', base.enabled, path, ctx),
        maxLines: _int(map, 'max_lines', base.maxLines, path, ctx),
        exclude: _strList(map, 'exclude', base.exclude, path, ctx),
      ),
    );
  }

  TestCoverageGateConfig _readTestCoverage(
    Object? node,
    TestCoverageGateConfig base,
    String path,
  ) {
    return _readGateConfig(
      node,
      base,
      path,
      'gates.test_coverage',
      const {'enabled', 'min_percent', 'per_file', 'dirs'},
      (map, base, path, ctx) => TestCoverageGateConfig(
        enabled: _bool(map, 'enabled', base.enabled, path, ctx),
        minPercent: _num(map, 'min_percent', base.minPercent, path, ctx),
        perFile: _bool(map, 'per_file', base.perFile, path, ctx),
        dirs: _strList(map, 'dirs', base.dirs, path, ctx),
      ),
    );
  }

  GoldenGateConfig _readGolden(
    Object? node,
    GoldenGateConfig base,
    String path,
  ) {
    return _readGateConfig(
      node,
      base,
      path,
      'gates.golden',
      const {
        'enabled',
        'min_widget_coverage',
        'widget_dirs',
        'test_dirs',
        'exclude_widgets',
      },
      (map, base, path, ctx) => GoldenGateConfig(
        enabled: _bool(map, 'enabled', base.enabled, path, ctx),
        minWidgetCoverage:
            _num(map, 'min_widget_coverage', base.minWidgetCoverage, path, ctx),
        widgetDirs: _strList(map, 'widget_dirs', base.widgetDirs, path, ctx),
        testDirs: _strList(map, 'test_dirs', base.testDirs, path, ctx),
        excludeWidgets:
            _strList(map, 'exclude_widgets', base.excludeWidgets, path, ctx),
      ),
    );
  }

  HardcodedStringsGateConfig _readHardcodedStrings(
    Object? node,
    HardcodedStringsGateConfig base,
    String path,
  ) {
    return _readGateConfig(
      node,
      base,
      path,
      'gates.hardcoded_strings',
      const {'enabled', 'ignore_marker', 'check_params'},
      (map, base, path, ctx) => HardcodedStringsGateConfig(
        enabled: _bool(map, 'enabled', base.enabled, path, ctx),
        ignoreMarker: _str(map, 'ignore_marker', base.ignoreMarker, path, ctx),
        checkParams: _strList(map, 'check_params', base.checkParams, path, ctx),
      ),
    );
  }

  AccessibilityGateConfig _readAccessibility(
    Object? node,
    AccessibilityGateConfig base,
    String path,
  ) {
    return _readGateConfig(
      node,
      base,
      path,
      'gates.accessibility',
      const {'enabled', 'require_label_for'},
      (map, base, path, ctx) => AccessibilityGateConfig(
        enabled: _bool(map, 'enabled', base.enabled, path, ctx),
        requireLabelFor:
            _strList(map, 'require_label_for', base.requireLabelFor, path, ctx),
      ),
    );
  }

  ComplexityGateConfig _readComplexity(
    Object? node,
    ComplexityGateConfig base,
    String path,
  ) {
    return _readGateConfig(
      node,
      base,
      path,
      'gates.complexity',
      const {'enabled', 'max_complexity', 'count_lambdas'},
      (map, base, path, ctx) => ComplexityGateConfig(
        enabled: _bool(map, 'enabled', base.enabled, path, ctx),
        maxComplexity:
            _int(map, 'max_complexity', base.maxComplexity, path, ctx),
        countLambdas: _bool(map, 'count_lambdas', base.countLambdas, path, ctx),
      ),
    );
  }

  MethodSizeGateConfig _readMethodSize(
    Object? node,
    MethodSizeGateConfig base,
    String path,
  ) {
    return _readGateConfig(
      node,
      base,
      path,
      'gates.method_size',
      const {'enabled', 'max_lines', 'max_params'},
      (map, base, path, ctx) => MethodSizeGateConfig(
        enabled: _bool(map, 'enabled', base.enabled, path, ctx),
        maxLines: _int(map, 'max_lines', base.maxLines, path, ctx),
        maxParams: _int(map, 'max_params', base.maxParams, path, ctx),
      ),
    );
  }

  PublicDocsGateConfig _readPublicDocs(
    Object? node,
    PublicDocsGateConfig base,
    String path,
  ) {
    return _readGateConfig(
      node,
      base,
      path,
      'gates.public_docs',
      const {'enabled', 'exclude'},
      (map, base, path, ctx) => PublicDocsGateConfig(
        enabled: _bool(map, 'enabled', base.enabled, path, ctx),
        exclude: _strList(map, 'exclude', base.exclude, path, ctx),
      ),
    );
  }

  DuplicationGateConfig _readDuplication(
    Object? node,
    DuplicationGateConfig base,
    String path,
  ) {
    return _readGateConfig(
      node,
      base,
      path,
      'gates.duplication',
      const {'enabled', 'threshold', 'min_tokens', 'min_lines', 'exclude'},
      (map, base, path, ctx) => DuplicationGateConfig(
        enabled: _bool(map, 'enabled', base.enabled, path, ctx),
        threshold: _num(map, 'threshold', base.threshold, path, ctx),
        minTokens: _int(map, 'min_tokens', base.minTokens, path, ctx),
        minLines: _int(map, 'min_lines', base.minLines, path, ctx),
        exclude: _strList(map, 'exclude', base.exclude, path, ctx),
      ),
    );
  }

  T _readGateConfig<T>(
    Object? node,
    T base,
    String path,
    String ctx,
    Set<String> knownKeys,
    T Function(YamlMap map, T base, String path, String ctx) build,
  ) {
    if (node == null) return base;
    final map = _asMap(node, path, ctx);
    _checkKeys(map, knownKeys, path, ctx);
    return build(map, base, path, ctx);
  }

  YamlMap _asMap(Object? node, String path, String key) {
    if (node is YamlMap) return node;
    throw ConfigException(path, key, 'expected a map');
  }

  void _checkKeys(
    YamlMap map,
    Set<String> known,
    String path,
    String context,
  ) {
    for (final key in map.keys) {
      if (!known.contains(key)) {
        final full = context.isEmpty ? '$key' : '$context.$key';
        throw ConfigException(path, full, 'unknown key');
      }
    }
  }

  bool _bool(YamlMap map, String key, bool base, String path, String ctx) {
    final value = map[key];
    if (value == null) return base;
    if (value is bool) return value;
    throw ConfigException(path, '$ctx.$key', 'expected a boolean');
  }

  double _num(YamlMap map, String key, double base, String path, String ctx) {
    final value = map[key];
    if (value == null) return base;
    if (value is num) return value.toDouble();
    throw ConfigException(path, '$ctx.$key', 'expected a number');
  }

  int _int(YamlMap map, String key, int base, String path, String ctx) {
    final value = map[key];
    if (value == null) return base;
    if (value is int) return value;
    throw ConfigException(path, '$ctx.$key', 'expected an integer');
  }

  String _str(YamlMap map, String key, String base, String path, String ctx) {
    final value = map[key];
    if (value == null) return base;
    if (value is String) return value;
    throw ConfigException(path, '$ctx.$key', 'expected a string');
  }

  List<String> _strList(
    YamlMap map,
    String key,
    List<String> base,
    String path,
    String ctx,
  ) {
    final value = map[key];
    if (value == null) return base;
    if (value is YamlList &&
        value.nodes.every((n) => n is YamlScalar && n.value is String)) {
      return [for (final n in value.nodes) (n as YamlScalar).value as String];
    }
    throw ConfigException(
      path,
      ctx.isEmpty ? key : '$ctx.$key',
      'expected a list of strings',
    );
  }
}
