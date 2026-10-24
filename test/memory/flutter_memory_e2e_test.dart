import 'dart:io';

import 'package:crap4dart/src/memory/flutter_memory.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// End-to-end coverage of the Flutter measurement path: a fake
/// `flutter` tool prints the spawn trace, and a fake `flutter_tester`
/// (real WebSockets, real protocol) runs one test against the driver
/// while a fake VM Service reports allocation and one GC event.
void main() {
  test('runFlutterMemory measures the traced spawn', () async {
    final root = Directory.systemTemp.createTempSync('crap4dart_flmem');
    addTearDown(() {
      try {
        root.deleteSync(recursive: true);
      } on Object {
        // best effort
      }
    });
    // Under `dart test` Platform.script points at a temp kernel copy —
    // resolve the fixture from the working directory instead.
    final fixtureDir = p.absolute('test/memory/fixtures');
    final notes = <String>[];
    final report = await runFlutterMemory(
      root.path,
      notes.add,
      flutterBinary: 'dart',
      toolArgs: [p.join(fixtureDir, 'fake_flutter_tool.dart')],
    );
    expect(report.suites, hasLength(1), reason: notes.join('\n'));
    expect(report.tests, hasLength(1));
    expect(report.tests.single.label, contains('fake churns'));
    expect(report.tests.single.allocatedMb, closeTo(45, 1));
    expect(report.tests.single.gcs, hasLength(1));
    expect(report.totalAllocatedMb, greaterThan(40));
    // The VM Service GC stream has no reclaimed-new-gen counters:
    // churn must surface as unavailable (null), never as a fake 0.0.
    expect(report.churnAvailable, isFalse);
    expect(report.tests.single.churnAvailable, isFalse);
    expect(report.tests.single.toJson()['churnNewMb'], isNull);
    expect(report.suites.single.toJson()['churnNewMb'], isNull);
    expect(report.tests.single.toJson()['allocatedMb'], isNotNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
