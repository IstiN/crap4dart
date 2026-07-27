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

  group('crap4dart check selection modes', () {
    test('empty selection exits 0 with a message', () async {
      final result = await runCliInProcess(tempDir, ['check']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('No Dart files to check.'));
    });

    test('invalid config exits 1', () async {
      writeCleanProject(tempDir);
      File(p.join(tempDir.path, 'crap4dart.yaml'))
          .writeAsStringSync('bogus: 1\n');
      final result = await runCliInProcess(tempDir, ['check']);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('bogus'));
    });

    test('--changed and --staged work in a git repo', () async {
      writeCleanProject(tempDir);
      await gitInitAndCommit(tempDir, 'base');
      final changed = await runCliInProcess(tempDir, ['check', '--changed']);
      expect(changed.exitCode, 0);
      expect(changed.stdout, contains('No Dart files to check.'));

      File(p.join(tempDir.path, 'lib', 'staged.dart'))
          .writeAsStringSync('/// Docs.\nvoid staged() {}\n');
      await Process.run(
        'git',
        ['add', 'lib/staged.dart'],
        workingDirectory: tempDir.path,
      );
      final staged = await runCliInProcess(tempDir, ['check', '--staged']);
      expect(staged.exitCode, 0);
      expect(staged.stdout, contains('[PASS] loc'));
    });

    test('--changed and --staged are mutually exclusive', () async {
      writeCleanProject(tempDir);
      final result = await runCliInProcess(
        tempDir,
        ['check', '--changed', '--staged'],
      );
      expect(result.exitCode, 1);
    });

    test('--changed outside a git repository exits 1', () async {
      writeCleanProject(tempDir);
      final result = await runCliInProcess(tempDir, ['check', '--changed']);
      expect(result.exitCode, 1);
    });
  });
}
