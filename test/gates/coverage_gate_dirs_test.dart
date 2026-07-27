import 'dart:io';

import 'package:crap4dart/src/coverage/lcov_parser.dart';
import 'package:crap4dart/src/gates/coverage_gate.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  const gate = CoverageGate();

  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  List<FileCoverage> parseLcov(String content) =>
      const LcovParser().parse(content);

  test('ignores coverage entries outside the project (e.g. .pub-cache)',
      () async {
    // Raw "dart test --coverage" output contains entries for dependencies
    // under .pub-cache; their paths contain a "lib" segment but are not
    // project sources and must not dilute the aggregate percentage.
    final lcov = parseLcov(
      'SF:/Users/x/.pub-cache/hosted/pub.dev/some_pkg-1.0/lib/src/dep.dart\n'
      'DA:1,0\nDA:2,0\nDA:3,0\nDA:4,0\nDA:5,0\nDA:6,0\nDA:7,0\nDA:8,0\n'
      'end_of_record\n'
      'SF:lib/a.dart\nDA:1,1\nDA:2,1\nend_of_record\n',
    );
    final result = await gate.run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n  test_coverage:\n    min_percent: 80.0\n',
        lcov: lcov,
      ),
    );
    expect(result.passed, isTrue);
    expect(result.summary, contains('100.0%'));
  });

  test('dirs scopes the aggregate; test/** is excluded by default', () async {
    final lcov = parseLcov(
      'SF:lib/a.dart\nDA:1,1\nend_of_record\n'
      'SF:test/a_test.dart\nDA:1,0\nDA:2,0\nend_of_record\n',
    );
    final defaultResult = await gate.run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n  test_coverage:\n    min_percent: 50.0\n',
        lcov: lcov,
      ),
    );
    expect(defaultResult.passed, isTrue);
    expect(defaultResult.summary, contains('100.0%'));

    final withTestResult = await gate.run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  test_coverage:\n'
            '    min_percent: 50.0\n'
            '    dirs: [lib, test]\n',
        lcov: lcov,
      ),
    );
    expect(withTestResult.passed, isFalse);
    expect(withTestResult.summary, contains('33.3%'));
  });
}
