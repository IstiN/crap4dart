import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../analysis/method_extractor.dart';
import 'profile_runner.dart';

/// Loads collector output shards and merges them into one timing map.
///
/// Extracted from [ProfileRunner] to keep its cyclomatic complexity
/// within the repo's class-size gate.
class ProfileShardReader {
  /// Loads [outputFile] plus every collector shard beside it and merges
  /// them: calls and totals are summed (each shard holds one isolate's
  /// cumulative data — summing cannot double-count), min is minimized,
  /// max maximized. Returns `null` when nothing exists.
  static Map<String, dynamic>? read(File outputFile) {
    final dir = outputFile.parent;
    final name = p.basename(outputFile.path);
    final prefix = '$name.';
    final merged = <String, Map<String, dynamic>>{};
    final files = <File>[
      if (outputFile.existsSync()) outputFile,
      for (final entity in dir.listSync())
        if (entity is File)
          if (p.basename(entity.path).startsWith(prefix) &&
              p.basename(entity.path).endsWith('.json') &&
              !p.basename(entity.path).contains('.tmp.'))
            entity,
    ];
    for (final file in files) {
      final dynamic raw;
      try {
        raw = jsonDecode(file.readAsStringSync());
      } on FormatException {
        continue;
      }
      if (raw is! Map) continue;
      for (final entry in raw.entries) {
        if (entry.value is! Map) continue;
        final stats = Map<String, dynamic>.from(entry.value as Map);
        final key = entry.key as String;
        final existing = merged[key];
        if (existing == null) {
          merged[key] = stats;
          continue;
        }
        int stat(String name) => (existing[name] as int? ?? 0);
        existing['calls'] = stat('calls') + (stats['calls'] as int? ?? 0);
        existing['totalMicros'] =
            stat('totalMicros') + (stats['totalMicros'] as int? ?? 0);
        existing['totalSelfMicros'] =
            stat('totalSelfMicros') + (stats['totalSelfMicros'] as int? ?? 0);
        existing['minMicros'] = [
          stat('minMicros'),
          stats['minMicros'] as int? ?? 0,
        ].reduce((a, b) => a < b ? a : b);
        existing['maxMicros'] = [
          stat('maxMicros'),
          stats['maxMicros'] as int? ?? 0,
        ].reduce((a, b) => a > b ? a : b);
      }
    }
    return merged.isEmpty ? null : merged;
  }

  /// Loads and merges the shards of [outputFile] into sorted per-method
  /// timings, or `null` when no shard exists. `#`-prefixed keys are
  /// collector diagnostics (e.g. `#flushes`) and are skipped.
  static List<MethodTiming>? readTimings(File outputFile) {
    final json = read(outputFile);
    if (json == null || json.isEmpty) return null;
    final timings = <MethodTiming>[];
    for (final entry in json.entries) {
      final key = entry.key;
      if (key.startsWith('#')) continue;
      final stats = entry.value;
      final dotIndex = key.indexOf('.');
      timings.add(MethodTiming(
        className:
            dotIndex > 0 ? key.substring(0, dotIndex) : topLevelClassName,
        methodName: dotIndex > 0 ? key.substring(dotIndex + 1) : key,
        calls: stats['calls'] as int? ?? 0,
        totalMicros: stats['totalMicros'] as int? ?? 0,
        totalSelfMicros: stats['totalSelfMicros'] as int? ?? 0,
        minMicros: stats['minMicros'] as int? ?? 0,
        maxMicros: stats['maxMicros'] as int? ?? 0,
      ));
    }
    timings.sort((a, b) => b.totalMicros.compareTo(a.totalMicros));
    return timings;
  }
}
