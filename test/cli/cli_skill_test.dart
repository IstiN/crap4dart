import 'dart:io';

import 'package:crap4dart/src/cli/exit_codes.dart';
import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  test('skill prints the SKILL.md content', () async {
    final result = await runCliInProcess(Directory.current, const ['skill']);
    expect(result.exitCode, ExitCodes.success);
    expect(result.stdout, contains('crap4dart'));
  });

  test('skill --format install prints installation instructions', () async {
    final result = await runCliInProcess(
      Directory.current,
      const ['skill', '--format', 'install'],
    );
    expect(result.exitCode, ExitCodes.success);
    expect(result.stdout, contains('Installing the crap4dart profiling skill'));
  });

  test('skill rejects an unknown format', () async {
    final result = await runCliInProcess(
      Directory.current,
      const ['skill', '--format', 'yaml'],
    );
    expect(result.exitCode, ExitCodes.usageError);
  });
}
