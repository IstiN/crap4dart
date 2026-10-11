import 'package:crap4dart/src/analysis/method_extractor.dart';
import 'package:crap4dart/src/crap/crap_analyzer.dart';
import 'package:crap4dart/src/crap/crap_report.dart';
import 'package:test/test.dart';

MethodMetrics _metric({double? coverage, double? crap, int complexity = 1}) =>
    MethodMetrics(
      method: const MethodInfo(
        className: topLevelClassName,
        methodName: 'f',
        startLine: 1,
        endLine: 1,
        filePath: 'lib/f.dart',
      ),
      complexity: complexity,
      coverage: coverage,
      branchCoverage: coverage,
      crap: crap,
    );

void main() {
  group('CrapReport mutation survivors', () {
    test('threshold comparison is strict (tie does not exceed)', () {
      final report = CrapReport([_metric(crap: 6.0)]);
      expect(report.maxCrap, 6.0);
      expect(report.isThresholdExceeded(6.0), isFalse);
      expect(report.isThresholdExceeded(5.99), isTrue);
      expect(report.isThresholdExceeded(8.0), isFalse);
    });

    test('maxCrap ignores N/A entries', () {
      final report = CrapReport([
        _metric(),
        _metric(crap: 3.5, coverage: 0.5),
        _metric(),
      ]);
      expect(report.maxCrap, 3.5);
    });

    test('renders coverage percents with exactly one decimal', () {
      final report = CrapReport([
        _metric(crap: 1.0, coverage: 0.829),
        _metric(crap: 2.0, coverage: 1.0),
        _metric(),
      ]);
      final output = report.render();
      expect(output, contains('82.9'));
      expect(output, contains('100.0'));
      expect(output, contains('N/A'));
    });

    test('numeric CRAP sorts before N/A regardless of input order', () {
      // Dart's List.sort is sign-based (binary insertion): the N/A-vs-
      // numeric comparator branch is only exercised when an N/A entry
      // sits AFTER a numeric one in the input.
      final numeric = _metric(crap: 2.0, coverage: 0.5);
      final na = _metric();
      for (final input in [
        [na, numeric],
        [numeric, na],
      ]) {
        expect(CrapReport(input).sorted.first.crap, 2.0);
      }
    });
  });
}
