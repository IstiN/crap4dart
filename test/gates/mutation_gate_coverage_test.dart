import 'dart:io';

import 'package:crap4dart/src/coverage/lcov_parser.dart';
import 'package:crap4dart/src/gates/mutation_engine.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';
import 'mutation_gate_fixtures.dart';

const topLevelSource = '''
final total = 1 + 2;
''';

void main() {
  late Directory project;

  setUp(() {
    project = createTempProject();
    writeFile(project, 'test/a_test.dart', 'void main() {}\n');
  });

  tearDown(() => project.deleteSync(recursive: true));

  test('files missing from the LCOV data contribute no covered sites',
      () async {
    writeFile(project, 'lib/a.dart', mutationFixtureSource);
    var calls = 0;
    final result = await mutationGateWith((root, timeout, args) async {
      calls++;
      return MutantOutcome.killed;
    }).run(
      makeContext(
        project,
        ['lib/a.dart'],
        lcov: const LcovParser()
            .parse('SF:lib/other.dart\nDA:1,1\nend_of_record\n'),
      ),
    );
    expect(calls, 0);
    expect(result.passed, isTrue);
    expect(result.summary, contains('no covered mutation sites'));
  });

  test('sites outside methods fall back to line coverage', () async {
    writeFile(project, 'lib/t.dart', topLevelSource);
    var calls = 0;
    final result = await mutationGateWith((root, timeout, args) async {
      calls++;
      return MutantOutcome.killed;
    }).run(
      makeContext(
        project,
        ['lib/t.dart'],
        lcov:
            const LcovParser().parse('SF:lib/t.dart\nDA:1,1\nend_of_record\n'),
      ),
    );
    expect(calls, 2);
    expect(result.passed, isTrue);
    expect(result.summary, contains('score 100.0%'));
  });

  test('uncovered lines outside methods exclude the site', () async {
    writeFile(project, 'lib/t.dart', topLevelSource);
    var calls = 0;
    final result = await mutationGateWith((root, timeout, args) async {
      calls++;
      return MutantOutcome.killed;
    }).run(
      makeContext(
        project,
        ['lib/t.dart'],
        lcov:
            const LcovParser().parse('SF:lib/t.dart\nDA:1,0\nend_of_record\n'),
      ),
    );
    expect(calls, 0);
    expect(result.summary, contains('2 uncovered'));
  });
}
