@Timeout.factor(2)
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'cli_test_utils.dart';

/// A method with CC 12 (eleven `if`s) — over the default complexity max.
const String riskyMethod = '''
int oldRisky(int x) {
  if (x == 1) return 1;
  if (x == 2) return 2;
  if (x == 3) return 3;
  if (x == 4) return 4;
  if (x == 5) return 5;
  if (x == 6) return 6;
  if (x == 7) return 7;
  if (x == 8) return 8;
  if (x == 9) return 9;
  if (x == 10) return 10;
  if (x == 11) return 11;
  return 0;
}
''';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = createCliTestProject());
  tearDown(() => tempDir.deleteSync(recursive: true));

  String legacyFile() => p.join(tempDir.path, 'lib', 'legacy.dart');

  Future<void> commitBase() async {
    writeCleanProject(tempDir);
    File(legacyFile()).writeAsStringSync(riskyMethod);
    await gitInitAndCommit(tempDir, 'base');
  }

  void append(String content) {
    File(legacyFile()).writeAsStringSync(content, mode: FileMode.append);
  }

  group('crap4dart check --diff', () {
    test('ignores violations on untouched legacy lines', () async {
      await commitBase();
      append('int addedClean() => 1;\n');
      final result = await runCliInProcess(
        tempDir,
        ['check', '--diff', '--only', 'complexity'],
      );
      expect(result.exitCode, 0);
      expect(result.stdout, contains('(diff mode)'));
    });

    test('fails on the same violation without --diff', () async {
      await commitBase();
      append('int addedClean() => 1;\n');
      final result =
          await runCliInProcess(tempDir, ['check', '--only', 'complexity']);
      expect(result.exitCode, 2);
    });

    test('flags violations on newly added lines', () async {
      await commitBase();
      append(riskyMethod.replaceAll('oldRisky', 'newRisky'));
      final result = await runCliInProcess(
        tempDir,
        ['check', '--diff', '--only', 'complexity'],
      );
      expect(result.exitCode, 2);
      expect(result.stdout, contains('newRisky'));
    });

    test('checks new files entirely', () async {
      await commitBase();
      File(p.join(tempDir.path, 'lib', 'brand_new.dart'))
          .writeAsStringSync(riskyMethod.replaceAll('oldRisky', 'brandNew'));
      // Untracked files are not in "git diff"; stage the new file.
      await Process.run(
        'git',
        ['add', 'lib/brand_new.dart'],
        workingDirectory: tempDir.path,
      );
      final result = await runCliInProcess(
        tempDir,
        ['check', '--diff', '--only', 'complexity'],
      );
      expect(result.exitCode, 2);
      expect(result.stdout, contains('brandNew'));
    });

    test('--diff conflicts with --changed and --staged', () async {
      await commitBase();
      for (final flag in ['--changed', '--staged']) {
        final result =
            await runCliInProcess(tempDir, ['check', '--diff', flag]);
        expect(result.exitCode, 1, reason: flag);
      }
    });
  });
}
