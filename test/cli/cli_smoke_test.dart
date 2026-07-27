@Timeout.factor(2)
library;

import 'dart:io';

import 'package:test/test.dart';

import 'cli_test_utils.dart';

/// Smoke tests for the real compiled binary via subprocess. Everything
/// else runs in-process (see runCliInProcess) so coverage is honest.
void main() {
  late Directory tempDir;

  setUp(() => tempDir = createCliTestProject());
  tearDown(() => tempDir.deleteSync(recursive: true));

  test('--help exits 0 and prints usage', () async {
    final result = await runCli(tempDir, ['--help']);
    expect(result.exitCode, 0);
    expect(result.stdout, contains('Usage: crap4dart'));
  });

  test('--version prints the pubspec version', () async {
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(File('pubspec.yaml').readAsStringSync())!
        .group(1);
    final result = await runCli(tempDir, ['--version']);
    expect(result.exitCode, 0);
    expect(result.stdout, contains('crap4dart $version'));
  });

  test('check --help lists the flags including --run-tests', () async {
    final result = await runCli(tempDir, ['check', '--help']);
    expect(result.exitCode, 0);
    expect(result.stdout, contains('--run-tests'));
    expect(result.stdout, contains('--diff'));
  });
}
