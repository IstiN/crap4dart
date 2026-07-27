@Timeout.factor(2)
library;

import 'dart:io';

import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = createCliTestProject());
  tearDown(() => tempDir.deleteSync(recursive: true));

  group('crap4dart analyze selection modes', () {
    test('--changed analyzes changed files in a git repo', () async {
      writeCleanProject(tempDir);
      await gitInitAndCommit(tempDir, 'base');
      final clean = await runCliInProcess(tempDir, ['analyze', '--changed']);
      expect(clean.stdout, contains('No Dart files to analyze.'));

      File('${tempDir.path}/lib/a.dart')
          .writeAsStringSync('/// Docs.\nvoid changed() {}\n');
      final result = await runCliInProcess(tempDir, ['analyze', '--changed']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('changed'));
    });

    test('--changed outside a git repository exits 1', () async {
      writeCleanProject(tempDir);
      final result = await runCliInProcess(tempDir, ['analyze', '--changed']);
      expect(result.exitCode, 1);
    });

    test('a missing explicit path exits 1', () async {
      writeCleanProject(tempDir);
      final result = await runCliInProcess(tempDir, ['analyze', 'no/such/dir']);
      expect(result.exitCode, 1);
    });

    test('--diff conflicts with --changed and explicit paths', () async {
      writeCleanProject(tempDir);
      await gitInitAndCommit(tempDir, 'base');
      final withChanged =
          await runCliInProcess(tempDir, ['analyze', '--diff', '--changed']);
      expect(withChanged.exitCode, 1);
      final withPath = await runCliInProcess(
        tempDir,
        ['analyze', '--diff', 'lib/a.dart'],
      );
      expect(withPath.exitCode, 1);
    });
  });
}
