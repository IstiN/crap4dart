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

  group('crap4dart analyze', () {
    test('empty selection exits 0 with a message', () async {
      final result = await runCliInProcess(tempDir, []);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('No Dart files to analyze.'));
    });

    test('threshold exceeded exits 2 and reports to stderr', () async {
      writeMiniProject(tempDir, lcov: zeroCoverageLcov);
      final result = await runCliInProcess(tempDir, []);
      expect(result.exitCode, 2);
      expect(result.stderr, contains('CRAP threshold exceeded: 12.00 > 8.0'));
      expect(result.stdout, contains('(top-level).risky'));
    });

    test('missing lcov warns and keeps exit 0', () async {
      writeMiniProject(tempDir, lcov: '');
      File(p.join(tempDir.path, 'coverage', 'lcov.info')).deleteSync();
      final result = await runCliInProcess(tempDir, []);
      expect(result.exitCode, 0);
      expect(result.stderr, contains('Warning: no LCOV coverage data found'));
      expect(result.stdout, contains('N/A'));
    });

    test('invalid arguments exit 1', () async {
      final result =
          await runCliInProcess(tempDir, ['analyze', '--threshold', 'nan']);
      expect(result.exitCode, 1);
    });

    test('unknown command exits 1', () async {
      final result = await runCliInProcess(tempDir, ['frobnicate']);
      expect(result.exitCode, 1);
    });

    test('explicit path analysis works', () async {
      writeMiniProject(tempDir, lcov: fullCoverageLcov);
      final result = await runCliInProcess(
        tempDir,
        ['analyze', p.join(tempDir.path, 'lib', 'sample.dart')],
      );
      expect(result.exitCode, 0);
      expect(result.stdout, contains('Max CRAP: 3.00'));
    });
  });
}
