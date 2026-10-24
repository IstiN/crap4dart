import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'gc_log.dart';
import 'test_run_events.dart';

/// Aggregated memory metrics of one test (or of a whole suite/file).
class MemoryEntry {
  /// Creates an empty [MemoryEntry] for [label].
  MemoryEntry(this.label, {this.suitePath});

  /// Display label: test name for tests, file path for suites.
  final String label;

  /// Test file path when this entry is a single test.
  final String? suitePath;

  /// GC events attributed to this entry.
  final List<GcEvent> gcs = [];

  /// Bytes allocated during this entry's window, from the VM
  /// allocation profile (Flutter engine; `null` when unavailable —
  /// the Dart engine reports reclaimed new-gen volume instead).
  int? allocatedBytes;

  /// Whether [churnNewMb] carries real data. The VM Service GC stream
  /// (Flutter engine) has no reclaimed-new-gen counters, so the churn
  /// proxy is unavailable there — serialized as `null`, never as a
  /// misleading `0.0`; use [allocatedMb] (exact allocated bytes).
  bool get churnAvailable => allocatedBytes == null;

  /// Reclaimed new-gen volume — the honest "allocated MB" proxy.
  /// Only meaningful when [churnAvailable] is true.
  double get churnNewMb => gcs.fold(0, (sum, gc) => sum + gc.reclaimedNewMb);

  /// Signed old-gen growth: positive and never freed = leak suspect.
  double get oldGrowthMb => gcs.fold(0, (sum, gc) => sum + gc.oldDeltaMb);

  /// Allocation volume: profile bytes when available, otherwise the
  /// reclaimed-new-gen proxy of the Dart engine's GC table.
  double get allocatedMb =>
      allocatedBytes == null ? churnNewMb : allocatedBytes! / 1048576;

  /// The JSON shape of this entry.
  Map<String, dynamic> toJson() => {
        'label': label,
        if (suitePath != null) 'suite': suitePath,
        'gcs': gcs.length,
        'churnNewMb':
            churnAvailable ? double.parse(churnNewMb.toStringAsFixed(1)) : null,
        if (allocatedBytes != null)
          'allocatedMb': double.parse(allocatedMb.toStringAsFixed(1)),
        'oldGrowthMb': double.parse(oldGrowthMb.toStringAsFixed(1)),
      };
}

/// The full memory report of one suite run.
class MemoryReport {
  /// Total allocation volume across suites (profile-based for the
  /// Flutter engine, reclaimed-proxy for the Dart engine).
  double get totalAllocatedMb =>
      suites.fold(0, (sum, suite) => sum + suite.allocatedMb);

  /// Creates a [MemoryReport].
  MemoryReport({
    required this.testCount,
    required this.totalGcs,
    required this.suites,
    required this.tests,
    required this.unattributedGcs,
    this.churnAvailable = true,
  });

  /// Whether [totalChurnMb] carries real data: false on the Flutter
  /// engine (VM Service GC stream has no reclaimed-new-gen counters).
  /// JSON/console surface `null`/unavailable instead of a fake 0.0;
  /// [totalAllocatedMb] is the allocation-volume metric on both engines.
  final bool churnAvailable;

  /// Tests executed (spans with a result).
  final int testCount;

  /// All GC events of test isolates.
  final List<GcEvent> totalGcs;

  /// Per-suite entries.
  final List<MemoryEntry> suites;

  /// Per-test entries.
  final List<MemoryEntry> tests;

  /// GCs that no test window claims: isolate loading (kernel
  /// compilation) and teardown. Their isolate identity in the stream
  /// is unreliable (the VM truncates names and spawn announcements
  /// lag/lead their rows), so they are reported as a separate bucket
  /// instead of polluting file totals.
  final List<GcEvent> unattributedGcs;

  /// Tests with GC activity, sorted by allocation churn, descending.
  List<MemoryEntry> get topChurn => [
        for (final test in tests)
          if (test.gcs.isNotEmpty) test,
      ]..sort((a, b) => b.allocatedMb.compareTo(a.allocatedMb));

  /// Tests with GC activity, sorted by old-gen growth, descending
  /// (leak suspects first).
  List<MemoryEntry> get topOldGrowth => [
        for (final test in tests)
          if (test.gcs.isNotEmpty) test,
      ]..sort((a, b) => b.oldGrowthMb.compareTo(a.oldGrowthMb));

  /// Total reclaimed new-gen MB across all GCs. Only meaningful when
  /// [churnAvailable] is true (0.0 on the Flutter engine by absence
  /// of counters, not by absence of churn).
  double get totalChurnMb =>
      totalGcs.fold(0, (sum, gc) => sum + gc.reclaimedNewMb);

  /// Net old-gen growth of the run.
  double get totalOldGrowthMb =>
      totalGcs.fold(0, (sum, gc) => sum + gc.oldDeltaMb);

  /// Reclaimed new-gen MB of the unattributed bucket.
  double get unattributedChurnMb =>
      unattributedGcs.fold(0, (sum, gc) => sum + gc.reclaimedNewMb);
}

/// What a suite run returns: both output streams.
typedef MemoryRunResult = ({String stdoutText, String stderrText});

/// The injectable suite-runner signature.
typedef SuiteRunner = Future<MemoryRunResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

/// Runs the test suite under `--verbose_gc` and attributes GC events
/// and reclaimed memory to tests.
class MemoryProfiler {
  /// Creates a [MemoryProfiler]; [runner] is injectable for tests.
  MemoryProfiler({SuiteRunner? runner}) : _runner = runner ?? _defaultRunner;

  final SuiteRunner _runner;

  static Future<MemoryRunResult> _defaultRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    final stdoutText = <int>[];
    final stderrText = <int>[];
    await Future.wait([
      process.stdout.forEach(stdoutText.addAll),
      process.stderr.forEach(stderrText.addAll),
      process.exitCode,
    ]);
    return (
      stdoutText: utf8.decode(stdoutText),
      stderrText: utf8.decode(stderrText),
    );
  }

  /// Profiles `dart test [paths]` in [projectRoot].
  Future<MemoryReport> profile(
    String projectRoot,
    List<String> paths, {
    int repeat = 1,
  }) async {
    final args = [
      '--verbose_gc',
      'test',
      '--concurrency=1',
      '-r',
      'json',
      ...paths,
    ];
    final run = await _runner('dart', args, workingDirectory: projectRoot);
    return _report(run);
  }

  /// Builds the report from one raw run's streams.
  MemoryReport reportFromStreams(MemoryRunResult run) => _report(run);

  MemoryReport _report(MemoryRunResult run) {
    final events = TestRunEvents();
    for (final line in run.stdoutText.split('\n')) {
      events.addLine(line);
    }
    final gcs = GcLogParser.parse(run.stderrText.split('\n'))
        .where((gc) => gc.isolate.startsWith('test_suite'))
        .toList();
    final suitesInOrder = events.suitesById.values.toList();
    // With --concurrency=1 the k-th spawned test isolate runs the k-th
    // suite. The spawn index is embedded in the isolate name
    // (`…/test.dart_N.dill`): isolate N maps onto suite N — robust
    // against light suites that never GC at all (first-sighting order
    // would skip them and shift every later mapping).
    final isolateToSuite = <String, TestSuiteEvent>{};
    for (final gc in gcs) {
      if (isolateToSuite.containsKey(gc.isolate)) continue;
      final index = _suiteIndexOf(gc.isolate);
      if (index != null && index > 0 && index <= suitesInOrder.length) {
        isolateToSuite[gc.isolate] = suitesInOrder[index - 1];
      }
    }
    return _attribute(gcs, isolateToSuite, events);
  }

  /// The suite spawn index embedded in an isolate name
  /// (`…kernel.XXXX/test.dart_N.dill` → N), or `null` when absent.
  static int? _suiteIndexOf(String isolate) {
    final match = RegExp(r'test\.dart_(\d+)\.dill').firstMatch(isolate);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Spans of every suite, keyed by suite id, in start order.
  static Map<int, List<TestSpan>> _spansBySuite(TestRunEvents events) {
    final bySuite = <int, List<TestSpan>>{};
    for (final span in events.spansById.values) {
      bySuite.putIfAbsent(span.suiteId, () => []).add(span);
    }
    for (final spans in bySuite.values) {
      spans.sort((a, b) => a.startMs.compareTo(b.startMs));
    }
    return bySuite;
  }

  /// Attributes every GC to a suite (by isolate — exact) and to a test
  /// (by a PER-SUITE clock offset anchored on the suite's own last GC
  /// vs its last test end, so a calibration error can never move a GC
  /// into another file), producing the report.
  static MemoryReport _attribute(
    List<GcEvent> gcs,
    Map<String, TestSuiteEvent> isolateToSuite,
    TestRunEvents events,
  ) {
    final suiteEntries = <int, MemoryEntry>{};
    final testEntries = <int, MemoryEntry>{};
    for (final suite in events.suitesById.values) {
      suiteEntries[suite.id] = MemoryEntry(suite.path);
    }
    final spansBySuite = _spansBySuite(events);
    for (final span in events.spansById.values) {
      final suite = events.suitesById[span.suiteId];
      testEntries[span.id] = MemoryEntry(
        span.name,
        suitePath: suite?.path,
      );
    }
    final gcsBySuite = _gcsBySuite(gcs, isolateToSuite);
    final unattributed = <GcEvent>[];
    for (final entry in gcsBySuite.entries) {
      final spans = spansBySuite[entry.key];
      if (spans == null || spans.isEmpty) continue;
      final suite = events.suitesById[entry.key];
      _assignSuiteGcs(
        entry.value,
        spans,
        testEntries,
        suiteEntries,
        entry.key,
        suite?.timeMs ?? 0,
        unattributed,
      );
    }
    final tests =
        testEntries.values.where((entry) => entry.label.isNotEmpty).toList();
    return MemoryReport(
      testCount:
          events.spansById.values.where((span) => span.result != null).length,
      totalGcs: gcs,
      suites: suiteEntries.values.toList(),
      tests: tests,
      unattributedGcs: [
        ...unattributed,
        for (final gc in gcs)
          if (isolateToSuite[gc.isolate] == null) gc,
      ],
    );
  }

  /// GCs grouped by suite id (candidate attribution — windows refine
  /// it; suite file totals carry only window-attributed rows).
  static Map<int, List<GcEvent>> _gcsBySuite(
    List<GcEvent> gcs,
    Map<String, TestSuiteEvent> isolateToSuite,
  ) {
    final gcsBySuite = <int, List<GcEvent>>{};
    for (final gc in gcs) {
      final suite = isolateToSuite[gc.isolate];
      if (suite == null) continue;
      gcsBySuite.putIfAbsent(suite.id, () => []).add(gc);
    }
    return gcsBySuite;
  }

  /// Assigns one suite's GCs to its tests. GC rows count time from
  /// ISOLATE start; the suite event time [suiteTimeMs] (reporter ms)
  /// marks that same zero point, so a test's window in isolate-clock
  /// seconds is ((span ms − suiteTimeMs) / 1000).
  static void _assignSuiteGcs(
    List<GcEvent> suiteGcs,
    List<TestSpan> spans,
    Map<int, MemoryEntry> testEntries,
    Map<int, MemoryEntry> suiteEntries,
    int suiteId,
    int suiteTimeMs,
    List<GcEvent> unattributed,
  ) {
    final lastEndMs = spans.last.endOrStartMs - suiteTimeMs;
    for (final gc in suiteGcs) {
      final gcMs = (gc.startSeconds * 1000).round();
      // Outside every test window: isolate LOADING (kernel compile)
      // before the first start, TEARDOWN after the last end. Their
      // isolate identity is unreliable — keep them unattributed.
      if (gcMs < spans.first.startMs - suiteTimeMs || gcMs > lastEndMs) {
        unattributed.add(gc);
        continue;
      }
      final span = _spanAt(spans, gcMs, suiteTimeMs);
      if (span == null) {
        unattributed.add(gc);
        continue;
      }
      testEntries[span.id]!.gcs.add(gc);
      suiteEntries[suiteId]?.gcs.add(gc);
    }
  }

  /// The span whose isolate-clock window contains [gcMs], preferring
  /// the smallest.
  static TestSpan? _spanAt(List<TestSpan> spans, int gcMs, int suiteTimeMs) {
    TestSpan? best;
    for (final span in spans) {
      if (span.endMs == null) continue;
      if (gcMs >= span.startMs - suiteTimeMs &&
          gcMs <= span.endOrStartMs - suiteTimeMs) {
        final current = best;
        if (current == null ||
            span.endOrStartMs - span.startMs <
                current.endOrStartMs - current.startMs) {
          best = span;
        }
      }
    }
    return best;
  }
}
