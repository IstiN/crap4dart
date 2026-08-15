/// Source code for the collector library injected into instrumented projects.
///
/// This file is written to `lib/__crap_collector.dart` in the temp project
/// directory. It accumulates per-method timing data and writes it to a JSON
/// file specified by the `CRAP_PROFILE_OUTPUT` environment variable.
///
/// Because `dart test` runs each test file in a separate isolate (possibly
/// in parallel), the collector merges its data into the output file on every
/// flush using atomic write (temp file + rename) to avoid races.
const String collectorSource = r'''
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class _MethodStats {
  int calls = 0;
  int totalMicros = 0;
  int minMicros = 9223372036854775807;
  int maxMicros = 0;
}

/// Singleton collector for profiling data.
class CrapCollector {
  static final instance = CrapCollector._();

  final _stats = <String, _MethodStats>{};
  int _callCount = 0;

  CrapCollector._();

  /// Records a single method invocation timing.
  void record(String key, int micros) {
    final s = _stats[key] ??= _MethodStats();
    s.calls++;
    s.totalMicros += micros;
    if (micros < s.minMicros) s.minMicros = micros;
    if (micros > s.maxMicros) s.maxMicros = micros;
    // Flush frequently (flutter_test forbids pending timers after
    // widget teardown, so a periodic Timer cannot be kept alive).
    if (++_callCount % 5 == 0) _flush();
  }

  void _flush() {
    final path = Platform.environment['CRAP_PROFILE_OUTPUT'];
    if (path == null) return;

    // Read existing data (from other isolates that already flushed).
    final existing = <String, Map<String, int>>{};
    try {
      final f = File(path);
      if (f.existsSync()) {
        final raw = jsonDecode(f.readAsStringSync());
        if (raw is Map) {
          for (final e in raw.entries) {
            if (e.value is Map) {
              existing[e.key as String] =
                  Map<String, int>.from(e.value as Map);
            }
          }
        }
      }
    } catch (_) {
      // Corrupt or missing file — start fresh.
    }

    // Merge our stats into existing.
    for (final e in _stats.entries) {
      final minVal = e.value.minMicros == 9223372036854775807
          ? 0
          : e.value.minMicros;
      final ex = existing[e.key];
      if (ex == null) {
        existing[e.key] = {
          'calls': e.value.calls,
          'totalMicros': e.value.totalMicros,
          'minMicros': minVal,
          'maxMicros': e.value.maxMicros,
        };
      } else {
        ex['calls'] = (ex['calls'] ?? 0) + e.value.calls;
        ex['totalMicros'] =
            (ex['totalMicros'] ?? 0) + e.value.totalMicros;
        ex['minMicros'] = [
          ex['minMicros'] ?? 0,
          minVal,
        ].reduce((a, b) => a < b ? a : b);
        ex['maxMicros'] = [
          ex['maxMicros'] ?? 0,
          e.value.maxMicros,
        ].reduce((a, b) => a > b ? a : b);
      }
    }

    // Atomic write: write to temp file, then rename.
    try {
      final tmpPath = '$path.tmp.${DateTime.now().microsecondsSinceEpoch}';
      File(tmpPath).writeAsStringSync(jsonEncode(existing));
      File(tmpPath).renameSync(path);
    } catch (_) {
      // Ignore write errors — best effort.
    }
  }
}
''';
