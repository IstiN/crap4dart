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

  /// Reclaimed new-gen volume — the honest "allocated MB" proxy.
  double get churnNewMb => gcs.fold(0, (sum, gc) => sum + gc.reclaimedNewMb);

  /// Signed old-gen growth: positive and never freed = leak suspect.
  double get oldGrowthMb => gcs.fold(0, (sum, gc) => sum + gc.oldDeltaMb);

  /// The JSON shape of this entry.
  Map<String, dynamic> toJson() => {
        'label': label,
        if (suitePath != null) 'suite': suitePath,
        'gcs': gcs.length,
        'churnNewMb': double.parse(churnNewMb.toStringAsFixed(1)),
        'oldGrowthMb': double.parse(oldGrowthMb.toStringAsFixed(1)),
      };
}

/// The full memory report of one suite run.
class MemoryReport {
  /// Creates a [MemoryReport].
  MemoryReport({
    required this.testCount,
    required this.totalGcs,
    required this.suites,
    required this.tests,
    required this.clockOffsetSeconds,
  });

  /// Tests executed (spans with a result).
  final int testCount;

  /// All GC events of test isolates.
  final List<GcEvent> totalGcs;

  /// Per-suite entries.
  final List<MemoryEntry> suites;

  /// Per-test entries.
  final List<MemoryEntry> tests;

  /// The estimated offset between the GC clock (VM monotonic seconds)
  /// and the reporter clock (ms since run start) — for transparency.
  final double clockOffsetSeconds;

  /// Tests with GC activity, sorted by allocation churn, descending.
  List<MemoryEntry> get topChurn => [
        for (final test in tests)
          if (test.gcs.isNotEmpty) test,
      ]..sort((a, b) => b.churnNewMb.compareTo(a.churnNewMb));

  /// Tests with GC activity, sorted by old-gen growth, descending
  /// (leak suspects first).
  List<MemoryEntry> get topOldGrowth => [
        for (final test in tests)
          if (test.gcs.isNotEmpty) test,
      ]..sort((a, b) => b.oldGrowthMb.compareTo(a.oldGrowthMb));

  /// Total reclaimed new-gen MB across all GCs.
  double get totalChurnMb =>
      totalGcs.fold(0, (sum, gc) => sum + gc.reclaimedNewMb);

  /// Net old-gen growth of the run.
  double get totalOldGrowthMb =>
      totalGcs.fold(0, (sum, gc) => sum + gc.oldDeltaMb);
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
    final gcsBySuite = _gcsBySuite(
      gcs,
      isolateToSuite,
      suiteEntries,
    );
    final offset = _globalOffset(gcsBySuite, spansBySuite);
    for (final entry in gcsBySuite.entries) {
      final spans = spansBySuite[entry.key];
      if (spans == null || spans.isEmpty) continue;
      _assignSuiteGcs(entry.value, spans, testEntries, offset);
    }
    final tests =
        testEntries.values.where((entry) => entry.label.isNotEmpty).toList();
    return MemoryReport(
      testCount:
          events.spansById.values.where((span) => span.result != null).length,
      totalGcs: gcs,
      suites: suiteEntries.values.toList(),
      tests: tests,
      clockOffsetSeconds: offset,
    );
  }

  /// GCs grouped by suite id; also lands every GC on its suite entry.
  static Map<int, List<GcEvent>> _gcsBySuite(
    List<GcEvent> gcs,
    Map<String, TestSuiteEvent> isolateToSuite,
    Map<int, MemoryEntry> suiteEntries,
  ) {
    final gcsBySuite = <int, List<GcEvent>>{};
    for (final gc in gcs) {
      final suite = isolateToSuite[gc.isolate];
      if (suite == null) continue;
      suiteEntries[suite.id]?.gcs.add(gc);
      gcsBySuite.putIfAbsent(suite.id, () => []).add(gc);
    }
    return gcsBySuite;
  }

  /// One GLOBAL offset (GC clock − reporter clock), voted per suite by
  /// (last GC of the file − end of its last test). A file whose last
  /// GC fires well before its last test ends votes BELOW the true
  /// offset, and a rare post-end teardown GC votes above it; the 90th
  /// percentile sits just under the truth and ignores both tails —
  /// and unlike first-GC anchors, loading GCs cannot pollute these
  /// pairs.
  static double _globalOffset(
    Map<int, List<GcEvent>> gcsBySuite,
    Map<int, List<TestSpan>> spansBySuite,
  ) {
    final votes = <double>[];
    for (final entry in gcsBySuite.entries) {
      final spans = spansBySuite[entry.key];
      if (spans == null || spans.isEmpty) continue;
      final lastGc = entry.value
          .reduce((a, b) => a.startSeconds >= b.startSeconds ? a : b);
      votes.add(lastGc.startSeconds - spans.last.endOrStartMs / 1000);
    }
    if (votes.isEmpty) return 0.0;
    votes.sort();
    return votes[(votes.length * 0.9).floor().clamp(0, votes.length - 1)];
  }

  /// Assigns one suite's GCs to its tests using the global [offset].
  static void _assignSuiteGcs(
    List<GcEvent> suiteGcs,
    List<TestSpan> spans,
    Map<int, MemoryEntry> testEntries,
    double offset,
  ) {
    for (final gc in suiteGcs) {
      final gcMs = ((gc.startSeconds - offset) * 1000).round();
      // Before the first test start: isolate LOADING (kernel
      // compilation) — file total only, not any test's.
      if (gcMs < spans.first.startMs) continue;
      final span = _spanAt(spans, gcMs);
      testEntries[span?.id]?.gcs.add(gc);
    }
  }

  /// The span whose window contains [gcMs], preferring the smallest.
  static TestSpan? _spanAt(List<TestSpan> spans, int gcMs) {
    TestSpan? best;
    for (final span in spans) {
      if (span.endMs == null) continue;
      if (gcMs >= span.startMs && gcMs <= span.endOrStartMs) {
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
