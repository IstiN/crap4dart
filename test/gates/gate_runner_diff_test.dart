import 'dart:io';

import 'package:crap4dart/src/files/diff_parser.dart';
import 'package:crap4dart/src/gates/gate_runner.dart';
import 'package:test/test.dart';

import 'gate_test_utils.dart';

void main() {
  late Directory project;

  setUp(() {
    project = createTempProject();
  });

  tearDown(() {
    project.deleteSync(recursive: true);
  });

  DiffLineMap diff(Map<String, Set<int>> added) =>
      DiffLineMap(projectRoot: project.path, addedLines: added);

  test('violations on unchanged lines are filtered out', () async {
    writeFile(project, 'lib/a.dart', 'void undocumented() {}\n');
    final result = await GateRunner().run(
      makeContext(project, ['lib/a.dart']),
      only: {'public_docs'},
      diff: diff({
        'lib/a.dart': {9},
      }),
    );
    expect(result.passed, isTrue);
    expect(result.diffMode, isTrue);
  });

  test('violations on changed lines survive', () async {
    writeFile(project, 'lib/a.dart', 'void undocumented() {}\n');
    final result = await GateRunner().run(
      makeContext(project, ['lib/a.dart']),
      only: {'public_docs'},
      diff: diff({
        'lib/a.dart': {1},
      }),
    );
    expect(result.passed, isFalse);
    expect(result.results.single.violations, hasLength(1));
  });

  test('file-level violations need real changes to survive', () async {
    final filler = List.filled(150, '// filler\n').join();
    writeFile(project, 'lib/a.dart', filler);
    const config = 'gates:\n  loc:\n    max_lines: 100\n';
    final deletedOnly = await GateRunner().run(
      makeContext(project, ['lib/a.dart'], configYaml: config),
      only: {'loc'},
      diff: diff({
        'lib/a.dart': <int>{},
      }),
    );
    expect(deletedOnly.passed, isTrue);
    final withChanges = await GateRunner().run(
      makeContext(project, ['lib/a.dart'], configYaml: config),
      only: {'loc'},
      diff: diff({
        'lib/a.dart': {5},
      }),
    );
    expect(withChanges.passed, isFalse);
  });

  test('render marks gates in diff mode', () async {
    writeFile(project, 'lib/a.dart', 'void undocumented() {}\n');
    final result = await GateRunner().run(
      makeContext(project, ['lib/a.dart']),
      only: {'public_docs'},
      diff: diff({
        'lib/a.dart': {1},
      }),
    );
    final output = GateRunner().render(result);
    expect(output, contains('[FAIL] public_docs'));
    expect(output, contains('(diff mode)'));
  });
}
