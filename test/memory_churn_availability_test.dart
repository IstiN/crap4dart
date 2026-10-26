import 'package:crap4dart/src/memory/gc_log.dart';
import 'package:crap4dart/src/memory/memory_profiler.dart';
import 'package:test/test.dart';

GcEvent _gc({double newBefore = 8, double newAfter = 2}) => GcEvent(
      isolate: 'main',
      seq: 1,
      startSeconds: 1,
      newBeforeMb: newBefore,
      newAfterMb: newAfter,
      oldBeforeMb: 4,
      oldAfterMb: 5,
    );

void main() {
  test('dart entry keeps numeric churnNewMb', () {
    final entry = MemoryEntry('t')..gcs.add(_gc());
    expect(entry.churnAvailable, isTrue);
    expect(entry.toJson()['churnNewMb'], 6.0);
  });

  test('flutter entry serializes churnNewMb as null, not 0.0', () {
    final entry = MemoryEntry('t')
      ..gcs.add(_gc(newBefore: 0, newAfter: 0))
      ..allocatedBytes = 47185920;
    expect(entry.churnAvailable, isFalse);
    expect(entry.churnNewMb, 0.0); // no counters in the VM stream
    final json = entry.toJson();
    expect(json['churnNewMb'], isNull);
    expect(json['allocatedMb'], 45.0);
  });

  test('report defaults to churn available (dart engine)', () {
    final report = MemoryReport(
      testCount: 0,
      totalGcs: const [],
      suites: const [],
      tests: const [],
      unattributedGcs: const [],
    );
    expect(report.churnAvailable, isTrue);
  });
}
