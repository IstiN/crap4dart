import 'dart:io';

import 'package:test/test.dart';

import 'duplication_normalization_fixtures.dart';
import 'duplication_normalization_helpers.dart';
import 'gate_test_utils.dart';

void main() {
  late Directory project;

  setUp(() => project = createTempProject());

  tearDown(() => project.deleteSync(recursive: true));

  test('swapped locals never match', () async {
    final result = await runPair(
      project,
      swappable('calc', 'a', 'b', 'total'),
      swapped('calc', 'x', 'y', 'sum'),
      ignoreLocals: true,
    );
    expect(result.passed, isTrue,
        reason: 'consistent renaming keeps a/b != y/x');
  });

  test('different called methods never match', () async {
    final result = await runPair(
      project,
      callee('process', 'value', 'result', 'add'),
      callee('handle', 'data', 'out', 'push'),
      ignoreLocals: true,
    );
    expect(result.passed, isTrue,
        reason: 'API surface (called method names) stays visible');
  });

  test('field references stay visible under ignore_locals', () async {
    final result = await runPair(
      project,
      repo('RepoA', '_cache', 'key', 'value'),
      repo('RepoB', '_store', 'name', 'raw'),
      ignoreLocals: true,
    );
    expect(result.passed, isTrue,
        reason: 'field names are API surface, not locals');
  });
}
