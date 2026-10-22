import 'package:crap4dart/src/memory/memory_profiler.dart';
import 'package:test/test.dart';

import 'gc_log_fixtures.dart';

void main() {
  group('MemoryProfiler.reportFromStreams', () {
    test('attributes GCs to suites by dill index and to tests by window', () {
      final report = MemoryProfiler().reportFromStreams(
        (stdoutText: kTwoSuiteJson, stderrText: kTwoSuiteGcLog),
      );
      expect(report.testCount, 2);
      final byPath = {
        for (final suite in report.suites) suite.label: suite,
      };
      // Suite 1 (heavy test): its isolate reclaimed 3.8 MB.
      expect(byPath['test/heavy_test.dart']!.churnNewMb, closeTo(3.8, 0.01));
      // Suite 2 (light test): 1.8 MB in-window + 1.0 MB loading GC
      // (loading rows count towards the file total, never a test).
      expect(byPath['test/light_test.dart']!.churnNewMb, closeTo(2.8, 0.01));
      // Per-test: each file has a single test owning its GCs.
      final heavy =
          report.tests.singleWhere((t) => t.label == 'heavy allocates a lot');
      expect(heavy.suitePath, 'test/heavy_test.dart');
      expect(heavy.gcs, isNotEmpty);
    });

    test('GCs before the first test start stay out of every test', () {
      final report = MemoryProfiler().reportFromStreams(
        (stdoutText: kTwoSuiteJson, stderrText: kTwoSuiteGcLog),
      );
      final loading =
          report.tests.singleWhere((t) => t.label == 'light test stays quiet');
      // The loading-time GC (before the first testStart of suite 2) is
      // file-total only; the test owns just its in-window GC (1.8 MB).
      expect(loading.churnNewMb, closeTo(1.8, 0.01));
    });

    test('a GC inside nested test windows lands on the shorter span', () {
      final report = MemoryProfiler().reportFromStreams(
        (stdoutText: kNestedSpansJson, stderrText: kNestedSpansGcLog),
      );
      final inner =
          report.tests.singleWhere((t) => t.label == 'inner short test');
      final outer =
          report.tests.singleWhere((t) => t.label == 'outer long test');
      expect(inner.gcs, hasLength(1));
      expect(outer.gcs, isEmpty);
    });

    test('stragglers at a spawn boundary return to the previous file', () {
      final report = MemoryProfiler().reportFromStreams(
        (stdoutText: kTwoSuiteJson, stderrText: kStragglerGcLog),
      );
      final byPath = {
        for (final suite in report.suites) suite.label: suite,
      };
      // The seq-2 row after suite 2's spawn belongs to suite 1; only
      // suite 2's own seq-1 row (1.0 MB) stays with it.
      expect(
        byPath['test/heavy_test.dart']!.churnNewMb,
        closeTo(3.8 + 2.0, 0.01),
      );
      expect(byPath['test/light_test.dart']!.churnNewMb, closeTo(1.0, 0.01));
    });
  });
}
