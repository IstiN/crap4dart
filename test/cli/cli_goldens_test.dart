import 'dart:io';

import 'package:crap4dart/src/cli/exit_codes.dart';
import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  test('goldens --print-snippet prints the guard source', () async {
    final result = await runCliInProcess(
        Directory.current, ['goldens', '--print-snippet']);
    expect(result.exitCode, ExitCodes.success);
    expect(result.stdout, contains('guardGoldens'));
    expect(result.stdout, contains('Unable to load asset'));
  });

  test('goldens --write drops the guard into test/', () async {
    final root = createCliTestProject();
    addTearDown(() => root.deleteSync(recursive: true));
    final result = await runCliInProcess(root, ['goldens', '--write']);
    expect(result.exitCode, ExitCodes.success);
    final file = File('${root.path}/test/goldens_guard.dart');
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('guardGoldens'));
    // Never leave a flutter_test-importing file in this pure-Dart repo.
    file.deleteSync();
  });
}
