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

  group('crap4dart misc', () {
    test('--version prints the version in-process', () async {
      final result = await runCliInProcess(tempDir, ['--version']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('crap4dart 0.'));
    });

    test('analyze --lcov uses the given coverage file', () async {
      writeMiniProject(tempDir, lcov: zeroCoverageLcov);
      Directory(p.join(tempDir.path, 'custom')).createSync();
      File(p.join(tempDir.path, 'custom', 'cov.info'))
          .writeAsStringSync(fullCoverageLcov);
      final result = await runCliInProcess(
        tempDir,
        ['analyze', '--lcov', p.join(tempDir.path, 'custom', 'cov.info')],
      );
      expect(result.exitCode, 0);
      expect(result.stdout, contains('Max CRAP: 3.00'));
    });

    test('check reports test_coverage when lcov exists', () async {
      writeMiniProject(tempDir, lcov: fullCoverageLcov);
      File(p.join(tempDir.path, 'crap4dart.yaml')).writeAsStringSync('''
gates:
  test_coverage:
    min_percent: 50.0
''');
      final result = await runCliInProcess(
        tempDir,
        ['check', '--only', 'test_coverage'],
      );
      expect(result.exitCode, 0);
      expect(result.stdout, contains('[PASS] test_coverage'));
    });

    test('install with an invalid config exits 1', () async {
      writeCleanProject(tempDir);
      await gitInitAndCommit(tempDir, 'base');
      File(p.join(tempDir.path, 'crap4dart.yaml'))
          .writeAsStringSync('bogus: 1\n');
      final result = await runCliInProcess(tempDir, ['install']);
      expect(result.exitCode, 1);
    });
  });
}
