import 'dart:convert';

import 'package:crap4dart/src/analysis/method_extractor.dart';
import 'package:crap4dart/src/crap/crap_analyzer.dart';
import 'package:crap4dart/src/crap/crap_report.dart';
import 'package:crap4dart/src/report/json_reporter.dart';
import 'package:test/test.dart';

/// Builds a [MethodMetrics] with a synthetic method and CRAP from the
/// formula (null when coverage is null).
MethodMetrics buildMetrics({
  required String name,
  required int complexity,
  double? coverage,
  double? branchCoverage,
}) =>
    MethodMetrics(
      method: MethodInfo(
        className: 'Foo',
        methodName: name,
        startLine: 12,
        endLine: 20,
        filePath: 'lib/foo.dart',
      ),
      complexity: complexity,
      coverage: coverage,
      branchCoverage: branchCoverage,
      crap: coverage == null
          ? null
          : complexity *
                  complexity *
                  (1 - coverage) *
                  (1 - coverage) *
                  (1 - coverage) +
              complexity,
    );

void main() {
  const reporter = JsonReporter();

  group('renderAnalyze', () {
    test('serializes methods in CRAP-descending order with nulls', () {
      final report = CrapReport([
        buildMetrics(name: 'noCoverage', complexity: 5),
        buildMetrics(name: 'covered', complexity: 2, coverage: 1.0),
        buildMetrics(
          name: 'risky',
          complexity: 3,
          coverage: 0.5,
          branchCoverage: 0.75,
        ),
      ]);
      final json = jsonDecode(reporter.renderAnalyze(report, threshold: 8.0))
          as Map<String, dynamic>;
      expect(json['command'], 'analyze');
      expect(json['threshold'], 8.0);
      expect(json['passed'], isTrue);
      // risky: 9 * 0.125 + 3 = 4.125; covered: 2.0; N/A last.
      expect(json['maxCrap'], closeTo(4.125, 1e-9));
      final methods = json['methods'] as List<dynamic>;
      expect(
        methods.map((m) => m['method']),
        ['risky', 'covered', 'noCoverage'],
      );
      final risky = methods[0] as Map<String, dynamic>;
      expect(risky['file'], 'lib/foo.dart');
      expect(risky['line'], 12);
      expect(risky['class'], 'Foo');
      expect(risky['complexity'], 3);
      expect(risky['lineCoverage'], 0.5);
      expect(risky['branchCoverage'], 0.75);
      expect(risky['crap'], closeTo(4.125, 1e-9));
      final na = methods[2] as Map<String, dynamic>;
      expect(na['lineCoverage'], isNull);
      expect(na['branchCoverage'], isNull);
      expect(na['crap'], isNull);
    });

    test('passed is false when the threshold is exceeded', () {
      final report = CrapReport([
        buildMetrics(name: 'risky', complexity: 3, coverage: 0.0),
      ]);
      final json = jsonDecode(reporter.renderAnalyze(report, threshold: 8.0))
          as Map<String, dynamic>;
      expect(json['passed'], isFalse);
      expect(json['maxCrap'], 12.0);
    });
  });
}
