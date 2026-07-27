import 'dart:io';

import 'package:crap4dart/src/crap/crap_analyzer.dart';
import 'package:crap4dart/src/crap/crap_report.dart';
import 'package:test/test.dart';

import 'crap_test_fixture.dart';

void main() {
  group('CrapReport', () {
    late Directory tempDir;

    setUp(() {
      tempDir = createCrapTestProject();
      writeSampleProject(tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    List<MethodMetrics> analyzeFixture({bool withLcov = true}) =>
        const CrapAnalyzer().analyze(
          [sampleFile(tempDir)],
          lcovPath: withLcov ? sampleLcov(tempDir) : null,
          projectRoot: tempDir.path,
        );

    test('sorts numeric CRAP first, N/A last', () {
      final report = CrapReport([
        ...analyzeFixture(withLcov: false),
        ...analyzeFixture(),
      ]);
      final sorted = report.sorted;
      expect(sorted.first.crap, 6.0);
      expect(sorted[1].crap, 1.0);
      expect(sorted.skip(2).every((m) => m.crap == null), isTrue);
      expect(report.maxCrap, 6.0);
      expect(report.isThresholdExceeded(8.0), isFalse);
      expect(report.isThresholdExceeded(5.0), isTrue);
    });

    test('renders a table with a summary line', () {
      final output = CrapReport(analyzeFixture()).render();
      expect(output, contains('CRAP'));
      expect(output, contains('COV%'));
      expect(output, contains('(top-level).uncovered'));
      expect(output, contains('6.00'));
      expect(output, contains('Max CRAP: 6.00 — OK (threshold: 8.00)'));
    });
  });
}
