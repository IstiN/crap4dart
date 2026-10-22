import 'dart:convert';

import 'package:crap4dart/src/memory/test_run_events.dart';
import 'package:test/test.dart';

void main() {
  group('TestRunEvents', () {
    test('suite and test events build spans', () {
      final events = TestRunEvents();
      events.addLine(jsonEncode({
        'type': 'suite',
        'suite': {'id': 0, 'path': 'test/a_test.dart'},
        'time': 100,
      }));
      events.addLine(jsonEncode({
        'type': 'testStart',
        'test': {'id': 1, 'name': 'first test', 'suiteID': 0},
        'time': 120,
      }));
      events.addLine(jsonEncode({
        'type': 'testDone',
        'testID': 1,
        'result': 'success',
        'time': 180,
      }));
      expect(events.suitesById[0]!.path, 'test/a_test.dart');
      final span = events.spansById[1]!;
      expect(span.name, 'first test');
      expect(span.startMs, 120);
      expect(span.endMs, 180);
      expect(span.result, 'success');
      expect(span.endOrStartMs, 180);
    });

    test('loading pseudo-tests are skipped', () {
      final events = TestRunEvents();
      events.addLine(jsonEncode({
        'type': 'suite',
        'suite': {'id': 0, 'path': 'test/a_test.dart'},
      }));
      events.addLine(jsonEncode({
        'type': 'testStart',
        'test': {'id': 1, 'name': 'loading test/a_test.dart', 'suiteID': 0},
        'time': 10,
      }));
      expect(events.spansById, isEmpty);
    });

    test('non-JSON noise lines are ignored', () {
      final events = TestRunEvents();
      events.addLine('00:01 +0: some test');
      events.addLine('');
      expect(events.suitesById, isEmpty);
    });

    test('done event records the run end', () {
      final events = TestRunEvents();
      events.addLine('{"type":"done","success":true,"time":900}');
      expect(events.doneMs, 900);
    });

    test('unfinished spans use start as the end estimate', () {
      final events = TestRunEvents();
      events.addLine(jsonEncode({
        'type': 'suite',
        'suite': {'id': 0, 'path': 'a'},
      }));
      events.addLine(jsonEncode({
        'type': 'testStart',
        'test': {'id': 1, 'name': 'x', 'suiteID': 0},
        'time': 42,
      }));
      expect(events.spansById[1]!.endOrStartMs, 42);
    });
  });
}
