import 'dart:io';

import 'package:crap4dart/src/crap/crap_analyzer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'crap_test_fixture.dart';

void main() {
  group('CrapAnalyzer mutation survivors', () {
    late Directory dir;

    setUp(() {
      dir = createCrapTestProject();
      writeSampleProject(dir);
    });

    tearDown(() {
      dir.deleteSync(recursive: true);
    });

    test('countLambdas defaults to true', () {
      File(p.join(dir.path, 'lib', 'lambdas.dart')).writeAsStringSync('''
int f(List<int> xs) => xs.where((e) => e > 0 && e.isEven).length;
''');
      final file = p.join(dir.path, 'lib', 'lambdas.dart');
      const analyzer = CrapAnalyzer();
      final byDefault = analyzer.analyze([file]).single.complexity;
      final without =
          analyzer.analyze([file], countLambdas: false).single.complexity;
      final withTrue =
          analyzer.analyze([file], countLambdas: true).single.complexity;
      expect(byDefault, greaterThan(without));
      expect(byDefault, withTrue);
    });

    test('absolute LCOV entries are ignored without a project root', () {
      // A coverage record naming the sample file by ABSOLUTE path. Without
      // a project root the parser cannot relativize it, and the analyzer
      // must not trust absolute paths (dependency/pub-cache records) —
      // with a root the same record is attributed.
      final lcov = File(p.join(dir.path, 'coverage', 'abs.info'))
        ..writeAsStringSync('''
SF:${sampleFile(dir)}
DA:9,1
DA:10,1
end_of_record
''');
      const analyzer = CrapAnalyzer();
      final untrusted = analyzer.analyze(
        [sampleFile(dir)],
        lcovPath: lcov.path,
      );
      expect(
        untrusted.map((m) => m.coverage),
        everyElement(isNull),
      );
      final trusted = analyzer.analyze(
        [sampleFile(dir)],
        lcovPath: lcov.path,
        projectRoot: dir.path,
      );
      expect(
        trusted.map((m) => m.coverage),
        isNot(everyElement(isNull)),
      );
    });
  });
}
