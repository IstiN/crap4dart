/// Source code for the collector library injected into instrumented projects.
///
/// This file is written to `lib/__crap_collector.dart` in the temp project
/// directory. It accumulates per-method timing data and writes it to a JSON
/// file specified by the `CRAP_PROFILE_OUTPUT` environment variable.
///
/// Flush design (no timers — `flutter_test` forbids pending timers after
/// widget teardown):
///
/// - Each isolate writes its OWN shard file
///   `<output>.<shardId>.json` holding that isolate's CUMULATIVE stats,
///   replaced atomically (temp + rename) on every flush. Shards never
///   read other isolates' data, so concurrent isolates cannot lose each
///   other's updates (the old shared-file read-merge-write lost updates
///   under concurrency); the runner merges all shards at the end.
/// - A shard write is O(#methods), never O(#calls). Nested method exits
///   do NO I/O at all — only the outermost exit of the call tree can
///   flush, and the outermost exit ALWAYS flushes: it is the only
///   reliable delivery point (an isolate dying after its last
///   instrumented call has no other chance to report), so data loss on
///   normal termination is impossible. The write is a few hundred
///   microseconds even for a thousand-method stats map.
/// - A backstop flush every [flushBackstopCalls] calls (default 100000)
///   bounds the loss when the call stack is stuck non-empty (a leaked
///   frame whose exit never ran) or the process dies mid-tree.
/// - `CRAP_PROFILE_FLUSH_MS` (default 0) throttles outermost flushes to
///   at most one per interval — an OPT-IN trade: it keeps extremely
///   outermost-heavy loops I/O-light but the tail after the last
///   throttled exit is lost unless an explicit flush() runs. Keep 0
///   (flush per outermost exit) unless that shape actually hurts.
///
/// Tunables (environment): `CRAP_PROFILE_FLUSH_MS` (0 = always flush on
/// outermost exit), `CRAP_PROFILE_FLUSH_EVERY`, `CRAP_PROFILE_FLUSH_BATCH`
/// (kept for compatibility; only used by diagnostics).
const String collectorSource = r'''
import 'dart:convert';
import 'dart:io';

class _MethodStats {
  int calls = 0;
  int totalMicros = 0;
  int totalSelfMicros = 0;
  int minMicros = 9223372036854775807;
  int maxMicros = 0;
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
  int _flushSeq = 0;
  // Elapsed-ms clock for the flush-rate throttle; a Stopwatch is not a
  // Timer, so it never leaves a pending timer behind.
  final Stopwatch _sinceFlush = Stopwatch()..start();
  late final String _shardId;
  late final int _flushMinIntervalMs;
  late final int _flushBackstopCalls;
  late final int _flushBatchLimit;

  CrapCollector._() {
    final identity = identityHashCode(this);
    final boot = DateTime.now().microsecondsSinceEpoch;
    _shardId = '${Platform.environment['CRAP_PROFILE_SHARD'] ?? '$boot-$identity'}';
    int env(String name, int fallback) {
      final raw = Platform.environment[name];
      if (raw == null) return fallback;
      return int.tryParse(raw) ?? fallback;
    }

    _flushMinIntervalMs = env('CRAP_PROFILE_FLUSH_MS', 0);
    _flushBackstopCalls = env('CRAP_PROFILE_FLUSH_EVERY', 100000);
    _flushBatchLimit = env('CRAP_PROFILE_FLUSH_BATCH', 256);
  }

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
    final outermost = _stack.isEmpty;
    if (!outermost) _stack.last.childMicros += inclusive;

    final s = _stats[key] ??= _MethodStats();
    s.calls++;
    s.totalMicros += inclusive;
    s.totalSelfMicros += self;
    if (inclusive < s.minMicros) s.minMicros = inclusive;
    if (inclusive > s.maxMicros) s.maxMicros = inclusive;
    _callCount++;

    // Nested exits never touch the filesystem. The outermost exit of a
    // call tree is the natural checkpoint: flush while the run is short
    // (small unreported batch — keeps brief tests complete), then throttle
    // to at most one shard write per interval so a hot outermost loop
    // cannot turn profiling into an I/O benchmark. The backstop bounds
    // the tail when the stack is stuck non-empty (leaked frame) or the
    // process dies between checkpoints.
    if (outermost) {
      // The outermost exit is the only reliable delivery point — an
      // isolate that dies after it has no other chance to report — so
      // it flushes by default. An opt-in interval keeps pathological
      // outermost-heavy loops I/O-light at the cost of a bounded tail.
      if (_flushMinIntervalMs <= 0 ||
          _sinceFlush.elapsedMilliseconds >= _flushMinIntervalMs) {
        _flush();
      }
    } else if (_callCount % _flushBackstopCalls == 0) {
      _flush();
    }
  }

  /// Flushes pending data immediately. Useful at the end of a test run.
  void flush() => _flush();

  void _flush() {
    final path = Platform.environment['CRAP_PROFILE_OUTPUT'];
    if (path == null) return;
    if (_stats.isEmpty) return;

    // Cumulative snapshot of THIS isolate only — the shard file is
    // private to us, so replacing it wholesale is race-free (no
    // read-merge of other isolates' data, no lost updates).
    final snapshot = <String, Map<String, int>>{};
    for (final e in _stats.entries) {
      final minVal = e.value.minMicros == 9223372036854775807
          ? 0
          : e.value.minMicros;
      snapshot[e.key] = {
        'calls': e.value.calls,
        'totalMicros': e.value.totalMicros,
        'totalSelfMicros': e.value.totalSelfMicros,
        'minMicros': minVal,
        'maxMicros': e.value.maxMicros,
      };
    }
    // Diagnostic flush counter (a `#`-prefixed key; the report skips it)
    // so tests and debugging can observe how many shard writes happened.
    // Counted as 1-based; the sequence number is only advanced on a
    // successful rename so a failed write retries the same number.
    snapshot['#flushes'] = {'calls': _flushSeq + 1};

    try {
      final shardPath = '$path.$_shardId.json';
      final tmpPath = '$shardPath.tmp.${_flushSeq}';
      File(tmpPath).writeAsStringSync(jsonEncode(snapshot));
      File(tmpPath).renameSync(shardPath);
      _flushSeq++;
      _sinceFlush.reset();
    } catch (_) {
      // Ignore write errors — best effort; the next checkpoint retries.
    }
  }
}
''';
