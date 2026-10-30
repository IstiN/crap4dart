import 'package:crap4dart/src/memory/gc_log.dart';
import 'package:test/test.dart';

const _spawn1 = 'test_suite:file:///tmp/dart_test.kernel.abc/test.dart_1.dill: '
    'hard_threshold=8796093022208MB';
const _spawn2 = 'test_suite:file:///tmp/dart_test.kernel.abc/test.dart_2.dill: '
    'hard_threshold=8796093022208MB';

/// A table row for [isolate] (the truncated form the VM prints).
String _row(String isolate, int seq, String start,
    {double newBefore = 4.2, double newAfter = 0.4, double oldDelta = 0.0}) {
  final oldBefore = 36.5;
  final oldAfter = oldBefore + oldDelta;
  return '[ $isolate,  Scavenge( new space), ${seq.toString().padLeft(4)}, '
      '$start,  0.1, ${newBefore.toStringAsFixed(1)}, '
      '${newAfter.toStringAsFixed(1)},  1.5,  1.5, 0.0, 0.0, '
      '${oldBefore.toStringAsFixed(1)}, ${oldAfter.toStringAsFixed(1)}, '
      '38.0, 38.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ]';
}

void main() {
  group('GcLogParser', () {
    test('rows are recognized and parsed', () {
      final events = GcLogParser.parse([_row('test_suite:fi', 1, ' 0.09')]);
      expect(events, hasLength(1));
      expect(events.single.seq, 1);
      expect(events.single.newBeforeMb, 4.2);
      expect(events.single.reclaimedNewMb, closeTo(3.8, 0.001));
    });

    test('announcement lines switch the current isolate', () {
      final events = GcLogParser.parse([
        _spawn1,
        _row('test_suite:fi', 1, ' 0.10'),
        _spawn2,
        _row('test_suite:fi', 1, ' 5.00'),
      ]);
      expect(events, hasLength(2));
      expect(events[0].isolate, contains('test.dart_1.dill'));
      expect(events[1].isolate, contains('test.dart_2.dill'));
      expect(events[1].startSeconds, 5.0);
    });

    test(
        'a straggler row before the new isolate opens returns to the '
        'previous isolate', () {
      final events = GcLogParser.parse([
        _spawn1,
        _row('test_suite:fi', 1, ' 0.10'),
        _row('test_suite:fi', 2, ' 0.20'),
        // The next suite's spawn is announced, but the row that follows
        // carries seq 3 — isolate 2 has not shown seq 1 yet, so the row
        // is a late flush of isolate 1.
        _spawn2,
        _row('test_suite:fi', 3, ' 0.25'),
        _row('test_suite:fi', 1, ' 0.40'),
      ]);
      expect(events, hasLength(4));
      expect(events[2].isolate, contains('test.dart_1.dill'));
      expect(events[3].isolate, contains('test.dart_2.dill'));
    });

    test('main-isolate rows before any announcement keep their name', () {
      final events = GcLogParser.parse([
        _row('main', 1, ' 0.08'),
        _spawn1,
        _row('test_suite:fi', 1, ' 0.10'),
      ]);
      expect(events, hasLength(2));
      expect(events[0].isolate, 'main');
    });

    test('old-gen deltas are signed', () {
      final events = GcLogParser.parse([
        _row('main', 1, ' 0.08', oldDelta: 1.5),
      ]);
      expect(events.single.oldDeltaMb, closeTo(1.5, 0.001));
    });
  });
}
