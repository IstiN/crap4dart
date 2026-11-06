import 'dart:io';

import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  late Directory workDir;

  setUp(() {
    workDir = Directory.systemTemp.createTempSync('crap4dart_scaffold_test_');
  });

  tearDown(() {
    workDir.deleteSync(recursive: true);
  });

  test('scaffold writes the harness files', () async {
    final result = await runCliInProcess(workDir, ['goldens', '--scaffold']);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = [
      'test/golden/golden_scaffold_helper.dart',
      'test/golden/scenes/example_scene_golden_test.dart',
      'test/golden/update_goldens.sh',
      'test/golden/montage.dart',
      'test/golden/goldens/README.md',
    ];
    for (final relative in expected) {
      expect(
        File('${workDir.path}/$relative').existsSync(),
        isTrue,
        reason: '$relative missing',
      );
    }
    // The update script must be executable for the documented flow.
    final stat =
        File('${workDir.path}/test/golden/update_goldens.sh').statSync();
    expect(stat.mode & 0x111, isNot(0));
    // Scopes install at MaterialApp.builder — the load-bearing rule.
    final helper = File(
      '${workDir.path}/test/golden/golden_scaffold_helper.dart',
    ).readAsStringSync();
    expect(helper, contains('MaterialApp.builder'));
    expect(helper, contains('GoldenVariant'));
  });

  test('refuses to overwrite without --force', () async {
    await runCliInProcess(workDir, ['goldens', '--scaffold']);
    final again = await runCliInProcess(workDir, ['goldens', '--scaffold']);
    expect(again.exitCode, 1);
    expect(again.stderr, contains('already exists'));
    final forced =
        await runCliInProcess(workDir, ['goldens', '--scaffold', '--force']);
    expect(forced.exitCode, 0, reason: forced.stderr);
  });

  test('--dry-run writes nothing', () async {
    final result = await runCliInProcess(
      workDir,
      ['goldens', '--scaffold', '--dry-run'],
    );
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, contains('would write'));
    expect(
      Directory('${workDir.path}/test').existsSync(),
      isFalse,
    );
  });

  test('--dir targets a custom directory', () async {
    final result = await runCliInProcess(
      workDir,
      ['goldens', '--scaffold', '--dir', 'integration/golden'],
    );
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
      File('${workDir.path}/integration/golden/montage.dart').existsSync(),
      isTrue,
    );
  });
}
