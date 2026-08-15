part of 'config_loader.dart';

/// YAML keys for the shared gate flags, used across the config parts.
const String _enabledKey = 'enabled';
const String _severityKey = 'severity';
const String _ignorableKey = 'ignorable';

/// Error message for values that must be integers.
const String _expectedIntegerMsg = 'expected an integer';

/// The three framework flags every gate config shares.
typedef GateFlagsRecord = ({
  bool enabled,
  GateSeverity severity,
  bool ignorable,
});

/// Shared scalar readers used by [ConfigLoader] and [GateConfigReaders]
/// to decode typed values out of parsed YAML maps.
class _ConfigScalars {
  static YamlMap asMap(Object? node, String path, String key) {
    if (node is YamlMap) return node;
    throw ConfigException(path, key, 'expected a map');
  }

  static void checkKeys(
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

  static bool readBool(
      YamlMap map, String key, bool base, String path, String ctx) {
    final value = map[key];
    if (value == null) return base;
    if (value is bool) return value;
    throw ConfigException(path, '$ctx.$key', 'expected a boolean');
  }

  static GateSeverity severity(
    YamlMap map,
    String key,
    GateSeverity base,
    String path,
    String ctx,
  ) {
    final value = map[key];
    if (value == null) return base;
    if (value is String && (value == 'error' || value == 'warning')) {
      return GateSeverity.parse(value);
    }
    throw ConfigException(
      path,
      '$ctx.$key',
      "expected 'error' or 'warning'",
    );
  }

  static double readNum(
      YamlMap map, String key, double base, String path, String ctx) {
    final value = map[key];
    if (value == null) return base;
    if (value is num) return value.toDouble();
    throw ConfigException(path, '$ctx.$key', 'expected a number');
  }

  static int readInt(
    YamlMap map,
    String key,
    int base,
    String path,
    String ctx,
  ) {
    final value = map[key];
    if (value == null) return base;
    if (value is int) return value;
    throw ConfigException(path, '$ctx.$key', _expectedIntegerMsg);
  }

  static String str(
      YamlMap map, String key, String base, String path, String ctx) {
    final value = map[key];
    if (value == null) return base;
    if (value is String) return value;
    throw ConfigException(path, '$ctx.$key', 'expected a string');
  }

  static List<String> strList(
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

  static T readGateConfig<T>(
    Object? node,
    T base,
    String path,
    String ctx,
    Set<String> knownKeys,
    T Function(YamlMap map, T base, String path, String ctx) build,
  ) {
    if (node == null) return base;
    final map = asMap(node, path, ctx);
    checkKeys(map, knownKeys, path, ctx);
    return build(map, base, path, ctx);
  }

  /// Reads the shared `enabled`/`severity`/`ignorable` gate flags.
  static GateFlagsRecord gateFlags(
    YamlMap map,
    dynamic base,
    String path,
    String ctx,
  ) {
    return (
      enabled: readBool(map, _enabledKey, base.enabled, path, ctx),
      severity: severity(map, _severityKey, base.severity, path, ctx),
      ignorable: readBool(map, _ignorableKey, base.ignorable, path, ctx),
    );
  }

  /// Validates an `entries` list and returns its member maps.
  static List<YamlMap> entryMaps(Object? node, String ctx, String path) {
    if (node is! YamlList) {
      throw ConfigException(path, ctx, 'expected a list of entries');
    }
    final maps = <YamlMap>[];
    for (final n in node.nodes) {
      if (n is! YamlMap) {
        throw ConfigException(path, ctx, 'expected entry maps');
      }
      maps.add(n);
    }
    return maps;
  }

  /// Reads the required non-empty `paths` list of an entry.
  static List<String> entryPaths(YamlMap entry, String ctx, String path) {
    final paths = entry['paths'];
    if (paths is YamlList &&
        paths.nodes.isNotEmpty &&
        paths.nodes.every((n) => n is YamlScalar && n.value is String)) {
      return [
        for (final n in paths.nodes) (n as YamlScalar).value as String,
      ];
    }
    throw ConfigException(
      path,
      '$ctx.paths',
      'expected a non-empty list of globs',
    );
  }

  /// Reads a required integer entry key.
  static int requiredInt(YamlMap map, String key, String ctx, String path) {
    final value = map[key];
    if (value is int) return value;
    throw ConfigException(path, '$ctx.$key', _expectedIntegerMsg);
  }

  /// Reads an optional integer entry key, or `null` when absent.
  static int? optionalInt(YamlMap map, String key, String ctx, String path) {
    final value = map[key];
    if (value == null) return null;
    if (value is int) return value;
    throw ConfigException(path, '$ctx.$key', _expectedIntegerMsg);
  }
}
