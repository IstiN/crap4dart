part of 'config_loader.dart';

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
}
