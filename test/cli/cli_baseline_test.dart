import 'dart:io';

import 'package:crap4dart/src/cli/exit_codes.dart';
import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  test('check --save-baseline records violations and --baseline passes',
      () async {
    final root = createCliTestProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeCleanProject(root);
    // Undocumented public function: public_docs violation.
    File('${root.path}/lib/dirty.dart').writeAsStringSync('void dirty() {}\n');

    final dirty = await runCliInProcess(root, ['check']);
    expect(dirty.exitCode, ExitCodes.thresholdExceeded);

    final saved = await runCliInProcess(root, ['check', '--save-baseline']);
    expect(saved.exitCode, ExitCodes.success);
    expect(saved.stderr, contains('Baseline saved'));
    final baselineFile = File('${root.path}/.crap-baseline.json');
    expect(baselineFile.existsSync(), isTrue);
    expect(baselineFile.readAsStringSync(), contains('dirty'));

    final baselined = await runCliInProcess(root, ['check', '--baseline']);
    expect(baselined.exitCode, ExitCodes.success,
        reason: 'baseline-covered violations must not fail the run');

    // A NEW violation must still fail even with the baseline.
    File('${root.path}/lib/dirty2.dart')
        .writeAsStringSync('void dirty2() {}\n');
    final fresh = await runCliInProcess(root, ['check', '--baseline']);
    expect(fresh.exitCode, ExitCodes.thresholdExceeded);
  });

  test('check --baseline without a baseline file fails normally', () async {
    final root = createCliTestProject();
    addTearDown(() => root.deleteSync(recursive: true));
    writeCleanProject(root);
    final result = await runCliInProcess(root, ['check', '--baseline']);
    expect(result.exitCode, ExitCodes.success);
  });
}
