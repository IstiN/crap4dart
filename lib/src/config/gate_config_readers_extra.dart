part of 'config_loader.dart';

const String _externalCtx = '$kGatePrefix.${GateIds.external}';

/// Readers for the newer gates (broken_goldens, test_assertions,
/// folder_structure) — split out of [_GateConfigReaders] to keep both
/// classes under the class_size method limit.
class _ExtendedGateConfigReaders {
  static BrokenGoldensGateConfig readBrokenGoldens(
    Object? node,
    BrokenGoldensGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      '$kGatePrefix.${GateIds.brokenGoldens}',
      const {
        _enabledKey,
        _severityKey,
        _ignorableKey,
        _dirsKey,
        'min_stripe_run',
        _excludeKey
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return BrokenGoldensGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          dirs: _ConfigScalars.strList(map, _dirsKey, base.dirs, path, ctx),
          minStripeRun: _ConfigScalars.readInt(
              map, 'min_stripe_run', base.minStripeRun, path, ctx),
          exclude:
              _ConfigScalars.strList(map, _excludeKey, base.exclude, path, ctx),
        );
      },
    );
  }

  static SimilarityGateConfig readSimilarity(
    Object? node,
    SimilarityGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      '$kGatePrefix.${GateIds.similarity}',
      const {
        _enabledKey,
        _severityKey,
        _ignorableKey,
        _dirsKey,
        kInclude,
        'min_shingles',
        kJaccard,
        kContainment,
        kExclude
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return SimilarityGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          dirs: _ConfigScalars.strList(map, _dirsKey, base.dirs, path, ctx),
          include:
              _ConfigScalars.strList(map, kInclude, base.include, path, ctx),
          minShingles: _ConfigScalars.readInt(
              map, 'min_shingles', base.minShingles, path, ctx),
          jaccard:
              _ConfigScalars.readNum(map, kJaccard, base.jaccard, path, ctx),
          containment: _ConfigScalars.readNum(
              map, kContainment, base.containment, path, ctx),
          exclude:
              _ConfigScalars.strList(map, _excludeKey, base.exclude, path, ctx),
        );
      },
    );
  }

  static TestAssertionsGateConfig readTestAssertions(
    Object? node,
    TestAssertionsGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      '$kGatePrefix.${GateIds.testAssertions}',
      const {
        _enabledKey,
        _severityKey,
        _ignorableKey,
        'min_assertions',
        _excludeKey
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return TestAssertionsGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          minAssertions: _ConfigScalars.readInt(
              map, 'min_assertions', base.minAssertions, path, ctx),
          exclude:
              _ConfigScalars.strList(map, _excludeKey, base.exclude, path, ctx),
        );
      },
    );
  }

  /// Validates the `config` map: pattern keys, integer caps.
  static Map<String, int> _capsOf(YamlMap node, String path) {
    final caps = <String, int>{};
    for (final entry in node.entries) {
      final pattern = entry.key;
      final cap = entry.value;
      if (pattern is! String) {
        throw ConfigException(path, 'gates.folder_structure.dirs',
            'expected pattern keys as strings');
      }
      if (cap is! int) {
        throw ConfigException(path, 'gates.folder_structure.dirs',
            "expected an integer cap for '\$pattern'");
      }
      caps[pattern] = cap;
    }
    return caps;
  }

  static FolderStructureGateConfig readFolderStructure(
    Object? node,
    FolderStructureGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      '$kGatePrefix.${GateIds.folderStructure}',
      const {
        _enabledKey,
        _severityKey,
        _ignorableKey,
        _dirsKey,
        'max_loose_files',
        kConfig,
        _excludeKey
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        if (map[kConfig] != null) {
          // The per-pattern caps take precedence: dirs and
          // max_loose_files are not consulted.
          return FolderStructureGateConfig(
            enabled: flags.enabled,
            severity: flags.severity,
            ignorable: flags.ignorable,
            caps: _capsOf(map[kConfig], path),
            exclude: _ConfigScalars.strList(
                map, _excludeKey, base.exclude, path, ctx),
          );
        }
        return FolderStructureGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          dirs: _ConfigScalars.strList(map, _dirsKey, base.dirs, path, ctx),
          maxLooseFiles: _ConfigScalars.readInt(
              map, 'max_loose_files', base.maxLooseFiles, path, ctx),
          exclude:
              _ConfigScalars.strList(map, _excludeKey, base.exclude, path, ctx),
        );
      },
    );
  }

  static MutationGateConfig readMutation(
    Object? node,
    MutationGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      '$kGatePrefix.${GateIds.mutation}',
      const {
        _enabledKey,
        _severityKey,
        _ignorableKey,
        'min_score',
        'max_survivors',
        'timeout_seconds',
        'max_mutants',
        'operators',
        'cache',
        'test_args',
        'scope_tests',
        _excludeKey,
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        final operators =
            _ConfigScalars.strList(map, 'operators', base.operators, path, ctx);
        for (final operator in operators) {
          if (!mutationOperatorCategories.contains(operator)) {
            throw ConfigException(
              path,
              '$ctx.operators',
              'unknown operator category "$operator"',
            );
          }
        }
        return MutationGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          minScore: _ConfigScalars.readNum(
              map, 'min_score', base.minScore, path, ctx),
          maxSurvivors: _ConfigScalars.readInt(
              map, 'max_survivors', base.maxSurvivors, path, ctx),
          operators: operators,
          execution: MutationExecution(
            timeoutSeconds: _ConfigScalars.readInt(map, 'timeout_seconds',
                base.execution.timeoutSeconds, path, ctx),
            maxMutants: _ConfigScalars.readInt(
                map, 'max_mutants', base.execution.maxMutants, path, ctx),
            cache: _ConfigScalars.readBool(
                map, 'cache', base.execution.cache, path, ctx),
            testArgs: _testArgs(map, base, path, ctx),
            testScope: _ConfigScalars.readBool(
                map, 'scope_tests', base.execution.testScope, path, ctx),
          ),
          exclude:
              _ConfigScalars.strList(map, _excludeKey, base.exclude, path, ctx),
        );
      },
    );
  }

  /// Reads `test_args`: a non-empty list of non-empty strings.
  static List<String> _testArgs(
    YamlMap map,
    MutationGateConfig base,
    String path,
    String ctx,
  ) {
    final args = _ConfigScalars.strList(
        map, 'test_args', base.execution.testArgs, path, ctx);
    if (args.isEmpty) {
      throw ConfigException(path, '$ctx.test_args', 'must not be empty');
    }
    for (final arg in args) {
      if (arg.isEmpty) {
        throw ConfigException(
          path,
          '$ctx.test_args',
          'arguments must be non-empty strings',
        );
      }
    }
    return args;
  }

  static ExternalGateConfig readExternal(
    Object? node,
    ExternalGateConfig base,
    String path,
  ) {
    if (node == null) return base;
    final map = _ConfigScalars.asMap(node, path, _externalCtx);
    _ConfigScalars.checkKeys(
      map,
      const {_enabledKey, _severityKey, _ignorableKey, 'rules'},
      path,
      _externalCtx,
    );
    final flags = _ConfigScalars.gateFlags(map, base, path, _externalCtx);
    return ExternalGateConfig(
      enabled: flags.enabled,
      severity: flags.severity,
      ignorable: flags.ignorable,
      rules: _readExternalRules(map['rules'], path),
    );
  }

  static List<ExternalToolRule> _readExternalRules(Object? node, String path) {
    if (node == null) return const [];
    if (node is! YamlList) {
      throw ConfigException(
        path,
        '$kGatePrefix.${GateIds.external}.rules',
        'expected a list of rules',
      );
    }
    return [
      for (final n in node.nodes) _readExternalRule(n, path),
    ];
  }

  /// Parses one `gates.external.rules` entry.
  static ExternalToolRule _readExternalRule(Object? n, String path) {
    const ctx = '$kGatePrefix.${GateIds.external}.rules';
    if (n is! YamlMap) {
      throw ConfigException(path, ctx, 'expected rule maps');
    }
    _ConfigScalars.checkKeys(
        n, const {'id', 'executable', 'arguments', 'report'}, path, ctx);
    final id = _requiredString(n, 'id', ctx, path);
    final executable = _requiredString(n, 'executable', ctx, path);
    final arguments =
        _ConfigScalars.strList(n, 'arguments', const [], path, ctx);
    final report = n['report'];
    if (report != null && report is! String) {
      throw ConfigException(path, '$ctx.report', _expectedStringMsg);
    }
    return ExternalToolRule(
      id: id,
      executable: executable,
      arguments: arguments,
      reportPath: report as String?,
    );
  }

  /// A required non-empty string entry field.
  static String _requiredString(
    YamlMap map,
    String key,
    String ctx,
    String path,
  ) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
    throw ConfigException(path, '$ctx.$key', 'expected a non-empty string');
  }

  /// YAML keys shared by the two scattered-literal readers.
  static const _minFilesKey = 'min_files';
  static const _minValueKey = 'min_value';

  static ScatteredGateConfig readScatteredConstants(
    Object? node,
    ScatteredGateConfig base,
    String path,
  ) {
    return _readScatteredGate(
        node, base, path, GateIds.scatteredConstants, const {
      _enabledKey,
      _severityKey,
      _ignorableKey,
      _minFilesKey,
      _minLengthKey,
      _minValueKey,
      'ignore',
      _excludeKey
    });
  }

  /// The shared body of the two scattered-literal readers: one config
  /// class, two yaml key surfaces.
  static ScatteredGateConfig _readScatteredGate(
    Object? node,
    ScatteredGateConfig base,
    String path,
    String ctx,
    Set<String> keys,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      ctx,
      keys,
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return ScatteredGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          minFiles: _ConfigScalars.readInt(
              map, _minFilesKey, base.minFiles, path, ctx),
          minLength: _ConfigScalars.readInt(
              map, _minLengthKey, base.minLength, path, ctx),
          minValue: _ConfigScalars.readInt(
              map, _minValueKey, base.minValue, path, ctx),
          ignore: _readIgnoreValues(map['ignore'], base.ignore, path),
          exclude:
              _ConfigScalars.strList(map, _excludeKey, base.exclude, path, ctx),
        );
      },
    );
  }

  static List<String> _readIgnoreValues(
    Object? node,
    List<String> base,
    String path,
  ) {
    if (node == null) return base;
    const ctx = 'gates.scattered_constants.ignore';
    if (node is! YamlList) {
      throw ConfigException(path, ctx, 'expected a list of values');
    }
    final values = <String>[];
    for (final n in node.nodes) {
      final value = n is YamlScalar ? n.value : null;
      if (value is String) {
        values.add(value);
      } else if (value is int) {
        values.add('$value');
      } else {
        throw ConfigException(path, ctx, 'expected strings or integers');
      }
    }
    return values;
  }

  static RecordNamedFieldsGateConfig readRecordNamedFields(
    Object? node,
    RecordNamedFieldsGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      '$kGatePrefix.${GateIds.recordNamedFields}',
      const {_enabledKey, _severityKey, _ignorableKey},
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return RecordNamedFieldsGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
        );
      },
    );
  }

  static InlineRecordTypesGateConfig readInlineRecordTypes(
    Object? node,
    InlineRecordTypesGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      '$kGatePrefix.${GateIds.inlineRecordTypes}',
      const {_enabledKey, _severityKey, _ignorableKey},
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return InlineRecordTypesGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
        );
      },
    );
  }

  static RecordSizeGateConfig readRecordSize(
    Object? node,
    RecordSizeGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      '$kGatePrefix.${GateIds.recordSize}',
      const {_enabledKey, _severityKey, _ignorableKey, 'max_fields'},
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return RecordSizeGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          maxFields: _ConfigScalars.readInt(
              map, 'max_fields', base.maxFields, path, ctx),
        );
      },
    );
  }
}
