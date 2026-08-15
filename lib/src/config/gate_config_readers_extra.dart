part of 'config_loader.dart';

const String _externalCtx = 'gates.external';

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
      'gates.broken_goldens',
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

  static TestAssertionsGateConfig readTestAssertions(
    Object? node,
    TestAssertionsGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.test_assertions',
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

  static FolderStructureGateConfig readFolderStructure(
    Object? node,
    FolderStructureGateConfig base,
    String path,
  ) {
    return _ConfigScalars.readGateConfig(
      node,
      base,
      path,
      'gates.folder_structure',
      const {
        _enabledKey,
        _severityKey,
        _ignorableKey,
        _dirsKey,
        'max_loose_files',
        _excludeKey
      },
      (map, base, path, ctx) {
        final flags = _ConfigScalars.gateFlags(map, base, path, ctx);
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
        'gates.external.rules',
        'expected a list of rules',
      );
    }
    return [
      for (final n in node.nodes) _readExternalRule(n, path),
    ];
  }

  /// Parses one `gates.external.rules` entry.
  static ExternalToolRule _readExternalRule(Object? n, String path) {
    const ctx = 'gates.external.rules';
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
      throw ConfigException(path, '$ctx.report', 'expected a string');
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
}
