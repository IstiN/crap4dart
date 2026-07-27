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

  test('skips when lcov is missing and coverage is not required', () async {
    final result = await gate.run(
      makeContext(
        project,
        const [],
        configYaml: 'coverage:\n  required: false\n',
      ),
    );
    expect(result.skipped, isTrue);
    expect(result.skipReason, contains('no coverage data'));
  });

  test('fails when lcov is missing and coverage is required', () async {
    final result = await gate.run(makeContext(project, const []));
    expect(result.passed, isFalse);
    expect(result.violations.single.message, contains('no coverage data'));
  });

  test('passes when total coverage meets the minimum', () async {
    final lcov = parseLcov(
      'SF:lib/a.dart\nDA:1,1\nDA:2,1\nDA:3,0\nDA:4,1\nend_of_record\n',
    );
    final result = await gate.run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n  test_coverage:\n    min_percent: 70.0\n',
        lcov: lcov,
      ),
    );
    expect(result.passed, isTrue);
    expect(result.summary, contains('75.0%'));
  });

  test('fails below the minimum, per-file violations when per_file', () async {
    final lcov = parseLcov(
      'SF:lib/a.dart\nDA:1,1\nDA:2,0\nDA:3,0\nDA:4,0\nend_of_record\n'
      'SF:lib/b.dart\nDA:1,1\nDA:2,1\nDA:3,1\nDA:4,1\nDA:5,0\nend_of_record\n',
    );
    final result = await gate.run(
      makeContext(
        project,
        const [],
        configYaml: 'gates:\n'
            '  test_coverage:\n'
            '    min_percent: 80.0\n'
            '    per_file: true\n',
        lcov: lcov,
      ),
    );
    expect(result.passed, isFalse);
    // Total violation + one per-file violation (a.dart 25% < 80%).
    expect(result.violations, hasLength(2));
    expect(result.violations[0].message, contains('total coverage'));
    expect(result.violations[1].file, 'lib/a.dart');
    expect(result.violations[1].message, contains('25.0%'));
  });
}
