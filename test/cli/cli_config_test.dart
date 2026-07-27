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

  void writeConfig(String content) {
    File(p.join(tempDir.path, 'crap4dart.yaml')).writeAsStringSync(content);
  }

  group('crap4dart analyze with config', () {
    test('threshold from the config file applies', () async {
      writeMiniProject(tempDir, lcov: zeroCoverageLcov);
      // risky() has CRAP 12.00: passes with threshold 15, fails with 8.
      writeConfig('crap:\n  threshold: 15.0\n');
      final result = await runCli(tempDir, []);
      expect(result.exitCode, 0);
      expect(
        result.stdout,
        contains('Max CRAP: 12.00 — OK (threshold: 15.00)'),
      );
    });

    test('CLI --threshold overrides the config value', () async {
      writeMiniProject(tempDir, lcov: zeroCoverageLcov);
      writeConfig('crap:\n  threshold: 15.0\n');
      final result = await runCli(tempDir, ['analyze', '--threshold', '8.0']);
      expect(result.exitCode, 2);
      expect(result.stderr, contains('CRAP threshold exceeded: 12.00 > 8.0'));
    });

    test('crap.enabled: false exits 0 without analysis', () async {
      writeMiniProject(tempDir, lcov: zeroCoverageLcov);
      writeConfig('crap:\n  enabled: false\n');
      final result = await runCli(tempDir, []);
      expect(result.exitCode, 0);
      expect(result.stdout, contains('CRAP analysis disabled in config.'));
    });

    test('invalid config exits 1 with the offending key', () async {
      writeMiniProject(tempDir, lcov: zeroCoverageLcov);
      writeConfig('crap:\n  threshld: 8.0\n');
      final result = await runCli(tempDir, []);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('crap.threshld'));
    });
  });
}
