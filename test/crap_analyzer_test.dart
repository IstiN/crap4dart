import 'dart:io';

import 'package:crap4dart/src/crap/crap_analyzer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'crap_test_fixture.dart';

void main() {
  group('CrapAnalyzer (integration)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = createCrapTestProject();
      writeSampleProject(tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('combines complexity, coverage and CRAP per method', () {
      final metrics = const CrapAnalyzer().analyze(
        [sampleFile(tempDir)],
        lcovPath: sampleLcov(tempDir),
        projectRoot: tempDir.path,
      );
      expect(metrics, hasLength(2));

      final byName = {for (final m in metrics) m.method.methodName: m};
      final uncovered = byName['uncovered']!;
      expect(uncovered.complexity, 2);
      expect(uncovered.coverage, 0.0);
      expect(uncovered.branchCoverage, 0.5);
      expect(uncovered.crap, 6.0);

      final covered = byName['covered']!;
      expect(covered.complexity, 1);
      expect(covered.coverage, 1.0);
      expect(covered.crap, 1.0);
    });

    test('reports N/A when no lcov data is available', () {
      final metrics = const CrapAnalyzer().analyze(
        [sampleFile(tempDir)],
        lcovPath: p.join(tempDir.path, 'coverage', 'missing.info'),
        projectRoot: tempDir.path,
      );
      expect(metrics, hasLength(2));
      for (final m in metrics) {
        expect(m.coverage, isNull);
        expect(m.branchCoverage, isNull);
        expect(m.crap, isNull);
      }
    });
  });
}
