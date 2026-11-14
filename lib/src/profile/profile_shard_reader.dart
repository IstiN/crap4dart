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
    final merged = <String, Map<String, dynamic>>{};
    for (final file in _shardFiles(outputFile)) {
      _mergeShard(merged, file);
    }
    return merged.isEmpty ? null : merged;
  }

  /// [outputFile] itself (if it exists — debug or legacy writers) plus
  /// every collector shard beside it (`<name>.<shardId>.json`), excluding
  /// in-flight `.tmp.` files.
  static List<File> _shardFiles(File outputFile) {
    final name = p.basename(outputFile.path);
    final prefix = '$name.';
    return [
      if (outputFile.existsSync()) outputFile,
      for (final entity in outputFile.parent.listSync())
        if (entity is File)
          if (p.basename(entity.path).startsWith(prefix) &&
              p.basename(entity.path).endsWith('.json') &&
              !p.basename(entity.path).contains('.tmp.'))
            entity,
    ];
  }

  /// Decodes [file] and merges its per-method stats into [merged].
  /// Corrupt or non-map content is skipped (a concurrent rename can
  /// leave a reader mid-file; the remaining shards still report).
  static void _mergeShard(
    Map<String, dynamic> merged,
    File file,
  ) {
    final dynamic raw;
    try {
      raw = jsonDecode(file.readAsStringSync());
    } on FormatException {
      return;
    }
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      _mergeEntry(merged, entry.key as String, entry.value);
    }
  }

  /// Merges one method's [stats] into [merged] under [key].
  static void _mergeEntry(
    Map<String, dynamic> merged,
    String key,
    Object statsValue,
  ) {
    final stats = Map<String, dynamic>.from(statsValue as Map);
    final existing = merged[key];
    if (existing == null) {
      merged[key] = stats;
      return;
    }
    _sumInto(existing, 'calls', stats);
    _sumInto(existing, 'totalMicros', stats);
    _sumInto(existing, 'totalSelfMicros', stats);
    existing['minMicros'] = _minOf(
      existing['minMicros'],
      stats['minMicros'],
    );
    existing['maxMicros'] = _maxOf(
      existing['maxMicros'],
      stats['maxMicros'],
    );
  }

  /// Adds [from]'s [field] value into [into].
  static void _sumInto(
    Map<String, dynamic> into,
    String field,
    Map<String, dynamic> from,
  ) {
    into[field] = (into[field] as int? ?? 0) + (from[field] as int? ?? 0);
  }

  /// Smaller of two nullable ints (null counts as 0, mirroring missing
  /// fields in hand-written shards).
  static int _minOf(Object? a, Object? b) =>
      _intOf(a) <= _intOf(b) ? _intOf(a) : _intOf(b);

  /// Larger of two nullable ints (null counts as 0).
  static int _maxOf(Object? a, Object? b) =>
      _intOf(a) >= _intOf(b) ? _intOf(a) : _intOf(b);

  static int _intOf(Object? value) => value is int ? value : 0;

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
