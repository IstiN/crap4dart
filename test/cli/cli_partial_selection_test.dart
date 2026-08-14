import 'dart:io';

import 'package:crap4dart/src/cli/exit_codes.dart';
import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  test('whole-project gates skip in --staged mode', () async {
    final tempDir = createCliTestProject();
    addTearDown(() => tempDir.deleteSync(recursive: true));
    writeCleanProject(tempDir);
    await gitInitAndCommit(tempDir, 'base');
    // A staged file no one imports: must NOT fail in a partial run.
    File('${tempDir.path}/lib/staged.dart')
        .writeAsStringSync('/// Docs.\nvoid staged() {}\n');
    await Process.run(
      'git',
      ['add', 'lib/staged.dart'],
      workingDirectory: tempDir.path,
    );
    final result = await runCliInProcess(tempDir, ['check', '--staged']);
    expect(result.exitCode, ExitCodes.success, reason: result.stdout);
    expect(result.stdout, contains('[SKIP] unused_files'));
    expect(result.stdout, contains('partial selection'));
  });

  test('whole-project gates run in full mode', () async {
    final root = createCliTestProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeCleanProject(root);
    final result = await runCliInProcess(root, ['check']);
    expect(result.exitCode, ExitCodes.success);
    expect(result.stdout, contains('[PASS] unused_files'));
  });

  test('whole-project gates skip with explicit paths', () async {
    final root = createCliTestProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeCleanProject(root);
    final result = await runCliInProcess(root, [
      'check',
      '${root.path}/lib/a.dart',
    ]);
    expect(result.exitCode, ExitCodes.success, reason: result.stdout);
    expect(result.stdout, contains('[SKIP] unused_files'));
  });
}
