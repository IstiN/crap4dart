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
  int totalSelfMicros = 0;
  int minMicros = 9223372036854775807;
  int maxMicros = 0;
  // Last values already merged into the output file. Flushes merge only
  // the DELTA since the last successful flush — merging the cumulative
  // values instead re-adds them on every flush, inflating counters
  // quadratically (a hot loop with millions of calls reported tens of
  // billions).
  int flushedCalls = 0;
  int flushedTotalMicros = 0;
  int flushedTotalSelfMicros = 0;
}

/// One open method invocation on the current call stack.
class _Frame {
  _Frame(this.key);

  final String key;
  final Stopwatch sw = Stopwatch()..start();
  int childMicros = 0;
}

/// Singleton collector for profiling data.
class CrapCollector {
  static final instance = CrapCollector._();

  final _stats = <String, _MethodStats>{};
  final _stack = <_Frame>[];
  int _callCount = 0;

  CrapCollector._();

  /// Marks method entry. Paired with [exit] via try/finally by the
  /// instrumented code.
  void enter(String key) {
    _stack.add(_Frame(key));
  }

  /// Marks method exit: records inclusive and self time for the call.
  ///
  /// Inclusive = wall time of the call (nested instrumented calls
  /// included, awaits included for async methods). Self = inclusive minus
  /// the inclusive time of nested calls that completed while the frame
  /// was open — flamegraph semantics.
  void exit(String key) {
    if (_stack.isEmpty) return;
    final frame = _stack.removeLast();
    frame.sw.stop();
    final inclusive = frame.sw.elapsedMicroseconds;
    var self = inclusive - frame.childMicros;
    if (self < 0) self = 0;
    if (_stack.isNotEmpty) _stack.last.childMicros += inclusive;

    final s = _stats[key] ??= _MethodStats();
    s.calls++;
    s.totalMicros += inclusive;
    s.totalSelfMicros += self;
    if (inclusive < s.minMicros) s.minMicros = inclusive;
    if (inclusive > s.maxMicros) s.maxMicros = inclusive;
    // Flush frequently (flutter_test forbids pending timers after
    // widget teardown, so a periodic Timer cannot be kept alive). The
    // outermost exit also flushes — a top-level call completing is a
    // natural checkpoint, so short runs don't lose their tail.
    if (++_callCount % 5 == 0 || _stack.isEmpty) _flush();
  }

  /// Flushes pending deltas immediately. Useful at the end of a test run:
  /// the periodic every-5-calls flush otherwise leaves up to 4 records
  /// unwritten.
  void flush() => _flush();

  void _flush() {
    final path = Platform.environment['CRAP_PROFILE_OUTPUT'];
    if (path == null) return;
    if (_stats.isEmpty) return;

    // Read existing data (from other isolates that already flushed).
    // Retries once: a concurrent rename can land between existsSync
    // and readAsStringSync.
    final existing = <String, Map<String, int>>{};
    for (var attempt = 0; attempt < 2; attempt++) {
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
          break;
        }
      } catch (_) {
        // Corrupt or concurrently-replaced file — retry once, then
        // start fresh.
      }
    }

    // Merge our stats into existing. Only the delta since the last
    // successful flush is added — the cumulative values were already
    // written by previous flushes.
    for (final e in _stats.entries) {
      final minVal = e.value.minMicros == 9223372036854775807
          ? 0
          : e.value.minMicros;
      final deltaCalls = e.value.calls - e.value.flushedCalls;
      final deltaTotal = e.value.totalMicros - e.value.flushedTotalMicros;
      final deltaSelf =
          e.value.totalSelfMicros - e.value.flushedTotalSelfMicros;
      final ex = existing[e.key];
      if (ex == null) {
        existing[e.key] = {
          'calls': deltaCalls,
          'totalMicros': deltaTotal,
          'totalSelfMicros': deltaSelf,
          'minMicros': minVal,
          'maxMicros': e.value.maxMicros,
        };
      } else {
        ex['calls'] = (ex['calls'] ?? 0) + deltaCalls;
        ex['totalMicros'] =
            (ex['totalMicros'] ?? 0) + deltaTotal;
        ex['totalSelfMicros'] =
            (ex['totalSelfMicros'] ?? 0) + deltaSelf;
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

    // Atomic write: write to a per-isolate temp file, then rename.
    // Microsecond timestamps can collide across isolates — the
    // identity hash keeps every flush's temp unique.
    try {
      final tmpPath = '$path.tmp.${identityHashCode(this)}.'
          '${DateTime.now().microsecondsSinceEpoch}';
      File(tmpPath).writeAsStringSync(jsonEncode(existing));
      File(tmpPath).renameSync(path);
      // Advance the flushed snapshots only after a successful write so a
      // failed flush retries the same delta next time (at-least-once).
      for (final e in _stats.entries) {
        e.value.flushedCalls = e.value.calls;
        e.value.flushedTotalMicros = e.value.totalMicros;
        e.value.flushedTotalSelfMicros = e.value.totalSelfMicros;
      }
    } catch (_) {
      // Ignore write errors — best effort.
    }
  }
}
''';
