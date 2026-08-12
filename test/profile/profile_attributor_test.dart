import 'package:crap4dart/src/profile/profile_runner.dart';
import 'package:crap4dart/src/profile/profile_reporter.dart';
import 'package:test/test.dart';

import 'profile_test_data.dart';

void main() {
  group('ProfileAttributor', () {
    test('attributes by class.method name', () {
      const attributor = ProfileAttributor();
      final timings = [
        const MethodTiming(
          className: 'Foo',
          methodName: 'bar',
          calls: 100,
          totalMicros: 5000,
          minMicros: 10,
          maxMicros: 200,
        ),
        const MethodTiming(
          className: '(top-level)',
          methodName: 'helper',
          calls: 50,
          totalMicros: 3000,
          minMicros: 20,
          maxMicros: 150,
        ),
      ];
      final result = attributor.attribute(timings, testMethods);
      expect(result, hasLength(2));

      final fooBar = result.firstWhere((p) => p.method.methodName == 'bar');
      expect(fooBar.timing.calls, 100);
      expect(fooBar.timing.totalMicros, 5000);
      expect(fooBar.timing.meanMicros, 50.0);
      expect(fooBar.timing.maxMicros, 200);

      final helper = result.firstWhere((p) => p.method.methodName == 'helper');
      expect(helper.timing.calls, 50);
    });

    test('skips timings with no matching method', () {
      const attributor = ProfileAttributor();
      final timings = [
        const MethodTiming(
          className: 'Ghost',
          methodName: 'missing',
          calls: 1,
          totalMicros: 1,
          minMicros: 1,
          maxMicros: 1,
        ),
      ];
      final result = attributor.attribute(timings, testMethods);
      expect(result, isEmpty);
    });
  });

  group('MethodTiming', () {
    test('meanMicros computes average', () {
      const t = MethodTiming(
        className: 'A',
        methodName: 'b',
        calls: 4,
        totalMicros: 1000,
        minMicros: 100,
        maxMicros: 400,
      );
      expect(t.meanMicros, 250.0);
      expect(t.totalMillis, 1.0);
    });

    test('zero calls gives zero mean', () {
      const t = MethodTiming(
        className: 'A',
        methodName: 'b',
        calls: 0,
        totalMicros: 0,
        minMicros: 0,
        maxMicros: 0,
      );
      expect(t.meanMicros, 0.0);
    });
  });
}
