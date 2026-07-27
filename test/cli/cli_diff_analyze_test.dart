@Timeout.factor(2)
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = createCliTestProject());
  tearDown(() => tempDir.deleteSync(recursive: true));

  String legacyFile() => p.join(tempDir.path, 'lib', 'legacy.dart');

  Future<void> commitBase() async {
    writeCleanProject(tempDir);
    File(legacyFile()).writeAsStringSync('int oldMethod() => 0;\n');
    await gitInitAndCommit(tempDir, 'base');
  }

  group('crap4dart analyze --diff', () {
    test('reports only methods touched by the diff', () async {
      await commitBase();
      File(legacyFile()).writeAsStringSync(
        'int addedMethod() => 1;\n',
        mode: FileMode.append,
      );
      final result = await runCli(tempDir, ['analyze', '--diff']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('Diff mode: base HEAD'));
      expect(result.stdout, contains('addedMethod'));
      expect(result.stdout, isNot(contains('oldMethod')));
    });

    test('--diff-base diffs against the given ref', () async {
      await commitBase();
      File(legacyFile()).writeAsStringSync(
        'int addedMethod() => 1;\n',
        mode: FileMode.append,
      );
      await gitInitAndCommit(tempDir, 'second');
      // Working tree is clean: plain --diff has nothing to report.
      final clean = await runCli(tempDir, ['analyze', '--diff']);
      expect(clean.stdout, contains('No Dart files to analyze.'));
      final result =
          await runCli(tempDir, ['analyze', '--diff-base', 'HEAD~1']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('Diff mode: base HEAD~1'));
      expect(result.stdout, contains('addedMethod'));
    });

    test('git failure exits 1', () async {
      writeCleanProject(tempDir); // not a git repo
      final result = await runCli(tempDir, ['analyze', '--diff']);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('git diff failed'));
    });
  });
}
