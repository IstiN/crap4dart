import '../common/constants.dart';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../gates/gate_ids.dart';
import 'config.dart';

part 'config_scalars.dart';
part 'gate_config_readers.dart';
part 'gate_config_readers_extra.dart';

/// Top-level and section keys of `crap4dart.yaml`.
const String _crapKey = 'crap';
const String _sourcesKey = 'sources';
const String _runTestsKey = 'run_tests';
const String _thresholdMsKey = 'threshold_ms';

/// Error raised for malformed or invalid `crap4dart.yaml` content.
class ConfigException implements Exception {
  /// Path of the config file that failed to load.
  final String path;

  /// The offending key (dot-separated for nested keys).
  final String key;

  /// Human readable description of the problem.
  final String message;

  /// Creates a [ConfigException].
  const ConfigException(this.path, this.key, this.message);

  @override
  String toString() => 'Invalid config "$path": $key: $message';
}

/// Loads `crap4dart.yaml` with strict validation and per-key defaults.
class ConfigLoader {
  /// Default config file name looked up in the project root.
  static const String configFileName = 'crap4dart.yaml';

  /// Known gate identifiers under the `gates` key.
  static const Set<String> knownGates = {...GateIds.all};

  /// Creates a [ConfigLoader].
  const ConfigLoader();

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
    final root = _ConfigScalars.asMap(doc, path, '(root)');
    _ConfigScalars.checkKeys(
      root,
      const {_crapKey, kCoverage, kGatePrefix, kProfile, _sourcesKey, kExclude},
      path,
      '',
    );
    final defaults = Crap4DartConfig.defaults();
    return Crap4DartConfig(
      crap: _readCrap(root[_crapKey], defaults.crap, path),
      coverage: _readCoverage(root[kCoverage], defaults.coverage, path),
      gates: _readGates(root[kGatePrefix], defaults.gates, path),
      profile: _readProfile(root[kProfile], defaults.profile, path),
      sources: _readSources(root[_sourcesKey], defaults.sources, path),
      exclude: _ConfigScalars.strList(
        root,
        kExclude,
        defaults.exclude,
        path,
        '',
      ),
    );
  }

  List<String> _readSources(Object? node, List<String> base, String path) {
    if (node == null) return base;
    if (node is! YamlList) {
      throw ConfigException(path, _sourcesKey, 'expected a list of strings');
    }
    final sources = <String>[];
    for (final entry in node.nodes) {
      final value = entry is YamlScalar ? entry.value : null;
      if (value is! String || value.isEmpty) {
        throw ConfigException(
          path,
          _sourcesKey,
          'expected a list of non-empty strings',
        );
      }
      sources.add(value);
    }
    return sources;
  }

  CrapConfig _readCrap(Object? node, CrapConfig base, String path) {
    if (node == null) return base;
    final map = _ConfigScalars.asMap(node, path, _crapKey);
    _ConfigScalars.checkKeys(
      map,
      const {_enabledKey, kThreshold, _runTestsKey, 'count_lambdas'},
      path,
      _crapKey,
    );
    return CrapConfig(
      enabled: _ConfigScalars.readBool(
          map, _enabledKey, base.enabled, path, _crapKey),
      threshold: _ConfigScalars.readNum(
          map, kThreshold, base.threshold, path, _crapKey),
      runTests: _ConfigScalars.readBool(
          map, _runTestsKey, base.runTests, path, _crapKey),
      countLambdas: _ConfigScalars.readBool(
          map, 'count_lambdas', base.countLambdas, path, _crapKey),
    );
  }

  CoverageConfig _readCoverage(Object? node, CoverageConfig base, String path) {
    if (node == null) return base;
    final map = _ConfigScalars.asMap(node, path, kCoverage);
    _ConfigScalars.checkKeys(
      map,
      const {'lcov_path', _runTestsKey, 'required', 'branch_coverage'},
      path,
      kCoverage,
    );
    return CoverageConfig(
      lcovPath:
          _ConfigScalars.str(map, 'lcov_path', base.lcovPath, path, kCoverage),
      runTests: _ConfigScalars.readBool(
          map, _runTestsKey, base.runTests, path, kCoverage),
      required: _ConfigScalars.readBool(
          map, 'required', base.required, path, kCoverage),
      branchCoverage: _ConfigScalars.readBool(
          map, 'branch_coverage', base.branchCoverage, path, kCoverage),
    );
  }

  ProfileConfig _readProfile(Object? node, ProfileConfig base, String path) {
    if (node == null) return base;
    final map = _ConfigScalars.asMap(node, path, kProfile);
    _ConfigScalars.checkKeys(
      map,
      const {_enabledKey, _thresholdMsKey, 'top'},
      path,
      kProfile,
    );
    final thresholdValue = map[_thresholdMsKey];
    double? thresholdMs;
    if (thresholdValue != null) {
      thresholdMs = _ConfigScalars.readNum(
        map,
        _thresholdMsKey,
        base.thresholdMs ?? 0,
        path,
        kProfile,
      );
    }
    final topRaw = map['top'];
    return ProfileConfig(
      enabled: _ConfigScalars.readBool(
          map, _enabledKey, base.enabled, path, kProfile),
      thresholdMs: thresholdMs,
      top: topRaw == null
          ? null
          : _ConfigScalars.readInt(map, 'top', base.top ?? 20, path, kProfile),
    );
  }

  GatesConfig _readGates(Object? node, GatesConfig base, String path) {
    if (node == null) return base;
    final map = _ConfigScalars.asMap(node, path, kGatePrefix);
    for (final key in map.keys) {
      if (!knownGates.contains(key)) {
        throw ConfigException(path, '$kGatePrefix.$key', 'unknown gate id');
      }
    }
    return GatesConfig(
      loc: _GateConfigReaders.readLoc(map[GateIds.loc], base.loc, path),
      testCoverage: _GateConfigReaders.readTestCoverage(
        map[GateIds.testCoverage],
        base.testCoverage,
        path,
      ),
      complexity: _GateConfigReaders.readComplexity(
          map[GateIds.complexity], base.complexity, path),
      methodSize: _GateConfigReaders.readMethodSize(
          map[GateIds.methodSize], base.methodSize, path),
      nesting: _GateConfigReaders.readNesting(
          map[GateIds.nesting], base.nesting, path),
      recordNamedFields: _ExtendedGateConfigReaders.readRecordNamedFields(
          map[GateIds.recordNamedFields], base.recordNamedFields, path),
      inlineRecordTypes: _ExtendedGateConfigReaders.readInlineRecordTypes(
          map[GateIds.inlineRecordTypes], base.inlineRecordTypes, path),
      recordSize: _ExtendedGateConfigReaders.readRecordSize(
          map[GateIds.recordSize], base.recordSize, path),
      classSize: _GateConfigReaders.readClassSize(
          map[GateIds.classSize], base.classSize, path),
      weightOfClass: _GateConfigReaders.readWeightOfClass(
        map[GateIds.weightOfClass],
        base.weightOfClass,
        path,
      ),
      unusedCode: _GateConfigReaders.readUnusedCode(
          map[GateIds.unusedCode], base.unusedCode, path),
      unusedFiles: _GateConfigReaders.readUnusedFiles(
          map[GateIds.unusedFiles], base.unusedFiles, path),
      bannedImports: _GateConfigReaders.readBannedImports(
        map[GateIds.bannedImports],
        base.bannedImports,
        path,
      ),
      publicDocs: _GateConfigReaders.readPublicDocs(
          map[GateIds.publicDocs], base.publicDocs, path),
      duplication: _GateConfigReaders.readDuplication(
          map[GateIds.duplication], base.duplication, path),
      fileNaming: _GateConfigReaders.readFileNaming(
          map[GateIds.fileNaming], base.fileNaming, path),
      magicConstants: _GateConfigReaders.readMagicConstants(
          map[GateIds.magicConstants], base.magicConstants, path),
      scatteredConstants: _ExtendedGateConfigReaders.readScatteredConstants(
          map[GateIds.scatteredConstants], base.scatteredConstants, path),
      brokenGoldens: _ExtendedGateConfigReaders.readBrokenGoldens(
          map[GateIds.brokenGoldens], base.brokenGoldens, path),
      testAssertions: _ExtendedGateConfigReaders.readTestAssertions(
          map[GateIds.testAssertions], base.testAssertions, path),
      folderStructure: _ExtendedGateConfigReaders.readFolderStructure(
          map[GateIds.folderStructure], base.folderStructure, path),
      external: _ExtendedGateConfigReaders.readExternal(
          map[GateIds.external], base.external, path),
      mutation: _ExtendedGateConfigReaders.readMutation(
          map[GateIds.mutation], base.mutation, path),
      similarity: _ExtendedGateConfigReaders.readSimilarity(
          map[GateIds.similarity], base.similarity, path),
      stringHazards: _GateConfigReaders.readStringHazards(
          map[GateIds.stringHazards], base.stringHazards, path),
      flutter: FlutterGatesConfig(
        golden: _GateConfigReaders.readGolden(
            map[GateIds.golden], base.flutter.golden, path),
        hardcodedStrings: _GateConfigReaders.readHardcodedStrings(
          map[GateIds.hardcodedStrings],
          base.flutter.hardcodedStrings,
          path,
        ),
        accessibility: _GateConfigReaders.readAccessibility(
            map[GateIds.accessibility], base.flutter.accessibility, path),
      ),
    );
  }
}
