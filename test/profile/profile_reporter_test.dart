import 'package:crap4dart/src/profile/profile_runner.dart';
import 'package:crap4dart/src/profile/profile_reporter.dart';
import 'package:test/test.dart';

import 'profile_test_data.dart';

void main() {
  group('ProfileReport', () {
    test('sorted by totalMicros descending', () {
      final profiles = [
        MethodProfile(
          method: testMethods[0],
          timing: const MethodTiming(
            className: 'Foo',
            methodName: 'bar',
            calls: 100,
            totalMicros: 5000,
            minMicros: 10,
            maxMicros: 200,
          ),
        ),
        MethodProfile(
          method: testMethods[1],
          timing: const MethodTiming(
            className: 'Foo',
            methodName: 'baz',
            calls: 10,
            totalMicros: 500,
            minMicros: 10,
            maxMicros: 100,
          ),
        ),
      ];
      final report = ProfileReport(profiles: profiles);
      final sorted = report.sorted;
      expect(sorted.first.timing.totalMicros, 5000);
      expect(sorted.last.timing.totalMicros, 500);
    });

    test('render includes table headers', () {
      final profiles = [
        MethodProfile(
          method: testMethods[0],
          timing: const MethodTiming(
            className: 'Foo',
            methodName: 'bar',
            calls: 100,
            totalMicros: 5000,
            minMicros: 10,
            maxMicros: 200,
          ),
        ),
      ];
      final report = ProfileReport(profiles: profiles);
      final rendered = report.render();
      expect(rendered, contains('TOTAL(ms)'));
      expect(rendered, contains('CALLS'));
      expect(rendered, contains('@60fps'));
      expect(rendered, contains('Foo.bar'));
    });

    test('render with threshold', () {
      final profiles = [
        MethodProfile(
          method: testMethods[0],
          timing: const MethodTiming(
            className: 'Foo',
            methodName: 'bar',
            calls: 100,
            totalMicros: 500000,
            minMicros: 1000,
            maxMicros: 10000,
          ),
        ),
      ];
      final report = ProfileReport(profiles: profiles);
      final rendered = report.render(thresholdMs: 100.0);
      expect(rendered, contains('1 method exceeds'));
    });
  });
}
