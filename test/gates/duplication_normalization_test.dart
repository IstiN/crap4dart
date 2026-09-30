import 'dart:io';

import 'package:crap4dart/src/config/config_loader.dart';
import 'package:test/test.dart';

import 'duplication_normalization_fixtures.dart';
import 'duplication_normalization_helpers.dart';
import 'gate_test_utils.dart';

void main() {
  late Directory project;

  setUp(() => project = createTempProject());

  tearDown(() => project.deleteSync(recursive: true));

  test('ignore_locals detects renamed clone across files', () async {
    final result = await runPair(
      project,
      renamedOriginal(),
      renamedClone(),
      ignoreLocals: true,
    );
    expect(result.passed, isFalse, reason: 'renamed clone must be detected');
    expect(result.violations, hasLength(2));
  });

  test('renamed clone passes without ignore_locals (back-compat)', () async {
    final result = await runPair(project, renamedOriginal(), renamedClone());
    expect(result.passed, isTrue, reason: 'default mode is Type-1 only');
  });

  test('ignore_literals masks string and numeric literals', () async {
    final masked = await runPair(
      project,
      literal('process', 100, 'alpha'),
      literal('handle', 200, 'beta'),
      ignoreLiterals: true,
    );
    expect(masked.passed, isFalse, reason: 'literals must be masked');

    final raw = await runPair(
      project,
      literal('process', 100, 'alpha'),
      literal('handle', 200, 'beta'),
    );
    expect(raw.passed, isTrue,
        reason: 'without ignore_literals literals stay visible');
  });

  test('locals of every declaration kind are masked', () async {
    final result = await runPair(
      project,
      kindsOriginal(),
      kindsClone(),
      ignoreLocals: true,
    );
    expect(result.passed, isFalse,
        reason: 'patterns, loop vars, local functions, catch params renamed');
  });

  test('unknown duplication key is rejected', () {
    expect(
      () => const ConfigLoader().loadString(duplicationYaml(badKey: true)),
      throwsException,
    );
  });
}
