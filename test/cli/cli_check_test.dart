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

  group('crap4dart check', () {
    test('exit 0 on a clean project', () async {
      writeCleanProject(tempDir);
      final result = await runCli(tempDir, ['check']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('[PASS] loc'));
      expect(result.stdout, contains('[SKIP] test_coverage'));
    });

    test('exit 2 when a gate fails', () async {
      writeCleanProject(tempDir);
      final filler = List.filled(900, '// filler\n').join();
      File(p.join(tempDir.path, 'lib', 'big.dart')).writeAsStringSync(filler);
      File(p.join(tempDir.path, 'crap4dart.yaml')).writeAsStringSync('''
coverage:
  required: false
gates:
  loc:
    max_lines: 100
''');
      final result = await runCli(tempDir, ['check']);
      expect(result.exitCode, 2);
      expect(result.stdout, contains('[FAIL] loc'));
      expect(result.stdout, contains('900 lines > max 100'));
    });

    test('--only and --skip filter gates', () async {
      writeCleanProject(tempDir);
      final only = await runCli(tempDir, ['check', '--only', 'loc']);
      expect(only.exitCode, 0);
      expect(only.stdout, contains('[PASS] loc'));
      expect(only.stdout, isNot(contains('public_docs')));

      final skip = await runCli(tempDir, ['check', '--skip', 'loc']);
      expect(skip.exitCode, 0);
      expect(skip.stdout, isNot(contains('[PASS] loc')));
    });

    test('unknown gate id in --only exits 1', () async {
      writeCleanProject(tempDir);
      final result = await runCli(tempDir, ['check', '--only', 'bogus']);
      expect(result.exitCode, 1);
    });

    test('check --run-tests flag is accepted', () async {
      final result = await runCli(tempDir, ['check', '--help']);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('--run-tests'));
    });
  });
}
