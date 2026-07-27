@Timeout.factor(2)
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = createCliTestProject());
  tearDown(() => tempDir.deleteSync(recursive: true));

  Map<String, dynamic> decode(ProcessResult result) =>
      jsonDecode(result.stdout as String) as Map<String, dynamic>;

  group('crap4dart --format json', () {
    test('analyze emits only JSON and keeps exit 2', () async {
      writeMiniProject(tempDir, lcov: zeroCoverageLcov);
      final result = await runCli(tempDir, ['analyze', '--format', 'json']);
      expect(result.exitCode, 2);
      final json = decode(result);
      expect(json['command'], 'analyze');
      expect(json['passed'], isFalse);
      expect(json['maxCrap'], 12.0);
      final methods = json['methods'] as List<dynamic>;
      expect(methods, hasLength(1));
      expect(methods.single['method'], 'risky');
      expect(methods.single['crap'], 12.0);
      expect(methods.single['lineCoverage'], 0.0);
      // The threshold message still goes to stderr, not into the JSON.
      expect(result.stderr, contains('CRAP threshold exceeded'));
    });

    test('analyze emits nulls when coverage is missing', () async {
      writeMiniProject(tempDir, lcov: '');
      File(p.join(tempDir.path, 'coverage', 'lcov.info')).deleteSync();
      final result = await runCli(tempDir, ['analyze', '--format', 'json']);
      expect(result.exitCode, 0);
      final json = decode(result);
      expect(json['passed'], isTrue);
      final methods = json['methods'] as List<dynamic>;
      expect(methods.single['crap'], isNull);
      expect(methods.single['lineCoverage'], isNull);
      // Warnings go to stderr, keeping stdout valid JSON.
      expect(result.stderr, contains('Warning'));
    });

    test('check emits a JSON gate report', () async {
      writeCleanProject(tempDir);
      final result = await runCli(tempDir, ['check', '--format', 'json']);
      expect(result.exitCode, 0);
      final json = decode(result);
      expect(json['command'], 'check');
      expect(json['passed'], isTrue);
      final gates = {
        for (final g in json['gates'] as List<dynamic>)
          (g as Map)['id']: g['status'],
      };
      expect(gates['loc'], 'passed');
      expect(gates['test_coverage'], 'skipped');
    });
  });
}
