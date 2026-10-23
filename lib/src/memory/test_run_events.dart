import '../common/constants.dart';
import 'dart:convert';

/// A suite (test file) seen in the package:test JSON reporter stream.
class TestSuiteEvent {
  /// Creates a [TestSuiteEvent].
  const TestSuiteEvent({required this.id, required this.path, this.timeMs = 0});

  /// Suite id from the reporter.
  final int id;

  /// Test file path as reported.
  final String path;

  /// The `suite` event time, ms since run start — the moment the
  /// suite's isolate spawns. GC rows count THEIR time from isolate
  /// start, so this value is the isolate-clock zero in reporter time.
  final int timeMs;
}

/// One test's span: name, suite, start/end times (ms since suite run
/// start) and result.
class TestSpan {
  /// Creates a [TestSpan].
  TestSpan({
    required this.id,
    required this.name,
    required this.suiteId,
    required this.startMs,
  });

  /// Test id from the reporter.
  final int id;

  /// Full test name (group prefixes included).
  final String name;

  /// Owning suite id.
  final int suiteId;

  /// `testStart` time, ms since run start.
  final int startMs;

  /// `testDone` time, ms since run start; `null` until done.
  int? endMs;

  /// `success` / `failure` / `error`; `null` until done.
  String? result;

  /// The span's end in ms ([endMs] once known, else [startMs]).
  int get endOrStartMs => endMs ?? startMs;
}

/// Parses the package:test `-r json` stream (one JSON object per line).
class TestRunEvents {
  /// Creates a parser.
  TestRunEvents();

  /// Suites in first-seen order, keyed by id.
  final Map<int, TestSuiteEvent> suitesById = {};

  /// Test spans in start order, keyed by test id.
  final Map<int, TestSpan> spansById = {};

  /// The `done` time of the whole run, ms; `null` until seen.
  int? doneMs;

  /// Feeds one output line; ignores non-JSON noise.
  void addLine(String line) {
    final trimmed = line.trimLeft();
    if (!trimmed.startsWith('{')) return;
    Map<String, dynamic> event;
    try {
      event = jsonDecode(trimmed) as Map<String, dynamic>;
    } on FormatException {
      return;
    }
    final type = event['type'] as String?;
    switch (type) {
      case 'suite':
        _addSuite(event);
      case 'testStart':
        _addTestStart(event);
      case 'testDone':
        _addTestDone(event);
      case 'done':
        doneMs = event['time'] as int? ?? doneMs;
    }
  }

  void _addSuite(Map<String, dynamic> event) {
    final suite = event['suite'] as Map<String, dynamic>?;
    if (suite == null) return;
    final id = suite['id'] as int?;
    final path = suite['path'] as String?;
    if (id == null || path == null) return;
    suitesById.putIfAbsent(
      id,
      () => TestSuiteEvent(
          id: id, path: path, timeMs: event['time'] as int? ?? 0),
    );
  }

  void _addTestStart(Map<String, dynamic> event) {
    final test = event['test'] as Map<String, dynamic>?;
    final time = event['time'] as int?;
    if (test == null || time == null) return;
    final id = test['id'] as int?;
    final name = test['name'] as String?;
    final suiteId = test['suiteID'] as int?;
    if (id == null || name == null || suiteId == null) return;
    if (name.startsWith('loading ') && name.endsWith(dartFileExtension)) {
      return;
    }
    spansById.putIfAbsent(
      id,
      () => TestSpan(id: id, name: name, suiteId: suiteId, startMs: time),
    );
  }

  void _addTestDone(Map<String, dynamic> event) {
    final id = event['testID'] as int?;
    final time = event['time'] as int?;
    final result = event['result'] as String?;
    if (id == null || time == null) return;
    final span = spansById[id];
    if (span == null) return;
    span.endMs = time;
    span.result = result ?? span.result;
  }
}
