import 'dart:io';

import 'package:crap4dart/src/cli/exit_codes.dart';
import 'package:test/test.dart';

import 'cli_test_utils.dart';

void main() {
  test('profile treats positional paths as tests even when tests are excluded',
      () async {
    final root = createCliProfileProject();
    addTearDown(() => root.deleteSync(recursive: true));
    Directory('${root.path}/test').createSync();
    File('${root.path}/test/a_test.dart').writeAsStringSync('void main() {}\n');
    File('${root.path}/crap4dart.yaml')
        .writeAsStringSync("exclude:\n  - 'test/**'\n");
    final captured = <List<String>>[];

    final result = await runCliInProcessWithProfile(
      root,
      ['profile', 'test/a_test.dart', '--format', 'json'],
      capturingSlowRunner(captured),
    );

    expect(result.exitCode, ExitCodes.success);
    expect(result.stdout, contains('"class": "Foo"'));
    expect(captured.single, contains('test/a_test.dart'));
  });
}
