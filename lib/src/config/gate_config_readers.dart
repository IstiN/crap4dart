part of 'config_loader.dart';

/// Reads the per-gate sub-configs under the `gates` key; each reader
/// validates its gate's keys and applies per-key defaults from [base].
class _GateConfigReaders {
  static LocGateConfig readLoc(Object? node, LocGateConfig base, String path) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.loc',
      const {
        'enabled',
        'severity',
        'ignorable',
        'max_lines',
        'entries',
        'exclude'
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return LocGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          maxLines: _ConfigScalars.readInt(
              map, 'max_lines', base.maxLines, path, ctx),
          entries: readLocEntries(map['entries'], path),
          exclude:
              _ConfigScalars.strList(map, 'exclude', base.exclude, path, ctx),
        );
      },
    );
  }

  static List<LocPathEntry> readLocEntries(Object? node, String path) {
    if (node == null) return const [];
    return _ConfigScalars.entryMaps(node, 'gates.loc.entries', path)
        .map((entry) => LocPathEntry(
              maxLines: _ConfigScalars.requiredInt(
                  entry, 'max_lines', 'gates.loc.entries', path),
              paths:
                  _ConfigScalars.entryPaths(entry, 'gates.loc.entries', path),
            ))
        .toList();
  }

  static TestCoverageGateConfig readTestCoverage(
    Object? node,
    TestCoverageGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.test_coverage',
      const {
        'enabled',
        'severity',
        'ignorable',
        'min_percent',
        'per_file',
        'dirs'
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return TestCoverageGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          minPercent: _ConfigScalars.readNum(
              map, 'min_percent', base.minPercent, path, ctx),
          perFile:
              _ConfigScalars.readBool(map, 'per_file', base.perFile, path, ctx),
          dirs: _ConfigScalars.strList(map, 'dirs', base.dirs, path, ctx),
        );
      },
    );
  }

  static GoldenGateConfig readGolden(
    Object? node,
    GoldenGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.golden',
      const {
        'enabled',
        'severity',
        'ignorable',
        'min_widget_coverage',
        'widget_dirs',
        'test_dirs',
        'exclude_widgets',
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return GoldenGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          minWidgetCoverage: _ConfigScalars.readNum(
              map, 'min_widget_coverage', base.minWidgetCoverage, path, ctx),
          widgetDirs: _ConfigScalars.strList(
              map, 'widget_dirs', base.widgetDirs, path, ctx),
          testDirs: _ConfigScalars.strList(
              map, 'test_dirs', base.testDirs, path, ctx),
          excludeWidgets: _ConfigScalars.strList(
              map, 'exclude_widgets', base.excludeWidgets, path, ctx),
        );
      },
    );
  }

  static HardcodedStringsGateConfig readHardcodedStrings(
    Object? node,
    HardcodedStringsGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.hardcoded_strings',
      const {
        'enabled',
        'severity',
        'ignorable',
        'ignore_marker',
        'check_params'
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return HardcodedStringsGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          ignoreMarker: _ConfigScalars.str(
              map, 'ignore_marker', base.ignoreMarker, path, ctx),
          checkParams: _ConfigScalars.strList(
              map, 'check_params', base.checkParams, path, ctx),
        );
      },
    );
  }

  static AccessibilityGateConfig readAccessibility(
    Object? node,
    AccessibilityGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.accessibility',
      const {'enabled', 'severity', 'ignorable', 'require_label_for'},
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return AccessibilityGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          requireLabelFor: _ConfigScalars.strList(
              map, 'require_label_for', base.requireLabelFor, path, ctx),
        );
      },
    );
  }

  static ComplexityGateConfig readComplexity(
    Object? node,
    ComplexityGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.complexity',
      const {
        'enabled',
        'severity',
        'ignorable',
        'max_complexity',
        'entries',
        'count_lambdas'
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return ComplexityGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          maxComplexity: _ConfigScalars.readInt(
              map, 'max_complexity', base.maxComplexity, path, ctx),
          entries: readComplexityEntries(map['entries'], path),
          countLambdas: _ConfigScalars.readBool(
              map, 'count_lambdas', base.countLambdas, path, ctx),
        );
      },
    );
  }

  static List<ComplexityPathEntry> readComplexityEntries(
    Object? node,
    String path,
  ) {
    if (node == null) return const [];
    return _ConfigScalars.entryMaps(node, 'gates.complexity.entries', path)
        .map((entry) => ComplexityPathEntry(
              maxComplexity: _ConfigScalars.requiredInt(
                  entry, 'max_complexity', 'gates.complexity.entries', path),
              paths: _ConfigScalars.entryPaths(
                  entry, 'gates.complexity.entries', path),
            ))
        .toList();
  }

  static MethodSizeGateConfig readMethodSize(
    Object? node,
    MethodSizeGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.method_size',
      const {
        'enabled',
        'severity',
        'ignorable',
        'max_lines',
        'max_params',
        'entries'
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return MethodSizeGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          maxLines: _ConfigScalars.readInt(
              map, 'max_lines', base.maxLines, path, ctx),
          maxParams: _ConfigScalars.readInt(
              map, 'max_params', base.maxParams, path, ctx),
          entries: readMethodSizeEntries(map['entries'], path),
        );
      },
    );
  }

  static List<MethodSizePathEntry> readMethodSizeEntries(
    Object? node,
    String path,
  ) {
    if (node == null) return const [];
    const ctx = 'gates.method_size.entries';
    return _ConfigScalars.entryMaps(node, ctx, path).map((entry) {
      _ConfigScalars.checkKeys(
          entry, const {'max_lines', 'max_params', 'paths'}, path, ctx);
      final maxLines =
          _ConfigScalars.optionalInt(entry, 'max_lines', ctx, path);
      final maxParams =
          _ConfigScalars.optionalInt(entry, 'max_params', ctx, path);
      if (maxLines == null && maxParams == null) {
        throw ConfigException(
          path,
          ctx,
          'entry must set at least one of max_lines, max_params',
        );
      }
      return MethodSizePathEntry(
        maxLines: maxLines,
        maxParams: maxParams,
        paths: _ConfigScalars.entryPaths(entry, ctx, path),
      );
    }).toList();
  }

  static NestingGateConfig readNesting(
    Object? node,
    NestingGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.nesting',
      const {'enabled', 'severity', 'ignorable', 'max_nesting'},
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return NestingGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          maxNesting: _ConfigScalars.readInt(
              map, 'max_nesting', base.maxNesting, path, ctx),
        );
      },
    );
  }

  static ClassSizeGateConfig readClassSize(
    Object? node,
    ClassSizeGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.class_size',
      const {'enabled', 'severity', 'ignorable', 'max_methods', 'max_wmc'},
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return ClassSizeGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          maxMethods: _ConfigScalars.readInt(
              map, 'max_methods', base.maxMethods, path, ctx),
          maxWmc:
              _ConfigScalars.readInt(map, 'max_wmc', base.maxWmc, path, ctx),
        );
      },
    );
  }

  static WeightOfClassGateConfig readWeightOfClass(
    Object? node,
    WeightOfClassGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.weight_of_class',
      const {'enabled', 'severity', 'ignorable', 'max_weight', 'exclude'},
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return WeightOfClassGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          maxWeight: _ConfigScalars.readNum(
              map, 'max_weight', base.maxWeight, path, ctx),
          exclude:
              _ConfigScalars.strList(map, 'exclude', base.exclude, path, ctx),
        );
      },
    );
  }

  static UnusedCodeGateConfig readUnusedCode(
    Object? node,
    UnusedCodeGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.unused_code',
      const {'enabled', 'severity', 'ignorable', 'exclude'},
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return UnusedCodeGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          exclude:
              _ConfigScalars.strList(map, 'exclude', base.exclude, path, ctx),
        );
      },
    );
  }

  static UnusedFilesGateConfig readUnusedFiles(
    Object? node,
    UnusedFilesGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.unused_files',
      const {'enabled', 'severity', 'ignorable', 'dirs', 'exclude'},
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return UnusedFilesGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          dirs: _ConfigScalars.strList(map, 'dirs', base.dirs, path, ctx),
          exclude:
              _ConfigScalars.strList(map, 'exclude', base.exclude, path, ctx),
        );
      },
    );
  }

  static BannedImportsGateConfig readBannedImports(
    Object? node,
    BannedImportsGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.banned_imports',
      const {'enabled', 'severity', 'ignorable', 'rules'},
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return BannedImportsGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          rules: readBannedImportRules(map['rules'], path),
        );
      },
    );
  }

  static List<BannedImportRule> readBannedImportRules(
    Object? node,
    String path,
  ) {
    if (node == null) return const [];
    if (node is! YamlList) {
      throw ConfigException(
        path,
        'gates.banned_imports.rules',
        'expected a list of rules',
      );
    }
    const ctx = 'gates.banned_imports.rules';
    return [
      for (final n in node.nodes) _readBannedImportRule(n, path, ctx),
    ];
  }

  /// Parses one `gates.banned_imports.rules` entry.
  static BannedImportRule _readBannedImportRule(
    Object? node,
    String path,
    String ctx,
  ) {
    if (node is! YamlMap) {
      throw ConfigException(path, ctx, 'expected rule maps');
    }
    _ConfigScalars.checkKeys(
        node, const {'from', 'forbid', 'message'}, path, ctx);
    final forbid = _ConfigScalars.strList(node, 'forbid', const [], path, ctx);
    if (forbid.isEmpty) {
      throw ConfigException(
        path,
        '$ctx.forbid',
        'expected a non-empty list of globs',
      );
    }
    return BannedImportRule(
      from: _requiredGlob(node['from'], path, ctx),
      forbid: forbid,
      message: _optionalString(node['message'], '$ctx.message', path),
    );
  }

  /// A required non-empty glob string under [ctx].from.
  static String _requiredGlob(Object? value, String path, String ctx) {
    if (value is! String || value.isEmpty) {
      throw ConfigException(path, '$ctx.from', 'expected a non-empty glob');
    }
    return value;
  }

  /// An optional string value at [key], when not `null`.
  static String? _optionalString(Object? value, String key, String path) {
    if (value != null && value is! String) {
      throw ConfigException(path, key, 'expected a string');
    }
    return value as String?;
  }

  static PublicDocsGateConfig readPublicDocs(
    Object? node,
    PublicDocsGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.public_docs',
      const {'enabled', 'severity', 'ignorable', 'exclude'},
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return PublicDocsGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          exclude:
              _ConfigScalars.strList(map, 'exclude', base.exclude, path, ctx),
        );
      },
    );
  }

  static DuplicationGateConfig readDuplication(
    Object? node,
    DuplicationGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.duplication',
      const {
        'enabled',
        'severity',
        'ignorable',
        'threshold',
        'min_tokens',
        'min_lines',
        'exclude'
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return DuplicationGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          threshold: _ConfigScalars.readNum(
              map, 'threshold', base.threshold, path, ctx),
          minTokens: _ConfigScalars.readInt(
              map, 'min_tokens', base.minTokens, path, ctx),
          minLines: _ConfigScalars.readInt(
              map, 'min_lines', base.minLines, path, ctx),
          exclude:
              _ConfigScalars.strList(map, 'exclude', base.exclude, path, ctx),
        );
      },
    );
  }

  static FileNamingGateConfig readFileNaming(
    Object? node,
    FileNamingGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.file_naming',
      const {'enabled', 'severity', 'ignorable', 'exclude', 'allow'},
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
        return FileNamingGateConfig(
          enabled: flags.enabled,
          severity: flags.severity,
          ignorable: flags.ignorable,
          exclude:
              _ConfigScalars.strList(map, 'exclude', base.exclude, path, ctx),
          allow: _ConfigScalars.strList(map, 'allow', base.allow, path, ctx),
        );
      },
    );
  }
}
