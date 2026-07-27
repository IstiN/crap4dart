import 'dart:io';

import 'package:crap4dart/src/crap/crap_analyzer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'crap_test_fixture.dart';

void main() {
  group('CrapAnalyzer coverage matching', () {
    late Directory tempDir;

    setUp(() {
      tempDir = createCrapTestProject();
      writeSampleProject(tempDir);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('ignores LCOV entries outside the project root', () {
      Directory(p.join(tempDir.path, 'lib', 'src')).createSync();
      File(p.join(tempDir.path, 'lib', 'src', 'dep.dart'))
          .writeAsStringSync('int dep() => 1;\n');
      File(p.join(tempDir.path, 'coverage', 'deps.info')).writeAsStringSync(
        'SF:/Users/x/.pub-cache/hosted/pub.dev/some_pkg/lib/src/dep.dart\n'
        'DA:1,7\n'
        'end_of_record\n',
      );
      final metrics = const CrapAnalyzer().analyze(
        [p.join(tempDir.path, 'lib', 'src', 'dep.dart')],
        lcovPath: p.join(tempDir.path, 'coverage', 'deps.info'),
        projectRoot: tempDir.path,
      );
      expect(metrics, hasLength(1));
      // The pub-cache entry must not be attributed to the project file.
      expect(metrics.single.coverage, isNull);
      expect(metrics.single.crap, isNull);
    });

    test('matches coverage by suffix when the roots differ', () {
      // No projectRoot: the analyzed absolute path cannot be relativized
      // onto the LCOV key, so the suffix fallback has to match.
      final metrics = const CrapAnalyzer().analyze(
        [sampleFile(tempDir)],
        lcovPath: sampleLcov(tempDir),
      );
      final byName = {for (final m in metrics) m.method.methodName: m};
      expect(byName['uncovered']!.coverage, 0.0);
      expect(byName['uncovered']!.crap, 6.0);
      expect(byName['covered']!.coverage, 1.0);
    });

    test('reports N/A when no LCOV entry matches the file', () {
      File(p.join(tempDir.path, 'coverage', 'other.info')).writeAsStringSync(
        'SF:lib/other.dart\nDA:1,1\nend_of_record\n',
      );
      final metrics = const CrapAnalyzer().analyze(
        [sampleFile(tempDir)],
        lcovPath: p.join(tempDir.path, 'coverage', 'other.info'),
        projectRoot: tempDir.path,
      );
      expect(metrics, hasLength(2));
      for (final m in metrics) {
        expect(m.coverage, isNull);
        expect(m.crap, isNull);
      }
    });
  });
}
