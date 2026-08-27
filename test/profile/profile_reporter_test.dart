import 'package:test/test.dart';

import 'profile_test_data.dart';

void main() {
  group('ProfileReport', () {
    test('sorted by totalMicros descending', () {
      final report = reportFor([
        timing('bar', calls: 100, totalMicros: 5000),
        timing('baz', calls: 10, totalMicros: 500),
      ]);
      final sorted = report.sorted;
      expect(sorted.first.timing.totalMicros, 5000);
      expect(sorted.last.timing.totalMicros, 500);
    });

    test('render includes table headers', () {
      final rendered = reportFor([
        timing(
          'bar',
          calls: 100,
          totalMicros: 5000,
          minMicros: 10,
          maxMicros: 200,
        ),
      ]).render();
      expect(rendered, contains('TOTAL'));
      expect(rendered, contains('SELF'));
      expect(rendered, contains('CALLS'));
      expect(rendered, contains('@60fps'));
      expect(rendered, contains('Foo.bar'));
    });

    test('render with threshold', () {
      final rendered = reportFor([
        timing(
          'bar',
          calls: 100,
          totalMicros: 500000,
          minMicros: 1000,
          maxMicros: 10000,
        ),
      ]).render(thresholdMs: 100.0);
      expect(rendered, contains('1 method exceeds'));
    });

    test('render formats huge totals with adaptive units', () {
      // Tens of billions of calls on a hot loop used to render TOTAL as
      // `50000000.00` — a wall of digits blowing the column width up.
      final rendered = reportFor(hugeTimingFixtures).render();
      expect(rendered, contains('TOTAL'));
      expect(rendered, contains('SELF'));
      expect(rendered, contains('13.89h')); // 5e7 ms — hours tier
      expect(rendered, contains('total 13.89h')); // summary line
      expect(rendered, contains('2.50s')); // 2500 ms — seconds tier
      expect(rendered, isNot(contains('50000000.00')));
    });

    test('render shows self time from timing data', () {
      final rendered = reportFor([
        timing(
          'bar',
          calls: 100,
          totalMicros: 5000000, // 5s inclusive
          totalSelfMicros: 2000000, // 2s self
        ),
      ]).render();
      expect(rendered, contains('5.00s')); // TOTAL inclusive
      expect(rendered, contains('2.00s')); // SELF
    });
  });
}
